import asyncio
from typing import Optional

import serial

from .csv_logger import CsvLogger
from .parser import LineParser
from .ws_hub import WebSocketHub


class SerialManager:
    def __init__(
        self,
        port: str,
        baud: int,
        retry_seconds: int,
        logger: CsvLogger,
        parser: LineParser,
        ws_hub: WebSocketHub,
    ):
        self.port = port
        self.baud = baud
        self.retry_seconds = retry_seconds

        self.logger = logger
        self.parser = parser
        self.ws_hub = ws_hub

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
        await self.force_close()
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

                # Log to CSV
                self.logger.write(parsed.to_csv_row())
                print(parsed.to_csv_row())

                # Broadcast to websocket clients
                await self.ws_hub.broadcast_text(parsed.to_ws_text())

                await asyncio.sleep(0)

        except asyncio.CancelledError:
            raise
        finally:
            await self.force_close()
            self.logger.close()
            print("Serial port closed.")
