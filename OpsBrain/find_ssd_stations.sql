-- Find Sub Same Day (SSD) Fulfillment Centers
-- S prefix = Sub Same Day FC, not Sort Center!
-- SWA1 = Sub Same Day FC in Everett, WA

-- 1. Check if SWA1 exists in any time period
SELECT
  'SWA1_EXISTENCE_CHECK' as analysis,
  delivery_station_code,
  MIN(DATE(event_datetime_utc)) as earliest_date,
  MAX(DATE(event_datetime_utc)) as latest_date,
  COUNT(DISTINCT DATE(event_datetime_utc)) as days_with_data,
  COUNT(DISTINCT tracking_id) as total_packages,
  COUNT(*) as total_events
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE delivery_station_code = 'SWA1'
GROUP BY delivery_station_code;

-- 2. Find all S-prefix stations (likely SSD FCs)
SELECT
  'SSD_FC_STATIONS' as analysis,
  delivery_station_code,
  COUNT(DISTINCT DATE(event_datetime_utc)) as days_active,
  COUNT(DISTINCT tracking_id) as total_packages,
  MIN(DATE(event_datetime_utc)) as first_seen,
  MAX(DATE(event_datetime_utc)) as last_seen
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE delivery_station_code LIKE 'S%'  -- SSD FCs
  AND DATE(event_datetime_utc) BETWEEN '2024-01-01' AND '2025-12-31'
GROUP BY delivery_station_code
ORDER BY total_packages DESC
LIMIT 20;

-- 3. Check for SSD-specific ship methods
SELECT
  'SSD_SHIP_METHODS' as analysis,
  delivery_station_code,
  ship_method,
  COUNT(DISTINCT tracking_id) as packages
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE (delivery_station_code LIKE 'S%' OR ship_method LIKE '%SSD%' OR ship_method LIKE '%SAME%')
  AND DATE(event_datetime_utc) BETWEEN '2024-12-01' AND '2024-12-31'
GROUP BY delivery_station_code, ship_method
HAVING COUNT(DISTINCT tracking_id) > 100
ORDER BY packages DESC
LIMIT 20;

-- 4. Find SSD FC bottlenecks (30-minute target is critical!)
WITH ssd_performance AS (
  SELECT
    delivery_station_code,
    tracking_id,
    DATE(MIN(event_datetime_utc)) as event_date,
    EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 as dwell_minutes,
    CASE
      WHEN EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 <= 30 THEN 'Met SSD Target'
      WHEN EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 <= 60 THEN 'Missed by <30min'
      WHEN EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 <= 120 THEN 'Missed by 30-90min'
      ELSE 'Critical Miss (>90min)'
    END as ssd_performance
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code LIKE 'S%'  -- SSD FCs
    AND DATE(event_datetime_utc) BETWEEN '2024-12-01' AND '2024-12-31'
    AND (ship_method LIKE '%RUSH%' OR ship_method LIKE '%SAME%' OR ship_method LIKE '%SSD%')
  GROUP BY delivery_station_code, tracking_id
)
SELECT
  'SSD_PERFORMANCE_SUMMARY' as analysis,
  delivery_station_code,
  COUNT(DISTINCT tracking_id) as total_packages,
  COUNT(CASE WHEN ssd_performance = 'Met SSD Target' THEN 1 END) as met_30min_target,
  COUNT(CASE WHEN ssd_performance = 'Critical Miss (>90min)' THEN 1 END) as critical_misses,
  ROUND(COUNT(CASE WHEN ssd_performance = 'Met SSD Target' THEN 1 END)::FLOAT /
        NULLIF(COUNT(DISTINCT tracking_id), 0) * 100, 1) as ssd_success_rate,
  AVG(dwell_minutes) as avg_dwell_min,
  MAX(dwell_minutes) as max_dwell_min
FROM ssd_performance
GROUP BY delivery_station_code
HAVING COUNT(DISTINCT tracking_id) > 100
ORDER BY ssd_success_rate ASC;  -- Worst performers first

-- 5. If SWA1 not found, check alternate date ranges
SELECT
  'SWA1_ALTERNATE_DATES' as analysis,
  delivery_station_code,
  DATE(event_datetime_utc) as event_date,
  COUNT(DISTINCT tracking_id) as packages,
  COUNT(*) as events
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE delivery_station_code IN ('SWA1', 'SWA2', 'SWA3', 'SWA4', 'SWA5')  -- Check related codes
  OR delivery_station_code LIKE '%WA%'  -- Washington state stations
GROUP BY delivery_station_code, DATE(event_datetime_utc)
ORDER BY event_date DESC
LIMIT 20;