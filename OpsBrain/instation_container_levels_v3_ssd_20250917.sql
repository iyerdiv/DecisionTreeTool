-- Mercury SSD Container Level Analysis
-- Modified for Same-Day Delivery (includes SAME packages)
-- 5-minute intervals for rapid SSD transitions
-- Date: 2025-09-17

WITH station_data AS (
    SELECT
        station_code,
        DATE_TRUNC('minute', event_timestamp) -
            INTERVAL '1 minute' * (EXTRACT(MINUTE FROM event_timestamp)::INTEGER % 5) AS time_bucket,
        package_id,
        MIN(CASE WHEN event_type = 'INDUCT' THEN event_timestamp END) AS induct_time,
        MIN(CASE WHEN event_type = 'STOW' THEN event_timestamp END) AS stow_time,
        MIN(CASE WHEN event_type IN ('DEPART', 'DELIVER') THEN event_timestamp END) AS depart_time
    FROM mercury_ssd_events
    WHERE station_code = :station
        AND event_timestamp >= :start_date
        AND event_timestamp < :end_date
        -- REMOVED: AND delivery_type NOT LIKE '%SAME%' to INCLUDE same-day
    GROUP BY station_code, time_bucket, package_id
),
container_levels AS (
    SELECT
        station_code,
        time_bucket,
        -- Container 1: Inducted but not yet stowed
        COUNT(DISTINCT CASE
            WHEN induct_time <= time_bucket
            AND (stow_time IS NULL OR stow_time > time_bucket)
            THEN package_id
        END) AS container_1_count,

        -- Container 2: Stowed but not yet departed/delivered
        COUNT(DISTINCT CASE
            WHEN stow_time <= time_bucket
            AND (depart_time IS NULL OR depart_time > time_bucket)
            THEN package_id
        END) AS container_2_count,

        COUNT(DISTINCT package_id) AS total_packages
    FROM station_data
    GROUP BY station_code, time_bucket
)
SELECT
    station_code,
    time_bucket,
    container_1_count AS packages_inducted_not_stowed,
    container_2_count AS packages_stowed_not_departed,
    container_1_count + container_2_count AS total_in_station,
    total_packages,
    ROUND(100.0 * container_1_count / NULLIF(total_packages, 0), 2) AS pct_in_container_1,
    ROUND(100.0 * container_2_count / NULLIF(total_packages, 0), 2) AS pct_in_container_2
FROM container_levels
ORDER BY time_bucket;