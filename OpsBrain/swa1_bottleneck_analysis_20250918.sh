#!/bin/bash

# SWA1 Bottleneck Analysis using Mercury High-Dwell Packages
# Station: SWA1
# Date Range: Sept 13-17, 2025
# Focus: Packages with 200+ minute dwell times

DB_HOST="superlab-na.db.amazon.com"
DB_PORT="8199"
DB_NAME="superlab"
DB_USER="iyerdiv"
DB_PASS='2w|:k0]!bY9&r~#T(yhn5=;$6D%;j*9yEO[z2}U[kCve8~F}2NTQV.b$ViZs4X.`'

echo "======================================="
echo "SWA1 BOTTLENECK ANALYSIS"
echo "Mercury Validation - High Dwell Packages"
echo "======================================="

# Step 1: Verify SWA1 has data for these dates
echo ""
echo "Step 1: Checking SWA1 data availability..."
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
    -c "SELECT DATE(event_datetime_utc) as date,
               COUNT(DISTINCT tracking_id) as total_packages,
               COUNT(DISTINCT CASE WHEN ship_method LIKE '%RUSH%' THEN tracking_id END) as rush_packages,
               COUNT(DISTINCT CASE WHEN route_code IS NULL THEN tracking_id END) as no_route_packages
        FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
        WHERE delivery_station_code = 'SWA1'
          AND DATE(event_datetime_utc) BETWEEN '2025-09-13' AND '2025-09-17'
        GROUP BY DATE(event_datetime_utc)
        ORDER BY date;"

# Step 2: Trace the worst Mercury packages
echo ""
echo "Step 2: Tracing high-dwell packages (267-2497 min)..."
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
    --csv \
    -c "SELECT
          tracking_id,
          status_code,
          TO_CHAR(event_datetime_utc, 'MM-DD HH24:MI') as event_time,
          route_code,
          reason_code,
          LAG(event_datetime_utc) OVER (PARTITION BY tracking_id ORDER BY event_datetime_utc) as prev_time,
          ROUND(EXTRACT(EPOCH FROM (event_datetime_utc - LAG(event_datetime_utc)
            OVER (PARTITION BY tracking_id ORDER BY event_datetime_utc)))/60) as minutes_since_last
        FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
        WHERE delivery_station_code = 'SWA1'
          AND tracking_id IN (
            'TBA324382452417',  -- 2269 min
            'TBA324407564226',  -- 267 min
            'TBA324387931890',  -- 289 min
            'TBA324328209818',  -- 2497 min
            'TBA324408440124'   -- 266 min
          )
        ORDER BY tracking_id, event_datetime_utc;" \
    -o swa1_package_traces.csv

echo "Package traces saved to: swa1_package_traces.csv"

# Step 3: Find bottleneck pattern - where do packages get stuck?
echo ""
echo "Step 3: Identifying bottleneck stages..."
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
    -c "WITH package_stages AS (
          SELECT
            status_code,
            COUNT(*) as occurrences,
            AVG(EXTRACT(EPOCH FROM (
              LEAD(event_datetime_utc) OVER (PARTITION BY tracking_id ORDER BY event_datetime_utc)
              - event_datetime_utc
            ))/60) as avg_minutes_at_stage,
            MAX(EXTRACT(EPOCH FROM (
              LEAD(event_datetime_utc) OVER (PARTITION BY tracking_id ORDER BY event_datetime_utc)
              - event_datetime_utc
            ))/60) as max_minutes_at_stage
          FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
          WHERE delivery_station_code = 'SWA1'
            AND DATE(event_datetime_utc) BETWEEN '2025-09-13' AND '2025-09-17'
          GROUP BY status_code
        )
        SELECT
          status_code,
          occurrences,
          ROUND(avg_minutes_at_stage) as avg_dwell_min,
          ROUND(max_minutes_at_stage) as max_dwell_min,
          CASE
            WHEN avg_minutes_at_stage > 60 THEN '🔴 BOTTLENECK'
            WHEN avg_minutes_at_stage > 30 THEN '🟡 SLOW'
            ELSE '🟢 OK'
          END as status
        FROM package_stages
        WHERE avg_minutes_at_stage IS NOT NULL
        ORDER BY avg_minutes_at_stage DESC
        LIMIT 10;"

# Step 4: Apply Little's Law to SWA1
echo ""
echo "Step 4: Little's Law Analysis (L = λW)..."
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
    -c "WITH hourly_flow AS (
          SELECT
            DATE_TRUNC('hour', event_datetime_utc) as hour,
            COUNT(CASE WHEN status_code = 'AT_STATION' THEN 1 END) as arrivals,
            COUNT(CASE WHEN status_code IN ('DELIVERED', 'READY_FOR_DEPARTURE') THEN 1 END) as exits,
            COUNT(DISTINCT tracking_id) as inventory
          FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
          WHERE delivery_station_code = 'SWA1'
            AND DATE(event_datetime_utc) = '2025-09-15'
          GROUP BY hour
        )
        SELECT
          TO_CHAR(hour, 'HH24:00') as time,
          arrivals as lambda,
          inventory as L,
          CASE
            WHEN arrivals > 0
            THEN ROUND(inventory::numeric / arrivals * 60)
            ELSE 0
          END as W_minutes,
          CASE
            WHEN arrivals > exits * 1.2 THEN '🔴 BOTTLENECK'
            ELSE '🟢 FLOWING'
          END as status
        FROM hourly_flow
        WHERE arrivals > 0
        ORDER BY hour;"

# Step 5: Check for Missing DEA pattern
echo ""
echo "Step 5: Missing DEA Analysis..."
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
    -c "SELECT
          COUNT(DISTINCT tracking_id) as total_packages,
          COUNT(DISTINCT CASE WHEN route_code IS NULL THEN tracking_id END) as missing_dea,
          ROUND(100.0 * COUNT(DISTINCT CASE WHEN route_code IS NULL THEN tracking_id END) /
            COUNT(DISTINCT tracking_id), 1) as missing_dea_pct
        FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
        WHERE delivery_station_code = 'SWA1'
          AND DATE(event_datetime_utc) = '2025-09-15'
          AND ship_method LIKE '%RUSH%';"

echo ""
echo "======================================="
echo "Analysis Complete!"
echo "Check swa1_package_traces.csv for details"
echo "======================================="