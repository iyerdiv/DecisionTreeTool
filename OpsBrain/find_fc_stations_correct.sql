-- Find FULFILLMENT CENTERS (B prefix) with bottleneck issues
-- Using correct Amazon naming conventions

-- 1. Verify station types in our data
SELECT
  'STATION_TYPES' as analysis,
  CASE
    WHEN delivery_station_code LIKE 'D%' THEN 'Delivery Station'
    WHEN delivery_station_code LIKE 'B%' THEN 'Fulfillment Center'
    WHEN delivery_station_code LIKE 'S%' THEN 'Sort Center'
    WHEN delivery_station_code LIKE 'A%' THEN 'Air Hub'
    ELSE 'Other/Legacy'
  END as station_type,
  COUNT(DISTINCT delivery_station_code) as station_count,
  STRING_AGG(DISTINCT delivery_station_code, ', ' ORDER BY delivery_station_code LIMIT 10) as sample_stations
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE DATE(event_datetime_utc) BETWEEN '2024-12-01' AND '2024-12-31'
  AND delivery_station_code IS NOT NULL
GROUP BY station_type
ORDER BY station_count DESC;

-- 2. Find Fulfillment Centers (B prefix) with high volume
SELECT
  'FC_HIGH_VOLUME' as analysis,
  delivery_station_code,
  COUNT(DISTINCT DATE(event_datetime_utc)) as days_active,
  COUNT(DISTINCT tracking_id) as total_packages,
  COUNT(*) as total_events
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE delivery_station_code LIKE 'B%'  -- Fulfillment Centers only
  AND DATE(event_datetime_utc) BETWEEN '2024-12-01' AND '2024-12-31'
  AND ship_method LIKE '%RUSH%'
GROUP BY delivery_station_code
HAVING COUNT(DISTINCT tracking_id) > 1000
ORDER BY total_packages DESC
LIMIT 10;

-- 3. Check what our original stations actually are
SELECT
  'ORIGINAL_STATIONS_TYPE' as analysis,
  delivery_station_code,
  CASE
    WHEN delivery_station_code LIKE 'D%' THEN 'Delivery Station'
    WHEN delivery_station_code LIKE 'B%' THEN 'Fulfillment Center'
    WHEN delivery_station_code LIKE 'S%' THEN 'Sort Center'
    WHEN delivery_station_code LIKE 'A%' THEN 'Air Hub'
    ELSE 'Other/Legacy'
  END as station_type,
  COUNT(DISTINCT tracking_id) as packages_dec_2024
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE delivery_station_code IN ('SWA1', 'CAX2', 'DCK1', 'STL8', 'VNY5', 'DCM3', 'DLX5')
  AND DATE(event_datetime_utc) BETWEEN '2024-12-01' AND '2024-12-31'
GROUP BY delivery_station_code
ORDER BY packages_dec_2024 DESC;

-- 4. Find FCs with bottleneck issues (B prefix only)
WITH fc_bottlenecks AS (
  SELECT
    delivery_station_code,
    tracking_id,
    DATE(MIN(event_datetime_utc)) as event_date,
    EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 as dwell_minutes,
    MAX(CASE WHEN route_code IS NULL THEN 1 ELSE 0 END) as missing_dea
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code LIKE 'B%'  -- FCs only
    AND DATE(event_datetime_utc) BETWEEN '2024-12-15' AND '2024-12-17'  -- Recent dates
    AND ship_method LIKE '%RUSH%'
  GROUP BY delivery_station_code, tracking_id
)
SELECT
  'FC_WITH_BOTTLENECKS' as analysis,
  delivery_station_code,
  COUNT(DISTINCT tracking_id) as total_packages,
  COUNT(DISTINCT CASE WHEN dwell_minutes > 180 THEN tracking_id END) as high_dwell_packages,
  ROUND(COUNT(DISTINCT CASE WHEN dwell_minutes > 180 THEN tracking_id END)::FLOAT /
        NULLIF(COUNT(DISTINCT tracking_id), 0) * 100, 1) as high_dwell_pct,
  SUM(missing_dea) as missing_dea_packages,
  AVG(CASE WHEN dwell_minutes > 180 THEN dwell_minutes END) as avg_high_dwell_min
FROM fc_bottlenecks
GROUP BY delivery_station_code
HAVING COUNT(DISTINCT tracking_id) > 100
ORDER BY high_dwell_pct DESC
LIMIT 10;

-- 5. Alternative: Check Sort Centers (S prefix) since SWA1 is one
SELECT
  'SORT_CENTER_CHECK' as analysis,
  delivery_station_code,
  COUNT(DISTINCT tracking_id) as packages,
  AVG(EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0) as avg_dwell_min
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE delivery_station_code LIKE 'S%'  -- Sort Centers
  AND DATE(event_datetime_utc) = '2024-12-17'
  AND ship_method LIKE '%RUSH%'
GROUP BY delivery_station_code, tracking_id
GROUP BY delivery_station_code
HAVING COUNT(DISTINCT tracking_id) > 100
ORDER BY avg_dwell_min DESC
LIMIT 5;