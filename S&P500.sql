-- ============================================
-- INVESTMENT ANALYSIS DATABASE
-- Schema + analytical queries for stock screening
-- Run each section in MySQL Workbench
-- ============================================

-- ============================================
-- SECTION 1: SCHEMA
-- ============================================

CREATE DATABASE IF NOT EXISTS investment_analysis;
USE investment_analysis;

CREATE TABLE securities (
    security_id INT AUTO_INCREMENT PRIMARY KEY,
    ticker VARCHAR(10) NOT NULL UNIQUE,
    company_name VARCHAR(100),
    sector VARCHAR(50)
);

CREATE TABLE price_history (
    price_id INT AUTO_INCREMENT PRIMARY KEY,
    security_id INT NOT NULL,
    trade_date DATE NOT NULL,
    open_price DECIMAL(12,4),
    high_price DECIMAL(12,4),
    low_price DECIMAL(12,4),
    close_price DECIMAL(12,4),
    volume BIGINT,
    FOREIGN KEY (security_id) REFERENCES securities(security_id),
    UNIQUE KEY uq_security_date (security_id, trade_date)
);

CREATE TABLE fundamentals (
    fundamental_id INT AUTO_INCREMENT PRIMARY KEY,
    security_id INT NOT NULL,
    report_date DATE NOT NULL,
    pe_ratio DECIMAL(10,2),
    eps DECIMAL(10,2),
    dividend_yield DECIMAL(6,3),
    debt_to_equity DECIMAL(10,3),
    roe DECIMAL(6,3),
    market_cap BIGINT,
    FOREIGN KEY (security_id) REFERENCES securities(security_id)
);

-- To load price data from a CSV (e.g. your S&P 500 dataset):
-- LOAD DATA LOCAL INFILE '/path/to/your.csv'
-- INTO TABLE price_history
-- FIELDS TERMINATED BY ',' ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS
-- (security_id, trade_date, open_price, high_price, low_price, close_price, volume);


-- ============================================
-- SECTION 2: DAILY RETURNS
-- ============================================

SELECT
    security_id,
    trade_date,
    close_price,
    (close_price - LAG(close_price) OVER (PARTITION BY security_id ORDER BY trade_date))
        / LAG(close_price) OVER (PARTITION BY security_id ORDER BY trade_date) AS daily_return
FROM price_history;


-- ============================================
-- SECTION 3: MOVING AVERAGES
-- ============================================

SELECT
    security_id,
    trade_date,
    close_price,
    AVG(close_price) OVER (PARTITION BY security_id ORDER BY trade_date
        ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) AS ma_20,
    AVG(close_price) OVER (PARTITION BY security_id ORDER BY trade_date
        ROWS BETWEEN 49 PRECEDING AND CURRENT ROW) AS ma_50
FROM price_history;


-- ============================================
-- SECTION 4: ANNUALIZED VOLATILITY
-- ============================================

WITH returns AS (
    SELECT
        security_id,
        trade_date,
        (close_price - LAG(close_price) OVER (PARTITION BY security_id ORDER BY trade_date))
            / LAG(close_price) OVER (PARTITION BY security_id ORDER BY trade_date) AS daily_return
    FROM price_history
)
SELECT
    security_id,
    STDDEV(daily_return) * SQRT(252) AS annualized_volatility
FROM returns
WHERE daily_return IS NOT NULL
GROUP BY security_id;


-- ============================================
-- SECTION 5: RISK ADJUSTED RETURN (SHARPE RATIO)
-- Assumes a 4% risk free rate, adjust as needed
-- ============================================

WITH returns AS (
    SELECT
        security_id,
        trade_date,
        (close_price - LAG(close_price) OVER (PARTITION BY security_id ORDER BY trade_date))
            / LAG(close_price) OVER (PARTITION BY security_id ORDER BY trade_date) AS daily_return
    FROM price_history
),
metrics AS (
    SELECT
        security_id,
        AVG(daily_return) * 252 AS annualized_return,
        STDDEV(daily_return) * SQRT(252) AS annualized_volatility
    FROM returns
    WHERE daily_return IS NOT NULL
    GROUP BY security_id
)
SELECT
    security_id,
    annualized_return,
    annualized_volatility,
    (annualized_return - 0.04) / annualized_volatility AS sharpe_ratio
FROM metrics;


-- ============================================
-- SECTION 6: STOCK SCREENER
-- Combines valuation, leverage, and risk adjusted return
-- Adjust thresholds to match your risk tolerance
-- ============================================

WITH returns AS (
    SELECT
        security_id,
        trade_date,
        (close_price - LAG(close_price) OVER (PARTITION BY security_id ORDER BY trade_date))
            / LAG(close_price) OVER (PARTITION BY security_id ORDER BY trade_date) AS daily_return
    FROM price_history
),
metrics AS (
    SELECT
        security_id,
        AVG(daily_return) * 252 AS annualized_return,
        STDDEV(daily_return) * SQRT(252) AS annualized_volatility
    FROM returns
    WHERE daily_return IS NOT NULL
    GROUP BY security_id
),
sharpe AS (
    SELECT
        security_id,
        annualized_return,
        annualized_volatility,
        (annualized_return - 0.04) / annualized_volatility AS sharpe_ratio
    FROM metrics
)
SELECT
    s.ticker,
    s.company_name,
    f.pe_ratio,
    f.dividend_yield,
    f.debt_to_equity,
    f.roe,
    sh.annualized_return,
    sh.annualized_volatility,
    sh.sharpe_ratio
FROM securities s
JOIN fundamentals f ON f.security_id = s.security_id
JOIN sharpe sh ON sh.security_id = s.security_id
WHERE f.pe_ratio BETWEEN 5 AND 25
    AND f.debt_to_equity < 1.0
    AND sh.sharpe_ratio > 0.5
ORDER BY sh.sharpe_ratio DESC;