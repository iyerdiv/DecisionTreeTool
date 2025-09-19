#!/usr/bin/env python3
"""
Physics Model Testing on EVENT1 Data - Final Version with Complete Logic Checks
NO assumptions without evidence, NO hallucinations, complete verification
"""

import pandas as pd
import numpy as np
from datetime import datetime
import json

print("="*80)
print("COMPREHENSIVE PHYSICS MODEL TESTING - EVENT1 DATA")
print("WITH COMPLETE LOGIC VERIFICATION")
print("="*80)

# ============= RESULTS TRACKING WITH EVIDENCE =============
results_summary = []

def log_result(model_name, metric, value, status, evidence, logic_check):
    """Log results with complete evidence trail"""
    results_summary.append({
        'Model': model_name,
        'Metric': metric,
        'Value': value,
        'Status': status,
        'Evidence': evidence,
        'Logic_Check': logic_check
    })
    print(f"   📊 {model_name}: {metric}={value} [{status}]")
    print(f"      Evidence: {evidence}")
    print(f"      Logic: {logic_check}")

# ============= LOAD DATA WITH VERIFICATION =============
print("\n" + "="*80)
print("STEP 1: DATA LOADING AND VERIFICATION")
print("="*80)

data_path = "/Volumes/workplace/perfectmile-brazil-ws/src/PerfectMileSciOpsBrain/data/20250917_151132_534436_SWA1_analysis/processed_data_with_timestamps/EVENT1_CONSOLIDATED.csv"

df = pd.read_csv(data_path)

print(f"\n✅ Loaded {len(df)} records from EVENT1_CONSOLIDATED.csv")
print(f"📊 Data columns: {list(df.columns)}")

# Verify data structure - NO ASSUMPTIONS
print("\n🔍 DATA STRUCTURE VERIFICATION:")
print(f"   Total records: {len(df)}")
print(f"   Columns with 'time': {[col for col in df.columns if 'time' in col.lower()]}")
print(f"   Columns with 'flow': {[col for col in df.columns if 'flow' in col.lower()]}")
print(f"   Columns with 'num': {[col for col in df.columns if 'num' in col.lower()]}")

# ============= PREPARE TIME SERIES FROM ACTUAL DATA =============
print("\n" + "="*80)
print("STEP 2: TIME SERIES CONSTRUCTION FROM EVENT DATA")
print("="*80)

# Parse time columns - using actual column names
df['event1_arrival_parsed'] = pd.to_datetime(df['event1_arrival_time'], errors='coerce')
df['event1_bucket_parsed'] = pd.to_datetime(df['event1_bucket_time'], errors='coerce')

# Count valid timestamps
valid_arrivals = df['event1_arrival_parsed'].notna().sum()
valid_buckets = df['event1_bucket_parsed'].notna().sum()

print(f"\n📊 Time Data Quality Check:")
print(f"   Valid arrival times: {valid_arrivals}/{len(df)} ({valid_arrivals/len(df)*100:.1f}%)")
print(f"   Valid bucket times: {valid_buckets}/{len(df)} ({valid_buckets/len(df)*100:.1f}%)")

# Use bucket time as primary timestamp (it has more valid entries)
df['timestamp'] = df['event1_bucket_parsed']

# Filter to valid timestamps only
df_valid = df[df['timestamp'].notna()].copy()
print(f"   Working with {len(df_valid)} records with valid timestamps")

# Create time-based aggregations
df_valid['hour'] = df_valid['timestamp'].dt.floor('H')
df_valid['minute_5'] = df_valid['timestamp'].dt.floor('5min')

# ============= CALCULATE PHYSICS QUANTITIES FROM DATA =============
print("\n" + "="*80)
print("STEP 3: PHYSICS QUANTITIES CALCULATION")
print("="*80)

# Aggregate by time buckets - using ACTUAL data columns
hourly_stats = df_valid.groupby('hour').agg({
    'num_inflow_event1': 'sum',     # Total inflow per hour
    'num_outflow_event2': 'sum',     # Total outflow per hour
    'num_remain_event1': 'mean',     # Average remaining (queue depth)
    'timestamp_dwell_min': 'mean',   # Average dwell time
    'id': 'count'                     # Number of packages
}).reset_index()

hourly_stats.columns = ['hour', 'inflow', 'outflow', 'queue_depth', 'dwell_time', 'package_count']

print(f"\n📊 Hourly Statistics Summary:")
print(f"   Time windows: {len(hourly_stats)}")
print(f"   Avg inflow: {hourly_stats['inflow'].mean():.2f} packages/hour")
print(f"   Avg outflow: {hourly_stats['outflow'].mean():.2f} packages/hour")
print(f"   Avg queue depth: {hourly_stats['queue_depth'].mean():.2f} packages")
print(f"   Avg dwell time: {hourly_stats['dwell_time'].mean():.2f} minutes")

# ============= MODEL 1: CONSERVATION LAW =============
print("\n" + "="*80)
print("MODEL 1: CONSERVATION LAW (Mass Balance)")
print("="*80)
print("Theory: Queue[t+1] = Queue[t] + Inflow[t] - Outflow[t]")

# Apply conservation law
hourly_stats['queue_change'] = hourly_stats['inflow'] - hourly_stats['outflow']
hourly_stats['queue_predicted'] = hourly_stats['queue_depth'].iloc[0] + hourly_stats['queue_change'].cumsum()

# Calculate accuracy
valid_mask = ~hourly_stats['queue_predicted'].isna()
if valid_mask.sum() > 2:
    correlation = np.corrcoef(hourly_stats.loc[valid_mask, 'queue_predicted'],
                              hourly_stats.loc[valid_mask, 'queue_depth'])[0, 1]
    r2 = correlation ** 2
    mae = np.abs(hourly_stats.loc[valid_mask, 'queue_predicted'] -
                 hourly_stats.loc[valid_mask, 'queue_depth']).mean()

    log_result("Conservation Law", "R²", f"{r2:.4f}",
               "SUCCESS" if r2 > 0.7 else "MODERATE" if r2 > 0.4 else "FAILED",
               f"Based on {valid_mask.sum()} hourly windows",
               "Mass balance should hold for any queue system")
else:
    log_result("Conservation Law", "R²", "N/A", "INSUFFICIENT DATA",
               f"Only {valid_mask.sum()} valid points",
               "Need at least 3 time points")

# ============= MODEL 2: LITTLE'S LAW =============
print("\n" + "="*80)
print("MODEL 2: LITTLE'S LAW VERIFICATION")
print("="*80)
print("Theory: L = λW (Queue Length = Arrival Rate × Wait Time)")

# We have actual dwell times! Use them instead of calculating
hourly_stats['L_measured'] = hourly_stats['queue_depth']
hourly_stats['lambda_measured'] = hourly_stats['inflow']
hourly_stats['W_measured'] = hourly_stats['dwell_time'] / 60  # Convert minutes to hours

# Calculate Little's Law prediction
hourly_stats['L_littles'] = hourly_stats['lambda_measured'] * hourly_stats['W_measured']

# Check validity
valid_mask = (hourly_stats['L_measured'] > 0) & (hourly_stats['lambda_measured'] > 0)
if valid_mask.sum() > 0:
    # Calculate error
    errors = np.abs(hourly_stats.loc[valid_mask, 'L_measured'] -
                    hourly_stats.loc[valid_mask, 'L_littles'])
    relative_error = (errors / hourly_stats.loc[valid_mask, 'L_measured']).mean() * 100

    log_result("Little's Law", "Error", f"{relative_error:.1f}%",
               "SUCCESS" if relative_error < 20 else "MODERATE" if relative_error < 50 else "FAILED",
               f"Using actual measured dwell times from data",
               "This is NOT circular - using independent measurements")
else:
    log_result("Little's Law", "Error", "N/A", "INSUFFICIENT DATA",
               "No valid queue measurements",
               "Cannot verify without data")

# ============= MODEL 3: FLOW STABILITY =============
print("\n" + "="*80)
print("MODEL 3: FLOW STABILITY ANALYSIS")
print("="*80)
print("Theory: System stable when ρ = λ/μ < 1")

# Calculate utilization
max_outflow = hourly_stats['outflow'].max()
if max_outflow > 0:
    hourly_stats['utilization'] = hourly_stats['inflow'] / max_outflow
    avg_utilization = hourly_stats['utilization'].mean()
    unstable_hours = (hourly_stats['utilization'] >= 1).sum()

    log_result("Flow Stability", "Avg Utilization", f"{avg_utilization:.3f}",
               "STABLE" if avg_utilization < 0.8 else "CRITICAL" if avg_utilization > 1 else "MODERATE",
               f"Max capacity = {max_outflow}, Unstable {unstable_hours}/{len(hourly_stats)} hours",
               "ρ < 1 required for stability (queue theory)")
else:
    log_result("Flow Stability", "Utilization", "N/A", "NO OUTFLOW",
               "Zero outflow observed",
               "Cannot calculate utilization")

# ============= MODEL 4: POISSON ARRIVALS TEST =============
print("\n" + "="*80)
print("MODEL 4: POISSON ARRIVAL PROCESS")
print("="*80)
print("Theory: For Poisson process, Variance = Mean")

inflows = hourly_stats['inflow'].values
if len(inflows) > 2:
    mean_inflow = inflows.mean()
    var_inflow = inflows.var()

    if mean_inflow > 0:
        dispersion_index = var_inflow / mean_inflow

        log_result("Poisson Process", "Dispersion Index", f"{dispersion_index:.3f}",
                   "POISSON" if abs(dispersion_index - 1) < 0.5 else "NOT POISSON",
                   f"Mean={mean_inflow:.2f}, Var={var_inflow:.2f}",
                   "Index ≈ 1 indicates Poisson distribution")
    else:
        log_result("Poisson Process", "Dispersion Index", "N/A", "ZERO MEAN",
                   "Mean inflow is zero",
                   "Cannot test with zero arrivals")
else:
    log_result("Poisson Process", "Dispersion Index", "N/A", "INSUFFICIENT DATA",
               f"Only {len(inflows)} data points",
               "Need more data for statistical test")

# ============= MODEL 5: QUEUE DYNAMICS =============
print("\n" + "="*80)
print("MODEL 5: QUEUE DYNAMICS (Sensitivity)")
print("="*80)
print("Theory: Measure dQ/dλ (queue response to arrival changes)")

# Calculate sensitivities
hourly_stats['inflow_change'] = hourly_stats['inflow'].diff()
hourly_stats['queue_depth_change'] = hourly_stats['queue_depth'].diff()

valid_changes = hourly_stats[hourly_stats['inflow_change'].notna() &
                             (hourly_stats['inflow_change'] != 0)]

if len(valid_changes) > 2:
    # Calculate sensitivity coefficient
    if valid_changes['inflow_change'].var() > 0:
        sensitivity = (valid_changes['queue_depth_change'].cov(valid_changes['inflow_change']) /
                      valid_changes['inflow_change'].var())

        log_result("Queue Sensitivity", "dQ/dλ", f"{sensitivity:.3f}",
                   "LOW" if abs(sensitivity) < 1 else "HIGH" if abs(sensitivity) > 5 else "MODERATE",
                   f"Based on {len(valid_changes)} change measurements",
                   "Measures system responsiveness to arrival variations")
    else:
        log_result("Queue Sensitivity", "dQ/dλ", "N/A", "NO VARIATION",
                   "Inflow changes have zero variance",
                   "Cannot measure sensitivity without variation")
else:
    log_result("Queue Sensitivity", "dQ/dλ", "N/A", "INSUFFICIENT DATA",
               f"Only {len(valid_changes)} valid change points",
               "Need more data for sensitivity analysis")

# ============= MODEL 6: CHAOS ANALYSIS =============
print("\n" + "="*80)
print("MODEL 6: CHAOS/PREDICTABILITY ANALYSIS")
print("="*80)
print("Theory: Check for chaotic behavior via variability metrics")

# Calculate coefficient of variation
queue_cv = (hourly_stats['queue_depth'].std() /
           hourly_stats['queue_depth'].mean() if hourly_stats['queue_depth'].mean() > 0 else np.inf)

inflow_cv = (hourly_stats['inflow'].std() /
            hourly_stats['inflow'].mean() if hourly_stats['inflow'].mean() > 0 else np.inf)

# Check autocorrelation (persistence of patterns)
if len(hourly_stats) > 5:
    queue_series = hourly_stats['queue_depth'].values
    autocorr_lag1 = pd.Series(queue_series).autocorr(1)

    log_result("Chaos Analysis", "Queue CV", f"{queue_cv:.3f}",
               "ORDERED" if queue_cv < 0.5 else "CHAOTIC" if queue_cv > 1 else "EDGE OF CHAOS",
               f"Autocorr(1)={autocorr_lag1:.3f}, Inflow CV={inflow_cv:.3f}",
               "High CV and low autocorr indicate chaos")
else:
    log_result("Chaos Analysis", "Queue CV", f"{queue_cv:.3f}",
               "INSUFFICIENT DATA",
               f"Only {len(hourly_stats)} time points",
               "Need longer time series for chaos detection")

# ============= MODEL 7: M/M/1 QUEUE MODEL =============
print("\n" + "="*80)
print("MODEL 7: M/M/1 QUEUE MODEL")
print("="*80)
print("Theory: L = ρ/(1-ρ) where ρ = λ/μ")

if max_outflow > 0:
    # Calculate theoretical M/M/1 queue lengths
    hourly_stats['rho'] = hourly_stats['inflow'] / max_outflow
    hourly_stats['L_mm1'] = hourly_stats['rho'] / (1 - hourly_stats['rho'])

    # Only consider stable regime (ρ < 1)
    stable_mask = hourly_stats['rho'] < 0.95

    if stable_mask.sum() > 0:
        # Scale theoretical values to match data magnitude
        scale = (hourly_stats.loc[stable_mask, 'queue_depth'].mean() /
                hourly_stats.loc[stable_mask, 'L_mm1'].mean() if hourly_stats.loc[stable_mask, 'L_mm1'].mean() > 0 else 1)

        hourly_stats['L_mm1_scaled'] = hourly_stats['L_mm1'] * scale

        # Calculate fit
        correlation = np.corrcoef(hourly_stats.loc[stable_mask, 'queue_depth'],
                                 hourly_stats.loc[stable_mask, 'L_mm1_scaled'])[0, 1]
        r2 = correlation ** 2

        log_result("M/M/1 Queue", "R²", f"{r2:.4f}",
                   "GOOD FIT" if r2 > 0.6 else "POOR FIT",
                   f"Based on {stable_mask.sum()} stable periods (ρ<0.95)",
                   "Assumes exponential service and Poisson arrivals")
    else:
        log_result("M/M/1 Queue", "R²", "N/A", "ALWAYS UNSTABLE",
                   "System always above capacity (ρ≥1)",
                   "M/M/1 undefined for ρ≥1")
else:
    log_result("M/M/1 Queue", "R²", "N/A", "NO CAPACITY",
               "Zero max outflow",
               "Cannot apply M/M/1 model")

# ============= FINAL SUMMARY =============
print("\n" + "="*80)
print("FINAL SUMMARY - ALL MODELS TESTED WITH COMPLETE VERIFICATION")
print("="*80)

# Create summary DataFrame
summary_df = pd.DataFrame(results_summary)

print("\n📊 MODELS TESTED:", len(summary_df))
print("\n✅ STATUS DISTRIBUTION:")
status_counts = summary_df['Status'].value_counts()
for status, count in status_counts.items():
    print(f"   {status}: {count}")

print("\n🔍 KEY FINDINGS:")
print("1. Data Quality:")
print(f"   - Valid timestamps: {valid_buckets}/{len(df)} records")
print(f"   - Time windows analyzed: {len(hourly_stats)} hours")

print("\n2. System Characteristics:")
print(f"   - Avg queue depth: {hourly_stats['queue_depth'].mean():.2f}")
print(f"   - Avg dwell time: {hourly_stats['dwell_time'].mean():.2f} minutes")
print(f"   - Flow balance: Inflow={hourly_stats['inflow'].mean():.2f}, Outflow={hourly_stats['outflow'].mean():.2f}")

print("\n3. Physics Validation:")
for _, row in summary_df.iterrows():
    if row['Status'] not in ['INSUFFICIENT DATA', 'N/A']:
        print(f"   • {row['Model']}: {row['Status']}")

# Save comprehensive results
output_path = '/Volumes/workplace/DecisionTreeTool/OpsBrain/physics_models_event1_verified.json'

final_report = {
    'timestamp': datetime.now().isoformat(),
    'data_source': 'EVENT1_CONSOLIDATED.csv',
    'data_stats': {
        'total_records': len(df),
        'valid_timestamps': int(valid_buckets),
        'time_windows': len(hourly_stats),
        'time_range': {
            'start': str(hourly_stats['hour'].min()),
            'end': str(hourly_stats['hour'].max())
        }
    },
    'system_metrics': {
        'avg_inflow': float(hourly_stats['inflow'].mean()),
        'avg_outflow': float(hourly_stats['outflow'].mean()),
        'avg_queue': float(hourly_stats['queue_depth'].mean()),
        'avg_dwell_minutes': float(hourly_stats['dwell_time'].mean())
    },
    'models_tested': summary_df.to_dict('records'),
    'verification_notes': [
        "All calculations based on actual data - no synthetic values",
        "Little's Law tested with independent measurements - not circular",
        "Conservation law applied to measured inflows/outflows",
        "Statistical tests require minimum data points for validity"
    ]
}

with open(output_path, 'w') as f:
    json.dump(final_report, f, indent=2)

summary_df.to_csv('/Volumes/workplace/DecisionTreeTool/OpsBrain/physics_models_event1_summary.csv', index=False)

print(f"\n✅ Results saved to:")
print(f"   - physics_models_event1_verified.json")
print(f"   - physics_models_event1_summary.csv")

print("\n" + "="*80)
print("PHYSICS MODEL TESTING COMPLETE - ALL EVIDENCE DOCUMENTED")
print("="*80)