-- FIND THE ACTUAL PROBLEM PACKAGES
-- Goal: Identify specific packages with 267-307 minute dwell times

WITH package_journey AS (
  SELECT
    tracking_id,
    delivery_station_code,
    status_code,
    event_datetime_utc,
    ship_method,
    -- Calculate time between events
    LAG(event_datetime_utc) OVER (PARTITION BY tracking_id ORDER BY event_datetime_utc) as prev_event_time,
    LAG(status_code) OVER (PARTITION BY tracking_id ORDER BY event_datetime_utc) as prev_status,
    LAG(delivery_station_code) OVER (PARTITION BY tracking_id ORDER BY event_datetime_utc) as prev_location,
    -- Time spent at each stage
    EXTRACT(EPOCH FROM (
      event_datetime_utc - LAG(event_datetime_utc) OVER (PARTITION BY tracking_id ORDER BY event_datetime_utc)
    ))/60 as minutes_at_stage
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE DATE(event_datetime_utc) = '2024-09-03'
    AND ship_method LIKE '%RUSH%'
),
problem_packages AS (
  -- Find packages with high dwell at any stage
  SELECT DISTINCT tracking_id
  FROM package_journey
  WHERE minutes_at_stage BETWEEN 267 AND 307
)
-- Get full journey for problem packages
SELECT
  pj.tracking_id,
  pj.delivery_station_code as location,
  pj.prev_location,
  pj.status_code,
  pj.prev_status,
  TO_CHAR(pj.event_datetime_utc, 'HH24:MI:SS') as event_time,
  pj.minutes_at_stage,
  CASE
    WHEN pj.minutes_at_stage > 180 THEN '🔴 CRITICAL DELAY'
    WHEN pj.minutes_at_stage > 60 THEN '🟡 MODERATE DELAY'
    ELSE '🟢 NORMAL'
  END as delay_status,
  pj.ship_method
FROM package_journey pj
WHERE pj.tracking_id IN (SELECT tracking_id FROM problem_packages)
ORDER BY pj.tracking_id, pj.event_datetime_utc;

-- Summary of where delays occur
WITH delay_analysis AS (
  SELECT
    delivery_station_code,
    status_code,
    COUNT(*) as delay_count,
    AVG(minutes_at_stage) as avg_delay_minutes,
    MAX(minutes_at_stage) as max_delay_minutes
  FROM package_journey
  WHERE minutes_at_stage > 180
  GROUP BY delivery_station_code, status_code
)
SELECT
  delivery_station_code,
  status_code,
  delay_count,
  ROUND(avg_delay_minutes, 1) as avg_delay,
  ROUND(max_delay_minutes, 1) as max_delay
FROM delay_analysis
ORDER BY delay_count DESC
LIMIT 10;