-- DCM3 Validation using correct table: d_perfectmile_shipment_status_history

-- 1. DCM3 dwell distribution on Dec 17, 2024
WITH package_dwell AS (
  SELECT
    tracking_id,
    MIN(event_datetime_utc) as first_event,
    MAX(event_datetime_utc) as last_event,
    EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 as dwell_minutes,
    COUNT(*) as event_count
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
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

-- 2. 5-Minute flow analysis for DCM3
WITH five_min_flow AS (
  SELECT
    DATE_TRUNC('hour', event_datetime_utc) +
    INTERVAL '5 minutes' * FLOOR(EXTRACT(MINUTE FROM event_datetime_utc) / 5) as time_slot,
    COUNT(DISTINCT tracking_id) as packages,
    COUNT(*) as total_events
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'DCM3'
    AND DATE(event_datetime_utc) = '2024-12-17'
    AND EXTRACT(HOUR FROM event_datetime_utc) BETWEEN 14 AND 18
  GROUP BY 1
)
SELECT
  'DCM3_5MIN_FLOW' as analysis,
  TO_CHAR(time_slot, 'HH24:MI') as time_5min,
  packages,
  total_events,
  CASE
    WHEN packages > 1000 THEN 'BOTTLENECK'
    WHEN packages > 500 THEN 'CONGESTED'
    ELSE 'NORMAL'
  END as flow_status
FROM five_min_flow
ORDER BY time_slot
LIMIT 20;

-- 3. Sample high-dwell packages
SELECT
  'SAMPLE_HIGH_DWELL_DCM3' as analysis,
  tracking_id,
  MIN(event_datetime_utc) as first_scan,
  MAX(event_datetime_utc) as last_scan,
  EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 as dwell_minutes,
  COUNT(*) as events
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE delivery_station_code = 'DCM3'
  AND DATE(event_datetime_utc) = '2024-12-17'
GROUP BY tracking_id
HAVING EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 > 180
ORDER BY dwell_minutes DESC
LIMIT 10;
