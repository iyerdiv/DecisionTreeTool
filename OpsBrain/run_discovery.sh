#!/bin/bash

# Discovery script to find correct Mercury tables
# Usage: ./run_discovery.sh '<password>'

if [ $# -eq 0 ]; then
    echo "Usage: ./run_discovery.sh '<password>'"
    exit 1
fi

DB_PASS="$1"
DB_HOST="superlab-na.db.amazon.com"
DB_PORT="8199"
DB_NAME="superlab"
DB_USER="iyerdiv"

echo "==================================="
echo "Mercury Table Discovery"
echo "==================================="
echo ""

echo "Finding Mercury-related schemas..."
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
    -f discover_mercury_tables.sql \
    -o mercury_schemas.txt

echo "Results saved to mercury_schemas.txt"
echo ""
cat mercury_schemas.txt | head -20

echo ""
echo "==================================="
echo "Discovery complete!"
echo "==================================="