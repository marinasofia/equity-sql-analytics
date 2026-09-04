"""Deterministic feature contracts using synthetic prices only."""

import csv
import math
import random
import tempfile
import unittest
from datetime import date, timedelta
from pathlib import Path
from unittest.mock import patch

from scripts.build_features import ema, main, read_series, rolling_vol, wilder_rsi


class FeatureTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "prices.csv"

    def test_normalizes_sorts_and_preserves_rows(self):
        self.source.write_text("Date,Close\n2026-01-02,12\n2026-01-01T16:00:00,$10\n")
        self.assertEqual(
            read_series(self.source), [("2026-01-01", 10), ("2026-01-02", 12)]
        )

    def test_invalid_source_fails_with_no_silent_row_loss(self):
        cases = [
            "Date,Close\n",
            "Date,Open\n2026-01-01,1\n",
            "Date,Close, CLOSE\n2026-01-01,1,2\n",
            "Date,Close\n2026-01-01,1\n2026-01-01,2\n",
            "Date,Close\n2026-01-01,1,2\n",
            "Date,Close\n2026-01-01\n",
        ]
        cases += [
            f"Date,Close\n2026-01-01,{v}\n"
            for v in ["NaN", "inf", "-inf", "0", "-1", "", "x"]
        ]
        cases += [
            f"Date,Close\n{v},1\n"
            for v in ["2026-02-30", "20260101", "01/01/2026", "2026-01-01junk", ""]
        ]
        for body in cases:
            with self.subTest(body=body):
                self.source.write_text(body)
                with self.assertRaises(ValueError):
                    read_series(self.source)

    def test_ema_seed_and_recurrence(self):
        self.assertEqual(ema([1.0, 2.0, 3.0, 4.0], 3), [None, None, 2.0, 3.0])
        self.assertEqual(ema([], 3), [])

    def test_rsi_warmup_and_direction(self):
        self.assertEqual(
            wilder_rsi([1.0, 2.0, 3.0, 4.0], 2), [None, None, 100.0, 100.0]
        )
        self.assertEqual(wilder_rsi([4.0, 3.0, 2.0, 1.0], 2), [None, None, 0.0, 0.0])
        self.assertEqual(wilder_rsi([1.0], 14), [None])
        self.assertEqual(wilder_rsi([1.0] * 4, 2), [None, None, 100.0, 100.0])

    def test_volatility_uses_sample_variance(self):
        values = rolling_vol([None, 0.1, -0.1, 0.1], 2, 1)
        self.assertEqual(values[:2], [None, None])
        self.assertAlmostEqual(values[2], math.sqrt(0.02))

    def test_invalid_windows_are_rejected(self):
        for function in [ema, wilder_rsi, rolling_vol]:
            for window in [0, -1, True, 1.5]:
                with (
                    self.subTest(function=function, window=window),
                    self.assertRaises(ValueError),
                ):
                    function([1.0, 2.0], window)

    def test_seeded_series_has_finite_bounded_indicators_without_future_leakage(self):
        generator = random.Random(42)
        for _ in range(20):
            prices = [100.0]
            for _ in range(79):
                prices.append(prices[-1] * (1 + generator.uniform(-0.05, 0.05)))
            rsi = wilder_rsi(prices)
            self.assertTrue(
                all(v is None or math.isfinite(v) and 0 <= v <= 100 for v in rsi)
            )
            self.assertEqual(rsi[:40], wilder_rsi(prices[:40]))
            self.assertEqual(ema(prices, 12)[:40], ema(prices[:40], 12))

    def test_end_to_end_csv_has_expected_dates_and_warmups(self):
        with self.source.open("w", newline="") as stream:
            writer = csv.writer(stream)
            writer.writerow(["Date", "Close"])
            for i in range(40):
                writer.writerow(
                    [(date(2026, 1, 1) + timedelta(days=i)).isoformat(), 100 + i]
                )
        target = self.root / "nested" / "features.csv"
        self.assertEqual(main([str(self.source), "-o", str(target)]), 0)
        with target.open() as stream:
            rows = list(csv.DictReader(stream))
        self.assertEqual(len(rows), 40)
        self.assertEqual(rows[0]["Daily_Return"], "")
        self.assertEqual(float(rows[1]["Daily_Return"]), 0.01)
        self.assertEqual(rows[13]["RSI"], "")
        self.assertEqual(rows[14]["RSI"], "100.000")
        self.assertEqual(rows[24]["MACD"], "")
        self.assertNotEqual(rows[25]["MACD"], "")
        original = target.read_bytes()
        with patch(
            "scripts.build_features.os.replace",
            side_effect=OSError("Synthetic failure"),
        ):
            with self.assertRaises(OSError):
                main([str(self.source), "-o", str(target)])
        self.assertEqual(target.read_bytes(), original)
        self.assertEqual(list(target.parent.iterdir()), [target])


if __name__ == "__main__":
    unittest.main()
