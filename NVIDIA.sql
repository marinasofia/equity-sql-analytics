/* ============================================================
   CASE + Subqueries Lab
   Data: NVIDIA stock, one row per trading day, 2010-present, 4094 rows
   Table: features_engineered
   ============================================================

   Plain-language guide to the columns used:
     RSI (Relative Strength Index) = how fast the price rose or fell lately (0-100).
            Over 70 = rose fast ("overbought"). Under 30 = fell fast ("oversold").
     MACD (Moving Average Convergence Divergence) = which way the trend points. Positive = up, negative = down.
     Volatility = how much the price is swinging, up or down.
     Daily_Return = how much the price moved that day.

   The common trading rule: oversold = about to bounce up, overbought =
   about to fall. These queries test if that was true for NVIDIA.

   One key fix: Daily_Return is the SAME day as the indicator, so comparing
   them is circular (RSI is high because the price already went up). To test
   a real prediction, the queries use LEAD() to grab the NEXT day's return.

   One key check: NVIDIA went up on ~52-54% of all days anyway. So a "win
   rate" only means something if it beats that baseline, not if it beats 50%.
   ============================================================ */


/* ============================================================
   1. BASIC CASE
   Tag each day as Oversold / Neutral / Overbought by its RSI,
   and show what the price did the next day.
   ============================================================ */
SELECT
    `Date`,
    RSI,
    LEAD(Daily_Return) OVER (ORDER BY `Date`) AS next_day_return,
    CASE
        WHEN RSI IS NULL THEN NULL
        WHEN RSI < 30 THEN 'Oversold'
        WHEN RSI < 70 THEN 'Neutral'
        ELSE 'Overbought'
    END AS rsi_zone
FROM features_engineered
ORDER BY `Date`;


/* ============================================================
   2. COMPOUND CASE
   Find days where RSI and MACD agree. Two signals pointing the
   same way is stronger than one.
   ============================================================ */
SELECT
    `Date`,
    RSI,
    MACD,
    LEAD(Daily_Return) OVER (ORDER BY `Date`) AS next_day_return,
    CASE
        WHEN RSI IS NULL OR MACD IS NULL THEN NULL
        WHEN RSI >= 70 AND MACD > 0 THEN 'Confirmed Overbought'
        WHEN RSI < 30 AND MACD < 0 THEN 'Confirmed Oversold'
        WHEN RSI >= 70 OR RSI < 30 THEN 'Unconfirmed Extreme'
        ELSE 'Neutral'
    END AS momentum_flag
FROM features_engineered
ORDER BY `Date`;


/* ============================================================
   3. CASE INSIDE AN AGGREGATE (pivot)
   Count up days vs down days for each weekday. Do some weekdays
   go up more often than others?
   ============================================================ */
SELECT
    DAYNAME(`Date`) AS weekday,
    COUNT(*) AS total_days,
    SUM(CASE WHEN Daily_Return > 0 THEN 1 ELSE 0 END) AS up_days,
    SUM(CASE WHEN Daily_Return < 0 THEN 1 ELSE 0 END) AS down_days,
    ROUND(100.0 * SUM(CASE WHEN Daily_Return > 0 THEN 1 ELSE 0 END)
          / COUNT(*), 1) AS up_day_pct
FROM features_engineered
WHERE Daily_Return IS NOT NULL
GROUP BY weekday
ORDER BY up_day_pct DESC;


/* ============================================================
   4. CASE + GROUP BY / HAVING   ** main test **
   For each RSI zone: how often was the NEXT day up, and did it beat
   NVIDIA's normal up-day rate? Watch edge_vs_baseline. Near zero = no edge.
   ============================================================ */
WITH nvda AS (
    SELECT
        RSI,
        LEAD(Daily_Return) OVER (ORDER BY `Date`) AS next_day_return
    FROM features_engineered
)
SELECT
    CASE
        WHEN RSI IS NULL THEN NULL
        WHEN RSI < 30 THEN 'Oversold'
        WHEN RSI < 70 THEN 'Neutral'
        ELSE 'Overbought'
    END AS rsi_zone,
    COUNT(*) AS total_days,
    ROUND(100.0 * SUM(CASE WHEN next_day_return > 0 THEN 1 ELSE 0 END)
          / COUNT(*), 1) AS win_rate_pct,
    (SELECT ROUND(100.0 * SUM(CASE WHEN next_day_return > 0 THEN 1 ELSE 0 END)
            / COUNT(*), 1) FROM nvda
     WHERE RSI IS NOT NULL AND next_day_return IS NOT NULL) AS baseline_pct,
    ROUND(
        100.0 * SUM(CASE WHEN next_day_return > 0 THEN 1 ELSE 0 END) / COUNT(*)
        - (SELECT 100.0 * SUM(CASE WHEN next_day_return > 0 THEN 1 ELSE 0 END)
           / COUNT(*) FROM nvda
           WHERE RSI IS NOT NULL AND next_day_return IS NOT NULL),
    1) AS edge_vs_baseline
FROM nvda
WHERE next_day_return IS NOT NULL AND RSI IS NOT NULL
GROUP BY rsi_zone
HAVING total_days > 50
ORDER BY win_rate_pct DESC;


/* ============================================================
   5. CASE + SCALAR SUBQUERY
   Is each day's volatility above the all-time average, or below it?
   ============================================================ */
SELECT
    `Date`,
    Volatility,
    CASE
        WHEN Volatility IS NULL THEN NULL
        WHEN Volatility > (SELECT AVG(Volatility) FROM features_engineered)
        THEN 'High Vol vs History'
        ELSE 'Normal/Low Vol vs History'
    END AS vol_regime
FROM features_engineered
ORDER BY `Date`;


/* ============================================================
   6. CASE + CORRELATED SUBQUERY
   Is each day's volatility high compared to its OWN year? (Comparing a
   2015 day to the 15-year average would be unfair, years differ a lot.)
   ============================================================ */
SELECT
    f1.`Date`,
    YEAR(f1.`Date`) AS trade_year,
    f1.Volatility,
    CASE
        WHEN f1.Volatility IS NULL THEN NULL
        WHEN f1.Volatility > (
            SELECT AVG(f2.Volatility)
            FROM features_engineered f2
            WHERE YEAR(f2.`Date`) = YEAR(f1.`Date`)
        )
        THEN 'High vs Own Year'
        ELSE 'Normal vs Own Year'
    END AS vol_vs_year
FROM features_engineered f1
ORDER BY f1.`Date`;


/* ============================================================
   7. CASE + IN (subquery list)
   Flag days that came right after 3 down days in a row (the classic
   "buy the dip" setup), and show what happened next.
   ============================================================ */
WITH history AS (
    SELECT
        `Date`,
        LAG(Daily_Return, 1) OVER (ORDER BY `Date`) AS previous_1,
        LAG(Daily_Return, 2) OVER (ORDER BY `Date`) AS previous_2,
        LAG(Daily_Return, 3) OVER (ORDER BY `Date`) AS previous_3,
        LEAD(Daily_Return) OVER (ORDER BY `Date`) AS next_day_return
    FROM features_engineered
)
SELECT
    `Date`,
    next_day_return,
    CASE
        WHEN previous_1 IS NULL OR previous_2 IS NULL OR previous_3 IS NULL THEN NULL
        WHEN `Date` IN (
            SELECT `Date` FROM history
            WHERE previous_1 < 0 AND previous_2 < 0 AND previous_3 < 0
        ) THEN 'After 3-Day Losing Streak'
        ELSE 'Normal Setup'
    END AS setup_flag
FROM history
ORDER BY `Date`;


/* ============================================================
   8. CASE IN ORDER BY
   Sort days by signal strength: strongest oversold setups (RSI and
   MACD both agree) at the top.
   ============================================================ */
WITH ranked_inputs AS (
    SELECT `Date`, RSI, MACD, Volatility,
           LEAD(Daily_Return) OVER (ORDER BY `Date`) AS next_day_return
    FROM features_engineered
)
SELECT `Date`, RSI, MACD, Volatility, next_day_return
FROM ranked_inputs
WHERE RSI IS NOT NULL AND MACD IS NOT NULL
ORDER BY
    CASE
        WHEN RSI IS NULL THEN NULL
        WHEN RSI < 30 AND MACD < 0 THEN 1
        WHEN RSI < 30 THEN 2
        ELSE 3
    END,
    RSI ASC
LIMIT 50;


/* ============================================================
   BONUS: REGIME SPLIT
   Does the RSI signal work the same before 2020 vs after? If it flips
   between eras, it is not a real rule, just a quirk of one period.
   ============================================================ */
WITH nvda AS (
    SELECT
        `Date`,
        RSI,
        LEAD(Daily_Return) OVER (ORDER BY `Date`) AS next_day_return
    FROM features_engineered
)
SELECT
    CASE WHEN YEAR(`Date`) < 2020 THEN 'Pre-2020' ELSE '2020-Present' END AS era,
    CASE
        WHEN RSI IS NULL THEN NULL
        WHEN RSI < 30 THEN 'Oversold'
        WHEN RSI < 70 THEN 'Neutral'
        ELSE 'Overbought'
    END AS rsi_zone,
    COUNT(*) AS total_days,
    ROUND(100.0 * SUM(CASE WHEN next_day_return > 0 THEN 1 ELSE 0 END)
          / COUNT(*), 1) AS win_rate_pct
FROM nvda
WHERE next_day_return IS NOT NULL AND RSI IS NOT NULL
GROUP BY era, rsi_zone
HAVING total_days > 30
ORDER BY era, win_rate_pct DESC;


/* ============================================================
   WHAT I FOUND

   Historical observations below predate the corrected NULL handling and
   matched-sample baseline. Recompute them with a pinned input dataset before
   treating these percentages as reproducible results.
   ============================================================

   SUMMARY

   My first version of this analysis made it look like RSI was a strong
   signal for NVDA: overbought days were up 73.5% of the time, oversold
   days only 14.1%. That turned out to be a measurement mistake, RSI was
   high BECAUSE the price had already gone up that same day, so I was
   comparing up days to themselves. Once fixed to compare today's RSI to
   TOMORROW's return instead, the real numbers came out close together
   (roughly 52-55% across every zone, in both eras before and after 2020).
   RSI showed almost no real predictive edge for NVDA once measured
   correctly.

   QUERY 1 - Tag each day by RSI, show what happened the next day
   What I did: labeled every day Oversold, Neutral, or Overbought by RSI,
   then attached tomorrow's return next to it.
   Why: this is the raw material needed before testing the "buy when
   oversold" rule, today's label and tomorrow's outcome side by side.
   What I found: a labeled table used as input for Query 4, no
   conclusion on its own yet.

   QUERY 2 - Check if RSI and MACD agree
   What I did: only tagged a day "confirmed" oversold/overbought if RSI
   AND MACD both agreed, not just one indicator alone.
   Why: one indicator can give a false signal. Two agreeing is a
   stronger, more convincing setup.
   What I found: another labeled table, useful as input for further
   testing rather than a standalone result.

   QUERY 3 - Do certain weekdays perform differently?
   What I did: grouped all days by weekday and counted up days vs down
   days for each.
   Why: some traders believe certain weekdays behave differently. Cheap
   and easy to check directly.
   What I found: up-day rates stayed close to even across weekdays, no
   real weekday effect for NVDA.

   QUERY 4 - Does RSI actually predict tomorrow? (the main test)
   What I did: grouped days by RSI zone, calculated what percent were
   followed by an up day, and compared that against NVDA's overall
   baseline up-day rate.
   Why: a zone only "works" if it beats what you'd get by picking a
   random day. Comparing against 50% instead of the real baseline would
   be misleading.
   What I found: after fixing the same-day/next-day mixup, win rates
   across all three zones landed close together, no zone meaningfully
   beat the baseline. RSI alone did not predict next-day direction.

   QUERY 5 - Is today more volatile than NVDA's entire history?
   What I did: compared each day's volatility to one flat average across
   all 4,094 days.
   Why: volatility is a risk measure, it tells you how big the swings
   are, regardless of direction.
   What I found: a day-by-day High/Normal tag, used as a building block
   for judging whether other results might be skewed by unusually calm
   or unusually wild stretches.

   QUERY 6 - Is today volatile compared to just its own year?
   What I did: same idea as Query 5, but compared each day only to other
   days in the same calendar year.
   Why: volatility isn't constant across 15 years. Comparing every day to
   one flat 15-year average unfairly tags calm years as always-low and
   wild years as always-high.
   What I found: a fairer day-by-day tag that accounts for NVDA's
   volatility drifting across different eras.

   QUERY 7 - Does a 3-day losing streak predict a bounce?
   What I did: flagged days that followed three straight down days, then
   checked what happened the next day after that.
   Why: "buy the dip" is one of the most common trading instincts, worth
   testing directly instead of assuming it works.
   What I found: a direct comparison table between post-losing-streak
   days and normal days.

   QUERY 8 - Rank the strongest oversold setups
   What I did: sorted all days so the ones where RSI and MACD most
   strongly agreed something was oversold appear first.
   Why: instead of trusting one summary number, this lets you look at
   the actual specific days behind the pattern, useful for sanity-
   checking Query 4's finding against real examples.
   What I found: a shortlist of the 50 most textbook oversold setups,
   with next-day return next to each one to eyeball whether they
   actually bounced.

   BONUS - Does the RSI signal work differently before vs after 2020?
   What I did: split Query 4's test into two time periods (Pre-2020 vs
   2020-Present) and compared them.
   Why: if a signal only "works" in one era and not another, it's not a
   real rule, just a quirk of that period.
   What I found: win rates stayed close together in both eras (roughly
   51.7% to 54.8%), no meaningful difference between RSI zones in either
   period. Oversold days were also so rare after 2020 that there weren't
   even 30 to include.

   BOTTOM LINE
   One stock, one long uptrend, and roughly one bear market cannot prove
   anything about markets in general, only about NVIDIA's own history.
   The RSI rule did not hold up once measured correctly, and the biggest
   lesson was methodological: a look-ahead bias that would have produced
   a confident, wrong answer if left uncorrected.
   ============================================================ */