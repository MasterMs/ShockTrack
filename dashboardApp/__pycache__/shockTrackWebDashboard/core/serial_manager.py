import asyncio
from typing import Optional
import serial

from .csv_logger import CsvLogger
from .parser import LineParser
from .ws_hub import WebSocketHub


class SerialManager:
    def __init__(self, port, baud, retry_seconds, logger, parser, ws_hub):
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

    async def _open_serial_with_retry(self):
        while True:
            try:
                s = serial.Serial(self.port, self.baud, timeout=1)
                async with self._ser_lock:
                    self._ser = s
                return s
            except Exception:
                await asyncio.sleep(self.retry_seconds)

    async def is_connected(self) -> bool:
        async with self._ser_lock:
            return self._ser is not None and self._ser.is_open

    async def start(self):
        if self._task is None or self._task.done():
            self._stop = False
            self._task = asyncio.create_task(self._run())

    async def stop(self):
        self._stop = True
        if self._task:
            self._task.cancel()
        await self.force_close()
        self.logger.close()

    async def force_close(self):
        async with self._ser_lock:
            if self._ser:
                try:
                    self._ser.close()
                except Exception:
                    pass
            self._ser = None

    async def reconnect(self):
        await self.force_close()
        await self.start()

    async def _run(self):
        self.logger.open()
        await self._open_serial_with_retry()

        try:
            while not self._stop:
                async with self._ser_lock:
                    ser = self._ser
                if not ser:
                    await asyncio.sleep(0.5)
                    continue

                raw = ser.readline().decode("utf-8", errors="ignore").strip()
                if not raw:
                    continue

                parsed = self.parser.parse(raw)
                self.logger.write(parsed.to_csv_row())
                await self.ws_hub.broadcast_text(parsed.to_ws_text())
        finally:
            await self.force_close()
            self.logger.close()
