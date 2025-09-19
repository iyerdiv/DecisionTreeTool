#!/bin/bash

# DLA9 SSD Analysis - High Volume Station
# Created: 2025-09-17

DB_HOST="superlab-na.db.amazon.com"
DB_PORT="8199"
DB_NAME="superlab"
DB_USER="iyerdiv"
DB_PASS='2w|:k0]!bY9&r~#T(yhn5=;$6D%;j*9yEO[z2}U[kCve8~F}2NTQV.b$ViZs4X.`'

echo "==================================="
echo "DLA9 SSD Analysis"
echo "==================================="

# First check for RUSH packages at DLA9
echo "Checking for RUSH packages at DLA9..."
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
    -c "SELECT DATE(event_datetime_utc) as date,
               COUNT(*) as rush_packages,
               COUNT(DISTINCT tracking_id) as unique_packages
        FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
        WHERE delivery_station_code = 'DLA9'
          AND ship_method LIKE '%RUSH%'
          AND DATE(event_datetime_utc) BETWEEN '2025-09-14' AND '2025-09-16'
        GROUP BY DATE(event_datetime_utc)
        ORDER BY date;"

echo ""
echo "Checking ship methods at DLA9..."
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
    -c "SELECT ship_method, COUNT(*) as count
        FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
        WHERE delivery_station_code = 'DLA9'
          AND DATE(event_datetime_utc) = '2025-09-15'
          AND ship_method IS NOT NULL
        GROUP BY ship_method
        ORDER BY count DESC
        LIMIT 10;"