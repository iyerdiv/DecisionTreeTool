-- SWA1 Validation Query - Redshift Compatible Version
-- Fixed for syntax and logic issues

-- Step 1: Mercury benchmark data using UNION ALL
WITH mercury_benchmark AS (
  SELECT 'TBA324382452417' as tracking_id, TIMESTAMP '2025-09-15 03:23:48' as induct_time, 2269 as mercury_dwell_min
  UNION ALL SELECT 'TBA324407564226', TIMESTAMP '2025-09-16 02:32:04', 267
  UNION ALL SELECT 'TBA324387931890', TIMESTAMP '2025-09-15 10:59:49', 289
  UNION ALL SELECT 'TBA324328209818', TIMESTAMP '2025-09-12 18:18:32', 2497
  UNION ALL SELECT 'TBA324408440124', TIMESTAMP '2025-09-16 05:02:36', 266
),

-- Step 2: Check if packages exist at SWA1
package_check AS (
  SELECT
    tracking_id,
    COUNT(*) as event_count,
    MIN(delivery_station_code) as station
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE tracking_id IN (SELECT tracking_id FROM mercury_benchmark)
    AND DATE(event_datetime_utc) BETWEEN '2025-09-12' AND '2025-09-17'
  GROUP BY tracking_id
),

-- Step 3: Calculate dwell using our method
our_analysis AS (
  SELECT
    h.tracking_id,
    MIN(h.event_datetime_utc) as first_scan,
    MAX(h.event_datetime_utc) as last_scan,
    MIN(CASE WHEN h.status_code = 'AT_STATION' THEN h.event_datetime_utc END) as induct_time,
    MAX(CASE WHEN h.status_code = 'DELIVERED' THEN h.event_datetime_utc END) as deliver_time,
    DATEDIFF(minute,
      MIN(h.event_datetime_utc),
      MAX(h.event_datetime_utc)
    ) as our_total_dwell_min,
    COUNT(DISTINCT h.status_code) as status_changes,
    MAX(CASE WHEN h.route_code IS NOT NULL THEN 1 ELSE 0 END) as has_route,
    MAX(h.delivery_station_code) as station_code
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history h
  WHERE h.tracking_id IN (SELECT tracking_id FROM mercury_benchmark)
    AND DATE(h.event_datetime_utc) BETWEEN '2025-09-12' AND '2025-09-17'
  GROUP BY h.tracking_id
),

-- Step 4: Validation comparison
validation AS (
  SELECT
    m.tracking_id,
    m.mercury_dwell_min,
    o.our_total_dwell_min,
    ABS(m.mercury_dwell_min - o.our_total_dwell_min) as delta_minutes,
    CASE
      WHEN o.tracking_id IS NULL THEN 'NOT_FOUND'
      WHEN ABS(m.mercury_dwell_min - o.our_total_dwell_min) < 30 THEN 'MATCH'
      WHEN ABS(m.mercury_dwell_min - o.our_total_dwell_min) < 60 THEN 'CLOSE'
      ELSE 'MISMATCH'
    END as validation_status,
    o.has_route,
    o.station_code,
    p.event_count
  FROM mercury_benchmark m
  LEFT JOIN our_analysis o ON m.tracking_id = o.tracking_id
  LEFT JOIN package_check p ON m.tracking_id = p.tracking_id
)

SELECT
  tracking_id,
  mercury_dwell_min,
  our_total_dwell_min,
  delta_minutes,
  validation_status,
  CASE WHEN has_route = 1 THEN 'YES' ELSE 'NO' END as has_route,
  station_code,
  event_count
FROM validation
ORDER BY mercury_dwell_min DESC;

-- Step 5: Count all high-dwell packages at SWA1
WITH swa1_high_dwell AS (
  SELECT
    tracking_id,
    DATEDIFF(minute,
      MIN(event_datetime_utc),
      MAX(event_datetime_utc)
    ) as dwell_minutes,
    MAX(CASE WHEN route_code IS NOT NULL THEN 1 ELSE 0 END) as has_route
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'SWA1'
    AND DATE(event_datetime_utc) BETWEEN '2025-09-12' AND '2025-09-17'
    AND ship_method LIKE '%RUSH%'
  GROUP BY tracking_id
  HAVING DATEDIFF(minute, MIN(event_datetime_utc), MAX(event_datetime_utc)) > 200
)
SELECT
  'SWA1 High Dwell Summary' as report_type,
  COUNT(*) as total_high_dwell_packages,
  COUNT(CASE WHEN dwell_minutes BETWEEN 267 AND 307 THEN 1 END) as in_267_307_range,
  COUNT(CASE WHEN has_route = 0 THEN 1 END) as missing_dea,
  ROUND(AVG(dwell_minutes), 0) as avg_dwell,
  MAX(dwell_minutes) as max_dwell
FROM swa1_high_dwell;

-- Step 6: Little's Law hourly analysis
WITH hourly_flow AS (
  SELECT
    DATE_TRUNC('hour', event_datetime_utc) as hour,
    COUNT(CASE WHEN status_code = 'AT_STATION' THEN 1 END) as arrivals,
    COUNT(DISTINCT tracking_id) as inventory,
    COUNT(CASE WHEN status_code IN ('DELIVERED', 'READY_FOR_DEPARTURE') THEN 1 END) as exits
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'SWA1'
    AND DATE(event_datetime_utc) = '2025-09-15'
    AND ship_method LIKE '%RUSH%'
  GROUP BY DATE_TRUNC('hour', event_datetime_utc)
)
SELECT
  TO_CHAR(hour, 'HH24:00') as time_hour,
  arrivals,
  inventory,
  CASE
    WHEN arrivals > 0 THEN ROUND(inventory::FLOAT / arrivals * 60, 0)
    ELSE 0
  END as wait_minutes,
  CASE
    WHEN arrivals > exits * 1.5 THEN 'BOTTLENECK'
    WHEN arrivals > exits * 1.2 THEN 'CONGESTION'
    ELSE 'NORMAL'
  END as flow_status
FROM hourly_flow
WHERE arrivals > 0
ORDER BY wait_minutes DESC
LIMIT 5;