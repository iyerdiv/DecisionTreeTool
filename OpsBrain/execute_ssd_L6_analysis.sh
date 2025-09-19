#!/bin/bash

# SSD Analysis Execution Framework - L6 Standards
# Includes validation, monitoring, and alerting
# Author: OpsBrain Team
# Date: 2025-09-17

set -euo pipefail  # Exit on error, undefined variables, pipe failures

# ============================================================================
# CONFIGURATION
# ============================================================================

readonly DB_HOST="superlab-na.db.amazon.com"
readonly DB_PORT="8199"
readonly DB_NAME="superlab"
readonly DB_USER="iyerdiv"

# Analysis parameters
readonly STATION_CODES="'DAE1'"
readonly START_TIMESTAMP="2025-07-18 00:00:00"
readonly END_TIMESTAMP="2025-07-19 23:59:59"
readonly TIME_INTERVAL_MINUTES="5"

# Output configuration
readonly OUTPUT_DIR="./ssd_analysis_results_$(date +%Y%m%d_%H%M%S)"
readonly LOG_FILE="${OUTPUT_DIR}/execution.log"
readonly METRICS_FILE="${OUTPUT_DIR}/metrics.csv"
readonly VALIDATION_FILE="${OUTPUT_DIR}/validation_report.txt"
readonly MAIN_RESULTS="${OUTPUT_DIR}/ssd_container_analysis.csv"

# Thresholds for validation
readonly MIN_EXPECTED_ROWS=200  # Minimum rows for 2-day analysis
readonly MAX_EXECUTION_TIME=300  # Maximum seconds for query execution
readonly MIN_SLA_SUCCESS_RATE=0.90  # Minimum acceptable SLA

# ============================================================================
# FUNCTIONS
# ============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$LOG_FILE" >&2
}

validate_environment() {
    log "Validating environment..."

    # Check database connectivity
    if ! nslookup "$DB_HOST" &>/dev/null; then
        log_error "Cannot resolve database host. Check VPN connection."
        exit 1
    fi

    # Check SQL file exists
    if [[ ! -f "ssd_analysis_L6_quality.sql" ]]; then
        log_error "SQL file not found: ssd_analysis_L6_quality.sql"
        exit 1
    fi

    # Validate password provided
    if [[ $# -eq 0 ]]; then
        log_error "Usage: $0 <database_password>"
        exit 1
    fi

    log "✓ Environment validated"
}

create_output_directory() {
    mkdir -p "$OUTPUT_DIR"
    log "Created output directory: $OUTPUT_DIR"
}

execute_query() {
    local db_pass="$1"
    local start_time=$(date +%s)

    log "Executing SSD analysis query..."
    log "  Station: ${STATION_CODES}"
    log "  Period: ${START_TIMESTAMP} to ${END_TIMESTAMP}"
    log "  Interval: ${TIME_INTERVAL_MINUTES} minutes"

    # Execute main analysis query
    PGPASSWORD="$db_pass" timeout "$MAX_EXECUTION_TIME" \
        psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
        -v start_timestamp="'$START_TIMESTAMP'" \
        -v end_timestamp="'$END_TIMESTAMP'" \
        -v station_codes="$STATION_CODES" \
        -v time_interval_minutes="$TIME_INTERVAL_MINUTES" \
        -f ssd_analysis_L6_quality.sql \
        -o "$MAIN_RESULTS" \
        --csv \
        2>&1 | tee -a "$LOG_FILE"

    local exit_code=$?
    local end_time=$(date +%s)
    local execution_time=$((end_time - start_time))

    log "Query execution time: ${execution_time} seconds"

    if [[ $exit_code -ne 0 ]]; then
        log_error "Query execution failed with exit code: $exit_code"
        return 1
    fi

    if [[ $execution_time -gt $MAX_EXECUTION_TIME ]]; then
        log_error "Query exceeded maximum execution time"
        return 1
    fi

    log "✓ Query executed successfully"
    return 0
}

validate_results() {
    log "Validating results..."

    # Check file exists and has content
    if [[ ! -f "$MAIN_RESULTS" ]]; then
        log_error "Results file not created"
        return 1
    fi

    local row_count=$(wc -l < "$MAIN_RESULTS")
    row_count=$((row_count - 1))  # Subtract header

    log "Result row count: $row_count"

    # Validation report
    {
        echo "=== SSD ANALYSIS VALIDATION REPORT ==="
        echo "Generated: $(date)"
        echo ""
        echo "CONFIGURATION:"
        echo "  Station: ${STATION_CODES}"
        echo "  Period: ${START_TIMESTAMP} to ${END_TIMESTAMP}"
        echo "  Interval: ${TIME_INTERVAL_MINUTES} minutes"
        echo ""
        echo "RESULTS:"
        echo "  Total rows: $row_count"
        echo "  Expected minimum: $MIN_EXPECTED_ROWS"
        echo "  Status: $([ $row_count -ge $MIN_EXPECTED_ROWS ] && echo 'PASS' || echo 'FAIL')"
        echo ""
    } > "$VALIDATION_FILE"

    # Data quality checks
    log "Running data quality checks..."

    # Check for nulls in critical columns
    local null_check=$(awk -F',' '
        NR > 1 {
            for(i=1; i<=5; i++) {
                if($i == "") null_count++
            }
        }
        END { print null_count+0 }
    ' "$MAIN_RESULTS")

    {
        echo "DATA QUALITY:"
        echo "  Null values in critical columns: $null_check"
        echo "  Status: $([ $null_check -eq 0 ] && echo 'PASS' || echo 'WARNING')"
        echo ""
    } >> "$VALIDATION_FILE"

    # Extract key metrics
    log "Extracting key metrics..."

    # Parse SLA success rate from results
    local sla_rate=$(awk -F',' 'NR==2 {print $12}' "$MAIN_RESULTS" 2>/dev/null || echo "0")

    {
        echo "KEY METRICS:"
        echo "  SLA Success Rate: ${sla_rate}%"
        echo "  Target: ${MIN_SLA_SUCCESS_RATE}"
        echo "  Status: $(awk -v sla="$sla_rate" -v target="$MIN_SLA_SUCCESS_RATE" \
            'BEGIN { if(sla >= target) print "PASS"; else print "FAIL" }')"
        echo ""
    } >> "$VALIDATION_FILE"

    cat "$VALIDATION_FILE" | tee -a "$LOG_FILE"

    # Return based on validation status
    if [[ $row_count -lt $MIN_EXPECTED_ROWS ]]; then
        log_error "Insufficient data rows"
        return 1
    fi

    log "✓ Results validated"
    return 0
}

generate_summary() {
    log "Generating summary statistics..."

    # Create summary metrics file
    {
        echo "metric,value"
        echo "execution_date,$(date +%Y-%m-%d)"
        echo "station,${STATION_CODES//\'/}"
        echo "analysis_period,${START_TIMESTAMP} to ${END_TIMESTAMP}"
        echo "row_count,$(wc -l < "$MAIN_RESULTS")"
        echo "file_size_kb,$(du -k "$MAIN_RESULTS" | cut -f1)"
    } > "$METRICS_FILE"

    # Sample of results
    log "First 5 time buckets:"
    head -n 6 "$MAIN_RESULTS" | column -t -s ',' | tee -a "$LOG_FILE"

    log "✓ Summary generated"
}

cleanup_on_exit() {
    if [[ -f "temp_query.sql" ]]; then
        rm -f "temp_query.sql"
    fi
    log "Cleanup completed"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    local db_pass="$1"

    # Setup
    trap cleanup_on_exit EXIT
    create_output_directory

    log "==================================="
    log "SSD Analysis - L6 Quality Standards"
    log "==================================="

    # Pre-flight checks
    validate_environment "$@"

    # Execute analysis
    if ! execute_query "$db_pass"; then
        log_error "Analysis failed during execution"
        exit 1
    fi

    # Validate results
    if ! validate_results; then
        log_error "Results failed validation"
        exit 1
    fi

    # Generate summary
    generate_summary

    # Success
    log ""
    log "==================================="
    log "✓ ANALYSIS COMPLETE"
    log "==================================="
    log ""
    log "Results saved to: $OUTPUT_DIR"
    log "  Main results: $MAIN_RESULTS"
    log "  Validation: $VALIDATION_FILE"
    log "  Metrics: $METRICS_FILE"
    log "  Log: $LOG_FILE"

    return 0
}

# Run main function with all arguments
main "$@"