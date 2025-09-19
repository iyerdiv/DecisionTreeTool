-- Diagnostic Queries to Find What's Actually in Heisenberg

-- 1. Check if the Mercury tracking IDs exist anywhere (any date, any station)
SELECT 'MERCURY_PACKAGES_CHECK' as check_type,
  tracking_id,
  MIN(DATE(event_datetime_utc)) as first_date,
  MAX(DATE(event_datetime_utc)) as last_date,
  COUNT(*) as event_count,
  COUNT(DISTINCT delivery_station_code) as station_count,
  ARRAY_AGG(DISTINCT delivery_station_code) as stations
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE tracking_id IN (
  'TBA324382452417', 'TBA324407564226', 'TBA324387931890',
  'TBA324328209818', 'TBA324408440124'
)
GROUP BY tracking_id;

-- 2. Check what stations exist with 'SWA' pattern
SELECT 'SWA_STATIONS' as check_type,
  delivery_station_code,
  COUNT(DISTINCT tracking_id) as packages,
  MIN(DATE(event_datetime_utc)) as first_date,
  MAX(DATE(event_datetime_utc)) as last_date
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE delivery_station_code LIKE '%SWA%'
  OR delivery_station_code LIKE '%SW%'
  OR delivery_station_code = 'SWA1'
GROUP BY delivery_station_code
LIMIT 20;

-- 3. Get top 10 stations for Sept 15-17, 2025
SELECT 'TOP_STATIONS_SEPT' as check_type,
  delivery_station_code,
  COUNT(DISTINCT tracking_id) as package_count,
  COUNT(*) as event_count
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE DATE(event_datetime_utc) BETWEEN '2025-09-15' AND '2025-09-17'
  AND ship_method LIKE '%RUSH%'
GROUP BY delivery_station_code
ORDER BY package_count DESC
LIMIT 10;

-- 4. Check date range of data
SELECT 'DATE_RANGE' as check_type,
  MIN(DATE(event_datetime_utc)) as earliest_date,
  MAX(DATE(event_datetime_utc)) as latest_date,
  COUNT(DISTINCT DATE(event_datetime_utc)) as days_with_data
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE DATE(event_datetime_utc) >= '2025-09-01';

-- 5. Sample tracking IDs from Sept 15-17
SELECT 'SAMPLE_TRACKING' as check_type,
  LEFT(tracking_id, 3) as prefix,
  COUNT(*) as count,
  MIN(tracking_id) as sample_id
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE DATE(event_datetime_utc) = '2025-09-16'
  AND ship_method LIKE '%RUSH%'
GROUP BY LEFT(tracking_id, 3)
ORDER BY count DESC
LIMIT 5;

-- 6. Find any station with high dwell packages (>200 min)
WITH high_dwell AS (
  SELECT
    delivery_station_code,
    tracking_id,
    EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 as dwell_min
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE DATE(event_datetime_utc) = '2025-09-16'
    AND ship_method LIKE '%RUSH%'
  GROUP BY delivery_station_code, tracking_id
  HAVING EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 > 200
)
SELECT 'HIGH_DWELL_STATIONS' as check_type,
  delivery_station_code,
  COUNT(*) as high_dwell_packages,
  AVG(dwell_min) as avg_dwell,
  MAX(dwell_min) as max_dwell
FROM high_dwell
GROUP BY delivery_station_code
ORDER BY high_dwell_packages DESC
LIMIT 10;