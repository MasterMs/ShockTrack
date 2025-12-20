import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI, WebSocket, BackgroundTasks
from fastapi.responses import FileResponse, HTMLResponse, JSONResponse


class ShockTrackAPI:
    def __init__(self, serial_mgr):
        self.serial_mgr = serial_mgr
        self.app = FastAPI(lifespan=self._lifespan)
        self._mount_routes()

    @asynccontextmanager
    async def _lifespan(self, app):
        await self.serial_mgr.start()
        try:
            yield
        finally:
            await self.serial_mgr.stop()

    def _mount_routes(self):
        @self.app.websocket("/ws")
        async def ws(ws: WebSocket):
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
            background_tasks.add_task(self.serial_mgr.reconnect)
            return JSONResponse({"message": "Reconnect started"})

        @self.app.get("/", response_class=HTMLResponse)
        async def index():
            return FileResponse("static/index.html")
