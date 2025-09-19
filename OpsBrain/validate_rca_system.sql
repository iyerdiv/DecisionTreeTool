-- Validate RCA System Components
-- Shows how our analysis feeds the LLM-powered RCA architecture

-- 1. DEA MISS DETECTION (Input for LLM system)
WITH dea_miss_events AS (
  SELECT
    DATE_TRUNC('hour', event_datetime_utc) as hour,
    COUNT(DISTINCT CASE WHEN route_code IS NULL THEN tracking_id END) as dea_misses,
    COUNT(DISTINCT tracking_id) as total_packages,
    ROUND(COUNT(DISTINCT CASE WHEN route_code IS NULL THEN tracking_id END)::FLOAT /
          NULLIF(COUNT(DISTINCT tracking_id), 0) * 100, 1) as dea_miss_rate
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'DCM3'
    AND DATE(event_datetime_utc) = '2024-12-17'
    AND ship_method LIKE '%RUSH%'
  GROUP BY hour
)
SELECT
  'DEA_MISS_INPUT' as component,
  TO_CHAR(hour, 'HH24:00') as time,
  dea_misses,
  total_packages,
  dea_miss_rate || '%' as miss_rate,
  CASE
    WHEN dea_miss_rate > 20 THEN '🔴 ALERT: High DEA Miss Rate'
    WHEN dea_miss_rate > 10 THEN '🟠 WARNING: Elevated DEA Miss'
    ELSE '🟢 Normal'
  END as alert_status
FROM dea_miss_events
ORDER BY hour;

-- 2. TRACKING ID ANOMALY DETECTION (For alerts)
WITH tracking_anomalies AS (
  SELECT
    tracking_id,
    COUNT(*) as event_count,
    COUNT(DISTINCT status_code) as unique_statuses,
    EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 as dwell_minutes,
    MAX(CASE WHEN route_code IS NULL THEN 1 ELSE 0 END) as has_dea_miss
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'DCM3'
    AND DATE(event_datetime_utc) = '2024-12-17'
    AND ship_method LIKE '%RUSH%'
  GROUP BY tracking_id
)
SELECT
  'TRACKING_ALERTS' as component,
  COUNT(CASE WHEN dwell_minutes > 240 THEN 1 END) as extreme_dwell_alerts,
  COUNT(CASE WHEN has_dea_miss = 1 AND dwell_minutes > 120 THEN 1 END) as dea_related_delays,
  COUNT(CASE WHEN unique_statuses < 3 THEN 1 END) as incomplete_scan_alerts,
  COUNT(CASE WHEN event_count > 20 THEN 1 END) as excessive_scan_alerts
FROM tracking_anomalies;

-- 3. DELTA ANALYSIS (Generated vs Observed)
-- This would compare predicted vs actual, using Little's Law
WITH predicted_vs_actual AS (
  SELECT
    DATE_TRUNC('hour', event_datetime_utc) as hour,
    -- Actual metrics
    COUNT(DISTINCT tracking_id) as L_actual,
    COUNT(DISTINCT CASE WHEN status_code = 'AT_STATION' THEN tracking_id END) as lambda_actual,
    -- Predicted using Little's Law (L = λW, assuming W = 30 min for SSD)
    COUNT(DISTINCT CASE WHEN status_code = 'AT_STATION' THEN tracking_id END) * 0.5 as L_predicted
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'DCM3'
    AND DATE(event_datetime_utc) = '2024-12-17'
    AND ship_method LIKE '%RUSH%'
  GROUP BY hour
)
SELECT
  'DELTA_ANALYSIS' as component,
  TO_CHAR(hour, 'HH24:00') as time,
  L_actual as actual_inventory,
  ROUND(L_predicted, 0) as predicted_inventory,
  L_actual - L_predicted as delta,
  ROUND(ABS(L_actual - L_predicted)::FLOAT / NULLIF(L_actual, 0) * 100, 1) as error_pct,
  CASE
    WHEN ABS(L_actual - L_predicted) > L_actual * 0.5 THEN '🔴 Model Deviation Alert'
    WHEN ABS(L_actual - L_predicted) > L_actual * 0.3 THEN '🟠 Model Warning'
    ELSE '🟢 Model Accurate'
  END as model_status
FROM predicted_vs_actual
WHERE EXTRACT(HOUR FROM hour) BETWEEN 12 AND 20
ORDER BY hour;

-- 4. ALERT THRESHOLDS (Statistical Analysis Output)
WITH threshold_calculation AS (
  SELECT
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY dwell_minutes) as median_dwell,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY dwell_minutes) as p75_dwell,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY dwell_minutes) as p95_dwell,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY dwell_minutes) as p99_dwell,
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
  ROUND(median_dwell, 0) as median_baseline,
  ROUND(p75_dwell, 0) as warning_threshold,
  ROUND(p95_dwell, 0) as alert_threshold,
  ROUND(p99_dwell, 0) as critical_threshold,
  ROUND(median_dwell + 2 * std_dev, 0) as statistical_alert_2sigma,
  ROUND(median_dwell + 3 * std_dev, 0) as statistical_alert_3sigma
FROM threshold_calculation;