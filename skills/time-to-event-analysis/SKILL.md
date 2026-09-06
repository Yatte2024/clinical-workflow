---
name: time-to-event-analysis
description: >
  Use when performing time-to-event analysis, survival modeling, or hazard
  estimation on clinical trial data. Covers Kaplan-Meier estimation, Cox
  proportional hazards, concordance index evaluation, and competing risks.
  Requires ADTTE with AVAL (time), CNSR (censoring), PARAMCD, and TRT01A.
  Complements clinical-graphics (which has KM visualization specs) by
  adding the analysis layer.
---

# Survival Analysis for Clinical Trials

## Data Preparation: ADTTE → scikit-survival

Time-to-event data is stored in ADTTE (ADaM). Extract via DuckDB, then
convert to the structured array format scikit-survival requires.

### Step 1: Query ADTTE

```sql
-- Extract time-to-event data for a specific endpoint
SELECT t.USUBJID, t.PARAMCD, t.PARAM,
       t.AVAL,                          -- time (days, months)
       t.CNSR,                          -- 0=event, 1=censored (ADaM convention)
       t.STARTDT, t.ADT,               -- dates for verification
       s.TRT01A, s.AGE, s.SEX, s.RACE  -- covariates from ADSL
FROM adtte t
JOIN adsl s ON t.USUBJID = s.USUBJID
WHERE t.PARAMCD = 'OS'                  -- or 'PFS', 'EFS', 'DOR', 'TTR'
  AND s.ITTFL = 'Y'
ORDER BY t.USUBJID
```

Common PARAMCD values: `OS` (overall survival), `PFS` (progression-free survival),
`EFS` (event-free survival), `DOR` (duration of response), `TTR` (time to response).

### Step 2: Convert to scikit-survival Format

```python
import pandas as pd
import numpy as np
from sksurv.util import Surv

# df = result from DuckDB query above
# ADaM CNSR: 0=event, 1=censored → sksurv event: True=event, False=censored
y = Surv.from_arrays(
    event=(df['CNSR'] == 0).values,  # invert ADaM convention
    time=df['AVAL'].values
)

# Covariates for modeling
X = pd.get_dummies(df[['TRT01A', 'AGE', 'SEX', 'RACE']], drop_first=True)
```

**Critical:** ADaM uses CNSR=0 for event, CNSR=1 for censored. scikit-survival
uses event=True for event. Always invert.

## Model Selection

```
Start
├─ Need interpretable hazard ratios?
│  ├─ Yes → Cox PH (standard clinical reporting)
│  └─ No → Continue
│
├─ High-dimensional covariates (p > n)?
│  └─ Yes → CoxnetSurvivalAnalysis (elastic net)
│
├─ Complex non-linear relationships?
│  ├─ Large dataset (n > 1000) → GradientBoostingSurvivalAnalysis
│  └─ Smaller dataset → RandomSurvivalForest
│
└─ Default for clinical trials → Cox PH
    (regulatory submissions expect interpretable coefficients)
```

**For most clinical trial analyses, Cox PH is the standard.** Ensemble methods
are useful for exploratory biomarker analyses but not for primary endpoints
in regulatory submissions.

## Kaplan-Meier Estimation

Non-parametric survival estimate — the standard first step.

```python
from sksurv.nonparametric import kaplan_meier_estimator

for arm in df['TRT01A'].unique():
    mask = df['TRT01A'] == arm
    time_km, surv_km = kaplan_meier_estimator(
        (df.loc[mask, 'CNSR'] == 0).values,  # event indicator
        df.loc[mask, 'AVAL'].values            # time
    )
    median_idx = np.searchsorted(-surv_km, -0.5)
    median_surv = time_km[median_idx] if median_idx < len(time_km) else float('inf')
    print(f"{arm}: median survival = {median_surv:.1f} days")
```

**For KM plots:** Use the matplotlib template in `clinical-graphics`.
That skill has the full KM curve spec including number-at-risk table,
censoring marks, and CI shading.

### Log-Rank Test

```python
from lifelines.statistics import logrank_test

results = logrank_test(
    durations_A=drug_time, durations_B=placebo_time,
    event_observed_A=(drug_cnsr == 0), event_observed_B=(placebo_cnsr == 0)
)
print(f"Log-rank p = {results.p_value:.4f}")
```

## Cox Proportional Hazards

The standard model for treatment effect estimation in clinical trials.

### Basic Cox Model

```python
from sksurv.linear_model import CoxPHSurvivalAnalysis
from sklearn.preprocessing import StandardScaler

# Standardize continuous covariates (age, lab values)
scaler = StandardScaler()
X_scaled = X.copy()
X_scaled[['AGE']] = scaler.fit_transform(X[['AGE']])

# Fit
cox = CoxPHSurvivalAnalysis()
cox.fit(X_scaled, y)

# Hazard ratios
hr = pd.DataFrame({
    'covariate': X.columns,
    'coef': cox.coef_,
    'HR': np.exp(cox.coef_)
})
print(hr)
```

### Hazard Ratio with Confidence Interval

For regulatory reporting, use lifelines for CI extraction:

```python
from lifelines import CoxPHFitter

cph = CoxPHFitter()
cph.fit(df_model, duration_col='AVAL', event_col='EVENT')
cph.print_summary()
# Outputs: coef, exp(coef)=HR, se, z, p, 95% CI for HR
```

**Reporting format:** "HR = 0.65 (95% CI: 0.48–0.88), p = 0.005"

### Check Proportional Hazards Assumption

**Always verify before interpreting Cox model results.**

```python
# Schoenfeld residuals test
cph.check_assumptions(df_model, show_plots=True)
# If violated for a covariate: stratify on it or use time-varying coefficient
```

If PH assumption violated:
- **Stratify** on the offending covariate (`strata` parameter)
- **Add interaction with time** for time-varying effects
- **Use restricted mean survival time (RMST)** as an alternative

## Model Evaluation

### Concordance Index (C-index)

Measures discrimination — probability that predictions are concordant with outcomes.

```python
from sksurv.metrics import concordance_index_censored, concordance_index_ipcw

# Harrell's C-index: use when censoring < 40%
c_harrell = concordance_index_censored(
    y['event'], y['time'], cox.predict(X_scaled)
)[0]

# Uno's C-index: use when censoring ≥ 40% (more robust)
c_uno = concordance_index_ipcw(y_train, y_test, risk_scores)[0]
```

| C-index | Interpretation |
|---------|---------------|
| 0.50 | No discrimination (random) |
| 0.60–0.70 | Poor to acceptable |
| 0.70–0.80 | Good |
| 0.80+ | Excellent (rare for survival models) |

### Time-Dependent AUC

Evaluate discrimination at specific timepoints (6, 12, 24 months):

```python
from sksurv.metrics import cumulative_dynamic_auc

times = [182, 365, 730]  # 6mo, 1yr, 2yr in days
auc, mean_auc = cumulative_dynamic_auc(y_train, y_test, risk_scores, times)
```

### Integrated Brier Score

Assesses both discrimination and calibration:

```python
from sksurv.metrics import integrated_brier_score

surv_funcs = cox.predict_survival_function(X_test)
preds = np.row_stack([fn(times) for fn in surv_funcs])
ibs = integrated_brier_score(y_train, y_test, preds, times)
# Lower is better; 0.25 = no-information baseline
```

## Competing Risks

When multiple mutually exclusive event types exist (e.g., death from disease
vs death from other causes), treating competing events as censored biases KM
estimates upward.

```python
from sksurv.nonparametric import cumulative_incidence_competing_risks

# Event codes: 0=censored, 1=event of interest, 2=competing event
time_pts, cif_primary, cif_competing = cumulative_incidence_competing_risks(y)
```

**Use competing risks when:**
- Analyzing cause-specific mortality (cardiac death vs non-cardiac)
- Oncology: progression vs death without progression
- Multiple event types in ADTTE (different PARAMCD values for same subjects)

## Landmark Analysis

Assess survival conditional on surviving to a landmark time:

```sql
-- Subjects alive at 6-month landmark
SELECT USUBJID, TRT01A, AVAL, CNSR
FROM adtte
WHERE PARAMCD = 'OS' AND AVAL >= 182
```

Report as "12-month survival rate among patients alive at 6 months."
Useful when treatment effect is delayed (e.g., immunotherapy).

## Presentation Standards

### Required Elements for Survival Results

1. **Median survival** per arm with 95% CI
2. **Hazard ratio** with 95% CI and p-value
3. **Landmark rates** (6-month, 12-month, 24-month survival probability)
4. **Number at risk** at each timepoint
5. **KM curve** with censoring marks — see `clinical-graphics`
6. **Log-rank p-value**

### Reporting Template

```
Median OS: Drug 18.5 months (95% CI: 14.2–22.8) vs Placebo 12.1 months
(95% CI: 9.3–15.4). HR = 0.65 (95% CI: 0.48–0.88), log-rank p = 0.005.
12-month OS rate: Drug 68.2% vs Placebo 51.4%.
```

## Related Skills

- `clinical-graphics` — KM curve visualization spec with number-at-risk table
- `oncology-endpoints` — endpoint definitions (OS, PFS, DOR) and RECIST 1.1
- `statistical-testing` — general hypothesis testing and effect sizes
- `adam-explorer` — ADTTE variable reference (AVAL, CNSR, PARAMCD, STARTDT)
- `safety-signal-review` — time-to-onset analysis for safety events
