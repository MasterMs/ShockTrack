import asyncio
import csv
import os
import time
import serial
from datetime import datetime

from fastapi import FastAPI, WebSocket, BackgroundTasks, Request
from fastapi.responses import FileResponse, HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles


from contextlib import asynccontextmanager


# ----- CONFIG -----


PORT = "COM3"
BAUD = 115200
RETRY_SECONDS = 2
LOG_DIR = "logs"
HEADER = ["timestamp", "acel_x", "acel_y",
          "acel_z", "gyro_x", "gyro_y", "gyro_z"]

clients = set()
ser = None  # global serial object
ser_lock = asyncio.Lock()
serial_task_handle = None
stop_serial = False


async def open_serial_with_retry(port: str, baudrate: int, retry_seconds: int = 2) -> serial.Serial:
    global ser
    while True:
        try:
            s = serial.Serial(port, baudrate, timeout=1)
            print(f"Connected to {port} at {baudrate} baud.")
            async with ser_lock:
                ser = s
            return s
        except Exception as e:
            print(
                f"Waiting for {port}... (retrying in {retry_seconds}s) [{e}]")
            await asyncio.sleep(retry_seconds)


def parse_csv_line(line: str):
    parts = [p.strip() for p in line.split(",")]
    if len(parts) != 6:
        return None
    try:
        return [float(p) for p in parts]
    except ValueError:
        return None


async def serial_task(port=PORT, baud=BAUD, retry_seconds=RETRY_SECONDS, csv_file=None):
    global ser, stop_serial

    os.makedirs(LOG_DIR, exist_ok=True)
    if csv_file is None:
        csv_file = os.path.join(
            LOG_DIR, f"sensor_output_with_timestamps_{time.strftime('%Y%m%d-%H%M%S')}.csv")

    # ensure serial is opened (this will wait until device available)
    try:
        await open_serial_with_retry(port, baud, retry_seconds)
    except asyncio.CancelledError:
        return

    f = None
    writer = None

    try:
        f = open(csv_file, mode="a", newline="")
        writer = csv.writer(f)
        if f.tell() == 0:
            writer.writerow(HEADER)
            f.flush()

        print(f"Logging CSV rows to {csv_file} (Ctrl+C to stop)...")

        while True:
            if stop_serial:
                break

            async with ser_lock:
                local_ser = ser

            if local_ser is None or not getattr(local_ser, "is_open", False):
                # try to reopen in background and wait a bit
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

            row = parse_csv_line(raw)
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]

            if row is not None:
                writer.writerow([timestamp] + row)
                f.flush()
                print([timestamp] + row)
            else:
                writer.writerow([timestamp, raw])
                f.flush()
                print([timestamp, raw])

            if clients:
                for ws in list(clients):
                    try:
                        await ws.send_text(raw)
                    except Exception:
                        clients.discard(ws)

            await asyncio.sleep(0)

    except asyncio.CancelledError:
        raise
    finally:
        if f:
            f.close()
            print(f"Closed log file {csv_file}")
        async with ser_lock:
            if ser and getattr(ser, "is_open", False):
                try:
                    ser.close()
                except Exception:
                    pass
            ser = None
        print("Serial port closed.")


async def ensure_serial_running():
    global serial_task_handle
    if serial_task_handle is None or serial_task_handle.done():
        serial_task_handle = asyncio.create_task(serial_task())


# --------------------
# LIFESPAN HANDLER
# --------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    global serial_task_handle, stop_serial
    stop_serial = False
    serial_task_handle = asyncio.create_task(serial_task())
    try:
        yield
    finally:
        stop_serial = True
        if serial_task_handle:
            serial_task_handle.cancel()
            try:
                await serial_task_handle
            except asyncio.CancelledError:
                pass


app = FastAPI(lifespan=lifespan)


# --------------------
# WEBSOCKET ENDPOINT
# --------------------
@app.websocket("/ws")
async def ws_endpoint(ws: WebSocket):
    await ws.accept()
    clients.add(ws)
    try:
        while True:
            await ws.receive_text()
    except Exception:
        clients.discard(ws)


# --------------------
# STATUS + RECONNECT ENDPOINTS
# --------------------
@app.get("/status")
async def status():
    async with ser_lock:
        connected = ser is not None and getattr(ser, "is_open", False)
    return JSONResponse({"connected": connected})


@app.post("/reconnect")
async def reconnect(background_tasks: BackgroundTasks):
    """
    Trigger a reconnect attempt. Returns current status immediately (tries
    for a short window) and ensures a background task will try to open the
    serial port if closed.
    """
    global ser, serial_task_handle

    # If already connected, short-circuit
    async with ser_lock:
        if ser is not None and getattr(ser, "is_open", False):
            return JSONResponse({"connected": True, "message": "Already connected"})

        # If there's a stale handle, close it so Windows releases the COM port
        if ser is not None:
            try:
                ser.close()
            except Exception:
                pass
            ser = None

    # Schedule a background ensure/open attempt (create_task around the coroutine)
    # background_tasks.add_task will call the callable we provide with the args below.
    # Here we call asyncio.create_task(ensure_serial_running()) so it runs in the loop.
    background_tasks.add_task(asyncio.create_task, ensure_serial_running())

    # Poll the connection status for a short window so the caller gets immediate feedback.
    # If the background opener is quick, we can return connected: true right away.
    timeout_s = 3.0
    interval = 0.25
    checks = int(timeout_s / interval)

    for _ in range(checks):
        async with ser_lock:
            connected = ser is not None and getattr(ser, "is_open", False)
        if connected:
            return JSONResponse({"connected": True, "message": "Reconnected"})
        await asyncio.sleep(interval)

    # If we get here, reconnect didn't complete within the short window.
    return JSONResponse({"connected": False, "message": "Reconnect attempt started; not connected yet"})


# --------------------
# BLANK PAGE SHOWING THE LIVE MPU DATA + RECONNECT BUTTON
# --------------------
@app.get("/", response_class=HTMLResponse)
async def index():
    return FileResponse("static/index.html")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("pyTrack:app", host="192.168.2.12",
                port=8000, log_level="info", reload=True)
