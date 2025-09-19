#!/bin/bash

# Execute 5-Minute SSD Container Analysis
# Target: DLA8 (high-volume LA station)

DB_HOST="superlab-na.db.amazon.com"
DB_PORT="8199"
DB_NAME="superlab"
DB_USER="iyerdiv"
DB_PASS='2w|:k0]!bY9&r~#T(yhn5=;$6D%;j*9yEO[z2}U[kCve8~F}2NTQV.b$ViZs4X.`'

echo "======================================="
echo "5-MINUTE SSD CONTAINER ANALYSIS"
echo "Station: DLA8"
echo "Date: Sept 15, 2025"
echo "======================================="

# First verify DLA8 has RUSH volume
echo "Verifying RUSH package volume at DLA8..."
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
    -c "SELECT
          COUNT(DISTINCT tracking_id) as rush_packages,
          COUNT(DISTINCT CASE WHEN status_code = 'AT_STATION' THEN tracking_id END) as inducted,
          COUNT(DISTINCT CASE WHEN status_code = 'DELIVERED' THEN tracking_id END) as delivered
        FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
        WHERE delivery_station_code = 'DLA8'
          AND DATE(event_datetime_utc) = '2025-09-15'
          AND (ship_method LIKE '%RUSH%' OR ship_method LIKE '%SDD%');"

echo ""
echo "Running 5-minute interval analysis..."
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
    -f /Volumes/workplace/DecisionTreeTool/OpsBrain/get_5min_ssd_data.sql \
    -o dla8_5min_results.csv \
    --csv

echo ""
echo "Analysis complete. Results saved to dla8_5min_results.csv"

# Quick peek at peak hours
echo ""
echo "Peak congestion periods:"
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
    -c "WITH hourly AS (
          SELECT
            DATE_TRUNC('hour', event_datetime_utc) as hour,
            COUNT(DISTINCT tracking_id) as packages
          FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
          WHERE delivery_station_code = 'DLA8'
            AND DATE(event_datetime_utc) = '2025-09-15'
            AND (ship_method LIKE '%RUSH%' OR ship_method LIKE '%SDD%')
          GROUP BY DATE_TRUNC('hour', event_datetime_utc)
        )
        SELECT TO_CHAR(hour, 'HH24:00') as hour,
               packages,
               REPEAT('█', packages/10) as volume_bar
        FROM hourly
        ORDER BY packages DESC
        LIMIT 5;"