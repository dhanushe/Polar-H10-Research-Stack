from datetime import datetime, timedelta
from types import SimpleNamespace
import unittest

from urap_polar.metabolic import estimate_metabolic_rate


def _hr_points(start, values):
    return [
        SimpleNamespace(timestamp=start + timedelta(seconds=i), value=value)
        for i, value in enumerate(values)
    ]


def _acc_points(start, magnitudes):
    return [
        SimpleNamespace(timestamp=start + timedelta(seconds=i), magnitude=magnitude)
        for i, magnitude in enumerate(magnitudes)
    ]


class MetabolicEstimationTests(unittest.TestCase):
    def test_auto_uses_heart_rate_when_accelerometer_is_absent(self):
        start = datetime(2026, 1, 1, 12, 0, 0)
        result = estimate_metabolic_rate(
            acc_points=[],
            hr_points=_hr_points(start, [130] * 120),
            epoch_seconds=60,
            method="auto",
        )

        self.assertEqual(result.method, "heart_rate")
        self.assertEqual(len(result.epochs), 2)
        self.assertGreater(result.mean_mets, 1.0)

    def test_flex_hr_aligns_heart_rate_to_accelerometer_epoch_windows(self):
        start = datetime(2026, 1, 1, 12, 0, 0)
        acc = _acc_points(start, [0.0] * 120)
        hr = _hr_points(
            start + timedelta(seconds=30),
            [50] * 30 + [130] * 60 + [50] * 30,
        )

        result = estimate_metabolic_rate(
            acc_points=acc,
            hr_points=hr,
            epoch_seconds=60,
            resting_hr=60,
            flex_hr=100,
            method="flex_hr",
        )

        self.assertEqual(result.method, "flex_hr")
        self.assertLess(result.epochs[0].mets, 1.5)
        self.assertGreater(result.epochs[1].mets, 3.0)


if __name__ == "__main__":
    unittest.main()
