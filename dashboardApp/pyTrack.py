import asyncio
import csv
import os
import time
from dataclasses import dataclass
from datetime import datetime
from typing import Optional, List, Set, Dict, Any

import serial
from fastapi import FastAPI, WebSocket, BackgroundTasks
from fastapi.responses import FileResponse, HTMLResponse, JSONResponse
from contextlib import asynccontextmanager


# --------------------
# CONFIG
# --------------------
PORT = "COM3"
BAUD = 115200
RETRY_SECONDS = 2
LOG_DIR = "logs"
HEADER = ["timestamp", "acel_x", "acel_y",
          "acel_z", "gyro_x", "gyro_y", "gyro_z"]


# --------------------
# SERIALIZATION / PARSING
# --------------------
@dataclass
class ParsedLine:
    timestamp: str
    raw: str
    values: Optional[List[float]]  # 6 floats if valid, else None

    @property
    def is_valid(self) -> bool:
        return self.values is not None

    def to_csv_row(self) -> List[Any]:
        if self.is_valid:
            return [self.timestamp] + self.values  # type: ignore
        return [self.timestamp, self.raw]

    def to_ws_text(self) -> str:
        # Keep identical behavior: you were sending raw line over WS
        return self.raw


class LineParser:
    """Turns a raw CSV-ish line into floats (or None)."""

    @staticmethod
    def parse_csv_6floats(line: str) -> Optional[List[float]]:
        parts = [p.strip() for p in line.split(",")]
        if len(parts) != 6:
            return None
        try:
            return [float(p) for p in parts]
        except ValueError:
            return None

    def parse(self, raw: str) -> ParsedLine:
        ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
        values = self.parse_csv_6floats(raw)
        return ParsedLine(timestamp=ts, raw=raw, values=values)


# --------------------
# CSV LOGGING
# --------------------
class CsvLogger:
    def __init__(self, log_dir: str = LOG_DIR, header: Optional[List[str]] = None):
        self.log_dir = log_dir
        self.header = header or HEADER
        self.filepath: Optional[str] = None
        self._f = None
        self._writer = None

    def open(self, filepath: Optional[str] = None) -> str:
        os.makedirs(self.log_dir, exist_ok=True)
        if filepath is None:
            filepath = os.path.join(
                self.log_dir,
                f"sensor_output_with_timestamps_{time.strftime('%Y%m%d-%H%M%S')}.csv"
            )
        self.filepath = filepath
        self._f = open(filepath, mode="a", newline="")
        self._writer = csv.writer(self._f)

        if self._f.tell() == 0:
            self._writer.writerow(self.header)
            self._f.flush()

        print(f"Logging CSV rows to {filepath} (Ctrl+C to stop)...")
        return filepath

    def write(self, row: List[Any]) -> None:
        if not self._writer or not self._f:
            raise RuntimeError("CsvLogger is not open()")
        self._writer.writerow(row)
        self._f.flush()

    def close(self) -> None:
        if self._f:
            self._f.close()
            print(f"Closed log file {self.filepath}")
        self._f = None
        self._writer = None
        self.filepath = None


# --------------------
# WEBSOCKET CLIENT HUB
# --------------------
class WebSocketHub:
    def __init__(self):
        self._clients: Set[WebSocket] = set()
        self._lock = asyncio.Lock()

    async def add(self, ws: WebSocket) -> None:
        async with self._lock:
            self._clients.add(ws)

    async def remove(self, ws: WebSocket) -> None:
        async with self._lock:
            self._clients.discard(ws)

    async def broadcast_text(self, text: str) -> None:
        async with self._lock:
            clients = list(self._clients)

        if not clients:
            return

        for ws in clients:
            try:
                await ws.send_text(text)
            except Exception:
                await self.remove(ws)

    async def count(self) -> int:
        async with self._lock:
            return len(self._clients)


# --------------------
# SERIAL MANAGER (read loop + reconnect)
# --------------------
class SerialManager:
    def __init__(
        self,
        port: str = PORT,
        baud: int = BAUD,
        retry_seconds: int = RETRY_SECONDS,
        parser: Optional[LineParser] = None,
        logger: Optional[CsvLogger] = None,
        ws_hub: Optional[WebSocketHub] = None,
    ):
        self.port = port
        self.baud = baud
        self.retry_seconds = retry_seconds

        self.parser = parser or LineParser()
        self.logger = logger or CsvLogger()
        self.ws_hub = ws_hub or WebSocketHub()

        self._ser: Optional[serial.Serial] = None
        self._ser_lock = asyncio.Lock()

        self._task: Optional[asyncio.Task] = None
        self._stop = False

    async def _open_serial_with_retry(self) -> serial.Serial:
        while True:
            try:
                s = serial.Serial(self.port, self.baud, timeout=1)
                print(f"Connected to {self.port} at {self.baud} baud.")
                async with self._ser_lock:
                    self._ser = s
                return s
            except Exception as e:
                print(
                    f"Waiting for {self.port}... (retrying in {self.retry_seconds}s) [{e}]")
                await asyncio.sleep(self.retry_seconds)

    async def is_connected(self) -> bool:
        async with self._ser_lock:
            return self._ser is not None and getattr(self._ser, "is_open", False)

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
        await self.force_close()
        self.logger.close()

    async def reconnect(self) -> None:
        # Close stale handle so Windows releases COM port
        await self.force_close()
        # Ensure task is running (it will reopen)
        await self.start()

    async def _run(self) -> None:
        # Open CSV once per run
        self.logger.open()

        # Ensure serial is opened (wait until device available)
        try:
            await self._open_serial_with_retry()
        except asyncio.CancelledError:
            return

        try:
            while not self._stop:
                async with self._ser_lock:
                    local_ser = self._ser

                if local_ser is None or not getattr(local_ser, "is_open", False):
                    await asyncio.sleep(0.5)
                    continue

                try:
                    raw = local_ser.readline().decode("utf-8", errors="ignore").strip()
                except Exception as e:
                    print("Serial read error:", e)
                    raw = ""

                if not raw:
                    await asyncio.sleep(0)
                    continue

                parsed = self.parser.parse(raw)

                # Log to CSV (valid lines become 7 columns; invalid are [timestamp, raw])
                self.logger.write(parsed.to_csv_row())

                # Console debug (same spirit as before)
                print(parsed.to_csv_row())

                # Broadcast to websocket clients (raw line)
                await self.ws_hub.broadcast_text(parsed.to_ws_text())

                await asyncio.sleep(0)

        except asyncio.CancelledError:
            raise
        finally:
            await self.force_close()
            self.logger.close()
            print("Serial port closed.")


# --------------------
# FASTAPI WRAPPER
# --------------------
class ShockTrackAPI:
    def __init__(self, serial_mgr: SerialManager):
        self.serial_mgr = serial_mgr
        self.app = FastAPI(lifespan=self._lifespan)
        self._mount_routes()

    @asynccontextmanager
    async def _lifespan(self, app: FastAPI):
        await self.serial_mgr.start()
        try:
            yield
        finally:
            await self.serial_mgr.stop()

    def _mount_routes(self) -> None:
        @self.app.websocket("/ws")
        async def ws_endpoint(ws: WebSocket):
            await ws.accept()
            await self.serial_mgr.ws_hub.add(ws)
            try:
                while True:
                    # Keep it simple: clients can send pings, we ignore content
                    await ws.receive_text()
            except Exception:
                await self.serial_mgr.ws_hub.remove(ws)

        @self.app.get("/status")
        async def status():
            return JSONResponse({"connected": await self.serial_mgr.is_connected()})

        @self.app.post("/reconnect")
        async def reconnect(background_tasks: BackgroundTasks):
            """
            Kick off a reconnect attempt and return quick feedback.
            """
            if await self.serial_mgr.is_connected():
                return JSONResponse({"connected": True, "message": "Already connected"})

            # Start reconnect in background
            background_tasks.add_task(self.serial_mgr.reconnect)

            # Poll briefly for immediate feedback
            timeout_s = 3.0
            interval = 0.25
            checks = int(timeout_s / interval)

            for _ in range(checks):
                if await self.serial_mgr.is_connected():
                    return JSONResponse({"connected": True, "message": "Reconnected"})
                await asyncio.sleep(interval)

            return JSONResponse({"connected": False, "message": "Reconnect attempt started; not connected yet"})

        @self.app.get("/", response_class=HTMLResponse)
        async def index():
            return FileResponse("static/index.html")


# --------------------
# APP ENTRYPOINT
# --------------------
serial_mgr = SerialManager()
api = ShockTrackAPI(serial_mgr)
app = api.app

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("pyTrack:app", host="192.168.2.12",
                port=8000, log_level="info", reload=True)
