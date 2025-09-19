# Data Requirements for Physics Model Analysis

## Essential Data Elements Needed:

### 1. **FLOW DATA (Arrivals & Departures)**
```
Required columns:
- timestamp: When the measurement was taken
- arrivals (λ_in): Number of items entering the system
- departures (λ_out): Number of items leaving the system
- time_interval: Duration of measurement window (e.g., 5 min, 1 hour)
```

### 2. **STATE DATA (Queue/Inventory)**
```
Required columns:
- timestamp: When measured
- queue_depth (L): Number of items currently in the system
- OR cumulative counts that allow queue calculation
```

### 3. **DWELL/WAIT TIME DATA**
```
Required columns:
- wait_time (W): Time items spend in system
- Can be average, median, or distribution
- Units must be clear (minutes, hours)
```

## For Each Physics Model:

### Conservation Laws (Mass Balance)
**Need:**
- Inflow count
- Outflow count
- Starting queue depth
- Ending queue depth
**Test:** Inflow - Outflow = Change in Queue

### Little's Law (L = λW)
**Need:**
- L: Queue depth (independent measurement)
- λ: Arrival rate
- W: Wait time
**Test:** All three measured independently, then verify L = λW

### Queue Theory (M/M/1, etc.)
**Need:**
- Arrival rate distribution
- Service rate distribution
- Number of servers
- Queue discipline (FIFO, LIFO, etc.)

### Stability Analysis
**Need:**
- Time series of arrivals
- Time series of departures
- Maximum service capacity
**Test:** ρ = λ/μ < 1 for stability

### Chaos/Predictability
**Need:**
- Long time series (>1000 points)
- Consistent sampling interval
- No aggregation/averaging
**Test:** Calculate Lyapunov exponents, autocorrelation

## Current Data Problems:

### ❌ What We Have:
- Pre-aggregated counts (already summed)
- Unclear field definitions
- Mixed granularities
- No clear queue depth measurement

### ✅ What We Need:
- Raw event data OR
- Clear time-bucketed measurements with:
  - Actual queue depth (not calculated)
  - Actual arrival events
  - Actual departure events
  - Measured wait times

## Minimum Viable Dataset:

```csv
timestamp, queue_depth, arrivals, departures, avg_wait_time
2024-01-01 08:00:00, 245, 120, 115, 12.5
2024-01-01 08:05:00, 250, 125, 120, 13.2
2024-01-01 08:10:00, 248, 118, 120, 12.8
...
```

With this, we can test:
- Conservation: ✓
- Little's Law: ✓
- Stability: ✓
- Basic queue theory: ✓

## Why Current Files Fail:

1. **EVENT1_CONSOLIDATED.csv**
   - Has package-level data but pre-aggregated
   - `num_remain_event1` is unclear (not queue depth)
   - Individual package records, not system state

2. **EVENT1_FLOW_COMPARISON.csv**
   - Has flows but `actual_package_count` = 6.5 (unrealistic)
   - `num_remain_event1` = cumulative counter, not queue

3. **littles_law_analysis.csv**
   - Might have the right structure - need to check!

## Next Step:

Check if `littles_law_analysis.csv` has:
- Clear queue measurements
- Independent arrival/departure counts
- Consistent time intervals
- Realistic values

If not, we need to either:
1. Find the right source data
2. Create it from raw event logs
3. Get clarification on field meanings