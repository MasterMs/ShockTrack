"""USB serial ingest and on-demand, user-owned recordings."""
import asyncio
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
from uuid import uuid4

import serial

from .csv_logger import CsvLogger
from .parser import LineParser, ParsedLine
from .ws_hub import WebSocketHub


@dataclass
class Recording:
    id: str
    uid: str
    filepath: str
    started_at: str
    ended_at: Optional[str] = None
    samples: int = 0
    upload_status: str = "recording"
    storage_path: Optional[str] = None

    def as_dict(self):
        return {
            "sessionId": self.id,
            "startedAt": self.started_at,
            "endedAt": self.ended_at,
            "sampleCount": self.samples,
            "status": self.upload_status,
            "storagePath": self.storage_path,
        }


class SessionError(Exception):
    def __init__(self, status_code: int, message: str):
        self.status_code = status_code
        super().__init__(message)


class SerialManager:
    def __init__(
        self,
        port: str,
        baud: int,
        retry_seconds: int,
        logger: CsvLogger,
        parser: LineParser,
        ws_hub: WebSocketHub,
        firebase_store=None,
    ):
        self.port = port
        self.baud = baud
        self.retry_seconds = retry_seconds
        self.logger = logger
        self.parser = parser
        self.ws_hub = ws_hub
        self.firebase_store = firebase_store

        self._ser: Optional[serial.Serial] = None
        self._ser_lock = asyncio.Lock()
        self._record_lock = asyncio.Lock()
        self._active: Optional[Recording] = None
        # Failed uploads can be retried while this server process is running.
        self._finished: dict[str, Recording] = {}

        self._task: Optional[asyncio.Task] = None
        self._stop = False

    async def _open_serial_with_retry(self) -> serial.Serial:
        while not self._stop:
            try:
                s = serial.Serial(self.port, self.baud, timeout=1)
                async with self._ser_lock:
                    self._ser = s
                print(f"Connected to {self.port} at {self.baud} baud.")
                return s
            except Exception as exc:
                print(f"Waiting for {self.port} ({exc}); retrying...")
                await asyncio.sleep(self.retry_seconds)
        raise asyncio.CancelledError()

    async def is_connected(self) -> bool:
        async with self._ser_lock:
            return self._ser is not None and bool(getattr(self._ser, "is_open", False))

    async def force_close(self) -> None:
        async with self._ser_lock:
            if self._ser is not None:
                try:
                    self._ser.close()
                except Exception:
                    pass
                self._ser = None

    async def start(self) -> None:
        if self._task is None or self._task.done():
            self._stop = False
            self._task = asyncio.create_task(self._run())

    async def stop(self) -> None:
        self._stop = True
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
            self._task = None
        await self.force_close()
        if self._active is not None:
            recording = self._active
            try:
                await self.stop_session(recording.uid, recording.id)
            except SessionError as exc:
                print(f"Recording finalized locally but not uploaded: {exc}")

    async def reconnect(self) -> None:
        # _run automatically reopens the serial port; do not restart the logger.
        await self.force_close()
        if self._task is None or self._task.done():
            await self.start()

    async def current_session(self, uid: str) -> dict:
        async with self._record_lock:
            if self._active is None or self._active.uid != uid:
                return {"recording": False}
            return {"recording": True, **self._active.as_dict()}

    async def is_recording(self) -> bool:
        async with self._record_lock:
            return self._active is not None

    async def start_session(self, uid: str) -> dict:
        if self.firebase_store is None:
            raise SessionError(503, "Firebase is not configured on the Python server")
        if not await self.is_connected():
            raise SessionError(409, "Serial sensor is not connected")
        async with self._record_lock:
            if self._active is not None:
                raise SessionError(409, "A recording is already in progress")
            session_id = uuid4().hex
            filepath = str(Path(self.logger.log_dir) / f"{session_id}.csv")
            self.logger.open(filepath)
            self._active = Recording(
                id=session_id,
                uid=uid,
                filepath=filepath,
                started_at=datetime.now(timezone.utc).isoformat(),
            )
            return self._active.as_dict()

    async def stop_session(self, uid: str, session_id: str) -> dict:
        async with self._record_lock:
            recording = self._active
            if recording is None or recording.id != session_id:
                raise SessionError(404, "No active recording with that session ID")
            if recording.uid != uid:
                raise SessionError(403, "This recording belongs to another user")
            self.logger.close()  # flush/close before uploading
            recording.ended_at = datetime.now(timezone.utc).isoformat()
            recording.upload_status = "uploading"
            self._active = None
            self._finished[session_id] = recording

        return await self._upload(recording)

    async def retry_upload(self, uid: str, session_id: str) -> dict:
        async with self._record_lock:
            recording = self._finished.get(session_id)
            if recording is None or recording.uid != uid:
                raise SessionError(404, "Unknown recording")
            if recording.upload_status == "complete":
                return recording.as_dict()
            if recording.upload_status == "uploading":
                raise SessionError(409, "Upload is already in progress")
            recording.upload_status = "uploading"
        return await self._upload(recording)

    async def _upload(self, recording: Recording) -> dict:
        try:
            # Cloud uploads are blocking I/O and must not stall the serial loop.
            path = await asyncio.to_thread(
                self.firebase_store.upload_session, recording
            )
        except Exception as exc:
            async with self._record_lock:
                recording.upload_status = "upload_failed"
            raise SessionError(
                502,
                f"Firebase upload failed; local CSV retained at {recording.filepath}: {exc}",
            ) from exc

        async with self._record_lock:
            recording.storage_path = path
            recording.upload_status = "complete"
        return recording.as_dict()

    async def _handle_line(self, raw: str) -> None:
        parsed: ParsedLine = self.parser.parse(raw)
        # Invalid lines still go to existing WebSocket clients, but never
        # corrupt the fixed seven-column CSV format.
        if parsed.is_valid:
            async with self._record_lock:
                if self._active is not None:
                    self.logger.write(parsed.to_csv_row())
                    self._active.samples += 1
        await self.ws_hub.broadcast_text(parsed.to_ws_text())

    async def _run(self) -> None:
        try:
            while not self._stop:
                if not await self.is_connected():
                    await self._open_serial_with_retry()
                async with self._ser_lock:
                    current = self._ser
                if current is None:
                    continue
                try:
                    # readline() has a 1-second timeout; never block the API loop.
                    raw = (await asyncio.to_thread(current.readline)).decode(
                        "utf-8", errors="ignore"
                    ).strip()
                except (OSError, serial.SerialException) as exc:
                    print(f"Serial read failed: {exc}")
                    await self.force_close()
                    continue
                if raw:
                    await self._handle_line(raw)
        except asyncio.CancelledError:
            raise
        finally:
            await self.force_close()
