#!/bin/bash

# CAX2 Dashboard Validation Analysis
# Date: September 18, 2025
# Expected: ~349 packages with Missing DEA issues

DB_HOST="superlab-na.db.amazon.com"
DB_PORT="8199"
DB_NAME="superlab"
DB_USER="iyerdiv"
DB_PASS='2w|:k0]!bY9&r~#T(yhn5=;$6D%;j*9yEO[z2}U[kCve8~F}2NTQV.b$ViZs4X.`'

echo "======================================="
echo "CAX2 MISSING DEA ANALYSIS"
echo "Validating against Dashboard (349 packages)"
echo "Date: September 18, 2025"
echo "======================================="

echo ""
echo "Checking for 2025 data at CAX2..."
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
    -c "SELECT DATE(event_datetime_utc) as date,
               COUNT(DISTINCT tracking_id) as packages,
               COUNT(*) as total_events
        FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
        WHERE delivery_station_code = 'CAX2'
          AND DATE(event_datetime_utc) BETWEEN '2025-09-16' AND '2025-09-18'
        GROUP BY DATE(event_datetime_utc)
        ORDER BY date DESC;"

echo ""
echo "Running Missing DEA analysis..."
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
    -f /Volumes/workplace/DecisionTreeTool/OpsBrain/analyze_cax2_2025.sql \
    -o cax2_missing_dea_results.csv \
    --csv

echo ""
echo "Checking DCK1 CPT Banding issues (60 packages expected)..."
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
    -c "SELECT COUNT(DISTINCT tracking_id) as packages,
               COUNT(CASE WHEN reason_code LIKE '%BAND%' OR reason_code LIKE '%CPT%' THEN 1 END) as banding_issues
        FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
        WHERE delivery_station_code = 'DCK1'
          AND DATE(event_datetime_utc) = '2025-09-18'
          AND ship_method LIKE '%RUSH%';"

echo ""
echo "Results saved to: cax2_missing_dea_results.csv"
echo "Dashboard shows: 349 Missing DEA at CAX2"
echo "Our analysis shows: [Check CSV results]"
echo "======================================="