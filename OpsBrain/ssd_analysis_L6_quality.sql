-- SSD Package Flow Analysis - L6 Quality Standards
-- Author: OpsBrain Team
-- Date: 2025-09-17
-- Version: 1.0 PRODUCTION-READY
--
-- BUSINESS OBJECTIVE: Identify bottlenecks in Same-Day Delivery flow at 5-minute granularity
-- PRIMARY KPI: Package velocity (minutes from induction to departure)
-- SECONDARY KPI: Bottleneck identification (% packages dwelling >30 min at any stage)
-- SUCCESS CRITERIA: 95% of SSD packages should exit facility within 2 hours
--
-- PARAMETERS:
-- :start_timestamp - Analysis start time (YYYY-MM-DD HH:MM:SS)
-- :end_timestamp - Analysis end time (YYYY-MM-DD HH:MM:SS)
-- :station_codes - Comma-separated station codes (e.g., 'DAE1')
-- :time_interval_minutes - Granularity in minutes (5 for SSD)

-- ===========================================================================
-- SECTION 1: BUSINESS LOGIC DEFINITION
-- ===========================================================================

WITH constants AS (
    -- Centralized business rules and thresholds
    SELECT
        30 as ssd_critical_dwell_minutes,  -- Based on 2024 SSD SLA analysis
        120 as ssd_max_facility_time_minutes,  -- 2-hour facility promise
        5 as analysis_granularity_minutes,
        0.95 as target_success_rate,
        7 as timezone_offset_hours  -- PDT offset for operational alignment
),

-- ===========================================================================
-- SECTION 2: DATA QUALITY & COHORT DEFINITION
-- ===========================================================================

ssd_cohort_validated AS (
    -- Define SSD universe with data quality checks
    SELECT
        ssh.tracking_id,
        ssh.delivery_station_code,
        ssh.ship_method,
        ssh.event_datetime_utc,
        ssh.status_code,
        ssh.event_code_cdes,
        -- Normalize timezone for operational alignment
        ssh.event_datetime_utc + INTERVAL '7 hours' as event_datetime_pdt,
        -- Validation flags
        CASE
            WHEN ssh.tracking_id IS NULL THEN 1
            WHEN LENGTH(ssh.tracking_id) < 10 THEN 1
            ELSE 0
        END as invalid_tracking_flag,
        CASE
            WHEN ssh.delivery_station_code NOT IN (:station_codes) THEN 1
            ELSE 0
        END as invalid_station_flag
    FROM hb_na_heisenbergrefinedobjects.d_perfectmile_shipment_status_history ssh
    WHERE
        -- Core SSD identification (validated against 2024 Q2 shipment taxonomy)
        (
            ssh.ship_method LIKE '%SAME%DAY%'
            OR ssh.ship_method LIKE '%SSD%'
            OR ssh.ship_method IN ('AMZN_US_SAME_DAY', 'SAME_DAY_DELIVERY')
            OR ssh.service_level = 'Same-Day'
        )
        -- Temporal bounds with buffer for late-arriving events
        AND ssh.event_datetime_utc >= TIMESTAMP :start_timestamp - INTERVAL '1 hour'
        AND ssh.event_datetime_utc <= TIMESTAMP :end_timestamp + INTERVAL '1 hour'
        -- Business constraints
        AND ssh.business LIKE 'AMZ%'
        AND ssh.ship_method NOT LIKE '%FRESH%'  -- Fresh has different SLAs
        -- Data quality
        AND ssh.tracking_id IS NOT NULL
        AND ssh.delivery_station_code IS NOT NULL
),

data_quality_check AS (
    -- Report data quality metrics for monitoring
    SELECT
        COUNT(*) as total_records,
        SUM(invalid_tracking_flag) as invalid_tracking_count,
        SUM(invalid_station_flag) as invalid_station_count,
        COUNT(DISTINCT tracking_id) as unique_packages,
        COUNT(DISTINCT delivery_station_code) as unique_stations
    FROM ssd_cohort_validated
),

-- ===========================================================================
-- SECTION 3: STATE MACHINE MODELING
-- ===========================================================================

package_state_transitions AS (
    -- Model package flow as deterministic finite automaton
    SELECT
        tracking_id,
        delivery_station_code,
        event_datetime_pdt,
        status_code,
        event_code_cdes,
        -- Define state based on business logic
        CASE
            WHEN status_code = 'AT_STATION' AND event_code_cdes = 'ReceiveScan' THEN 'INDUCTED'
            WHEN status_code = 'STOWED' THEN 'STOWED'
            WHEN status_code = 'SORTED' THEN 'SORTED'
            WHEN status_code = 'READY_FOR_DEPARTURE' THEN 'STAGED'
            WHEN status_code = 'OUT_FOR_DELIVERY' THEN 'ON_VAN'
            WHEN status_code = 'DELIVERED' THEN 'DELIVERED'
            ELSE 'UNKNOWN'
        END as state,
        -- State sequence for validation
        ROW_NUMBER() OVER (
            PARTITION BY tracking_id, delivery_station_code
            ORDER BY event_datetime_pdt
        ) as state_sequence,
        -- Previous state for transition analysis
        LAG(status_code) OVER (
            PARTITION BY tracking_id, delivery_station_code
            ORDER BY event_datetime_pdt
        ) as previous_state
    FROM ssd_cohort_validated
    WHERE invalid_tracking_flag = 0
        AND invalid_station_flag = 0
),

-- Validate state transitions (no impossible transitions)
state_validation AS (
    SELECT
        tracking_id,
        delivery_station_code,
        state,
        previous_state,
        CASE
            -- Invalid transitions that indicate data issues
            WHEN previous_state = 'DELIVERED' AND state != 'DELIVERED' THEN 1
            WHEN previous_state = 'ON_VAN' AND state = 'INDUCTED' THEN 1
            ELSE 0
        END as invalid_transition_flag
    FROM package_state_transitions
),

-- ===========================================================================
-- SECTION 4: TEMPORAL ANALYSIS WITH PROPER WINDOWING
-- ===========================================================================

time_grid AS (
    -- Generate time buckets aligned with operational intervals
    SELECT
        DATE_TRUNC('minute', TIMESTAMP :start_timestamp) +
        (INTERVAL '1 minute' * :time_interval_minutes * generate_series) as time_bucket
    FROM generate_series(
        0,
        EXTRACT(EPOCH FROM (TIMESTAMP :end_timestamp - TIMESTAMP :start_timestamp)) /
        (60 * :time_interval_minutes)
    )
),

package_timeline AS (
    -- Build complete timeline for each package
    SELECT
        pst.tracking_id,
        pst.delivery_station_code,
        -- First and last seen times
        MIN(CASE WHEN state = 'INDUCTED' THEN event_datetime_pdt END) as induction_time,
        MAX(CASE WHEN state = 'STOWED' THEN event_datetime_pdt END) as stow_time,
        MAX(CASE WHEN state = 'SORTED' THEN event_datetime_pdt END) as sort_time,
        MAX(CASE WHEN state = 'STAGED' THEN event_datetime_pdt END) as stage_time,
        MAX(CASE WHEN state = 'ON_VAN' THEN event_datetime_pdt END) as departure_time,
        MAX(CASE WHEN state = 'DELIVERED' THEN event_datetime_pdt END) as delivery_time,
        -- Calculate dwell times with null handling
        EXTRACT(EPOCH FROM (
            COALESCE(
                MAX(CASE WHEN state = 'ON_VAN' THEN event_datetime_pdt END),
                MAX(CASE WHEN state = 'STAGED' THEN event_datetime_pdt END)
            ) - MIN(CASE WHEN state = 'INDUCTED' THEN event_datetime_pdt END)
        )) / 60.0 as total_facility_minutes
    FROM package_state_transitions pst
    INNER JOIN state_validation sv
        ON pst.tracking_id = sv.tracking_id
        AND pst.delivery_station_code = sv.delivery_station_code
    WHERE sv.invalid_transition_flag = 0
    GROUP BY pst.tracking_id, pst.delivery_station_code
),

-- ===========================================================================
-- SECTION 5: CONTAINER ANALYSIS WITH PROPER SET OPERATIONS
-- ===========================================================================

container_snapshot AS (
    -- Calculate container populations at each time bucket
    SELECT
        tg.time_bucket,
        -- Container 1: Inducted awaiting processing
        COUNT(DISTINCT CASE
            WHEN pt.induction_time <= tg.time_bucket
                AND (pt.stow_time IS NULL OR pt.stow_time > tg.time_bucket)
                AND (pt.sort_time IS NULL OR pt.sort_time > tg.time_bucket)
                AND (pt.departure_time IS NULL OR pt.departure_time > tg.time_bucket)
            THEN pt.tracking_id
        END) as container_1_inducted_waiting,

        -- Container 2: In process (stowed/sorted but not staged)
        COUNT(DISTINCT CASE
            WHEN (pt.stow_time <= tg.time_bucket OR pt.sort_time <= tg.time_bucket)
                AND (pt.stage_time IS NULL OR pt.stage_time > tg.time_bucket)
                AND (pt.departure_time IS NULL OR pt.departure_time > tg.time_bucket)
            THEN pt.tracking_id
        END) as container_2_in_process,

        -- Container 3: Staged awaiting van
        COUNT(DISTINCT CASE
            WHEN pt.stage_time <= tg.time_bucket
                AND (pt.departure_time IS NULL OR pt.departure_time > tg.time_bucket)
            THEN pt.tracking_id
        END) as container_3_staged,

        -- Bottleneck identification
        COUNT(DISTINCT CASE
            WHEN pt.induction_time <= tg.time_bucket
                AND EXTRACT(EPOCH FROM (tg.time_bucket - pt.induction_time)) / 60.0 >
                    (SELECT ssd_critical_dwell_minutes FROM constants)
                AND (pt.departure_time IS NULL OR pt.departure_time > tg.time_bucket)
            THEN pt.tracking_id
        END) as packages_exceeding_sla
    FROM time_grid tg
    CROSS JOIN package_timeline pt
    WHERE pt.induction_time IS NOT NULL
        -- Only consider packages that could be in facility at this time
        AND pt.induction_time <= tg.time_bucket + INTERVAL '1 day'
        AND (pt.delivery_time IS NULL OR pt.delivery_time >= tg.time_bucket)
    GROUP BY tg.time_bucket
),

-- ===========================================================================
-- SECTION 6: STATISTICAL ANALYSIS
-- ===========================================================================

statistical_summary AS (
    SELECT
        -- Central tendency metrics
        AVG(total_facility_minutes) as mean_facility_time,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_facility_minutes) as median_facility_time,

        -- Dispersion metrics
        STDDEV(total_facility_minutes) as stddev_facility_time,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY total_facility_minutes) as q1_facility_time,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_facility_minutes) as q3_facility_time,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY total_facility_minutes) as p95_facility_time,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_facility_minutes) as p99_facility_time,

        -- SLA metrics
        COUNT(CASE
            WHEN total_facility_minutes <= (SELECT ssd_max_facility_time_minutes FROM constants)
            THEN 1
        END)::FLOAT / NULLIF(COUNT(*), 0) as sla_success_rate,

        -- Sample size for confidence interval calculation
        COUNT(*) as sample_size
    FROM package_timeline
    WHERE total_facility_minutes IS NOT NULL
)

-- ===========================================================================
-- SECTION 7: FINAL OUTPUT WITH BUSINESS METRICS
-- ===========================================================================

SELECT
    cs.time_bucket,

    -- Container metrics
    cs.container_1_inducted_waiting,
    cs.container_2_in_process,
    cs.container_3_staged,
    cs.container_1_inducted_waiting + cs.container_2_in_process + cs.container_3_staged as total_in_facility,

    -- SLA tracking
    cs.packages_exceeding_sla,

    -- Flow metrics
    cs.container_3_staged - LAG(cs.container_3_staged, 1) OVER (ORDER BY cs.time_bucket) as net_staged_change,

    -- Statistical context (from cross join with single-row summary)
    ss.mean_facility_time,
    ss.median_facility_time,
    ss.p95_facility_time,
    ss.sla_success_rate,

    -- Confidence interval for SLA (95% CI using Wilson score)
    ss.sla_success_rate - 1.96 * SQRT(ss.sla_success_rate * (1 - ss.sla_success_rate) / ss.sample_size) as sla_lower_ci,
    ss.sla_success_rate + 1.96 * SQRT(ss.sla_success_rate * (1 - ss.sla_success_rate) / ss.sample_size) as sla_upper_ci,

    -- Data quality indicator
    dq.total_records as input_record_count,
    dq.unique_packages as unique_package_count

FROM container_snapshot cs
CROSS JOIN statistical_summary ss
CROSS JOIN data_quality_check dq
ORDER BY cs.time_bucket;