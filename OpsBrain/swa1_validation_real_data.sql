-- SWA1 Validation Query with REAL DATA (DCM3 station, Dec 2024)

-- Mercury benchmark data (keeping original for comparison)
WITH mercury_benchmark AS (
  SELECT 'TBA324382452417' as tracking_id, 2269 as mercury_dwell_min
  UNION ALL SELECT 'TBA324407564226', 267
  UNION ALL SELECT 'TBA324387931890', 289
  UNION ALL SELECT 'TBA324328209818', 2497
  UNION ALL SELECT 'TBA324408440124', 266
),

-- Our dwell calculation for Mercury packages (search all dates)
our_analysis AS (
  SELECT
    h.tracking_id,
    MIN(h.event_datetime_utc) as first_scan,
    MAX(h.event_datetime_utc) as last_scan,
    EXTRACT(EPOCH FROM (MAX(h.event_datetime_utc) - MIN(h.event_datetime_utc)))/60.0 as our_total_dwell_min,
    MIN(h.delivery_station_code) as station_code,
    COUNT(*) as event_count
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history h
  WHERE h.tracking_id IN (SELECT tracking_id FROM mercury_benchmark)
  GROUP BY h.tracking_id
)

-- Part 1: Mercury Validation Results
SELECT 
  'MERCURY_VALIDATION' as analysis_type,
  m.tracking_id,
  m.mercury_dwell_min,
  COALESCE(o.our_total_dwell_min, 0) as our_total_dwell_min,
  ABS(m.mercury_dwell_min - COALESCE(o.our_total_dwell_min, 0)) as delta_minutes,
  CASE
    WHEN o.tracking_id IS NULL THEN 'NOT_FOUND'
    WHEN ABS(m.mercury_dwell_min - o.our_total_dwell_min) < 30 THEN 'MATCH'
    WHEN ABS(m.mercury_dwell_min - o.our_total_dwell_min) < 60 THEN 'CLOSE'
    ELSE 'MISMATCH'
  END as validation_status,
  o.station_code,
  o.event_count
FROM mercury_benchmark m
LEFT JOIN our_analysis o ON m.tracking_id = o.tracking_id
ORDER BY m.mercury_dwell_min DESC;

-- Part 2: DCM3 High Dwell Analysis (Dec 17, 2024 - highest activity day)
WITH dcm3_analysis AS (
  SELECT
    h.tracking_id,
    EXTRACT(EPOCH FROM (MAX(h.event_datetime_utc) - MIN(h.event_datetime_utc)))/60.0 as total_dwell_min
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history h
  WHERE h.delivery_station_code = 'DCM3'
    AND DATE(h.event_datetime_utc) = '2024-12-17'
  GROUP BY h.tracking_id
  HAVING EXTRACT(EPOCH FROM (MAX(h.event_datetime_utc) - MIN(h.event_datetime_utc)))/60.0 > 200
)
SELECT 
  'DCM3_HIGH_DWELL' as analysis_type,
  COUNT(*) as total_high_dwell_packages,
  COUNT(CASE WHEN total_dwell_min BETWEEN 267 AND 307 THEN 1 END) as target_range_packages,
  AVG(total_dwell_min) as avg_dwell_minutes,
  MIN(total_dwell_min) as min_dwell,
  MAX(total_dwell_min) as max_dwell
FROM dcm3_analysis;

-- Part 3: DCM3 5-Minute Bottleneck Detection (Dec 17, 2024)
WITH five_min_flow AS (
  SELECT
    DATE_TRUNC('hour', event_datetime_utc) +
    INTERVAL '5 minutes' * FLOOR(EXTRACT(MINUTE FROM event_datetime_utc) / 5) as interval_time,
    COUNT(CASE WHEN status_code LIKE '%STATION%' THEN 1 END) as arrivals,
    COUNT(DISTINCT tracking_id) as inventory,
    COUNT(CASE WHEN status_code IN ('DELIVERED', 'OUT_FOR_DELIVERY') THEN 1 END) as exits
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'DCM3'
    AND DATE(event_datetime_utc) = '2024-12-17'
  GROUP BY DATE_TRUNC('hour', event_datetime_utc) +
           INTERVAL '5 minutes' * FLOOR(EXTRACT(MINUTE FROM event_datetime_utc) / 5)
)
SELECT
  'DCM3_BOTTLENECK_5MIN' as analysis_type,
  TO_CHAR(interval_time, 'HH24:MI') as time_5min,
  arrivals,
  inventory,
  exits,
  CASE
    WHEN arrivals > 0 THEN ROUND(inventory::FLOAT / arrivals * 60, 0)
    ELSE 0
  END as wait_minutes,
  CASE
    WHEN arrivals > 0 AND exits > 0 THEN
      CASE
        WHEN arrivals::FLOAT / NULLIF(exits, 0) > 1.5 THEN 'BOTTLENECK'
        WHEN arrivals::FLOAT / NULLIF(exits, 0) > 1.2 THEN 'CONGESTION'
        ELSE 'NORMAL'
      END
    ELSE 'NORMAL'
  END as flow_status
FROM five_min_flow
WHERE arrivals > 0
  AND EXTRACT(HOUR FROM interval_time) BETWEEN 8 AND 20
ORDER BY interval_time
LIMIT 50;
