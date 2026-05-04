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
    AccelerometerPoint,
    HeartRatePoint,
    RRIntervalPoint,
    RecordingSession,
    RecordingSummary,
    SensorData,
    to_dataframes,
)
from .plotting import plot_accelerometer, plot_heart_rate, plot_metabolic, plot_rr_intervals, plot_session
from .zip_loader import load_from_zip
from .metabolic import (
    ActivityEpoch,
    MetabolicResult,
    classify_intensity,
    estimate_from_accelerometer,
    estimate_from_heart_rate,
    estimate_flex_hr,
    estimate_metabolic_rate,
    magnitude_to_mets,
)

__all__ = [
    # HTTP client
    "get_recording",
    "list_recordings",
    # Data loading
    "load_from_zip",
    "to_dataframes",
    # Session models
    "RecordingSession",
    "RecordingSummary",
    "SensorData",
    "AccelerometerPoint",
    "HeartRatePoint",
    "RRIntervalPoint",
    # Plotting
    "plot_session",
    "plot_accelerometer",
    "plot_heart_rate",
    "plot_rr_intervals",
    "plot_metabolic",
    # Metabolic rate estimation
    "estimate_metabolic_rate",
    "estimate_from_accelerometer",
    "estimate_from_heart_rate",
    "estimate_flex_hr",
    "magnitude_to_mets",
    "classify_intensity",
    "MetabolicResult",
    "ActivityEpoch",
]
