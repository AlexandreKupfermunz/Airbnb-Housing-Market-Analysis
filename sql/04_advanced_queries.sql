-- =====================================================================
-- Airbnb Housing Market Analysis Database
-- File: 04_advanced_queries.sql
-- Purpose: Advanced analytical queries showcasing joins, aggregation,
--          subqueries, and window functions.
-- Run after 01_schema.sql and 02_mock_data.sql.
-- =====================================================================

USE airbnb_market;

-- =====================================================================
-- QUERY 1: Average nightly price and active listing count per neighborhood
-- (multi-table JOIN + GROUP BY + aggregate functions, most recent snapshot only)
-- =====================================================================
SELECT
    c.name                              AS city,
    n.name                               AS neighborhood,
    COUNT(DISTINCT l.listing_id)         AS active_listings,
    ROUND(AVG(latest.nightly_price), 2)  AS avg_nightly_price,
    ROUND(MIN(latest.nightly_price), 2)  AS min_nightly_price,
    ROUND(MAX(latest.nightly_price), 2)  AS max_nightly_price
FROM neighborhood n
JOIN city c            ON c.city_id = n.city_id
JOIN property p         ON p.neighborhood_id = n.neighborhood_id
JOIN listing l           ON l.property_id = p.property_id
JOIN listing_snapshot latest
     ON latest.listing_id = l.listing_id
    AND latest.snapshot_date = (
        SELECT MAX(ls2.snapshot_date)
        FROM listing_snapshot ls2
        WHERE ls2.listing_id = l.listing_id
    )
WHERE latest.active = TRUE
GROUP BY c.name, n.name
ORDER BY avg_nightly_price DESC;


-- =====================================================================
-- QUERY 2: Hosts managing more than one property, with portfolio size
-- and total number of listings across platforms
-- (subquery/derived table + HAVING + aggregate join)
-- =====================================================================
SELECT
    h.host_id,
    h.host_type,
    h.verified,
    COUNT(DISTINCT hp.property_id) AS properties_owned,
    COUNT(DISTINCT l.listing_id)   AS total_listings
FROM host h
JOIN host_property hp ON hp.host_id = h.host_id
LEFT JOIN listing l    ON l.host_id = h.host_id
GROUP BY h.host_id, h.host_type, h.verified
HAVING COUNT(DISTINCT hp.property_id) > 1
ORDER BY properties_owned DESC, total_listings DESC;


-- =====================================================================
-- QUERY 3: Price ranking of listings within their own neighborhood
-- (window function: RANK() OVER PARTITION BY)
-- =====================================================================
SELECT
    n.name                    AS neighborhood,
    l.listing_id,
    p.property_type,
    latest.nightly_price,
    RANK() OVER (
        PARTITION BY n.neighborhood_id
        ORDER BY latest.nightly_price DESC
    ) AS price_rank_in_neighborhood
FROM listing l
JOIN property p ON p.property_id = l.property_id
JOIN neighborhood n ON n.neighborhood_id = p.neighborhood_id
JOIN listing_snapshot latest
     ON latest.listing_id = l.listing_id
    AND latest.snapshot_date = (
        SELECT MAX(ls2.snapshot_date)
        FROM listing_snapshot ls2
        WHERE ls2.listing_id = l.listing_id
    )
ORDER BY n.name, price_rank_in_neighborhood;


-- =====================================================================
-- QUERY 4: Month-over-month price growth per listing vs. neighborhood
-- long-term rent growth, comparing April -> June 2024
-- (CTEs + window function LAG + join across fact tables)
-- =====================================================================
WITH listing_growth AS (
    SELECT
        ls.listing_id,
        ls.snapshot_date,
        ls.nightly_price,
        LAG(ls.nightly_price) OVER (
            PARTITION BY ls.listing_id ORDER BY ls.snapshot_date
        ) AS previous_price
    FROM listing_snapshot ls
),
rent_growth AS (
    SELECT
        hmo.neighborhood_id,
        hmo.observation_date,
        hmo.avg_rent_per_m2,
        LAG(hmo.avg_rent_per_m2) OVER (
            PARTITION BY hmo.neighborhood_id ORDER BY hmo.observation_date
        ) AS previous_rent
    FROM housing_market_observation hmo
)
SELECT
    n.name                                                         AS neighborhood,
    l.listing_id,
    lg.snapshot_date,
    ROUND(100 * (lg.nightly_price - lg.previous_price) / lg.previous_price, 2)  AS listing_price_growth_pct,
    ROUND(100 * (rg.avg_rent_per_m2 - rg.previous_rent) / rg.previous_rent, 2)  AS neighborhood_rent_growth_pct
FROM listing_growth lg
JOIN listing l          ON l.listing_id = lg.listing_id
JOIN property p          ON p.property_id = l.property_id
JOIN neighborhood n       ON n.neighborhood_id = p.neighborhood_id
JOIN rent_growth rg       ON rg.neighborhood_id = n.neighborhood_id
                          AND rg.observation_date = '2024-04-01'
WHERE lg.previous_price IS NOT NULL
ORDER BY neighborhood, l.listing_id, lg.snapshot_date;


-- =====================================================================
-- QUERY 5: Neighborhoods under an active regulation together with the
-- number of listings that would violate an annual_night_limit
-- (based on estimated nights booked = 365 - available_days_next_365)
-- (M:N join through the junction table + correlated subquery + CASE)
-- =====================================================================
SELECT
    n.name                     AS neighborhood,
    r.regulation_type,
    r.annual_night_limit,
    COUNT(DISTINCT l.listing_id) AS total_listings,
    SUM(
        CASE
            WHEN r.annual_night_limit IS NOT NULL
             AND (365 - latest.available_days_next_365) > r.annual_night_limit
            THEN 1 ELSE 0
        END
    ) AS listings_over_limit
FROM regulation r
JOIN regulation_area ra ON ra.regulation_id = r.regulation_id
JOIN neighborhood n      ON n.neighborhood_id = ra.neighborhood_id
JOIN property p           ON p.neighborhood_id = n.neighborhood_id
JOIN listing l             ON l.property_id = p.property_id
JOIN listing_snapshot latest
     ON latest.listing_id = l.listing_id
    AND latest.snapshot_date = (
        SELECT MAX(ls2.snapshot_date)
        FROM listing_snapshot ls2
        WHERE ls2.listing_id = l.listing_id
    )
WHERE r.effective_to IS NULL OR r.effective_to >= CURDATE()
GROUP BY n.name, r.regulation_type, r.annual_night_limit
ORDER BY listings_over_limit DESC;