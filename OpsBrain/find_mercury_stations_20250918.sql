-- Find which stations these Mercury packages are from
-- Focus on high-dwell unfixed packages

WITH mercury_packages AS (
  SELECT * FROM (VALUES
    ('TBA324382452417', 2269, 'Unfixed'),  -- 37.8 hours
    ('TBA324407564226', 267, 'Unfixed'),   -- 4.5 hours
    ('TBA324387931890', 289, 'Unfixed'),   -- 4.8 hours
    ('TBA324407650027', 246, 'Unfixed'),
    ('TBA324328209818', 2497, 'Unfixed'),  -- 41.6 hours!
    ('TBA324322667321', 951, 'Unfixed'),   -- 15.8 hours
    ('TBA324408440124', 266, 'Unfixed'),
    ('TBA324408371373', 263, 'Unfixed'),
    ('TBA324432069410', 196, 'Unfixed')
  ) AS t(tracking_id, mercury_dwell_min, status)
),

-- Get station and journey for each package
package_stations AS (
  SELECT DISTINCT
    mp.tracking_id,
    mp.mercury_dwell_min,
    mp.status as mercury_status,
    h.delivery_station_code,
    h.ship_method,
    MIN(h.event_datetime_utc) as first_scan,
    MAX(h.event_datetime_utc) as last_scan,
    COUNT(DISTINCT h.status_code) as status_changes,
    MAX(CASE WHEN h.route_code IS NOT NULL THEN 'Has_Route' ELSE 'No_Route' END) as route_assignment
  FROM mercury_packages mp
  LEFT JOIN heisenbergrefinedobjects.d_perfectmile_shipment_status_history h
    ON mp.tracking_id = h.tracking_id
  WHERE DATE(h.event_datetime_utc) BETWEEN '2025-09-13' AND '2025-09-17'
  GROUP BY mp.tracking_id, mp.mercury_dwell_min, mp.status, h.delivery_station_code, h.ship_method
)

-- Summary by station
SELECT
  delivery_station_code,
  COUNT(DISTINCT tracking_id) as package_count,
  AVG(mercury_dwell_min) as avg_dwell_minutes,
  MAX(mercury_dwell_min) as max_dwell_minutes,
  COUNT(CASE WHEN route_assignment = 'No_Route' THEN 1 END) as missing_dea_count,
  STRING_AGG(DISTINCT ship_method, ', ') as ship_methods
FROM package_stations
WHERE delivery_station_code IS NOT NULL
GROUP BY delivery_station_code
ORDER BY package_count DESC;