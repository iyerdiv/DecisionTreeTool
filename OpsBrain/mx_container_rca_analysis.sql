-- M(x) Container Model for Root Cause Analysis
-- Identifies WHERE in the process flow packages accumulate

-- Using any station with data (since we can't find SWA1)
-- This demonstrates RCA capability, not specific validation

WITH container_levels AS (
  SELECT
    DATE_TRUNC('hour', event_datetime_utc) +
    INTERVAL '5 minutes' * FLOOR(EXTRACT(MINUTE FROM event_datetime_utc) / 5) as time_bucket,

    -- M1: Inducted but not stowed (AT_STATION but no STOWED status)
    COUNT(DISTINCT CASE
      WHEN status_code = 'AT_STATION' THEN tracking_id
    END) as M1_inducted_not_stowed,

    -- M2: Stowed but not picked (STOWED but no PICKED status)
    COUNT(DISTINCT CASE
      WHEN status_code = 'STOWED' THEN tracking_id
    END) as M2_stowed_not_picked,

    -- M3: Picked but not packed (PICKED but no PACKED status)
    COUNT(DISTINCT CASE
      WHEN status_code IN ('PICKED', 'PICKING') THEN tracking_id
    END) as M3_picked_not_packed,

    -- M4: Packed but not sorted (PACKED but no SORTED status)
    COUNT(DISTINCT CASE
      WHEN status_code IN ('PACKED', 'SLAM') THEN tracking_id
    END) as M4_packed_not_sorted,

    -- M5: Sorted but not departed (Missing DEA or awaiting departure)
    COUNT(DISTINCT CASE
      WHEN status_code IN ('SORTED', 'READY_FOR_DEPARTURE')
        AND route_code IS NULL THEN tracking_id
    END) as M5_missing_dea,

    -- Total packages in system
    COUNT(DISTINCT tracking_id) as total_in_system

  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'DCM3'  -- Replace with any station
    AND DATE(event_datetime_utc) = '2024-12-17'
    AND EXTRACT(HOUR FROM event_datetime_utc) BETWEEN 14 AND 18  -- Peak hours
  GROUP BY time_bucket
)
SELECT
  TO_CHAR(time_bucket, 'HH24:MI') as time_5min,
  M1_inducted_not_stowed as M1,
  M2_stowed_not_picked as M2,
  M3_picked_not_packed as M3,
  M4_packed_not_sorted as M4,
  M5_missing_dea as M5,
  total_in_system as L_total,

  -- RCA: Identify which container is the bottleneck
  CASE
    WHEN M1_inducted_not_stowed > total_in_system * 0.3 THEN 'STOW_BOTTLENECK'
    WHEN M2_stowed_not_picked > total_in_system * 0.3 THEN 'PICK_BOTTLENECK'
    WHEN M3_picked_not_packed > total_in_system * 0.3 THEN 'PACK_BOTTLENECK'
    WHEN M4_packed_not_sorted > total_in_system * 0.3 THEN 'SORT_BOTTLENECK'
    WHEN M5_missing_dea > total_in_system * 0.3 THEN 'DEA_BOTTLENECK'
    ELSE 'NORMAL_FLOW'
  END as root_cause,

  -- Little's Law validation: W = L/λ
  CASE
    WHEN M1_inducted_not_stowed > 0
    THEN ROUND(total_in_system::FLOAT / NULLIF(M1_inducted_not_stowed, 0) * 5, 1)
    ELSE 0
  END as wait_time_minutes

FROM container_levels
ORDER BY time_bucket;

-- Summary: Which container causes most delays?
WITH bottleneck_summary AS (
  SELECT
    CASE
      WHEN status_code = 'AT_STATION' THEN 'M1_Pre_Stow'
      WHEN status_code = 'STOWED' THEN 'M2_Inventory'
      WHEN status_code IN ('PICKED', 'PICKING') THEN 'M3_Pre_Pack'
      WHEN status_code IN ('PACKED', 'SLAM') THEN 'M4_Pre_Sort'
      WHEN status_code IN ('SORTED', 'READY_FOR_DEPARTURE') AND route_code IS NULL THEN 'M5_Missing_DEA'
      ELSE 'Other'
    END as container,
    COUNT(*) as events,
    COUNT(DISTINCT tracking_id) as packages,
    AVG(EXTRACT(EPOCH FROM (
      LEAD(event_datetime_utc) OVER (PARTITION BY tracking_id ORDER BY event_datetime_utc) - event_datetime_utc
    ))/60.0) as avg_time_in_container_min
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'DCM3'
    AND DATE(event_datetime_utc) = '2024-12-17'
    AND EXTRACT(HOUR FROM event_datetime_utc) BETWEEN 14 AND 18
  GROUP BY container
)
SELECT
  container,
  packages,
  events,
  ROUND(avg_time_in_container_min, 1) as avg_minutes,
  CASE
    WHEN avg_time_in_container_min > 60 THEN '⚠️ BOTTLENECK'
    WHEN avg_time_in_container_min > 30 THEN '⚡ SLOW'
    ELSE '✅ OK'
  END as status
FROM bottleneck_summary
ORDER BY avg_time_in_container_min DESC;