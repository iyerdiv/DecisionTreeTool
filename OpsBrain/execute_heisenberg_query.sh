#!/bin/bash

# Execute Heisenberg query with proper parameter substitution
# Usage: ./execute_heisenberg_query.sh '<password>'

if [ $# -eq 0 ]; then
    echo "Usage: ./execute_heisenberg_query.sh '<password>'"
    exit 1
fi

DB_PASS="$1"
DB_HOST="superlab-na.db.amazon.com"
DB_PORT="8199"
DB_NAME="superlab"
DB_USER="iyerdiv"

# Query parameters
STATION="DAE1"
START_DATE="2024-07-18"  # Using 2024, not 2025!
END_DATE="2024-07-20"
OUTPUT_FILE="heisenberg_ssd_results_${STATION}_$(date +%Y%m%d_%H%M%S).csv"

echo "==================================="
echo "Heisenberg SSD Analysis"
echo "==================================="
echo ""
echo "Configuration:"
echo "- Station: $STATION"
echo "- Period: $START_DATE to $END_DATE"
echo "- Output: $OUTPUT_FILE"
echo ""

# Create the actual query with substituted values
cat > temp_query.sql << EOF
-- Heisenberg SSD Analysis with substituted values
-- Station: ${STATION}
-- Period: ${START_DATE} to ${END_DATE}

WITH ssd_packages AS (
    SELECT
        warehouse_id,
        tracking_id,
        observation_timestamp,
        location_code,
        process_name,
        DATE_TRUNC('hour', observation_timestamp) +
            INTERVAL '5 minute' * FLOOR(EXTRACT(MINUTE FROM observation_timestamp) / 5) as time_bucket
    FROM heisenberg.package_observation
    WHERE warehouse_id = '${STATION}'
        AND observation_timestamp >= '${START_DATE}'::timestamp
        AND observation_timestamp < '${END_DATE}'::timestamp
        AND (ship_method LIKE '%SAME%' OR delivery_speed = 'SSD')
),
container_metrics AS (
    SELECT
        time_bucket,
        -- Container 1: Receive/Induct area
        COUNT(DISTINCT CASE
            WHEN location_code IN ('RECEIVE', 'INDUCT', 'PRESORT')
            THEN tracking_id
        END) AS container_1_count,

        -- Container 2: Stow/Sort area
        COUNT(DISTINCT CASE
            WHEN location_code IN ('STOW', 'SORT', 'PICK')
            THEN tracking_id
        END) AS container_2_count,

        -- Container 3: Stage/Ship area
        COUNT(DISTINCT CASE
            WHEN location_code IN ('STAGE', 'SHIP', 'LOAD')
            THEN tracking_id
        END) AS container_3_count,

        COUNT(DISTINCT tracking_id) AS total_packages
    FROM ssd_packages
    GROUP BY time_bucket
)
SELECT
    time_bucket,
    container_1_count AS receive_induct,
    container_2_count AS stow_sort,
    container_3_count AS stage_ship,
    total_packages,
    container_1_count + container_2_count + container_3_count AS total_in_facility
FROM container_metrics
ORDER BY time_bucket;
EOF

echo "Executing query..."
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
    -f temp_query.sql \
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
    head -n 10 "$OUTPUT_FILE" | column -t -s ','

    # Clean up
    rm temp_query.sql
else
    echo "ERROR: Query execution failed"
    echo "Check if:"
    echo "1. heisenberg.package_observation table exists"
    echo "2. Column names are correct (warehouse_id, tracking_id, etc.)"
    echo "3. Date range has data"
fi

echo ""
echo "==================================="