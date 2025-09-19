-- FIXED: 5-Minute Container Analysis with Accurate Dwell Logic
-- Handles packages that skip states and calculates true dwell times

WITH date_params AS (
  -- Use most recent date with data
  SELECT
    '2025-09-15'::date as analysis_date,
    'DLA8' as station
),

five_minute_intervals AS (
  -- Generate 5-minute intervals for the full day
  SELECT generate_series(
    (SELECT analysis_date FROM date_params)::timestamp,
    (SELECT analysis_date FROM date_params)::timestamp + INTERVAL '23 hours 55 minutes',
    INTERVAL '5 minutes'
  ) as interval_start
),

-- Get all package events for RUSH packages
package_events AS (
  SELECT
    tracking_id,
    event_datetime_utc,
    status_code,
    ship_method,
    ROW_NUMBER() OVER (PARTITION BY tracking_id, status_code ORDER BY event_datetime_utc) as status_occurrence
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = (SELECT station FROM date_params)
    AND DATE(event_datetime_utc) = (SELECT analysis_date FROM date_params)
    AND (ship_method LIKE '%RUSH%' OR ship_method LIKE '%SDD%')
),

-- Calculate key timestamps for each package (using FIRST occurrence of each status)
package_milestones AS (
  SELECT
    tracking_id,
    -- Entry point: First time package arrives at station
    MIN(CASE WHEN status_code = 'AT_STATION' AND status_occurrence = 1
             THEN event_datetime_utc END) as inducted_time,
    -- Container 1 exit: First time package is stowed (may be NULL if skipped)
    MIN(CASE WHEN status_code = 'STOWED' AND status_occurrence = 1
             THEN event_datetime_utc END) as stowed_time,
    -- Final exit: First time package leaves (any departure status)
    MIN(CASE WHEN status_code IN ('READY_FOR_DEPARTURE', 'OUT_FOR_DELIVERY', 'DELIVERED')
             AND status_occurrence = 1 THEN event_datetime_utc END) as departed_time
  FROM package_events
  GROUP BY tracking_id
  HAVING MIN(CASE WHEN status_code = 'AT_STATION' THEN event_datetime_utc END) IS NOT NULL
),

-- Calculate dwell times for each package
package_dwell AS (
  SELECT
    tracking_id,
    inducted_time,
    stowed_time,
    departed_time,
    -- Container 1 dwell: Induction to stow (or departure if no stow)
    CASE
      WHEN stowed_time IS NOT NULL THEN
        EXTRACT(EPOCH FROM (stowed_time - inducted_time))/60
      WHEN departed_time IS NOT NULL THEN
        EXTRACT(EPOCH FROM (departed_time - inducted_time))/60
      ELSE NULL
    END as container1_minutes,
    -- Container 2 dwell: Stow to departure (only if stowed)
    CASE
      WHEN stowed_time IS NOT NULL AND departed_time IS NOT NULL THEN
        EXTRACT(EPOCH FROM (departed_time - stowed_time))/60
      ELSE NULL
    END as container2_minutes,
    -- Total dwell: Entry to exit
    CASE
      WHEN departed_time IS NOT NULL THEN
        EXTRACT(EPOCH FROM (departed_time - inducted_time))/60
      ELSE
        EXTRACT(EPOCH FROM (NOW() - inducted_time))/60  -- Still in station
    END as total_dwell_minutes
  FROM package_milestones
),

-- Calculate container populations at each 5-minute interval
interval_populations AS (
  SELECT
    fi.interval_start,
    TO_CHAR(fi.interval_start, 'HH24:MI') as time_label,

    -- Container 1: Inducted but not yet stowed or departed
    COUNT(DISTINCT CASE
      WHEN pd.inducted_time <= fi.interval_start
        AND (pd.stowed_time IS NULL OR pd.stowed_time > fi.interval_start)
        AND (pd.departed_time IS NULL OR pd.departed_time > fi.interval_start)
      THEN pd.tracking_id
    END) as container1_count,

    -- Container 2: Stowed but not yet departed
    COUNT(DISTINCT CASE
      WHEN pd.stowed_time IS NOT NULL
        AND pd.stowed_time <= fi.interval_start
        AND (pd.departed_time IS NULL OR pd.departed_time > fi.interval_start)
      THEN pd.tracking_id
    END) as container2_count,

    -- Total packages in station
    COUNT(DISTINCT CASE
      WHEN pd.inducted_time <= fi.interval_start
        AND (pd.departed_time IS NULL OR pd.departed_time > fi.interval_start)
      THEN pd.tracking_id
    END) as total_in_station

  FROM five_minute_intervals fi
  CROSS JOIN package_dwell pd
  GROUP BY fi.interval_start
  ORDER BY fi.interval_start
)

-- Main output: 5-minute interval metrics
SELECT
  time_label,
  container1_count,
  container2_count,
  total_in_station,
  -- Identify bottlenecks based on thresholds
  CASE
    WHEN container1_count > 50 THEN 'INDUCTION_BOTTLENECK'
    WHEN container2_count > 50 THEN 'STAGING_BOTTLENECK'
    WHEN total_in_station > 100 THEN 'STATION_OVERLOAD'
    ELSE 'NORMAL'
  END as bottleneck_status,
  -- Running average to smooth spikes
  AVG(container1_count) OVER (ORDER BY interval_start ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING) as container1_smooth,
  AVG(container2_count) OVER (ORDER BY interval_start ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING) as container2_smooth
FROM interval_populations
ORDER BY interval_start;

-- Add summary statistics at the end
SELECT
  'SUMMARY' as metric_type,
  COUNT(*) as total_packages,
  ROUND(AVG(total_dwell_minutes), 1) as avg_dwell_minutes,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_dwell_minutes), 1) as median_dwell_minutes,
  ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY total_dwell_minutes), 1) as p95_dwell_minutes,
  COUNT(CASE WHEN total_dwell_minutes <= 30 THEN 1 END) as met_sla_count,
  COUNT(CASE WHEN total_dwell_minutes > 30 THEN 1 END) as missed_sla_count,
  ROUND(100.0 * COUNT(CASE WHEN total_dwell_minutes <= 30 THEN 1 END) / COUNT(*), 1) as sla_compliance_pct
FROM package_dwell
WHERE departed_time IS NOT NULL;