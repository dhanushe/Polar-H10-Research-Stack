"""
Metabolic rate estimation from Polar H10 accelerometer and heart rate data.

The accelerometer data arriving here is already on-device processed:
  - Per-axis 2nd-order Butterworth HPF (0.25 Hz) removes gravity/DC
  - Per-axis 2nd-order Butterworth LPF  (5 Hz)   removes high-frequency noise
  - Vector magnitude sqrt(x²+y²+z²) computed, then 1-second window-averaged
  - Output: magnitude in mG at 1 Hz

Because gravity is removed, the resting baseline is ~0 mG and the signal is
equivalent to the High-Pass Filtered Vector Magnitude (HPFVM) used in
chest-worn accelerometry literature (Brage et al., 2004; Corder et al., 2007).

MET estimation approach (piecewise linear, chest placement):
  Thresholds and calibration adapted from:
    - Troiano et al. (2008) cut-points (converted from Actigraph CPM)
    - Staudenmayer et al. (2009) regression for body-worn accelerometers
    - Hildebrand et al. (2014) HPFVM thresholds
  Approximate calibration (chest, HPF-filtered):
    0 mG  → 1.0 MET  (seated / supine at rest)
    5 mG  → 1.5 METs (very light standing)
   20 mG  → 3.0 METs (brisk walking ~5 km/h)
   55 mG  → 6.0 METs (jogging ~8 km/h)
  100 mG  → 9.0 METs (running ~12 km/h)

Caloric expenditure uses the MET definition:
    kcal = MET × weight_kg × duration_hours
where weight_kg must be supplied by the caller.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Dict, List, Optional, Sequence, Tuple

try:
    import pandas as pd  # type: ignore[import]
except ImportError:
    pd = None  # type: ignore[assignment]


# ---------------------------------------------------------------------------
# Intensity thresholds (METs)
# Based on Ainsworth et al. (2011) compendium and ACSM guidelines
# ---------------------------------------------------------------------------
SEDENTARY_UPPER = 1.5   # < 1.5 METs → sedentary
LIGHT_UPPER     = 3.0   # 1.5–3.0 METs → light
MODERATE_UPPER  = 6.0   # 3.0–6.0 METs → moderate
# ≥ 6.0 METs → vigorous

# Piecewise breakpoints: (magnitude_mG, METs)
# Derived from chest-accelerometer calibration studies cited in module docstring
_HPFVM_BREAKPOINTS: List[Tuple[float, float]] = [
    (0.0,   1.0),
    (5.0,   1.5),
    (20.0,  3.0),
    (55.0,  6.0),
    (100.0, 9.0),
    (200.0, 14.0),  # extrapolation cap for sprint/very vigorous
]


def magnitude_to_mets(magnitude_mG: float) -> float:
    """Map HPF-filtered vector magnitude (mG) to MET estimate via piecewise linear interpolation.

    Uses the _HPFVM_BREAKPOINTS calibration curve for chest-worn Polar H10.
    Values above the highest breakpoint are clamped to avoid implausible outputs.
    """
    if magnitude_mG <= 0.0:
        return 1.0

    bps = _HPFVM_BREAKPOINTS
    if magnitude_mG >= bps[-1][0]:
        return bps[-1][1]

    for (x0, y0), (x1, y1) in zip(bps, bps[1:]):
        if x0 <= magnitude_mG < x1:
            t = (magnitude_mG - x0) / (x1 - x0)
            return y0 + t * (y1 - y0)

    return 1.0  # fallback (unreachable)


def classify_intensity(mets: float) -> str:
    """Return intensity category string for a given MET value.

    Categories follow ACSM/Ainsworth guidelines:
      sedentary: < 1.5 METs
      light:     1.5–3.0 METs
      moderate:  3.0–6.0 METs
      vigorous:  ≥ 6.0 METs
    """
    if mets < SEDENTARY_UPPER:
        return "sedentary"
    if mets < LIGHT_UPPER:
        return "light"
    if mets < MODERATE_UPPER:
        return "moderate"
    return "vigorous"


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class ActivityEpoch:
    """One time epoch of metabolic activity data."""

    timestamp: datetime
    duration_seconds: float
    mean_magnitude_mG: float
    mets: float
    intensity: str
    kcal: Optional[float] = None

    def __repr__(self) -> str:
        kcal_s = f", kcal={self.kcal:.2f}" if self.kcal is not None else ""
        return (
            f"ActivityEpoch({self.timestamp.strftime('%H:%M:%S')}, "
            f"{self.duration_seconds:.0f}s, "
            f"{self.mean_magnitude_mG:.1f} mG, "
            f"{self.mets:.2f} METs [{self.intensity}]{kcal_s})"
        )


@dataclass
class MetabolicResult:
    """Full metabolic rate analysis for a sensor recording.

    Attributes
    ----------
    epochs:
        List of ActivityEpoch objects (one per analysis epoch).
    method:
        Estimation method used ('hpfvm', 'heart_rate', or 'flex_hr').
    weight_kg:
        Body weight used for kcal calculation, or None.
    total_duration_seconds:
        Total analysed duration.
    mean_mets:
        Mean MET value across all epochs.
    total_kcal:
        Total kilocalories (None if weight_kg not provided).
    time_sedentary_seconds:
        Seconds classified as sedentary (< 1.5 METs).
    time_light_seconds:
        Seconds classified as light (1.5–3.0 METs).
    time_moderate_seconds:
        Seconds classified as moderate (3.0–6.0 METs).
    time_vigorous_seconds:
        Seconds classified as vigorous (≥ 6.0 METs).
    """

    epochs: List[ActivityEpoch] = field(default_factory=list)
    method: str = "hpfvm"
    weight_kg: Optional[float] = None

    @property
    def total_duration_seconds(self) -> float:
        return sum(e.duration_seconds for e in self.epochs)

    @property
    def mean_mets(self) -> float:
        if not self.epochs:
            return 0.0
        return sum(e.mets * e.duration_seconds for e in self.epochs) / self.total_duration_seconds

    @property
    def total_kcal(self) -> Optional[float]:
        if any(e.kcal is None for e in self.epochs):
            return None
        return sum(e.kcal for e in self.epochs)  # type: ignore[misc]

    @property
    def time_sedentary_seconds(self) -> float:
        return sum(e.duration_seconds for e in self.epochs if e.intensity == "sedentary")

    @property
    def time_light_seconds(self) -> float:
        return sum(e.duration_seconds for e in self.epochs if e.intensity == "light")

    @property
    def time_moderate_seconds(self) -> float:
        return sum(e.duration_seconds for e in self.epochs if e.intensity == "moderate")

    @property
    def time_vigorous_seconds(self) -> float:
        return sum(e.duration_seconds for e in self.epochs if e.intensity == "vigorous")

    @property
    def active_time_seconds(self) -> float:
        """Time above sedentary threshold (≥ 1.5 METs)."""
        return sum(e.duration_seconds for e in self.epochs if e.mets >= SEDENTARY_UPPER)

    def intensity_breakdown(self) -> Dict[str, float]:
        """Return dict mapping intensity category → fraction of total time (0–1)."""
        total = self.total_duration_seconds
        if total == 0:
            return {"sedentary": 0.0, "light": 0.0, "moderate": 0.0, "vigorous": 0.0}
        return {
            "sedentary": self.time_sedentary_seconds / total,
            "light":     self.time_light_seconds / total,
            "moderate":  self.time_moderate_seconds / total,
            "vigorous":  self.time_vigorous_seconds / total,
        }

    def to_dataframe(self) -> Any:
        if pd is None:
            raise ImportError("pandas is required for MetabolicResult.to_dataframe()")
        rows = [
            {
                "timestamp":         e.timestamp,
                "duration_seconds":  e.duration_seconds,
                "mean_magnitude_mG": e.mean_magnitude_mG,
                "mets":              e.mets,
                "intensity":         e.intensity,
                "kcal":              e.kcal,
            }
            for e in self.epochs
        ]
        return pd.DataFrame(rows)

    def __repr__(self) -> str:
        dur_min = self.total_duration_seconds / 60
        kcal_s = f", {self.total_kcal:.0f} kcal" if self.total_kcal is not None else ""
        bdown = self.intensity_breakdown()
        return (
            f"MetabolicResult(method={self.method!r}, "
            f"duration={dur_min:.1f} min, "
            f"mean_METs={self.mean_mets:.2f}{kcal_s}, "
            f"sedentary={bdown['sedentary']*100:.0f}%, "
            f"light={bdown['light']*100:.0f}%, "
            f"moderate={bdown['moderate']*100:.0f}%, "
            f"vigorous={bdown['vigorous']*100:.0f}%)"
        )


# ---------------------------------------------------------------------------
# Core estimation functions
# ---------------------------------------------------------------------------

def estimate_from_accelerometer(
    acc_points: Sequence[Any],
    epoch_seconds: int = 60,
    weight_kg: Optional[float] = None,
) -> MetabolicResult:
    """Estimate metabolic rate from a sequence of AccelerometerPoint objects.

    Parameters
    ----------
    acc_points:
        Iterable of AccelerometerPoint (timestamp: datetime, magnitude: float mG).
    epoch_seconds:
        Aggregation window in seconds. Default 60 s (1-minute epochs).
    weight_kg:
        Subject body mass for kcal calculation. Pass None to skip kcal.

    Returns
    -------
    MetabolicResult with one ActivityEpoch per epoch window.
    """
    if not acc_points:
        return MetabolicResult(method="hpfvm", weight_kg=weight_kg)

    # Sort by timestamp
    pts = sorted(acc_points, key=lambda p: p.timestamp)
    t0 = pts[0].timestamp.timestamp()

    # Group into fixed-length time buckets
    buckets: Dict[int, List] = {}
    for pt in pts:
        bucket_idx = int((pt.timestamp.timestamp() - t0) / epoch_seconds)
        buckets.setdefault(bucket_idx, []).append(pt)

    epochs: List[ActivityEpoch] = []
    for idx in sorted(buckets.keys()):
        bucket = buckets[idx]
        mean_mag = sum(p.magnitude for p in bucket) / len(bucket)
        mets = magnitude_to_mets(mean_mag)
        intensity = classify_intensity(mets)
        dur = float(len(bucket))  # each point is 1-second averaged
        kcal = (mets * weight_kg * dur / 3600.0) if weight_kg is not None else None
        epochs.append(ActivityEpoch(
            timestamp=bucket[0].timestamp,
            duration_seconds=dur,
            mean_magnitude_mG=mean_mag,
            mets=mets,
            intensity=intensity,
            kcal=kcal,
        ))

    return MetabolicResult(epochs=epochs, method="hpfvm", weight_kg=weight_kg)


def _hr_to_mets(
    hr_bpm: float,
    age: Optional[float],
    sex: str,
    weight_kg: Optional[float],
    resting_hr: Optional[float],
) -> float:
    """Convert heart rate to MET estimate.

    Uses the Keytel et al. (2005) regression with adaptations:
      males:   EE (kcal/min) = (-55.0969 + 0.6309*HR + 0.1988*W + 0.2017*A) / 4.184
      females: EE (kcal/min) = (-20.4022 + 0.4472*HR - 0.1263*W + 0.0740*A) / 4.184

    When age and/or weight are unknown, fallback to heart rate reserve (Karvonen)
    assuming mean resting HR ~65 BPM and max HR ~200 BPM.

    Returns METs (1 MET ≈ 3.5 mL O₂/kg/min, and 1 MET ≈ 1 kcal/kg/h;
    we estimate via VO₂ proxy from HR reserve fraction).
    """
    # Normalised heart rate reserve fraction
    rest = resting_hr if resting_hr else 65.0
    hr_max = (220 - age) if age else 185.0
    hrr_fraction = max(0.0, min(1.0, (hr_bpm - rest) / max(1.0, hr_max - rest)))

    if weight_kg and age:
        if sex.lower().startswith("f"):
            ee_kcal_min = (-20.4022 + 0.4472 * hr_bpm - 0.1263 * weight_kg + 0.0740 * age) / 4.184
        else:
            ee_kcal_min = (-55.0969 + 0.6309 * hr_bpm + 0.1988 * weight_kg + 0.2017 * age) / 4.184
        ee_kcal_min = max(1.0, ee_kcal_min)
        # Convert kcal/min to METs using body weight and MET definition
        mets = (ee_kcal_min * 60.0) / weight_kg if weight_kg > 0 else 1.0
        return max(1.0, mets)

    # Simplified VO₂ proxy: VO₂ = VO₂rest + hrr_fraction * (VO₂max - VO₂rest)
    # Assuming VO₂max ~35 mL/kg/min for average adult (conservative)
    vo2_rest = 3.5  # mL/kg/min = 1 MET
    vo2_max = 35.0
    vo2 = vo2_rest + hrr_fraction * (vo2_max - vo2_rest)
    return max(1.0, vo2 / vo2_rest)


def estimate_from_heart_rate(
    hr_points: Sequence[Any],
    epoch_seconds: int = 60,
    weight_kg: Optional[float] = None,
    age: Optional[float] = None,
    sex: str = "male",
    resting_hr: Optional[float] = None,
) -> MetabolicResult:
    """Estimate metabolic rate from heart rate data.

    Uses Keytel et al. (2005) when age and weight are provided, otherwise
    falls back to a heart rate reserve (Karvonen) VO₂ proxy.

    Parameters
    ----------
    hr_points:
        Iterable of HeartRatePoint (timestamp: datetime, value: int BPM).
    epoch_seconds:
        Aggregation window size.
    weight_kg:
        Body mass in kg. Required for Keytel equation; otherwise uses proxy.
    age:
        Age in years. Required for Keytel equation.
    sex:
        'male' or 'female'. Used by Keytel equation.
    resting_hr:
        Resting heart rate (BPM). Falls back to 65 BPM if not provided.
    """
    if not hr_points:
        return MetabolicResult(method="heart_rate", weight_kg=weight_kg)

    pts = sorted(hr_points, key=lambda p: p.timestamp)
    t0 = pts[0].timestamp.timestamp()

    buckets: Dict[int, List] = {}
    for pt in pts:
        bucket_idx = int((pt.timestamp.timestamp() - t0) / epoch_seconds)
        buckets.setdefault(bucket_idx, []).append(pt)

    epochs: List[ActivityEpoch] = []
    for idx in sorted(buckets.keys()):
        bucket = buckets[idx]
        mean_hr = sum(float(p.value) for p in bucket) / len(bucket)
        mets = _hr_to_mets(mean_hr, age, sex, weight_kg, resting_hr)
        intensity = classify_intensity(mets)
        dur = float(len(bucket))
        kcal = (mets * weight_kg * dur / 3600.0) if weight_kg is not None else None
        epochs.append(ActivityEpoch(
            timestamp=bucket[0].timestamp,
            duration_seconds=dur,
            mean_magnitude_mG=0.0,
            mets=mets,
            intensity=intensity,
            kcal=kcal,
        ))

    return MetabolicResult(epochs=epochs, method="heart_rate", weight_kg=weight_kg)


def estimate_flex_hr(
    acc_points: Sequence[Any],
    hr_points: Sequence[Any],
    epoch_seconds: int = 60,
    weight_kg: Optional[float] = None,
    age: Optional[float] = None,
    sex: str = "male",
    resting_hr: Optional[float] = None,
    flex_hr: Optional[float] = None,
) -> MetabolicResult:
    """Flex-HR combined accelerometer + heart rate estimation (Brage et al., 2004).

    Below HR_flex threshold: accelerometer-based METs are used (better at low intensity).
    At or above HR_flex:     heart-rate-based METs are used (better at high intensity).

    HR_flex defaults to the mean of resting HR and the HR at 3.0 METs (~light-moderate
    boundary), approximated as resting_hr + 0.35 * (hr_max - resting_hr).

    Parameters
    ----------
    acc_points, hr_points:
        Sensor data sequences.
    epoch_seconds:
        Aggregation window in seconds.
    weight_kg, age, sex, resting_hr:
        Subject parameters forwarded to HR-based estimation.
    flex_hr:
        Override the computed HR_flex threshold. If None, auto-computed.
    """
    acc_result = estimate_from_accelerometer(acc_points, epoch_seconds, weight_kg)
    hr_result  = estimate_from_heart_rate(hr_points, epoch_seconds, weight_kg, age, sex, resting_hr)

    if not acc_result.epochs and not hr_result.epochs:
        return MetabolicResult(method="flex_hr", weight_kg=weight_kg)
    if not acc_result.epochs:
        return MetabolicResult(epochs=hr_result.epochs, method="heart_rate", weight_kg=weight_kg)
    if not hr_result.epochs:
        return MetabolicResult(epochs=acc_result.epochs, method="hpfvm", weight_kg=weight_kg)

    # Auto-compute flex_hr
    if flex_hr is None:
        rest = resting_hr if resting_hr else 65.0
        hr_max = (220 - age) if age else 185.0
        flex_hr = rest + 0.35 * (hr_max - rest)

    hr_pts_sorted = sorted(hr_points, key=lambda p: p.timestamp)

    combined: List[ActivityEpoch] = []
    for acc_ep in acc_result.epochs:
        epoch_start = acc_ep.timestamp.timestamp()
        epoch_end = epoch_start + epoch_seconds
        hr_values = [
            float(pt.value)
            for pt in hr_pts_sorted
            if epoch_start <= pt.timestamp.timestamp() < epoch_end
        ]
        mean_hr_for_epoch = (
            sum(hr_values) / len(hr_values)
            if hr_values
            else flex_hr - 1
        )

        if mean_hr_for_epoch >= flex_hr:
            # Use HR-based estimate above flex threshold
            mets = _hr_to_mets(mean_hr_for_epoch, age, sex, weight_kg, resting_hr)
            intensity = classify_intensity(mets)
            kcal = (
                mets * weight_kg * acc_ep.duration_seconds / 3600.0
                if weight_kg is not None
                else None
            )
            ep = ActivityEpoch(
                timestamp=acc_ep.timestamp,
                duration_seconds=acc_ep.duration_seconds,
                mean_magnitude_mG=acc_ep.mean_magnitude_mG,
                mets=mets,
                intensity=intensity,
                kcal=kcal,
            )
        else:
            ep = acc_ep
        combined.append(ep)

    return MetabolicResult(epochs=combined, method="flex_hr", weight_kg=weight_kg)


# ---------------------------------------------------------------------------
# Convenience wrapper that accepts dataframes or point lists
# ---------------------------------------------------------------------------

def estimate_metabolic_rate(
    acc_points: Sequence[Any],
    hr_points: Optional[Sequence[Any]] = None,
    epoch_seconds: int = 60,
    weight_kg: Optional[float] = None,
    age: Optional[float] = None,
    sex: str = "male",
    resting_hr: Optional[float] = None,
    flex_hr: Optional[float] = None,
    method: str = "auto",
) -> MetabolicResult:
    """Estimate metabolic rate from accelerometer (and optionally heart rate) data.

    This is the primary entry point for metabolic estimation.

    Parameters
    ----------
    acc_points:
        List of AccelerometerPoint objects (or objects with `.timestamp` and
        `.magnitude` attributes). One point per second.
    hr_points:
        Optional list of HeartRatePoint objects. When provided with
        method='flex_hr' or method='auto', enables the combined Flex-HR method.
    epoch_seconds:
        Length of analysis epochs in seconds. Default 60 (1-minute epochs).
        Smaller values (e.g. 15, 30) give finer temporal resolution.
    weight_kg:
        Body mass in kg. Required for kcal calculation.
    age:
        Age in years. Improves HR-based MET accuracy (Keytel equation).
    sex:
        'male' (default) or 'female'. Used by Keytel HR equation.
    resting_hr:
        Resting heart rate in BPM. Used in HR reserve and Flex-HR computations.
        Auto-estimated as 65 BPM if not provided.
    flex_hr:
        Manual override for the Flex-HR threshold. Auto-computed if None.
    method:
        Estimation method:
          'hpfvm'      — accelerometer only
          'heart_rate' — HR only
          'flex_hr'    — combined
          'auto'       — flex_hr with both streams, heart_rate with HR only,
                         hpfvm otherwise

    Returns
    -------
    MetabolicResult
        Contains ActivityEpoch list and summary statistics.
    """
    has_acc_points = bool(len(acc_points))
    has_hr_points = bool(len(hr_points)) if hr_points is not None else False

    if method == "auto":
        if has_acc_points and has_hr_points:
            method = "flex_hr"
        elif has_hr_points:
            method = "heart_rate"
        else:
            method = "hpfvm"

    if method == "hpfvm":
        return estimate_from_accelerometer(acc_points, epoch_seconds, weight_kg)
    if method == "heart_rate":
        return estimate_from_heart_rate(
            hr_points if hr_points is not None else [],
            epoch_seconds,
            weight_kg,
            age,
            sex,
            resting_hr,
        )
    if method == "flex_hr":
        return estimate_flex_hr(
            acc_points,
            hr_points if hr_points is not None else [],
            epoch_seconds,
            weight_kg,
            age,
            sex,
            resting_hr,
            flex_hr,
        )

    raise ValueError(f"Unknown method {method!r}. Use 'hpfvm', 'heart_rate', 'flex_hr', or 'auto'.")
