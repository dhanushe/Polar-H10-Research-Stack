"""
CLI for URAP Polar H10: fetch a recording and plot. Uses the urap_polar package.

Run from python-client directory: python urap_polar.py <recording_id> [base_url]
"""

from __future__ import annotations

import sys

import requests

import urap_polar


def main() -> None:
    base_url = "http://localhost:8080"
    recording_id = None

    args = sys.argv[1:]
    if args:
        if args[0].startswith("http://") or args[0].startswith("https://"):
            base_url = args[0].rstrip("/")
            recording_id = None
        else:
            recording_id = args[0]
            if len(args) >= 2:
                base_url = args[1].rstrip("/")

    if not recording_id:
        print("Usage: python urap_polar.py <recording_id> [base_url]")
        print("Example: python urap_polar.py abc12345678901234567 http://192.168.1.42:8080")
        print("\nFetching list of recordings to choose one...")
        try:
            recordings = urap_polar.list_recordings(base_url=base_url)
            if not recordings:
                print("No recordings found. Start a recording in the app first.")
                sys.exit(1)
            rec = recordings[0]
            recording_id = rec.id
            print(f"Using first recording: {rec.name} (id: {recording_id})")
        except Exception as e:
            print(f"Could not list recordings: {e}")
            sys.exit(1)

    try:
        session = urap_polar.get_recording(recording_id, base_url=base_url)
        session.plot(show=True)
    except requests.exceptions.ConnectionError as e:
        print(f"Connection error: {e}")
        print()
        print("The app's API server is not reachable. Check:")
        print("  1. App is open and in the foreground (not backgrounded or locked).")
        print("  2. iPhone/iPad is on the same Wi-Fi network as this computer.")
        print("  3. In iOS Settings → URAP Polar H10 → Local Network is ON.")
        print("  4. Base URL matches the one shown in the app: Settings → API for Python.")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
