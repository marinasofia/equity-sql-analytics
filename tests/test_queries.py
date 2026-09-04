"""Execute the query logic with SQLite window functions and date adapters.

These tests verify results against synthetic data. They do not certify MySQL
DDL, LOAD DATA behavior, permissions, or query plans.
"""

import re
import sqlite3
import unittest
from datetime import date, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class QueryTests(unittest.TestCase):
    def setUp(self):
        self.connection = sqlite3.connect(":memory:")
        self.addCleanup(self.connection.close)
        self.connection.create_function(
            "YEAR", 1, lambda value: date.fromisoformat(value).year
        )
        self.connection.create_function(
            "DAYNAME", 1, lambda value: date.fromisoformat(value).strftime("%A")
        )
        self.connection.execute(
            "CREATE TABLE features_engineered (Date TEXT PRIMARY KEY, RSI REAL, MACD REAL, Volatility REAL, Daily_Return REAL)"
        )
        source = re.sub(r"/\*.*?\*/", "", (ROOT / "NVIDIA.sql").read_text(), flags=re.S)
        self.queries = [query.strip() for query in source.split(";") if query.strip()]

    def insert(self, rows):
        self.connection.executemany(
            "INSERT INTO features_engineered VALUES (?, ?, ?, ?, ?)",
            [
                ((date(2025, 1, 1) + timedelta(days=i)).isoformat(), *row)
                for i, row in enumerate(rows)
            ],
        )

    def test_every_query_executes_on_declared_feature_columns(self):
        self.insert([(None, None, None, None)] + [(20, -1, 0.2, 0.01)] * 80)
        self.assertEqual(len(self.queries), 9)
        for query in self.queries:
            with self.subTest(query=query[:80]):
                self.connection.execute(query).fetchall()

    def test_missing_indicators_are_not_classified_as_observed_values(self):
        self.insert(
            [(None, None, None, None), (70, 1, 0.2, 0.01), (20, -1, 0.1, -0.01)]
        )
        for index in [0, 1, 4, 5]:
            with self.subTest(query=index + 1):
                rows = self.connection.execute(self.queries[index]).fetchall()
                self.assertIsNone(rows[0][-1])
        self.assertEqual(
            self.connection.execute(self.queries[1]).fetchall()[1][-1],
            "Confirmed Overbought",
        )
        ranked = self.connection.execute(self.queries[7]).fetchall()
        self.assertEqual(len(ranked), 2)
        self.assertTrue(all(row[1] is not None for row in ranked))

    def test_streak_requires_three_prior_negative_returns(self):
        self.insert(
            [(50, 1, 0.1, value) for value in [None, -0.1, -0.1, -0.1, 0.2, 0.3]]
        )
        rows = self.connection.execute(self.queries[6]).fetchall()
        self.assertTrue(all(row[-1] is None for row in rows[:4]))
        self.assertEqual(rows[4][-1], "After 3-Day Losing Streak")
        self.assertAlmostEqual(rows[4][1], 0.3)
        self.assertEqual(rows[5][-1], "Normal Setup")
        self.assertIsNone(rows[5][1])

    def test_zone_baseline_uses_the_same_eligible_next_day_sample(self):
        self.insert([(None, None, None, -0.5)] * 60 + [(20, -1, 0.1, 0.1)] * 70)
        rows = self.connection.execute(self.queries[3]).fetchall()
        self.assertEqual(len(rows), 1)
        zone, count, win_rate, baseline, edge = rows[0]
        self.assertEqual(
            (zone, count, win_rate, baseline, edge), ("Oversold", 69, 100.0, 100.0, 0.0)
        )


if __name__ == "__main__":
    unittest.main()
