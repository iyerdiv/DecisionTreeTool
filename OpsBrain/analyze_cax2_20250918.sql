-- CAX2 Analysis for September 2025 - Dashboard Validation
-- Focus: Missing DEA issues and dwell time analysis

-- First check if we have 2025 data
WITH data_check AS (
  SELECT
    DATE(event_datetime_utc) as event_date,
    COUNT(*) as record_count,
    COUNT(DISTINCT tracking_id) as unique_packages
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'CAX2'
    AND DATE(event_datetime_utc) BETWEEN '2025-09-17' AND '2025-09-18'
  GROUP BY DATE(event_datetime_utc)
),

-- Find packages with Missing DEA or high dwell
problem_packages AS (
  SELECT
    tracking_id,
    delivery_station_code,
    ship_method,
    status_code,
    event_datetime_utc,
    route_code,
    reason_code,
    -- Calculate dwell between events
    LAG(event_datetime_utc) OVER (PARTITION BY tracking_id ORDER BY event_datetime_utc) as prev_event_time,
    EXTRACT(EPOCH FROM (
      event_datetime_utc - LAG(event_datetime_utc) OVER (PARTITION BY tracking_id ORDER BY event_datetime_utc)
    ))/60 as minutes_between_events
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'CAX2'
    AND DATE(event_datetime_utc) = '2025-09-18'
    AND ship_method LIKE '%RUSH%'
),

-- Identify Missing DEA patterns
dea_analysis AS (
  SELECT
    tracking_id,
    -- Check for DEA assignment
    MAX(CASE WHEN route_code IS NOT NULL THEN 1 ELSE 0 END) as has_route,
    MAX(CASE WHEN status_code = 'READY_FOR_DEPARTURE' THEN 1 ELSE 0 END) as ready_for_departure,
    MAX(CASE WHEN status_code = 'OUT_FOR_DELIVERY' THEN 1 ELSE 0 END) as out_for_delivery,
    MIN(event_datetime_utc) as first_scan,
    MAX(event_datetime_utc) as last_scan,
    EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60 as total_dwell_minutes
  FROM problem_packages
  GROUP BY tracking_id
),

-- Find packages stuck without DEA assignment
missing_dea AS (
  SELECT
    tracking_id,
    first_scan,
    last_scan,
    total_dwell_minutes,
    CASE
      WHEN has_route = 0 THEN 'NO_ROUTE_ASSIGNED'
      WHEN ready_for_departure = 0 THEN 'NOT_READY_FOR_DEPARTURE'
      WHEN out_for_delivery = 0 THEN 'NOT_OUT_FOR_DELIVERY'
      ELSE 'OTHER_ISSUE'
    END as dea_issue_type
  FROM dea_analysis
  WHERE has_route = 0 OR ready_for_departure = 0
),

-- Summary for dashboard validation
summary AS (
  SELECT
    'CAX2 Analysis - Sept 18, 2025' as report,
    COUNT(DISTINCT tracking_id) as total_ssd_packages,
    COUNT(DISTINCT CASE WHEN dea_issue_type = 'NO_ROUTE_ASSIGNED' THEN tracking_id END) as missing_dea_count,
    AVG(total_dwell_minutes) as avg_dwell_minutes,
    MAX(total_dwell_minutes) as max_dwell_minutes,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY total_dwell_minutes) as p95_dwell_minutes
  FROM missing_dea
)

-- Output results
SELECT * FROM summary;

-- Detail view of stuck packages
SELECT
  tracking_id,
  TO_CHAR(first_scan, 'HH24:MI') as first_scan_time,
  TO_CHAR(last_scan, 'HH24:MI') as last_scan_time,
  ROUND(total_dwell_minutes, 0) as dwell_minutes,
  dea_issue_type
FROM missing_dea
WHERE total_dwell_minutes > 30  -- SSD violation
ORDER BY total_dwell_minutes DESC
LIMIT 20;