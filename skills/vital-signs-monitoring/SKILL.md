---
name: vital-signs-monitoring
description: >
  Use when reviewing vital signs data (blood pressure, heart rate, temperature,
  weight). Provides PCS thresholds, categorical outlier criteria, and analysis
  patterns. Use with adam-explorer for ADVS variable lookup.
---

# Vital Signs Review

## Vital Signs Parameters

| Parameter | ADaM PARAMCD | SDTM VSTESTCD | Unit |
|-----------|-------------|---------------|------|
| Systolic BP | SYSBP | SYSBP | mmHg |
| Diastolic BP | DIABP | DIABP | mmHg |
| Pulse / Heart Rate | PULSE (or HR) | PULSE (or HR) | bpm |
| Temperature | TEMP | TEMP | °C or °F |
| Weight | WEIGHT | WEIGHT | kg |
| Height | HEIGHT | HEIGHT | cm |
| BMI | BMI | — | kg/m² |
| Respiratory Rate | RESP | RESP | breaths/min |

## Potentially Clinically Significant (PCS) Thresholds

**Absolute value thresholds:**

| Parameter | PCS Low | PCS High |
|-----------|---------|----------|
| Systolic BP | ≤ 90 mmHg | ≥ 180 mmHg |
| Diastolic BP | ≤ 50 mmHg | ≥ 105 mmHg |
| Pulse | ≤ 50 bpm | ≥ 120 bpm |
| Temperature | ≤ 35.0 °C | ≥ 38.3 °C (≥ 38.0 °C in oncology) |
| Weight | — | — (use % change) |
| Respiratory Rate | ≤ 8 breaths/min | ≥ 25 breaths/min |

**Combined criteria (absolute AND change from baseline):**

A PCS value is most meaningful when BOTH conditions are met:

| Parameter | Direction | Absolute Threshold | AND CFB Threshold |
|-----------|-----------|-------------------|-------------------|
| Systolic BP | High | ≥ 180 mmHg | AND increase ≥ 20 mmHg |
| Systolic BP | Low | ≤ 90 mmHg | AND decrease ≥ 20 mmHg |
| Diastolic BP | High | ≥ 105 mmHg | AND increase ≥ 15 mmHg |
| Diastolic BP | Low | ≤ 50 mmHg | AND decrease ≥ 10 mmHg |
| Pulse | High | ≥ 120 bpm | AND increase ≥ 25 bpm |
| Pulse | Low | ≤ 50 bpm | AND decrease ≥ 25 bpm |

**Secondary thresholds (less conservative):**

| Parameter | Secondary Low | Secondary High |
|-----------|--------------|----------------|
| Systolic BP | ≤ 100 mmHg | ≥ 160 mmHg |
| Diastolic BP | ≤ 60 mmHg | ≥ 90 mmHg |
| Pulse | ≤ 55 bpm | ≥ 100 bpm |

## Weight Change Criteria

Weight change is assessed as **percent change from baseline**:

| Threshold | Significance |
|-----------|-------------|
| ≥ 7% increase | Clinically significant weight gain (FDA standard) |
| ≥ 7% decrease | Clinically significant weight loss |
| ≥ 5% change | Moderate threshold (some protocols) |
| ≥ 10% change | Severe threshold |

**DuckDB SQL for weight change:**

```sql
SELECT adsl.TRT01A, advs.USUBJID, advs.AVISIT,
       advs.AVAL, advs.BASE, advs.CHG,
       ROUND(100.0 * advs.CHG / NULLIF(advs.BASE, 0), 1) AS pchg,
       CASE
         WHEN 100.0 * advs.CHG / NULLIF(advs.BASE, 0) >= 7 THEN 'Gain ≥7%'
         WHEN 100.0 * advs.CHG / NULLIF(advs.BASE, 0) <= -7 THEN 'Loss ≥7%'
         ELSE 'Within range'
       END AS weight_flag
FROM advs
JOIN adsl ON advs.USUBJID = adsl.USUBJID
WHERE advs.PARAMCD = 'WEIGHT' AND adsl.SAFFL = 'Y'
  AND advs.ANL01FL = 'Y'
```

## Orthostatic Hypotension

**Standard definition (AAS/AAN consensus):**
- Systolic BP decrease ≥ 20 mmHg, OR
- Diastolic BP decrease ≥ 10 mmHg
- Measured within 1-3 minutes of standing from supine/sitting

**Requires positional data:** SDTM VS.VSPOS (SUPINE, SITTING, STANDING).
If ADVS has ATPT (analysis timepoint) with positional indicators, derive
the difference. Many studies do not collect orthostatic measurements —
note this limitation.

## Standard Analysis Approach

**Step 1: Summary statistics by visit and arm**

```sql
-- Mean change from baseline by visit and treatment
SELECT adsl.TRT01A, advs.PARAMCD, advs.PARAM, advs.AVISIT,
       COUNT(advs.CHG) AS n,
       ROUND(AVG(advs.CHG), 2) AS mean_chg,
       ROUND(STDDEV(advs.CHG), 2) AS sd_chg,
       ROUND(MIN(advs.CHG), 2) AS min_chg,
       ROUND(MAX(advs.CHG), 2) AS max_chg,
       ROUND(MEDIAN(advs.CHG), 2) AS median_chg
FROM advs
JOIN adsl ON advs.USUBJID = adsl.USUBJID
WHERE adsl.SAFFL = 'Y' AND advs.ANL01FL = 'Y'
  AND advs.ABLFL IS DISTINCT FROM 'Y'
  AND advs.PARAMCD IN ('SYSBP', 'DIABP', 'PULSE')
GROUP BY adsl.TRT01A, advs.PARAMCD, advs.PARAM, advs.AVISIT
ORDER BY advs.PARAMCD, advs.AVISIT, adsl.TRT01A
```

**Step 2: Categorical outlier analysis**

```sql
-- Count subjects meeting PCS criteria
WITH pcs_flags AS (
  SELECT advs.USUBJID, adsl.TRT01A, advs.PARAMCD,
    CASE
      WHEN advs.PARAMCD = 'SYSBP' AND advs.AVAL >= 180 AND advs.CHG >= 20 THEN 'PCS High'
      WHEN advs.PARAMCD = 'SYSBP' AND advs.AVAL <= 90  AND advs.CHG <= -20 THEN 'PCS Low'
      WHEN advs.PARAMCD = 'DIABP' AND advs.AVAL >= 105 AND advs.CHG >= 15 THEN 'PCS High'
      WHEN advs.PARAMCD = 'DIABP' AND advs.AVAL <= 50  AND advs.CHG <= -10 THEN 'PCS Low'
      WHEN advs.PARAMCD = 'PULSE' AND advs.AVAL >= 120 AND advs.CHG >= 25 THEN 'PCS High'
      WHEN advs.PARAMCD = 'PULSE' AND advs.AVAL <= 50  AND advs.CHG <= -25 THEN 'PCS Low'
    END AS pcs_flag
  FROM advs
  JOIN adsl ON advs.USUBJID = adsl.USUBJID
  WHERE adsl.SAFFL = 'Y' AND advs.ANL01FL = 'Y'
    AND advs.ABLFL IS DISTINCT FROM 'Y'
)
SELECT TRT01A, PARAMCD, pcs_flag,
       COUNT(DISTINCT USUBJID) AS n_subjects
FROM pcs_flags
WHERE pcs_flag IS NOT NULL
GROUP BY TRT01A, PARAMCD, pcs_flag
ORDER BY PARAMCD, pcs_flag, TRT01A
```

## Signal Detection for Vitals

**Flag if:**
- Mean CFB differs by > 5 mmHg (BP) or > 5 bpm (pulse) between arms at any visit
- PCS outlier incidence is > 2× in drug arm vs. comparator
- Dose-dependent trend in mean CFB across dose groups
- Individual subjects with sustained BP ≥ 160/100 across multiple visits

**Presentation:**
- Line plot: mean CFB ± SE by visit and arm (one plot per parameter)
- Bar chart: PCS outlier incidence (n/N, %) by arm
- Spaghetti plot: individual subject trajectories for flagged subjects

## Related Skills

- Use `adam-explorer` for ADVS variable lookup
- Use `safety-signal-review` Phase 4 for where vitals fit in the review
- Use `clinical-graphics` for line plot / spaghetti plot specs
