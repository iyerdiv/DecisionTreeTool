# UAT Validation Plan - SSD Bottleneck Analysis

## Test Cases for User Acceptance Testing

### Test Case 1: High-Volume Station Peak Hour
**Station:** CAX2
**Date:** September 17, 2025 (Monday)
**Time:** 14:00-16:00 (2-4 PM)
**Expected:**
- High dwell times during peak
- Missing DEA assignments
- ~300-400 affected packages

### Test Case 2: Weekend Low Volume
**Station:** CAX2
**Date:** September 14, 2025 (Saturday)
**Time:** 10:00-12:00 (Morning)
**Expected:**
- Lower volumes
- Better SLA compliance
- <50 affected packages

### Test Case 3: Multi-Station Comparison
**Stations:** CAX2, DCK1, STL8
**Date:** September 16, 2025 (Sunday)
**Time:** Full day
**Expected:**
- CAX2: Missing DEA issues
- DCK1: CPT Banding problems
- STL8: TDU Accumulation

### Test Case 4: Historical Benchmark
**Station:** VNY5
**Date:** September 3, 2024
**Time:** Full day
**Expected:**
- 81,837 RUSH packages
- Known good data day
- Baseline for comparison

### Test Case 5: Real-Time Validation
**Station:** Current dashboard top offender
**Date:** TODAY (September 18, 2025)
**Time:** Last 4 hours
**Expected:**
- Should match dashboard counts ±5%
- Same bottleneck types
- Similar dwell distributions

## Validation Queries

### Query 1: Peak Hour Bottleneck Detection
```sql
-- CAX2 Peak Hour Analysis
SELECT
  DATE_TRUNC('hour', event_datetime_utc) as hour,
  COUNT(DISTINCT tracking_id) as packages,
  AVG(CASE
    WHEN status_code = 'AT_STATION' THEN 1
  END) * COUNT(DISTINCT tracking_id) as inducted,
  AVG(CASE
    WHEN route_code IS NULL THEN 1
    ELSE 0
  END) * 100 as pct_missing_dea
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE delivery_station_code = 'CAX2'
  AND DATE(event_datetime_utc) = '2025-09-17'
  AND DATE_TRUNC('hour', event_datetime_utc) BETWEEN
      '2025-09-17 14:00:00' AND '2025-09-17 16:00:00'
  AND ship_method LIKE '%RUSH%'
GROUP BY hour
ORDER BY hour;
```

### Query 2: Weekend Comparison
```sql
-- Weekend vs Weekday at CAX2
WITH daily_stats AS (
  SELECT
    DATE(event_datetime_utc) as date,
    EXTRACT(DOW FROM event_datetime_utc) as day_of_week,
    COUNT(DISTINCT tracking_id) as total_packages,
    COUNT(DISTINCT CASE
      WHEN route_code IS NULL THEN tracking_id
    END) as missing_dea_packages,
    AVG(EXTRACT(EPOCH FROM (
      MAX(event_datetime_utc) - MIN(event_datetime_utc)
    ))/60) as avg_dwell_minutes
  FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
  WHERE delivery_station_code = 'CAX2'
    AND DATE(event_datetime_utc) BETWEEN '2025-09-14' AND '2025-09-17'
    AND ship_method LIKE '%RUSH%'
  GROUP BY DATE(event_datetime_utc), tracking_id
)
SELECT
  date,
  CASE
    WHEN day_of_week IN (0,6) THEN 'Weekend'
    ELSE 'Weekday'
  END as day_type,
  SUM(total_packages) as packages,
  SUM(missing_dea_packages) as missing_dea,
  ROUND(AVG(avg_dwell_minutes), 1) as avg_dwell
FROM daily_stats
GROUP BY date, day_of_week
ORDER BY date;
```

### Query 3: Multi-Station Issues
```sql
-- Compare CAX2, DCK1, STL8 issues
SELECT
  delivery_station_code,
  COUNT(DISTINCT tracking_id) as total_packages,
  -- Missing DEA
  COUNT(DISTINCT CASE
    WHEN route_code IS NULL THEN tracking_id
  END) as missing_dea,
  -- Banding issues (reason_code check)
  COUNT(DISTINCT CASE
    WHEN reason_code LIKE '%BAND%' OR reason_code LIKE '%CPT%'
    THEN tracking_id
  END) as banding_issues,
  -- Accumulation (high dwell)
  COUNT(DISTINCT CASE
    WHEN status_code IN ('AT_STATION', 'STOWED')
    THEN tracking_id
  END) as accumulated,
  ROUND(AVG(EXTRACT(EPOCH FROM (
    event_datetime_utc - LAG(event_datetime_utc)
    OVER (PARTITION BY tracking_id ORDER BY event_datetime_utc)
  ))/60), 1) as avg_dwell_minutes
FROM heisenbergrefinedobjects.d_perfectmile_shipment_status_history
WHERE delivery_station_code IN ('CAX2', 'DCK1', 'STL8')
  AND DATE(event_datetime_utc) = '2025-09-16'
  AND ship_method LIKE '%RUSH%'
GROUP BY delivery_station_code;
```

## Success Criteria

1. **Data Availability**: Queries return non-zero results
2. **Volume Match**: Package counts within 10% of dashboard
3. **Pattern Match**: Peak hours show increased delays
4. **Issue Type Match**: CAX2=DEA, DCK1=Banding, STL8=Accumulation
5. **Dwell Accuracy**: Average dwell times align with operational reports

## UAT Execution Plan

**Step 1:** Run Query 1 for peak validation
**Step 2:** Compare weekend vs weekday (Query 2)
**Step 3:** Validate multi-station patterns (Query 3)
**Step 4:** Screenshot dashboard at same time
**Step 5:** Compare results in validation matrix

## Validation Matrix

| Metric | Our Analysis | Dashboard | Delta | Pass/Fail |
|--------|-------------|-----------|-------|-----------|
| CAX2 Missing DEA (Sept 17) | TBD | 349 | TBD | TBD |
| DCK1 Banding Issues | TBD | 60 | TBD | TBD |
| STL8 Accumulation | TBD | 18 | TBD | TBD |
| Peak Hour Spike | TBD | 2-4pm | TBD | TBD |
| Weekend Reduction | TBD | -60% | TBD | TBD |