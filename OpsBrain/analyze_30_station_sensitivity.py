#!/usr/bin/env python3
"""
Real 30 Station Sensitivity Analysis
Analyzes queue data to calculate Little's Law metrics and sensitivity coefficients
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

def calculate_littles_law(df):
    """Apply Little's Law calculations to queue data"""

    # Calculate total queue depth
    df['total_queue'] = df['loading_queue'] + df['sorting_queue'] + df['dispatch_queue']

    # Calculate wait times using Little's Law: W = L/λ
    df['loading_wait'] = np.where(df['arrivals'] > 0,
                                   df['loading_queue'] / df['arrivals'],
                                   np.nan)

    df['sorting_wait'] = np.where(df['loading_throughput'] > 0,
                                   df['sorting_queue'] / df['loading_throughput'],
                                   np.nan)

    df['dispatch_wait'] = np.where(df['sorting_throughput'] > 0,
                                    df['dispatch_queue'] / df['sorting_throughput'],
                                    np.nan)

    df['total_wait'] = np.where(df['arrivals'] > 0,
                                 df['total_queue'] / df['arrivals'],
                                 np.nan)

    # Calculate utilization rates (ρ = λ/μ)
    df['loading_utilization'] = np.where((df['loading_throughput'] > 0) & (df['arrivals'] > 0),
                                          df['arrivals'] / df['loading_throughput'],
                                          np.nan)

    df['sorting_utilization'] = np.where((df['sorting_throughput'] > 0) & (df['loading_throughput'] > 0),
                                          df['loading_throughput'] / df['sorting_throughput'],
                                          np.nan)

    df['dispatch_utilization'] = np.where((df['dispatch_throughput'] > 0) & (df['sorting_throughput'] > 0),
                                           df['sorting_throughput'] / df['dispatch_throughput'],
                                           np.nan)

    return df

def calculate_sensitivity(df):
    """Calculate sensitivity coefficients for each station"""

    results = []

    for station in df['delivery_station_code'].unique():
        station_data = df[df['delivery_station_code'] == station].copy()
        station_data = station_data.sort_values('timestamp')

        # Calculate changes
        station_data['arrival_change'] = station_data['arrivals'].diff()
        station_data['queue_change'] = station_data['total_queue'].diff()

        # Remove NaN values for correlation calculation
        valid_data = station_data.dropna(subset=['arrival_change', 'queue_change'])

        if len(valid_data) > 10:  # Need sufficient data points
            # Calculate sensitivity coefficient
            if valid_data['arrival_change'].std() > 0:
                sensitivity = (valid_data['queue_change'].cov(valid_data['arrival_change']) /
                              valid_data['arrival_change'].var())
            else:
                sensitivity = 0

            # Calculate coefficient of variation
            arrival_cv = station_data['arrivals'].std() / station_data['arrivals'].mean() if station_data['arrivals'].mean() > 0 else 0
            queue_cv = station_data['total_queue'].std() / station_data['total_queue'].mean() if station_data['total_queue'].mean() > 0 else 0

            # Peak hour analysis (14:00-18:00)
            peak_data = station_data[(station_data['hour'] >= 14) & (station_data['hour'] <= 18)]
            offpeak_data = station_data[(station_data['hour'] < 14) | (station_data['hour'] > 18)]

            peak_avg_queue = peak_data['total_queue'].mean()
            offpeak_avg_queue = offpeak_data['total_queue'].mean()
            peak_ratio = peak_avg_queue / offpeak_avg_queue if offpeak_avg_queue > 0 else 1

            # Count anomalies
            anomaly_count = station_data['anomaly_detected'].sum()
            anomaly_rate = anomaly_count / len(station_data)

            # Identify primary bottleneck
            bottlenecks = []
            for _, row in station_data.iterrows():
                waits = {
                    'LOADING': row['loading_wait'] if pd.notna(row['loading_wait']) else 0,
                    'SORTING': row['sorting_wait'] if pd.notna(row['sorting_wait']) else 0,
                    'DISPATCH': row['dispatch_wait'] if pd.notna(row['dispatch_wait']) else 0
                }
                if max(waits.values()) > 0:
                    bottlenecks.append(max(waits, key=waits.get))

            primary_bottleneck = max(set(bottlenecks), key=bottlenecks.count) if bottlenecks else 'BALANCED'

            # Calculate stability score (lower is more stable)
            stability_score = (
                queue_cv * 0.3 +
                abs(sensitivity) * 0.001 * 0.3 +  # Normalize sensitivity
                anomaly_rate * 0.2 +
                (peak_ratio - 1) * 0.2
            )

            # Classify stability
            if queue_cv < 0.5 and abs(sensitivity) < 1000:
                stability_class = 'STABLE'
            elif queue_cv > 1.0 or abs(sensitivity) > 5000:
                stability_class = 'CRITICAL'
            else:
                stability_class = 'MODERATE'

            results.append({
                'station': station,
                'stability_class': stability_class,
                'stability_score': round(stability_score, 3),
                'avg_arrivals': round(station_data['arrivals'].mean(), 1),
                'avg_queue': round(station_data['total_queue'].mean(), 1),
                'avg_wait': round(station_data['total_wait'].mean(), 2),
                'sensitivity': round(sensitivity, 2),
                'arrival_cv': round(arrival_cv, 3),
                'queue_cv': round(queue_cv, 3),
                'peak_ratio': round(peak_ratio, 2),
                'anomaly_count': int(anomaly_count),
                'anomaly_rate': round(anomaly_rate * 100, 1),
                'primary_bottleneck': primary_bottleneck,
                'data_points': len(station_data)
            })

    return pd.DataFrame(results)

def generate_recommendations(row):
    """Generate recommendations based on sensitivity analysis"""

    if row['stability_class'] == 'CRITICAL':
        return 'URGENT: High sensitivity detected. Implement flow control and capacity review.'
    elif row['stability_class'] == 'MODERATE' and row['peak_ratio'] > 2:
        return 'ATTENTION: High peak sensitivity. Consider peak hour staffing adjustments.'
    elif row['anomaly_count'] > 10:
        return 'MONITOR: Frequent anomalies. Review operational procedures.'
    else:
        return 'STABLE: Continue monitoring with standard thresholds.'

def main():
    # Load data
    file_path = '/Volumes/workplace/temp_extract/TO_ARCHIVE_workspace_archive_20250912_094840/opsbrain_backup_20250830/opsbrain_workspace/opsbrainpoc/src/OpsBrainPOC/real_30_station_queue_data.csv'

    print("Loading queue data...")
    df = load_queue_data(file_path)

    print(f"Loaded {len(df)} records for {df['delivery_station_code'].nunique()} stations")
    print(f"Date range: {df['timestamp'].min()} to {df['timestamp'].max()}")

    # Apply Little's Law
    print("\nCalculating Little's Law metrics...")
    df = calculate_littles_law(df)

    # Calculate sensitivity
    print("Calculating sensitivity coefficients...")
    sensitivity_df = calculate_sensitivity(df)

    # Add recommendations
    sensitivity_df['recommendation'] = sensitivity_df.apply(generate_recommendations, axis=1)

    # Calculate alert thresholds
    sensitivity_df['yellow_threshold'] = sensitivity_df.apply(
        lambda x: round(x['avg_queue'] + (2 * x['queue_cv'] * x['avg_queue']), 0), axis=1
    )
    sensitivity_df['red_threshold'] = sensitivity_df.apply(
        lambda x: round(x['avg_queue'] + (3 * x['queue_cv'] * x['avg_queue']), 0), axis=1
    )

    # Sort by stability score (higher score = less stable)
    sensitivity_df = sensitivity_df.sort_values('stability_score', ascending=False)

    # Display results
    print("\n" + "="*80)
    print("30 STATION SENSITIVITY ANALYSIS RESULTS")
    print("="*80)

    # Summary statistics
    print(f"\nStability Classification Summary:")
    print(sensitivity_df['stability_class'].value_counts())

    print("\nTop 5 Most Critical Stations (Highest Sensitivity):")
    print("-"*60)
    for _, row in sensitivity_df.head(5).iterrows():
        print(f"\nStation: {row['station']}")
        print(f"  Class: {row['stability_class']} (Score: {row['stability_score']})")
        print(f"  Sensitivity: {row['sensitivity']} | Queue CV: {row['queue_cv']}")
        print(f"  Peak Ratio: {row['peak_ratio']}x | Anomaly Rate: {row['anomaly_rate']}%")
        print(f"  Bottleneck: {row['primary_bottleneck']}")
        print(f"  Alert Thresholds - Yellow: {row['yellow_threshold']}, Red: {row['red_threshold']}")
        print(f"  → {row['recommendation']}")

    print("\n" + "-"*60)
    print("\nTop 5 Most Stable Stations (Lowest Sensitivity):")
    print("-"*60)
    for _, row in sensitivity_df.tail(5).iterrows():
        print(f"\nStation: {row['station']}")
        print(f"  Class: {row['stability_class']} (Score: {row['stability_score']})")
        print(f"  Sensitivity: {row['sensitivity']} | Queue CV: {row['queue_cv']}")
        print(f"  Peak Ratio: {row['peak_ratio']}x | Anomaly Rate: {row['anomaly_rate']}%")
        print(f"  → {row['recommendation']}")

    # Save detailed results
    output_file = '/Volumes/workplace/DecisionTreeTool/OpsBrain/30_station_sensitivity_results.csv'
    sensitivity_df.to_csv(output_file, index=False)
    print(f"\nDetailed results saved to: {output_file}")

    # Little's Law validation
    print("\n" + "="*80)
    print("LITTLE'S LAW VALIDATION")
    print("="*80)

    # Check where Little's Law breaks down (utilization > 0.9)
    high_utilization = df[
        (df['loading_utilization'] > 0.9) |
        (df['sorting_utilization'] > 0.9) |
        (df['dispatch_utilization'] > 0.9)
    ]

    if len(high_utilization) > 0:
        print(f"\nFound {len(high_utilization)} instances where utilization > 90% (system overload)")
        breakdown_stations = high_utilization['delivery_station_code'].value_counts().head()
        print("\nStations with most overload events:")
        for station, count in breakdown_stations.items():
            print(f"  {station}: {count} hours")
    else:
        print("\nNo instances of system overload (utilization > 90%) detected")

    # Correlation analysis
    print("\n" + "-"*60)
    print("CORRELATION ANALYSIS")
    print("-"*60)

    correlation = df[['arrivals', 'total_queue', 'total_wait']].corr()
    print("\nCorrelation Matrix:")
    print(correlation)

    print("\n" + "="*80)
    print("ANALYSIS COMPLETE")
    print("="*80)

    return sensitivity_df

if __name__ == "__main__":
    results = main()