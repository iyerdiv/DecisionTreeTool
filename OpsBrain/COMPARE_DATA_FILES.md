# Comparison of EVENT1 Data Files

## File Differences:

### 1. EVENT1_CONSOLIDATED.csv (7,176 lines)
**Structure:** Package-level records
```
Columns: id, event1_arrival_time, event1_bucket_time, num_inflow_event1,
         num_outflow_event2, num_remain_event1, timestamp_dwell_min,
         timebucket_dwell_min, dwell_category, package_status, has_valid_timestamp
```
- **What it is:** Individual package records with their dwell times
- **Granularity:** One row per package
- **Size:** 783KB

### 2. EVENT1_FLOW_COMPARISON.csv (1,098 lines)
**Structure:** Aggregated time buckets
```
Columns: readable_time, num_inflow_event1, num_outflow_event2, num_remain_event1,
         bucket_time, actual_package_count, avg_dwell, median_dwell
```
- **What it is:** Pre-aggregated flow data by time bucket
- **Granularity:** One row per time bucket (appears to be 5-minute buckets)
- **Size:** 103KB
- **Key difference:** Has `actual_package_count` which might be more reliable!

## Critical Insight:

I've been using the WRONG file!

- **EVENT1_CONSOLIDATED** = package-level data (what I used)
- **EVENT1_FLOW_COMPARISON** = pre-aggregated flows (what I should use for flow analysis)

The FLOW_COMPARISON file has:
- Already aggregated flows
- Actual package counts
- Average and median dwell times per bucket
- Cleaner structure for physics modeling

## Let me re-run the analysis with the CORRECT file!