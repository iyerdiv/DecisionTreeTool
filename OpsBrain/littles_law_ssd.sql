-- Little's Law Analysis for SSD Bottleneck Detection
-- L = λ × W (Inventory = Arrival Rate × Wait Time)

WITH hourly_metrics AS (
  SELECT
    DATE_TRUNC('hour', event_datetime_utc) as hour,
    delivery_station_code,

    -- λ (Lambda): Arrival rate - packages entering per hour
    COUNT(CASE WHEN status_code = 'AT_STATION' THEN 1 END) as arrivals_per_hour,

    -- L (Inventory): Average packages in system
    COUNT(DISTINCT CASE
      WHEN status_code IN ('AT_STATION', 'STOWED')
      AND status_code NOT IN ('DELIVERED', 'READY_FOR_DEPARTURE')
      THEN tracking_id
    END) as avg_inventory,

    -- Throughput: Packages exiting per hour
    COUNT(CASE WHEN status_code IN ('DELIVERED', 'READY_FOR_DEPARTURE') THEN 1 END) as exits_per_hour

  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code IN ('VNY5', 'DBL8')
    AND DATE(event_datetime_utc) = '2024-09-03'
    AND ship_method LIKE '%RUSH%'
  GROUP BY DATE_TRUNC('hour', event_datetime_utc), delivery_station_code
),

littles_law_calc AS (
  SELECT
    hour,
    delivery_station_code,
    arrivals_per_hour as lambda,
    avg_inventory as L,
    exits_per_hour,

    -- W = L / λ (Wait time from Little's Law)
    CASE
      WHEN arrivals_per_hour > 0
      THEN ROUND(avg_inventory::numeric / arrivals_per_hour * 60, 1)
      ELSE 0
    END as wait_time_minutes,

    -- Utilization = Exits / Arrivals (efficiency metric)
    CASE
      WHEN arrivals_per_hour > 0
      THEN ROUND(100.0 * exits_per_hour / arrivals_per_hour, 1)
      ELSE 0
    END as utilization_pct,

    -- Bottleneck indicator
    CASE
      WHEN avg_inventory > arrivals_per_hour * 2 THEN 'SEVERE_BOTTLENECK'
      WHEN avg_inventory > arrivals_per_hour THEN 'MODERATE_BOTTLENECK'
      WHEN exits_per_hour < arrivals_per_hour * 0.8 THEN 'FLOW_RESTRICTION'
      ELSE 'NORMAL'
    END as bottleneck_status

  FROM hourly_metrics
)

SELECT
  TO_CHAR(hour, 'HH24:00') as time,
  delivery_station_code as location,
  lambda as arrival_rate,
  L as inventory,
  wait_time_minutes,
  utilization_pct,
  bottleneck_status,
  -- Visual indicator
  REPEAT('█', LEAST(wait_time_minutes::int/10, 20)) as wait_time_bar
FROM littles_law_calc
WHERE lambda > 0
ORDER BY hour, delivery_station_code;

-- Summary Statistics
WITH summary AS (
  SELECT
    delivery_station_code,
    AVG(wait_time_minutes) as avg_wait,
    MAX(wait_time_minutes) as max_wait,
    AVG(utilization_pct) as avg_utilization,
    COUNT(CASE WHEN bottleneck_status != 'NORMAL' THEN 1 END) as bottleneck_hours
  FROM littles_law_calc
  GROUP BY delivery_station_code
)
SELECT
  delivery_station_code,
  ROUND(avg_wait, 1) || ' min' as avg_wait_time,
  ROUND(max_wait, 1) || ' min' as peak_wait_time,
  ROUND(avg_utilization, 1) || '%' as avg_utilization,
  bottleneck_hours || ' hours' as hours_bottlenecked,
  CASE
    WHEN avg_wait > 30 THEN '❌ FAILS SSD SLA'
    ELSE '✅ MEETS SSD SLA'
  END as sla_status
FROM summary;