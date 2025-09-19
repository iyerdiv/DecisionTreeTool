-- Check if the ORIGINAL UAT stations exist in our data
-- These were specifically chosen for known bottleneck patterns

-- 1. Check if CAX2, DCK1, STL8, VNY5 exist
SELECT
  'ORIGINAL_UAT_STATIONS' as analysis,
  delivery_station_code,
  COUNT(DISTINCT DATE(event_datetime_utc)) as days_with_data,
  MIN(DATE(event_datetime_utc)) as earliest_date,
  MAX(DATE(event_datetime_utc)) as latest_date,
  COUNT(DISTINCT tracking_id) as total_packages,
  COUNT(*) as total_events
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE delivery_station_code IN ('CAX2', 'DCK1', 'STL8', 'VNY5', 'SWA1')
  AND DATE(event_datetime_utc) BETWEEN '2024-01-01' AND '2025-12-31'
GROUP BY delivery_station_code
ORDER BY total_events DESC;

-- 2. Check VNY5 specifically for Sept 3, 2024 (the benchmark date)
SELECT
  'VNY5_BENCHMARK_CHECK' as analysis,
  delivery_station_code,
  DATE(event_datetime_utc) as event_date,
  COUNT(DISTINCT tracking_id) as packages,
  COUNT(DISTINCT CASE WHEN ship_method LIKE '%RUSH%' THEN tracking_id END) as rush_packages,
  COUNT(*) as events
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE delivery_station_code = 'VNY5'
  AND DATE(event_datetime_utc) = '2024-09-03'
GROUP BY delivery_station_code, DATE(event_datetime_utc);

-- 3. Find recent data for CAX2 (primary test station)
SELECT
  'CAX2_RECENT_DATA' as analysis,
  DATE(event_datetime_utc) as event_date,
  COUNT(DISTINCT tracking_id) as packages,
  SUM(CASE WHEN route_code IS NULL THEN 1 ELSE 0 END) as missing_dea_events,
  ROUND(SUM(CASE WHEN route_code IS NULL THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100, 1) as missing_dea_pct
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE delivery_station_code = 'CAX2'
  AND DATE(event_datetime_utc) BETWEEN '2024-12-01' AND '2024-12-31'
  AND ship_method LIKE '%RUSH%'
GROUP BY DATE(event_datetime_utc)
ORDER BY event_date DESC
LIMIT 10;

-- 4. Check bottleneck characteristics for each original station
WITH station_profile AS (
  SELECT
    delivery_station_code,
    DATE(event_datetime_utc) as event_date,
    tracking_id,
    MIN(event_datetime_utc) as first_event,
    MAX(event_datetime_utc) as last_event,
    EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 as dwell_minutes,
    MAX(CASE WHEN route_code IS NULL THEN 1 ELSE 0 END) as missing_dea
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code IN ('CAX2', 'DCK1', 'STL8', 'VNY5')
    AND DATE(event_datetime_utc) BETWEEN '2024-12-01' AND '2024-12-31'
    AND ship_method LIKE '%RUSH%'
  GROUP BY delivery_station_code, DATE(event_datetime_utc), tracking_id
)
SELECT
  'STATION_BOTTLENECK_PROFILE' as analysis,
  delivery_station_code,
  COUNT(DISTINCT CASE WHEN dwell_minutes > 180 THEN tracking_id END) as high_dwell_packages,
  AVG(CASE WHEN dwell_minutes > 180 THEN dwell_minutes END) as avg_high_dwell,
  SUM(missing_dea) as total_missing_dea,
  COUNT(DISTINCT event_date) as days_analyzed
FROM station_profile
GROUP BY delivery_station_code
ORDER BY high_dwell_packages DESC;