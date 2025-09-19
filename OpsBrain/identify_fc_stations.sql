-- Identify FC (Fulfillment Center) stations vs other types
-- Amazon station naming conventions:
-- FCs: Usually 3-4 letters ending in numbers (e.g., PHX6, ONT2)
-- Sort Centers: Often start with D (e.g., DXX1, DCM3, DLX5)
-- Delivery Stations: Often start with D or have specific patterns

-- 1. Check station code patterns
SELECT
  'STATION_PATTERNS' as analysis,
  LEFT(delivery_station_code, 1) as first_letter,
  CASE
    WHEN delivery_station_code LIKE 'D%' THEN 'Likely Delivery/Sort Center'
    WHEN delivery_station_code ~ '^[A-Z]{3}[0-9]$' THEN 'Likely FC (XXX#)'
    WHEN delivery_station_code ~ '^[A-Z]{2,4}[0-9]{1,2}$' THEN 'Likely FC'
    ELSE 'Unknown Pattern'
  END as station_type,
  COUNT(DISTINCT delivery_station_code) as station_count,
  STRING_AGG(DISTINCT delivery_station_code, ', ' ORDER BY delivery_station_code) as sample_stations
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE DATE(event_datetime_utc) BETWEEN '2024-12-01' AND '2024-12-31'
  AND delivery_station_code IS NOT NULL
GROUP BY first_letter, station_type
ORDER BY station_count DESC;

-- 2. Look for traditional FC patterns (3-letter code + number)
SELECT
  'FC_CANDIDATES' as analysis,
  delivery_station_code,
  COUNT(DISTINCT DATE(event_datetime_utc)) as days_with_data,
  COUNT(DISTINCT tracking_id) as total_packages,
  COUNT(*) as total_events
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE DATE(event_datetime_utc) BETWEEN '2024-12-01' AND '2024-12-31'
  AND delivery_station_code ~ '^[A-Z]{3}[0-9]{1,2}$'  -- Pattern: XXX# or XXX##
  AND delivery_station_code NOT LIKE 'D%'  -- Exclude D-prefix stations
  AND ship_method LIKE '%RUSH%'
GROUP BY delivery_station_code
HAVING COUNT(DISTINCT tracking_id) > 1000  -- Significant volume
ORDER BY total_packages DESC
LIMIT 20;

-- 3. Check our original UAT stations
SELECT
  'UAT_STATION_CHECK' as analysis,
  delivery_station_code,
  CASE
    WHEN delivery_station_code LIKE 'D%' THEN 'Sort/Delivery Center'
    WHEN delivery_station_code ~ '^[A-Z]{3}[0-9]{1,2}$' THEN 'Fulfillment Center'
    ELSE 'Unknown Type'
  END as station_type,
  COUNT(DISTINCT tracking_id) as packages,
  COUNT(*) as events
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE delivery_station_code IN ('CAX2', 'DCK1', 'STL8', 'VNY5', 'SWA1', 'DCM3', 'DLX5')
  AND DATE(event_datetime_utc) BETWEEN '2024-12-01' AND '2024-12-31'
GROUP BY delivery_station_code;

-- 4. Find FCs with high dwell issues (focus on real FCs)
WITH fc_dwell AS (
  SELECT
    delivery_station_code,
    tracking_id,
    EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 as dwell_minutes
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE DATE(event_datetime_utc) BETWEEN '2024-12-01' AND '2024-12-31'
    AND delivery_station_code ~ '^[A-Z]{3}[0-9]{1,2}$'  -- FC pattern
    AND delivery_station_code NOT LIKE 'D%'
    AND ship_method LIKE '%RUSH%'
  GROUP BY delivery_station_code, tracking_id
)
SELECT
  'FC_BOTTLENECK_STATIONS' as analysis,
  delivery_station_code,
  COUNT(DISTINCT CASE WHEN dwell_minutes > 180 THEN tracking_id END) as high_dwell_packages,
  COUNT(DISTINCT tracking_id) as total_packages,
  ROUND(COUNT(DISTINCT CASE WHEN dwell_minutes > 180 THEN tracking_id END)::FLOAT /
        NULLIF(COUNT(DISTINCT tracking_id), 0) * 100, 1) as high_dwell_pct,
  AVG(CASE WHEN dwell_minutes > 180 THEN dwell_minutes END) as avg_high_dwell
FROM fc_dwell
GROUP BY delivery_station_code
HAVING COUNT(DISTINCT CASE WHEN dwell_minutes > 180 THEN tracking_id END) > 10
ORDER BY high_dwell_pct DESC
LIMIT 10;