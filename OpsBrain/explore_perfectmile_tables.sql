-- Explore the perfectmile tables we found

-- 1. Check d_perfectmile_global_dea (most promising)
SELECT 'GLOBAL_DEA_RECENT' as check_type,
  COUNT(*) as row_count,
  MIN(DATE(event_datetime_utc)) as earliest_date,
  MAX(DATE(event_datetime_utc)) as latest_date,
  COUNT(DISTINCT delivery_station_code) as stations
FROM heisenbergrefinedobjects.d_perfectmile_global_dea
WHERE DATE(event_datetime_utc) BETWEEN '2024-01-01' AND '2025-12-31'
LIMIT 1;

-- 2. Sample data from global_dea
SELECT 'GLOBAL_DEA_SAMPLE' as check_type,
  delivery_station_code,
  DATE(event_datetime_utc) as event_date,
  COUNT(*) as events
FROM heisenbergrefinedobjects.d_perfectmile_global_dea
WHERE DATE(event_datetime_utc) BETWEEN '2024-09-01' AND '2024-09-30'
  AND delivery_station_code IS NOT NULL
GROUP BY delivery_station_code, DATE(event_datetime_utc)
ORDER BY events DESC
LIMIT 10;

-- 3. Check for tracking IDs in global_dea
SELECT 'TRACKING_ID_CHECK' as check_type,
  tracking_id,
  delivery_station_code,
  event_datetime_utc
FROM heisenbergrefinedobjects.d_perfectmile_global_dea
WHERE tracking_id IN (
  'TBA324382452417', 'TBA324407564226', 'TBA324387931890',
  'TBA324328209818', 'TBA324408440124'
)
LIMIT 10;

-- 4. Check d_perfectmile_delivered_dea table
SELECT 'DELIVERED_DEA_CHECK' as check_type,
  COUNT(*) as total,
  MIN(DATE(event_datetime_utc)) as earliest,
  MAX(DATE(event_datetime_utc)) as latest
FROM heisenbergrefinedobjects.d_perfectmile_delivered_dea
WHERE DATE(event_datetime_utc) BETWEEN '2024-01-01' AND '2025-12-31'
LIMIT 1;

-- 5. Find which table has the most recent data
WITH table_dates AS (
  SELECT 'd_perfectmile_global_dea' as table_name,
    MAX(DATE(event_datetime_utc)) as latest_date
  FROM heisenbergrefinedobjects.d_perfectmile_global_dea
  WHERE DATE(event_datetime_utc) < CURRENT_DATE

  UNION ALL

  SELECT 'd_perfectmile_delivered_dea' as table_name,
    MAX(DATE(event_datetime_utc)) as latest_date
  FROM heisenbergrefinedobjects.d_perfectmile_delivered_dea
  WHERE DATE(event_datetime_utc) < CURRENT_DATE
)
SELECT 'LATEST_DATA_BY_TABLE' as check_type,
  table_name,
  latest_date
FROM table_dates
ORDER BY latest_date DESC;