-- Real 30 Station Sensitivity Analysis using Queue Data
-- Uses actual queue levels from real_30_station_queue_data.csv
-- Tests sensitivity to arrival rates and throughput variations

WITH station_queue_metrics AS (
    -- Calculate queue-based Little's Law metrics for each station
    SELECT
        delivery_station_code,
        DATE(timestamp) as analysis_date,
        EXTRACT(HOUR FROM timestamp) as hour_of_day,

        -- Queue Levels (L - Inventory)
        loading_queue,
        sorting_queue,
        dispatch_queue,
        (loading_queue + sorting_queue + dispatch_queue) as total_queue_depth,

        -- Arrival and Throughput Rates (λ)
        arrivals,
        loading_throughput,
        sorting_throughput,
        dispatch_throughput,

        -- Calculate effective arrival rate at each stage
        CASE
            WHEN loading_throughput > 0 THEN arrivals
            ELSE 0
        END as loading_arrival_rate,

        CASE
            WHEN sorting_throughput > 0 THEN loading_throughput
            ELSE 0
        END as sorting_arrival_rate,

        CASE
            WHEN dispatch_throughput > 0 THEN sorting_throughput
            ELSE 0
        END as dispatch_arrival_rate,

        -- Anomaly flags
        anomaly_detected,
        root_cause_classification

    FROM real_30_station_queue_data
),

littles_law_calculation AS (
    -- Apply Little's Law: W = L/λ (Wait Time = Queue Length / Arrival Rate)
    SELECT
        *,

        -- Calculate wait times at each stage using Little's Law
        CASE
            WHEN arrivals > 0 THEN loading_queue / arrivals
            ELSE NULL
        END as loading_wait_time,

        CASE
            WHEN loading_throughput > 0 THEN sorting_queue / loading_throughput
            ELSE NULL
        END as sorting_wait_time,

        CASE
            WHEN sorting_throughput > 0 THEN dispatch_queue / sorting_throughput
            ELSE NULL
        END as dispatch_wait_time,

        -- Calculate total system wait time
        CASE
            WHEN arrivals > 0 THEN total_queue_depth / arrivals
            ELSE NULL
        END as total_system_wait_time,

        -- Calculate utilization rates (ρ = λ/μ)
        CASE
            WHEN loading_throughput > 0 AND arrivals > 0
            THEN arrivals / loading_throughput
            ELSE NULL
        END as loading_utilization,

        CASE
            WHEN sorting_throughput > 0 AND loading_throughput > 0
            THEN loading_throughput / sorting_throughput
            ELSE NULL
        END as sorting_utilization,

        CASE
            WHEN dispatch_throughput > 0 AND sorting_throughput > 0
            THEN sorting_throughput / dispatch_throughput
            ELSE NULL
        END as dispatch_utilization

    FROM station_queue_metrics
),

sensitivity_windows AS (
    -- Calculate sensitivity over sliding windows
    SELECT
        delivery_station_code,
        analysis_date,
        hour_of_day,
        arrivals,
        total_queue_depth,
        total_system_wait_time,

        -- Calculate moving averages for stability analysis
        AVG(arrivals) OVER (
            PARTITION BY delivery_station_code
            ORDER BY timestamp
            ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
        ) as avg_arrival_rate_4hr,

        AVG(total_queue_depth) OVER (
            PARTITION BY delivery_station_code
            ORDER BY timestamp
            ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
        ) as avg_queue_depth_4hr,

        -- Calculate rate of change
        arrivals - LAG(arrivals, 1) OVER (
            PARTITION BY delivery_station_code
            ORDER BY timestamp
        ) as arrival_rate_change,

        total_queue_depth - LAG(total_queue_depth, 1) OVER (
            PARTITION BY delivery_station_code
            ORDER BY timestamp
        ) as queue_depth_change,

        -- Identify peak hours (14:00-18:00)
        CASE
            WHEN hour_of_day BETWEEN 14 AND 18 THEN 1
            ELSE 0
        END as is_peak_hour,

        anomaly_detected,
        root_cause_classification

    FROM littles_law_calculation
),

sensitivity_coefficients AS (
    -- Calculate sensitivity coefficient: Δ(Queue) / Δ(Arrivals)
    SELECT
        delivery_station_code,
        analysis_date,

        -- Basic statistics
        COUNT(*) as observations,
        SUM(CASE WHEN anomaly_detected THEN 1 ELSE 0 END) as anomaly_count,

        -- Average metrics
        AVG(arrivals) as avg_arrival_rate,
        AVG(total_queue_depth) as avg_queue_depth,
        AVG(total_system_wait_time) as avg_wait_time,

        -- Variability metrics
        STDDEV(arrivals) as arrival_rate_std,
        STDDEV(total_queue_depth) as queue_depth_std,

        -- Coefficient of Variation (CV = σ/μ)
        CASE
            WHEN AVG(arrivals) > 0
            THEN STDDEV(arrivals) / AVG(arrivals)
            ELSE NULL
        END as arrival_cv,

        CASE
            WHEN AVG(total_queue_depth) > 0
            THEN STDDEV(total_queue_depth) / AVG(total_queue_depth)
            ELSE NULL
        END as queue_cv,

        -- Sensitivity coefficient (using correlation-based approach)
        CASE
            WHEN STDDEV(arrivals) > 0
            THEN COVAR_POP(queue_depth_change, arrival_rate_change) / VAR_POP(arrival_rate_change)
            ELSE NULL
        END as sensitivity_coefficient,

        -- Peak hour sensitivity
        AVG(CASE WHEN is_peak_hour = 1 THEN total_queue_depth ELSE NULL END) as peak_avg_queue,
        AVG(CASE WHEN is_peak_hour = 0 THEN total_queue_depth ELSE NULL END) as offpeak_avg_queue,

        -- Peak hour sensitivity ratio
        CASE
            WHEN AVG(CASE WHEN is_peak_hour = 0 THEN total_queue_depth ELSE NULL END) > 0
            THEN AVG(CASE WHEN is_peak_hour = 1 THEN total_queue_depth ELSE NULL END) /
                 AVG(CASE WHEN is_peak_hour = 0 THEN total_queue_depth ELSE NULL END)
            ELSE NULL
        END as peak_sensitivity_ratio

    FROM sensitivity_windows
    WHERE arrival_rate_change IS NOT NULL
      AND queue_depth_change IS NOT NULL
    GROUP BY delivery_station_code, analysis_date
),

station_stability_ranking AS (
    -- Rank stations by stability and sensitivity
    SELECT
        delivery_station_code,

        -- Aggregate metrics across all dates
        AVG(avg_arrival_rate) as overall_avg_arrivals,
        AVG(avg_queue_depth) as overall_avg_queue,
        AVG(avg_wait_time) as overall_avg_wait,

        -- Stability metrics
        AVG(arrival_cv) as avg_arrival_cv,
        AVG(queue_cv) as avg_queue_cv,
        AVG(sensitivity_coefficient) as avg_sensitivity,

        -- Anomaly frequency
        SUM(anomaly_count) as total_anomalies,
        AVG(anomaly_count * 1.0 / observations) as anomaly_rate,

        -- Peak sensitivity
        AVG(peak_sensitivity_ratio) as avg_peak_sensitivity,

        -- Calculate stability score (lower is more stable)
        (AVG(queue_cv) * 0.3 +
         AVG(COALESCE(ABS(sensitivity_coefficient), 0)) * 0.3 +
         AVG(anomaly_count * 1.0 / observations) * 0.2 +
         AVG(COALESCE(peak_sensitivity_ratio, 1)) * 0.2) as stability_score,

        -- Classify stability
        CASE
            WHEN AVG(queue_cv) < 0.5 AND AVG(COALESCE(ABS(sensitivity_coefficient), 0)) < 10 THEN 'STABLE'
            WHEN AVG(queue_cv) > 1.0 OR AVG(COALESCE(ABS(sensitivity_coefficient), 0)) > 50 THEN 'CRITICAL'
            ELSE 'MODERATE'
        END as stability_classification

    FROM sensitivity_coefficients
    GROUP BY delivery_station_code
),

bottleneck_analysis AS (
    -- Identify specific bottleneck patterns
    SELECT
        l.delivery_station_code,
        l.analysis_date,
        l.hour_of_day,

        -- Identify bottleneck stage
        CASE
            WHEN l.loading_wait_time > COALESCE(l.sorting_wait_time, 0)
                 AND l.loading_wait_time > COALESCE(l.dispatch_wait_time, 0) THEN 'LOADING'
            WHEN l.sorting_wait_time > COALESCE(l.loading_wait_time, 0)
                 AND l.sorting_wait_time > COALESCE(l.dispatch_wait_time, 0) THEN 'SORTING'
            WHEN l.dispatch_wait_time > COALESCE(l.loading_wait_time, 0)
                 AND l.dispatch_wait_time > COALESCE(l.sorting_wait_time, 0) THEN 'DISPATCH'
            ELSE 'BALANCED'
        END as bottleneck_stage,

        -- Calculate bottleneck severity
        GREATEST(
            COALESCE(l.loading_wait_time, 0),
            COALESCE(l.sorting_wait_time, 0),
            COALESCE(l.dispatch_wait_time, 0)
        ) as max_stage_wait,

        -- Check if Little's Law is breaking down (utilization > 0.9)
        CASE
            WHEN l.loading_utilization > 0.9 OR
                 l.sorting_utilization > 0.9 OR
                 l.dispatch_utilization > 0.9
            THEN 1
            ELSE 0
        END as system_overload

    FROM littles_law_calculation l
)

-- Final output with comprehensive sensitivity analysis
SELECT
    r.delivery_station_code,
    r.stability_classification,
    ROUND(r.stability_score, 3) as stability_score,

    -- Operational metrics
    ROUND(r.overall_avg_arrivals, 1) as avg_hourly_arrivals,
    ROUND(r.overall_avg_queue, 1) as avg_queue_depth,
    ROUND(r.overall_avg_wait, 2) as avg_wait_hours,

    -- Sensitivity metrics
    ROUND(r.avg_sensitivity, 2) as sensitivity_coefficient,
    ROUND(r.avg_arrival_cv, 3) as arrival_variability,
    ROUND(r.avg_queue_cv, 3) as queue_variability,

    -- Peak hour impact
    ROUND(r.avg_peak_sensitivity, 2) as peak_hour_multiplier,

    -- Anomaly metrics
    r.total_anomalies,
    ROUND(r.anomaly_rate * 100, 1) as anomaly_percentage,

    -- Bottleneck analysis
    b.primary_bottleneck,
    b.bottleneck_frequency,
    b.avg_max_wait,

    -- Recommendations
    CASE
        WHEN r.stability_classification = 'CRITICAL' THEN
            'URGENT: Station showing high sensitivity. Implement flow control and capacity review.'
        WHEN r.stability_classification = 'MODERATE' AND r.avg_peak_sensitivity > 2 THEN
            'ATTENTION: High peak sensitivity. Consider peak hour staffing adjustments.'
        WHEN r.total_anomalies > 10 THEN
            'MONITOR: Frequent anomalies detected. Review operational procedures.'
        ELSE
            'STABLE: Continue monitoring with standard thresholds.'
    END as recommendation,

    -- Alert thresholds (based on sensitivity)
    ROUND(r.overall_avg_queue + (2 * r.avg_queue_cv * r.overall_avg_queue), 0) as yellow_alert_threshold,
    ROUND(r.overall_avg_queue + (3 * r.avg_queue_cv * r.overall_avg_queue), 0) as red_alert_threshold

FROM station_stability_ranking r
LEFT JOIN (
    -- Aggregate bottleneck patterns
    SELECT
        delivery_station_code,
        MODE() WITHIN GROUP (ORDER BY bottleneck_stage) as primary_bottleneck,
        COUNT(CASE WHEN bottleneck_stage != 'BALANCED' THEN 1 END) * 100.0 / COUNT(*) as bottleneck_frequency,
        AVG(max_stage_wait) as avg_max_wait
    FROM bottleneck_analysis
    GROUP BY delivery_station_code
) b ON r.delivery_station_code = b.delivery_station_code

ORDER BY r.stability_score DESC, r.total_anomalies DESC

-- ANALYSIS SUMMARY:
-- 1. Stability Score: Composite metric (0-1 scale, lower = more stable)
-- 2. Sensitivity Coefficient: How much queue grows per unit arrival increase
-- 3. Peak Hour Multiplier: How much worse peak hours are vs off-peak
-- 4. Alert Thresholds: Dynamic based on each station's variability
-- 5. Recommendations: Action items based on stability classification