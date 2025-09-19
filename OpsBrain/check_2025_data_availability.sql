-- Focus on 2025 data availability
-- Check what we actually have for 2025

-- 1. What's the latest 2025 data we have?
SELECT 'LATEST_2025_DATA' as check_type,
  MAX(DATE(event_datetime_utc)) as latest_date,
  MIN(DATE(event_datetime_utc)) as earliest_date,
  COUNT(DISTINCT DATE(event_datetime_utc)) as days_with_data
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE DATE(event_datetime_utc) >= '2025-01-01';

-- 2. Check each day in September 2025
SELECT 'SEPT_2025_DAILY' as check_type,
  DATE(event_datetime_utc) as event_date,
  COUNT(DISTINCT tracking_id) as packages,
  COUNT(DISTINCT delivery_station_code) as stations,
  COUNT(*) as events
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE DATE(event_datetime_utc) BETWEEN '2025-09-01' AND '2025-09-18'
GROUP BY DATE(event_datetime_utc)
ORDER BY event_date DESC;

-- 3. Try earlier September 2025 dates (Sept 1-10)
SELECT 'EARLY_SEPT_2025' as check_type,
  delivery_station_code,
  COUNT(DISTINCT tracking_id) as packages
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE DATE(event_datetime_utc) BETWEEN '2025-09-01' AND '2025-09-10'
  AND ship_method LIKE '%RUSH%'
GROUP BY delivery_station_code
ORDER BY packages DESC
LIMIT 10;

-- 4. Check August 2025 (previous month)
SELECT 'AUG_2025_DATA' as check_type,
  DATE(event_datetime_utc) as event_date,
  COUNT(DISTINCT tracking_id) as packages
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE DATE(event_datetime_utc) BETWEEN '2025-08-15' AND '2025-08-31'
GROUP BY DATE(event_datetime_utc)
ORDER BY event_date DESC
LIMIT 10;

-- 5. Find ANY high dwell packages in 2025
WITH high_dwell_2025 AS (
  SELECT
    tracking_id,
    delivery_station_code,
    DATE(MIN(event_datetime_utc)) as event_date,
    EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 as dwell_min
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE DATE(event_datetime_utc) BETWEEN '2025-08-01' AND '2025-09-18'
    AND ship_method LIKE '%RUSH%'
  GROUP BY tracking_id, delivery_station_code
  HAVING EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 > 200
)
SELECT 'HIGH_DWELL_2025' as check_type,
  event_date,
  delivery_station_code,
  COUNT(*) as high_dwell_packages,
  AVG(dwell_min) as avg_dwell
FROM high_dwell_2025
GROUP BY event_date, delivery_station_code
ORDER BY event_date DESC, high_dwell_packages DESC
LIMIT 20;

-- 6. Sample tracking IDs from most recent 2025 data
SELECT 'SAMPLE_IDS_2025' as check_type,
  tracking_id,
  delivery_station_code,
  MIN(event_datetime_utc) as first_event,
  MAX(event_datetime_utc) as last_event,
  COUNT(*) as event_count
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE DATE(event_datetime_utc) = (
  SELECT MAX(DATE(event_datetime_utc))
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE DATE(event_datetime_utc) >= '2025-08-01'
)
  AND ship_method LIKE '%RUSH%'
GROUP BY tracking_id, delivery_station_code
ORDER BY event_count DESC
LIMIT 10;