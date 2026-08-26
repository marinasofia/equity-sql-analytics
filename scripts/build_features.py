"""Build the features_engineered table from a daily OHLCV CSV.

    python scripts/build_features.py NVDA.csv -o features_engineered.csv

The input needs a date column and a close column. Anything else is ignored.
Column names are matched case insensitively, so the usual exports (Yahoo
Finance, Stooq, a broker download) work without editing.

This is the path that reproduces the numbers written up in NVIDIA.sql: the
full NVIDIA daily series from 2010 onward, roughly 4,094 trading days.

Indicator definitions, stated because they vary between implementations:

  Daily_Return  close over previous close, minus 1. Same day as the
                indicators, which is exactly the circularity NVIDIA.sql
                corrects for with LEAD().
  RSI           Wilder's 14 period smoothing, not a simple moving average.
                The two disagree by a few points, which matters when the
                queries bucket on 30 and 70.
  MACD          12 period EMA minus 26 period EMA.
  Volatility    20 day rolling standard deviation of Daily_Return,
                annualized by sqrt(252).

Warm-up rows are left empty rather than filled, so they load as NULL and
drop out of aggregates instead of counting as a reading of zero.

On seeding: RSI and MACD here are seeded on the first full window's simple
average, which is Wilder's original definition. pandas `ewm(adjust=False)`
seeds on the first observation instead. The two agree to within 0.002 by
about 100 rows in and are identical by 200, but they differ by up to 6 RSI
points immediately after the warm-up period. Checked against a pandas
reference on the sample series: Daily_Return and Volatility match exactly.
"""
import argparse
import csv
import math
import sys


def read_series(path):
    """Return [(date_string, close_float)] sorted by date."""
    with open(path, newline="") as f:
        rows = list(csv.DictReader(f))
    if not rows:
        sys.exit(f"{path} has no data rows")

    cols = {k.lower().strip(): k for k in rows[0]}
    date_col = next((cols[c] for c in ("date", "datetime", "timestamp") if c in cols), None)
    close_col = next((cols[c] for c in ("close", "adj close", "close/last", "closeprice")
                      if c in cols), None)
    if not date_col or not close_col:
        sys.exit(f"could not find a date and close column in {list(rows[0])}")

    out = []
    for r in rows:
        raw = (r[close_col] or "").strip().replace("$", "").replace(",", "")
        if not raw:
            continue
        out.append((r[date_col].strip()[:10], float(raw)))
    out.sort(key=lambda t: t[0])
    return out


def ema(values, span):
    """Exponential moving average, None until `span` values are available."""
    k = 2 / (span + 1)
    out, acc = [], None
    for i, v in enumerate(values):
        if i + 1 < span:
            out.append(None)
            continue
        if acc is None:
            acc = sum(values[: span]) / span   # seed on the first full window
        else:
            acc = v * k + acc * (1 - k)
        out.append(acc)
    return out


def wilder_rsi(closes, period=14):
    """Wilder-smoothed RSI. None for the first `period` rows."""
    out = [None] * len(closes)
    if len(closes) <= period:
        return out
    gains = [max(closes[i] - closes[i - 1], 0.0) for i in range(1, len(closes))]
    losses = [max(closes[i - 1] - closes[i], 0.0) for i in range(1, len(closes))]

    avg_gain = sum(gains[:period]) / period
    avg_loss = sum(losses[:period]) / period
    for i in range(period, len(closes)):
        if i > period:  # smooth forward
            avg_gain = (avg_gain * (period - 1) + gains[i - 1]) / period
            avg_loss = (avg_loss * (period - 1) + losses[i - 1]) / period
        if avg_loss == 0:
            out[i] = 100.0
        else:
            rs = avg_gain / avg_loss
            out[i] = 100 - (100 / (1 + rs))
    return out


def rolling_vol(returns, window=20, periods_per_year=252):
    out = [None] * len(returns)
    for i in range(window, len(returns)):
        w = [r for r in returns[i - window + 1: i + 1] if r is not None]
        if len(w) < window:
            continue
        mean = sum(w) / len(w)
        var = sum((x - mean) ** 2 for x in w) / (len(w) - 1)
        out[i] = math.sqrt(var) * math.sqrt(periods_per_year)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("csv", help="daily OHLCV csv with a date and a close column")
    ap.add_argument("-o", "--out", default="features_engineered.csv")
    args = ap.parse_args()

    series = read_series(args.csv)
    dates = [d for d, _ in series]
    closes = [c for _, c in series]

    returns = [None] + [closes[i] / closes[i - 1] - 1 for i in range(1, len(closes))]
    rsi = wilder_rsi(closes)
    ema12, ema26 = ema(closes, 12), ema(closes, 26)
    macd = [None if (a is None or b is None) else a - b for a, b in zip(ema12, ema26)]
    vol = rolling_vol(returns)

    def fmt(x, places):
        return "" if x is None else f"{x:.{places}f}"

    with open(args.out, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["Date", "RSI", "MACD", "Volatility", "Daily_Return"])
        for i, d in enumerate(dates):
            w.writerow([d, fmt(rsi[i], 3), fmt(macd[i], 4),
                        fmt(vol[i], 6), fmt(returns[i], 6)])

    warm = sum(1 for i in range(len(dates)) if rsi[i] is None or macd[i] is None)
    print(f"wrote {args.out}: {len(dates)} rows, {warm} warm-up rows with NULL indicators")
    print(f"date range {dates[0]} to {dates[-1]}")


if __name__ == "__main__":
    main()
