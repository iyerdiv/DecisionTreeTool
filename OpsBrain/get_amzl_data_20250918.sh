#!/bin/bash

# AMZL Data Extraction for M4 Analysis
# Focus: AMZL delivery network performance

DB_HOST="superlab-na.db.amazon.com"
DB_PORT="8199"
DB_NAME="superlab"
DB_USER="iyerdiv"
DB_PASS='2w|:k0]!bY9&r~#T(yhn5=;$6D%;j*9yEO[z2}U[kCve8~F}2NTQV.b$ViZs4X.`'

echo "==================================="
echo "M4 FRAMEWORK: AMZL NETWORK ANALYSIS"
echo "==================================="

# M1: Identify AMZL ship methods
echo "M1 - AMZL Ship Method Discovery..."
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
    -c "SELECT ship_method,
               COUNT(*) as volume,
               AVG(EXTRACT(EPOCH FROM (event_datetime_utc - LAG(event_datetime_utc) OVER (PARTITION BY tracking_id ORDER BY event_datetime_utc)))/60) as avg_transition_minutes
        FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
        WHERE delivery_station_code = 'DLA9'
          AND ship_method LIKE 'AMZL%'
          AND DATE(event_datetime_utc) = '2025-09-15'
        GROUP BY ship_method
        ORDER BY volume DESC
        LIMIT 15;"

# M2: Measure AMZL package flow at different time granularities
echo ""
echo "M2 - AMZL Time Granularity Analysis..."
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
    -c "WITH amzl_flow AS (
          SELECT DATE_TRUNC('hour', event_datetime_utc) as hour,
                 DATE_TRUNC('minute', event_datetime_utc) - DATE_TRUNC('hour', event_datetime_utc) as minute_in_hour,
                 status_code,
                 COUNT(*) as package_count
          FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
          WHERE delivery_station_code = 'DLA9'
            AND ship_method LIKE 'AMZL%RUSH%'
            AND DATE(event_datetime_utc) = '2025-09-15'
          GROUP BY DATE_TRUNC('hour', event_datetime_utc),
                   DATE_TRUNC('minute', event_datetime_utc),
                   status_code
        )
        SELECT hour,
               COUNT(DISTINCT minute_in_hour) as active_minutes,
               SUM(package_count) as total_packages,
               SUM(package_count) / NULLIF(COUNT(DISTINCT minute_in_hour), 0) as avg_packages_per_minute
        FROM amzl_flow
        GROUP BY hour
        ORDER BY hour;"

# M3: Model AMZL route complexity
echo ""
echo "M3 - AMZL Route Pattern Analysis..."
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
    -c "SELECT route_code,
               COUNT(DISTINCT tracking_id) as packages,
               COUNT(DISTINCT status_code) as status_transitions,
               MIN(event_datetime_utc) as route_start,
               MAX(event_datetime_utc) as route_end,
               EXTRACT(EPOCH FROM (MAX(event_datetime_utc) - MIN(event_datetime_utc)))/3600 as route_duration_hours
        FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
        WHERE delivery_station_code = 'DLA9'
          AND ship_method LIKE 'AMZL%'
          AND route_code IS NOT NULL
          AND DATE(event_datetime_utc) = '2025-09-15'
        GROUP BY route_code
        ORDER BY packages DESC
        LIMIT 10;"

# M4: Missing Context - AMZL capacity and constraints
echo ""
echo "M4 - AMZL Network Context..."
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
    -c "WITH hourly_capacity AS (
          SELECT DATE_TRUNC('hour', event_datetime_utc) as hour,
                 COUNT(DISTINCT route_code) as active_routes,
                 COUNT(DISTINCT tracking_id) as packages_processed,
                 COUNT(CASE WHEN status_code = 'DELIVERED' THEN 1 END) as delivered,
                 COUNT(CASE WHEN status_code IN ('UNDELIVERABLE', 'RETURNED') THEN 1 END) as failed
          FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
          WHERE delivery_station_code = 'DLA9'
            AND ship_method LIKE 'AMZL%'
            AND DATE(event_datetime_utc) = '2025-09-15'
          GROUP BY DATE_TRUNC('hour', event_datetime_utc)
        )
        SELECT hour,
               active_routes,
               packages_processed,
               delivered,
               failed,
               ROUND(100.0 * delivered / NULLIF(packages_processed, 0), 2) as delivery_rate_pct,
               ROUND(packages_processed::numeric / NULLIF(active_routes, 0), 1) as packages_per_route
        FROM hourly_capacity
        ORDER BY hour;"