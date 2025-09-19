#!/usr/bin/env python3
"""
Physics Analysis using the CORRECT file: EVENT1_FLOW_COMPARISON.csv
This has pre-aggregated flow data with actual package counts
"""

import pandas as pd
import numpy as np
from datetime import datetime

print("="*80)
print("PHYSICS ANALYSIS - USING CORRECT FLOW_COMPARISON FILE")
print("="*80)

# Use the CORRECT file this time!
data_path = "/Volumes/workplace/perfectmile-brazil-ws/src/PerfectMileSciOpsBrain/data/20250917_151132_534436_SWA1_analysis/processed_data_with_timestamps/EVENT1_FLOW_COMPARISON.csv"

df = pd.read_csv(data_path)

print(f"\n📁 Loaded EVENT1_FLOW_COMPARISON.csv")
print(f"   Records: {len(df)}")
print(f"   Columns: {list(df.columns)}")

# Parse timestamps
df['timestamp'] = pd.to_datetime(df['readable_time'], errors='coerce')

print(f"\n📊 Data Overview:")
print(f"   Time range: {df['timestamp'].min()} to {df['timestamp'].max()}")
print(f"   Time buckets: {len(df)}")

# Check time bucket spacing
df = df.sort_values('timestamp')
df['time_diff'] = df['timestamp'].diff()
median_diff = df['time_diff'].median()
print(f"   Median time between buckets: {median_diff}")

print(f"\n📊 Key Statistics:")
print(f"   Total inflow: {df['num_inflow_event1'].sum():,}")
print(f"   Total outflow: {df['num_outflow_event2'].sum():,}")
print(f"   Total actual packages: {df['actual_package_count'].sum():,}")
print(f"   Avg dwell: {df['avg_dwell'].mean():.1f} minutes")
print(f"   Median dwell: {df['median_dwell'].median():.1f} minutes")

# CRITICAL: Compare num_remain with actual_package_count
print(f"\n🔍 CRITICAL CHECK: num_remain vs actual_package_count")
print(f"   Sum of num_remain: {df['num_remain_event1'].sum():,}")
print(f"   Sum of actual_package_count: {df['actual_package_count'].sum():,}")
print(f"   Are they the same? {df['num_remain_event1'].sum() == df['actual_package_count'].sum()}")

# Check if they differ row by row
df['count_diff'] = df['actual_package_count'] - df['num_remain_event1']
if df['count_diff'].abs().sum() > 0:
    print(f"   ⚠️ They differ in {(df['count_diff'] != 0).sum()} rows")
    print(f"   Max difference: {df['count_diff'].abs().max()}")

print("\n" + "="*80)
print("FLOW CONSERVATION TEST")
print("="*80)

# Test conservation with this data
total_in = df['num_inflow_event1'].sum()
total_out = df['num_outflow_event2'].sum()
net_accumulation = total_in - total_out

print(f"   Total IN: {total_in:,}")
print(f"   Total OUT: {total_out:,}")
print(f"   Net accumulation: {net_accumulation:,}")

# Check if accumulation matches remaining
total_remaining = df['num_remain_event1'].iloc[-1] - df['num_remain_event1'].iloc[0]
print(f"   Change in remaining: {total_remaining}")
print(f"   Conservation check: {net_accumulation} should equal {total_remaining}")

if abs(net_accumulation - total_remaining) < 100:
    print(f"   ✅ Conservation holds!")
else:
    print(f"   ❌ Conservation violated by {abs(net_accumulation - total_remaining):,} packages")

print("\n" + "="*80)
print("LITTLE'S LAW TEST")
print("="*80)

# Calculate Little's Law with ACTUAL package counts
df['L'] = df['actual_package_count']  # Use actual count!
df['lambda'] = df['num_inflow_event1'] / 5  # Per minute (assuming 5-min buckets)
df['W'] = df['avg_dwell']  # Already in minutes

# Check Little's Law
df['L_predicted'] = df['lambda'] * df['W']

print(f"   Average L (actual): {df['L'].mean():.1f}")
print(f"   Average L (Little's Law): {df['L_predicted'].mean():.1f}")
print(f"   Ratio: {df['L_predicted'].mean() / df['L'].mean() if df['L'].mean() > 0 else 0:.2f}x")

# Check correlation
mask = (df['L'] > 0) & (df['L_predicted'] > 0)
if mask.sum() > 10:
    correlation = np.corrcoef(df.loc[mask, 'L'], df.loc[mask, 'L_predicted'])[0,1]
    print(f"   Correlation: {correlation:.3f}")

print("\n" + "="*80)
print("HOURLY PATTERN ANALYSIS")
print("="*80)

# Aggregate to hourly for pattern analysis
df['hour'] = df['timestamp'].dt.floor('h')
hourly = df.groupby('hour').agg({
    'num_inflow_event1': 'sum',
    'num_outflow_event2': 'sum',
    'actual_package_count': 'mean',
    'avg_dwell': 'mean'
}).reset_index()

print(f"\n📊 Hourly Aggregation ({len(hourly)} hours):")
print(f"   Avg inflow: {hourly['num_inflow_event1'].mean():.0f}/hour")
print(f"   Avg outflow: {hourly['num_outflow_event2'].mean():.0f}/hour")
print(f"   Avg packages in system: {hourly['actual_package_count'].mean():.0f}")

# Peak analysis
hourly['hour_of_day'] = hourly['hour'].dt.hour
peak_hours = hourly.groupby('hour_of_day').agg({
    'num_inflow_event1': 'mean',
    'num_outflow_event2': 'mean',
    'actual_package_count': 'mean'
}).round(0)

print("\n📊 Peak Hour Analysis:")
max_inflow_hour = peak_hours['num_inflow_event1'].idxmax()
max_outflow_hour = peak_hours['num_outflow_event2'].idxmax()
print(f"   Peak inflow hour: {max_inflow_hour:02d}:00 ({peak_hours.loc[max_inflow_hour, 'num_inflow_event1']:.0f} packages)")
print(f"   Peak outflow hour: {max_outflow_hour:02d}:00 ({peak_hours.loc[max_outflow_hour, 'num_outflow_event2']:.0f} packages)")

print("\n" + "="*80)
print("STABILITY ANALYSIS")
print("="*80)

# Check system stability
avg_lambda_in = hourly['num_inflow_event1'].mean()
avg_lambda_out = hourly['num_outflow_event2'].mean()
max_lambda_out = hourly['num_outflow_event2'].max()

utilization = avg_lambda_in / max_lambda_out if max_lambda_out > 0 else np.inf
flow_ratio = avg_lambda_in / avg_lambda_out if avg_lambda_out > 0 else np.inf

print(f"   Utilization (λ/μ_max): {utilization:.3f}")
print(f"   Flow ratio (λ_in/λ_out): {flow_ratio:.3f}")

if flow_ratio > 1:
    print(f"   ❌ UNSTABLE: Building queue at {(flow_ratio-1)*avg_lambda_in:.0f} packages/hour")
elif flow_ratio < 0.95:
    print(f"   ✅ STABLE: System clearing faster than arriving")
else:
    print(f"   ⚠️ MARGINAL: System near equilibrium")

# Check variability
cv_in = hourly['num_inflow_event1'].std() / hourly['num_inflow_event1'].mean()
cv_out = hourly['num_outflow_event2'].std() / hourly['num_outflow_event2'].mean()

print(f"\n   Inflow CV: {cv_in:.3f}")
print(f"   Outflow CV: {cv_out:.3f}")

if cv_in > 1 or cv_out > 1:
    print(f"   ⚠️ High variability detected")

print("\n" + "="*80)
print("KEY FINDINGS FROM CORRECT DATA FILE")
print("="*80)

print("\n✅ What we learned from FLOW_COMPARISON:")
print(f"1. Data has {len(df)} time buckets (~{median_diff.total_seconds()/60:.1f} min intervals)")
print(f"2. Total flow: {total_in:,} IN, {total_out:,} OUT")
print(f"3. Net accumulation: {net_accumulation:,} packages")
print(f"4. Average dwell: {df['avg_dwell'].mean():.1f} minutes")
print(f"5. System utilization: {utilization:.1%}")

print("\n📊 Big difference from CONSOLIDATED file:")
print("- This file has pre-aggregated flows")
print("- Has 'actual_package_count' field")
print("- Time buckets are regular")
print("- Better for physics modeling")

print("\n" + "="*80)
print("ANALYSIS COMPLETE - USING CORRECT FILE")
print("="*80)