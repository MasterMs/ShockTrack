import csv
import os
import time
from typing import Any, List, Optional


class CsvLogger:
    def __init__(self, log_dir: str, header: List[str]):
        """CSV Logger for logging sensor data with timestamps."""
        self.log_dir = log_dir
        self.header = header
        self.filepath: Optional[str] = None
        self._f = None
        self._writer = None

    def open(self, filepath: Optional[str] = None) -> str:
        """Open a new or existing CSV log file for appending."""
        os.makedirs(self.log_dir, exist_ok=True)

        if filepath is None:
            filepath = os.path.join(
                self.log_dir,
                f"sensor_output_with_timestamps_{time.strftime('%Y%m%d-%H%M%S')}.csv",
            )
        elif not os.path.isabs(filepath):
            filepath = os.path.join(self.log_dir, filepath)

        self.filepath = filepath

        self._f = open(filepath, mode="a", newline="")
        self._writer = csv.writer(self._f)

        if self._f.tell() == 0:
            self._writer.writerow(self.header)
            self._f.flush()

        print(f"Logging CSV rows to {filepath}...")
        return filepath

    def write(self, row: List[Any]) -> None:
        """Write a row to the CSV log file."""
        if not self._writer or not self._f:
            raise RuntimeError("CsvLogger is not open()")
        self._writer.writerow(row)
        self._f.flush()

    def is_open(self) -> bool:
        """Return True when a CSV file is currently open for logging."""
        return self._f is not None and not self._f.closed

    def close(self) -> None:
        """Close the CSV log file."""
        if self._f:
            self._f.close()
            print(f"Closed log file {self.filepath}")
        self._f = None
        self._writer = None
        self.filepath = None
