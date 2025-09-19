-- FINAL UAT Validation Query
-- Using DCM3 station with confirmed 4.4M events on Dec 17, 2024
-- Table: heisenbergrefinedobjects.d_perfectmile_shipment_status_history (confirmed exists)

-- 1. Verify DCM3 data volume for Dec 17, 2024
SELECT
  'DATA_VERIFICATION' as analysis_type,
  delivery_station_code,
  DATE(event_datetime_utc) as event_date,
  COUNT(DISTINCT tracking_id) as unique_packages,
  COUNT(*) as total_events
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE delivery_station_code = 'DCM3'
  AND DATE(event_datetime_utc) = '2024-12-17'
GROUP BY delivery_station_code, DATE(event_datetime_utc);

-- 2. Dwell Time Distribution Analysis (Like Mercury's DwellTime column)
WITH package_dwell AS (
  SELECT
    tracking_id,
    MIN(event_datetime_utc) as first_event,
    MAX(event_datetime_utc) as last_event,
    EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 as dwell_minutes,
    COUNT(*) as event_count,
    MAX(CASE WHEN route_code IS NULL THEN 1 ELSE 0 END) as missing_dea
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'DCM3'
    AND DATE(event_datetime_utc) = '2024-12-17'
    AND ship_method LIKE '%RUSH%'
  GROUP BY tracking_id
)
SELECT
  'DWELL_DISTRIBUTION' as analysis_type,
  CASE
    WHEN dwell_minutes < 30 THEN '0-30 min (SSD Target)'
    WHEN dwell_minutes < 60 THEN '30-60 min'
    WHEN dwell_minutes < 120 THEN '1-2 hours'
    WHEN dwell_minutes < 180 THEN '2-3 hours'
    WHEN dwell_minutes < 240 THEN '3-4 hours'
    WHEN dwell_minutes >= 240 THEN '4+ hours (Like Mercury 267-2497 min)'
  END as dwell_category,
  COUNT(*) as package_count,
  ROUND(AVG(dwell_minutes), 1) as avg_dwell,
  MAX(dwell_minutes) as max_dwell,
  SUM(missing_dea) as missing_dea_count
FROM package_dwell
GROUP BY dwell_category
ORDER BY
  CASE dwell_category
    WHEN '0-30 min (SSD Target)' THEN 1
    WHEN '30-60 min' THEN 2
    WHEN '1-2 hours' THEN 3
    WHEN '2-3 hours' THEN 4
    WHEN '3-4 hours' THEN 5
    ELSE 6
  END;

-- 3. 5-Minute Interval Bottleneck Detection (2-6 PM Peak)
WITH five_minute_flow AS (
  SELECT
    DATE_TRUNC('hour', event_datetime_utc) +
    INTERVAL '5 minutes' * FLOOR(EXTRACT(MINUTE FROM event_datetime_utc) / 5) as time_slot,
    COUNT(DISTINCT tracking_id) as L_packages_in_system,
    SUM(CASE WHEN status_code = 'AT_STATION' THEN 1 ELSE 0 END) as lambda_arrivals,
    SUM(CASE WHEN status_code IN ('DEPARTED', 'DELIVERED') THEN 1 ELSE 0 END) as mu_departures,
    SUM(CASE WHEN route_code IS NULL THEN 1 ELSE 0 END) as missing_dea_events
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'DCM3'
    AND DATE(event_datetime_utc) = '2024-12-17'
    AND EXTRACT(HOUR FROM event_datetime_utc) BETWEEN 14 AND 18  -- 2-6 PM
    AND ship_method LIKE '%RUSH%'
  GROUP BY 1
)
SELECT
  'BOTTLENECK_5MIN' as analysis_type,
  TO_CHAR(time_slot, 'HH24:MI') as time_5min,
  L_packages_in_system,
  lambda_arrivals,
  mu_departures,
  CASE
    WHEN lambda_arrivals > 0
    THEN ROUND(L_packages_in_system::FLOAT / lambda_arrivals * 5, 1)
    ELSE 0
  END as W_wait_minutes,
  ROUND(missing_dea_events::FLOAT / NULLIF(L_packages_in_system, 0) * 100, 1) as missing_dea_pct,
  CASE
    WHEN lambda_arrivals > mu_departures * 1.5 THEN 'BOTTLENECK'
    WHEN lambda_arrivals > mu_departures * 1.2 THEN 'CONGESTED'
    ELSE 'NORMAL'
  END as flow_status
FROM five_minute_flow
WHERE L_packages_in_system > 0
ORDER BY time_slot
LIMIT 48;  -- All 5-min slots from 2-6 PM

-- 4. Sample High-Dwell Packages (Validation Examples)
SELECT
  'HIGH_DWELL_SAMPLES' as analysis_type,
  tracking_id,
  MIN(event_datetime_utc) as first_scan,
  MAX(event_datetime_utc) as last_scan,
  EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 as dwell_minutes,
  COUNT(*) as event_count,
  MAX(CASE WHEN route_code IS NULL THEN 'Missing DEA' ELSE 'Has DEA' END) as dea_status
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE delivery_station_code = 'DCM3'
  AND DATE(event_datetime_utc) = '2024-12-17'
  AND ship_method LIKE '%RUSH%'
GROUP BY tracking_id
HAVING EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 > 240  -- 4+ hours like Mercury
ORDER BY dwell_minutes DESC
LIMIT 10;