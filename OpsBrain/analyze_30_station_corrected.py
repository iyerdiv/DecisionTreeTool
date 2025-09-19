#!/usr/bin/env python3
"""
Corrected 30 Station Sensitivity Analysis
Fixed wait time calculations using throughput instead of arrivals
"""

import pandas as pd
import numpy as np
from datetime import datetime
import warnings
warnings.filterwarnings('ignore')

def load_queue_data(file_path):
    """Load the real 30 station queue data"""
    df = pd.read_csv(file_path)
    df['timestamp'] = pd.to_datetime(df['timestamp'])
    df['hour'] = df['timestamp'].dt.hour
    df['date'] = df['timestamp'].dt.date
    return df

def calculate_littles_law_corrected(df):
    """Apply Little's Law calculations with CORRECTED formulas"""

    # Calculate total queue depth (in packages)
    df['total_queue'] = df['loading_queue'] + df['sorting_queue'] + df['dispatch_queue']

    # Calculate total throughput (packages per hour)
    df['total_throughput'] = df['loading_throughput'] + df['sorting_throughput'] + df['dispatch_throughput']

    # CORRECTED: Calculate wait times using throughput (Little's Law: W = L/μ where μ is service rate)
    # Wait time in MINUTES (assuming throughput is packages/hour, convert to minutes)
    df['loading_wait_min'] = np.where(df['loading_throughput'] > 0,
                                       (df['loading_queue'] / df['loading_throughput']) * 60,
                                       np.nan)

    df['sorting_wait_min'] = np.where(df['sorting_throughput'] > 0,
                                       (df['sorting_queue'] / df['sorting_throughput']) * 60,
                                       np.nan)

    df['dispatch_wait_min'] = np.where(df['dispatch_throughput'] > 0,
                                        (df['dispatch_queue'] / df['dispatch_throughput']) * 60,
                                        np.nan)

    # Total system wait time based on effective throughput
    df['total_wait_min'] = np.where(df['total_throughput'] > 0,
                                     (df['total_queue'] / df['total_throughput']) * 60,
                                     np.nan)

    # Calculate utilization rates (ρ = λ/μ)
    # For each stage, utilization = input rate / processing capacity
    df['loading_utilization'] = np.where((df['loading_throughput'] > 0) & (df['arrivals'] > 0),
                                          df['arrivals'] / df['loading_throughput'],
                                          0)

    df['sorting_utilization'] = np.where((df['sorting_throughput'] > 0) & (df['loading_throughput'] > 0),
                                          df['loading_throughput'] / df['sorting_throughput'],
                                          0)

    df['dispatch_utilization'] = np.where((df['dispatch_throughput'] > 0) & (df['sorting_throughput'] > 0),
                                           df['sorting_throughput'] / df['dispatch_throughput'],
                                           0)

    # Cap utilization at realistic values (can't be > 100% in steady state)
    df['loading_utilization'] = df['loading_utilization'].clip(upper=1.0)
    df['sorting_utilization'] = df['sorting_utilization'].clip(upper=1.0)
    df['dispatch_utilization'] = df['dispatch_utilization'].clip(upper=1.0)

    return df

def calculate_sensitivity_corrected(df):
    """Calculate sensitivity coefficients with time-lag consideration"""

    results = []

    for station in df['delivery_station_code'].unique():
        station_data = df[df['delivery_station_code'] == station].copy()
        station_data = station_data.sort_values('timestamp')

        # Calculate changes with 1-hour lag (packages take time to flow through)
        station_data['arrival_change'] = station_data['arrivals'].diff()
        station_data['queue_change'] = station_data['total_queue'].diff()

        # Also calculate lagged sensitivity (queue response to previous hour's arrivals)
        station_data['arrival_lagged'] = station_data['arrivals'].shift(1)
        station_data['arrival_change_lagged'] = station_data['arrival_lagged'].diff()

        # Remove NaN values for correlation calculation
        valid_data = station_data.dropna(subset=['arrival_change', 'queue_change'])

        if len(valid_data) > 10:
            # Immediate sensitivity
            if valid_data['arrival_change'].std() > 0:
                immediate_sensitivity = (valid_data['queue_change'].cov(valid_data['arrival_change']) /
                                        valid_data['arrival_change'].var())
            else:
                immediate_sensitivity = 0

            # Lagged sensitivity (often more meaningful)
            valid_lagged = station_data.dropna(subset=['arrival_change_lagged', 'queue_change'])
            if len(valid_lagged) > 10 and valid_lagged['arrival_change_lagged'].std() > 0:
                lagged_sensitivity = (valid_lagged['queue_change'].cov(valid_lagged['arrival_change_lagged']) /
                                     valid_lagged['arrival_change_lagged'].var())
            else:
                lagged_sensitivity = immediate_sensitivity

            # Use the maximum absolute sensitivity
            sensitivity = max(abs(immediate_sensitivity), abs(lagged_sensitivity))

            # Calculate coefficient of variation
            arrival_cv = station_data['arrivals'].std() / station_data['arrivals'].mean() if station_data['arrivals'].mean() > 0 else 0
            queue_cv = station_data['total_queue'].std() / station_data['total_queue'].mean() if station_data['total_queue'].mean() > 0 else 0

            # Peak hour analysis (14:00-18:00)
            peak_data = station_data[(station_data['hour'] >= 14) & (station_data['hour'] <= 18)]
            offpeak_data = station_data[(station_data['hour'] < 14) | (station_data['hour'] > 18)]

            peak_avg_queue = peak_data['total_queue'].mean() if len(peak_data) > 0 else 0
            offpeak_avg_queue = offpeak_data['total_queue'].mean() if len(offpeak_data) > 0 else 0
            peak_ratio = peak_avg_queue / offpeak_avg_queue if offpeak_avg_queue > 0 else 1

            # Count anomalies
            anomaly_count = station_data['anomaly_detected'].sum()
            anomaly_rate = anomaly_count / len(station_data)

            # Identify primary bottleneck based on wait times
            avg_loading_wait = station_data['loading_wait_min'].mean()
            avg_sorting_wait = station_data['sorting_wait_min'].mean()
            avg_dispatch_wait = station_data['dispatch_wait_min'].mean()

            max_wait = max([avg_loading_wait or 0, avg_sorting_wait or 0, avg_dispatch_wait or 0])
            if max_wait > 0:
                if avg_loading_wait == max_wait:
                    primary_bottleneck = 'LOADING'
                elif avg_sorting_wait == max_wait:
                    primary_bottleneck = 'SORTING'
                else:
                    primary_bottleneck = 'DISPATCH'
            else:
                primary_bottleneck = 'BALANCED'

            # Calculate stability score (normalized 0-1)
            stability_score = (
                min(queue_cv, 2.0) / 2.0 * 0.3 +  # Normalize CV to 0-1
                min(sensitivity / 10, 1.0) * 0.3 +  # Normalize sensitivity
                anomaly_rate * 0.2 +
                min((peak_ratio - 1), 2.0) / 2.0 * 0.2  # Normalize peak ratio
            )

            # Classify stability
            if stability_score < 0.3:
                stability_class = 'STABLE'
            elif stability_score > 0.5:
                stability_class = 'CRITICAL'
            else:
                stability_class = 'MODERATE'

            results.append({
                'station': station,
                'stability_class': stability_class,
                'stability_score': round(stability_score, 3),
                'avg_arrivals': round(station_data['arrivals'].mean(), 1),
                'avg_queue': round(station_data['total_queue'].mean(), 1),
                'avg_wait_min': round(station_data['total_wait_min'].mean(), 1),
                'sensitivity': round(sensitivity, 2),
                'arrival_cv': round(arrival_cv, 3),
                'queue_cv': round(queue_cv, 3),
                'peak_ratio': round(peak_ratio, 2),
                'anomaly_count': int(anomaly_count),
                'anomaly_rate': round(anomaly_rate * 100, 1),
                'primary_bottleneck': primary_bottleneck,
                'avg_utilization': round(station_data[['loading_utilization', 'sorting_utilization', 'dispatch_utilization']].mean().mean(), 3),
                'data_points': len(station_data)
            })

    return pd.DataFrame(results)

def main():
    # Load data
    file_path = '/Volumes/workplace/temp_extract/TO_ARCHIVE_workspace_archive_20250912_094840/opsbrain_backup_20250830/opsbrain_workspace/opsbrainpoc/src/OpsBrainPOC/real_30_station_queue_data.csv'

    print("="*80)
    print("CORRECTED 30 STATION SENSITIVITY ANALYSIS")
    print("Analysis Date: September 18, 2025")
    print("="*80)

    print("\nLoading queue data...")
    df = load_queue_data(file_path)

    print(f"Loaded {len(df)} records for {df['delivery_station_code'].nunique()} stations")
    print(f"Data period: {df['timestamp'].min().date()} to {df['timestamp'].max().date()}")

    # Apply corrected Little's Law calculations
    print("\nApplying corrected Little's Law calculations...")
    df = calculate_littles_law_corrected(df)

    # Show sample of corrected wait times
    sample = df[df['total_wait_min'].notna()].head(10)
    print("\nSample wait times (CORRECTED - in minutes):")
    for _, row in sample.iterrows():
        if row['total_wait_min'] > 0:
            hours = row['total_wait_min'] / 60
            print(f"  {row['delivery_station_code']} at {row['timestamp']}: {row['total_wait_min']:.1f} min ({hours:.1f} hrs)")

    # Calculate sensitivity with corrections
    print("\nCalculating sensitivity coefficients with time-lag consideration...")
    sensitivity_df = calculate_sensitivity_corrected(df)

    # Add recommendations
    def generate_recommendation(row):
        if row['stability_class'] == 'CRITICAL':
            if row['peak_ratio'] > 2:
                return 'URGENT: Critical sensitivity + high peak impact. Implement surge staffing and flow control.'
            else:
                return 'URGENT: High sensitivity. Review capacity and implement flow control.'
        elif row['stability_class'] == 'MODERATE':
            if row['anomaly_rate'] > 10:
                return 'MONITOR: Frequent anomalies. Investigate root causes.'
            elif row['peak_ratio'] > 1.5:
                return 'ATTENTION: Peak hour stress. Consider staffing adjustments.'
            else:
                return 'MONITOR: Moderate sensitivity. Track trends.'
        else:
            return 'STABLE: Operating within normal parameters.'

    sensitivity_df['recommendation'] = sensitivity_df.apply(generate_recommendation, axis=1)

    # Calculate dynamic thresholds
    sensitivity_df['yellow_threshold'] = sensitivity_df.apply(
        lambda x: round(x['avg_queue'] * (1 + x['queue_cv']), 0), axis=1
    )
    sensitivity_df['red_threshold'] = sensitivity_df.apply(
        lambda x: round(x['avg_queue'] * (1 + 2 * x['queue_cv']), 0), axis=1
    )

    # Sort by stability score
    sensitivity_df = sensitivity_df.sort_values('stability_score', ascending=False)

    # Display results
    print("\n" + "="*80)
    print("SENSITIVITY ANALYSIS RESULTS")
    print("="*80)

    # Summary
    print(f"\nStability Classification:")
    for class_name in ['CRITICAL', 'MODERATE', 'STABLE']:
        count = len(sensitivity_df[sensitivity_df['stability_class'] == class_name])
        pct = count / len(sensitivity_df) * 100
        print(f"  {class_name}: {count} stations ({pct:.1f}%)")

    print("\n" + "-"*80)
    print("TOP 5 CRITICAL STATIONS (Require Immediate Attention)")
    print("-"*80)

    top_critical = sensitivity_df[sensitivity_df['stability_class'] == 'CRITICAL'].head(5)
    if len(top_critical) == 0:
        top_critical = sensitivity_df.head(5)

    for idx, row in top_critical.iterrows():
        print(f"\n{row['station']}:")
        print(f"  Status: {row['stability_class']} (Score: {row['stability_score']})")
        print(f"  Avg Queue: {row['avg_queue']:.0f} packages | Wait: {row['avg_wait_min']:.0f} min")
        print(f"  Sensitivity: {row['sensitivity']} | Peak Ratio: {row['peak_ratio']}x")
        print(f"  Utilization: {row['avg_utilization']*100:.1f}% | Anomaly Rate: {row['anomaly_rate']}%")
        print(f"  Primary Bottleneck: {row['primary_bottleneck']}")
        print(f"  Thresholds - Yellow: {row['yellow_threshold']:.0f}, Red: {row['red_threshold']:.0f}")
        print(f"  → {row['recommendation']}")

    print("\n" + "-"*80)
    print("MOST STABLE STATIONS")
    print("-"*80)

    most_stable = sensitivity_df.tail(3)
    for idx, row in most_stable.iterrows():
        print(f"\n{row['station']}: {row['stability_class']} (Score: {row['stability_score']})")
        print(f"  Avg Wait: {row['avg_wait_min']:.0f} min | Sensitivity: {row['sensitivity']}")
        print(f"  → {row['recommendation']}")

    # Save results
    output_file = '/Volumes/workplace/DecisionTreeTool/OpsBrain/30_station_sensitivity_corrected.csv'
    sensitivity_df.to_csv(output_file, index=False)
    print(f"\nResults saved to: {output_file}")

    # Key insights
    print("\n" + "="*80)
    print("KEY INSIGHTS")
    print("="*80)

    avg_wait = df['total_wait_min'].mean()
    max_wait = df['total_wait_min'].max()
    print(f"\n1. Average system wait time: {avg_wait:.1f} minutes")
    print(f"2. Maximum observed wait: {max_wait:.1f} minutes")

    high_util = df[(df['loading_utilization'] > 0.8) |
                   (df['sorting_utilization'] > 0.8) |
                   (df['dispatch_utilization'] > 0.8)]
    print(f"3. High utilization events (>80%): {len(high_util)} hours ({len(high_util)/len(df)*100:.1f}%)")

    bottleneck_counts = sensitivity_df['primary_bottleneck'].value_counts()
    print(f"\n4. Bottleneck Distribution:")
    for bottleneck, count in bottleneck_counts.items():
        print(f"   {bottleneck}: {count} stations")

    print(f"\n5. Average peak hour impact: {sensitivity_df['peak_ratio'].mean():.2f}x normal load")

    print("\n" + "="*80)
    print("ANALYSIS COMPLETE")
    print("="*80)

    return sensitivity_df

if __name__ == "__main__":
    results = main()