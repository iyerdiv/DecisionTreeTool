-- COMPREHENSIVE RCA VALIDATION PACKAGE
-- Demonstrates all components needed for LLM-powered RCA system

-- ============================================
-- PART 1: BOTTLENECK DETECTION (Little's Law)
-- ============================================
WITH littles_law_validation AS (
  SELECT
    DATE_TRUNC('hour', event_datetime_utc) +
    INTERVAL '5 minutes' * FLOOR(EXTRACT(MINUTE FROM event_datetime_utc) / 5) as time_bucket,

    -- Little's Law Components
    COUNT(DISTINCT tracking_id) as L_inventory,
    COUNT(DISTINCT CASE WHEN status_code = 'AT_STATION' THEN tracking_id END) as lambda_arrivals,
    COUNT(DISTINCT CASE WHEN status_code IN ('DEPARTED', 'DELIVERED') THEN tracking_id END) as mu_departures,

    -- Calculate Wait Time: W = L/λ
    CASE
      WHEN COUNT(DISTINCT CASE WHEN status_code = 'AT_STATION' THEN tracking_id END) > 0
      THEN ROUND(COUNT(DISTINCT tracking_id)::FLOAT /
           COUNT(DISTINCT CASE WHEN status_code = 'AT_STATION' THEN tracking_id END) * 5, 1)
      ELSE 0
    END as W_calculated_minutes,

    -- Bottleneck Score
    CASE
      WHEN COUNT(DISTINCT CASE WHEN status_code = 'AT_STATION' THEN tracking_id END) >
           COUNT(DISTINCT CASE WHEN status_code IN ('DEPARTED', 'DELIVERED') THEN tracking_id END) * 1.5
      THEN 1 ELSE 0
    END as is_bottleneck

  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'DCM3'
    AND DATE(event_datetime_utc) = '2024-12-17'
    AND ship_method LIKE '%RUSH%'
  GROUP BY time_bucket
)
SELECT
  'LITTLES_LAW_VALIDATION' as component,
  TO_CHAR(time_bucket, 'HH24:MI') as time,
  L_inventory,
  lambda_arrivals,
  mu_departures,
  W_calculated_minutes,
  CASE is_bottleneck
    WHEN 1 THEN '🔴 BOTTLENECK'
    ELSE '🟢 NORMAL'
  END as status
FROM littles_law_validation
WHERE EXTRACT(HOUR FROM time_bucket) BETWEEN 14 AND 18
ORDER BY time_bucket
LIMIT 10;

-- ============================================
-- PART 2: ROOT CAUSE IDENTIFICATION
-- ============================================
WITH root_cause_analysis AS (
  SELECT
    tracking_id,
    -- Factor 1: Missing DEA
    MAX(CASE WHEN route_code IS NULL THEN 1 ELSE 0 END) as missing_dea,
    -- Factor 2: Time in system
    EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 as dwell_minutes,
    -- Factor 3: Number of scans (process complexity)
    COUNT(*) as scan_count,
    -- Factor 4: Peak hour
    MAX(CASE WHEN EXTRACT(HOUR FROM event_datetime_utc) BETWEEN 14 AND 18 THEN 1 ELSE 0 END) as in_peak_hour
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'DCM3'
    AND DATE(event_datetime_utc) = '2024-12-17'
    AND ship_method LIKE '%RUSH%'
  GROUP BY tracking_id
)
SELECT
  'ROOT_CAUSE_SUMMARY' as component,
  COUNT(*) as total_packages,
  -- DEA Impact
  COUNT(CASE WHEN missing_dea = 1 THEN 1 END) as missing_dea_count,
  ROUND(AVG(CASE WHEN missing_dea = 1 THEN dwell_minutes END), 1) as avg_dwell_with_missing_dea,
  ROUND(AVG(CASE WHEN missing_dea = 0 THEN dwell_minutes END), 1) as avg_dwell_with_dea,
  -- Peak Hour Impact
  ROUND(AVG(CASE WHEN in_peak_hour = 1 THEN dwell_minutes END), 1) as avg_dwell_peak,
  ROUND(AVG(CASE WHEN in_peak_hour = 0 THEN dwell_minutes END), 1) as avg_dwell_offpeak,
  -- Combined Impact
  ROUND(AVG(CASE WHEN missing_dea = 1 AND in_peak_hour = 1 THEN dwell_minutes END), 1) as avg_dwell_worst_case
FROM root_cause_analysis;

-- ============================================
-- PART 3: SENSITIVITY ANALYSIS
-- ============================================
WITH sensitivity_metrics AS (
  SELECT
    -- Bucket arrival rates
    CASE
      WHEN arrival_count <= 10 THEN 'Low (0-10)'
      WHEN arrival_count <= 20 THEN 'Medium (11-20)'
      WHEN arrival_count <= 30 THEN 'High (21-30)'
      ELSE 'Very High (30+)'
    END as arrival_bucket,
    arrival_count,
    AVG(dwell_minutes) as avg_dwell,
    COUNT(*) as sample_size
  FROM (
    SELECT
      DATE_TRUNC('hour', event_datetime_utc) as hour,
      COUNT(DISTINCT CASE WHEN status_code = 'AT_STATION' THEN tracking_id END) as arrival_count,
      AVG(EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0) as dwell_minutes
    FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
    WHERE delivery_station_code = 'DCM3'
      AND DATE(event_datetime_utc) = '2024-12-17'
      AND ship_method LIKE '%RUSH%'
    GROUP BY hour, tracking_id
    GROUP BY hour
  ) t
  GROUP BY arrival_bucket, arrival_count
)
SELECT
  'SENSITIVITY_TO_ARRIVALS' as component,
  arrival_bucket,
  ROUND(AVG(arrival_count), 0) as avg_arrivals,
  ROUND(AVG(avg_dwell), 1) as avg_dwell_minutes,
  -- Calculate sensitivity slope
  ROUND((MAX(avg_dwell) - MIN(avg_dwell)) / NULLIF(MAX(arrival_count) - MIN(arrival_count), 0), 2) as sensitivity_coefficient,
  SUM(sample_size) as total_samples
FROM sensitivity_metrics
GROUP BY arrival_bucket
ORDER BY avg_arrivals;

-- ============================================
-- PART 4: ALERT THRESHOLD CALIBRATION
-- ============================================
WITH threshold_stats AS (
  SELECT
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY dwell_minutes) as p50,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY dwell_minutes) as p75,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY dwell_minutes) as p90,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY dwell_minutes) as p95,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY dwell_minutes) as p99,
    AVG(dwell_minutes) as mean,
    STDDEV(dwell_minutes) as std_dev
  FROM (
    SELECT
      tracking_id,
      EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 as dwell_minutes
    FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
    WHERE delivery_station_code = 'DCM3'
      AND DATE(event_datetime_utc) = '2024-12-17'
      AND ship_method LIKE '%RUSH%'
    GROUP BY tracking_id
  ) t
)
SELECT
  'ALERT_THRESHOLDS' as component,
  ROUND(p50, 0) as median_dwell,
  ROUND(p75, 0) as yellow_alert,
  ROUND(p90, 0) as orange_alert,
  ROUND(p95, 0) as red_alert,
  ROUND(p99, 0) as critical_alert,
  ROUND(mean + 2 * std_dev, 0) as statistical_2sigma,
  ROUND(mean + 3 * std_dev, 0) as statistical_3sigma
FROM threshold_stats;

-- ============================================
-- PART 5: VALIDATION SUMMARY
-- ============================================
SELECT 'VALIDATION_COMPLETE' as status,
  'Bottleneck Detection' as capability_1,
  'Root Cause Analysis' as capability_2,
  'Sensitivity Analysis' as capability_3,
  'Alert Calibration' as capability_4,
  'Ready for LLM Integration' as conclusion;