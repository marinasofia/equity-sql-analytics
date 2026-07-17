# Equity SQL Analytics

Two MySQL projects that form one thesis: test honestly whether market-timing signals actually work, then, when they don't, screen stocks on fundamentals and risk-adjusted return instead.

## Headline finding

My first version of the RSI backtest showed overbought NVIDIA days closing up 73.5% of the time, a strong-looking signal. It was wrong. RSI was high *because* the price had already risen that same day, so the query was comparing up days to themselves (look-ahead bias). After fixing the test to compare today's RSI against **tomorrow's** return with `LEAD()`, and benchmarking against NVIDIA's true base rate (52 to 54% of all days close up) instead of 50%, the edge disappeared: win rates landed within a few points of baseline in every RSI zone, in both the pre-2020 and post-2020 eras. RSI alone showed no real predictive edge for NVDA once measured correctly.

## Why these two together

`NVIDIA.sql` asks whether entry timing via technical signals works, and after correcting for look-ahead bias it concludes the signals don't beat the base rate. `S&P500.sql` is the consequence: if timing fails, selection should be driven by fundamentals and risk-adjusted return, so it builds a screener on P/E, debt-to-equity, and Sharpe ratio. Together they form one thesis: measure timing claims honestly, then allocate on fundamentals.

## Files

| File | What it is |
|---|---|
| `NVIDIA.sql` | RSI/MACD signal backtest over 4,094 NVIDIA trading days (2010 to present). Eight queries plus a regime-split bonus: signal tagging with `CASE`, next-day returns via `LEAD()`, win rates vs. base rate with scalar subqueries, per-year volatility regimes with correlated subqueries, weekday effects, and "buy the dip" losing-streak setups. A full written findings section ("WHAT I FOUND") is at the bottom of the file. |
| `S&P500.sql` | Investment-analysis schema (`securities` / `price_history` / `fundamentals` with FKs and a unique security+date constraint) plus analytics: daily returns via `LAG()`, 20/50-day moving averages with window frames, annualized volatility (√252), Sharpe ratio (4% risk-free assumption), and a multi-CTE screener filtering on P/E 5 to 25, debt-to-equity < 1.0, and Sharpe > 0.5. |
| `sector_mapping.csv` | S&P 500 constituents mapped to sectors (492 companies), for joining sector context onto screener output. |
| `practice/` | Earlier guided labs (CASE-statement and JOIN exercises), kept for completeness. |

## SQL techniques demonstrated

Window functions (`LEAD`, `LAG`, rolling `AVG` with `ROWS BETWEEN`, `PARTITION BY`), multi-stage CTEs, correlated and scalar subqueries, conditional aggregation pivots (`SUM(CASE ...)`), `CASE` in `ORDER BY`, `HAVING` with minimum-sample-size guards, and schema design with integrity constraints.

## Running it

Requires **MySQL 8.0+** (window functions and CTEs).

- `NVIDIA.sql` expects a `features_engineered` table (one row per trading day with `Date`, `RSI`, `MACD`, `Volatility`, `Daily_Return`, and lagged closes), built from NVIDIA daily OHLCV data with standard technical-indicator feature engineering.
- `S&P500.sql` creates its own schema; a commented `LOAD DATA` template shows how to load your own price CSV. Queries run against whatever prices/fundamentals you load.

## Honest limitations

One stock, one long uptrend, and roughly one bear market can't prove anything about markets in general, only about NVIDIA's own history. The value of the backtest is methodological: measuring signals against next-day outcomes, benchmarking against the true base rate, enforcing minimum sample sizes, and checking that results hold across market regimes.
