-- Find SSD FC (Sub Same Day Fulfillment Center) Data
-- SWA1 is an SSD FC - hybrid between FC and delivery station

-- 1. Look for SSD-specific patterns in any station
SELECT
  'SSD_FC_SEARCH' as analysis,
  delivery_station_code,
  ship_method,
  COUNT(DISTINCT tracking_id) as packages,
  COUNT(*) as events,
  MIN(DATE(event_datetime_utc)) as earliest_date,
  MAX(DATE(event_datetime_utc)) as latest_date
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE (
    -- SSD FC patterns
    delivery_station_code LIKE 'S%'  -- SSD prefix
    OR ship_method LIKE '%SSD%'      -- SSD ship method
    OR ship_method LIKE '%SUB_SAME%' -- Sub Same Day
    OR ship_method LIKE '%PRIME_NOW%' -- Often uses SSD FCs
  )
  AND DATE(event_datetime_utc) BETWEEN '2024-01-01' AND '2025-12-31'
GROUP BY delivery_station_code, ship_method
HAVING COUNT(DISTINCT tracking_id) > 100
ORDER BY packages DESC
LIMIT 30;

-- 2. Check Washington state facilities (SWA = Seattle/WA area)
SELECT
  'WASHINGTON_FACILITIES' as analysis,
  delivery_station_code,
  COUNT(DISTINCT DATE(event_datetime_utc)) as days_active,
  COUNT(DISTINCT tracking_id) as total_packages,
  MIN(DATE(event_datetime_utc)) as first_seen,
  MAX(DATE(event_datetime_utc)) as last_seen
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE (
    delivery_station_code LIKE '%WA%'     -- Washington
    OR delivery_station_code LIKE '%SEA%'  -- Seattle
    OR delivery_station_code LIKE 'S%1'    -- SSD pattern
  )
  AND DATE(event_datetime_utc) BETWEEN '2024-01-01' AND '2025-12-31'
GROUP BY delivery_station_code
ORDER BY total_packages DESC;

-- 3. Find facilities with SSD-like processing times (very fast)
WITH rapid_processing AS (
  SELECT
    delivery_station_code,
    tracking_id,
    MIN(event_datetime_utc) as first_scan,
    MAX(event_datetime_utc) as last_scan,
    EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 as process_minutes,
    COUNT(DISTINCT status_code) as status_changes
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE DATE(event_datetime_utc) = '2024-12-17'
    AND delivery_station_code IS NOT NULL
  GROUP BY delivery_station_code, tracking_id
  HAVING COUNT(*) > 3  -- Multiple scans
)
SELECT
  'RAPID_PROCESSING_FACILITIES' as analysis,
  delivery_station_code,
  COUNT(*) as packages,
  COUNT(CASE WHEN process_minutes <= 30 THEN 1 END) as under_30min,
  COUNT(CASE WHEN process_minutes <= 60 THEN 1 END) as under_60min,
  ROUND(COUNT(CASE WHEN process_minutes <= 30 THEN 1 END)::FLOAT / COUNT(*) * 100, 1) as pct_under_30min,
  AVG(process_minutes) as avg_process_min,
  MIN(process_minutes) as fastest_process_min
FROM rapid_processing
GROUP BY delivery_station_code
HAVING COUNT(*) > 500
  AND COUNT(CASE WHEN process_minutes <= 60 THEN 1 END) > 100  -- Many fast packages
ORDER BY pct_under_30min DESC
LIMIT 20;

-- 4. Check for SSD FC specific status codes
SELECT
  'SSD_STATUS_PATTERNS' as analysis,
  delivery_station_code,
  status_code,
  COUNT(*) as occurrences
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE DATE(event_datetime_utc) = '2024-12-17'
  AND (
    status_code LIKE '%SSD%'
    OR status_code LIKE '%PRIME_NOW%'
    OR status_code LIKE '%SUB_SAME%'
    OR status_code LIKE '%RAPID%'
    OR status_code LIKE '%EXPRESS%'
  )
GROUP BY delivery_station_code, status_code
ORDER BY occurrences DESC
LIMIT 20;

-- 5. Alternative: Check if SWA1 exists under different naming
SELECT
  'ALTERNATIVE_SWA1_NAMES' as analysis,
  delivery_station_code,
  COUNT(DISTINCT tracking_id) as packages
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE (
    delivery_station_code IN ('SWA1', 'SWA01', 'SEA1', 'SEA01', 'SW1', 'SA1')
    OR delivery_station_code LIKE '%EVERETT%'  -- SWA1 location
  )
  AND DATE(event_datetime_utc) BETWEEN '2024-01-01' AND '2025-12-31'
GROUP BY delivery_station_code;

-- 6. Find ANY station meeting SSD FC profile (30-min processing, high volume)
WITH ssd_profile AS (
  SELECT
    delivery_station_code,
    DATE(event_datetime_utc) as event_date,
    COUNT(DISTINCT tracking_id) as daily_packages,
    AVG(EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0) as avg_dwell
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE DATE(event_datetime_utc) BETWEEN '2024-12-15' AND '2024-12-17'
  GROUP BY delivery_station_code, DATE(event_datetime_utc), tracking_id
  GROUP BY delivery_station_code, DATE(event_datetime_utc)
)
SELECT
  'SSD_FC_CANDIDATES' as analysis,
  delivery_station_code,
  AVG(daily_packages) as avg_daily_volume,
  AVG(avg_dwell) as avg_dwell_minutes,
  COUNT(DISTINCT event_date) as days_active
FROM ssd_profile
GROUP BY delivery_station_code
HAVING AVG(daily_packages) > 1000  -- High volume
  AND AVG(avg_dwell) < 120  -- Fast processing
ORDER BY avg_daily_volume DESC
LIMIT 10;