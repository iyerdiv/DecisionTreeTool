-- Find Bottleneck Patterns Instead of Specific Tracking IDs
-- Focus on identifying systemic issues, not individual packages

-- 1. Find ANY high-dwell packages in reasonable date range
WITH high_dwell_packages AS (
  SELECT
    delivery_station_code,
    tracking_id,
    DATE(MIN(event_datetime_utc)) as event_date,
    EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 as dwell_minutes,
    COUNT(*) as event_count
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE DATE(event_datetime_utc) BETWEEN '2024-01-01' AND '2025-12-31'
    AND delivery_station_code IS NOT NULL
    AND ship_method LIKE '%RUSH%'
  GROUP BY delivery_station_code, tracking_id
  HAVING EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 > 180  -- 3+ hours
)
SELECT
  'HIGH_DWELL_SUMMARY' as analysis_type,
  delivery_station_code,
  COUNT(*) as packages_over_3hrs,
  AVG(dwell_minutes) as avg_dwell,
  MAX(dwell_minutes) as max_dwell,
  MIN(event_date) as earliest_date,
  MAX(event_date) as latest_date
FROM high_dwell_packages
GROUP BY delivery_station_code
ORDER BY packages_over_3hrs DESC
LIMIT 10;

-- 2. Find stations with consistent bottleneck patterns
WITH station_daily_stats AS (
  SELECT
    delivery_station_code,
    DATE(event_datetime_utc) as event_date,
    COUNT(DISTINCT tracking_id) as packages,
    COUNT(*) as events,
    COUNT(CASE WHEN route_code IS NULL THEN 1 END) as missing_dea_events
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE DATE(event_datetime_utc) BETWEEN '2024-01-01' AND '2025-12-31'
    AND ship_method LIKE '%RUSH%'
    AND delivery_station_code IS NOT NULL
  GROUP BY delivery_station_code, DATE(event_datetime_utc)
  HAVING COUNT(DISTINCT tracking_id) > 100  -- Days with meaningful volume
)
SELECT
  'BOTTLENECK_STATIONS' as analysis_type,
  delivery_station_code,
  COUNT(*) as days_with_data,
  AVG(packages) as avg_daily_packages,
  AVG(missing_dea_events::FLOAT / NULLIF(events, 0) * 100) as avg_missing_dea_pct
FROM station_daily_stats
GROUP BY delivery_station_code
HAVING COUNT(*) > 5  -- Stations with at least 5 days of data
ORDER BY avg_missing_dea_pct DESC
LIMIT 10;

-- 3. Find peak congestion hours across all stations
WITH hourly_flow AS (
  SELECT
    DATE_TRUNC('hour', event_datetime_utc) as hour,
    delivery_station_code,
    COUNT(DISTINCT tracking_id) as packages,
    COUNT(CASE WHEN status_code = 'AT_STATION' THEN 1 END) as arrivals,
    COUNT(CASE WHEN route_code IS NULL THEN 1 END) as missing_dea
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE DATE(event_datetime_utc) BETWEEN '2024-01-01' AND '2025-12-31'
    AND EXTRACT(HOUR FROM event_datetime_utc) BETWEEN 12 AND 20  -- Focus on afternoon/evening
    AND ship_method LIKE '%RUSH%'
    AND delivery_station_code IS NOT NULL
  GROUP BY DATE_TRUNC('hour', event_datetime_utc), delivery_station_code
  HAVING COUNT(DISTINCT tracking_id) > 50
)
SELECT
  'PEAK_CONGESTION_HOURS' as analysis_type,
  EXTRACT(HOUR FROM hour) as hour_of_day,
  AVG(packages) as avg_packages,
  AVG(arrivals) as avg_arrivals,
  AVG(missing_dea::FLOAT / NULLIF(packages, 0) * 100) as avg_missing_dea_pct
FROM hourly_flow
GROUP BY EXTRACT(HOUR FROM hour)
ORDER BY hour_of_day;

-- 4. Sample of actual high-dwell packages (for verification)
SELECT
  'SAMPLE_HIGH_DWELL' as analysis_type,
  tracking_id,
  delivery_station_code,
  DATE(MIN(event_datetime_utc)) as event_date,
  EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 as dwell_minutes,
  COUNT(*) as events
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE DATE(event_datetime_utc) BETWEEN '2024-01-01' AND '2025-12-31'
  AND delivery_station_code IS NOT NULL
  AND ship_method LIKE '%RUSH%'
GROUP BY tracking_id, delivery_station_code
HAVING EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 > 240  -- 4+ hours
ORDER BY dwell_minutes DESC
LIMIT 10;

-- 5. Find the best station and date for 5-minute analysis
WITH recent_high_volume AS (
  SELECT
    delivery_station_code,
    DATE(event_datetime_utc) as event_date,
    COUNT(DISTINCT tracking_id) as packages
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE DATE(event_datetime_utc) BETWEEN '2024-01-01' AND '2025-12-31'
    AND ship_method LIKE '%RUSH%'
    AND delivery_station_code IS NOT NULL
  GROUP BY delivery_station_code, DATE(event_datetime_utc)
  HAVING COUNT(DISTINCT tracking_id) > 500
)
SELECT
  'BEST_STATION_FOR_ANALYSIS' as analysis_type,
  delivery_station_code,
  event_date,
  packages
FROM recent_high_volume
ORDER BY event_date DESC, packages DESC
LIMIT 5;