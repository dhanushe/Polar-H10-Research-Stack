#!/usr/bin/env python3
"""
Load an exported CSV zip and show heart rate + RR interval plots (same as API client).

Usage (from python-client directory):
  python scripts/zip_to_plot.py path/to/recording_xxx_csv.zip

  Optional: save figure
  python scripts/zip_to_plot.py path/to/recording.zip --save plot.png

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
        description="Plot heart rate and RR intervals from an exported CSV zip."
    )
    parser.add_argument(
        "zip_path",
        type=str,
        help="Path to the .zip file (e.g. from the app's Export as CSV or Share zip)",
    )
    parser.add_argument(
        "--save", "-s",
        type=str,
        default=None,
        help="Optional path to save the figure (e.g. plot.png)",
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

    session.plot(show=True, save_path=args.save)


if __name__ == "__main__":
    main()
