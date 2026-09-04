# Equity SQL Analytics

MySQL analyses and a Python feature builder explore NVIDIA technical signals
and an S&P 500 fundamentals screener.

[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](LICENSE)
[![Status](https://img.shields.io/badge/status-research%20prototype-orange)](docs/maintenance.md)

## Quickstart: inspect the committed sample

Requires Python 3.12 or newer. This offline example needs no database, account,
downloaded market data, or third-party Python packages.

```bash
git clone https://github.com/marinasofia/equity-sql-analytics.git
cd equity-sql-analytics
python3 scripts/build_features.py --help
python3 - <<'PY'
import csv
from pathlib import Path
with Path("sample/features_engineered_sample.csv").open(newline="") as source:
    rows = list(csv.DictReader(source))
print(f"{len(rows)} synthetic observations")
print("Columns:", ", ".join(rows[0]))
PY
```

Expect 400 synthetic observations. The sample is for exercising queries; it
cannot reproduce the historical NVIDIA results described in `NVIDIA.sql`.

## Architecture and features

`daily close CSV -> scripts/build_features.py -> indicator CSV -> MySQL table -> SQL queries`

- `scripts/build_features.py` computes daily returns, Wilder RSI, MACD, and
  annualized rolling volatility using the Python standard library.
- `schema.sql` defines the date/indicator table and a `LOAD DATA` template.
- `NVIDIA.sql` explores CASE expressions, windows, conditional aggregation,
  subqueries, and next-day outcomes.
- `S&P500.sql` defines a separate schema and screening queries using prices
  and fundamentals. It requires your own input data.
- `sample/features_engineered_sample.csv` contains a committed synthetic series.

## Findings and limitations

The NVIDIA notebook-style SQL narrative documents a methodological correction:
same-day RSI and returns measured the same price movement. Aligning today's
indicator with the next day's return using `LEAD()` removes that circularity.
The historical analysis reports little directional advantage over its baseline.
The exact real-data snapshot is not included, so the numerical claims cannot
be reproduced from the sample alone. The fundamentals screener is a separate
descriptive analysis; the timing result does not validate a selection strategy.

The current complete SQL script is **not a working end-to-end quickstart**:
query 7 references `Close_Lag_1`, `Close_Lag_2`, and `Close_Lag_3`, which the
provided schema and feature builder do not supply. Warm-up NULL handling and
baseline denominators also need correction before interpreting aggregates.
These limitations are tracked below, rather than hidden behind a green CI badge.

## Generate features from your own data

Use ISO dates, unique observations, and finite positive split-adjusted closing
prices. Normalize your export to `Date,Close`; if both `Close` and `Adj Close`
are present, the current parser chooses `Close`. These input requirements are
not all enforced by the current implementation.

```bash
mkdir -p data outputs
# Place an authorized Date,Close export at data/prices.csv first.
python3 scripts/build_features.py data/prices.csv -o outputs/features.csv
```

No dependency installation is needed. The output columns match `schema.sql`.
Record the source, adjustment policy, date range, and checksum with each
analysis. Do not commit a vendor dataset unless its terms permit redistribution.

## MySQL development setup

Use MySQL 8.0 or newer with a disposable local database and an account allowed
to create tables in it. The schema drops and recreates `features_engineered`.
Database credentials belong in your local client configuration or password
prompt, not in this repository or command history.

```bash
mysql -u YOUR_LOCAL_USER -p -e 'CREATE DATABASE IF NOT EXISTS equity_demo;'
mysql -u YOUR_LOCAL_USER -p equity_demo < schema.sql
```

Replace `YOUR_LOCAL_USER` with your local database user. To import the sample,
adapt the `LOAD DATA` template in `schema.sql` to an absolute local path. Some
MySQL installations disable `LOCAL INFILE`; enable it only for an intentional
local import under your database policy. Read the SQL sections individually
until the schema/query integration issue is fixed. `S&P500.sql` manages its
own schema and has separate price/fundamental import requirements.

## Development and roadmap

There is no automated test suite or CI gate yet. Use the checks in
[CONTRIBUTING.md](CONTRIBUTING.md); they validate syntax and sample structure,
not SQL correctness or historical results.

TODO: implement the [MySQL reproducibility and validation follow-up](https://github.com/marinasofia/equity-sql-analytics/issues/1).
It covers query/schema alignment, warm-up behavior, date/price contracts,
point-in-time joins, dataset provenance, and automated integration tests.

See [maintainer guidance](docs/maintenance.md), [CHANGELOG.md](CHANGELOG.md),
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), and [SECURITY.md](SECURITY.md).

## License

Repository code is [MIT licensed](LICENSE). External market datasets retain
their own terms. The committed sample is synthetic.
