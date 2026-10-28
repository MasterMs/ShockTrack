import asyncio
from pathlib import Path
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import Optional
from uuid import uuid4

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

from .serial_manager import SerialManager
from .firebaseHelper import FirebaseHelper


class ShockTrackAPI:
    def __init__(self, firebase_user: str, serial_mgr: SerialManager):
        self.serial_mgr = serial_mgr
        self.firebase_user = firebase_user
        self.firebase_helper = FirebaseHelper(
            bucket_name="shocktrack_motion_data",
            credentials_path="C:/Users/Marco/Documents/ShockTrack/git/ShockTrack/WebDashboard/shocktrack-512317-c8a483490e28.json"
        )
        self.app = FastAPI(lifespan=self._lifespan)

        # Track active WebSocket connections
        self.connections = {}

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

            # Register connection
            client_id = str(uuid4())[:8]

            self.connections[client_id] = {
                "websocket": ws,
                "ip": ws.client.host if ws.client else "unknown",
                "connected_at": datetime.now(timezone.utc)
            }

            try:
                await self.serial_mgr.ws_hub.add(ws)

                while True:
                    await ws.receive_text()

            except WebSocketDisconnect:
                pass

            finally:
                # Remove from existing WebSocket hub
                await self.serial_mgr.ws_hub.remove(ws)

                # Remove from connection registry
                self.connections.pop(client_id, None)

        # List active WebSocket connections
        @self.app.get("/connections")
        async def get_connections():
            now = datetime.now(timezone.utc)

            connections = [
                {
                    "id": client_id,
                    "ip": client["ip"],
                    "connected_at": client["connected_at"].isoformat(),
                    "duration_seconds": int(
                        (now - client["connected_at"]).total_seconds()
                    )
                }
                for client_id, client in self.connections.items()
            ]

            return JSONResponse({
                "count": len(connections),
                "connections": connections
            })

        # Serial connection status
        @self.app.get("/status")
        async def status():
            return JSONResponse({
                "connected": await self.serial_mgr.is_connected(),
                "csv_logging": await self.serial_mgr.is_csv_logging(),
                "csv_file": self.serial_mgr.logger.filepath
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

        # Start CSV recording
        @self.app.post("/startCSV")
        async def start_csv(filepath: Optional[str] = None):
            if await self.serial_mgr.is_csv_logging():
                return JSONResponse({
                    "recording": True,
                    "filepath": self.serial_mgr.logger.filepath,
                    "message": "CSV recording is already active"
                })

            opened_filepath = await self.serial_mgr.start_csv(filepath)

            return JSONResponse({
                "recording": True,
                "filepath": opened_filepath,
                "message": "CSV recording started"
            })

        # Stop CSV recording
        @self.app.post("/stopCSV")
        async def stop_csv() -> JSONResponse:
            filepath = await self.serial_mgr.stop_csv()

            if filepath is None:
                return JSONResponse({
                    "recording": False,
                    "filepath": None,
                    "message": "CSV recording is not active"
                })

            firebase_response = self.firebase_helper.upload_csv(
                filepath, user_id="test_user")

            return JSONResponse({
                "recording": False,
                "filepath": firebase_response.get("storagePath"),
                "public_url": f"https://storage.googleapis.com/shocktrack_motion_data/users/test_user/sessions/test_user_sensor_output_with_timestamps_20261028-193157.csv",
                "message": "CSV recording stopped"
            })

        # Dashboard
        @self.app.get("/")
        async def index():
            return FileResponse(self.static_dir / "index.html")
