-- =====================================================================
-- Bank term-deposit campaign analysis: SQL version of the key analyses
-- Table: calls  (loaded from bank-additional-full.csv, one row per call)
-- Written in standard SQL and tested on SQLite. Runs on PostgreSQL / MySQL
-- with at most minor changes (e.g. quoting of column names containing dots).
-- =====================================================================

-- 1. Overall KPIs
SELECT COUNT(*)                                        AS total_calls,
       SUM(CASE WHEN y = 'yes' THEN 1 ELSE 0 END)      AS subscriptions,
       ROUND(AVG(CASE WHEN y = 'yes' THEN 1.0 ELSE 0 END) * 100, 2) AS conv_rate_pct
FROM calls;

-- 2. Conversion by contact channel (channel mix)
SELECT contact,
       COUNT(*) AS calls,
       ROUND(AVG(CASE WHEN y = 'yes' THEN 1.0 ELSE 0 END) * 100, 2) AS conv_rate_pct
FROM calls
GROUP BY contact
ORDER BY conv_rate_pct DESC;

-- 3. Month-wise volume vs conversion: is effort going to the right months?
WITH m AS (
    SELECT month,
           COUNT(*) AS calls,
           AVG(CASE WHEN y = 'yes' THEN 1.0 ELSE 0 END) AS conv_rate
    FROM calls
    GROUP BY month
)
SELECT month,
       calls,
       ROUND(calls * 100.0 / SUM(calls) OVER (), 1) AS share_of_calls_pct,
       ROUND(conv_rate * 100, 2)                     AS conv_rate_pct,
       RANK() OVER (ORDER BY conv_rate DESC)         AS conv_rank
FROM m
ORDER BY share_of_calls_pct DESC;

-- 4. Past responders: outcome of the previous campaign
SELECT poutcome,
       COUNT(*) AS calls,
       ROUND(AVG(CASE WHEN y = 'yes' THEN 1.0 ELSE 0 END) * 100, 2) AS conv_rate_pct
FROM calls
GROUP BY poutcome
ORDER BY conv_rate_pct DESC;

-- 5. Age-band segmentation with lift vs overall average
WITH base AS (SELECT AVG(CASE WHEN y = 'yes' THEN 1.0 ELSE 0 END) AS avg_rate FROM calls),
seg AS (
    SELECT CASE WHEN age <= 25 THEN 'Up to 25'
                WHEN age <= 35 THEN '26-35'
                WHEN age <= 45 THEN '36-45'
                WHEN age <= 55 THEN '46-55'
                WHEN age <= 65 THEN '56-65'
                ELSE '65+' END AS age_band,
           y
    FROM calls
)
SELECT age_band,
       COUNT(*) AS calls,
       ROUND(AVG(CASE WHEN y = 'yes' THEN 1.0 ELSE 0 END) * 100, 2) AS conv_rate_pct,
       ROUND(AVG(CASE WHEN y = 'yes' THEN 1.0 ELSE 0 END) / (SELECT avg_rate FROM base), 2) AS lift
FROM seg
GROUP BY age_band
ORDER BY lift DESC;

-- 6. Call fatigue: conversion by number of calls made to the same customer
SELECT CASE WHEN campaign >= 11 THEN '11+'
            WHEN campaign >= 8  THEN '08-10'
            WHEN campaign >= 6  THEN '06-07'
            ELSE '0' || campaign END AS calls_made,
       COUNT(*) AS customers,
       ROUND(AVG(CASE WHEN y = 'yes' THEN 1.0 ELSE 0 END) * 100, 2) AS conv_rate_pct
FROM calls
GROUP BY calls_made
ORDER BY calls_made;

-- 7. Top 5 job x channel combinations (min. 200 calls) - candidate target segments
SELECT job, contact,
       COUNT(*) AS calls,
       ROUND(AVG(CASE WHEN y = 'yes' THEN 1.0 ELSE 0 END) * 100, 2) AS conv_rate_pct
FROM calls
GROUP BY job, contact
HAVING COUNT(*) >= 200
ORDER BY conv_rate_pct DESC
LIMIT 5;

-- 8. Interest-rate environment vs deposit demand
SELECT CASE WHEN euribor3m < 1.5 THEN '1. Low (<1.5%)'
            WHEN euribor3m < 4.0 THEN '2. Mid (1.5-4%)'
            ELSE '3. High (>4%)' END AS rate_regime,
       COUNT(*) AS calls,
       ROUND(AVG(CASE WHEN y = 'yes' THEN 1.0 ELSE 0 END) * 100, 2) AS conv_rate_pct
FROM calls
GROUP BY rate_regime
ORDER BY rate_regime;
