from dataclasses import dataclass
from datetime import datetime
from typing import Any, List, Optional


@dataclass
class ParsedLine:
    """Represents a parsed line from the sensor input."""
    timestamp: str
    raw: str
    values: Optional[List[float]]  # 6 floats if valid, else None

    @property
    def is_valid(self) -> bool:
        """Whether the parsed line contains valid float values."""
        return self.values is not None

    def to_csv_row(self) -> List[Any]:
        """Format for CSV logging."""
        if self.is_valid:
            return [self.timestamp] + self.values  # type: ignore
        return [self.timestamp, self.raw]

    def to_ws_text(self) -> str:
        """Format for WebSocket transmission."""
        return self.raw


class LineParser:
    """Turns a raw CSV-ish line into floats (or None)."""

    @staticmethod
    def parse_csv_6floats(line: str) -> Optional[List[float]]:
        """Parse a CSV line into 6 floats, or return None if invalid.
        1. Splits by commas whitespace
        2. Strips whitespace
        3. Checks for exactly 6 parts
        4. Tries to convert each part to float
        5. Returns list of floats or None if any part fails to convert to float.
        """
        parts = [p.strip() for p in line.split(",")]
        if len(parts) != 6:
            return None
        try:
            return [float(p) for p in parts]
        except ValueError:
            return None

    def parse(self, raw: str) -> ParsedLine:
        ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
        values = self.parse_csv_6floats(raw)
        return ParsedLine(timestamp=ts, raw=raw, values=values)
