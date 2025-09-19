-- Simplified Validation Approach - More Efficient

-- STEP 1: Find stations with recent high-volume RUSH traffic
SELECT
  'RECENT_HIGH_VOLUME' as analysis,
  delivery_station_code,
  DATE(event_datetime_utc) as event_date,
  COUNT(DISTINCT tracking_id) as packages,
  COUNT(*) as events,
  SUM(CASE WHEN route_code IS NULL THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100 as missing_dea_pct
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE DATE(event_datetime_utc) BETWEEN CURRENT_DATE - INTERVAL '90 days' AND CURRENT_DATE
  AND delivery_station_code IS NOT NULL
  AND ship_method LIKE '%RUSH%'
GROUP BY delivery_station_code, DATE(event_datetime_utc)
HAVING COUNT(DISTINCT tracking_id) > 500  -- High volume days only
ORDER BY event_date DESC, packages DESC
LIMIT 10;

-- STEP 2: For the top station/date from above, analyze dwell patterns
-- (We'll run this after seeing Step 1 results)

/*
-- High Dwell Analysis for Specific Station/Date
WITH package_dwell AS (
  SELECT
    tracking_id,
    MIN(event_datetime_utc) as first_event,
    MAX(event_datetime_utc) as last_event,
    EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 as dwell_minutes,
    MAX(CASE WHEN route_code IS NULL THEN 1 ELSE 0 END) as missing_dea
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'STATION_CODE'  -- From Step 1
    AND DATE(event_datetime_utc) = 'DATE'  -- From Step 1
    AND ship_method LIKE '%RUSH%'
  GROUP BY tracking_id
)
SELECT
  'DWELL_DISTRIBUTION' as analysis,
  CASE
    WHEN dwell_minutes < 30 THEN '0-30 min'
    WHEN dwell_minutes < 60 THEN '30-60 min'
    WHEN dwell_minutes < 120 THEN '1-2 hours'
    WHEN dwell_minutes < 180 THEN '2-3 hours'
    WHEN dwell_minutes < 240 THEN '3-4 hours'
    ELSE '4+ hours'
  END as dwell_bucket,
  COUNT(*) as packages,
  SUM(missing_dea) as missing_dea_count,
  AVG(dwell_minutes) as avg_dwell
FROM package_dwell
GROUP BY dwell_bucket
ORDER BY
  CASE dwell_bucket
    WHEN '0-30 min' THEN 1
    WHEN '30-60 min' THEN 2
    WHEN '1-2 hours' THEN 3
    WHEN '2-3 hours' THEN 4
    WHEN '3-4 hours' THEN 5
    ELSE 6
  END;

-- 5-Minute Flow Analysis
WITH five_min_flow AS (
  SELECT
    DATE_TRUNC('hour', event_datetime_utc) +
    INTERVAL '5 minutes' * FLOOR(EXTRACT(MINUTE FROM event_datetime_utc) / 5) as time_slot,
    COUNT(DISTINCT tracking_id) as packages_in_system,
    SUM(CASE WHEN status_code = 'AT_STATION' THEN 1 ELSE 0 END) as arrivals,
    SUM(CASE WHEN status_code IN ('DEPARTED', 'DELIVERED') THEN 1 ELSE 0 END) as departures
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'STATION_CODE'  -- From Step 1
    AND DATE(event_datetime_utc) = 'DATE'  -- From Step 1
    AND ship_method LIKE '%RUSH%'
  GROUP BY 1
)
SELECT
  TO_CHAR(time_slot, 'HH24:MI') as time_5min,
  packages_in_system as L,
  arrivals as lambda,
  departures as mu,
  CASE
    WHEN arrivals > 0 THEN ROUND(packages_in_system::FLOAT / arrivals * 5, 1)
    ELSE 0
  END as W_minutes,
  CASE
    WHEN arrivals > departures * 1.5 THEN 'BOTTLENECK'
    WHEN arrivals > departures * 1.2 THEN 'CONGESTED'
    ELSE 'NORMAL'
  END as status
FROM five_min_flow
WHERE EXTRACT(HOUR FROM time_slot) BETWEEN 12 AND 20
ORDER BY time_slot;
*/