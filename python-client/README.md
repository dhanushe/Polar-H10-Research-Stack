# URAP Polar H10 Python Client

This folder contains a small Python helper for talking to the URAP Polar H10 iOS app's local HTTP API.

## Prerequisites

- The **URAP Polar H10** iOS app running on your device or simulator.
- The app must be **open and active** so the in-app API server is running.
- Your computer and the iOS device must be on the **same Wi-Fi network**.
- Python 3.9+ with:
  - `requests`
  - `pandas` (for `to_dataframes` and the built-in visualization)
  - `matplotlib` (for the built-in visualization when you run the script)

Install dependencies:

```bash
pip install requests pandas matplotlib
```

## Finding the base URL

The app exposes an HTTP API while it is in the foreground. The **base URL** (e.g. `http://10.45.216.117:8080`) is **not fixed**—it depends on your device’s Wi‑Fi IP and port `8080`.

**Where to get it:** In the iOS app, open **Settings** and look at the **API for Python** section. It shows **Device IP** and **Base URL**. Use that exact Base URL in your Python script. If nothing appears there, keep the app in the foreground and ensure the device is connected to Wi‑Fi.

## Using the library

For a concise guide to the full API, see **[USAGE.md](USAGE.md)**. It documents **plotting methods** (`session.plot`, `plot_session`, `plot_heart_rate`, `plot_rr_intervals`) and **other methods** (session/sensor properties, `sensors()`, `sensor(id)`, `to_dataframes`, `heart_rate_points`, `rr_points`, etc.).

Quick example:

```python
import urap_polar

# Get base_url from the app: Settings → API for Python (Device IP / Base URL)
base_url = "http://YOUR_DEVICE_IP:8080"  # replace with the URL shown in the app
recordings = urap_polar.list_recordings(base_url=base_url)  # list of RecordingSummary
session = urap_polar.get_recording(recordings[0].id, base_url=base_url)  # RecordingSession

print(session.duration_seconds, session.total_data_points)
for s in session.sensors():
    print(s.sensor_name, s.heart_rate_avg, s.heart_rate_points()[:3])
session.plot()
```

## Recording IDs

When starting a recording in the iOS app, you will be prompted to enter (or generate) a **20-character Recording ID**.  
This ID is:

- Stored with the recording.
- Shown in the **Recordings** list and in the recording **detail** view.
- Used as the key in the Python client (`get_recording(recording_id, ...)`).


## Run the script to visualize

You can run the module directly to fetch a recording and open a matplotlib figure with heart rate and RR interval time series:

```bash
# Use the base URL from the app: Settings → API for Python
python urap_polar.py YOUR_RECORDING_ID <BASE_URL>
# Example: python urap_polar.py abc12345678901234567 http://10.45.216.117:8080

# Or with default http://localhost:8080 (e.g. iOS Simulator)
python urap_polar.py YOUR_RECORDING_ID

# If you omit the recording ID, the script uses the first recording from the API
python urap_polar.py <BASE_URL>
```

The plot shows one row per sensor: heart rate (BPM) and RR intervals (ms) over time. Close the figure window to exit.

## Working with exported CSV zip

You can also work with recordings **without the app running** by using the **exported CSV zip**:

1. In the app, open a recording and choose **Export → Export as CSV** (save to Files) or **Export → Share zip** to open the share sheet (e.g. Mail, AirDrop) and send the zip to your computer.
2. The zip contains CSVs for the session and each sensor (heart rate, RR intervals, statistics). Use the same Python library to load and process it.

**Load the zip in Python:**

```python
import urap_polar

session = urap_polar.load_from_zip("path/to/recording_xxx_csv.zip")
print(session.name, session.duration_seconds)
session.plot()  # same plotting as with the API
```

**Sample scripts** (run from the `python-client` directory):

- **Per-sensor statistics:**  
  `python scripts/process_zip_stats.py path/to/recording_xxx_csv.zip`  
  Optionally write a report: `--output report.csv`

- **Plot from zip:**  
  `python scripts/zip_to_plot.py path/to/recording_xxx_csv.zip`  
  Optionally save the figure: `--save plot.png`

You can email the zip from the app (Share zip) and run these scripts on your computer.

## Troubleshooting

### "Connection refused" or "Max retries exceeded"

The Python script could not connect to the app. Fix in order:

1. **App in foreground** — The API server runs only while the app is **open and in the foreground**. If the app is in the background or the device is locked, the server stops. Bring the app to the front and leave the screen on.

2. **Same Wi‑Fi** — The iPhone/iPad and your computer must be on the **same Wi‑Fi network**. Use the IP shown in the app (Settings → API for Python). If that section is empty, the app may not be on Wi‑Fi or the server may not be running.

3. **Local Network permission** — On first use, iOS may ask for **Local Network** access. If you denied it, the app cannot accept connections. Turn it on: **Settings → URAP Polar H10 → Local Network** (or **Settings → Privacy & Security → Local Network** and enable the app).

4. **Correct base URL** — Use the exact **Base URL** from the app: **Settings → API for Python**. The URL is different on each device/network (e.g. `http://10.45.216.117:8080`); always copy it from the app.

