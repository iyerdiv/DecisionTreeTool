-- Version 3 SSD (2025-09-17): Instation Container Levels INCLUDING Same-Day Packages
-- TEST RUN: 2 days only to verify logic works
-- Usage: ./export_data.sh instation_container_levels_v3_ssd_20250917.sql "2025-07-18 00:00:00" "2025-07-19 23:59:59" "DAE1" "5" container_levels_ssd_5min_test_20250917.csv
--
-- Modified to INCLUDE same-day packages for SSD analysis
-- Container 1: Packages that are inducted but not yet stowed
-- Container 2: Packages that are stowed but not yet delivered
--
-- Changes from v3:
-- - Includes SAME-DAY packages (removed %SAME% exclusion)
-- - Focused on recent date range for analysis

WITH numbers AS (
    -- Generate numbers 0-9999 for up to 10000 intervals
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
    -- Generate time buckets based on user-provided time period
    SELECT
        DATEADD(minute, minute_offset, DATE_TRUNC('minute', TIMESTAMP :start_timestamp)) as time_bucket
    FROM numbers
    WHERE DATEADD(minute, minute_offset, DATE_TRUNC('minute', TIMESTAMP :start_timestamp))
          <= DATE_TRUNC('minute', TIMESTAMP :end_timestamp)
),

-- Exclusions subquery from official logic
exclusions AS (
    -- Side/Commercial packages that got problem solved
    with inducted as (
        select tracking_id||delivery_station_code as trid, max(event_datetime_utc) edt
        from hb_na_heisenbergrefinedobjects.d_perfectmile_shipment_status_history ssh
        where ssh.business like 'AMZ%'
        AND ssh.status_code = 'AT_STATION'
        -- MODIFIED: Including SAME-DAY packages for SSD analysis
        AND ssh.ship_method not like '%FRESH%' and ssh.ship_method not like '%BULK%'
        AND nvl(ssh.induct_location_type, '') not in ('Crash Sort')
        AND nvl(ssh.shipment_type, '') not in ('MFNPickup', 'ReturnPickup')
        AND (ssh.manifest_route_code like '%SIDE%' OR ssh.manifest_route_code like '%COMM%')
        and ssh.delivery_station_code IN (:station_codes)
        and DATE(event_datetime_utc + INTERVAL '7 hours') >= DATE(TIMESTAMP :start_timestamp + INTERVAL '7 hours') - INTERVAL '1 day'
        and DATE(event_datetime_utc + INTERVAL '7 hours') <= DATE(TIMESTAMP :end_timestamp + INTERVAL '7 hours') + INTERVAL '1 day'
        group by 1
    )
    select trid
    from hb_na_heisenbergrefinedobjects.d_perfectmile_instation_events a
    inner join inducted b
        on b.trid = a.tracking_id||a.delivery_station_code
        and a.event_datetime_utc > b.edt
        and movement_dest_container_label like 'PS-%'
        and event_type = 'CONTAINER_MOVEMENT'
        and a.delivery_station_code IN (:station_codes)
        and DATE(event_datetime_utc + INTERVAL '7 hours') >= DATE(TIMESTAMP :start_timestamp + INTERVAL '7 hours') - INTERVAL '1 day'
        and DATE(event_datetime_utc + INTERVAL '7 hours') <= DATE(TIMESTAMP :end_timestamp + INTERVAL '7 hours') + INTERVAL '1 day'
    union
    -- Problem scan events
    select tracking_id||delivery_station_code
    from hb_na_heisenbergrefinedobjects.d_perfectmile_instation_events
    where event_type in ('EVENT_438', 'EVENT_407')
    and delivery_station_code IN (:station_codes)
    and DATE(event_datetime_utc + INTERVAL '7 hours') >= DATE(TIMESTAMP :start_timestamp + INTERVAL '7 hours') - INTERVAL '1 day'
    and DATE(event_datetime_utc + INTERVAL '7 hours') <= DATE(TIMESTAMP :end_timestamp + INTERVAL '7 hours') + INTERVAL '1 day'
    union
    -- Customer request events
    select tracking_id||delivery_station_code
    from hb_na_heisenbergrefinedobjects.d_perfectmile_shipment_status_history
    where (event_code in ('EVENT_442') or (event_code = 'EVENT_407' AND reason_code = 'CUSTOMER_REQUEST'))
    and delivery_station_code IN (:station_codes)
    and DATE(event_datetime_utc + INTERVAL '7 hours') >= DATE(TIMESTAMP :start_timestamp + INTERVAL '7 hours') - INTERVAL '1 day'
    and DATE(event_datetime_utc + INTERVAL '7 hours') <= DATE(TIMESTAMP :end_timestamp + INTERVAL '7 hours') + INTERVAL '1 day'
    union
    -- Package shadow universe exclusions
    select tracking_id||delivery_station_code
    from hb_na_heisenbergrefinedobjects.package_system_shadow_universe
    where pss_substatus in ('CUSTOMER_CANCELLATION', 'RESCHEDULED_BY_CUSTOMER', 'FDD', 'HELD', 'COMMERCIAL')
    and (pss_status not like 'DELIVER%' or pss_status not like 'DROP%' or pss_status IN ('STOWED', 'STAGED'))
    and delivery_station_code IN (:station_codes)
    and DATE(event_datetime_utc + INTERVAL '7 hours') >= DATE(TIMESTAMP :start_timestamp + INTERVAL '7 hours') - INTERVAL '1 day'
    and DATE(event_datetime_utc + INTERVAL '7 hours') <= DATE(TIMESTAMP :end_timestamp + INTERVAL '7 hours') + INTERVAL '1 day'

),

-- Base shipment data with all official filters
base_shipments AS (
    SELECT DISTINCT
        tracking_id,
        delivery_station_code,
        event_datetime_utc,
        status_code,
        event_code_cdes,
        ship_method,
        cycle_name,
        sort_zone,
        induct_location_type,
        shipment_type,
        manifest_route_code,
        reason_code
    FROM hb_na_heisenbergrefinedobjects.d_perfectmile_shipment_status_history
    WHERE delivery_station_code IN (:station_codes)
        AND business like 'AMZ%'
        AND DATE(event_datetime_utc + INTERVAL '7 hours') >= DATE(TIMESTAMP :start_timestamp + INTERVAL '7 hours') - INTERVAL '7 days'
        AND DATE(event_datetime_utc + INTERVAL '7 hours') <= DATE(TIMESTAMP :end_timestamp + INTERVAL '7 hours') + INTERVAL '1 day'
        -- MODIFIED: Including SAME-DAY packages for SSD analysis
        AND ship_method not like '%FRESH%' and ship_method not like '%BULK%'
        AND nvl(induct_location_type, '') not in ('Crash Sort')
        AND nvl(shipment_type, '') not in ('MFNPickup', 'ReturnPickup')
        AND manifest_route_code not like '%SIDE%' and manifest_route_code not like '%COMM%'
        AND delivery_station_code NOT IN ('OML1','OML2','OSG2','OSI2','OSI3','ORE2','EQB1')
        AND sort_zone <> delivery_station_code
        AND nvl(tracking_id || delivery_station_code, '') not in (select trid from exclusions)
        -- Exclude damaged packages
        AND tracking_id NOT IN (
            SELECT DISTINCT tracking_id
            FROM hb_na_heisenbergrefinedobjects.d_perfectmile_shipment_status_history
            WHERE delivery_station_code IN (:station_codes)
                and DATE(event_datetime_utc + INTERVAL '7 hours') >= DATE(TIMESTAMP :start_timestamp + INTERVAL '7 hours') - INTERVAL '1 day'
                and DATE(event_datetime_utc + INTERVAL '7 hours') <= DATE(TIMESTAMP :end_timestamp + INTERVAL '7 hours') + INTERVAL '1 day'
                AND reason_code = 'DAMAGED'
                AND status_code = 'DISPOSED_OFF'
        )
        -- Exclude packages without proper routing
        AND tracking_id not in (
            select distinct u.tracking_id
            FROM hb_na_heisenbergrefinedobjects.d_perfectmile_shipment_status_history u
            where u.delivery_station_code IN (:station_codes)
            and DATE(event_datetime_utc + INTERVAL '7 hours') >= DATE(TIMESTAMP :start_timestamp + INTERVAL '7 hours') - INTERVAL '1 day'
            and DATE(event_datetime_utc + INTERVAL '7 hours') <= DATE(TIMESTAMP :end_timestamp + INTERVAL '7 hours') + INTERVAL '1 day'
            and cycle_name not in ('CYCLE_1', 'CYCLE_2')
            and status_code = 'AT_STATION'
            and route_code is null
        )
        -- Exclude sort zone conflicts
        AND sort_zone not in (
            select distinct delivery_station_code
            FROM hb_na_heisenbergrefinedobjects.d_perfectmile_shipment_status_history
        )
        -- Additional filter for damaged undeliverable packages (from inducted logic)
        AND tracking_id not in (
            SELECT distinct u.tracking_id
            FROM hb_na_heisenbergrefinedobjects.d_perfectmile_shipment_status_history u
            WHERE u.delivery_station_code IN (:station_codes)
                and DATE(event_datetime_utc + INTERVAL '7 hours') >= DATE(TIMESTAMP :start_timestamp + INTERVAL '7 hours') - INTERVAL '1 day'
                and DATE(event_datetime_utc + INTERVAL '7 hours') <= DATE(TIMESTAMP :end_timestamp + INTERVAL '7 hours') + INTERVAL '1 day'
                AND u.business LIKE 'AMZ%'
                AND u.status_code in ('UNDELIVERABLE')
                and reason_code = 'DAMAGE'
                -- MODIFIED: Including SAME-DAY packages for SSD analysis
                AND ship_method NOT LIKE '%FRESH%' AND ship_method NOT LIKE '%BULK%'
                AND nvl(induct_location_type, '') NOT IN ('Crash Sort')
                AND nvl(shipment_type, '') NOT IN ('MFNPickup', 'ReturnPickup')
                AND manifest_route_code NOT LIKE '%SIDE%' AND manifest_route_code NOT LIKE '%COMM%'
                and tracking_id not in (
                    SELECT distinct u2.tracking_id
                    FROM hb_na_heisenbergrefinedobjects.d_perfectmile_shipment_status_history u2
                    WHERE u2.delivery_station_code IN (:station_codes)
                        and DATE(event_datetime_utc + INTERVAL '7 hours') >= DATE(TIMESTAMP :start_timestamp + INTERVAL '7 hours') - INTERVAL '1 day'
                        and DATE(event_datetime_utc + INTERVAL '7 hours') <= DATE(TIMESTAMP :end_timestamp + INTERVAL '7 hours') + INTERVAL '1 day'
                        AND u2.business LIKE 'AMZ%'
                        AND u2.status_code = 'READY_FOR_DEPARTURE'
                        -- MODIFIED: Including SAME-DAY packages for SSD analysis
                        AND ship_method NOT LIKE '%FRESH%' AND ship_method NOT LIKE '%BULK%'
                        AND nvl(induct_location_type, '') NOT IN ('Crash Sort')
                        AND nvl(shipment_type, '') NOT IN ('MFNPickup', 'ReturnPickup')
                        AND manifest_route_code NOT LIKE '%SIDE%' AND manifest_route_code NOT LIKE '%COMM%'
                )
        )
),

-- Get inducted packages (ReceiveScan events) - Container 1 entry
inducted_packages AS (
    SELECT DISTINCT
        tracking_id,
        delivery_station_code,
        event_datetime_utc as inducted_time
    FROM base_shipments
    WHERE status_code = 'AT_STATION'
        AND event_code_cdes = 'ReceiveScan'
),

-- Get stowed packages from instation events - Container 2 entry
stowed_packages AS (
    SELECT DISTINCT
        nvl(ie.tracking_id, ie.container_label) as tracking_id,
        ie.delivery_station_code,
        ie.event_datetime_utc as stowed_time
    FROM hb_na_heisenbergrefinedobjects.d_perfectmile_instation_events ie
    INNER JOIN inducted_packages ip
        ON nvl(ie.tracking_id, ie.container_label) = ip.tracking_id
        AND ie.delivery_station_code = ip.delivery_station_code
    WHERE ie.status = 'STOWED'
        AND ie.delivery_station_code IN (:station_codes)
        AND ie.event_datetime_utc >= TIMESTAMP :start_timestamp - INTERVAL '7 days'
        AND ie.event_datetime_utc <= TIMESTAMP :end_timestamp + INTERVAL '1 day'
),

-- Get packages that exited the system using official metric exit criteria
exited_packages AS (
    -- Packages that are delivered (final exit)
    SELECT DISTINCT
        tracking_id,
        delivery_station_code,
        event_datetime_utc as exit_time,
        'DELIVERED' as exit_type
    FROM base_shipments
    WHERE status_code = 'DELIVERED'

    UNION

    -- Packages that are ready for departure (Container 2 exit)
    SELECT DISTINCT
        tracking_id,
        delivery_station_code,
        event_datetime_utc as exit_time,
        'READY_FOR_DEPARTURE' as exit_type
    FROM base_shipments
    WHERE status_code = 'READY_FOR_DEPARTURE'

    UNION

    -- Packages that are undeliverable with damage (specific exit condition from official logic)
    SELECT DISTINCT
        tracking_id,
        delivery_station_code,
        event_datetime_utc as exit_time,
        'UNDELIVERABLE_DAMAGED' as exit_type
    FROM base_shipments
    WHERE status_code = 'UNDELIVERABLE'
        AND reason_code = 'DAMAGE'
),

-- Create package state timeline
package_states AS (
    SELECT
        ip.tracking_id,
        ip.delivery_station_code,
        ip.inducted_time,
        sp.stowed_time,
        ep.exit_time
    FROM inducted_packages ip
    LEFT JOIN stowed_packages sp
        ON ip.tracking_id = sp.tracking_id
        AND ip.delivery_station_code = sp.delivery_station_code
        AND sp.stowed_time >= ip.inducted_time
    LEFT JOIN exited_packages ep
        ON ip.tracking_id = ep.tracking_id
        AND ip.delivery_station_code = ep.delivery_station_code
        AND ep.exit_time >= ip.inducted_time
),

-- Calculate container membership for each time bucket
container_membership AS (
    SELECT
        tb.time_bucket,
        ps.tracking_id,
        ps.delivery_station_code,
        -- Container 1: Inducted but not yet stowed
        CASE
            WHEN ps.inducted_time <= tb.time_bucket
                 AND (ps.stowed_time IS NULL OR ps.stowed_time > tb.time_bucket)
                 AND (ps.exit_time IS NULL OR ps.exit_time > tb.time_bucket)
            THEN 1
            ELSE 0
        END as in_container1,
        -- Container 2: Stowed but not yet exited
        CASE
            WHEN ps.stowed_time IS NOT NULL
                 AND ps.stowed_time <= tb.time_bucket
                 AND (ps.exit_time IS NULL OR ps.exit_time > tb.time_bucket)
            THEN 1
            ELSE 0
        END as in_container2
    FROM time_buckets tb
    CROSS JOIN package_states ps
    WHERE ps.inducted_time <= tb.time_bucket + INTERVAL '1 day'  -- Only consider packages that could be active
),

-- Aggregate container populations
container_populations AS (
    SELECT
        time_bucket,
        delivery_station_code,
        SUM(in_container1) as packages_inducted_not_stowed,
        SUM(in_container2) as packages_stowed_not_exited
    FROM container_membership
    GROUP BY time_bucket, delivery_station_code
)

SELECT
    delivery_station_code,
    time_bucket,
    packages_inducted_not_stowed as container1_level,
    packages_stowed_not_exited as container2_level
FROM container_populations
WHERE time_bucket >= TIMESTAMP :start_timestamp
  AND time_bucket <= TIMESTAMP :end_timestamp
ORDER BY delivery_station_code, time_bucket;