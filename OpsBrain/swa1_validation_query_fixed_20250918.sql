-- SWA1 Validation Query: Match Our Analysis to Mercury Data
-- Goal: Prove we can identify same bottlenecks Mercury found

-- Step 1: Replicate Mercury's Defect Detection
WITH mercury_benchmark(tracking_id, induct_time, mercury_dwell_min) AS (
  VALUES
    ('TBA324382452417', '2025-09-15 03:23:48'::timestamp, 2269),
    ('TBA324407564226', '2025-09-16 02:32:04'::timestamp, 267),
    ('TBA324387931890', '2025-09-15 10:59:49'::timestamp, 289),
    ('TBA324328209818', '2025-09-12 18:18:32'::timestamp, 2497),
    ('TBA324408440124', '2025-09-16 05:02:36'::timestamp, 266)
),

-- Step 2: Our Analysis - Calculate Actual Dwell
our_analysis AS (
  SELECT
    tracking_id,
    MIN(CASE WHEN status_code = 'AT_STATION' THEN event_datetime_utc END) as first_scan,
    MAX(event_datetime_utc) as last_scan,
    EXTRACT(EPOCH FROM (MAX(event_datetime_utc) -
      MIN(CASE WHEN status_code = 'AT_STATION' THEN event_datetime_utc END)))/60 as our_dwell_min,
    COUNT(DISTINCT status_code) as status_changes,
    MAX(CASE WHEN route_code IS NOT NULL THEN 1 ELSE 0 END) as has_route,
    STRING_AGG(DISTINCT status_code, ' → ' ORDER BY status_code) as status_journey
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'SWA1'
    AND tracking_id IN (SELECT tracking_id FROM mercury_benchmark)
    AND DATE(event_datetime_utc) BETWEEN '2025-09-12' AND '2025-09-17'
  GROUP BY tracking_id
),

-- Step 3: Validation Comparison
validation AS (
  SELECT
    m.tracking_id,
    m.mercury_dwell_min,
    ROUND(o.our_dwell_min) as our_calculated_dwell,
    ABS(m.mercury_dwell_min - o.our_dwell_min) as delta_minutes,
    CASE
      WHEN ABS(m.mercury_dwell_min - o.our_dwell_min) < 30 THEN '✅ MATCH'
      WHEN ABS(m.mercury_dwell_min - o.our_dwell_min) < 60 THEN '🟡 CLOSE'
      ELSE '❌ MISMATCH'
    END as validation_status,
    o.has_route,
    o.status_journey
  FROM mercury_benchmark m
  LEFT JOIN our_analysis o ON m.tracking_id = o.tracking_id
)

SELECT * FROM validation
ORDER BY mercury_dwell_min DESC;

-- Step 4: Find ALL High-Dwell Packages at SWA1 (not just Mercury's list)
WITH all_swa1_packages AS (
  SELECT
    tracking_id,
    MIN(event_datetime_utc) as first_scan,
    MAX(event_datetime_utc) as last_scan,
    EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60 as dwell_minutes,
    MAX(CASE WHEN route_code IS NOT NULL THEN 1 ELSE 0 END) as has_route
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'SWA1'
    AND DATE(event_datetime_utc) BETWEEN '2025-09-15' AND '2025-09-16'
    AND ship_method LIKE '%RUSH%'
  GROUP BY tracking_id
  HAVING EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60 > 200
)
SELECT
  COUNT(*) as total_high_dwell_packages,
  COUNT(CASE WHEN dwell_minutes > 267 AND dwell_minutes < 307 THEN 1 END) as in_target_range,
  COUNT(CASE WHEN has_route = 0 THEN 1 END) as missing_dea,
  ROUND(AVG(dwell_minutes)) as avg_dwell,
  ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY dwell_minutes)) as p95_dwell
FROM all_swa1_packages;

-- Step 5: Little's Law Validation at SWA1
WITH hourly_metrics AS (
  SELECT
    DATE_TRUNC('hour', event_datetime_utc) as hour,
    COUNT(CASE WHEN status_code = 'AT_STATION' THEN 1 END) as lambda_arrivals,
    COUNT(DISTINCT tracking_id) as L_inventory,
    COUNT(CASE WHEN status_code IN ('DELIVERED', 'READY_FOR_DEPARTURE') THEN 1 END) as exits
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'SWA1'
    AND DATE(event_datetime_utc) = '2025-09-15'
  GROUP BY hour
),
littles_law AS (
  SELECT
    TO_CHAR(hour, 'HH24:00') as time,
    lambda_arrivals,
    L_inventory,
    CASE
      WHEN lambda_arrivals > 0
      THEN ROUND(L_inventory::numeric / lambda_arrivals * 60)
      ELSE NULL
    END as W_wait_minutes,
    CASE
      WHEN lambda_arrivals > exits * 1.5 THEN 'BOTTLENECK'
      WHEN lambda_arrivals > exits * 1.2 THEN 'CONGESTION'
      ELSE 'NORMAL'
    END as status
  FROM hourly_metrics
  WHERE lambda_arrivals > 0
)
SELECT
  time,
  lambda_arrivals as "λ (arrivals/hr)",
  L_inventory as "L (packages)",
  W_wait_minutes as "W (minutes)",
  status
FROM littles_law
ORDER BY W_wait_minutes DESC
LIMIT 5;