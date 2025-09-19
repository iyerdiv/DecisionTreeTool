-- REAL Bottleneck Detection for RCA
-- Focus on actual flow metrics, not misunderstood M(x) model

-- Find WHERE packages get stuck (by status code)
WITH package_flow AS (
  SELECT
    tracking_id,
    status_code,
    event_datetime_utc,
    -- Time to next status change
    LEAD(event_datetime_utc) OVER (PARTITION BY tracking_id ORDER BY event_datetime_utc) as next_event,
    -- Calculate dwell at each status
    EXTRACT(EPOCH FROM (
      LEAD(event_datetime_utc) OVER (PARTITION BY tracking_id ORDER BY event_datetime_utc) - event_datetime_utc
    ))/60.0 as minutes_at_status
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'DCM3'
    AND DATE(event_datetime_utc) = '2024-12-17'
    AND ship_method LIKE '%RUSH%'
)
-- Find which status codes have longest dwell
SELECT
  'STATUS_BOTTLENECKS' as analysis,
  status_code,
  COUNT(*) as occurrences,
  AVG(minutes_at_status) as avg_minutes,
  MAX(minutes_at_status) as max_minutes,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY minutes_at_status) as median_minutes,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY minutes_at_status) as p95_minutes,
  CASE
    WHEN AVG(minutes_at_status) > 60 THEN '🔴 BOTTLENECK'
    WHEN AVG(minutes_at_status) > 30 THEN '🟠 SLOW'
    ELSE '🟢 OK'
  END as status
FROM package_flow
WHERE minutes_at_status IS NOT NULL
GROUP BY status_code
HAVING COUNT(*) > 100
ORDER BY avg_minutes DESC;

-- Find WHEN bottlenecks occur (time of day)
WITH hourly_performance AS (
  SELECT
    EXTRACT(HOUR FROM event_datetime_utc) as hour,
    COUNT(DISTINCT tracking_id) as packages,
    -- Calculate throughput rate
    COUNT(DISTINCT CASE WHEN status_code = 'AT_STATION' THEN tracking_id END) as arrivals,
    COUNT(DISTINCT CASE WHEN status_code IN ('DEPARTED', 'DELIVERED') THEN tracking_id END) as departures,
    -- Missing DEA as root cause indicator
    SUM(CASE WHEN route_code IS NULL THEN 1 ELSE 0 END) as missing_dea_events
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'DCM3'
    AND DATE(event_datetime_utc) = '2024-12-17'
    AND ship_method LIKE '%RUSH%'
  GROUP BY hour
)
SELECT
  'HOURLY_BOTTLENECKS' as analysis,
  hour || ':00' as time,
  packages,
  arrivals,
  departures,
  arrivals - departures as net_accumulation,
  ROUND(missing_dea_events::FLOAT / packages * 100, 1) as missing_dea_pct,
  CASE
    WHEN arrivals > departures * 1.5 THEN '🔴 BOTTLENECK HOUR'
    WHEN arrivals > departures * 1.2 THEN '🟠 CONGESTED'
    ELSE '🟢 NORMAL'
  END as status
FROM hourly_performance
ORDER BY hour;

-- Root Cause: Missing DEA correlation with delays
WITH delay_analysis AS (
  SELECT
    tracking_id,
    MAX(CASE WHEN route_code IS NULL THEN 1 ELSE 0 END) as has_missing_dea,
    EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 as total_dwell_min
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'DCM3'
    AND DATE(event_datetime_utc) = '2024-12-17'
    AND ship_method LIKE '%RUSH%'
  GROUP BY tracking_id
)
SELECT
  'ROOT_CAUSE_ANALYSIS' as analysis,
  CASE
    WHEN has_missing_dea = 1 THEN 'Missing DEA'
    ELSE 'Has DEA'
  END as dea_status,
  COUNT(*) as packages,
  AVG(total_dwell_min) as avg_dwell,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_dwell_min) as median_dwell,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY total_dwell_min) as p95_dwell
FROM delay_analysis
GROUP BY has_missing_dea;