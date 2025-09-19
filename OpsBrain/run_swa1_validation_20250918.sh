#!/bin/bash

# SWA1 Validation Execution Script
# Runs the three parts of the analysis separately for clarity

DB_HOST="superlab-na.db.amazon.com"
DB_PORT="8199"
DB_NAME="superlab"
DB_USER="iyerdiv"
DB_PASS='2w|:k0]!bY9&r~#T(yhn5=;$6D%;j*9yEO[z2}U[kCve8~F}2NTQV.b$ViZs4X.`'

echo "======================================="
echo "SWA1 VALIDATION AGAINST MERCURY"
echo "======================================="

# Part 1: Validate specific Mercury packages
echo ""
echo "Part 1: Checking Mercury's 5 packages..."
echo "Expected: 2269, 267, 289, 2497, 266 minutes"
echo "Running validation..."

PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
    -f /Users/iyerdiv/swa1_validation_corrected.sql \
    -o swa1_validation_results.txt

echo "Results saved to: swa1_validation_results.txt"

# Show summary
echo ""
echo "======================================="
echo "VALIDATION SUMMARY"
echo "======================================="
echo "Mercury Data: 90,955 defects, 2,475 DPMO"
echo "Our Analysis: Check swa1_validation_results.txt"
echo ""
echo "Key Questions:"
echo "1. Do our dwell calculations match Mercury's?"
echo "2. How many packages exceed 200 min dwell?"
echo "3. What % are missing DEA assignment?"
echo "4. Which hours show bottlenecks?"
echo "======================================="