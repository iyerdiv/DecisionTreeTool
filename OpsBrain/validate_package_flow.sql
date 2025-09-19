-- VALIDATION 1: Trace a single RUSH package through the entire network
-- This shows actual flow pattern and time at each stage

WITH sample_packages AS (
  -- Get 5 random RUSH packages from VNY5
  SELECT DISTINCT tracking_id
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'VNY5'
    AND DATE(event_datetime_utc) = '2024-09-03'
    AND ship_method LIKE '%RUSH%'
    AND status_code = 'AT_STATION'
  LIMIT 5
)
SELECT
  sp.tracking_id,
  h.delivery_station_code,
  h.status_code,
  h.event_datetime_utc,
  h.ship_method,
  -- Calculate time since first event
  EXTRACT(EPOCH FROM (h.event_datetime_utc - FIRST_VALUE(h.event_datetime_utc)
    OVER (PARTITION BY sp.tracking_id ORDER BY h.event_datetime_utc)))/60 as minutes_since_start,
  -- Show the flow
  ROW_NUMBER() OVER (PARTITION BY sp.tracking_id ORDER BY h.event_datetime_utc) as step_number
FROM sample_packages sp
JOIN heisenbergrefinedobjects.d_perfectmile_shipment_status_history h
  ON sp.tracking_id = h.tracking_id
WHERE DATE(h.event_datetime_utc) = '2024-09-03'
ORDER BY sp.tracking_id, h.event_datetime_utc;

-- VALIDATION 2: Check if packages actually move V→D
WITH v_station_packages AS (
  SELECT DISTINCT tracking_id
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code LIKE 'V%'
    AND DATE(event_datetime_utc) = '2024-09-03'
    AND ship_method LIKE '%RUSH%'
),
d_station_packages AS (
  SELECT DISTINCT tracking_id
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code LIKE 'D%'
    AND DATE(event_datetime_utc) = '2024-09-03'
    AND ship_method LIKE '%RUSH%'
)
SELECT
  COUNT(DISTINCT v.tracking_id) as v_station_only,
  COUNT(DISTINCT d.tracking_id) as d_station_only,
  COUNT(DISTINCT CASE WHEN v.tracking_id = d.tracking_id THEN v.tracking_id END) as both_v_and_d,
  ROUND(100.0 * COUNT(DISTINCT CASE WHEN v.tracking_id = d.tracking_id THEN v.tracking_id END) /
    COUNT(DISTINCT v.tracking_id), 1) as pct_that_transfer
FROM v_station_packages v
FULL OUTER JOIN d_station_packages d ON v.tracking_id = d.tracking_id;

-- VALIDATION 3: Check actual end-to-end dwell times
WITH package_journey AS (
  SELECT
    tracking_id,
    MIN(CASE WHEN status_code = 'AT_STATION' THEN event_datetime_utc END) as first_scan,
    MAX(CASE WHEN status_code = 'DELIVERED' THEN event_datetime_utc END) as delivered
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE DATE(event_datetime_utc) = '2024-09-03'
    AND ship_method LIKE '%RUSH%'
  GROUP BY tracking_id
  HAVING MIN(CASE WHEN status_code = 'AT_STATION' THEN event_datetime_utc END) IS NOT NULL
    AND MAX(CASE WHEN status_code = 'DELIVERED' THEN event_datetime_utc END) IS NOT NULL
)
SELECT
  COUNT(*) as total_delivered_packages,
  ROUND(AVG(EXTRACT(EPOCH FROM (delivered - first_scan))/60), 1) as avg_dwell_minutes,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (delivered - first_scan))/60), 1) as median_dwell_minutes,
  ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (delivered - first_scan))/60), 1) as p95_dwell_minutes,
  COUNT(CASE WHEN EXTRACT(EPOCH FROM (delivered - first_scan))/60 <= 30 THEN 1 END) as met_30min_sla,
  ROUND(100.0 * COUNT(CASE WHEN EXTRACT(EPOCH FROM (delivered - first_scan))/60 <= 30 THEN 1 END) / COUNT(*), 1) as sla_compliance_pct
FROM package_journey;

-- VALIDATION 4: Check if status transitions make sense
SELECT
  status_code,
  LEAD(status_code) OVER (PARTITION BY tracking_id ORDER BY event_datetime_utc) as next_status,
  COUNT(*) as transition_count
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE DATE(event_datetime_utc) = '2024-09-03'
  AND ship_method LIKE '%RUSH%'
  AND delivery_station_code IN ('VNY5', 'DBL8')
GROUP BY status_code, next_status
ORDER BY transition_count DESC
LIMIT 20;