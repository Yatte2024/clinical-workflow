---
name: oncology-endpoints
description: >
  Use when analyzing efficacy outcomes, response rates, or tumor assessments
  in clinical trials. Defines OS, PFS, ORR, DOR, DCR, BOR with RECIST 1.1
  criteria, GRADE evidence grading, ECOG performance status, and landmark
  analysis conventions. Requires ADRS, ADTTE, or ADSL. Complements
  time-to-event-analysis (which provides the modeling layer).
---

# Efficacy Endpoints Reference

## Outcome Metrics

### Survival Endpoints (from ADTTE)

| Endpoint | PARAMCD | Definition | Censoring Rule |
|----------|---------|------------|---------------|
| Overall Survival (OS) | `OS` | Time from randomization to death from any cause | Censored at last known alive date |
| Progression-Free Survival (PFS) | `PFS` | Time from randomization to progression or death | Censored at last adequate tumor assessment |
| Event-Free Survival (EFS) | `EFS` | Time from randomization to progression, death, or treatment discontinuation | Censored at last assessment |
| Duration of Response (DOR) | `DOR` | Time from first response to progression or death | Only in responders |
| Time to Response (TTR) | `TTR` | Time from randomization to first response | Only in responders |

```sql
-- Median PFS by arm with event counts
SELECT TRT01A,
       COUNT(DISTINCT USUBJID) AS n,
       COUNT(DISTINCT CASE WHEN CNSR = 0 THEN USUBJID END) AS events,
       ROUND(MEDIAN(CASE WHEN CNSR = 0 THEN AVAL END), 1) AS approx_median_pfs
FROM adtte
WHERE PARAMCD = 'PFS'
GROUP BY TRT01A
```

**Note:** True median PFS requires KM estimation — see `time-to-event-analysis` skill.
The SQL median is approximate and does not account for censoring.

### Response Endpoints (from ADRS)

| Endpoint | Definition | Numerator | Denominator |
|----------|------------|-----------|-------------|
| ORR | Objective Response Rate | CR + PR | All evaluable subjects |
| DCR | Disease Control Rate | CR + PR + SD | All evaluable subjects |
| BOR | Best Overall Response | Best response per subject | Per subject |
| CBR | Clinical Benefit Rate | CR + PR + SD ≥ 24 weeks | All evaluable subjects |

```sql
-- ORR by arm
SELECT TRT01A,
       COUNT(DISTINCT CASE WHEN AVALC IN ('CR', 'PR') THEN USUBJID END) AS responders,
       COUNT(DISTINCT USUBJID) AS n,
       ROUND(100.0 * COUNT(DISTINCT CASE WHEN AVALC IN ('CR', 'PR') THEN USUBJID END)
             / COUNT(DISTINCT USUBJID), 1) AS orr_pct
FROM adrs
WHERE PARAMCD = 'BOR' AND ANL01FL = 'Y'
GROUP BY TRT01A
```

## RECIST 1.1 Response Criteria

Standard criteria for solid tumor assessment (Response Evaluation Criteria
in Solid Tumors, version 1.1).

### Target Lesion Assessment

| Response | Criteria |
|----------|---------|
| Complete Response (CR) | Disappearance of all target lesions. Any pathological lymph nodes must have short axis < 10 mm |
| Partial Response (PR) | ≥ 30% decrease in sum of diameters from baseline |
| Progressive Disease (PD) | ≥ 20% increase in sum of diameters from nadir AND absolute increase ≥ 5 mm, OR new lesion |
| Stable Disease (SD) | Neither PR nor PD criteria met |

### Best Overall Response Derivation

BOR considers all assessments and requires confirmation for CR/PR:

| Best Response | Requirement |
|--------------|-------------|
| CR | CR confirmed ≥ 4 weeks later |
| PR | PR (or better) confirmed ≥ 4 weeks later, not qualifying for CR |
| SD | SD maintained for minimum interval (protocol-defined, often ≥ 6 weeks) |
| PD | Any PD assessment |
| NE | Not evaluable — insufficient assessments |

**For immunotherapy:** Use iRECIST, which adds iUPD (unconfirmed progression)
and iCPD (confirmed progression) to handle pseudoprogression.

## GRADE Evidence System

Grading of Recommendations, Assessment, Development and Evaluations.

| Grade | Recommendation | Evidence Quality |
|-------|---------------|-----------------|
| **1A** | Strong | High (RCT, consistent results) |
| **1B** | Strong | Moderate (RCT with limitations) |
| **2A** | Conditional | High (benefits/risks closely balanced) |
| **2B** | Conditional | Moderate |
| **2C** | Conditional | Low (observational data) |

**Evidence Quality Factors:**
- **Upgrade:** Large effect, dose-response, confounders favor null
- **Downgrade:** Risk of bias, inconsistency, indirectness, imprecision

## ECOG Performance Status

| Grade | Definition |
|-------|-----------|
| 0 | Fully active, no restrictions |
| 1 | Restricted in strenuous activity, ambulatory |
| 2 | Ambulatory, capable of self-care, up > 50% of waking hours |
| 3 | Limited self-care, confined to bed/chair > 50% of waking hours |
| 4 | Completely disabled, confined to bed/chair |
| 5 | Dead |

```sql
-- Baseline ECOG distribution by arm
SELECT TRT01A,
       ECOGBSL,
       COUNT(DISTINCT USUBJID) AS n
FROM adsl
WHERE ITTFL = 'Y'
GROUP BY TRT01A, ECOGBSL
ORDER BY TRT01A, ECOGBSL
```

ECOG is often a stratification factor and key covariate in Cox models.

## Landmark Survival Rates

Report survival probability at fixed timepoints alongside medians:

| Timepoint | Typical Use |
|-----------|------------|
| 6-month | Early signal, aggressive disease |
| 12-month | Standard for most oncology endpoints |
| 24-month | Long-term benefit, immunotherapy trials |
| 36-month, 60-month | Curative intent, adjuvant settings |

Include 95% CI for each landmark rate. See `time-to-event-analysis` for KM
estimation methods.

## Subgroup Analysis Best Practices

1. **Pre-specify** subgroups in the statistical analysis plan
2. **Report all subgroups** — do not cherry-pick favorable results
3. **Use forest plots** to display treatment effects across subgroups —
   see `clinical-graphics`
4. **Interaction tests** — test treatment × subgroup interaction, not
   within-subgroup p-values
5. **Label as exploratory** unless powered for the subgroup

Common subgroups: age (<65/≥65), sex, race, ECOG (0/≥1), PD-L1 expression,
biomarker status, geographic region, number of prior lines.

## Related Skills

- `time-to-event-analysis` — KM estimation, Cox PH modeling, C-index evaluation
- `statistical-testing` — hypothesis testing, effect sizes, power analysis
- `clinical-graphics` — forest plots, waterfall plots, swimmer plots
- `safety-signal-review` — safety endpoint analysis
- `adam-explorer` — ADRS, ADTTE variable reference
