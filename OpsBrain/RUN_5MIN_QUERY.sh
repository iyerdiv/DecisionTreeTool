#!/bin/bash

# Mercury SSD 5-Minute Interval Query Execution
# Date: 2025-09-17

echo "==================================="
echo "Mercury SSD Container Analysis"
echo "5-Minute Intervals (Including SAME)"
echo "==================================="

# Database connection parameters
DB_HOST="superlab-na.db.amazon.com"
DB_PORT="8199"
DB_NAME="superlab"
DB_USER="iyerdiv"

# Query parameters
STATION="DAE1"
START_DATE="2025-07-18"
END_DATE="2025-07-20"  # 2-day test period
OUTPUT_FILE="ssd_5min_results_${STATION}_$(date +%Y%m%d_%H%M%S).csv"

echo ""
echo "Configuration:"
echo "- Station: $STATION"
echo "- Period: $START_DATE to $END_DATE"
echo "- Interval: 5 minutes"
echo "- Output: $OUTPUT_FILE"
echo ""

# Check VPN connection by testing DNS resolution
echo "Checking database connectivity..."
if ! nslookup superlab-na.db.amazon.com &> /dev/null; then
    echo "ERROR: Cannot resolve database. Please ensure VPN is connected."
    exit 1
fi
echo "✓ Database reachable"
echo ""

# Prompt for password
echo -n "Enter database password for $DB_USER: "
read -s DB_PASS
echo ""
echo ""

# Execute query
echo "Executing query..."
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
    -v station="'$STATION'" \
    -v start_date="'$START_DATE'" \
    -v end_date="'$END_DATE'" \
    -f instation_container_levels_v3_ssd_20250917.sql \
    -o "$OUTPUT_FILE" \
    --csv

if [ $? -eq 0 ]; then
    echo "✓ Query executed successfully"
    echo ""
    echo "Results saved to: $OUTPUT_FILE"
    echo ""

    # Quick summary
    echo "Quick Summary:"
    wc -l "$OUTPUT_FILE" | awk '{print "- Total rows: " $1-1}'  # Subtract header
    head -n 5 "$OUTPUT_FILE" | column -t -s ','
else
    echo "ERROR: Query execution failed"
    exit 1
fi

echo ""
echo "==================================="
echo "Query complete!"
echo "====================================="