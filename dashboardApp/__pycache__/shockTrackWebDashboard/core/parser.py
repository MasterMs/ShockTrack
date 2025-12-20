from dataclasses import dataclass
from datetime import datetime
from typing import Any, List, Optional


@dataclass
class ParsedLine:
    timestamp: str
    raw: str
    values: Optional[List[float]]

    @property
    def is_valid(self) -> bool:
        return self.values is not None

    def to_csv_row(self) -> List[Any]:
        if self.is_valid:
            return [self.timestamp] + self.values  # type: ignore
        return [self.timestamp, self.raw]

    def to_ws_text(self) -> str:
        return self.raw


class LineParser:
    @staticmethod
    def parse_csv_6floats(line: str) -> Optional[List[float]]:
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
