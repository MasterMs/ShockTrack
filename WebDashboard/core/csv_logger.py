import csv
import os
import time
from typing import Any, List, Optional


class CsvLogger:
    """Only writes while an explicit recording session is active."""

    def __init__(self, log_dir: str, header: List[str]):
        self.log_dir = log_dir
        self.header = header
        self.filepath: Optional[str] = None
        self._f = None
        self._writer = None

    def open(self, filepath: Optional[str] = None) -> str:
        if self._f is not None:
            raise RuntimeError("A CSV recording is already open")
        os.makedirs(self.log_dir, exist_ok=True)

        if filepath is None:
            filepath = os.path.join(
                self.log_dir,
                f"sensor_output_{time.strftime('%Y%m%d-%H%M%S')}.csv",
            )

        # Exclusive creation prevents accidentally overwriting a prior session.
        self._f = open(filepath, mode="x", newline="", encoding="utf-8")
        self.filepath = filepath
        self._writer = csv.writer(self._f)
        self._writer.writerow(self.header)
        self._f.flush()
        return filepath

    def write(self, row: List[Any]) -> None:
        if self._writer is None or self._f is None:
            raise RuntimeError("CSV recording is not active")
        self._writer.writerow(row)
        self._f.flush()

    def close(self) -> Optional[str]:
        filepath = self.filepath
        if self._f is not None:
            self._f.close()
        self._f = None
        self._writer = None
        self.filepath = None
        return filepath
