-- Simple Little's Law Bottleneck Detection
-- L = λ × W (Inventory = Arrival Rate × Wait Time)
-- When L grows faster than λ, we have a bottleneck

-- Step 1: Pick a station we KNOW has data (DCM3 on Dec 17, 2024)
WITH flow_metrics AS (
  SELECT
    -- 5-minute time buckets
    DATE_TRUNC('hour', event_datetime_utc) +
    INTERVAL '5 minutes' * FLOOR(EXTRACT(MINUTE FROM event_datetime_utc) / 5) as time_bucket,

    -- L: Inventory (unique packages in system during this 5-min window)
    COUNT(DISTINCT tracking_id) as L_inventory,

    -- λ: Arrivals (packages entering - AT_STATION events)
    COUNT(DISTINCT CASE
      WHEN status_code = 'AT_STATION' THEN tracking_id
    END) as lambda_arrivals,

    -- μ: Departures (packages leaving - DEPARTED/DELIVERED events)
    COUNT(DISTINCT CASE
      WHEN status_code IN ('DEPARTED', 'DELIVERED') THEN tracking_id
    END) as mu_departures,

    -- Total events (activity level)
    COUNT(*) as total_events

  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'DCM3'
    AND DATE(event_datetime_utc) = '2024-12-17'
    AND ship_method LIKE '%RUSH%'
  GROUP BY time_bucket
)
SELECT
  TO_CHAR(time_bucket, 'HH24:MI') as time,
  L_inventory as L,
  lambda_arrivals as lambda_in,
  mu_departures as mu_out,

  -- Calculate implied wait time: W = L/λ
  CASE
    WHEN lambda_arrivals > 0
    THEN ROUND(L_inventory::FLOAT / lambda_arrivals * 5, 1)  -- ×5 for 5-min buckets
    ELSE NULL
  END as W_implied_minutes,

  -- Flow balance: λ - μ (positive = accumulation)
  lambda_arrivals - mu_departures as net_accumulation,

  -- Bottleneck detection
  CASE
    WHEN lambda_arrivals > mu_departures * 2 THEN '🔴 SEVERE BOTTLENECK'
    WHEN lambda_arrivals > mu_departures * 1.5 THEN '🟠 BOTTLENECK'
    WHEN lambda_arrivals > mu_departures * 1.2 THEN '🟡 CONGESTION'
    WHEN mu_departures > lambda_arrivals THEN '🟢 CLEARING'
    ELSE '⚪ NORMAL'
  END as bottleneck_status

FROM flow_metrics
WHERE L_inventory > 0  -- Only show active periods
  AND EXTRACT(HOUR FROM time_bucket) BETWEEN 12 AND 20  -- Business hours
ORDER BY time_bucket
LIMIT 96;  -- 8 hours × 12 five-min periods

-- Step 2: Summary statistics to confirm Little's Law
WITH period_stats AS (
  SELECT
    DATE_TRUNC('hour', event_datetime_utc) as hour,

    -- Average inventory per hour
    COUNT(DISTINCT tracking_id) as L_avg,

    -- Arrival rate per hour
    COUNT(DISTINCT CASE WHEN status_code = 'AT_STATION' THEN tracking_id END) as lambda_total,

    -- Calculate average dwell time
    AVG(EXTRACT(EPOCH FROM (
      MAX(event_datetime_utc) - MIN(event_datetime_utc)
    )) / 60.0) as W_actual_minutes

  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'DCM3'
    AND DATE(event_datetime_utc) = '2024-12-17'
    AND ship_method LIKE '%RUSH%'
  GROUP BY hour, tracking_id
  GROUP BY hour
)
SELECT
  TO_CHAR(hour, 'HH24:00') as hour,
  L_avg as L_inventory,
  lambda_total as lambda_hourly,
  ROUND(W_actual_minutes, 1) as W_actual_min,

  -- Verify Little's Law: L should ≈ λ × W
  ROUND(lambda_total * (W_actual_minutes / 60.0), 0) as L_calculated,

  -- Error percentage
  ROUND(ABS(L_avg - (lambda_total * (W_actual_minutes / 60.0))) / NULLIF(L_avg, 0) * 100, 1) as error_pct

FROM period_stats
WHERE EXTRACT(HOUR FROM hour) BETWEEN 12 AND 20
ORDER BY hour;