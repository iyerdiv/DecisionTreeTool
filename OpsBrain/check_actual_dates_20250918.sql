-- Check what dates actually have data in the system
-- Try both 2024 and 2025

-- 1. Check September 2024 data (last year)
SELECT 'SEPT_2024_DATA' as check_type,
  DATE(event_datetime_utc) as event_date,
  COUNT(DISTINCT tracking_id) as packages,
  COUNT(DISTINCT delivery_station_code) as stations,
  COUNT(*) as total_events
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE DATE(event_datetime_utc) BETWEEN '2024-09-12' AND '2024-09-17'
GROUP BY DATE(event_datetime_utc)
ORDER BY event_date;

-- 2. Check recent 2025 data (if any)
SELECT 'RECENT_2025_DATA' as check_type,
  DATE(event_datetime_utc) as event_date,
  COUNT(DISTINCT tracking_id) as packages,
  COUNT(DISTINCT delivery_station_code) as stations
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE DATE(event_datetime_utc) >= '2025-09-01'
GROUP BY DATE(event_datetime_utc)
ORDER BY event_date DESC
LIMIT 10;

-- 3. Check for Mercury packages in 2024
SELECT 'MERCURY_2024' as check_type,
  tracking_id,
  MIN(DATE(event_datetime_utc)) as first_date,
  MAX(DATE(event_datetime_utc)) as last_date,
  COUNT(*) as event_count,
  MIN(delivery_station_code) as station
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE tracking_id IN (
  'TBA324382452417', 'TBA324407564226', 'TBA324387931890',
  'TBA324328209818', 'TBA324408440124'
)
  AND DATE(event_datetime_utc) BETWEEN '2024-09-01' AND '2024-09-30'
GROUP BY tracking_id;

-- 4. Get the most recent data available
SELECT 'MOST_RECENT_DATA' as check_type,
  MAX(DATE(event_datetime_utc)) as latest_date,
  MIN(DATE(event_datetime_utc)) as earliest_date
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE DATE(event_datetime_utc) >= '2024-01-01';

-- 5. Check SWA1 in 2024
SELECT 'SWA1_2024' as check_type,
  DATE(event_datetime_utc) as event_date,
  COUNT(DISTINCT tracking_id) as packages
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE delivery_station_code = 'SWA1'
  AND DATE(event_datetime_utc) BETWEEN '2024-09-12' AND '2024-09-17'
GROUP BY DATE(event_datetime_utc);

-- 6. Top stations in September 2024
SELECT 'TOP_STATIONS_2024' as check_type,
  delivery_station_code,
  COUNT(DISTINCT tracking_id) as packages
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE DATE(event_datetime_utc) = '2024-09-15'
  AND ship_method LIKE '%RUSH%'
GROUP BY delivery_station_code
ORDER BY packages DESC
LIMIT 10;