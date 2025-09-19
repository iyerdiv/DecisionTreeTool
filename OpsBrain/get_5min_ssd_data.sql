-- 5-Minute Interval SSD Analysis for Container Model
-- Station: DLA8 (Los Angeles high-volume)
-- Focus: RUSH packages with precise dwell measurement

WITH time_intervals AS (
    -- Generate 5-minute intervals for Sept 15, 2025
    SELECT generate_series(
        '2025-09-15 00:00:00'::timestamp,
        '2025-09-15 23:55:00'::timestamp,
        '5 minutes'::interval
    ) AS interval_start
),

rush_packages AS (
    -- Get all RUSH packages at DLA8 for the day
    SELECT
        tracking_id,
        event_datetime_utc,
        status_code,
        event_code,
        ship_method,
        route_code
    FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
    WHERE delivery_station_code = 'DLA8'
        AND DATE(event_datetime_utc) = '2025-09-15'
        AND (ship_method LIKE '%RUSH%' OR ship_method LIKE '%SDD%')
),

inducted_packages AS (
    -- Container 1 entry: Package inducted (AT_STATION)
    SELECT
        tracking_id,
        MIN(event_datetime_utc) as induction_time
    FROM rush_packages
    WHERE status_code = 'AT_STATION'
    GROUP BY tracking_id
),

stowed_packages AS (
    -- Container 1 exit/Container 2 entry: Package stowed
    SELECT
        rp.tracking_id,
        MIN(rp.event_datetime_utc) as stow_time
    FROM rush_packages rp
    INNER JOIN inducted_packages ip ON rp.tracking_id = ip.tracking_id
    WHERE rp.status_code = 'STOWED'
        AND rp.event_datetime_utc > ip.induction_time
    GROUP BY rp.tracking_id
),

departed_packages AS (
    -- Container 2 exit: Package ready for departure or delivered
    SELECT
        rp.tracking_id,
        MIN(rp.event_datetime_utc) as departure_time
    FROM rush_packages rp
    INNER JOIN inducted_packages ip ON rp.tracking_id = ip.tracking_id
    WHERE rp.status_code IN ('READY_FOR_DEPARTURE', 'OUT_FOR_DELIVERY', 'DELIVERED')
        AND rp.event_datetime_utc > ip.induction_time
    GROUP BY rp.tracking_id
),

package_timeline AS (
    -- Combine all events for each package
    SELECT
        ip.tracking_id,
        ip.induction_time,
        sp.stow_time,
        dp.departure_time,
        -- Calculate dwell times in minutes
        EXTRACT(EPOCH FROM (COALESCE(sp.stow_time, dp.departure_time) - ip.induction_time))/60 as container1_dwell_minutes,
        CASE
            WHEN sp.stow_time IS NOT NULL AND dp.departure_time IS NOT NULL
            THEN EXTRACT(EPOCH FROM (dp.departure_time - sp.stow_time))/60
        END as container2_dwell_minutes,
        EXTRACT(EPOCH FROM (COALESCE(dp.departure_time, NOW()) - ip.induction_time))/60 as total_dwell_minutes
    FROM inducted_packages ip
    LEFT JOIN stowed_packages sp ON ip.tracking_id = sp.tracking_id
    LEFT JOIN departed_packages dp ON ip.tracking_id = dp.tracking_id
),

interval_populations AS (
    -- Calculate container populations for each 5-minute interval
    SELECT
        ti.interval_start,
        -- Container 1: Inducted but not yet stowed
        COUNT(CASE
            WHEN pt.induction_time <= ti.interval_start
                AND (pt.stow_time IS NULL OR pt.stow_time > ti.interval_start)
                AND (pt.departure_time IS NULL OR pt.departure_time > ti.interval_start)
            THEN 1
        END) as container1_count,
        -- Container 2: Stowed but not yet departed
        COUNT(CASE
            WHEN pt.stow_time IS NOT NULL
                AND pt.stow_time <= ti.interval_start
                AND (pt.departure_time IS NULL OR pt.departure_time > ti.interval_start)
            THEN 1
        END) as container2_count,
        -- Total in station
        COUNT(CASE
            WHEN pt.induction_time <= ti.interval_start
                AND (pt.departure_time IS NULL OR pt.departure_time > ti.interval_start)
            THEN 1
        END) as total_in_station
    FROM time_intervals ti
    CROSS JOIN package_timeline pt
    GROUP BY ti.interval_start
)

-- Final output with analysis
SELECT
    interval_start,
    TO_CHAR(interval_start, 'HH24:MI') as time_label,
    container1_count,
    container2_count,
    total_in_station,
    -- Identify bottlenecks
    CASE
        WHEN container1_count > 100 THEN 'HIGH_INDUCTION_BOTTLENECK'
        WHEN container2_count > 100 THEN 'HIGH_STAGING_BOTTLENECK'
        WHEN total_in_station > 200 THEN 'STATION_OVERLOAD'
        ELSE 'NORMAL'
    END as status,
    -- Calculate hourly equivalent for comparison
    container1_count * 12 as container1_hourly_equivalent,
    container2_count * 12 as container2_hourly_equivalent
FROM interval_populations
ORDER BY interval_start;

-- Summary statistics
WITH summary AS (
    SELECT
        AVG(container1_dwell_minutes) as avg_container1_dwell,
        AVG(container2_dwell_minutes) as avg_container2_dwell,
        AVG(total_dwell_minutes) as avg_total_dwell,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_dwell_minutes) as median_total_dwell,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY total_dwell_minutes) as p95_total_dwell,
        COUNT(*) as total_packages,
        COUNT(CASE WHEN total_dwell_minutes <= 30 THEN 1 END) as packages_meeting_sla,
        COUNT(CASE WHEN total_dwell_minutes > 30 THEN 1 END) as packages_missing_sla
    FROM package_timeline
)
SELECT
    'SUMMARY METRICS' as metric_type,
    ROUND(avg_container1_dwell, 1) || ' min' as avg_container1_dwell,
    ROUND(avg_container2_dwell, 1) || ' min' as avg_container2_dwell,
    ROUND(avg_total_dwell, 1) || ' min' as avg_total_dwell,
    ROUND(median_total_dwell, 1) || ' min' as median_dwell,
    ROUND(p95_total_dwell, 1) || ' min' as p95_dwell,
    total_packages,
    packages_meeting_sla,
    packages_missing_sla,
    ROUND(100.0 * packages_meeting_sla / NULLIF(total_packages, 0), 1) || '%' as sla_compliance_rate
FROM summary;