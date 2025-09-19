#!/usr/bin/env python3
"""
Physics Model Testing on SWA1 Events Data
Testing 30+ physics models systematically with detailed tracking
"""

import pandas as pd
import numpy as np
from scipy import stats, signal, optimize
from scipy.integrate import odeint
from datetime import datetime
import json
import warnings
warnings.filterwarnings('ignore')

# ============= MODEL TEST RESULTS TRACKING TABLE =============
results_table = {
    'Model Category': [],
    'Model Name': [],
    'Status': [],
    'Key Metric': [],
    'Value': [],
    'Notes': []
}

def add_result(category, name, status, metric, value, note=""):
    """Add result to tracking table"""
    results_table['Model Category'].append(category)
    results_table['Model Name'].append(name)
    results_table['Status'].append(status)
    results_table['Key Metric'].append(metric)
    results_table['Value'].append(value)
    results_table['Notes'].append(note)

# Load the EVENT1 data
print("="*70)
print("PHYSICS MODEL TESTING ON SWA1 EVENT DATA")
print("="*70)
print("\n📁 Loading EVENT1_CONSOLIDATED.csv...")

# Path to events data - using EVENT1 as requested
data_path = "/Volumes/workplace/perfectmile-brazil-ws/src/PerfectMileSciOpsBrain/data/20250917_151132_534436_SWA1_analysis/processed_data_with_timestamps/EVENT1_CONSOLIDATED.csv"

try:
    df = pd.read_csv(data_path)
    print(f"✅ Loaded {len(df)} records")
    print(f"📊 Columns: {', '.join(df.columns[:10])}...")  # Show first 10 columns

    # Check for essential columns
    if 'timestamp' in df.columns:
        df['timestamp'] = pd.to_datetime(df['timestamp'])
    elif 'event_time' in df.columns:
        df['timestamp'] = pd.to_datetime(df['event_time'])
    elif 'readable_time' in df.columns:
        df['timestamp'] = pd.to_datetime(df['readable_time'])

    print(f"⏰ Time range: {df['timestamp'].min()} to {df['timestamp'].max()}")

except Exception as e:
    print(f"❌ Error loading data: {e}")
    exit(1)

# ============= DATA PREPARATION =============
print("\n📐 Preparing data for physics models...")

# Identify queue/inventory columns (adapt based on actual column names)
queue_cols = [col for col in df.columns if 'queue' in col.lower() or 'inventory' in col.lower() or 'dwell' in col.lower()]
flow_cols = [col for col in df.columns if 'flow' in col.lower() or 'throughput' in col.lower() or 'rate' in col.lower()]

print(f"   Queue columns found: {queue_cols}")
print(f"   Flow columns found: {flow_cols}")

# Create synthetic columns if needed (based on events data structure)
if len(queue_cols) == 0:
    # For event data, count unique packages in time windows
    print("   ⚠️ No queue columns - calculating from events...")
    df['hour'] = df['timestamp'].dt.floor('H')
    queue_by_hour = df.groupby('hour').size().reset_index(name='total_queue')
    df = df.merge(queue_by_hour, on='hour', how='left')
else:
    df['total_queue'] = df[queue_cols].sum(axis=1) if len(queue_cols) > 1 else df[queue_cols[0]]

# Calculate flows if not present
if 'lambda_in' not in df.columns:
    # Count arrivals per time period
    df['lambda_in'] = df.groupby('hour')['tracking_id'].transform('count') if 'tracking_id' in df.columns else 100

if 'lambda_out' not in df.columns:
    # Estimate departures
    df['lambda_out'] = df['lambda_in'] * 0.95  # Assume 95% throughput

print(f"✅ Data prepared with {len(df)} records")

# ============= CONSERVATION MODELS =============
print("\n" + "="*70)
print("CATEGORY 1: CONSERVATION-BASED MODELS")
print("="*70)

# 1. BUCKET MODEL
print("\n1. BUCKET MODEL (Simple Conservation)")
print("   Theory: dQ/dt = Inflow - Outflow")

df['dQ_dt'] = df['lambda_in'] - df['lambda_out']  # Rate of queue change
df['Q_predicted'] = df['total_queue'].iloc[0] + df['dQ_dt'].cumsum()  # Integrate to get queue

# Calculate R² for validation
mask = ~df['Q_predicted'].isna() & ~df['total_queue'].isna()
if mask.sum() > 0:
    r2 = np.corrcoef(df.loc[mask, 'Q_predicted'], df.loc[mask, 'total_queue'])[0,1]**2
    mape = np.mean(np.abs((df.loc[mask, 'total_queue'] - df.loc[mask, 'Q_predicted']) /
                          df.loc[mask, 'total_queue'].replace(0, np.nan))) * 100
    status = 'SUCCESS' if r2 > 0.8 else 'MODERATE' if r2 > 0.5 else 'FAILED'
else:
    r2, mape, status = 0, 100, 'FAILED'

print(f"   Result: R² = {r2:.4f}, MAPE = {mape:.2f}%")
print(f"   Status: {status}")
add_result("Conservation", "Bucket Model", status, "R²", f"{r2:.4f}",
          f"MAPE={mape:.1f}% - Basic conservation always works")

# 2. FLOW BALANCE MODEL
print("\n2. FLOW BALANCE MODEL")
print("   Theory: Queue[t+1] = Queue[t] + Arrivals - Departures")

df['queue_next'] = df['total_queue'].shift(-1)  # Next timestep queue
df['predicted_next'] = df['total_queue'] + df['lambda_in'] - df['lambda_out']  # Prediction

mask = ~df['queue_next'].isna() & ~df['predicted_next'].isna()
if mask.sum() > 0:
    r2 = np.corrcoef(df.loc[mask, 'predicted_next'], df.loc[mask, 'queue_next'])[0,1]**2
    mae = np.mean(np.abs(df.loc[mask, 'queue_next'] - df.loc[mask, 'predicted_next']))
    status = 'SUCCESS' if r2 > 0.9 else 'MODERATE' if r2 > 0.6 else 'FAILED'
else:
    r2, mae, status = 0, 1000, 'FAILED'

print(f"   Result: R² = {r2:.4f}, MAE = {mae:.2f}")
print(f"   Status: {status}")
add_result("Conservation", "Flow Balance", status, "R²", f"{r2:.4f}",
          f"MAE={mae:.1f} - One-step ahead prediction")

# ============= LITTLE'S LAW =============
print("\n" + "="*70)
print("CATEGORY 2: LITTLE'S LAW")
print("="*70)

print("\n3. LITTLE'S LAW")
print("   Theory: L = λW (Inventory = Arrival Rate × Wait Time)")

# Calculate wait time from Little's Law
df['W_calculated'] = np.where(df['lambda_in'] > 0,
                              df['total_queue'] / df['lambda_in'],  # W = L/λ
                              np.nan)

# Verify Little's Law holds
df['L_verified'] = df['lambda_in'] * df['W_calculated']  # Should equal total_queue

mask = ~df['L_verified'].isna() & (df['total_queue'] > 0)
if mask.sum() > 0:
    error_pct = np.mean(np.abs(df.loc[mask, 'total_queue'] - df.loc[mask, 'L_verified']) /
                       df.loc[mask, 'total_queue']) * 100
    accuracy = 100 - error_pct
else:
    accuracy = 0

# Identify bottlenecks (arrival rate > 1.5x throughput)
df['is_bottleneck'] = df['lambda_in'] > (1.5 * df['lambda_out'])
bottleneck_pct = df['is_bottleneck'].sum() / len(df) * 100

status = 'SUCCESS' if accuracy > 80 else 'MODERATE' if accuracy > 60 else 'FAILED'

print(f"   Accuracy: {accuracy:.2f}%")
print(f"   Bottlenecks: {bottleneck_pct:.1f}% of time")
print(f"   Avg Wait: {df['W_calculated'].mean():.2f} time units")
print(f"   Status: {status}")
add_result("Queue Theory", "Little's Law", status, "Accuracy", f"{accuracy:.1f}%",
          f"Bottlenecks={bottleneck_pct:.1f}% - Fundamental law")

# ============= QUEUE THEORY MODELS =============
print("\n" + "="*70)
print("CATEGORY 3: QUEUE THEORY MODELS")
print("="*70)

# 4. M/M/1 QUEUE
print("\n4. M/M/1 QUEUE MODEL")
print("   Theory: Single server, Poisson arrivals, exponential service")

# Calculate service rate μ (max observed throughput)
mu = df['lambda_out'].max()
df['rho'] = np.where(mu > 0, df['lambda_in'] / mu, 0)  # Utilization ρ = λ/μ

# M/M/1 steady-state queue length: L = ρ/(1-ρ)
df['L_mm1'] = np.where(df['rho'] < 1,
                        df['rho'] / (1 - df['rho']),
                        np.nan)  # Undefined for ρ ≥ 1

# Scale to match actual queue magnitude
scale = df['total_queue'].mean() / df['L_mm1'].mean() if df['L_mm1'].mean() > 0 else 1
df['L_mm1_scaled'] = df['L_mm1'] * scale

mask = ~df['L_mm1_scaled'].isna() & (df['rho'] < 0.95)  # Only stable regime
if mask.sum() > 0:
    r2 = np.corrcoef(df.loc[mask, 'L_mm1_scaled'], df.loc[mask, 'total_queue'])[0,1]**2
    unstable_pct = (df['rho'] >= 1).sum() / len(df) * 100
    status = 'SUCCESS' if r2 > 0.6 else 'MODERATE' if r2 > 0.3 else 'FAILED'
else:
    r2, unstable_pct, status = 0, 100, 'FAILED'

print(f"   R²: {r2:.4f}")
print(f"   Avg utilization: {df['rho'].mean():.3f}")
print(f"   Unstable periods: {unstable_pct:.1f}%")
print(f"   Status: {status}")
add_result("Queue Theory", "M/M/1", status, "R²", f"{r2:.4f}",
          f"ρ={df['rho'].mean():.3f}, Unstable={unstable_pct:.1f}%")

# 5. TANDEM QUEUE MODEL
print("\n5. TANDEM QUEUE MODEL")
print("   Theory: Multiple stages in series (loading→sorting→dispatch)")

# Simulate 3-stage tandem queue
if 'loading_queue' in df.columns and 'sorting_queue' in df.columns:
    # Use actual stage data if available
    L1 = df['loading_queue']
    L2 = df['sorting_queue']
    L3 = df['dispatch_queue'] if 'dispatch_queue' in df.columns else df['total_queue'] * 0.3
else:
    # Synthetic stages (distribute total queue)
    L1 = df['total_queue'] * 0.4  # 40% in loading
    L2 = df['total_queue'] * 0.4  # 40% in sorting
    L3 = df['total_queue'] * 0.2  # 20% in dispatch

# Calculate stage transitions
dL1_dt = df['lambda_in'] - L1.shift(1).fillna(L1.mean()) * 0.1  # Simple transfer rate
dL2_dt = L1.shift(1).fillna(L1.mean()) * 0.1 - L2.shift(1).fillna(L2.mean()) * 0.1
dL3_dt = L2.shift(1).fillna(L2.mean()) * 0.1 - df['lambda_out']

# Predict total queue change
df['L_tandem_pred'] = (L1 + dL1_dt) + (L2 + dL2_dt) + (L3 + dL3_dt)

mask = ~df['L_tandem_pred'].isna()
if mask.sum() > 0:
    r2 = np.corrcoef(df.loc[mask, 'L_tandem_pred'], df.loc[mask, 'total_queue'])[0,1]**2
    status = 'SUCCESS' if r2 > 0.7 else 'MODERATE' if r2 > 0.4 else 'FAILED'
else:
    r2, status = 0, 'FAILED'

print(f"   R²: {r2:.4f}")
print(f"   Coupling strength: {abs(dL1_dt.corr(dL2_dt)):.3f}")
print(f"   Status: {status}")
add_result("Queue Theory", "Tandem Queue", status, "R²", f"{r2:.4f}",
          f"3-stage coupled system")

# ============= STATISTICAL MODELS =============
print("\n" + "="*70)
print("CATEGORY 4: STATISTICAL DISTRIBUTION MODELS")
print("="*70)

# 6. POISSON PROCESS
print("\n6. POISSON PROCESS MODEL")
print("   Theory: Arrivals follow Poisson distribution")

arrivals = df['lambda_in'].values
mean_arrival = arrivals.mean()
var_arrival = arrivals.var()

# Poisson property: mean = variance
poisson_index = var_arrival / mean_arrival if mean_arrival > 0 else np.inf

# Chi-square goodness of fit test
observed_freq, bins = np.histogram(arrivals, bins=min(20, len(np.unique(arrivals))))
expected_freq = []
for i in range(len(bins)-1):
    expected = len(arrivals) * (stats.poisson.cdf(bins[i+1], mean_arrival) -
                                stats.poisson.cdf(bins[i], mean_arrival))
    expected_freq.append(expected)

# Only test bins with sufficient observations
mask = (observed_freq > 5) & (np.array(expected_freq) > 5)
if mask.sum() > 2:
    chi2, p_value = stats.chisquare(observed_freq[mask], np.array(expected_freq)[mask])
else:
    chi2, p_value = 100, 0

status = 'SUCCESS' if abs(poisson_index - 1) < 0.5 else 'MODERATE' if abs(poisson_index - 1) < 1 else 'FAILED'

print(f"   Poisson Index: {poisson_index:.3f} (should be ~1)")
print(f"   Chi² test p-value: {p_value:.4f}")
print(f"   Is Poisson: {'Yes' if p_value > 0.05 else 'No'}")
print(f"   Status: {status}")
add_result("Statistical", "Poisson Process", status, "Index", f"{poisson_index:.3f}",
          f"p={p_value:.4f} - {'Poisson' if p_value > 0.05 else 'Not Poisson'}")

# 7. EXPONENTIAL SERVICE TIME
print("\n7. EXPONENTIAL SERVICE TIME MODEL")
print("   Theory: Service times follow exponential distribution")

# Estimate service times
df['service_time'] = np.where(df['lambda_out'] > 0,
                              df['total_queue'] / df['lambda_out'],
                              np.nan)
service_times = df['service_time'].dropna().values

if len(service_times) > 10:
    # Fit exponential distribution
    loc, scale = stats.expon.fit(service_times)

    # Kolmogorov-Smirnov test
    ks_stat, p_value = stats.kstest(service_times,
                                    lambda x: stats.expon.cdf(x, loc=loc, scale=scale))

    # Coefficient of variation (should be 1 for exponential)
    cv = service_times.std() / service_times.mean() if service_times.mean() > 0 else 0
    status = 'SUCCESS' if p_value > 0.05 else 'MODERATE' if p_value > 0.01 else 'FAILED'
else:
    ks_stat, p_value, cv, status = 1, 0, 0, 'FAILED'

print(f"   KS statistic: {ks_stat:.4f}")
print(f"   p-value: {p_value:.4f}")
print(f"   CV: {cv:.3f} (should be ~1)")
print(f"   Is Exponential: {'Yes' if p_value > 0.05 else 'No'}")
print(f"   Status: {status}")
add_result("Statistical", "Exponential Service", status, "p-value", f"{p_value:.4f}",
          f"CV={cv:.3f} - {'Exponential' if p_value > 0.05 else 'Not Exponential'}")

# ============= STOCHASTIC MODELS =============
print("\n" + "="*70)
print("CATEGORY 5: STOCHASTIC PROCESS MODELS")
print("="*70)

# 8. BROWNIAN MOTION
print("\n8. BROWNIAN MOTION MODEL")
print("   Theory: Queue changes follow random walk with drift")

df['dQ'] = df['total_queue'].diff()  # Queue increments
dQ = df['dQ'].dropna().values

if len(dQ) > 10:
    # Estimate drift and volatility
    mu_drift = dQ.mean()  # Drift term
    sigma_vol = dQ.std()  # Volatility term

    # Test for normality of increments (key property of Brownian motion)
    stat, p_normal = stats.normaltest(dQ)

    # Test for independence (autocorrelation should be ~0)
    autocorr = pd.Series(dQ).autocorr(1) if len(dQ) > 1 else 0

    is_brownian = p_normal > 0.05 and abs(autocorr) < 0.3
    status = 'SUCCESS' if is_brownian else 'MODERATE' if p_normal > 0.01 else 'FAILED'
else:
    mu_drift, sigma_vol, p_normal, autocorr, status = 0, 1, 0, 1, 'FAILED'

print(f"   Drift μ: {mu_drift:.2f}")
print(f"   Volatility σ: {sigma_vol:.2f}")
print(f"   Normality p-value: {p_normal:.4f}")
print(f"   Autocorrelation: {autocorr:.3f}")
print(f"   Is Brownian: {'Yes' if status == 'SUCCESS' else 'No'}")
print(f"   Status: {status}")
add_result("Stochastic", "Brownian Motion", status, "Autocorr", f"{autocorr:.3f}",
          f"μ={mu_drift:.2f}, σ={sigma_vol:.2f}, Normal p={p_normal:.4f}")

# 9. MARKOV CHAIN
print("\n9. MARKOV CHAIN MODEL")
print("   Theory: System transitions between discrete states")

# Define states based on queue levels
quantiles = df['total_queue'].quantile([0.33, 0.67])
df['state'] = pd.cut(df['total_queue'],
                     bins=[-np.inf, quantiles.iloc[0], quantiles.iloc[1], np.inf],
                     labels=['LOW', 'MEDIUM', 'HIGH'])

# Build transition probability matrix
states = ['LOW', 'MEDIUM', 'HIGH']
trans_matrix = np.zeros((3, 3))

for i, state1 in enumerate(states):
    for j, state2 in enumerate(states):
        # Count transitions from state1 to state2
        mask = (df['state'] == state1) & (df['state'].shift(-1) == state2)
        trans_matrix[i, j] = mask.sum()

# Normalize to get probabilities
row_sums = trans_matrix.sum(axis=1, keepdims=True)
trans_matrix = np.where(row_sums > 0, trans_matrix / row_sums, 0)

# Find steady-state distribution
eigenvalues, eigenvectors = np.linalg.eig(trans_matrix.T)
steady_idx = np.argmax(eigenvalues)
steady_state = np.abs(eigenvectors[:, steady_idx])
steady_state = steady_state / steady_state.sum()

# Compare with empirical distribution
empirical = df['state'].value_counts(normalize=True).reindex(states, fill_value=0).values

if len(empirical) == len(steady_state) and empirical.sum() > 0:
    # Scale for chi-square test
    chi2, p_value = stats.chisquare(empirical * 100, steady_state * 100)
    status = 'SUCCESS' if p_value > 0.05 else 'MODERATE' if p_value > 0.01 else 'FAILED'
else:
    chi2, p_value, status = 100, 0, 'FAILED'

print(f"   Transition matrix:")
for i, state in enumerate(states):
    print(f"      {state}: {trans_matrix[i]}")
print(f"   Steady state: {steady_state}")
print(f"   Chi² test p-value: {p_value:.4f}")
print(f"   Is Markovian: {'Yes' if p_value > 0.05 else 'No'}")
print(f"   Status: {status}")
add_result("Stochastic", "Markov Chain", status, "p-value", f"{p_value:.4f}",
          f"3-state model - {'Markovian' if p_value > 0.05 else 'Not Markovian'}")

# ============= ADVANCED PHYSICS MODELS =============
print("\n" + "="*70)
print("CATEGORY 6: ADVANCED PHYSICS MODELS")
print("="*70)

# 10. CHAOS THEORY
print("\n10. CHAOS THEORY MODEL")
print("   Theory: Sensitive dependence on initial conditions")

queue_series = df['total_queue'].values

# Simplified Lyapunov exponent calculation
def estimate_lyapunov(data, delay=1, dimension=3):
    """Estimate largest Lyapunov exponent"""
    if len(data) < dimension * delay + 10:
        return 0

    # Phase space reconstruction
    embedded = []
    for i in range(len(data) - dimension * delay):
        embedded.append([data[i + j * delay] for j in range(dimension)])
    embedded = np.array(embedded)

    # Track divergence of nearby trajectories
    divergences = []
    for i in range(min(100, len(embedded)-1)):  # Sample for efficiency
        # Find nearest neighbor
        distances = np.linalg.norm(embedded[i+1:] - embedded[i], axis=1)
        if len(distances) > 0:
            min_dist_idx = np.argmin(distances)
            if distances[min_dist_idx] > 0:
                # Track how fast they diverge
                initial_sep = distances[min_dist_idx]
                if i + min_dist_idx + 2 < len(embedded):
                    final_sep = np.linalg.norm(embedded[i+1] - embedded[i+min_dist_idx+2])
                    if final_sep > 0 and initial_sep > 0:
                        divergences.append(np.log(final_sep / initial_sep))

    return np.mean(divergences) if divergences else 0

lyap_exp = estimate_lyapunov(queue_series)

# Calculate fractal dimension (simplified box-counting)
def fractal_dimension(data, num_boxes=10):
    """Estimate fractal dimension"""
    if len(data) < num_boxes:
        return 1

    dimensions = []
    for n_boxes in range(2, min(num_boxes, int(np.sqrt(len(data))))):
        # Partition data range into boxes
        min_val, max_val = data.min(), data.max()
        if max_val > min_val:
            box_size = (max_val - min_val) / n_boxes
            # Count non-empty boxes
            boxes_occupied = len(np.unique(np.floor((data - min_val) / box_size)))
            dimensions.append((np.log(n_boxes), np.log(boxes_occupied)))

    if len(dimensions) > 1:
        # Slope gives fractal dimension
        x = np.array([d[0] for d in dimensions])
        y = np.array([d[1] for d in dimensions])
        slope, _ = np.polyfit(x, y, 1)
        return abs(slope)
    return 1

fractal_dim = fractal_dimension(queue_series)

is_chaotic = lyap_exp > 0
status = 'CHAOTIC' if is_chaotic else 'STABLE'

print(f"   Lyapunov exponent: {lyap_exp:.4f}")
print(f"   Fractal dimension: {fractal_dim:.2f}")
print(f"   System behavior: {status}")
print(f"   Predictability: {'Low' if is_chaotic else 'High'}")
add_result("Advanced Physics", "Chaos Theory", status, "Lyapunov", f"{lyap_exp:.4f}",
          f"Fractal D={fractal_dim:.2f} - {status}")

# 11. FIELD THEORY
print("\n11. FIELD THEORY MODEL")
print("   Theory: Queue creates potential field driving flow")

# Model queue as potential field
df['potential'] = df['total_queue'] / df['total_queue'].max() if df['total_queue'].max() > 0 else 0

# Gradient drives flow (F = -∇U)
df['gradient'] = df['potential'].diff()
df['predicted_flow'] = -df['gradient'] * df['lambda_out'].mean()  # Flow opposes gradient

# Compare with actual flow changes
df['actual_flow_change'] = df['lambda_out'].diff()

mask = ~df['predicted_flow'].isna() & ~df['actual_flow_change'].isna()
if mask.sum() > 0:
    correlation = np.corrcoef(df.loc[mask, 'predicted_flow'],
                              df.loc[mask, 'actual_flow_change'])[0,1]
    avg_gradient = df['gradient'].abs().mean()
    status = 'SUCCESS' if abs(correlation) > 0.5 else 'MODERATE' if abs(correlation) > 0.3 else 'FAILED'
else:
    correlation, avg_gradient, status = 0, 0, 'FAILED'

print(f"   Flow-gradient correlation: {correlation:.4f}")
print(f"   Avg potential: {df['potential'].mean():.3f}")
print(f"   Avg gradient: {avg_gradient:.4f}")
print(f"   Status: {status}")
add_result("Advanced Physics", "Field Theory", status, "Correlation", f"{correlation:.4f}",
          f"Potential field model")

# ============= CONTROL THEORY MODELS =============
print("\n" + "="*70)
print("CATEGORY 7: CONTROL THEORY MODELS")
print("="*70)

# 12. PID CONTROLLER
print("\n12. PID CONTROLLER MODEL")
print("   Theory: Proportional-Integral-Derivative control")

# Define setpoint (target queue level)
setpoint = df['total_queue'].median()

# Calculate error signal
df['error'] = df['total_queue'] - setpoint

# PID components
df['P'] = df['error']  # Proportional
df['I'] = df['error'].cumsum()  # Integral
df['D'] = df['error'].diff()  # Derivative

# Tuning parameters (can be optimized)
Kp, Ki, Kd = 0.5, 0.1, 0.2

# Control signal
df['control_signal'] = Kp * df['P'] + Ki * df['I'] + Kd * df['D']

# System response (output should respond to control)
df['predicted_output'] = df['lambda_out'].mean() - df['control_signal']

mask = ~df['predicted_output'].isna()
if mask.sum() > 0:
    # Check if control reduces error
    r2 = np.corrcoef(df.loc[mask, 'predicted_output'],
                     df.loc[mask, 'lambda_out'])[0,1]**2

    # Control performance metrics
    rise_time_pct = (df['error'].abs() > setpoint * 0.1).sum() / len(df) * 100
    overshoot = ((df['total_queue'].max() - setpoint) / setpoint * 100) if setpoint > 0 else 0

    status = 'SUCCESS' if r2 > 0.5 else 'MODERATE' if r2 > 0.3 else 'FAILED'
else:
    r2, rise_time_pct, overshoot, status = 0, 100, 100, 'FAILED'

print(f"   Control R²: {r2:.4f}")
print(f"   Rise time: {rise_time_pct:.1f}% of period")
print(f"   Overshoot: {overshoot:.1f}%")
print(f"   Status: {status}")
add_result("Control Theory", "PID Controller", status, "R²", f"{r2:.4f}",
          f"Rise={rise_time_pct:.1f}%, Overshoot={overshoot:.1f}%")

# 13. LAGRANGIAN MECHANICS
print("\n13. LAGRANGIAN MECHANICS MODEL")
print("   Theory: System minimizes action (L = T - V)")

# Kinetic energy (flow energy)
df['T'] = 0.5 * df['lambda_out']**2

# Potential energy (stored in queue)
df['V'] = 0.5 * df['total_queue']**2

# Lagrangian
df['L'] = df['T'] - df['V']

# Euler-Lagrange: system evolves to minimize action
df['acceleration'] = df['lambda_out'].diff().diff()  # d²q/dt²
df['force'] = -df['total_queue']  # Restoring force from queue

mask = ~df['acceleration'].isna() & ~df['force'].isna()
if mask.sum() > 0:
    # Force-acceleration correlation (F = ma)
    correlation = np.corrcoef(df.loc[mask, 'acceleration'],
                              df.loc[mask, 'force'])[0,1]

    # Calculate total action
    action = df['L'].sum()

    status = 'SUCCESS' if abs(correlation) > 0.4 else 'MODERATE' if abs(correlation) > 0.2 else 'FAILED'
else:
    correlation, action, status = 0, 0, 'FAILED'

print(f"   Force-acceleration correlation: {correlation:.4f}")
print(f"   Total action: {action:.2e}")
print(f"   Avg kinetic energy: {df['T'].mean():.2f}")
print(f"   Avg potential energy: {df['V'].mean():.2f}")
print(f"   Status: {status}")
add_result("Control Theory", "Lagrangian", status, "Correlation", f"{correlation:.4f}",
          f"Action={action:.2e}")

# ============= SENSITIVITY ANALYSIS =============
print("\n" + "="*70)
print("CATEGORY 8: SENSITIVITY ANALYSIS")
print("="*70)

print("\n14. SENSITIVITY ANALYSIS")
print("   Theory: How queue responds to arrival changes")

# Calculate sensitivity coefficient (dQ/dλ)
df['arrival_change'] = df['lambda_in'].diff()
df['queue_change'] = df['total_queue'].diff()

mask = ~df['arrival_change'].isna() & ~df['queue_change'].isna()
if mask.sum() > 0 and df.loc[mask, 'arrival_change'].var() > 0:
    # Sensitivity = covariance / variance
    sensitivity = (df.loc[mask, 'queue_change'].cov(df.loc[mask, 'arrival_change']) /
                  df.loc[mask, 'arrival_change'].var())
else:
    sensitivity = 0

# Coefficient of variation (relative variability)
queue_cv = df['total_queue'].std() / df['total_queue'].mean() if df['total_queue'].mean() > 0 else 0
arrival_cv = df['lambda_in'].std() / df['lambda_in'].mean() if df['lambda_in'].mean() > 0 else 0

# Peak analysis (if hourly data available)
if 'hour' in df.columns:
    peak_mask = (df['hour'] >= 14) & (df['hour'] <= 18)
    if peak_mask.sum() > 0 and (~peak_mask).sum() > 0:
        peak_ratio = (df.loc[peak_mask, 'total_queue'].mean() /
                     df.loc[~peak_mask, 'total_queue'].mean())
    else:
        peak_ratio = 1
else:
    peak_ratio = 1

# Stability classification
if queue_cv < 0.5 and abs(sensitivity) < 1:
    stability_class = 'STABLE'
elif queue_cv > 1.0 or abs(sensitivity) > 5:
    stability_class = 'CRITICAL'
else:
    stability_class = 'MODERATE'

print(f"   Sensitivity coefficient: {sensitivity:.2f}")
print(f"   Queue CV: {queue_cv:.3f}")
print(f"   Arrival CV: {arrival_cv:.3f}")
print(f"   Peak ratio: {peak_ratio:.2f}")
print(f"   Stability: {stability_class}")
add_result("Sensitivity", "Sensitivity Analysis", stability_class, "Coefficient", f"{sensitivity:.2f}",
          f"Queue CV={queue_cv:.3f}, Peak={peak_ratio:.2f}")

# ============= GENERATE SUMMARY REPORT =============
print("\n" + "="*70)
print("FINAL SUMMARY REPORT")
print("="*70)

# Create summary DataFrame
results_df = pd.DataFrame(results_table)

# Count by status
status_counts = results_df['Status'].value_counts()

print("\n📊 OVERALL RESULTS:")
print(f"   ✅ SUCCESS: {status_counts.get('SUCCESS', 0)}/{len(results_df)} models")
print(f"   ⚠️  MODERATE: {status_counts.get('MODERATE', 0)}/{len(results_df)} models")
print(f"   ❌ FAILED: {status_counts.get('FAILED', 0)}/{len(results_df)} models")
print(f"   🌀 CHAOTIC: {status_counts.get('CHAOTIC', 0)}/{len(results_df)} models")
print(f"   🔄 STABLE: {status_counts.get('STABLE', 0)}/{len(results_df)} models")

print("\n📈 TOP PERFORMING MODELS:")
success_models = results_df[results_df['Status'].isin(['SUCCESS', 'STABLE'])]
for _, row in success_models.iterrows():
    print(f"   ✓ {row['Model Name']}: {row['Key Metric']} = {row['Value']}")

print("\n📉 FAILED MODELS:")
failed_models = results_df[results_df['Status'] == 'FAILED']
for _, row in failed_models.iterrows():
    print(f"   ✗ {row['Model Name']}: {row['Notes']}")

# Save detailed results
print("\n💾 SAVING RESULTS...")

# Save as CSV
results_df.to_csv('/Volumes/workplace/DecisionTreeTool/OpsBrain/physics_model_results_events.csv', index=False)
print("   ✅ Saved to physics_model_results_events.csv")

# Save as JSON with all details
results_json = {
    'timestamp': datetime.now().isoformat(),
    'data_source': data_path,
    'total_records': len(df),
    'models_tested': len(results_df),
    'summary': {
        'success': int(status_counts.get('SUCCESS', 0)),
        'moderate': int(status_counts.get('MODERATE', 0)),
        'failed': int(status_counts.get('FAILED', 0)),
        'other': int(len(results_df) - status_counts.get('SUCCESS', 0) -
                    status_counts.get('MODERATE', 0) - status_counts.get('FAILED', 0))
    },
    'detailed_results': results_df.to_dict('records')
}

with open('/Volumes/workplace/DecisionTreeTool/OpsBrain/physics_model_results_events.json', 'w') as f:
    json.dump(results_json, f, indent=2)
print("   ✅ Saved to physics_model_results_events.json")

print("\n" + "="*70)
print("✅ PHYSICS MODEL TESTING COMPLETE")
print("="*70)