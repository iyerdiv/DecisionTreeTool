# OpsBrain Current State - December 2024

## Mission: Validate RCA System Using Little's Law & Sensitivity Analysis

### Key Discoveries:
1. **SWA1 = SSD FC** (Sub Same Day Fulfillment Center), not Sort Center
   - Located at 607 Riverside Rd, Everett, WA 98201
   - S prefix = Sub Same Day delivery operations

2. **Found Real Data**: DCM3 station with 4.4M RUSH events on Dec 17, 2024
   - Table: `heisenbergrefinedobjects.d_perfectmile_shipment_status_history`
   - This is our validation dataset

3. **Architecture Understanding**:
   - M1-M4 are project modules, NOT container states
   - LLM-powered RCA system with sensitivity analysis components

4. **OpsBrain POC Source Located**:
   ```
   /Volumes/workplace/temp_extract/TO_ARCHIVE_workspace_archive_20250912_094840/
   opsbrain_backup_20250830/opsbrain_workspace/opsbrainpoc/src/OpsBrainPOC
   ```

## Current Focus: Sensitivity Analysis on 30 Real Stations

### Little's Law Application:
- **L = λW** (Inventory = Arrival Rate × Wait Time)
- When L grows faster than λ, we have a bottleneck
- Testing sensitivity: How does system respond to arrival rate changes?

### SQL Queries Created:
1. `comprehensive_rca_validation.sql` - Complete RCA validation package
2. `sensitivity_analysis_rca.sql` - Tests sensitivity to arrival rates, missing DEA, time of day
3. `littles_law_bottleneck_now.sql` - Simple bottleneck detection using Little's Law
4. `real_bottleneck_detection.sql` - Identifies WHERE and WHEN bottlenecks occur
5. `validate_rca_system.sql` - Validates all RCA system components

### Sensitivity Factors to Test:
1. **Arrival Rate (λ)**: How increased arrivals affect dwell time
2. **Missing DEA**: Impact of missing route codes on processing
3. **Time of Day**: Peak hour sensitivity (14:00-18:00)
4. **Multivariate**: Combined factor analysis

### Next Steps:
1. Identify 30 stations with sufficient RUSH volume
2. Calculate Little's Law baseline for each station
3. Measure sensitivity coefficients
4. Find where Little's Law breaks down (system instability)
5. Rank stations by sensitivity/stability
6. Validate with actual bottleneck events

### Key Insight:
We're not trying to match Mercury's specific tracking IDs anymore. Instead, we're validating that our RCA approach (Little's Law + Sensitivity Analysis) correctly identifies bottlenecks in real operational data.

## Success Criteria:
- Demonstrate bottleneck detection works on real data
- Show sensitivity analysis identifies unstable operating points
- Prove Little's Law predicts system behavior accurately
- Provide actionable thresholds for alerts

## Remember:
- Use DCM3 Dec 17, 2024 data as validation baseline
- Focus on RUSH packages (SSD with 30-min targets)
- 5-minute intervals critical for SSD analysis
- Sensitivity coefficient = Δ(output) / Δ(input)