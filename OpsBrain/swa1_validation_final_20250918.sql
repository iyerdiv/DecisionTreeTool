-- SWA1 Validation Query - Final Fixed Version
-- Testing against Mercury ground truth data

-- Part 1: Check specific Mercury packages
SELECT
  'Mercury Package Check' as analysis_type,
  tracking_id,
  delivery_station_code,
  MIN(event_datetime_utc) as first_scan,
  MAX(event_datetime_utc) as last_scan,
  COUNT(*) as event_count,
  EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60 as calculated_dwell_min
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE tracking_id IN (
  'TBA324382452417',  -- Mercury: 2269 min
  'TBA324407564226',  -- Mercury: 267 min
  'TBA324387931890',  -- Mercury: 289 min
  'TBA324328209818',  -- Mercury: 2497 min
  'TBA324408440124'   -- Mercury: 266 min
)
AND DATE(event_datetime_utc) BETWEEN '2025-09-12' AND '2025-09-17'
GROUP BY tracking_id, delivery_station_code
ORDER BY calculated_dwell_min DESC;

-- Part 2: Find all high-dwell packages at SWA1
SELECT
  'SWA1 High Dwell Summary' as analysis_type,
  COUNT(DISTINCT tracking_id) as total_packages,
  COUNT(DISTINCT CASE
    WHEN EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60 > 200
    THEN tracking_id
  END) as high_dwell_count,
  COUNT(DISTINCT CASE
    WHEN EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60 BETWEEN 267 AND 307
    THEN tracking_id
  END) as in_target_range,
  ROUND(AVG(EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60), 1) as avg_dwell_min
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE delivery_station_code = 'SWA1'
  AND DATE(event_datetime_utc) BETWEEN '2025-09-15' AND '2025-09-16'
  AND ship_method LIKE '%RUSH%'
GROUP BY tracking_id;

-- Part 3: Little's Law - Hourly bottleneck analysis
WITH hourly_stats AS (
  SELECT
    DATE_TRUNC('hour', event_datetime_utc) as hour,
    COUNT(DISTINCT CASE WHEN status_code = 'AT_STATION' THEN tracking_id END) as arrivals,
    COUNT(DISTINCT tracking_id) as inventory,
    COUNT(DISTINCT CASE WHEN status_code IN ('DELIVERED', 'READY_FOR_DEPARTURE') THEN tracking_id END) as exits
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'SWA1'
    AND DATE(event_datetime_utc) = '2025-09-15'
  GROUP BY DATE_TRUNC('hour', event_datetime_utc)
)
SELECT
  TO_CHAR(hour, 'HH24:00') as time_hour,
  arrivals as lambda_arrivals,
  inventory as L_inventory,
  CASE
    WHEN arrivals > 0
    THEN ROUND(inventory::NUMERIC / arrivals * 60, 0)
    ELSE 0
  END as W_wait_minutes,
  CASE
    WHEN arrivals > 0 AND exits > 0 AND arrivals::NUMERIC / exits > 1.5 THEN 'BOTTLENECK'
    WHEN arrivals > 0 AND exits > 0 AND arrivals::NUMERIC / exits > 1.2 THEN 'CONGESTION'
    ELSE 'NORMAL'
  END as status
FROM hourly_stats
WHERE arrivals > 0
ORDER BY hour;

-- Part 4: Missing DEA Analysis at SWA1
SELECT
  'Missing DEA Analysis' as analysis_type,
  DATE(event_datetime_utc) as date,
  COUNT(DISTINCT tracking_id) as total_rush_packages,
  COUNT(DISTINCT CASE WHEN route_code IS NULL THEN tracking_id END) as missing_dea,
  ROUND(100.0 * COUNT(DISTINCT CASE WHEN route_code IS NULL THEN tracking_id END) /
    NULLIF(COUNT(DISTINCT tracking_id), 0), 1) as missing_dea_pct
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE delivery_station_code = 'SWA1'
  AND DATE(event_datetime_utc) BETWEEN '2025-09-15' AND '2025-09-16'
  AND ship_method LIKE '%RUSH%'
  AND status_code = 'AT_STATION'
GROUP BY DATE(event_datetime_utc);