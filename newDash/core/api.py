import asyncio
from contextlib import asynccontextmanager

from fastapi import BackgroundTasks, FastAPI, WebSocket
from fastapi.responses import FileResponse, HTMLResponse, JSONResponse

from .serial_manager import SerialManager


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
                    await ws.receive_text()
            except Exception:
                await self.serial_mgr.ws_hub.remove(ws)

        @self.app.get("/status")
        async def status():
            return JSONResponse({"connected": await self.serial_mgr.is_connected()})

        @self.app.post("/reconnect")
        async def reconnect(background_tasks: BackgroundTasks):
            if await self.serial_mgr.is_connected():
                return JSONResponse({"connected": True, "message": "Already connected"})

            background_tasks.add_task(self.serial_mgr.reconnect)

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
