-- Validate bottleneck detection using DCM3 station (which has 4M+ events)
-- Date: December 17, 2024 (has most data)

-- 1. Check DCM3 high-dwell packages on Dec 17, 2024
WITH package_dwell AS (
  SELECT
    tracking_id,
    MIN(event_datetime_utc) as first_event,
    MAX(event_datetime_utc) as last_event,
    EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 as dwell_minutes,
    COUNT(*) as event_count
  FROM heisenbergrefinedobjects.d_perfectmile_global_dea
  WHERE delivery_station_code = 'DCM3'
    AND DATE(event_datetime_utc) = '2024-12-17'
  GROUP BY tracking_id
)
SELECT
  'DCM3_DWELL_DISTRIBUTION' as analysis,
  CASE
    WHEN dwell_minutes < 30 THEN '0-30 min'
    WHEN dwell_minutes < 60 THEN '30-60 min'
    WHEN dwell_minutes < 120 THEN '1-2 hours'
    WHEN dwell_minutes < 180 THEN '2-3 hours'
    WHEN dwell_minutes < 240 THEN '3-4 hours'
    ELSE '4+ hours'
  END as dwell_bucket,
  COUNT(*) as packages,
  AVG(dwell_minutes) as avg_dwell,
  MAX(dwell_minutes) as max_dwell
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

-- 2. 5-Minute interval analysis for DCM3 peak hours
WITH five_min_flow AS (
  SELECT
    DATE_TRUNC('hour', event_datetime_utc) +
    INTERVAL '5 minutes' * FLOOR(EXTRACT(MINUTE FROM event_datetime_utc) / 5) as time_slot,
    COUNT(DISTINCT tracking_id) as packages,
    COUNT(CASE WHEN status_code = 'AT_STATION' THEN 1 END) as arrivals,
    COUNT(CASE WHEN route_code IS NULL THEN 1 END) as missing_dea
  FROM heisenbergrefinedobjects.d_perfectmile_global_dea
  WHERE delivery_station_code = 'DCM3'
    AND DATE(event_datetime_utc) = '2024-12-17'
    AND EXTRACT(HOUR FROM event_datetime_utc) BETWEEN 14 AND 18  -- 2-6 PM peak
  GROUP BY 1
)
SELECT
  'DCM3_5MIN_FLOW' as analysis,
  TO_CHAR(time_slot, 'HH24:MI') as time_5min,
  packages,
  arrivals,
  missing_dea,
  CASE
    WHEN arrivals > 0 THEN ROUND(packages::FLOAT / arrivals * 5, 1)
    ELSE 0
  END as W_wait_minutes,
  CASE
    WHEN packages > 1000 THEN 'BOTTLENECK'
    WHEN packages > 500 THEN 'CONGESTED'
    ELSE 'NORMAL'
  END as flow_status
FROM five_min_flow
ORDER BY time_slot
LIMIT 50;

-- 3. Find sample high-dwell packages for validation
SELECT
  'SAMPLE_HIGH_DWELL_DCM3' as analysis,
  tracking_id,
  MIN(event_datetime_utc) as first_scan,
  MAX(event_datetime_utc) as last_scan,
  EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 as dwell_minutes,
  COUNT(*) as events
FROM heisenbergrefinedobjects.d_perfectmile_global_dea
WHERE delivery_station_code = 'DCM3'
  AND DATE(event_datetime_utc) = '2024-12-17'
GROUP BY tracking_id
HAVING EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 > 180
ORDER BY dwell_minutes DESC
LIMIT 10;