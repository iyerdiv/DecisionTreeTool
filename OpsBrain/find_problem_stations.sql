-- Find stations with ACTUAL bottleneck problems
-- Not just high volume, but real issues

-- 1. Find stations with high-dwell problems (like Mercury's 267-2497 min)
WITH station_problems AS (
  SELECT
    delivery_station_code,
    DATE(event_datetime_utc) as event_date,
    COUNT(DISTINCT tracking_id) as total_packages,
    -- Count packages with long dwell (3+ hours like Mercury)
    COUNT(DISTINCT CASE
      WHEN tracking_id IN (
        SELECT tracking_id
        FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history s2
        WHERE s2.tracking_id = s1.tracking_id
          AND DATE(s2.event_datetime_utc) = DATE(s1.event_datetime_utc)
          AND s2.delivery_station_code = s1.delivery_station_code
        GROUP BY tracking_id
        HAVING EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 > 180
      ) THEN tracking_id
    END) as high_dwell_packages
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history s1
  WHERE DATE(event_datetime_utc) BETWEEN '2024-12-01' AND '2024-12-31'
    AND ship_method LIKE '%RUSH%'
    AND delivery_station_code IS NOT NULL
  GROUP BY delivery_station_code, DATE(event_datetime_utc)
  HAVING COUNT(DISTINCT tracking_id) > 100  -- Meaningful volume
)
SELECT
  'PROBLEM_STATIONS' as analysis,
  delivery_station_code,
  MAX(event_date) as most_recent_issue,
  SUM(high_dwell_packages) as total_high_dwell,
  AVG(high_dwell_packages::FLOAT / NULLIF(total_packages, 0) * 100) as avg_high_dwell_pct,
  SUM(total_packages) as total_packages
FROM station_problems
WHERE high_dwell_packages > 20  -- Stations with significant issues
GROUP BY delivery_station_code
ORDER BY avg_high_dwell_pct DESC
LIMIT 10;

-- 2. Quick check for missing DEA issues by station
SELECT
  'MISSING_DEA_STATIONS' as analysis,
  delivery_station_code,
  DATE(event_datetime_utc) as event_date,
  COUNT(DISTINCT tracking_id) as packages,
  SUM(CASE WHEN route_code IS NULL THEN 1 ELSE 0 END) as missing_dea_events,
  ROUND(SUM(CASE WHEN route_code IS NULL THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100, 1) as missing_dea_pct
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE DATE(event_datetime_utc) = '2024-12-17'
  AND ship_method LIKE '%RUSH%'
  AND delivery_station_code IN ('DCM3', 'DLX5', 'CAX2', 'STL8', 'DCK1')  -- Check known stations
GROUP BY delivery_station_code, DATE(event_datetime_utc)
HAVING COUNT(DISTINCT tracking_id) > 500
ORDER BY missing_dea_pct DESC;

-- 3. Find a station that matches Mercury's profile
-- Mercury has packages with 4+ hour delays
SELECT
  'MERCURY_PROFILE_MATCH' as analysis,
  delivery_station_code,
  COUNT(DISTINCT tracking_id) as packages_over_4hrs,
  AVG(EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0) as avg_dwell_minutes,
  MAX(EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0) as max_dwell_minutes
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE DATE(event_datetime_utc) = '2024-12-17'
  AND ship_method LIKE '%RUSH%'
  AND delivery_station_code IS NOT NULL
GROUP BY delivery_station_code, tracking_id
HAVING EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 > 240  -- 4+ hours
GROUP BY delivery_station_code
ORDER BY packages_over_4hrs DESC
LIMIT 10;