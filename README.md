<div align="center">

# <img src="URAP Polar H10 V1/Assets.xcassets/AppIcon.appiconset/1024.png" width="80" height="80" alt="App icon"/> URAP Polar H10

**Research-grade heart rate & HRV recording with the Polar H10 chest strap**

*iOS app + Python API for analysis and visualization*

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org) [![Python](https://img.shields.io/badge/Python-3.9+-3776AB?logo=python&logoColor=white)](https://python.org) [![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20iPad%20%7C%20macOS-blue.svg)](https://apple.com)

</div>

---

## Purpose

URAP Polar H10 turns your **Polar H10** chest strap into a research-friendly data pipeline: record **ECG-derived heart rate** and **RR intervals** on your iPhone/iPad, then pull sessions into **Python** for analysis, pandas DataFrames, and publication-ready plots—all over your local network.

---

## Features

| Area | What you get |
|------|----------------|
| **iOS app** | Dashboard with live HR/RR from multiple sensors, per-sensor detail with HRV (SDNN, RMSSD), time-range charts, and a recordings library with 20-char IDs. |
| **Recording** | Start/stop from the app; optional **Live Activity**; data stored locally and exposed via an in-app HTTP API while the app is in the foreground. |
| **Python client** | List recordings, fetch sessions, get heart rate & RR series, export to **pandas** DataFrames, and plot (heart rate, RR intervals, multi-sensor) with matplotlib. |

---

## Quick start

### 1. iOS app

1. Build and run the **URAP Polar H10 V1** Xcode project on your device or simulator.
2. Open **Dashboard** → add a Polar H10 sensor (BLE).
3. Start a recording (optional 20-character ID); view live data and past **Recordings** in the app.
4. In **Settings** → **API for Python**, note the **Base URL** (e.g. `http://10.45.216.117:8080`). The app and your computer must be on the **same Wi‑Fi** network.

### 2. Python (optional)

```bash
cd python-client
pip install requests pandas matplotlib
```

```python
import urap_polar
base_url = "http://YOUR_DEVICE_IP:8080"  # from app Settings
recordings = urap_polar.list_recordings(base_url=base_url)
session = urap_polar.get_recording(recordings[0].id, base_url=base_url)
session.plot()  # matplotlib figure
```

See **[python-client/README.md](python-client/README.md)** and **[python-client/USAGE.md](python-client/USAGE.md)** for the full API and plotting options.

---

## Authors

**Dhanush Eashwar** · **Charlie Huizenga**

---

<div align="center">

*Built for URAP — clean data from Polar H10 to your analysis stack.*

</div>
