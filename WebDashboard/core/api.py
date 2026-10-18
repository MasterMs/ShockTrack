
import asyncio
from pathlib import Path
from contextlib import asynccontextmanager

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

from .serial_manager import SerialManager


class ShockTrackAPI:
    def __init__(self, serial_mgr: SerialManager):
        self.serial_mgr = serial_mgr
        self.app = FastAPI(lifespan=self._lifespan)

        # Static files directory
        self.static_dir = Path(__file__).resolve().parent.parent / "static"

        # Serve HTML, CSS, JS, and images
        self.app.mount(
            "/static",
            StaticFiles(directory=str(self.static_dir)),
            name="static"
        )

        self._mount_routes()

    @asynccontextmanager
    async def _lifespan(self, app: FastAPI):
        await self.serial_mgr.start()
        try:
            yield
        finally:
            await self.serial_mgr.stop()

    def _mount_routes(self) -> None:

        # WebSocket - Live sensor streaming
        @self.app.websocket("/ws")
        async def ws_endpoint(ws: WebSocket):
            await ws.accept()
            await self.serial_mgr.ws_hub.add(ws)

            try:
                while True:
                    await ws.receive_text()
            except WebSocketDisconnect:
                pass
            finally:
                await self.serial_mgr.ws_hub.remove(ws)

        # Serial connection status
        @self.app.get("/status")
        async def status():
            return JSONResponse({
                "connected": await self.serial_mgr.is_connected()
            })

        # Reconnect serial device
        @self.app.post("/reconnect")
        async def reconnect():
            if await self.serial_mgr.is_connected():
                return JSONResponse({
                    "connected": True,
                    "message": "Already connected"
                })

            await self.serial_mgr.reconnect()

            for _ in range(12):
                if await self.serial_mgr.is_connected():
                    return JSONResponse({
                        "connected": True,
                        "message": "Reconnected"
                    })

                await asyncio.sleep(0.25)

            return JSONResponse({
                "connected": False,
                "message": "Reconnect attempt started; not connected yet"
            })

        # Dashboard
        @self.app.get("/")
        async def index():
            return FileResponse(self.static_dir / "index.html")
