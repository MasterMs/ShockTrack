import uvicorn

from core.api import ShockTrackAPI
from core.csv_logger import CsvLogger
from core.parser import LineParser
from core.serial_manager import SerialManager
from core.ws_hub import WebSocketHub


# ----- CONFIG -----
PORT = "COM3"
BAUD = 115200
RETRY_SECONDS = 2
LOG_DIR = "logs"
HEADER = ["timestamp", "acel_x", "acel_y",
          "acel_z", "gyro_x", "gyro_y", "gyro_z"]


ws_hub = WebSocketHub()
parser = LineParser()
logger = CsvLogger(log_dir=LOG_DIR, header=HEADER)

serial_mgr = SerialManager(
    port=PORT,
    baud=BAUD,
    retry_seconds=RETRY_SECONDS,
    logger=logger,
    parser=parser,
    ws_hub=ws_hub,
)

api = ShockTrackAPI(serial_mgr)
app = api.app


if __name__ == "__main__":
    uvicorn.run(
        "pyTrack:app",
        host="192.168.2.12",
        port=8000,
        log_level="info",
        reload=True,
    )
