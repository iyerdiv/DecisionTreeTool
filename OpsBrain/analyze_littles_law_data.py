#!/usr/bin/env python3
"""
Analyze the CORRECT Little's Law data file
This has the proper structure with calculated queue lengths
"""

import pandas as pd
import numpy as np
from datetime import datetime
import json

print("="*80)
print("ANALYZING LITTLE'S LAW DATA - CORRECT FILE")
print("="*80)

# Load the Little's Law analysis file
df = pd.read_csv('/Volumes/workplace/DecisionTreeTool/OpsBrain/littles_law_analysis.csv')

print(f"\n✅ Loaded littles_law_analysis.csv")
print(f"   Records: {len(df)}")
print(f"   Columns: {list(df.columns)}")

# Parse datetime
df['datetime'] = pd.to_datetime(df['datetime'])

print(f"\n📊 Data Overview:")
print(f"   Time range: {df['datetime'].min()} to {df['datetime'].max()}")
print(f"   Time span: {(df['datetime'].max() - df['datetime'].min()).days} days")

# Check data quality
print(f"\n📊 Data Quality Check:")
print(f"   Null values: {df.isnull().sum().sum()}")
print(f"   Unique timestamps: {df['datetime'].nunique()}")

# Basic statistics
print(f"\n📊 Key Statistics:")
print(f"   Total inflow: {df['num_inflow_event1'].sum():,}")
print(f"   Avg arrival rate: {df['arrival_rate'].mean():.2f} packages/min")
print(f"   Avg wait time: {df['wait_time_minutes'].mean():.1f} minutes")
print(f"   Avg queue length: {df['queue_length_L'].mean():.1f} packages")

# Check bottleneck distribution
bottleneck_dist = df['bottleneck_severity'].value_counts()
print(f"\n📊 Bottleneck Distribution:")
for severity, count in bottleneck_dist.items():
    pct = count / len(df) * 100
    print(f"   {severity}: {count:,} ({pct:.1f}%)")

print("\n" + "="*80)
print("TEST 1: LITTLE'S LAW VERIFICATION")
print("="*80)

# Verify Little's Law: L = λ × W
df['L_calculated'] = df['arrival_rate'] * df['wait_time_minutes']

# Compare with provided queue_length_L
df['error'] = df['L_calculated'] - df['queue_length_L']
df['error_pct'] = np.where(df['queue_length_L'] > 0,
                           df['error'] / df['queue_length_L'] * 100,
                           0)

print(f"   Little's Law Check:")
print(f"   Mean error: {df['error'].mean():.6f}")
print(f"   Max error: {df['error'].abs().max():.6f}")
print(f"   Mean error %: {df['error_pct'].abs().mean():.4f}%")

if df['error'].abs().max() < 0.001:
    print(f"   ✅ Little's Law holds PERFECTLY (as expected - L was calculated from λ×W)")
else:
    print(f"   ⚠️ Small numerical errors detected")

print("\n" + "="*80)
print("TEST 2: SYSTEM STABILITY")
print("="*80)

# Check if system is building queue over time
df['hour'] = df['datetime'].dt.floor('h')
hourly = df.groupby('hour').agg({
    'num_inflow_event1': 'sum',
    'queue_length_L': 'mean',
    'arrival_rate': 'mean',
    'wait_time_minutes': 'mean'
}).reset_index()

# Calculate trend
if len(hourly) > 2:
    queue_trend = np.polyfit(range(len(hourly)), hourly['queue_length_L'], 1)[0]
    wait_trend = np.polyfit(range(len(hourly)), hourly['wait_time_minutes'], 1)[0]

    print(f"   Queue trend: {queue_trend:+.2f} packages/hour")
    print(f"   Wait time trend: {wait_trend:+.2f} minutes/hour")

    if abs(queue_trend) < 1:
        print(f"   ✅ System is STABLE (no significant queue growth)")
    elif queue_trend > 0:
        print(f"   ❌ System is UNSTABLE (queue growing)")
    else:
        print(f"   📉 System is clearing (queue shrinking)")

print("\n" + "="*80)
print("TEST 3: TEMPORAL PATTERNS")
print("="*80)

# Hour of day analysis
df['hour_of_day'] = df['datetime'].dt.hour
hourly_pattern = df.groupby('hour_of_day').agg({
    'queue_length_L': 'mean',
    'wait_time_minutes': 'mean',
    'arrival_rate': 'mean'
}).round(2)

print("\n📊 Hourly Patterns:")
print("   Hour | Queue | Wait(min) | Rate")
print("   -----|-------|-----------|------")
for hour in range(24):
    if hour in hourly_pattern.index:
        row = hourly_pattern.loc[hour]
        print(f"   {hour:02d}:00| {row['queue_length_L']:6.1f}| {row['wait_time_minutes']:9.1f}| {row['arrival_rate']:5.2f}")

# Find peak hours
if len(hourly_pattern) > 0:
    peak_queue_hour = hourly_pattern['queue_length_L'].idxmax()
    peak_wait_hour = hourly_pattern['wait_time_minutes'].idxmax()
    print(f"\n   Peak queue hour: {peak_queue_hour:02d}:00 ({hourly_pattern.loc[peak_queue_hour, 'queue_length_L']:.1f} packages)")
    print(f"   Peak wait hour: {peak_wait_hour:02d}:00 ({hourly_pattern.loc[peak_wait_hour, 'wait_time_minutes']:.1f} minutes)")

print("\n" + "="*80)
print("TEST 4: BOTTLENECK SEVERITY ANALYSIS")
print("="*80)

# Analyze by severity
severity_stats = df.groupby('bottleneck_severity').agg({
    'queue_length_L': ['mean', 'max'],
    'wait_time_minutes': ['mean', 'max'],
    'arrival_rate': ['mean', 'max']
}).round(2)

print("\nSeverity Statistics:")
print(severity_stats)

# Check if severity classifications make sense
severity_order = ['Normal', 'Light', 'Moderate', 'Severe', 'Critical']
severity_values = []
for sev in severity_order:
    if sev in df['bottleneck_severity'].values:
        avg_queue = df[df['bottleneck_severity'] == sev]['queue_length_L'].mean()
        severity_values.append((sev, avg_queue))

if len(severity_values) > 1:
    print("\n📊 Severity Validation:")
    for i in range(len(severity_values)-1):
        if severity_values[i][1] > severity_values[i+1][1]:
            print(f"   ❌ {severity_values[i][0]} ({severity_values[i][1]:.1f}) > {severity_values[i+1][0]} ({severity_values[i+1][1]:.1f})")
        else:
            print(f"   ✅ {severity_values[i][0]} ({severity_values[i][1]:.1f}) < {severity_values[i+1][0]} ({severity_values[i+1][1]:.1f})")

print("\n" + "="*80)
print("TEST 5: STATISTICAL PROPERTIES")
print("="*80)

# Check distributions
print("\n📊 Distribution Analysis:")

# Arrival rate distribution
arr_mean = df['arrival_rate'].mean()
arr_var = df['arrival_rate'].var()
arr_cv = df['arrival_rate'].std() / arr_mean if arr_mean > 0 else 0

print(f"   Arrival Rate:")
print(f"     Mean: {arr_mean:.3f}")
print(f"     Variance: {arr_var:.3f}")
print(f"     CV: {arr_cv:.3f}")
print(f"     Dispersion Index: {arr_var/arr_mean if arr_mean > 0 else 0:.2f}")

# Queue length distribution
queue_mean = df['queue_length_L'].mean()
queue_var = df['queue_length_L'].var()
queue_cv = df['queue_length_L'].std() / queue_mean if queue_mean > 0 else 0

print(f"   Queue Length:")
print(f"     Mean: {queue_mean:.1f}")
print(f"     Variance: {queue_var:.1f}")
print(f"     CV: {queue_cv:.3f}")

# Autocorrelation
if len(df) > 10:
    queue_autocorr = df['queue_length_L'].autocorr(1)
    wait_autocorr = df['wait_time_minutes'].autocorr(1)
    print(f"\n   Autocorrelation (lag-1):")
    print(f"     Queue: {queue_autocorr:.3f}")
    print(f"     Wait time: {wait_autocorr:.3f}")

print("\n" + "="*80)
print("FINAL ASSESSMENT")
print("="*80)

print("\n✅ Data Structure:")
print("   - Has proper timestamps")
print("   - Has arrival rates (λ)")
print("   - Has wait times (W)")
print("   - Has queue lengths (L)")
print("   - Has bottleneck classifications")

print("\n📊 Key Findings:")
print(f"   1. System processes ~{df['num_inflow_event1'].sum()/len(df)*24:.0f} packages/day")
print(f"   2. Average queue: {df['queue_length_L'].mean():.1f} packages")
print(f"   3. Average wait: {df['wait_time_minutes'].mean():.1f} minutes")
print(f"   4. {bottleneck_dist.get('Normal', 0)/len(df)*100:.1f}% of time is Normal")
print(f"   5. {bottleneck_dist.get('Critical', 0)/len(df)*100:.1f}% of time is Critical")

print("\n⚠️ Note:")
print("   This data has L calculated from λ×W (not independently measured)")
print("   So Little's Law will always appear to hold perfectly")
print("   But the data is still useful for understanding system behavior")

print("\n" + "="*80)
print("ANALYSIS COMPLETE - CORRECT DATA STRUCTURE CONFIRMED")
print("="*80)

# Save summary
summary = {
    'file': 'littles_law_analysis.csv',
    'records': len(df),
    'time_span_days': (df['datetime'].max() - df['datetime'].min()).days,
    'total_inflow': int(df['num_inflow_event1'].sum()),
    'avg_queue': float(df['queue_length_L'].mean()),
    'avg_wait_minutes': float(df['wait_time_minutes'].mean()),
    'bottleneck_distribution': bottleneck_dist.to_dict(),
    'data_structure': 'CORRECT - has all needed fields'
}

with open('/Volumes/workplace/DecisionTreeTool/OpsBrain/littles_law_data_summary.json', 'w') as f:
    json.dump(summary, f, indent=2)

print("\n💾 Summary saved to littles_law_data_summary.json")