---
name: clinical-graphics
description: >
  Use when creating clinical trial visualizations. Defines standard specifications
  for forest plots, Kaplan-Meier curves, eDISH plots, waterfall plots, spider
  plots, swimmer plots, and line plots. Includes axis conventions, annotations,
  and data requirements for each plot type.
---

# Clinical Plot Library

## Forest Plot (Safety/Efficacy)

**Purpose:** Compare event rates across treatment arms for multiple endpoints
simultaneously.

**Axes:**
- X-axis: Risk difference (safety) or hazard ratio/odds ratio (efficacy), log scale
  for ratios. Reference line at 0 (risk difference) or 1.0 (ratio).
- Y-axis: Endpoints (PTs or SOCs), sorted by incidence (descending)

**Required elements:**
```
Term    | Drug n/N (%) | Placebo n/N (%) | RD (95% CI)  | [●──────●]
SOC A   | 15/100 (15.0)| 5/100 (5.0)     | 10.0 (2.1, 17.9) | ──●──
  PT 1  | 8/100 (8.0)  | 2/100 (2.0)     | 6.0 (0.1, 11.9)  | ──●──
  PT 2  | 7/100 (7.0)  | 3/100 (3.0)     | 4.0 (-2.0, 10.0) | ──●──
```

- Point estimate: filled square/circle
- 95% CI: horizontal line with endcaps
- Vertical reference line at null value (0 or 1.0)
- Regulatory preference: **absolute risk difference** for safety forest plots

**Data requirements:** AE incidence table by PT and arm with subject counts.

## Kaplan-Meier Curve

**Purpose:** Display time-to-event data with censoring.

**Axes:**
- X-axis: Time from randomization (weeks, months). Starts at 0.
- Y-axis: Survival/event-free probability (0.0 to 1.0). Do not truncate.

**Required elements:**
- Step function: right-continuous (drops at event times)
- Censoring marks: vertical tick marks (|) on each curve
- Multiple arms: distinct line styles AND colors
- Median survival: horizontal reference at 0.50 with vertical drop to X-axis

**Number-at-risk table (mandatory for regulatory):**
- Below X-axis, aligned to tick marks
- One row per arm
- Decreasing counts left to right

**Annotations:**
- Log-rank p-value (upper right or lower left)
- Hazard ratio with 95% CI
- Median time per arm with 95% CI

**Data requirements:** ADTTE with AVAL (time), CNSR (0=event, 1=censored), per arm.

## eDISH Plot

**Purpose:** Screen for drug-induced liver injury (Hy's Law).

**Axes:**
- X-axis: Peak ALT (×ULN), **log scale**
- Y-axis: Peak total bilirubin (×ULN), **log scale**

**Quadrant lines:**
- Vertical at ALT = 3× ULN
- Horizontal at TBILI = 2× ULN

**Quadrant labels:**
- Upper-left: Temple's Corollary
- Upper-right: **Hy's Law** (highlight — this is the concern zone)
- Lower-left: Normal
- Lower-right: Hepatocellular

**Points:** Each point = one subject. Color/shape by treatment arm.

**Data requirements:** Peak post-baseline ALT and TBILI per subject from ADLB.
See `liver-safety` skill for SQL.

## Waterfall Plot (Oncology)

**Purpose:** Show best tumor response across all subjects.

**Axes:**
- X-axis: Subjects sorted by % change (best response on left)
- Y-axis: Best % change from baseline in sum of longest diameters (SLD)

**Reference lines:**
- Horizontal at -30% (RECIST 1.1 partial response threshold)
- Horizontal at +20% (RECIST 1.1 progressive disease threshold)
- Optional: horizontal at 0%

**Bars:**
- Color by best overall response: CR (green), PR (blue), SD (yellow), PD (red)
- Subjects with new lesions only: distinct marker (cannot show as % change)
- Not evaluable: exclude or show at 0% with distinct pattern

**Data requirements:** ADRS or ADTR with best % change from baseline in SLD
per subject, plus BOR category.

## Spider Plot (Oncology)

**Purpose:** Show individual tumor trajectories over time.

**Axes:**
- X-axis: Time from baseline (weeks or cycles)
- Y-axis: % change from baseline in SLD

**Reference lines:**
- Horizontal at -30% (PR threshold)
- Horizontal at +20% (PD threshold)
- Horizontal at 0%

**Lines:**
- Each line = one subject
- Color by best overall response or treatment arm
- Lines terminate at last assessment
- Optional markers at each assessment timepoint

**Data requirements:** ADTR with % change from baseline at each assessment visit.

## Swimmer Plot (Oncology)

**Purpose:** Show treatment duration and response events per subject over time.

**Axes:**
- X-axis: Time from first dose (weeks or months)
- Y-axis: Subjects (one row per subject, sorted by duration or response)

**Elements:**
- Horizontal bars: treatment duration per subject
- Bar color: best overall response
- Event markers on bars:
  - ● First response (PR or CR)
  - ▲ Response confirmation
  - ✕ Disease progression
  - ★ Death
  - → Still on treatment (open arrow at bar end)

**Sort order:** Longest duration on top (convention).

**Data requirements:** ADSL treatment dates, ADRS response dates, progression
dates, death dates.

## Line Plot (Vital Signs / Labs Over Time)

**Purpose:** Show mean change from baseline by visit and arm.

**Axes:**
- X-axis: Visit or timepoint (ordered chronologically)
- Y-axis: Mean change from baseline ± SE (or SD)

**Elements:**
- One line per treatment arm, distinct colors/styles
- Error bars: ± 1 SE (standard) or ± 1 SD
- Points at each visit with jittering if arms overlap
- Reference line at y = 0

**Presentation:**
- One plot per parameter (SBP, DBP, pulse, etc.)
- Consistent axis ranges across parameters for comparison
- Note sample size at each timepoint if attrition is substantial

**Data requirements:** ADVS or ADLB with AVISIT, CHG, per arm.

## Spaghetti Plot (Individual Trajectories)

**Purpose:** Show individual subject values over time for flagged parameters.

**Axes:**
- X-axis: Time or visit
- Y-axis: Actual value (AVAL) or change from baseline (CHG)

**Elements:**
- Each line = one subject
- Thin lines, slight transparency (alpha=0.3-0.5)
- Color by treatment arm
- Optional reference lines for thresholds (e.g., 3× ULN for ALT)
- Highlight specific subjects of concern (thicker line, labeled)

**Best for:** Small groups of flagged subjects (e.g., Hy's Law cases, PCS
outliers). Not useful for >50 subjects per arm.

**Data requirements:** ADLB or ADVS with AVAL at each visit.

## Color Palettes

**Standard treatment arm colors (colorblind-safe):**
| Arm | Color | Hex |
|-----|-------|-----|
| Placebo | Gray | #808080 |
| Drug Low | Blue | #0072B2 |
| Drug Mid | Orange | #E69F00 |
| Drug High | Red | #D55E00 |
| Active Comparator | Green | #009E73 |

Based on Wong (2011) colorblind-safe palette. Always include line styles
(solid, dashed, dotted) for B&W printing.

## Python Templates

### Kaplan-Meier Curve (numpy + matplotlib only)

Use this template for any KM plot. No `lifelines` dependency needed.

```python
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

def km_estimate(time, event):
    """Kaplan-Meier survival estimate with Greenwood 95% CI.

    Args:
        time: array of follow-up times
        event: array where 1=event, 0=censored
    Returns:
        times, surv, ci_lo, ci_hi, censor_times, censor_surv
    """
    order = np.argsort(time)
    t, e = np.asarray(time)[order], np.asarray(event)[order]
    unique_times = np.sort(np.unique(t[e == 1]))

    times, surv = [0.0], [1.0]
    greenwood_sum = 0.0
    ci_lo, ci_hi = [1.0], [1.0]
    n_total = len(t)

    for ut in unique_times:
        n_risk = np.sum(t >= ut)
        n_event = np.sum((t == ut) & (e == 1))
        s = surv[-1] * (1 - n_event / n_risk)
        if n_risk > n_event:
            greenwood_sum += n_event / (n_risk * (n_risk - n_event))
        se = s * np.sqrt(greenwood_sum)
        surv.append(s)
        times.append(ut)
        ci_lo.append(max(0, s - 1.96 * se))
        ci_hi.append(min(1, s + 1.96 * se))

    # Censored tick marks — find survival at each censoring time
    censor_times = t[e == 0]
    censor_surv = []
    t_arr, s_arr = np.array(times), np.array(surv)
    for ct in censor_times:
        idx = np.searchsorted(t_arr, ct, side='right') - 1
        censor_surv.append(s_arr[max(0, idx)])

    return (np.array(times), np.array(surv),
            np.array(ci_lo), np.array(ci_hi),
            np.array(censor_times), np.array(censor_surv))

def number_at_risk(time, event, eval_times):
    """Count subjects still at risk at each evaluation time."""
    return [int(np.sum(time >= t)) for t in eval_times]

# --- Plot ---
fig, (ax_km, ax_nar) = plt.subplots(
    2, 1, figsize=(10, 7), gridspec_kw={'height_ratios': [4, 1]},
    sharex=True
)

colors = {'Placebo': '#808080', 'Drug': '#0072B2'}
arms = df['TRT01A'].unique()
eval_pts = np.linspace(0, df['TIME_DAYS'].max(), 6)

for arm in arms:
    mask = df['TRT01A'] == arm
    t_arr = df.loc[mask, 'TIME_DAYS'].values
    e_arr = (1 - df.loc[mask, 'CNSR']).values  # CNSR: 0=event, 1=censored
    times, surv, lo, hi, ct, cs = km_estimate(t_arr, e_arr)
    c = colors.get(arm, '#333333')

    ax_km.step(times, surv, where='post', color=c, linewidth=2, label=arm)
    ax_km.fill_between(times, lo, hi, step='post', alpha=0.15, color=c)
    ax_km.plot(ct, cs, '|', color=c, markersize=8)  # censoring marks

    nar = number_at_risk(t_arr, e_arr, eval_pts)
    ax_nar.text(-0.02, arm, f'{arm}', transform=ax_nar.get_yaxis_transform(),
                ha='right', va='center', fontsize=9)

ax_km.set_ylim(0, 1.05)
ax_km.set_ylabel('Survival Probability')
ax_km.axhline(0.5, color='gray', linestyle=':', linewidth=0.8)
ax_km.legend(loc='lower left')
ax_km.set_title('Kaplan-Meier Estimate')
ax_nar.set_xlabel('Time (days)')
ax_nar.set_title('Number at Risk', fontsize=9, loc='left')
plt.tight_layout()
```

**Adapt this template — do not start from scratch.** Replace column names
(TRT01A, TIME_DAYS, CNSR) to match the actual data. Add log-rank p-value
and hazard ratio annotations when available.

## Related Skills

- Use `liver-safety` for eDISH plot data preparation and interpretation
- Use `vital-signs-monitoring` for which vital signs plots to produce
- Use `safety-signal-review` for which visualizations to use in each review phase
- Use `publication-quality` (Wave 3) for journal formatting standards
