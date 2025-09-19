-- Version 3 SSD CORRECTED: Fixed logic for Same-Day Package Analysis
-- Date: 2025-09-17
--
-- FIXES:
-- 1. Removed conflicting SIDE/COMM exclusions that could filter out SSD packages
-- 2. Added explicit filter to ONLY track SAME-DAY packages
-- 3. Simplified exclusions to only remove true problems (damaged, cancelled)
-- 4. Added SSD-specific metrics (velocity, dwell time)

WITH numbers AS (
    -- Generate numbers for time intervals
    SELECT
        (p0.n + p1.n*10 + p2.n*100 + p3.n*1000 + p4.n*10000) as minute_offset
    FROM
        (SELECT 0 as n UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
         UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) p0,
        (SELECT 0 as n UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
         UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) p1,
        (SELECT 0 as n UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
         UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) p2,
        (SELECT 0 as n UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
         UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) p3,
        (SELECT 0 as n UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
         UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) p4
    WHERE (p0.n + p1.n*10 + p2.n*100 + p3.n*1000 + p4.n*10000) % :time_interval_minutes = 0
),

time_buckets AS (
    -- Generate 5-minute time buckets
    SELECT
        DATEADD(minute, minute_offset, DATE_TRUNC('minute', TIMESTAMP :start_timestamp)) as time_bucket
    FROM numbers
    WHERE DATEADD(minute, minute_offset, DATE_TRUNC('minute', TIMESTAMP :start_timestamp))
          <= DATE_TRUNC('minute', TIMESTAMP :end_timestamp)
),

-- SIMPLIFIED EXCLUSIONS: Only exclude true problems, not route types
exclusions AS (
    -- Only exclude packages that are truly problematic
    SELECT DISTINCT tracking_id||delivery_station_code as trid
    FROM hb_na_heisenbergrefinedobjects.d_perfectmile_shipment_status_history
    WHERE delivery_station_code IN (:station_codes)
        AND DATE(event_datetime_utc) >= DATE(TIMESTAMP :start_timestamp) - INTERVAL '1 day'
        AND DATE(event_datetime_utc) <= DATE(TIMESTAMP :end_timestamp) + INTERVAL '1 day'
        AND (
            -- Customer cancelled
            (status_code = 'CANCELLED' AND reason_code = 'CUSTOMER_REQUEST')
            OR
            -- Package damaged and disposed
            (status_code = 'DISPOSED_OFF' AND reason_code = 'DAMAGED')
            OR
            -- Package marked as lost
            (status_code = 'LOST')
            OR
            -- Rescheduled by customer (not same-day anymore)
            (event_code = 'EVENT_442')
        )
),

-- CORRECTED: Focus on SAME-DAY packages only
base_ssd_shipments AS (
    SELECT DISTINCT
        tracking_id,
        delivery_station_code,
        event_datetime_utc,
        status_code,
        event_code_cdes,
        ship_method,
        manifest_route_code,
        cycle_name,
        sort_zone
    FROM hb_na_heisenbergrefinedobjects.d_perfectmile_shipment_status_history
    WHERE delivery_station_code IN (:station_codes)
        AND business like 'AMZ%'
        -- CRITICAL FIX: Only get SAME-DAY packages
        AND (
            ship_method LIKE '%SAME%'
            OR ship_method LIKE '%SSD%'
            OR delivery_speed = 'SAME_DAY'
            OR service_level LIKE '%SAME_DAY%'
        )
        -- Exclude Fresh (different process)
        AND ship_method NOT LIKE '%FRESH%'
        -- Time window for analysis
        AND DATE(event_datetime_utc) >= DATE(TIMESTAMP :start_timestamp)
        AND DATE(event_datetime_utc) <= DATE(TIMESTAMP :end_timestamp)
        -- Exclude only truly problematic packages
        AND tracking_id||delivery_station_code NOT IN (SELECT trid FROM exclusions)
        -- Basic validations
        AND tracking_id IS NOT NULL
        AND delivery_station_code IS NOT NULL
),

-- Track when SSD packages arrive at station
ssd_inducted AS (
    SELECT DISTINCT
        tracking_id,
        delivery_station_code,
        MIN(event_datetime_utc) as inducted_time
    FROM base_ssd_shipments
    WHERE status_code = 'AT_STATION'
    GROUP BY tracking_id, delivery_station_code
),

-- Track when SSD packages are stowed/sorted (if they go through this step)
ssd_stowed AS (
    SELECT DISTINCT
        nvl(ie.tracking_id, ie.container_label) as tracking_id,
        ie.delivery_station_code,
        MIN(ie.event_datetime_utc) as stowed_time
    FROM hb_na_heisenbergrefinedobjects.d_perfectmile_instation_events ie
    INNER JOIN ssd_inducted si
        ON nvl(ie.tracking_id, ie.container_label) = si.tracking_id
        AND ie.delivery_station_code = si.delivery_station_code
    WHERE ie.status IN ('STOWED', 'SORTED')
        AND ie.delivery_station_code IN (:station_codes)
        AND ie.event_datetime_utc >= TIMESTAMP :start_timestamp
        AND ie.event_datetime_utc <= TIMESTAMP :end_timestamp + INTERVAL '1 day'
        AND ie.event_datetime_utc >= si.inducted_time
    GROUP BY nvl(ie.tracking_id, ie.container_label), ie.delivery_station_code
),

-- Track when SSD packages leave (ready for delivery)
ssd_departed AS (
    SELECT DISTINCT
        tracking_id,
        delivery_station_code,
        MIN(event_datetime_utc) as departure_time,
        status_code as departure_type
    FROM base_ssd_shipments
    WHERE status_code IN ('READY_FOR_DEPARTURE', 'OUT_FOR_DELIVERY', 'DELIVERED')
    GROUP BY tracking_id, delivery_station_code, status_code
),

-- Build timeline for each SSD package
ssd_package_timeline AS (
    SELECT
        si.tracking_id,
        si.delivery_station_code,
        si.inducted_time,
        ss.stowed_time,
        sd.departure_time,
        sd.departure_type,
        -- Calculate dwell times (critical for SSD)
        EXTRACT(EPOCH FROM (COALESCE(ss.stowed_time, sd.departure_time) - si.inducted_time)) / 60.0 as induct_to_next_minutes,
        EXTRACT(EPOCH FROM (sd.departure_time - si.inducted_time)) / 60.0 as total_dwell_minutes
    FROM ssd_inducted si
    LEFT JOIN ssd_stowed ss
        ON si.tracking_id = ss.tracking_id
        AND si.delivery_station_code = ss.delivery_station_code
    LEFT JOIN ssd_departed sd
        ON si.tracking_id = sd.tracking_id
        AND si.delivery_station_code = sd.delivery_station_code
),

-- Calculate container populations for each time bucket
container_analysis AS (
    SELECT
        tb.time_bucket,
        -- Container 1: Inducted but not processed (not stowed/sorted and not departed)
        COUNT(DISTINCT CASE
            WHEN pt.inducted_time <= tb.time_bucket
                AND (pt.stowed_time IS NULL OR pt.stowed_time > tb.time_bucket)
                AND (pt.departure_time IS NULL OR pt.departure_time > tb.time_bucket)
            THEN pt.tracking_id
        END) as container_1_packages,

        -- Container 2: Stowed/sorted but not departed (traditional flow)
        COUNT(DISTINCT CASE
            WHEN pt.stowed_time IS NOT NULL
                AND pt.stowed_time <= tb.time_bucket
                AND (pt.departure_time IS NULL OR pt.departure_time > tb.time_bucket)
            THEN pt.tracking_id
        END) as container_2_packages,

        -- Container 3: Packages that went direct (inducted straight to departure, skip stow)
        COUNT(DISTINCT CASE
            WHEN pt.inducted_time <= tb.time_bucket
                AND pt.stowed_time IS NULL  -- Never stowed
                AND pt.departure_time IS NOT NULL
                AND pt.departure_time <= tb.time_bucket + INTERVAL '30 minutes'  -- Left quickly
            THEN pt.tracking_id
        END) as direct_to_van_packages,

        -- SSD-specific metrics
        COUNT(DISTINCT CASE
            WHEN pt.inducted_time <= tb.time_bucket
                AND pt.total_dwell_minutes > 60  -- Dwelling over 1 hour is bad for SSD
                AND (pt.departure_time IS NULL OR pt.departure_time > tb.time_bucket)
            THEN pt.tracking_id
        END) as critical_dwell_packages,

        COUNT(DISTINCT pt.tracking_id) as total_ssd_packages
    FROM time_buckets tb
    CROSS JOIN ssd_package_timeline pt
    WHERE pt.inducted_time <= tb.time_bucket + INTERVAL '1 day'
    GROUP BY tb.time_bucket
),

-- Add velocity metrics for SSD
velocity_metrics AS (
    SELECT
        time_bucket,
        container_1_packages,
        container_2_packages,
        direct_to_van_packages,
        critical_dwell_packages,
        total_ssd_packages,
        container_1_packages + container_2_packages as total_in_process,
        -- Calculate throughput rate (packages moving through per interval)
        LAG(total_ssd_packages, 1) OVER (ORDER BY time_bucket) as prev_total,
        total_ssd_packages - LAG(total_ssd_packages, 1) OVER (ORDER BY time_bucket) as net_flow
    FROM container_analysis
)

-- Final output with SSD-focused metrics
SELECT
    time_bucket,
    container_1_packages as inducted_not_processed,
    container_2_packages as stowed_not_departed,
    direct_to_van_packages as direct_flow_packages,
    critical_dwell_packages as over_60min_dwell,
    total_in_process,
    total_ssd_packages,
    net_flow as packages_per_5min,
    -- Calculate percentages
    ROUND(100.0 * container_1_packages / NULLIF(total_ssd_packages, 0), 2) as pct_in_container_1,
    ROUND(100.0 * container_2_packages / NULLIF(total_ssd_packages, 0), 2) as pct_in_container_2,
    ROUND(100.0 * direct_to_van_packages / NULLIF(total_ssd_packages, 0), 2) as pct_direct_flow,
    ROUND(100.0 * critical_dwell_packages / NULLIF(total_ssd_packages, 0), 2) as pct_critical_dwell
FROM velocity_metrics
ORDER BY time_bucket;