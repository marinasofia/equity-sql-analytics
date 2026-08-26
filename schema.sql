/* ============================================================
   Schema for NVIDIA.sql

   NVIDIA.sql queries a single table, features_engineered: one row per
   trading day, with the technical indicators already computed. This file
   creates it. Two ways to fill it, both documented in the README:

     1. scripts/build_features.py, which computes the indicators from any
        daily OHLCV CSV. This is the path that reproduces the findings in
        NVIDIA.sql, using the real NVIDIA series from 2010 onward.
     2. sample/features_engineered_sample.csv, a small synthetic series
        committed here so the queries run immediately with no download.
        It is synthetic. It will not reproduce the documented findings.

   Requires MySQL 8.0+ for the window functions used in NVIDIA.sql.
   ============================================================ */

DROP TABLE IF EXISTS features_engineered;

CREATE TABLE features_engineered (
    `Date`        DATE          NOT NULL,
    RSI           DECIMAL(6, 3) NULL,   -- Wilder 14 period, 0 to 100
    MACD          DECIMAL(9, 4) NULL,   -- 12/26 EMA difference
    Volatility    DECIMAL(9, 6) NULL,   -- 20 day stdev of daily return, annualized
    Daily_Return  DECIMAL(9, 6) NULL,   -- close to close, same day as the indicators
    PRIMARY KEY (`Date`)
);

/* The first rows of any series have NULL indicators: RSI needs 14 prior
   days, MACD needs 26, Volatility needs 20. They are NULL rather than 0 so
   the warm-up period is excluded from aggregates instead of being counted
   as a real reading of zero. */

/* Load the sample:

   LOAD DATA LOCAL INFILE 'sample/features_engineered_sample.csv'
   INTO TABLE features_engineered
   FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
   LINES TERMINATED BY '\n'
   IGNORE 1 ROWS
   (`Date`, @rsi, @macd, @vol, @ret)
   SET RSI          = NULLIF(@rsi,  ''),
       MACD         = NULLIF(@macd, ''),
       Volatility   = NULLIF(@vol,  ''),
       Daily_Return = NULLIF(@ret,  '');
*/
