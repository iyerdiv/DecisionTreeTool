-- Find DELIVERY STATION data (not FC data!)
-- SWA1 is a last-mile delivery station for SSD, not a fulfillment center

-- 1. Look for delivery station specific tables
SELECT
  'DELIVERY_TABLES_SEARCH' as analysis,
  table_schema,
  table_name
FROM information_schema.tables
WHERE table_schema IN ('heisenbergrefinedobjects', 'bifrost', 'sandbox')
  AND (
    table_name LIKE '%delivery%'
    OR table_name LIKE '%last_mile%'
    OR table_name LIKE '%amzl%'
    OR table_name LIKE '%comp%'
    OR table_name LIKE '%cdes%'
    OR table_name LIKE '%station%'
  )
ORDER BY table_schema, table_name
LIMIT 30;

-- 2. Check if SWA1 exists in AMZL/delivery context
SELECT
  'SWA1_DELIVERY_SEARCH' as analysis,
  delivery_station_code,
  ship_method,
  COUNT(DISTINCT tracking_id) as packages,
  MIN(DATE(event_datetime_utc)) as earliest,
  MAX(DATE(event_datetime_utc)) as latest
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE (
    delivery_station_code = 'SWA1'
    OR delivery_station_code LIKE '%SWA%'
    OR delivery_station_code LIKE '%SEA%'  -- Seattle area
  )
  AND (
    ship_method LIKE '%AMZL%'  -- Amazon Logistics
    OR ship_method LIKE '%SSD%'   -- Sub Same Day
    OR ship_method LIKE '%SAME%'  -- Same Day
  )
GROUP BY delivery_station_code, ship_method
ORDER BY packages DESC;

-- 3. Find delivery stations (D-prefix pattern we saw earlier)
SELECT
  'DELIVERY_STATIONS' as analysis,
  delivery_station_code,
  COUNT(DISTINCT DATE(event_datetime_utc)) as days_active,
  COUNT(DISTINCT tracking_id) as packages,
  AVG(EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0) as avg_dwell_min
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE delivery_station_code LIKE 'D%'  -- Delivery stations often start with D
  AND DATE(event_datetime_utc) BETWEEN '2024-12-01' AND '2024-12-31'
  AND (ship_method LIKE '%SAME%' OR ship_method LIKE '%SSD%')
GROUP BY delivery_station_code, tracking_id
GROUP BY delivery_station_code
HAVING COUNT(DISTINCT tracking_id) > 1000
ORDER BY avg_dwell_min DESC
LIMIT 10;

-- 4. Check for last-mile/delivery events
SELECT
  'LAST_MILE_EVENTS' as analysis,
  status_code,
  COUNT(*) as event_count,
  COUNT(DISTINCT delivery_station_code) as stations,
  COUNT(DISTINCT tracking_id) as packages
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE DATE(event_datetime_utc) = '2024-12-17'
  AND (
    status_code LIKE '%DELIVER%'
    OR status_code LIKE '%ROUTE%'
    OR status_code LIKE '%VEHICLE%'
    OR status_code LIKE '%DRIVER%'
  )
GROUP BY status_code
ORDER BY event_count DESC
LIMIT 20;

-- 5. Find SSD delivery performance at D-stations
WITH delivery_performance AS (
  SELECT
    delivery_station_code,
    tracking_id,
    MIN(CASE WHEN status_code LIKE '%ARRIVE%' OR status_code = 'AT_STATION'
         THEN event_datetime_utc END) as arrival_time,
    MAX(CASE WHEN status_code LIKE '%DELIVER%' OR status_code LIKE '%DEPART%'
         THEN event_datetime_utc END) as departure_time
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code LIKE 'D%'
    AND DATE(event_datetime_utc) = '2024-12-17'
    AND (ship_method LIKE '%SAME%' OR ship_method LIKE '%SSD%')
  GROUP BY delivery_station_code, tracking_id
)
SELECT
  'SSD_DELIVERY_PERFORMANCE' as analysis,
  delivery_station_code,
  COUNT(*) as ssd_packages,
  COUNT(CASE
    WHEN EXTRACT(EPOCH FROM (departure_time - arrival_time))/60 <= 30
    THEN 1 END) as met_30min_target,
  AVG(EXTRACT(EPOCH FROM (departure_time - arrival_time))/60) as avg_station_dwell_min,
  MAX(EXTRACT(EPOCH FROM (departure_time - arrival_time))/60) as max_station_dwell_min
FROM delivery_performance
WHERE arrival_time IS NOT NULL
  AND departure_time IS NOT NULL
GROUP BY delivery_station_code
HAVING COUNT(*) > 100
ORDER BY avg_station_dwell_min DESC;