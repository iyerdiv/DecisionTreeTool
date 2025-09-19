#!/bin/bash

# Run the EXISTING working SSD query from PerfectMileSciOpsBrain
# This query has already been tested and works!

if [ $# -eq 0 ]; then
    echo "Usage: ./run_existing_ssd_query.sh '<password>'"
    exit 1
fi

DB_PASS="$1"
DB_HOST="superlab-na.db.amazon.com"
DB_PORT="8199"
DB_NAME="superlab"
DB_USER="iyerdiv"

# Query parameters - Using 2025 dates (data available from June 2025)
START_TIMESTAMP="2025-07-18 00:00:00"  # July 2025 - we have data!
END_TIMESTAMP="2025-07-19 23:59:59"    # 2-day test period
STATION_CODES="'DAE1'"                 # Note the quotes!
TIME_INTERVAL_MINUTES="5"              # 5-minute intervals

OUTPUT_FILE="ssd_5min_working_results_$(date +%Y%m%d_%H%M%S).csv"

echo "==================================="
echo "SSD Analysis - Using WORKING Query"
echo "==================================="
echo ""
echo "Configuration:"
echo "- Station: DAE1"
echo "- Period: $START_TIMESTAMP to $END_TIMESTAMP"
echo "- Interval: 5 minutes"
echo "- Query: instation_container_levels_v3_ssd_20250917.sql"
echo "- Output: $OUTPUT_FILE"
echo ""

# Copy the working query from PerfectMileSciOpsBrain
cp /Volumes/workplace/perfectmile-brazil-ws/src/PerfectMileSciOpsBrain/src/sql/instation_container_levels_v3_ssd_20250917.sql ./working_query.sql

echo "Executing proven working query..."
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
    -v start_timestamp="'$START_TIMESTAMP'" \
    -v end_timestamp="'$END_TIMESTAMP'" \
    -v station_codes="$STATION_CODES" \
    -v time_interval_minutes="$TIME_INTERVAL_MINUTES" \
    -f working_query.sql \
    -o "$OUTPUT_FILE" \
    --csv

if [ $? -eq 0 ]; then
    echo "✓ Query executed successfully"
    echo ""
    echo "Results saved to: $OUTPUT_FILE"
    echo ""

    # Quick summary
    echo "Quick Summary:"
    wc -l "$OUTPUT_FILE" | awk '{print "- Total rows: " $1-1}'
    echo ""
    echo "First 10 rows:"
    head -n 10 "$OUTPUT_FILE" | column -t -s ','

    echo ""
    echo "Last 5 rows:"
    tail -n 5 "$OUTPUT_FILE" | column -t -s ','
else
    echo "ERROR: Query execution failed"
    echo ""
    echo "This is using the EXACT query that works in PerfectMileSciOpsBrain"
    echo "Table: hb_na_heisenbergrefinedobjects.d_perfectmile_shipment_status_history"
fi

echo ""
echo "====================================="