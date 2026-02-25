"""
Session and sensor data models for URAP Polar H10 recordings.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Dict, List, Optional, Union

# Optional pandas for to_dataframes / dataframe methods
try:
    import pandas as pd  # type: ignore[import]
except ImportError:
    pd = None  # type: ignore[assignment]


def _parse_iso(s: Any) -> Optional[datetime]:
    if s is None:
        return None
    if isinstance(s, datetime):
        return s
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except Exception:
        return None


@dataclass(frozen=True)
class HeartRatePoint:
    """Single heart rate sample: timestamp, value (BPM), optional monotonic time."""

    timestamp: datetime
    value: int
    monotonic_timestamp: float = 0.0


@dataclass(frozen=True)
class RRIntervalPoint:
    """Single RR interval sample: timestamp, value (ms), optional monotonic time."""

    timestamp: datetime
    value: int
    monotonic_timestamp: float = 0.0


def _point_from_hr(d: Dict[str, Any]) -> HeartRatePoint:
    ts = _parse_iso(d.get("timestamp")) or datetime.min
    return HeartRatePoint(
        timestamp=ts,
        value=int(d.get("value", 0)),
        monotonic_timestamp=float(d.get("monotonicTimestamp", 0)),
    )


def _point_from_rr(d: Dict[str, Any]) -> RRIntervalPoint:
    ts = _parse_iso(d.get("timestamp")) or datetime.min
    return RRIntervalPoint(
        timestamp=ts,
        value=int(d.get("value", 0)),
        monotonic_timestamp=float(d.get("monotonicTimestamp", 0)),
    )


@dataclass
class RecordingSummary:
    """Summary of a recording from GET /recordings."""

    id: str
    name: str
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    duration_seconds: float = 0.0
    sensor_count: int = 0
    average_heart_rate: float = 0.0
    average_sdnn: float = 0.0
    average_rmssd: float = 0.0

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> RecordingSummary:
        return cls(
            id=data.get("id", ""),
            name=data.get("name", ""),
            start_date=_parse_iso(data.get("startDate") or data.get("start_date")),
            end_date=_parse_iso(data.get("endDate") or data.get("end_date")),
            duration_seconds=float(data.get("duration", data.get("duration_seconds", 0))),
            sensor_count=int(data.get("sensorCount", data.get("sensor_count", 0))),
            average_heart_rate=float(
                data.get("averageHeartRate", data.get("average_heart_rate", 0))
            ),
            average_sdnn=float(data.get("averageSDNN", data.get("average_sdnn", 0))),
            average_rmssd=float(data.get("averageRMSSD", data.get("average_rmssd", 0))),
        )


@dataclass
class SensorData:
    """Data from one sensor in a recording session."""

    _data: Dict[str, Any] = field(repr=False)
    _hr_points: List[HeartRatePoint] = field(default_factory=list, repr=False)
    _rr_points: List[RRIntervalPoint] = field(default_factory=list, repr=False)

    def __post_init__(self) -> None:
        for d in self._data.get("heartRateData", []):
            self._hr_points.append(_point_from_hr(d))
        for d in self._data.get("rrIntervalData", []):
            self._rr_points.append(_point_from_rr(d))

    @property
    def sensor_id(self) -> str:
        return self._data.get("sensorId", self._data.get("sensor_id", ""))

    @property
    def sensor_name(self) -> str:
        return self._data.get("sensorName", self._data.get("sensor_name", ""))

    @property
    def duration_seconds(self) -> float:
        if not self._hr_points and not self._rr_points:
            return 0.0
        times = [p.timestamp for p in self._hr_points] + [p.timestamp for p in self._rr_points]
        if not times:
            return 0.0
        return max(times).timestamp() - min(times).timestamp()

    @property
    def data_point_count(self) -> int:
        return len(self._hr_points) + len(self._rr_points)

    # Statistics from API
    @property
    def heart_rate_min(self) -> int:
        s = self._data.get("statistics", {})
        return int(s.get("minHeartRate", s.get("min_heart_rate", 0)))

    @property
    def heart_rate_max(self) -> int:
        s = self._data.get("statistics", {})
        return int(s.get("maxHeartRate", s.get("max_heart_rate", 0)))

    @property
    def heart_rate_avg(self) -> int:
        s = self._data.get("statistics", {})
        return int(s.get("averageHeartRate", s.get("average_heart_rate", 0)))

    @property
    def sdnn(self) -> float:
        s = self._data.get("statistics", {})
        return float(s.get("sdnn", 0))

    @property
    def rmssd(self) -> float:
        s = self._data.get("statistics", {})
        return float(s.get("rmssd", 0))

    @property
    def hrv_window(self) -> str:
        s = self._data.get("statistics", {})
        return s.get("hrvWindow", s.get("hrv_window", ""))

    @property
    def hrv_sample_count(self) -> int:
        s = self._data.get("statistics", {})
        return int(s.get("hrvSampleCount", s.get("hrv_sample_count", 0)))

    def rr_min(self) -> int:
        if not self._rr_points:
            return 0
        return min(p.value for p in self._rr_points)

    def rr_max(self) -> int:
        if not self._rr_points:
            return 0
        return max(p.value for p in self._rr_points)

    def rr_avg(self) -> float:
        if not self._rr_points:
            return 0.0
        return sum(p.value for p in self._rr_points) / len(self._rr_points)

    def heart_rate_points(self) -> List[HeartRatePoint]:
        return list(self._hr_points)

    def rr_points(self) -> List[RRIntervalPoint]:
        return list(self._rr_points)

    def get_heart_rate_point(self, i: int) -> Optional[HeartRatePoint]:
        if 0 <= i < len(self._hr_points):
            return self._hr_points[i]
        return None

    def get_rr_point(self, i: int) -> Optional[RRIntervalPoint]:
        if 0 <= i < len(self._rr_points):
            return self._rr_points[i]
        return None

    def heart_rate_dataframe(self) -> Any:
        if pd is None:
            raise ImportError("pandas is required for heart_rate_dataframe()")
        rows = [
            {
                "timestamp": p.timestamp,
                "value": p.value,
                "monotonicTimestamp": p.monotonic_timestamp,
            }
            for p in self._hr_points
        ]
        return pd.DataFrame(rows)

    def rr_dataframe(self) -> Any:
        if pd is None:
            raise ImportError("pandas is required for rr_dataframe()")
        rows = [
            {
                "timestamp": p.timestamp,
                "value": p.value,
                "monotonicTimestamp": p.monotonic_timestamp,
            }
            for p in self._rr_points
        ]
        return pd.DataFrame(rows)


class RecordingSession:
    """Full recording session with all sensor data and methods."""

    def __init__(self, data: Dict[str, Any]) -> None:
        self._data = data
        self._sensors: List[SensorData] = [
            SensorData(s) for s in data.get("sensorRecordings", data.get("sensor_recordings", []))
        ]

    @property
    def raw(self) -> Dict[str, Any]:
        """Raw JSON dict for backward compatibility."""
        return self._data

    @property
    def id(self) -> str:
        return self._data.get("id", "")

    @property
    def name(self) -> str:
        return self._data.get("name", "")

    @property
    def start_date(self) -> Optional[datetime]:
        return _parse_iso(
            self._data.get("startDate") or self._data.get("start_date")
        )

    @property
    def end_date(self) -> Optional[datetime]:
        return _parse_iso(
            self._data.get("endDate") or self._data.get("end_date")
        )

    @property
    def duration_seconds(self) -> float:
        start = self.start_date
        end = self.end_date
        if start and end:
            return (end - start).total_seconds()
        return 0.0

    @property
    def sensor_count(self) -> int:
        return len(self._sensors)

    @property
    def total_data_points(self) -> int:
        return sum(s.data_point_count for s in self._sensors)

    @property
    def average_heart_rate(self) -> float:
        if not self._sensors:
            return 0.0
        return sum(s.heart_rate_avg for s in self._sensors) / len(self._sensors)

    @property
    def average_sdnn(self) -> float:
        valid = [s.sdnn for s in self._sensors if s.sdnn > 0]
        return sum(valid) / len(valid) if valid else 0.0

    @property
    def average_rmssd(self) -> float:
        valid = [s.rmssd for s in self._sensors if s.rmssd > 0]
        return sum(valid) / len(valid) if valid else 0.0

    def sensors(self) -> List[SensorData]:
        return list(self._sensors)

    def sensor(self, sensor_id: str) -> Optional[SensorData]:
        for s in self._sensors:
            if s.sensor_id == sensor_id:
                return s
        return None

    def to_dataframes(
        self,
    ) -> Dict[str, Dict[str, Any]]:
        if pd is None:
            raise ImportError("pandas is required for to_dataframes()")
        out: Dict[str, Dict[str, Any]] = {}
        for s in self._sensors:
            out[s.sensor_id] = {
                "heart_rate": s.heart_rate_dataframe(),
                "rr_intervals": s.rr_dataframe(),
            }
        return out

    def plot(
        self,
        show: bool = True,
        save_path: Optional[str] = None,
    ) -> None:
        from .plotting import plot_session
        plot_session(self, show=show, save_path=save_path)


def to_dataframes(session: Union[RecordingSession, Dict[str, Any]]) -> Dict[str, Dict[str, Any]]:
    """Convert a recording session to pandas DataFrames. Accepts RecordingSession or raw dict."""
    if isinstance(session, RecordingSession):
        return session.to_dataframes()
    return RecordingSession(session).to_dataframes()
