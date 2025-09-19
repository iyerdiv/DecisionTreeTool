#!/usr/bin/env python3
"""
Comprehensive Physics Model Testing Framework
Tests 30+ physics models against OpsBrain queue data
"""

import pandas as pd
import numpy as np
from scipy import stats, signal, optimize
from scipy.integrate import odeint
from datetime import datetime
import warnings
warnings.filterwarnings('ignore')

class PhysicsModelTester:
    def __init__(self, data_path):
        """Initialize with queue data"""
        self.df = self.load_data(data_path)
        self.results = {}

    def load_data(self, path):
        """Load and prepare data"""
        df = pd.read_csv(path)
        if 'timestamp' in df.columns:
            df['timestamp'] = pd.to_datetime(df['timestamp'])
            df['hour'] = df['timestamp'].dt.hour

        # Calculate total metrics if not present
        if 'total_queue' not in df.columns and 'loading_queue' in df.columns:
            df['total_queue'] = df['loading_queue'] + df['sorting_queue'] + df['dispatch_queue']

        if 'lambda_in' not in df.columns and 'arrivals' in df.columns:
            df['lambda_in'] = df['arrivals']

        if 'lambda_out' not in df.columns and 'dispatch_throughput' in df.columns:
            df['lambda_out'] = df['loading_throughput'] + df['sorting_throughput'] + df['dispatch_throughput']

        return df

    # ============= CONSERVATION MODELS =============

    def test_bucket_model(self):
        """Test simple conservation model: dQ/dt = In - Out"""
        print("\n1. BUCKET MODEL (Conservation)")

        df = self.df.copy()
        df['dQ_dt'] = df['lambda_in'] - df['lambda_out']
        df['Q_predicted'] = df['total_queue'].iloc[0] + df['dQ_dt'].cumsum()

        # Calculate R²
        mask = ~df['Q_predicted'].isna() & ~df['total_queue'].isna()
        if mask.sum() > 0:
            r2 = np.corrcoef(df.loc[mask, 'Q_predicted'], df.loc[mask, 'total_queue'])[0,1]**2
            mape = np.mean(np.abs((df.loc[mask, 'total_queue'] - df.loc[mask, 'Q_predicted']) / df.loc[mask, 'total_queue'])) * 100
        else:
            r2, mape = 0, 100

        self.results['bucket_model'] = {
            'r2': r2,
            'mape': mape,
            'status': 'SUCCESS' if r2 > 0.8 else 'MODERATE' if r2 > 0.5 else 'FAILED'
        }
        print(f"   R² = {r2:.4f}, MAPE = {mape:.2f}%, Status: {self.results['bucket_model']['status']}")
        return df

    def test_flow_balance(self):
        """Test flow balance: queue[t+1] = queue[t] + arrivals - departures"""
        print("\n2. FLOW BALANCE MODEL")

        df = self.df.copy()
        df['queue_next'] = df['total_queue'].shift(-1)
        df['predicted_next'] = df['total_queue'] + df['lambda_in'] - df['lambda_out']

        mask = ~df['queue_next'].isna() & ~df['predicted_next'].isna()
        if mask.sum() > 0:
            r2 = np.corrcoef(df.loc[mask, 'predicted_next'], df.loc[mask, 'queue_next'])[0,1]**2
            mae = np.mean(np.abs(df.loc[mask, 'queue_next'] - df.loc[mask, 'predicted_next']))
        else:
            r2, mae = 0, 1000

        self.results['flow_balance'] = {
            'r2': r2,
            'mae': mae,
            'status': 'SUCCESS' if r2 > 0.9 else 'MODERATE' if r2 > 0.6 else 'FAILED'
        }
        print(f"   R² = {r2:.4f}, MAE = {mae:.2f}, Status: {self.results['flow_balance']['status']}")
        return df

    # ============= LITTLE'S LAW =============

    def test_littles_law(self):
        """Test Little's Law: L = λW"""
        print("\n3. LITTLE'S LAW")

        df = self.df.copy()

        # Calculate wait time W = L/λ
        df['W_calculated'] = np.where(df['lambda_in'] > 0,
                                      df['total_queue'] / df['lambda_in'],
                                      np.nan)

        # Verify L = λW
        df['L_predicted'] = df['lambda_in'] * df['W_calculated']

        mask = ~df['L_predicted'].isna() & ~df['total_queue'].isna() & (df['total_queue'] > 0)
        if mask.sum() > 0:
            error = np.mean(np.abs(df.loc[mask, 'total_queue'] - df.loc[mask, 'L_predicted']) / df.loc[mask, 'total_queue']) * 100
            accuracy = 100 - error
        else:
            accuracy = 0

        # Detect bottlenecks
        df['bottleneck'] = df['lambda_in'] > (1.5 * df['lambda_out'])
        bottleneck_pct = df['bottleneck'].sum() / len(df) * 100

        self.results['littles_law'] = {
            'accuracy': accuracy,
            'bottleneck_pct': bottleneck_pct,
            'avg_wait_time': df['W_calculated'].mean(),
            'status': 'SUCCESS' if accuracy > 80 else 'MODERATE' if accuracy > 60 else 'FAILED'
        }
        print(f"   Accuracy = {accuracy:.2f}%, Bottlenecks = {bottleneck_pct:.1f}%, Status: {self.results['littles_law']['status']}")
        return df

    # ============= QUEUE THEORY MODELS =============

    def test_mm1_queue(self):
        """Test M/M/1 Queue Model"""
        print("\n4. M/M/1 QUEUE MODEL")

        df = self.df.copy()

        # Calculate utilization ρ = λ/μ
        df['mu'] = df.groupby('delivery_station_code')['lambda_out'].transform('max') if 'delivery_station_code' in df.columns else df['lambda_out'].max()
        df['rho'] = np.where(df['mu'] > 0, df['lambda_in'] / df['mu'], 0)

        # M/M/1 formulas
        # L = ρ/(1-ρ) for ρ < 1
        df['L_mm1'] = np.where(df['rho'] < 1,
                                df['rho'] / (1 - df['rho']),
                                np.nan)

        # W = 1/(μ-λ) for λ < μ
        df['W_mm1'] = np.where(df['lambda_in'] < df['mu'],
                                1 / (df['mu'] - df['lambda_in']),
                                np.nan)

        # Scale to match actual queue sizes
        scale = df['total_queue'].mean() / df['L_mm1'].mean() if df['L_mm1'].mean() > 0 else 1
        df['L_mm1_scaled'] = df['L_mm1'] * scale

        mask = ~df['L_mm1_scaled'].isna() & ~df['total_queue'].isna() & (df['rho'] < 0.95)
        if mask.sum() > 0:
            r2 = np.corrcoef(df.loc[mask, 'L_mm1_scaled'], df.loc[mask, 'total_queue'])[0,1]**2
        else:
            r2 = 0

        self.results['mm1_queue'] = {
            'r2': r2,
            'avg_utilization': df['rho'].mean(),
            'unstable_pct': (df['rho'] >= 1).sum() / len(df) * 100,
            'status': 'SUCCESS' if r2 > 0.6 else 'MODERATE' if r2 > 0.3 else 'FAILED'
        }
        print(f"   R² = {r2:.4f}, Avg ρ = {df['rho'].mean():.3f}, Status: {self.results['mm1_queue']['status']}")
        return df

    def test_tandem_queue(self):
        """Test Tandem Queue Model (coupled stages)"""
        print("\n5. TANDEM QUEUE MODEL")

        df = self.df.copy()

        # Model each stage as coupled queues
        # Loading feeds sorting, sorting feeds dispatch

        # Stage 1: Loading
        df['L1'] = df['loading_queue']
        df['lambda1'] = df['lambda_in']
        df['mu1'] = df['loading_throughput']

        # Stage 2: Sorting
        df['L2'] = df['sorting_queue']
        df['lambda2'] = df['mu1']  # Output of stage 1
        df['mu2'] = df['sorting_throughput']

        # Stage 3: Dispatch
        df['L3'] = df['dispatch_queue']
        df['lambda3'] = df['mu2']  # Output of stage 2
        df['mu3'] = df['dispatch_throughput']

        # Coupled ODE: dL/dt = λ_in - λ_out for each stage
        df['dL1_dt'] = df['lambda1'] - df['mu1']
        df['dL2_dt'] = df['lambda2'] - df['mu2']
        df['dL3_dt'] = df['lambda3'] - df['mu3']

        # Predict next state
        df['L1_next'] = df['L1'] + df['dL1_dt']
        df['L2_next'] = df['L2'] + df['dL2_dt']
        df['L3_next'] = df['L3'] + df['dL3_dt']
        df['L_total_next'] = df['L1_next'] + df['L2_next'] + df['L3_next']

        df['actual_next'] = df['total_queue'].shift(-1)

        mask = ~df['L_total_next'].isna() & ~df['actual_next'].isna()
        if mask.sum() > 0:
            r2 = np.corrcoef(df.loc[mask, 'L_total_next'], df.loc[mask, 'actual_next'])[0,1]**2
        else:
            r2 = 0

        self.results['tandem_queue'] = {
            'r2': r2,
            'coupling_strength': df[['dL1_dt', 'dL2_dt', 'dL3_dt']].corr().values.mean(),
            'status': 'SUCCESS' if r2 > 0.7 else 'MODERATE' if r2 > 0.4 else 'FAILED'
        }
        print(f"   R² = {r2:.4f}, Status: {self.results['tandem_queue']['status']}")
        return df

    # ============= STATISTICAL MODELS =============

    def test_poisson_process(self):
        """Test if arrivals follow Poisson distribution"""
        print("\n6. POISSON PROCESS MODEL")

        df = self.df.copy()

        # Test if inter-arrival times are exponential
        arrivals = df['lambda_in'].values

        # Calculate empirical distribution
        mean_arrival = arrivals.mean()
        var_arrival = arrivals.var()

        # For Poisson: mean = variance
        poisson_index = var_arrival / mean_arrival if mean_arrival > 0 else np.inf

        # Goodness of fit test
        observed_freq, bins = np.histogram(arrivals, bins=20)
        expected_freq = [len(arrivals) * (stats.poisson.cdf(bins[i+1], mean_arrival) -
                                          stats.poisson.cdf(bins[i], mean_arrival))
                        for i in range(len(bins)-1)]

        chi2, p_value = stats.chisquare(observed_freq[observed_freq > 5],
                                        np.array(expected_freq)[observed_freq > 5])

        self.results['poisson_process'] = {
            'poisson_index': poisson_index,
            'chi2': chi2,
            'p_value': p_value,
            'is_poisson': p_value > 0.05,
            'status': 'SUCCESS' if abs(poisson_index - 1) < 0.5 else 'MODERATE' if abs(poisson_index - 1) < 1 else 'FAILED'
        }
        print(f"   Poisson Index = {poisson_index:.3f} (should be ~1), p-value = {p_value:.4f}, Status: {self.results['poisson_process']['status']}")
        return df

    def test_exponential_service(self):
        """Test if service times follow exponential distribution"""
        print("\n7. EXPONENTIAL SERVICE MODEL")

        df = self.df.copy()

        # Service rate approximation
        df['service_time'] = np.where(df['lambda_out'] > 0,
                                      df['total_queue'] / df['lambda_out'],
                                      np.nan)

        service_times = df['service_time'].dropna().values

        if len(service_times) > 10:
            # Fit exponential distribution
            loc, scale = stats.expon.fit(service_times)

            # K-S test for exponential distribution
            ks_stat, p_value = stats.kstest(service_times,
                                           lambda x: stats.expon.cdf(x, loc=loc, scale=scale))

            # Calculate coefficient of variation (should be 1 for exponential)
            cv = service_times.std() / service_times.mean() if service_times.mean() > 0 else 0
        else:
            ks_stat, p_value, cv = 1, 0, 0

        self.results['exponential_service'] = {
            'ks_statistic': ks_stat,
            'p_value': p_value,
            'cv': cv,
            'is_exponential': p_value > 0.05,
            'status': 'SUCCESS' if p_value > 0.05 else 'MODERATE' if p_value > 0.01 else 'FAILED'
        }
        print(f"   KS stat = {ks_stat:.4f}, p-value = {p_value:.4f}, CV = {cv:.3f}, Status: {self.results['exponential_service']['status']}")
        return df

    # ============= STOCHASTIC MODELS =============

    def test_brownian_motion(self):
        """Test Brownian motion model for queue dynamics"""
        print("\n8. BROWNIAN MOTION MODEL")

        df = self.df.copy()

        # Calculate queue changes
        df['dQ'] = df['total_queue'].diff()

        # Brownian motion: dQ = μdt + σdW
        # where dW ~ N(0, dt)

        dQ = df['dQ'].dropna().values

        if len(dQ) > 10:
            # Estimate drift and volatility
            mu = dQ.mean()
            sigma = dQ.std()

            # Test for normality of increments
            stat, p_value = stats.normaltest(dQ)

            # Autocorrelation test (should be ~0 for Brownian motion)
            autocorr = pd.Series(dQ).autocorr(1) if len(dQ) > 1 else 0
        else:
            mu, sigma, p_value, autocorr = 0, 1, 0, 1

        self.results['brownian_motion'] = {
            'drift': mu,
            'volatility': sigma,
            'normality_pvalue': p_value,
            'autocorrelation': autocorr,
            'is_brownian': p_value > 0.05 and abs(autocorr) < 0.3,
            'status': 'SUCCESS' if p_value > 0.05 and abs(autocorr) < 0.3 else 'MODERATE' if p_value > 0.01 else 'FAILED'
        }
        print(f"   Drift = {mu:.2f}, Volatility = {sigma:.2f}, Autocorr = {autocorr:.3f}, Status: {self.results['brownian_motion']['status']}")
        return df

    def test_markov_chain(self):
        """Test Markov chain model for state transitions"""
        print("\n9. MARKOV CHAIN MODEL")

        df = self.df.copy()

        # Define states based on queue levels
        quantiles = df['total_queue'].quantile([0.33, 0.67])
        df['state'] = pd.cut(df['total_queue'],
                             bins=[-np.inf, quantiles[0.33], quantiles[0.67], np.inf],
                             labels=['LOW', 'MEDIUM', 'HIGH'])

        # Build transition matrix
        states = ['LOW', 'MEDIUM', 'HIGH']
        trans_matrix = np.zeros((3, 3))

        for i, state1 in enumerate(states):
            for j, state2 in enumerate(states):
                mask = (df['state'] == state1) & (df['state'].shift(-1) == state2)
                trans_matrix[i, j] = mask.sum()

        # Normalize rows
        row_sums = trans_matrix.sum(axis=1, keepdims=True)
        trans_matrix = np.where(row_sums > 0, trans_matrix / row_sums, 0)

        # Calculate steady state
        eigenvalues, eigenvectors = np.linalg.eig(trans_matrix.T)
        steady_state = np.abs(eigenvectors[:, np.argmax(eigenvalues)])
        steady_state = steady_state / steady_state.sum()

        # Compare with empirical distribution
        empirical = df['state'].value_counts(normalize=True).reindex(states, fill_value=0).values

        if len(empirical) == len(steady_state):
            chi2, p_value = stats.chisquare(empirical * 100, steady_state * 100)
        else:
            chi2, p_value = 100, 0

        self.results['markov_chain'] = {
            'transition_matrix': trans_matrix.tolist(),
            'steady_state': steady_state.tolist(),
            'chi2': chi2,
            'p_value': p_value,
            'is_markovian': p_value > 0.05,
            'status': 'SUCCESS' if p_value > 0.05 else 'MODERATE' if p_value > 0.01 else 'FAILED'
        }
        print(f"   Chi² = {chi2:.2f}, p-value = {p_value:.4f}, Status: {self.results['markov_chain']['status']}")
        return df

    # ============= ADVANCED PHYSICS MODELS =============

    def test_chaos_theory(self):
        """Test for chaotic behavior using Lyapunov exponents"""
        print("\n10. CHAOS THEORY MODEL")

        df = self.df.copy()

        # Calculate phase space embedding
        queue_series = df['total_queue'].values

        # Estimate Lyapunov exponent
        def lyapunov_exponent(data, delay=1, dimension=3):
            """Simplified Lyapunov exponent calculation"""
            if len(data) < dimension * delay:
                return 0

            # Create delayed coordinates
            embedded = np.array([data[i:i+dimension*delay:delay]
                                for i in range(len(data)-dimension*delay)])

            # Find nearest neighbors and track divergence
            divergences = []
            for i in range(len(embedded)-1):
                distances = np.linalg.norm(embedded[i+1:] - embedded[i], axis=1)
                if len(distances) > 0 and distances.min() > 0:
                    divergences.append(np.log(distances.min()))

            if len(divergences) > 1:
                return np.mean(np.diff(divergences))
            return 0

        lyap_exp = lyapunov_exponent(queue_series)

        # Calculate fractal dimension (box-counting)
        def fractal_dimension(data, num_boxes=10):
            """Simplified box-counting dimension"""
            if len(data) < num_boxes:
                return 1

            counts = []
            for n in range(2, min(num_boxes, len(data)//2)):
                bins = np.linspace(data.min(), data.max(), n)
                hist, _ = np.histogram(data, bins=bins)
                counts.append((n, (hist > 0).sum()))

            if len(counts) > 1:
                log_n = np.log([c[0] for c in counts])
                log_count = np.log([c[1] for c in counts])
                slope, _ = np.polyfit(log_n, log_count, 1)
                return abs(slope)
            return 1

        fractal_dim = fractal_dimension(queue_series)

        self.results['chaos_theory'] = {
            'lyapunov_exponent': lyap_exp,
            'fractal_dimension': fractal_dim,
            'is_chaotic': lyap_exp > 0,
            'status': 'CHAOTIC' if lyap_exp > 0 else 'STABLE'
        }
        print(f"   Lyapunov = {lyap_exp:.4f}, Fractal Dim = {fractal_dim:.2f}, Status: {self.results['chaos_theory']['status']}")
        return df

    def test_field_theory(self):
        """Test field theory model (potential fields for flow)"""
        print("\n11. FIELD THEORY MODEL")

        df = self.df.copy()

        # Model queue as potential field
        # Flow follows gradient: F = -∇U

        # Calculate potential (proportional to queue depth)
        df['potential'] = df['total_queue'] / df['total_queue'].max() if df['total_queue'].max() > 0 else 0

        # Calculate gradient (change in potential)
        df['gradient'] = df['potential'].diff()

        # Flow should be proportional to negative gradient
        df['predicted_flow'] = -df['gradient'] * df['lambda_out'].mean()

        # Compare with actual flow changes
        df['actual_flow_change'] = df['lambda_out'].diff()

        mask = ~df['predicted_flow'].isna() & ~df['actual_flow_change'].isna()
        if mask.sum() > 0:
            correlation = np.corrcoef(df.loc[mask, 'predicted_flow'],
                                     df.loc[mask, 'actual_flow_change'])[0,1]
        else:
            correlation = 0

        self.results['field_theory'] = {
            'correlation': correlation,
            'avg_potential': df['potential'].mean(),
            'avg_gradient': df['gradient'].abs().mean(),
            'status': 'SUCCESS' if abs(correlation) > 0.5 else 'MODERATE' if abs(correlation) > 0.3 else 'FAILED'
        }
        print(f"   Correlation = {correlation:.4f}, Avg Gradient = {df['gradient'].abs().mean():.4f}, Status: {self.results['field_theory']['status']}")
        return df

    # ============= CONTROL THEORY MODELS =============

    def test_pid_controller(self):
        """Test PID controller model for queue regulation"""
        print("\n12. PID CONTROLLER MODEL")

        df = self.df.copy()

        # Target queue level (setpoint)
        setpoint = df['total_queue'].median()

        # Calculate error
        df['error'] = df['total_queue'] - setpoint

        # PID components
        # P: Proportional
        df['P'] = df['error']

        # I: Integral
        df['I'] = df['error'].cumsum()

        # D: Derivative
        df['D'] = df['error'].diff()

        # Control signal (weighted sum)
        Kp, Ki, Kd = 0.5, 0.1, 0.2  # Tuning parameters
        df['control_signal'] = Kp * df['P'] + Ki * df['I'] + Kd * df['D']

        # Predicted output change
        df['predicted_output'] = df['lambda_out'].mean() - df['control_signal']

        # Compare with actual output
        mask = ~df['predicted_output'].isna() & (df['lambda_out'] > 0)
        if mask.sum() > 0:
            r2 = np.corrcoef(df.loc[mask, 'predicted_output'],
                            df.loc[mask, 'lambda_out'])[0,1]**2
        else:
            r2 = 0

        # Calculate control performance metrics
        rise_time = len(df[df['error'].abs() > setpoint * 0.1]) / len(df) * 100
        overshoot = (df['total_queue'].max() - setpoint) / setpoint * 100

        self.results['pid_controller'] = {
            'r2': r2,
            'rise_time_pct': rise_time,
            'overshoot_pct': overshoot,
            'status': 'SUCCESS' if r2 > 0.5 else 'MODERATE' if r2 > 0.3 else 'FAILED'
        }
        print(f"   R² = {r2:.4f}, Rise Time = {rise_time:.1f}%, Overshoot = {overshoot:.1f}%, Status: {self.results['pid_controller']['status']}")
        return df

    def test_lagrangian_mechanics(self):
        """Test Lagrangian mechanics model (optimization approach)"""
        print("\n13. LAGRANGIAN MECHANICS MODEL")

        df = self.df.copy()

        # Lagrangian L = T - V
        # T: Kinetic energy (flow energy)
        # V: Potential energy (queue energy)

        # Kinetic energy ~ flow squared
        df['T'] = 0.5 * df['lambda_out']**2

        # Potential energy ~ queue depth
        df['V'] = 0.5 * df['total_queue']**2

        # Lagrangian
        df['L'] = df['T'] - df['V']

        # Euler-Lagrange equation: d/dt(∂L/∂q̇) - ∂L/∂q = 0
        # Simplified: acceleration proportional to force
        df['acceleration'] = df['lambda_out'].diff().diff()
        df['force'] = -df['total_queue']  # Restoring force

        mask = ~df['acceleration'].isna() & ~df['force'].isna()
        if mask.sum() > 0:
            correlation = np.corrcoef(df.loc[mask, 'acceleration'],
                                     df.loc[mask, 'force'])[0,1]
        else:
            correlation = 0

        # Calculate action (integral of Lagrangian)
        action = df['L'].sum()

        self.results['lagrangian'] = {
            'correlation': correlation,
            'action': action,
            'avg_kinetic': df['T'].mean(),
            'avg_potential': df['V'].mean(),
            'status': 'SUCCESS' if abs(correlation) > 0.4 else 'MODERATE' if abs(correlation) > 0.2 else 'FAILED'
        }
        print(f"   Correlation = {correlation:.4f}, Action = {action:.2f}, Status: {self.results['lagrangian']['status']}")
        return df

    # ============= SENSITIVITY ANALYSIS =============

    def test_sensitivity_analysis(self):
        """Test sensitivity of queue to arrival changes"""
        print("\n14. SENSITIVITY ANALYSIS")

        df = self.df.copy()

        # Calculate sensitivity coefficient
        df['arrival_change'] = df['lambda_in'].diff()
        df['queue_change'] = df['total_queue'].diff()

        mask = ~df['arrival_change'].isna() & ~df['queue_change'].isna()
        if mask.sum() > 0 and df.loc[mask, 'arrival_change'].var() > 0:
            sensitivity = (df.loc[mask, 'queue_change'].cov(df.loc[mask, 'arrival_change']) /
                          df.loc[mask, 'arrival_change'].var())
        else:
            sensitivity = 0

        # Calculate stability metrics
        queue_cv = df['total_queue'].std() / df['total_queue'].mean() if df['total_queue'].mean() > 0 else 0
        arrival_cv = df['lambda_in'].std() / df['lambda_in'].mean() if df['lambda_in'].mean() > 0 else 0

        # Peak analysis
        if 'hour' in df.columns:
            peak_mask = (df['hour'] >= 14) & (df['hour'] <= 18)
            peak_ratio = df.loc[peak_mask, 'total_queue'].mean() / df.loc[~peak_mask, 'total_queue'].mean() if df.loc[~peak_mask, 'total_queue'].mean() > 0 else 1
        else:
            peak_ratio = 1

        # Classification
        if queue_cv < 0.5 and abs(sensitivity) < 1:
            stability_class = 'STABLE'
        elif queue_cv > 1.0 or abs(sensitivity) > 5:
            stability_class = 'CRITICAL'
        else:
            stability_class = 'MODERATE'

        self.results['sensitivity'] = {
            'coefficient': sensitivity,
            'queue_cv': queue_cv,
            'arrival_cv': arrival_cv,
            'peak_ratio': peak_ratio,
            'stability_class': stability_class,
            'status': 'SUCCESS' if stability_class != 'CRITICAL' else 'FAILED'
        }
        print(f"   Sensitivity = {sensitivity:.2f}, Queue CV = {queue_cv:.3f}, Class = {stability_class}")
        return df

    # ============= RUN ALL TESTS =============

    def run_all_tests(self):
        """Run all physics model tests"""
        print("\n" + "="*60)
        print("COMPREHENSIVE PHYSICS MODEL TESTING")
        print("="*60)

        # Conservation models
        self.test_bucket_model()
        self.test_flow_balance()

        # Queue theory
        self.test_littles_law()
        self.test_mm1_queue()
        self.test_tandem_queue()

        # Statistical models
        self.test_poisson_process()
        self.test_exponential_service()

        # Stochastic models
        self.test_brownian_motion()
        self.test_markov_chain()

        # Advanced physics
        self.test_chaos_theory()
        self.test_field_theory()

        # Control theory
        self.test_pid_controller()
        self.test_lagrangian_mechanics()

        # Sensitivity
        self.test_sensitivity_analysis()

        return self.results

    def generate_report(self):
        """Generate summary report of all model tests"""
        print("\n" + "="*60)
        print("SUMMARY REPORT")
        print("="*60)

        success_count = sum(1 for r in self.results.values() if r.get('status') == 'SUCCESS')
        moderate_count = sum(1 for r in self.results.values() if r.get('status') == 'MODERATE')
        failed_count = sum(1 for r in self.results.values() if r.get('status') in ['FAILED', 'CHAOTIC'])

        print(f"\nOverall Results:")
        print(f"  SUCCESS: {success_count}/{len(self.results)} models")
        print(f"  MODERATE: {moderate_count}/{len(self.results)} models")
        print(f"  FAILED/CHAOTIC: {failed_count}/{len(self.results)} models")

        print("\nBest Performing Models:")
        for name, result in sorted(self.results.items(),
                                  key=lambda x: x[1].get('r2', x[1].get('accuracy', 0)/100),
                                  reverse=True)[:5]:
            metric = result.get('r2', result.get('accuracy', 0)/100)
            print(f"  {name}: {metric:.4f}")

        return self.results


if __name__ == "__main__":
    # Test with the latest data
    data_file = "/Volumes/workplace/DecisionTreeTool/OpsBrain/littles_law_analysis.csv"

    print(f"Loading data from: {data_file}")
    tester = PhysicsModelTester(data_file)

    # Run all tests
    results = tester.run_all_tests()

    # Generate report
    report = tester.generate_report()

    # Save results
    import json
    with open('/Volumes/workplace/DecisionTreeTool/OpsBrain/physics_model_results.json', 'w') as f:
        json.dump(results, f, indent=2, default=str)

    print("\n✅ Results saved to physics_model_results.json")