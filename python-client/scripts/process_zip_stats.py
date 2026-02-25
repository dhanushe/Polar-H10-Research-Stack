#!/usr/bin/env python3
"""
Generate per-sensor statistics from an exported CSV zip file.

Usage (from python-client directory):
  python scripts/process_zip_stats.py path/to/recording_xxx_csv.zip

  Optional: write a report to a file
  python scripts/process_zip_stats.py path/to/recording.zip --output report.csv

The zip file is the one produced by the iOS app via Export as CSV or Share zip.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Allow importing urap_polar when run from python-client
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import urap_polar


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Print per-sensor statistics for a recording from an exported CSV zip."
    )
    parser.add_argument(
        "zip_path",
        type=str,
        help="Path to the .zip file (e.g. from the app's Export as CSV or Share zip)",
    )
    parser.add_argument(
        "--output", "-o",
        type=str,
        default=None,
        help="Optional path to write a CSV report (one row per sensor)",
    )
    args = parser.parse_args()

    zip_path = Path(args.zip_path)
    if not zip_path.exists():
        print(f"Error: file not found: {zip_path}", file=sys.stderr)
        sys.exit(1)

    try:
        session = urap_polar.load_from_zip(str(zip_path))
    except Exception as e:
        print(f"Error loading zip: {e}", file=sys.stderr)
        sys.exit(1)

    # Session summary
    print(f"Recording: {session.name}")
    print(f"ID: {session.id}")
    print(f"Duration: {session.duration_seconds:.1f} s")
    print(f"Sensors: {session.sensor_count}")
    print(f"Total data points: {session.total_data_points}")
    print(f"Average HR (session): {session.average_heart_rate:.1f} BPM")
    print(f"Average SDNN: {session.average_sdnn:.2f} ms")
    print(f"Average RMSSD: {session.average_rmssd:.2f} ms")
    print()

    rows = []
    for s in session.sensors():
        hr_min, hr_max = s.heart_rate_min, s.heart_rate_max
        rr_min, rr_max = s.rr_min(), s.rr_max()
        rr_avg = s.rr_avg()
        print(f"Sensor: {s.sensor_name} (id: {s.sensor_id})")
        print(f"  Duration: {s.duration_seconds:.1f} s")
        print(f"  Data points: {s.data_point_count} (HR: {len(s.heart_rate_points())}, RR: {len(s.rr_points())})")
        print(f"  Heart rate: min={hr_min} max={hr_max} avg={s.heart_rate_avg} BPM")
        print(f"  RR intervals: min={rr_min} max={rr_max} avg={rr_avg:.1f} ms")
        print(f"  SDNN: {s.sdnn:.2f} ms  RMSSD: {s.rmssd:.2f} ms")
        print()
        rows.append({
            "sensor_id": s.sensor_id,
            "sensor_name": s.sensor_name,
            "duration_seconds": f"{s.duration_seconds:.1f}",
            "data_points": s.data_point_count,
            "hr_min": hr_min,
            "hr_max": hr_max,
            "hr_avg": s.heart_rate_avg,
            "rr_min": rr_min,
            "rr_max": rr_max,
            "rr_avg": f"{rr_avg:.1f}",
            "sdnn": f"{s.sdnn:.2f}",
            "rmssd": f"{s.rmssd:.2f}",
        })

    if args.output:
        try:
            import csv
            out_path = Path(args.output)
            with open(out_path, "w", newline="") as f:
                if rows:
                    writer = csv.DictWriter(f, fieldnames=rows[0].keys())
                    writer.writeheader()
                    writer.writerows(rows)
            print(f"Report written to {out_path}")
        except Exception as e:
            print(f"Error writing report: {e}", file=sys.stderr)
            sys.exit(1)


if __name__ == "__main__":
    main()
