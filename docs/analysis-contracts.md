# Numerical and query contracts

CSV ingestion accepts ISO dates or ISO timestamps and normalizes them to dates.
Duplicate dates are rejected after normalization. It sorts observations and
rejects empty input, mismatched row width, duplicate normalized headers, and
nonfinite or nonpositive closes. Closing prices must already have the intended
split adjustment and provenance. When both Close and Adj Close exist, Close wins.

EMA uses a simple-average seed after a full window. RSI uses Wilder smoothing,
with 14 missing warm-up rows by default. The existing convention for a flat
series is RSI 100 when both average gain and average loss are zero. Rolling
volatility uses sample variance over 20 returns, annualized by sqrt(252).
Indicators depend only on the current and earlier observations. Tests use seeded
synthetic series to check bounded RSI, prefix stability, and exact small cases.

Feature output is written through a same-directory temporary file and atomic
replacement. Failed writes preserve a previous destination. This does not
provide concurrent-writer locking or fsync crash durability.

The SQL queries derive next-day outcomes with LEAD before filtering eligible
indicator rows. Warm-up NULLs are not treated as observed RSI or volatility.
The main RSI baseline uses the same nonmissing indicator/outcome sample as its
zone statistics. Query 7 requires three prior negative daily returns and marks
insufficient history as NULL. The published percentages are historical notes;
they were not recomputed in this change.

All nine NVIDIA query bodies execute against synthetic rows in SQLite tests,
using YEAR and DAYNAME adapters. This checks column compatibility, window
alignment, NULL handling, streak logic, and baseline arithmetic. It does not
verify MySQL DDL, LOAD DATA, server permissions, collation, or query plans.
Queries 5 and 6 compare against whole-history or whole-year volatility and are
descriptive; they are not point-in-time trading signals.

TODO: MySQL integration, pinned source-data provenance, point-in-time fundamental
inputs, and recomputed historical results remain tracked in
[issue 1](https://github.com/marinasofia/equity-sql-analytics/issues/1).
