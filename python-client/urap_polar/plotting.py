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
    """Plot HR, RR intervals, and accelerometer magnitude for all sensors.
    Columns: HR, RR, ACC (ACC column only shown when any sensor has accelerometer data)."""
    import matplotlib.dates as mdates
    import matplotlib.pyplot as plt

    data = _session_dict(session)
    frames = _session_to_frames(session)
    sensors = list(frames.keys())
    n_sensors = len(sensors)
    if n_sensors == 0:
        print("No sensor data to plot.")
        return

    has_acc = any(not frames[s].get("accelerometer", pd.DataFrame()).empty for s in sensors)
    n_cols = 3 if has_acc else 2
    col_w = 5 if has_acc else 6

    fig, axes = plt.subplots(n_sensors, n_cols, figsize=(col_w * n_cols, 4 * n_sensors), squeeze=False)
    fig.suptitle(f"Recording: {data.get('name', 'Unknown')}", fontsize=14)

    for i, sensor_id in enumerate(sensors):
        hr_df = frames[sensor_id]["heart_rate"].copy()
        rr_df = frames[sensor_id]["rr_intervals"].copy()
        acc_df = frames[sensor_id].get("accelerometer", pd.DataFrame())
        if not acc_df.empty:
            acc_df = acc_df.copy()

        if not hr_df.empty:
            hr_df["timestamp"] = pd.to_datetime(hr_df["timestamp"])
        if not rr_df.empty:
            rr_df["timestamp"] = pd.to_datetime(rr_df["timestamp"])
        if not acc_df.empty:
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
            if not acc_df.empty:
                ax_acc.fill_between(
                    acc_df["timestamp"], acc_df["magnitude"],
                    color="darkorange", alpha=0.4, linewidth=0,
                )
                ax_acc.plot(
                    acc_df["timestamp"], acc_df["magnitude"],
                    color="darkorange", linewidth=0.9, label=label,
                )
            ax_acc.set_ylabel("Magnitude (mG)")
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
    """Plot accelerometer magnitude (mG) for one sensor or all sensors (subplots).

    Each subplot shows the 1-second averaged, HPF 0.25 Hz + LPF 5 Hz filtered vector
    magnitude. A horizontal guide at 50 mG is drawn for light-activity reference.
    """
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
    fig.suptitle(f"Accelerometer magnitude — {data.get('name', 'Unknown')}", fontsize=14)

    for i, sid in enumerate(sensors):
        acc_df = frames[sid].get("accelerometer", pd.DataFrame())
        if not acc_df.empty:
            acc_df = acc_df.copy()
            acc_df["timestamp"] = pd.to_datetime(acc_df["timestamp"])

        label = sid
        for s in data.get("sensorRecordings", data.get("sensor_recordings", [])):
            if s.get("sensorId", s.get("sensor_id")) == sid:
                label = s.get("sensorName", s.get("sensor_name", sid))
                break

        ax = axes[i]
        if not acc_df.empty:
            ax.fill_between(
                acc_df["timestamp"], acc_df["magnitude"],
                color="darkorange", alpha=0.35, linewidth=0,
            )
            ax.plot(
                acc_df["timestamp"], acc_df["magnitude"],
                color="darkorange", linewidth=1.0, label=label,
            )
            # Light-activity reference line
            ax.axhline(50, color="gray", linewidth=0.8, linestyle="--", alpha=0.6, label="50 mG ref")
        else:
            ax.text(0.5, 0.5, "No accelerometer data", transform=ax.transAxes,
                    ha="center", va="center", color="gray")

        ax.set_ylabel("Magnitude (mG)")
        ax.set_title(label)
        ax.xaxis.set_major_formatter(mdates.DateFormatter("%H:%M:%S"))
        ax.xaxis.set_major_locator(mdates.AutoDateLocator())
        ax.grid(True, alpha=0.3)
        ax.legend(loc="upper right", fontsize=8)
        ax.tick_params(axis="x", rotation=15)

    plt.tight_layout()
    if save_path:
        plt.savefig(save_path)
    if show:
        plt.show()
    else:
        plt.close()


def plot_metabolic(
    result: Any,
    title: str = "Metabolic Rate",
    show: bool = True,
    save_path: Optional[str] = None,
) -> None:
    """Plot metabolic rate analysis from a MetabolicResult.

    Produces a two-panel figure:
      Top:    MET timeline coloured by intensity category
              (sedentary=grey, light=yellow-green, moderate=orange, vigorous=red)
      Bottom: Stacked bar/pie showing intensity time breakdown + summary stats.

    Parameters
    ----------
    result:
        MetabolicResult from estimate_metabolic_rate() or sensor.metabolic_rate().
    title:
        Figure title string.
    show:
        Call plt.show() when True.
    save_path:
        Optional file path to save the figure.
    """
    import matplotlib.dates as mdates
    import matplotlib.pyplot as plt
    import matplotlib.patches as mpatches

    if not result.epochs:
        print("No metabolic data to plot.")
        return

    COLORS = {
        "sedentary": "#9E9E9E",
        "light":     "#8BC34A",
        "moderate":  "#FF9800",
        "vigorous":  "#F44336",
    }
    LABELS = {
        "sedentary": f"Sedentary (<{1.5} METs)",
        "light":     f"Light (1.5–3.0 METs)",
        "moderate":  f"Moderate (3.0–6.0 METs)",
        "vigorous":  f"Vigorous (≥6.0 METs)",
    }

    timestamps = [e.timestamp for e in result.epochs]
    mets_vals  = [e.mets        for e in result.epochs]
    intensities = [e.intensity  for e in result.epochs]

    fig, (ax_met, ax_pie) = plt.subplots(
        1, 2,
        figsize=(14, 5),
        gridspec_kw={"width_ratios": [3, 1]},
    )
    fig.suptitle(title, fontsize=13)

    # --- MET timeline ---
    use_datetime = hasattr(timestamps[0], "year")

    for i in range(len(timestamps) - 1):
        x0 = timestamps[i]
        x1 = timestamps[i + 1]
        y  = mets_vals[i]
        c  = COLORS[intensities[i]]
        ax_met.fill_between([x0, x1], [y, y], alpha=0.7, color=c, linewidth=0, step="post")
        ax_met.step([x0, x1], [y, y], color=c, linewidth=1.2, where="post")

    # Last epoch
    if timestamps:
        ax_met.axhline(mets_vals[-1], color=COLORS[intensities[-1]], linewidth=0.5, linestyle=":")

    # Threshold lines
    for thr, label in [(1.5, "Sedentary / Light"), (3.0, "Light / Moderate"), (6.0, "Moderate / Vigorous")]:
        ax_met.axhline(thr, color="black", linewidth=0.6, linestyle="--", alpha=0.35)
        ax_met.text(timestamps[0], thr + 0.1, label, fontsize=6.5, color="black", alpha=0.5)

    ax_met.set_ylabel("METs")
    ax_met.set_ylim(bottom=0)
    ax_met.grid(True, alpha=0.2)
    if use_datetime:
        ax_met.xaxis.set_major_formatter(mdates.DateFormatter("%H:%M:%S"))
        ax_met.xaxis.set_major_locator(mdates.AutoDateLocator())
        ax_met.tick_params(axis="x", rotation=15)

    # Legend patches
    legend_patches = [
        mpatches.Patch(color=COLORS[k], label=LABELS[k])
        for k in ("sedentary", "light", "moderate", "vigorous")
    ]
    ax_met.legend(handles=legend_patches, loc="upper right", fontsize=7.5)

    # --- Summary pie chart ---
    bdown = result.intensity_breakdown()
    pie_labels = []
    pie_sizes  = []
    pie_colors = []
    for cat in ("sedentary", "light", "moderate", "vigorous"):
        frac = bdown[cat]
        if frac > 0:
            mins = frac * result.total_duration_seconds / 60
            pie_labels.append(f"{cat.capitalize()}\n{mins:.1f} min")
            pie_sizes.append(frac)
            pie_colors.append(COLORS[cat])

    if pie_sizes:
        ax_pie.pie(
            pie_sizes, labels=pie_labels, colors=pie_colors,
            autopct="%1.0f%%", startangle=90,
            textprops={"fontsize": 8},
            wedgeprops={"linewidth": 0.5, "edgecolor": "white"},
        )

    # Stat text box
    stats_lines = [
        f"Mean METs:  {result.mean_mets:.2f}",
        f"Duration:   {result.total_duration_seconds/60:.1f} min",
        f"Method:     {result.method}",
    ]
    if result.total_kcal is not None:
        stats_lines.insert(1, f"Total kcal: {result.total_kcal:.0f}")
    ax_pie.set_title("\n".join(stats_lines), fontsize=8, loc="center", pad=2)

    plt.tight_layout()
    if save_path:
        plt.savefig(save_path, bbox_inches="tight")
    if show:
        plt.show()
    else:
        plt.close()


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
