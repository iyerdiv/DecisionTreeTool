-- SENSITIVITY ANALYSIS for RCA
-- Identifies which variables have the strongest impact on outcomes

-- 1. SENSITIVITY TO ARRIVAL RATE (λ)
-- How does increasing arrival rate affect dwell time?
WITH arrival_sensitivity AS (
  SELECT
    DATE_TRUNC('hour', event_datetime_utc) as hour,
    -- Arrival rate (packages per hour)
    COUNT(DISTINCT CASE WHEN status_code = 'AT_STATION' THEN tracking_id END) as arrival_rate,
    -- Average dwell time for packages arriving in this hour
    AVG(EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0) as avg_dwell_min
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'DCM3'
    AND DATE(event_datetime_utc) = '2024-12-17'
    AND ship_method LIKE '%RUSH%'
  GROUP BY hour, tracking_id
  GROUP BY hour
)
SELECT
  'ARRIVAL_RATE_SENSITIVITY' as analysis,
  arrival_rate as input_variable,
  ROUND(avg_dwell_min, 1) as output_dwell,
  -- Calculate sensitivity: Δ(output) / Δ(input)
  ROUND((avg_dwell_min - LAG(avg_dwell_min) OVER (ORDER BY arrival_rate))::FLOAT /
        NULLIF(arrival_rate - LAG(arrival_rate) OVER (ORDER BY arrival_rate), 0), 2) as sensitivity_coefficient
FROM arrival_sensitivity
WHERE arrival_rate > 0
ORDER BY arrival_rate;

-- 2. SENSITIVITY TO MISSING DEA
-- How much does missing DEA impact dwell time?
WITH dea_sensitivity AS (
  SELECT
    CASE
      WHEN missing_dea_pct = 0 THEN '0% (No Missing)'
      WHEN missing_dea_pct <= 10 THEN '1-10%'
      WHEN missing_dea_pct <= 20 THEN '11-20%'
      WHEN missing_dea_pct <= 30 THEN '21-30%'
      ELSE '30%+'
    END as dea_miss_bucket,
    AVG(missing_dea_pct) as avg_miss_rate,
    AVG(dwell_minutes) as avg_dwell,
    COUNT(*) as sample_size
  FROM (
    SELECT
      tracking_id,
      SUM(CASE WHEN route_code IS NULL THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100 as missing_dea_pct,
      EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 as dwell_minutes
    FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
    WHERE delivery_station_code = 'DCM3'
      AND DATE(event_datetime_utc) = '2024-12-17'
      AND ship_method LIKE '%RUSH%'
    GROUP BY tracking_id
  ) t
  GROUP BY dea_miss_bucket
)
SELECT
  'DEA_MISS_SENSITIVITY' as analysis,
  dea_miss_bucket,
  ROUND(avg_miss_rate, 1) as input_dea_miss_pct,
  ROUND(avg_dwell, 1) as output_dwell_min,
  sample_size,
  -- Impact multiplier: how much does dwell increase per % of DEA miss
  ROUND(avg_dwell / NULLIF(avg_miss_rate, 0), 2) as impact_multiplier
FROM dea_sensitivity
ORDER BY avg_miss_rate;

-- 3. SENSITIVITY TO TIME OF DAY
-- Which hours are most sensitive to disruption?
WITH hourly_sensitivity AS (
  SELECT
    EXTRACT(HOUR FROM event_datetime_utc) as hour_of_day,
    COUNT(DISTINCT tracking_id) as volume,
    AVG(EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0) as avg_dwell,
    STDDEV(EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0) as dwell_variance
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'DCM3'
    AND DATE(event_datetime_utc) = '2024-12-17'
    AND ship_method LIKE '%RUSH%'
  GROUP BY hour_of_day, tracking_id
  GROUP BY hour_of_day
)
SELECT
  'TIME_SENSITIVITY' as analysis,
  hour_of_day || ':00' as time,
  volume,
  ROUND(avg_dwell, 1) as avg_dwell_min,
  ROUND(dwell_variance, 1) as variance,
  -- Coefficient of Variation: high = sensitive/unstable
  ROUND(dwell_variance / NULLIF(avg_dwell, 0), 2) as coefficient_of_variation,
  CASE
    WHEN dwell_variance / NULLIF(avg_dwell, 0) > 1.5 THEN '🔴 HIGHLY SENSITIVE'
    WHEN dwell_variance / NULLIF(avg_dwell, 0) > 1.0 THEN '🟠 SENSITIVE'
    ELSE '🟢 STABLE'
  END as sensitivity_level
FROM hourly_sensitivity
ORDER BY hour_of_day;

-- 4. MULTIVARIATE SENSITIVITY
-- Which combination of factors has biggest impact?
WITH multivariate AS (
  SELECT
    CASE WHEN route_code IS NULL THEN 1 ELSE 0 END as has_missing_dea,
    CASE WHEN EXTRACT(HOUR FROM event_datetime_utc) BETWEEN 14 AND 18 THEN 1 ELSE 0 END as is_peak_hour,
    CASE WHEN event_count > 10 THEN 1 ELSE 0 END as high_scan_count,
    AVG(dwell_minutes) as avg_dwell
  FROM (
    SELECT
      tracking_id,
      MAX(route_code) as route_code,
      MIN(event_datetime_utc) as event_datetime_utc,
      COUNT(*) as event_count,
      EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/60.0 as dwell_minutes
    FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
    WHERE delivery_station_code = 'DCM3'
      AND DATE(event_datetime_utc) = '2024-12-17'
      AND ship_method LIKE '%RUSH%'
    GROUP BY tracking_id
  ) t
  GROUP BY has_missing_dea, is_peak_hour, high_scan_count
)
SELECT
  'MULTIVARIATE_SENSITIVITY' as analysis,
  CASE has_missing_dea WHEN 1 THEN 'Missing DEA' ELSE 'Has DEA' END as factor_1,
  CASE is_peak_hour WHEN 1 THEN 'Peak Hour' ELSE 'Off-Peak' END as factor_2,
  CASE high_scan_count WHEN 1 THEN 'Many Scans' ELSE 'Few Scans' END as factor_3,
  ROUND(avg_dwell, 1) as avg_dwell_min,
  -- Rank by impact
  RANK() OVER (ORDER BY avg_dwell DESC) as impact_rank
FROM multivariate
ORDER BY avg_dwell DESC;