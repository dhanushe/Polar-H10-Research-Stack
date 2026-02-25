"""
URAP Polar H10 Python client library.

Connect to the iOS app API and work with recording sessions: list, fetch,
inspect sensors and data points, compute stats, and plot.
"""

from __future__ import annotations

import warnings
warnings.filterwarnings("ignore", message=".*urllib3 v2 only supports OpenSSL.*")

from .client import get_recording, list_recordings
from .session import (
    HeartRatePoint,
    RRIntervalPoint,
    RecordingSession,
    RecordingSummary,
    SensorData,
    to_dataframes,
)
from .plotting import plot_heart_rate, plot_rr_intervals, plot_session

__all__ = [
    "get_recording",
    "list_recordings",
    "to_dataframes",
    "RecordingSession",
    "RecordingSummary",
    "SensorData",
    "HeartRatePoint",
    "RRIntervalPoint",
    "plot_session",
    "plot_heart_rate",
    "plot_rr_intervals",
]
