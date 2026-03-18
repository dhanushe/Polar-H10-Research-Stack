"""
Plotting for URAP Polar H10 recording sessions.
Suppresses matplotlib font cache message.
"""

from __future__ import annotations

import logging
from typing import Any, Dict, Optional, Union

# Suppress "Matplotlib is building the font cache" message
logging.getLogger("matplotlib.font_manager").setLevel(logging.WARNING)

try:
    import pandas as pd  # type: ignore[import]
except ImportError:
    pd = None  # type: ignore[assignment]


def _session_to_frames(session: Union[Any, Dict[str, Any]]) -> Dict[str, Dict[str, Any]]:
    from .session import RecordingSession, to_dataframes
    if hasattr(session, "to_dataframes"):
        return session.to_dataframes()
    return to_dataframes(session)


def _session_dict(session: Union[Any, Dict[str, Any]]) -> Dict[str, Any]:
    if isinstance(session, dict):
        return session
    return getattr(session, "raw", session._data)


def plot_session(
    session: Union[Any, Dict[str, Any]],
    show: bool = True,
    save_path: Optional[str] = None,
) -> None:
    """Plot heart rate, RR intervals, and accelerometer for all sensors.

    Layout: one row per sensor. Columns: HR, RR, and optionally ACC (if data exists).
    """
    import matplotlib.dates as mdates
    import matplotlib.pyplot as plt

    data = _session_dict(session)
    frames = _session_to_frames(session)
    sensors = list(frames.keys())
    n_sensors = len(sensors)
    if n_sensors == 0:
        print("No sensor data to plot.")
        return

    # Determine if any sensor has accelerometer data
    has_acc = any("accelerometer" in frames[sid] for sid in sensors)
    n_cols = 3 if has_acc else 2

    fig, axes = plt.subplots(n_sensors, n_cols, figsize=(5 * n_cols, 4 * n_sensors), squeeze=False)
    fig.suptitle(f"Recording: {data.get('name', 'Unknown')}", fontsize=14)

    for i, sensor_id in enumerate(sensors):
        hr_df = frames[sensor_id]["heart_rate"].copy()
        rr_df = frames[sensor_id]["rr_intervals"].copy()
        acc_df = frames[sensor_id].get("accelerometer")
        if acc_df is not None:
            acc_df = acc_df.copy()

        if not hr_df.empty:
            hr_df["timestamp"] = pd.to_datetime(hr_df["timestamp"])
        if not rr_df.empty:
            rr_df["timestamp"] = pd.to_datetime(rr_df["timestamp"])
        if acc_df is not None and not acc_df.empty:
            acc_df["timestamp"] = pd.to_datetime(acc_df["timestamp"])

        label = sensor_id
        for s in data.get("sensorRecordings", data.get("sensor_recordings", [])):
            sid = s.get("sensorId", s.get("sensor_id", ""))
            if sid == sensor_id:
                label = s.get("sensorName", s.get("sensor_name", sensor_id))
                break

        ax_hr, ax_rr = axes[i, 0], axes[i, 1]

        if not hr_df.empty:
            ax_hr.plot(hr_df["timestamp"], hr_df["value"], color="coral", linewidth=0.8, label=label)
        ax_hr.set_ylabel("Heart rate (BPM)")
        ax_hr.set_title(f"Heart rate — {label}")
        ax_hr.xaxis.set_major_formatter(mdates.DateFormatter("%H:%M:%S"))
        ax_hr.xaxis.set_major_locator(mdates.AutoDateLocator())
        ax_hr.grid(True, alpha=0.3)
        ax_hr.legend(loc="upper right", fontsize=8)

        if not rr_df.empty:
            ax_rr.plot(rr_df["timestamp"], rr_df["value"], color="steelblue", linewidth=0.8, label=label)
        ax_rr.set_ylabel("RR interval (ms)")
        ax_rr.set_title(f"RR intervals — {label}")
        ax_rr.xaxis.set_major_formatter(mdates.DateFormatter("%H:%M:%S"))
        ax_rr.xaxis.set_major_locator(mdates.AutoDateLocator())
        ax_rr.grid(True, alpha=0.3)
        ax_rr.legend(loc="upper right", fontsize=8)

        if has_acc:
            ax_acc = axes[i, 2]
            if acc_df is not None and not acc_df.empty:
                ax_acc.plot(acc_df["timestamp"], acc_df["x"], color="red", linewidth=0.5, alpha=0.7, label="X")
                ax_acc.plot(acc_df["timestamp"], acc_df["y"], color="green", linewidth=0.5, alpha=0.7, label="Y")
                ax_acc.plot(acc_df["timestamp"], acc_df["z"], color="blue", linewidth=0.5, alpha=0.7, label="Z")
            ax_acc.set_ylabel("Acceleration (mG)")
            ax_acc.set_title(f"Accelerometer — {label}")
            ax_acc.xaxis.set_major_formatter(mdates.DateFormatter("%H:%M:%S"))
            ax_acc.xaxis.set_major_locator(mdates.AutoDateLocator())
            ax_acc.grid(True, alpha=0.3)
            ax_acc.legend(loc="upper right", fontsize=8)

    for ax in axes.flat:
        ax.tick_params(axis="x", rotation=15)
    plt.tight_layout()

    if save_path:
        plt.savefig(save_path)
    if show:
        plt.show()
    else:
        plt.close()


def plot_heart_rate(
    session: Union[Any, Dict[str, Any]],
    sensor_id: Optional[str] = None,
    show: bool = True,
    save_path: Optional[str] = None,
) -> None:
    """Plot heart rate for one sensor or all sensors (subplots)."""
    import matplotlib.dates as mdates
    import matplotlib.pyplot as plt

    data = _session_dict(session)
    frames = _session_to_frames(session)
    if sensor_id:
        sensors = [sensor_id] if sensor_id in frames else []
    else:
        sensors = list(frames.keys())
    if not sensors:
        print("No sensor data to plot.")
        return

    n = len(sensors)
    fig, axes = plt.subplots(n, 1, figsize=(12, 4 * n), squeeze=(n == 1))
    if n == 1:
        axes = [axes]
    fig.suptitle(f"Heart rate — {data.get('name', 'Unknown')}", fontsize=14)

    for i, sid in enumerate(sensors):
        hr_df = frames[sid]["heart_rate"].copy()
        if hr_df.empty:
            continue
        hr_df["timestamp"] = pd.to_datetime(hr_df["timestamp"])
        label = sid
        for s in data.get("sensorRecordings", data.get("sensor_recordings", [])):
            if s.get("sensorId", s.get("sensor_id")) == sid:
                label = s.get("sensorName", s.get("sensor_name", sid))
                break
        axes[i].plot(hr_df["timestamp"], hr_df["value"], color="coral", linewidth=0.8)
        axes[i].set_ylabel("Heart rate (BPM)")
        axes[i].set_title(label)
        axes[i].xaxis.set_major_formatter(mdates.DateFormatter("%H:%M:%S"))
        axes[i].grid(True, alpha=0.3)
        axes[i].tick_params(axis="x", rotation=15)
    plt.tight_layout()
    if save_path:
        plt.savefig(save_path)
    if show:
        plt.show()


def plot_accelerometer(
    session: Union[Any, Dict[str, Any]],
    sensor_id: Optional[str] = None,
    show: bool = True,
    save_path: Optional[str] = None,
) -> None:
    """Plot accelerometer X/Y/Z for one sensor or all sensors (subplots)."""
    import matplotlib.dates as mdates
    import matplotlib.pyplot as plt

    data = _session_dict(session)
    frames = _session_to_frames(session)
    if sensor_id:
        sensors = [sensor_id] if sensor_id in frames else []
    else:
        sensors = [sid for sid in frames if "accelerometer" in frames[sid]]
    if not sensors:
        print("No accelerometer data to plot.")
        return

    n = len(sensors)
    fig, axes = plt.subplots(n, 1, figsize=(12, 4 * n), squeeze=(n == 1))
    if n == 1:
        axes = [axes]
    fig.suptitle(f"Accelerometer — {data.get('name', 'Unknown')}", fontsize=14)

    for i, sid in enumerate(sensors):
        acc_df = frames[sid].get("accelerometer")
        if acc_df is None or acc_df.empty:
            continue
        acc_df = acc_df.copy()
        acc_df["timestamp"] = pd.to_datetime(acc_df["timestamp"])
        label = sid
        for s in data.get("sensorRecordings", data.get("sensor_recordings", [])):
            if s.get("sensorId", s.get("sensor_id")) == sid:
                label = s.get("sensorName", s.get("sensor_name", sid))
                break
        axes[i].plot(acc_df["timestamp"], acc_df["x"], color="red", linewidth=0.5, alpha=0.7, label="X")
        axes[i].plot(acc_df["timestamp"], acc_df["y"], color="green", linewidth=0.5, alpha=0.7, label="Y")
        axes[i].plot(acc_df["timestamp"], acc_df["z"], color="blue", linewidth=0.5, alpha=0.7, label="Z")
        axes[i].set_ylabel("Acceleration (mG)")
        axes[i].set_title(label)
        axes[i].xaxis.set_major_formatter(mdates.DateFormatter("%H:%M:%S"))
        axes[i].grid(True, alpha=0.3)
        axes[i].legend(loc="upper right", fontsize=8)
        axes[i].tick_params(axis="x", rotation=15)
    plt.tight_layout()
    if save_path:
        plt.savefig(save_path)
    if show:
        plt.show()


def plot_rr_intervals(
    session: Union[Any, Dict[str, Any]],
    sensor_id: Optional[str] = None,
    show: bool = True,
    save_path: Optional[str] = None,
) -> None:
    """Plot RR intervals for one sensor or all sensors (subplots)."""
    import matplotlib.dates as mdates
    import matplotlib.pyplot as plt

    data = _session_dict(session)
    frames = _session_to_frames(session)
    if sensor_id:
        sensors = [sensor_id] if sensor_id in frames else []
    else:
        sensors = list(frames.keys())
    if not sensors:
        print("No sensor data to plot.")
        return

    n = len(sensors)
    fig, axes = plt.subplots(n, 1, figsize=(12, 4 * n), squeeze=(n == 1))
    if n == 1:
        axes = [axes]
    fig.suptitle(f"RR intervals — {data.get('name', 'Unknown')}", fontsize=14)

    for i, sid in enumerate(sensors):
        rr_df = frames[sid]["rr_intervals"].copy()
        if rr_df.empty:
            continue
        rr_df["timestamp"] = pd.to_datetime(rr_df["timestamp"])
        label = sid
        for s in data.get("sensorRecordings", data.get("sensor_recordings", [])):
            if s.get("sensorId", s.get("sensor_id")) == sid:
                label = s.get("sensorName", s.get("sensor_name", sid))
                break
        axes[i].plot(rr_df["timestamp"], rr_df["value"], color="steelblue", linewidth=0.8)
        axes[i].set_ylabel("RR interval (ms)")
        axes[i].set_title(label)
        axes[i].xaxis.set_major_formatter(mdates.DateFormatter("%H:%M:%S"))
        axes[i].grid(True, alpha=0.3)
        axes[i].tick_params(axis="x", rotation=15)
    plt.tight_layout()
    if save_path:
        plt.savefig(save_path)
    if show:
        plt.show()
