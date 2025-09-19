-- Find Real Dates in Database (Not Corrupted Future Dates)

-- 1. Check date range distribution
SELECT 
  'DATE_RANGE_CHECK' as analysis_type,
  EXTRACT(YEAR FROM event_datetime_utc) as year,
  COUNT(*) as events,
  MIN(DATE(event_datetime_utc)) as earliest_date,
  MAX(DATE(event_datetime_utc)) as latest_date
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE EXTRACT(YEAR FROM event_datetime_utc) BETWEEN 2020 AND 2025
GROUP BY EXTRACT(YEAR FROM event_datetime_utc)
ORDER BY year DESC;

-- 2. Find reasonable dates (2024-2025) with most activity
SELECT 
  'REASONABLE_DATES' as analysis_type,
  DATE(event_datetime_utc) as date,
  COUNT(*) as events,
  COUNT(DISTINCT delivery_station_code) as stations,
  COUNT(DISTINCT tracking_id) as packages
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE DATE(event_datetime_utc) BETWEEN '2024-01-01' AND '2025-12-31'
GROUP BY DATE(event_datetime_utc)
ORDER BY events DESC
LIMIT 20;

-- 3. Top stations in 2024-2025 timeframe
SELECT 
  'TOP_STATIONS_2024_2025' as analysis_type,
  delivery_station_code,
  COUNT(*) as events,
  COUNT(DISTINCT tracking_id) as packages,
  MIN(DATE(event_datetime_utc)) as first_date,
  MAX(DATE(event_datetime_utc)) as last_date
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE DATE(event_datetime_utc) BETWEEN '2024-01-01' AND '2025-12-31'
  AND delivery_station_code IS NOT NULL
GROUP BY delivery_station_code
ORDER BY events DESC
LIMIT 15;

-- 4. Check September 2024 specifically for RUSH packages
SELECT 
  'SEPT_2024_RUSH' as analysis_type,
  DATE(event_datetime_utc) as date,
  delivery_station_code,
  COUNT(*) as events,
  COUNT(DISTINCT tracking_id) as packages
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE DATE(event_datetime_utc) BETWEEN '2024-09-01' AND '2024-09-30'
  AND ship_method LIKE '%RUSH%'
  AND delivery_station_code IS NOT NULL
GROUP BY DATE(event_datetime_utc), delivery_station_code
ORDER BY events DESC
LIMIT 20;

-- 5. Search for Mercury packages without date restriction
SELECT 
  'MERCURY_PACKAGES_SEARCH' as analysis_type,
  tracking_id,
  DATE(event_datetime_utc) as event_date,
  delivery_station_code,
  COUNT(*) as events
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE tracking_id IN ('TBA324382452417', 'TBA324407564226', 'TBA324387931890', 'TBA324328209818', 'TBA324408440124')
GROUP BY tracking_id, DATE(event_datetime_utc), delivery_station_code
ORDER BY tracking_id, event_date;
