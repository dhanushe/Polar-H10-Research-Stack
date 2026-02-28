#!/usr/bin/env python3
"""
Verify that the Python zip loader correctly parses the zip format produced by the iOS app.

Creates a minimal zip with the exact structure and CSV format from RecordingsStorageManager
and SensorRecording, then runs load_from_zip and checks session/sensor data.

Run from python-client directory:
  python scripts/verify_zip_parsing.py
"""

from __future__ import annotations

import io
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

# Import zip_loader without pulling in client (requests); load session first.
import importlib.util
pkg_dir = Path(__file__).resolve().parent.parent / "urap_polar"
session_path = pkg_dir / "session.py"
zip_loader_path = pkg_dir / "zip_loader.py"
spec_session = importlib.util.spec_from_file_location("urap_polar.session", session_path)
spec_zip = importlib.util.spec_from_file_location("urap_polar.zip_loader", zip_loader_path)
session_mod = importlib.util.module_from_spec(spec_session)
zip_loader_mod = importlib.util.module_from_spec(spec_zip)
import sys as _sys
_sys.modules["urap_polar.session"] = session_mod
spec_session.loader.exec_module(session_mod)
spec_zip.loader.exec_module(zip_loader_mod)
load_from_zip = zip_loader_mod.load_from_zip


def make_ios_style_zip() -> bytes:
    """Build an in-memory zip that matches the iOS app export format."""
    buffer = io.BytesIO()
    folder = "recording_testid123_csv"
    prefix = folder + "/"

    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as z:
        # session_info.csv (same format as RecordingsStorageManager.createSessionInfoCSV)
        session_info = """Recording Information

Session ID,testid123
Recording Name,Test Recording
Start Time,2024-05-15T19:30:00.000Z
End Time,2024-05-15T19:35:00.000Z
Duration (seconds),300.0
Number of Sensors,1
Total Data Points,120
Average Heart Rate (BPM),72.5
Average SDNN (ms),45.20
Average RMSSD (ms),38.70

Sensors
Sensor ID,Sensor Name,HR Samples,RR Samples,Avg HR,SDNN,RMSSD
ABC123,Polar H10 ABC123,60,60,72,45.20,38.70
"""
        z.writestr(prefix + "session_info.csv", session_info.encode("utf-8"))

        # sensor_1_ABC123_hr.csv (same format as SensorRecording.heartRateCSV)
        hr_csv = """Timestamp,Unix Time,Monotonic Time,Heart Rate (BPM)
2024-05-15T19:30:00.100Z,1715796600.1,100.1,70
2024-05-15T19:30:01.100Z,1715796601.1,101.1,72
"""
        z.writestr(prefix + "sensor_1_ABC123_hr.csv", hr_csv.encode("utf-8"))

        # sensor_1_ABC123_rr.csv (same format as SensorRecording.rrIntervalCSV)
        rr_csv = """Timestamp,Unix Time,Monotonic Time,RR Interval (ms)
2024-05-15T19:30:00.150Z,1715796600.15,100.15,820
2024-05-15T19:30:01.150Z,1715796601.15,101.15,815
"""
        z.writestr(prefix + "sensor_1_ABC123_rr.csv", rr_csv.encode("utf-8"))

        # sensor_1_ABC123_statistics.csv (same format as SensorRecording.statisticsCSV)
        stats_csv = """Metric,Value
Sensor ID,ABC123
Sensor Name,Polar H10 ABC123
Duration (seconds),300.0
Heart Rate Samples,60
RR Interval Samples,60
Min Heart Rate (BPM),65
Max Heart Rate (BPM),85
Average Heart Rate (BPM),72
SDNN (ms),45.20
RMSSD (ms),38.70
HRV Window,5 Minutes
HRV Sample Count,60
"""
        z.writestr(prefix + "sensor_1_ABC123_statistics.csv", stats_csv.encode("utf-8"))

    buffer.seek(0)
    return buffer.getvalue()


def main() -> None:
    zip_bytes = make_ios_style_zip()
    zip_path = Path(__file__).resolve().parent.parent / "urap_polar" / "_verify_zip_test.zip"
    zip_path.write_bytes(zip_bytes)

    try:
        session = load_from_zip(str(zip_path))
    except Exception as e:
        zip_path.unlink(missing_ok=True)
        print(f"FAIL: load_from_zip raised: {e}")
        sys.exit(1)

    # Session-level checks
    assert session.id == "testid123", f"session.id: got {session.id}"
    assert session.name == "Test Recording", f"session.name: got {session.name}"
    assert session.sensor_count == 1, f"sensor_count: got {session.sensor_count}"
    assert session.duration_seconds > 0, f"duration_seconds: got {session.duration_seconds}"
    assert session.average_heart_rate > 0, f"average_heart_rate: got {session.average_heart_rate}"

    # Sensor-level checks
    sensors = session.sensors()
    assert len(sensors) == 1, f"sensors(): got {len(sensors)}"
    s = sensors[0]
    assert s.sensor_id == "ABC123", f"sensor_id: got {s.sensor_id}"
    assert "Polar" in s.sensor_name, f"sensor_name: got {s.sensor_name}"
    assert len(s.heart_rate_points()) == 2, f"heart_rate_points: got {len(s.heart_rate_points())}"
    assert len(s.rr_points()) == 2, f"rr_points: got {len(s.rr_points())}"
    assert s.heart_rate_avg == 72, f"heart_rate_avg: got {s.heart_rate_avg}"
    assert s.sdnn == 45.2, f"sdnn: got {s.sdnn}"
    assert s.rmssd == 38.7, f"rmssd: got {s.rmssd}"

    # Data point values
    hr_pts = s.heart_rate_points()
    assert hr_pts[0].value == 70 and hr_pts[1].value == 72
    rr_pts = s.rr_points()
    assert rr_pts[0].value == 820 and rr_pts[1].value == 815

    zip_path.unlink(missing_ok=True)
    print("OK: Zip format matches iOS export; Python parsing verified.")


if __name__ == "__main__":
    main()
