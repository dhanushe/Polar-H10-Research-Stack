# How to use the urap_polar library

## Install

```bash
pip install requests pandas matplotlib
```

App must be **open** and on the **same Wi‑Fi** as your computer.

## Base URL (required for all API calls)

The base URL is **not fixed**—it depends on your device and network. In the iOS app, open **Settings** and go to **API for Python**. You’ll see **Device IP** and **Base URL** (e.g. `http://10.45.216.117:8080`). Use that exact Base URL in Python. If the section is empty, keep the app in the foreground and ensure the device is on Wi‑Fi.

## Connect

```python
import urap_polar

# Use the Base URL from the app: Settings → API for Python
base_url = "http://YOUR_DEVICE_IP:8080"  # replace with the URL shown in the app
```

## List recordings

```python
recordings = urap_polar.list_recordings(base_url=base_url)
for r in recordings:
    print(r.id, r.name, r.duration_seconds, r.sensor_count)
```

Each item is a **RecordingSummary** with: `id`, `name`, `start_date`, `end_date`, `duration_seconds`, `sensor_count`, `average_heart_rate`, `average_sdnn`, `average_rmssd`.

## Get one session

```python
session = urap_polar.get_recording("YOUR_RECORDING_ID", base_url=base_url)
# session is a RecordingSession; get recording IDs from the app (Recordings list or detail)
```

## Session-level properties and methods

- **Properties:** `session.id`, `session.name`, `session.start_date`, `session.end_date`, `session.duration_seconds`, `session.sensor_count`, `session.total_data_points`, `session.average_heart_rate`, `session.average_sdnn`, `session.average_rmssd`
- **Sensors:** `session.sensors()` → list of `SensorData`; `session.sensor(sensor_id)` → one sensor or `None`
- **DataFrames:** `session.to_dataframes()` → `{sensor_id: {"heart_rate": df, "rr_intervals": df}}`
- **Plot:** `session.plot(show=True, save_path=None)` — see Plotting below

## Sensor-level (one sensor)

```python
s = session.sensor(sensor_id)  # or session.sensors()[0]
```

- **Properties:** `s.sensor_id`, `s.sensor_name`, `s.duration_seconds`, `s.data_point_count`
- **Stats:** `s.heart_rate_min`, `s.heart_rate_max`, `s.heart_rate_avg`, `s.sdnn`, `s.rmssd`, `s.hrv_window`, `s.hrv_sample_count`
- **RR stats:** `s.rr_min()`, `s.rr_max()`, `s.rr_avg()`
- **All points:** `s.heart_rate_points()` → list of `HeartRatePoint(timestamp, value, monotonic_timestamp)`; `s.rr_points()` → list of `RRIntervalPoint(...)`
- **Single point by index:** `s.get_heart_rate_point(i)`, `s.get_rr_point(i)`
- **DataFrames:** `s.heart_rate_dataframe()`, `s.rr_dataframe()`

## Plotting methods

All plotting uses the base URL from **Settings → API for Python** when fetching data; the session object is then passed to these functions (or use `session.plot()`).

| Method | Description |
|--------|-------------|
| `session.plot(show=True, save_path=None)` | One figure: one row per sensor, two columns (heart rate, RR intervals). `save_path` optional (e.g. `"plot.png"`). |
| `urap_polar.plot_session(session, show=True, save_path=None)` | Same as `session.plot()`. |
| `urap_polar.plot_heart_rate(session, sensor_id=None, show=True, save_path=None)` | Heart rate only. Omit `sensor_id` to plot all sensors (one subplot per sensor); set `sensor_id` to plot a single sensor. |
| `urap_polar.plot_rr_intervals(session, sensor_id=None, show=True, save_path=None)` | RR intervals only. Same `sensor_id` behavior as above. |

Example:

```python
session.plot(show=True, save_path="recording.png")

# Or use the module functions:
urap_polar.plot_session(session, show=True, save_path=None)
urap_polar.plot_heart_rate(session, sensor_id=None, show=True, save_path=None)
urap_polar.plot_rr_intervals(session, sensor_id=None, show=True, save_path=None)
```

## Backward compatibility

- `to_dataframes(session)` accepts a **dict** or a **RecordingSession**.
- `session.raw` is the raw JSON dict.

## CLI

From the `python-client` directory. Use the **base URL from the app: Settings → API for Python**.

```bash
python urap_polar.py RECORDING_ID <BASE_URL>
python urap_polar.py <BASE_URL>   # uses first recording
```
