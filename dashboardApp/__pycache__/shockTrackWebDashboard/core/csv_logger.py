import csv
import os
import time
from typing import Any, List, Optional


class CsvLogger:
    def __init__(self, log_dir: str, header: List[str]):
        self.log_dir = log_dir
        self.header = header
        self.filepath: Optional[str] = None
        self._f = None
        self._writer = None

    def open(self, filepath: Optional[str] = None) -> str:
        os.makedirs(self.log_dir, exist_ok=True)
        if filepath is None:
            filepath = os.path.join(
                self.log_dir,
                f"sensor_output_with_timestamps_{time.strftime('%Y%m%d-%H%M%S')}.csv",
            )
        self.filepath = filepath
        self._f = open(filepath, mode="a", newline="")
        self._writer = csv.writer(self._f)

        if self._f.tell() == 0:
            self._writer.writerow(self.header)
            self._f.flush()

        return filepath

    def write(self, row: List[Any]) -> None:
        if not self._writer or not self._f:
            raise RuntimeError("CsvLogger is not open()")
        self._writer.writerow(row)
        self._f.flush()

    def close(self) -> None:
        if self._f:
            self._f.close()
        self._f = None
        self._writer = None
        self.filepath = None
