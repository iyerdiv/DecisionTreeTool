-- SSD Station Validation Query
-- Based on Perfect Mile documentation and correct station naming (airport code + number)
-- Focus: Sub Same Day stations with 30-minute targets

-- 1. Find all stations with SSD-like patterns (3-letter codes that might be airports)
SELECT
  'POTENTIAL_SSD_STATIONS' as analysis,
  delivery_station_code,
  COUNT(DISTINCT DATE(event_datetime_utc)) as days_active,
  COUNT(DISTINCT tracking_id) as total_packages,
  MIN(DATE(event_datetime_utc)) as first_seen,
  MAX(DATE(event_datetime_utc)) as last_seen
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE delivery_station_code ~ '^[A-Z]{3}[0-9]{1,2}$'  -- XXX# or XXX## pattern
  AND (ship_method LIKE '%SAME%' OR ship_method LIKE '%SSD%' OR ship_method LIKE '%RUSH%')
  AND DATE(event_datetime_utc) BETWEEN '2024-01-01' AND '2025-12-31'
GROUP BY delivery_station_code
ORDER BY total_packages DESC
LIMIT 30;

-- 2. Check SWA1 specifically across all dates
SELECT
  'SWA1_FULL_SEARCH' as analysis,
  delivery_station_code,
  EXTRACT(YEAR FROM event_datetime_utc) as year,
  EXTRACT(MONTH FROM event_datetime_utc) as month,
  COUNT(DISTINCT tracking_id) as packages,
  COUNT(*) as events
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE delivery_station_code = 'SWA1'
GROUP BY delivery_station_code, year, month
ORDER BY year DESC, month DESC;

-- 3. SSD Performance Analysis (30-minute target)
WITH ssd_dwell AS (
  SELECT
    delivery_station_code,
    tracking_id,
    DATE(MIN(event_datetime_utc)) as event_date,
    MIN(CASE WHEN status_code = 'AT_STATION' THEN event_datetime_utc END) as arrival_time,
    MAX(CASE WHEN status_code IN ('DEPARTED', 'DELIVERED') THEN event_datetime_utc END) as departure_time,
    EXTRACT(EPOCH FROM (
      MAX(event_datetime_utc) - MIN(event_datetime_utc)
    ))/60.0 as total_dwell_minutes
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code ~ '^[A-Z]{3}[0-9]{1,2}$'  -- Airport code pattern
    AND DATE(event_datetime_utc) BETWEEN '2024-12-01' AND '2024-12-31'
    AND (ship_method LIKE '%SAME%' OR ship_method LIKE '%RUSH%')
  GROUP BY delivery_station_code, tracking_id
)
SELECT
  'SSD_30MIN_PERFORMANCE' as analysis,
  delivery_station_code,
  COUNT(DISTINCT tracking_id) as total_packages,
  COUNT(CASE WHEN total_dwell_minutes <= 30 THEN 1 END) as met_ssd_target,
  COUNT(CASE WHEN total_dwell_minutes > 30 AND total_dwell_minutes <= 60 THEN 1 END) as missed_30_60min,
  COUNT(CASE WHEN total_dwell_minutes > 60 AND total_dwell_minutes <= 120 THEN 1 END) as missed_60_120min,
  COUNT(CASE WHEN total_dwell_minutes > 120 THEN 1 END) as critical_miss_over_120min,
  ROUND(COUNT(CASE WHEN total_dwell_minutes <= 30 THEN 1 END)::FLOAT /
        NULLIF(COUNT(*), 0) * 100, 1) as ssd_success_rate_pct,
  ROUND(AVG(total_dwell_minutes), 1) as avg_dwell_min,
  MAX(total_dwell_minutes) as max_dwell_min
FROM ssd_dwell
GROUP BY delivery_station_code
HAVING COUNT(DISTINCT tracking_id) > 500  -- Significant volume
ORDER BY ssd_success_rate_pct ASC  -- Worst performers first
LIMIT 20;

-- 4. Find stations with Mercury-like dwell patterns (267-2497 minutes)
WITH extreme_dwell AS (
  SELECT
    delivery_station_code,
    tracking_id,
    EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 as dwell_minutes
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE DATE(event_datetime_utc) BETWEEN '2024-12-01' AND '2024-12-31'
    AND delivery_station_code ~ '^[A-Z]{3}[0-9]{1,2}$'
    AND ship_method LIKE '%RUSH%'
  GROUP BY delivery_station_code, tracking_id
  HAVING EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 > 240  -- 4+ hours
)
SELECT
  'MERCURY_PATTERN_MATCH' as analysis,
  delivery_station_code,
  COUNT(*) as packages_over_4hrs,
  COUNT(CASE WHEN dwell_minutes BETWEEN 240 AND 300 THEN 1 END) as dwell_4_5hrs,
  COUNT(CASE WHEN dwell_minutes BETWEEN 300 AND 600 THEN 1 END) as dwell_5_10hrs,
  COUNT(CASE WHEN dwell_minutes BETWEEN 600 AND 1440 THEN 1 END) as dwell_10_24hrs,
  COUNT(CASE WHEN dwell_minutes > 1440 THEN 1 END) as dwell_over_24hrs,
  ROUND(AVG(dwell_minutes), 0) as avg_extreme_dwell_min,
  MAX(dwell_minutes) as max_dwell_min
FROM extreme_dwell
GROUP BY delivery_station_code
HAVING COUNT(*) > 10  -- At least 10 extreme cases
ORDER BY packages_over_4hrs DESC
LIMIT 10;

-- 5. 5-Minute bottleneck analysis for top problem station
-- (Run separately after identifying problem station from above)
/*
WITH five_min_analysis AS (
  SELECT
    DATE_TRUNC('hour', event_datetime_utc) +
    INTERVAL '5 minutes' * FLOOR(EXTRACT(MINUTE FROM event_datetime_utc) / 5) as time_slot,
    COUNT(DISTINCT tracking_id) as packages,
    SUM(CASE WHEN status_code = 'AT_STATION' THEN 1 ELSE 0 END) as arrivals,
    SUM(CASE WHEN status_code IN ('DEPARTED', 'DELIVERED') THEN 1 ELSE 0 END) as departures
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'XXX'  -- Replace with problem station
    AND DATE(event_datetime_utc) = '2024-12-XX'  -- Replace with date
    AND EXTRACT(HOUR FROM event_datetime_utc) BETWEEN 12 AND 20
    AND ship_method LIKE '%RUSH%'
  GROUP BY 1
)
SELECT
  TO_CHAR(time_slot, 'HH24:MI') as time_5min,
  packages as L,
  arrivals as lambda,
  departures as mu,
  CASE WHEN arrivals > 0 THEN ROUND(packages::FLOAT / arrivals * 5, 1) ELSE 0 END as W_min,
  CASE
    WHEN packages <= 30 THEN 'SSD_TARGET_MET'
    WHEN packages <= 60 THEN 'SSD_WARNING'
    ELSE 'SSD_CRITICAL'
  END as ssd_status
FROM five_min_analysis
ORDER BY time_slot;
*/