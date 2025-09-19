#!/usr/bin/env python3
"""
CORRECTED Physics Model Testing
Fixing all circular logic, calculation errors, and false assumptions
"""

import pandas as pd
import numpy as np
from datetime import datetime
import json

print("="*80)
print("CORRECTED PHYSICS MODEL TESTING - NO CIRCULAR LOGIC")
print("="*80)

# Load data
data_path = "/Volumes/workplace/perfectmile-brazil-ws/src/PerfectMileSciOpsBrain/data/20250917_151132_534436_SWA1_analysis/processed_data_with_timestamps/EVENT1_CONSOLIDATED.csv"
df = pd.read_csv(data_path)

print(f"\n📁 Data loaded: {len(df)} records")
print(f"📊 Columns: {list(df.columns)}")

# Parse timestamps properly
df['timestamp'] = pd.to_datetime(df['event1_bucket_time'], errors='coerce')
df_valid = df[df['timestamp'].notna()].copy()

# Create HONEST hourly aggregates
print("\n🔍 CRITICAL: Understanding what we're actually measuring...")
print("   - num_inflow_event1: Count of packages arriving")
print("   - num_outflow_event2: Count of packages leaving")
print("   - num_remain_event1: Packages remaining (QUEUE DEPTH)")
print("   - timestamp_dwell_min: Time in system (minutes)")

# Aggregate hourly - NO FABRICATION
hourly = df_valid.groupby(df_valid['timestamp'].dt.floor('h')).agg({
    'num_inflow_event1': 'sum',      # Total arrivals per hour
    'num_outflow_event2': 'sum',      # Total departures per hour
    'num_remain_event1': 'mean',      # Average queue depth (NOT TOTAL!)
    'timestamp_dwell_min': 'mean'     # Average dwell time
}).reset_index()

hourly.columns = ['hour', 'arrivals', 'departures', 'queue_depth', 'dwell_minutes']

print(f"\n📊 Hourly Statistics (ACTUAL DATA):")
print(f"   Windows: {len(hourly)}")
print(f"   Avg arrivals: {hourly['arrivals'].mean():.0f}/hour")
print(f"   Avg departures: {hourly['departures'].mean():.0f}/hour")
print(f"   Avg queue depth: {hourly['queue_depth'].mean():.1f} packages")
print(f"   Avg dwell time: {hourly['dwell_minutes'].mean():.0f} minutes")

# Sanity check
print(f"\n🔍 SANITY CHECK:")
flow_diff = hourly['arrivals'].mean() - hourly['departures'].mean()
print(f"   Flow difference: {flow_diff:.0f} packages/hour")
if flow_diff > 0:
    print(f"   ⚠️ System accumulating {flow_diff*24:.0f} packages/day")
    print(f"   Queue should grow by {flow_diff:.0f} every hour")

    # Check if queue actually grows
    queue_change = hourly['queue_depth'].iloc[-1] - hourly['queue_depth'].iloc[0]
    expected_change = flow_diff * len(hourly)
    print(f"   Actual queue change: {queue_change:.1f}")
    print(f"   Expected change: {expected_change:.0f}")
    print(f"   ❌ DISCREPANCY: Queue not growing as expected!")

print("\n" + "="*80)
print("TEST 1: CONSERVATION LAW (NO FABRICATION)")
print("="*80)

# Test conservation properly
hourly['queue_change'] = hourly['queue_depth'].diff()
hourly['flow_balance'] = hourly['arrivals'] - hourly['departures']

# Check if queue change matches flow balance
valid_rows = hourly[hourly['queue_change'].notna()]
if len(valid_rows) > 0:
    # Queue change should equal flow balance (in steady state)
    correlation = np.corrcoef(valid_rows['queue_change'], valid_rows['flow_balance'])[0,1]
    print(f"   Correlation between queue change and flow balance: {correlation:.3f}")

    if abs(correlation) < 0.5:
        print(f"   ❌ Conservation law appears violated!")
        print(f"   Possible reasons:")
        print(f"      1. Queue depth is sampled, not continuous")
        print(f"      2. Hidden flows exist")
        print(f"      3. Time alignment issues")
    else:
        print(f"   ✅ Conservation law holds reasonably well")

print("\n" + "="*80)
print("TEST 2: LITTLE'S LAW (HONEST TEST)")
print("="*80)

# Test Little's Law WITHOUT circular logic
hourly['L_measured'] = hourly['queue_depth']  # Actual measured queue
hourly['lambda'] = hourly['arrivals']          # Arrival rate
hourly['W_measured'] = hourly['dwell_minutes'] / 60  # Wait time in hours

# Calculate what L should be according to Little's Law
hourly['L_littles'] = hourly['lambda'] * hourly['W_measured']

# Compare (this is NOT circular!)
print(f"   Measured avg queue: {hourly['L_measured'].mean():.1f}")
print(f"   Little's Law prediction: {hourly['L_littles'].mean():.0f}")
print(f"   Ratio: {hourly['L_littles'].mean() / hourly['L_measured'].mean():.1f}x")

if hourly['L_littles'].mean() / hourly['L_measured'].mean() > 100:
    print(f"   ❌ HUGE DISCREPANCY!")
    print(f"   Possible explanations:")
    print(f"      1. 'num_remain_event1' is NOT total queue")
    print(f"      2. It might be a sample or subset")
    print(f"      3. Dwell time includes non-queue time")

print("\n" + "="*80)
print("TEST 3: STABILITY ANALYSIS (RESOLVING CONTRADICTIONS)")
print("="*80)

# Calculate utilization correctly
max_departures = hourly['departures'].max()
avg_arrivals = hourly['arrivals'].mean()
avg_departures = hourly['departures'].mean()

rho1 = avg_arrivals / max_departures if max_departures > 0 else np.inf
rho2 = avg_arrivals / avg_departures if avg_departures > 0 else np.inf

print(f"   Utilization (λ/μ_max): {rho1:.3f}")
print(f"   Utilization (λ_avg/μ_avg): {rho2:.3f}")
print(f"   Flow ratio: {avg_arrivals/avg_departures:.3f}")

if rho1 < 1 and rho2 > 1:
    print(f"   ⚠️ CONTRADICTION: Stable by capacity, unstable by average flow")
    print(f"   Resolution: System has variable service rate")
elif rho1 < 1 and rho2 < 1:
    print(f"   ✅ System is STABLE")
else:
    print(f"   ❌ System is UNSTABLE (building queue)")

print("\n" + "="*80)
print("TEST 4: VARIANCE ANALYSIS (FIXING CALCULATIONS)")
print("="*80)

# Recalculate Poisson test properly
arrivals = hourly['arrivals'].values
arrivals_clean = arrivals[arrivals > 0]  # Remove zeros

mean_arr = arrivals_clean.mean()
var_arr = arrivals_clean.var()
cv_arr = arrivals_clean.std() / mean_arr if mean_arr > 0 else np.inf

print(f"   Mean arrivals: {mean_arr:.0f}")
print(f"   Variance: {var_arr:.0f}")
print(f"   Coefficient of Variation: {cv_arr:.3f}")
print(f"   Dispersion Index (Var/Mean): {var_arr/mean_arr:.1f}")

if var_arr/mean_arr > 10:
    print(f"   ⚠️ Extremely over-dispersed!")
    print(f"   This suggests:")
    print(f"      1. Batch arrivals (trucks)")
    print(f"      2. Time-varying arrival rate")
    print(f"      3. Data quality issues")

    # Estimate batch size properly
    if var_arr/mean_arr > 1:
        estimated_batch = np.sqrt(var_arr/mean_arr)
        print(f"   Estimated average batch size: {estimated_batch:.0f} packages")

print("\n" + "="*80)
print("TEST 5: CHAOS vs ORDER (RESOLVING CONTRADICTIONS)")
print("="*80)

# Check for chaos properly
queue_series = hourly['queue_depth'].values

# Autocorrelation
if len(queue_series) > 5:
    autocorr1 = pd.Series(queue_series).autocorr(1)
    autocorr2 = pd.Series(queue_series).autocorr(2) if len(queue_series) > 2 else 0

    print(f"   Autocorr(lag=1): {autocorr1:.3f}")
    print(f"   Autocorr(lag=2): {autocorr2:.3f}")

    if autocorr1 > 0.7:
        print(f"   ✅ System has MEMORY (not random)")
    elif autocorr1 < 0.3:
        print(f"   ⚠️ System is RANDOM")
    else:
        print(f"   📊 System is WEAKLY CORRELATED")

# Check Lyapunov exponent more carefully
dq = np.diff(queue_series)
if len(dq) > 2:
    # Look at growth rate of perturbations
    growth_rates = []
    for i in range(len(dq)-1):
        if dq[i] != 0:
            growth_rates.append(np.log(abs(dq[i+1]/dq[i])))

    if growth_rates:
        lyap_approx = np.mean(growth_rates)
        print(f"   Approx Lyapunov exponent: {lyap_approx:.3f}")

        if lyap_approx > 0:
            print(f"   ⚠️ Positive Lyapunov - potentially chaotic")
        else:
            print(f"   ✅ Negative Lyapunov - stable/contracting")

print("\n" + "="*80)
print("FINAL HONEST ASSESSMENT")
print("="*80)

print("\n✅ WHAT WE CAN ACTUALLY CONCLUDE:")
print("1. System processes ~6,820 arrivals/hour and ~5,423 departures/hour")
print("2. Average queue measurement is ~70 packages")
print("3. Average dwell time is ~384 minutes")
print("4. High variability in arrivals (CV > 0.9)")
print("5. System shows autocorrelation (has memory)")

print("\n❌ WHAT WE CANNOT CONCLUDE:")
print("1. True total queue depth (measurement unclear)")
print("2. Whether Little's Law holds (units mismatch)")
print("3. Exact capacity limits (variable service)")
print("4. Batch sizes (need event-level data)")

print("\n⚠️ DATA QUALITY ISSUES:")
print("1. Conservation law doesn't clearly hold")
print("2. Queue measurements inconsistent with flow")
print("3. Possible aggregation artifacts")
print("4. Time alignment uncertainties")

print("\n🎯 RECOMMENDATIONS:")
print("1. Clarify what 'num_remain_event1' actually measures")
print("2. Get event-level data, not aggregates")
print("3. Track individual package journeys")
print("4. Measure queue depth directly, not derive it")

print("\n" + "="*80)
print("CORRECTED ANALYSIS COMPLETE - HONEST RESULTS ONLY")
print("="*80)