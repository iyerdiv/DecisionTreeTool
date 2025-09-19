# Little's Law vs Sensitivity Analysis - Raw Data Comparison

## LITTLE'S LAW DATA (30 Stations)

### Overall Metrics:
- **Total observations**: 23,040 (hourly)
- **Bottleneck detection accuracy**: 82%
- **System-wide L**: 2,406,477 packages average
- **System-wide λ**: 37,146 packages/hour
- **System-wide W**: 449 minutes

### Bottleneck Distribution:
| Severity | Hours | Percentage |
|----------|-------|------------|
| SEVERE (λ > 1.5×throughput) | 4,568 | 19.8% |
| MODERATE (λ > 1.2×throughput) | 8 | 0.0% |
| MILD (λ > throughput) | 5 | 0.0% |
| NONE | 18,459 | 80.1% |

### Station-Specific Little's Law Results:
| Station | Avg L (Queue) | Avg λ (Arrivals/hr) | Avg W (min) | Bottleneck Hours | Anomaly Hours |
|---------|---------------|---------------------|-------------|------------------|---------------|
| DAE1 | 59,398 | 1,098 | 6,242 | 156 | 81 |
| DJT6 | 303,114 | 4,397 | 4,180 | 213 | 57 |
| DXT2 | 72,458 | 1,279 | 9,277 | 151 | 69 |
| DRI1 | 56,467 | 1,100 | 4,645 | 170 | 79 |
| DKY8 | 64,141 | 1,105 | 3,934 | 159 | 67 |
| DWA5 | 64,929 | 958 | 572 | Data needed | 64 |
| DID2 | 54,361 | 738 | 523 | Data needed | 62 |
| DVV2 | 24,006 | 520 | 5,727 | Data needed | 101 |
| DTY4 | 70,472 | 1,583 | 287 | Data needed | 92 |
| DLC1 | 32,823 | 616 | 370 | Data needed | 60 |

### Peak Hour Impact (14:00-18:00):
- Peak avg queue: 98,974 packages
- Off-peak avg queue: 75,280 packages
- **Peak multiplier: 1.31x**

---

## SENSITIVITY ANALYSIS DATA (Same 30 Stations)

### Overall Classification:
- **CRITICAL**: 8 stations (27%)
- **MODERATE**: 22 stations (73%)
- **STABLE**: 0 stations (0%)

### Detailed Sensitivity Metrics:
| Station | Class | Stability Score | Sensitivity | Queue CV | Peak Ratio | Anomaly Rate | Avg Queue | Avg Arrivals |
|---------|-------|-----------------|-------------|----------|------------|--------------|-----------|--------------|
| DWA5 | MODERATE | 0.681 | 0.18 | 0.954 | **2.89** | 8.3% | 64,929 | 958 |
| DID2 | CRITICAL | 0.529 | **4.28** | 1.017 | 2.03 | 8.1% | 54,361 | 738 |
| DVV2 | MODERATE | 0.375 | 0.27 | 0.935 | 1.34 | **13.2%** | 24,006 | 520 |
| DTY4 | CRITICAL | 0.367 | 0.99 | **1.066** | 1.11 | 12.0% | 70,472 | 1,583 |
| DLC1 | CRITICAL | 0.366 | 1.68 | 1.068 | 1.15 | 7.8% | 32,823 | 616 |
| DRI1 | MODERATE | 0.365 | 1.58 | 0.974 | 1.26 | 10.3% | 56,467 | 1,100 |
| DJT6 | MODERATE | 0.361 | 0.35 | 0.659 | 1.74 | 7.4% | 303,114 | 4,397 |
| DYO5 | CRITICAL | 0.353 | -0.54 | 1.038 | 1.10 | 10.7% | 37,375 | 685 |
| DIA4 | MODERATE | 0.351 | 2.05 | 0.915 | 1.28 | 10.4% | 60,636 | 997 |
| DOR3 | CRITICAL | 0.348 | -0.50 | 1.013 | 1.10 | 12.0% | 70,191 | 881 |
| DDP7 | MODERATE | 0.346 | 0.19 | 0.998 | 1.15 | 7.8% | 65,217 | 1,079 |
| DXT8 | CRITICAL | 0.343 | -0.22 | 1.027 | 1.07 | 10.4% | 37,766 | 618 |
| DDP9 | CRITICAL | 0.340 | -0.39 | 1.020 | 1.08 | 9.5% | 68,794 | 820 |
| DLX5 | MODERATE | 0.339 | -0.32 | 0.639 | 1.69 | 4.3% | 298,141 | 4,154 |
| DXT2 | MODERATE | 0.337 | 1.12 | 0.976 | 1.13 | 9.0% | 72,458 | 1,279 |
| DBO9 | MODERATE | 0.334 | -0.57 | 0.960 | 1.12 | 10.8% | 65,741 | 1,055 |
| DLT3 | MODERATE | 0.332 | 0.30 | 0.966 | 1.11 | 10.2% | 170,933 | 3,297 |
| DFL3 | MODERATE | 0.331 | 1.65 | 0.920 | 1.17 | 10.7% | 80,527 | 1,022 |
| DPH8 | MODERATE | 0.330 | 0.81 | 0.973 | 1.09 | 10.4% | 72,306 | 889 |
| DTO3 | CRITICAL | 0.328 | -0.34 | 1.010 | 1.03 | 10.2% | 26,848 | 407 |
| DDP3 | MODERATE | 0.327 | 0.17 | 0.987 | 1.06 | 9.5% | 78,375 | 1,178 |
| DFM4 | MODERATE | 0.326 | 0.11 | 0.951 | 1.11 | 9.0% | 63,788 | 890 |
| DKY8 | MODERATE | 0.325 | 0.82 | 0.927 | 1.15 | 8.7% | 64,141 | 1,105 |
| DAE1 | MODERATE | 0.322 | 0.34 | 0.941 | 1.09 | 10.5% | 59,398 | 1,098 |
| DGD3 | MODERATE | 0.322 | 1.25 | 0.901 | 1.19 | 6.5% | 35,089 | 755 |
| DBC3 | MODERATE | 0.318 | -0.15 | 0.907 | 1.14 | 8.9% | 79,920 | 1,345 |
| DAE3 | MODERATE | 0.317 | 0.95 | 0.950 | 1.08 | 8.3% | 60,995 | 612 |
| DYR3 | MODERATE | 0.314 | 0.56 | 0.982 | 1.01 | 8.7% | 43,618 | 710 |
| DAE7 | MODERATE | 0.293 | 0.23 | 0.845 | 1.09 | 10.5% | 102,351 | 1,182 |
| DYN7 | MODERATE | 0.264 | 0.96 | 0.733 | 1.13 | 8.7% | 85,697 | 1,176 |

---

## DIRECT CORRELATIONS TO FIND:

### 1. Bottleneck Hours vs Sensitivity Score
- Do high sensitivity stations have more bottleneck hours?

### 2. Queue CV vs Little's Law Error
- Do high variability stations break Little's Law more?

### 3. Peak Ratio vs Bottleneck Severity
- Do high peak ratios correlate with severe bottlenecks?

### 4. Sensitivity Coefficient vs W (Wait Time)
- Do sensitive stations have longer wait times?

### 5. Anomaly Rate Comparison
- Little's Law detected anomalies: varies by station
- Sensitivity anomaly rates: 4.3% to 13.2%

---

## KEY OBSERVATIONS FOR CORRELATION:

### Stations Appearing in Both "Problem" Lists:
- **DWA5**: High peak ratio (2.89x) + sensitivity issues
- **DID2**: Highest sensitivity (4.28) + CRITICAL class
- **DVV2**: Highest anomaly rate (13.2%)
- **DTY4**: High queue CV (1.066) + CRITICAL
- **DLC1**: High sensitivity (1.68) + CRITICAL

### Validation Questions:
1. Are CRITICAL sensitivity stations the ones with most bottleneck hours?
2. Does high Queue CV predict Little's Law breakdown?
3. Does Peak Ratio correlate with bottleneck frequency?

### Numbers to Compare:
- Little's Law: 19.8% severe bottlenecks
- Sensitivity: 27% CRITICAL stations
- Little's Law: 82% accuracy
- Sensitivity: 8-13% anomaly rates