"""
Load a recording from the app's exported CSV zip file.

The zip contains a folder recording_<id>_csv/ with:
- session_info.csv: session metadata and sensor summary table
- sensor_<n>_<sensorId>_hr.csv, _rr.csv, _statistics.csv per sensor
"""

from __future__ import annotations

import csv
import io
import zipfile
from datetime import datetime
from typing import Any, Dict, List, Optional, Tuple

from .session import RecordingSession


def _parse_iso(s: str) -> Optional[datetime]:
    if not s or not s.strip():
        return None
    try:
        return datetime.fromisoformat(s.strip().replace("Z", "+00:00"))
    except Exception:
        return None


def _parse_session_info(content: str) -> Tuple[Dict[str, Any], List[Dict[str, Any]]]:
    """Parse session_info.csv into session metadata dict and list of sensor summary rows."""
    lines = content.splitlines()
    meta: Dict[str, Any] = {}
    sensors_table: List[Dict[str, Any]] = []
    in_sensors = False

    for line in lines:
        if not line.strip():
            continue
        if line.strip() == "Sensors":
            in_sensors = True
            continue
        if in_sensors:
            # Header: Sensor ID,Sensor Name,HR Samples,RR Samples,Avg HR,SDNN,RMSSD
            if "Sensor ID" in line and "Sensor Name" in line:
                continue
            row = list(csv.reader(io.StringIO(line)))
            if not row or not row[0]:
                continue
            row = row[0]
            # Expect at least 7 columns; sensor name may contain commas so use last 5 for numeric fields
            if len(row) >= 7:
                def _int(s: str) -> int:
                    try:
                        return int(s.strip())
                    except ValueError:
                        return 0

                def _float(s: str) -> float:
                    try:
                        return float(s.strip())
                    except ValueError:
                        return 0.0

                sensor_id = row[0].strip()
                # Last 5 columns: HR Samples, RR Samples, Avg HR, SDNN, RMSSD
                hr_samples = _int(row[-5])
                rr_samples = _int(row[-4])
                avg_hr = _float(row[-3])
                sdnn = _float(row[-2])
                rmssd = _float(row[-1])
                # Sensor name is everything between first and last 5 columns (handles commas in name)
                sensor_name = ",".join(c.strip() for c in row[1:-5]) if len(row) > 7 else row[1].strip()

                sensors_table.append({
                    "sensor_id": sensor_id,
                    "sensor_name": sensor_name,
                    "hr_samples": hr_samples,
                    "rr_samples": rr_samples,
                    "avg_hr": avg_hr,
                    "sdnn": sdnn,
                    "rmssd": rmssd,
                })
            continue
        # Key,Value (value may contain commas)
        idx = line.find(",")
        if idx < 0:
            continue
        key = line[:idx].strip()
        value = line[idx + 1:].strip()
        if key == "Session ID":
            meta["id"] = value
        elif key == "Recording Name":
            meta["name"] = value
        elif key == "Start Time":
            meta["startDate"] = _parse_iso(value)
        elif key == "End Time":
            meta["endDate"] = _parse_iso(value)
        elif key == "Duration (seconds)":
            try:
                meta["duration"] = float(value)
            except ValueError:
                meta["duration"] = 0.0
        elif key == "Number of Sensors":
            try:
                meta["sensorCount"] = int(value)
            except ValueError:
                meta["sensorCount"] = 0
        elif key == "Total Data Points":
            try:
                meta["totalDataPoints"] = int(value)
            except ValueError:
                meta["totalDataPoints"] = 0
        elif key == "Average Heart Rate (BPM)":
            try:
                meta["averageHeartRate"] = float(value)
            except ValueError:
                meta["averageHeartRate"] = 0.0
        elif key == "Average SDNN (ms)":
            try:
                meta["averageSDNN"] = float(value)
            except ValueError:
                meta["averageSDNN"] = 0.0
        elif key == "Average RMSSD (ms)":
            try:
                meta["averageRMSSD"] = float(value)
            except ValueError:
                meta["averageRMSSD"] = 0.0

    return meta, sensors_table


def _discover_sensors_from_zip(z: zipfile.ZipFile, prefix: str) -> List[Dict[str, Any]]:
    """If session_info has no sensor table, discover sensors from filenames sensor_<n>_<id>_hr.csv."""
    sensors_table: List[Dict[str, Any]] = []
    for name in z.namelist():
        if not name.startswith(prefix) or not name.endswith("_hr.csv"):
            continue
        # sensor_1_ABC123_hr.csv
        base = name[len(prefix):]
        if not base.startswith("sensor_"):
            continue
        parts = base.replace("_hr.csv", "").split("_")
        if len(parts) >= 3:
            try:
                idx = int(parts[1])
                sensor_id = "_".join(parts[2:])
                sensors_table.append({
                    "index": idx,
                    "sensor_id": sensor_id,
                    "sensor_name": sensor_id,
                    "hr_samples": 0,
                    "rr_samples": 0,
                    "avg_hr": 0.0,
                    "sdnn": 0.0,
                    "rmssd": 0.0,
                })
            except ValueError:
                pass
    sensors_table.sort(key=lambda r: r["index"])
    return sensors_table


def _read_hr_csv(content: str) -> List[Dict[str, Any]]:
    """Parse HR CSV: Timestamp, Unix Time, Monotonic Time, Heart Rate (BPM)."""
    lines = content.strip().splitlines()
    if len(lines) < 2:
        return []
    out = []
    for line in lines[1:]:
        parts = line.split(",")
        if len(parts) < 4:
            continue
        ts = _parse_iso(parts[0].strip())
        try:
            unix_time = float(parts[1].strip())
            mono = float(parts[2].strip())
            value = int(parts[3].strip())
        except (ValueError, IndexError):
            continue
        out.append({
            "timestamp": ts.isoformat() if ts else "",
            "value": value,
            "monotonicTimestamp": mono,
        })
    return out


def _read_rr_csv(content: str) -> List[Dict[str, Any]]:
    """Parse RR CSV: Timestamp, Unix Time, Monotonic Time, RR Interval (ms)."""
    lines = content.strip().splitlines()
    if len(lines) < 2:
        return []
    out = []
    for line in lines[1:]:
        parts = line.split(",")
        if len(parts) < 4:
            continue
        ts = _parse_iso(parts[0].strip())
        try:
            unix_time = float(parts[1].strip())
            mono = float(parts[2].strip())
            value = int(parts[3].strip())
        except (ValueError, IndexError):
            continue
        out.append({
            "timestamp": ts.isoformat() if ts else "",
            "value": value,
            "monotonicTimestamp": mono,
        })
    return out


def _read_statistics_csv(content: str) -> Dict[str, Any]:
    """Parse statistics CSV: Metric,Value rows."""
    lines = content.strip().splitlines()
    if len(lines) < 2:
        return {}
    stats = {}
    for line in lines[1:]:
        idx = line.find(",")
        if idx < 0:
            continue
        key = line[:idx].strip()
        value = line[idx + 1:].strip()
        if key == "Sensor ID":
            stats["sensorId"] = value
        elif key == "Sensor Name":
            stats["sensorName"] = value
        elif key == "Duration (seconds)":
            try:
                stats["duration"] = float(value)
            except ValueError:
                pass
        elif key == "Heart Rate Samples":
            try:
                stats["heartRateSamples"] = int(value)
            except ValueError:
                pass
        elif key == "RR Interval Samples":
            try:
                stats["rrIntervalSamples"] = int(value)
            except ValueError:
                pass
        elif key == "Min Heart Rate (BPM)":
            try:
                stats["minHeartRate"] = int(value)
            except ValueError:
                pass
        elif key == "Max Heart Rate (BPM)":
            try:
                stats["maxHeartRate"] = int(value)
            except ValueError:
                pass
        elif key == "Average Heart Rate (BPM)":
            try:
                stats["averageHeartRate"] = int(value)
            except ValueError:
                pass
        elif key == "SDNN (ms)":
            try:
                stats["sdnn"] = float(value)
            except ValueError:
                pass
        elif key == "RMSSD (ms)":
            try:
                stats["rmssd"] = float(value)
            except ValueError:
                pass
        elif key == "HRV Window":
            stats["hrvWindow"] = value
        elif key == "HRV Sample Count":
            try:
                stats["hrvSampleCount"] = int(value)
            except ValueError:
                pass
    return stats


def _find_folder_in_zip(z: zipfile.ZipFile) -> Optional[str]:
    """Return the top-level folder name (recording_*_csv) inside the zip."""
    names = z.namelist()
    for n in names:
        if "/" in n:
            top = n.split("/")[0]
            if top.endswith("_csv") and top.startswith("recording_"):
                return top
    return None


def load_from_zip(zip_path: str) -> RecordingSession:
    """
    Load a recording from the app's exported CSV zip file.

    The zip is produced by the iOS app via Export as CSV (or Share zip).
    Returns a RecordingSession that supports .sensors(), .plot(), .to_dataframes(), etc.

    :param zip_path: Path to the .zip file (e.g. downloaded from email or saved from the app).
    :return: RecordingSession with the same interface as get_recording() from the API.
    """
    with zipfile.ZipFile(zip_path, "r") as z:
        folder = _find_folder_in_zip(z)
        if not folder:
            raise ValueError(f"No recording_*_csv folder found in zip: {zip_path}")

        prefix = folder + "/"
        session_info_path = prefix + "session_info.csv"
        try:
            session_info_content = z.read(session_info_path).decode("utf-8")
        except KeyError:
            raise ValueError(f"Missing {session_info_path} in zip")

        meta, sensors_table = _parse_session_info(session_info_content)
        if not sensors_table:
            sensors_table = _discover_sensors_from_zip(z, prefix)
        meta.setdefault("id", "")
        meta.setdefault("name", meta.get("id", "Unknown"))

        sensor_recordings: List[Dict[str, Any]] = []
        for i, row in enumerate(sensors_table):
            sensor_id = row.get("sensor_id", "")
            sensor_name = row.get("sensor_name", sensor_id)
            file_prefix = f"{prefix}sensor_{i + 1}_{sensor_id}"

            hr_data: List[Dict[str, Any]] = []
            rr_data: List[Dict[str, Any]] = []
            statistics: Dict[str, Any] = {}

            hr_path = f"{file_prefix}_hr.csv"
            rr_path = f"{file_prefix}_rr.csv"
            stats_path = f"{file_prefix}_statistics.csv"
            try:
                hr_data = _read_hr_csv(z.read(hr_path).decode("utf-8"))
            except KeyError:
                pass
            try:
                rr_data = _read_rr_csv(z.read(rr_path).decode("utf-8"))
            except KeyError:
                pass
            try:
                statistics = _read_statistics_csv(z.read(stats_path).decode("utf-8"))
            except KeyError:
                statistics = {
                    "minHeartRate": min((p["value"] for p in hr_data), default=0),
                    "maxHeartRate": max((p["value"] for p in hr_data), default=0),
                    "averageHeartRate": int(row.get("avg_hr", 0)),
                    "sdnn": row.get("sdnn", 0),
                    "rmssd": row.get("rmssd", 0),
                    "hrvWindow": "",
                    "hrvSampleCount": 0,
                }

            sensor_recordings.append({
                "sensorId": sensor_id,
                "sensorName": sensor_name,
                "heartRateData": hr_data,
                "rrIntervalData": rr_data,
                "statistics": statistics,
            })

        meta["sensorRecordings"] = sensor_recordings
        return RecordingSession(meta)
