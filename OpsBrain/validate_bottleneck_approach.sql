-- Validation Approach: Find Bottlenecks, Then Deep Dive

-- STEP 1: Find the station with most bottlenecks
WITH bottleneck_summary AS (
  SELECT
    delivery_station_code,
    DATE(event_datetime_utc) as event_date,
    COUNT(DISTINCT tracking_id) as total_packages,
    -- Calculate high-dwell packages
    COUNT(DISTINCT CASE
      WHEN tracking_id IN (
        SELECT tracking_id
        FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history s2
        WHERE s2.tracking_id = s1.tracking_id
          AND DATE(s2.event_datetime_utc) = DATE(s1.event_datetime_utc)
        GROUP BY tracking_id
        HAVING EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 > 180
      ) THEN tracking_id
    END) as high_dwell_packages,
    -- Missing DEA count
    SUM(CASE WHEN route_code IS NULL THEN 1 ELSE 0 END) as missing_dea_events
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history s1
  WHERE DATE(event_datetime_utc) BETWEEN '2024-01-01' AND '2025-12-31'
    AND delivery_station_code IS NOT NULL
    AND ship_method LIKE '%RUSH%'
  GROUP BY delivery_station_code, DATE(event_datetime_utc)
  HAVING COUNT(DISTINCT tracking_id) > 100  -- Meaningful volume
)
SELECT
  'TOP_BOTTLENECK_STATIONS' as analysis,
  delivery_station_code,
  COUNT(DISTINCT event_date) as days_with_issues,
  SUM(high_dwell_packages) as total_high_dwell,
  AVG(missing_dea_events::FLOAT / NULLIF(total_packages, 0) * 100) as avg_missing_dea_pct,
  MAX(event_date) as most_recent_date
FROM bottleneck_summary
WHERE high_dwell_packages > 10  -- Days with significant delays
GROUP BY delivery_station_code
ORDER BY total_high_dwell DESC
LIMIT 5;

-- STEP 2: Once we identify the top station, run this with that station code
-- (Replace 'XXX' with the station code from Step 1)

/*
-- 5-Minute Interval Analysis for Specific Station
WITH five_minute_intervals AS (
  SELECT
    DATE_TRUNC('hour', event_datetime_utc) +
    INTERVAL '5 minutes' * FLOOR(EXTRACT(MINUTE FROM event_datetime_utc) / 5) as time_slot,
    COUNT(DISTINCT tracking_id) as packages,
    COUNT(CASE WHEN status_code = 'AT_STATION' THEN 1 END) as arrivals,
    COUNT(CASE WHEN route_code IS NULL THEN 1 END) as missing_dea,
    COUNT(CASE WHEN status_code IN ('DELIVERED', 'DEPARTED') THEN 1 END) as exits
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'XXX'  -- Replace with station from Step 1
    AND DATE(event_datetime_utc) = 'YYYY-MM-DD'  -- Replace with date from Step 1
    AND ship_method LIKE '%RUSH%'
    AND EXTRACT(HOUR FROM event_datetime_utc) BETWEEN 12 AND 20
  GROUP BY 1
)
SELECT
  TO_CHAR(time_slot, 'HH24:MI') as time_5min,
  packages,
  arrivals as lambda_arrivals,
  exits as mu_exits,
  packages as L_inventory,
  CASE
    WHEN arrivals > 0 THEN ROUND(packages::FLOAT / arrivals * 5, 1)  -- W = L/λ (in minutes)
    ELSE 0
  END as W_wait_minutes,
  CASE
    WHEN arrivals > exits * 1.5 THEN 'BOTTLENECK'
    WHEN arrivals > exits * 1.2 THEN 'CONGESTION'
    ELSE 'NORMAL'
  END as flow_status
FROM five_minute_intervals
WHERE packages > 0
ORDER BY time_slot;
*/