# Decision Tree - Current State

## Mission Evolution: From Specific Validation to RCA System Proof

### Phase 1: Initial Confusion ❌
**Goal**: Match Mercury's specific tracking IDs in Heisenberg
**Problem**: No overlap between Mercury (Sept 2025) and Heisenberg (Dec 2024) data
**Learning**: Mercury appears to be test/training data, Heisenberg has real operational data

### Phase 2: Understanding Station Types ✅
**Discovery**: Station naming conventions
- D prefix = Delivery Station (e.g., DCM3)
- B prefix = Fulfillment Center
- S prefix = Sub Same Day (NOT Sort Center!)
- SWA1 = SSD FC (Sub Same Day Fulfillment Center)

### Phase 3: Pivot to RCA Validation ✅
**New Goal**: Validate bottleneck detection APPROACH, not specific data points
**Strategy**: Use DCM3's 4.4M events (Dec 17, 2024) to prove RCA logic

### Phase 4: Architecture Understanding ✅
**LLM-Powered RCA System Components**:
```
Modules (M1-M4) → Sensitivity Analysis → Alert Thresholds → Root Cause
```
**Key**: M1-M4 are project modules, not container states!

### Phase 5: Current Focus - Sensitivity Analysis 🚀

#### Decision: Test Sensitivity Across 30 Stations
**Why**: Need to understand how different stations respond to load

**Approach**:
1. **Baseline**: Calculate Little's Law (L = λW) for normal operations
2. **Stress Test**: Increase arrival rate λ, measure impact on W
3. **Breaking Point**: Find where L >> λW (system breaks down)
4. **Classification**: Rank stations as stable/sensitive/critical

#### Key SQL Components:
```sql
-- Sensitivity Coefficient
Δ(dwell_time) / Δ(arrival_rate)

-- Coefficient of Variation
variance / mean (high = unstable)

-- Bottleneck Detection
WHEN arrivals > departures * 1.5 THEN 'BOTTLENECK'
```

### Files Created:
```
/OpsBrain/
├── comprehensive_rca_validation.sql     # Full validation package
├── sensitivity_analysis_rca.sql         # Sensitivity testing
├── littles_law_bottleneck_now.sql      # Simple bottleneck detection
├── real_bottleneck_detection.sql        # WHERE/WHEN analysis
└── validate_rca_system.sql             # Component validation
```

### Critical Decisions Made:
1. ✅ **Use real data** (DCM3 Dec 2024) instead of chasing Mercury test data
2. ✅ **Focus on approach validation** not specific tracking ID matches
3. ✅ **Test sensitivity** to understand system stability
4. ✅ **Apply Little's Law** as mathematical foundation
5. ✅ **Rank stations** by operational stability

### Next Decision Points:
- [ ] Which 30 stations to select? (Need RUSH volume > 1000/day)
- [ ] What sensitivity threshold indicates "critical"? (λ increase of 20%? 50%?)
- [ ] How to validate findings? (Compare with actual incident reports?)

### Success Metrics:
- Can identify bottlenecks BEFORE they become critical
- Sensitivity analysis predicts which stations need attention
- Little's Law accurately models system behavior
- Alert thresholds align with operational reality

### Current Status: READY TO EXECUTE
**Blocker**: None
**Next Action**: Run 30-station sensitivity analysis
**Confidence**: HIGH - have data, approach, and validation method