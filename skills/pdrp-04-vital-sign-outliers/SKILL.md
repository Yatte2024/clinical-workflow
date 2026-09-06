---
name: pdrp-04-vital-sign-outliers
description: >
  PDRP RO #4: Review for clinically significant vital sign abnormalities
  from baseline that may need adverse event reporting. Use when checking
  vital signs data. Primary reviewer: Clinical Reviewer. Automation: semi.
---

# PDRP Check #4: Vital Sign Abnormalities

## Review Objective

Review for any abnormal changes in the vital signs from baseline which may
need to be reported as an adverse event. Clinically significant vital sign
abnormalities should be reported as adverse events.

**CDW Forms:** `vits`, `subject`/`demog`
**Primary Reviewer:** Clinical Reviewer
**Automation Level:** Semi — agent flags candidates, clinician determines
clinical significance.

## Step 0: Schema Discovery (MANDATORY)

Before running ANY query, call `the schema-discovery tool` on the data folder. Then identify:
1. **Subject ID column** — look for SUBJECT, SUBJID, SUBJECTID across forms
2. **Exact column names** in `vits` for: test name, result value, result unit, collection date, visit (if available)
3. **Whether `subject` or `demog` form exists** — needed for site/arm context
4. **Test name values** — run a profiling query to discover how vital sign tests are named

Map discovered columns to the `{PLACEHOLDER}` variables in the SQL templates below.
Do NOT proceed until column names are confirmed from the schema.

### CDW Data Notes
- No population flags (SAFFL, ITTFL) — report all subjects
- **No VSBLFL (baseline flag)** — derive baseline as the first recorded value per subject per test
- Possible audit trail duplicates — deduplicate on (subject + test + date); if a sequence column exists, add it as ORDER BY tiebreaker
- Test names may be full names (e.g., "Systolic Blood Pressure") not codes (e.g., "SYSBP")
- Result values may be stored as strings — use TRY_CAST to numeric
- No ADaM ADVS dataset available — work directly from CDW `vits` form

### Pre-Query: Profile Vital Sign Test Names

```sql
SELECT DISTINCT {TEST_COL}, COUNT(*) AS n
FROM vits
GROUP BY {TEST_COL}
ORDER BY n DESC
```

Use results to identify which test name values correspond to:
- Systolic Blood Pressure (SYSBP)
- Diastolic Blood Pressure (DIABP)
- Heart Rate / Pulse (HR/PULSE)
- Temperature, Weight, Respiratory Rate, etc.

Map these to `{SYSBP_VALUE}`, `{DIABP_VALUE}`, `{HR_VALUE}` below.

## Detection Logic

### Placeholder Reference

| Placeholder | Description | Example CDW Columns |
|-------------|-------------|-------------------|
| `{SUBJECT_COL}` | Subject identifier | SUBJECT, SUBJID, SUBJECTID |
| `{TEST_COL}` | Vital sign test name | VSTEST, VSTESTCD, TEST_NAME |
| `{RESULT_COL}` | Result value | VSORRES, VSSTRESN, RESULT |
| `{UNIT_COL}` | Result unit (if available) | VSORRESU, VSSTRESU, UNIT |
| `{DATE_COL}` | Collection date | VSDTC, VSDAT, COLLECT_DATE |
| `{VISIT_COL}` | Visit name (if available) | VISIT, VISITNAM |
| `{SITE_COL}` | Site ID (from subject/demog) | SITEID, SITE |
| `{ARM_COL}` | Treatment arm (from subject/demog) | ARM, TREATMENT, TRT |
| `{SYSBP_VALUE}` | Test name for systolic BP | 'Systolic Blood Pressure', 'SYSBP' |
| `{DIABP_VALUE}` | Test name for diastolic BP | 'Diastolic Blood Pressure', 'DIABP' |
| `{HR_VALUE}` | Test name for heart rate | 'Heart Rate', 'Pulse', 'HR' |

### Query: Percentage Change from Baseline (Derived)

Baseline is derived as the **first recorded value** per subject per test
(no VSBLFL available in CDW data).

```sql
WITH vs_dedup AS (
  SELECT *, ROW_NUMBER() OVER (
    PARTITION BY {SUBJECT_COL}, {TEST_COL}, {DATE_COL}
    ORDER BY {DATE_COL}
  ) AS rn
  FROM vits
),
vs_clean AS (
  SELECT * FROM vs_dedup WHERE rn = 1
),
vs_numeric AS (
  SELECT {SUBJECT_COL}, {TEST_COL},
         TRY_CAST({RESULT_COL} AS DOUBLE) AS RESULT_NUM,
         {DATE_COL}
  FROM vs_clean
  WHERE TRY_CAST({RESULT_COL} AS DOUBLE) IS NOT NULL
),
vs_baseline AS (
  SELECT {SUBJECT_COL}, {TEST_COL}, RESULT_NUM AS BASELINE,
         ROW_NUMBER() OVER (
           PARTITION BY {SUBJECT_COL}, {TEST_COL}
           ORDER BY {DATE_COL} ASC
         ) AS rn
  FROM vs_numeric
),
vs_bl AS (
  SELECT {SUBJECT_COL}, {TEST_COL}, BASELINE
  FROM vs_baseline WHERE rn = 1
),
vs_post AS (
  SELECT vn.{SUBJECT_COL}, vn.{TEST_COL}, vn.{DATE_COL},
         vn.RESULT_NUM AS CURRENT_VALUE,
         bl.BASELINE,
         ROUND(100.0 * (vn.RESULT_NUM - bl.BASELINE)
               / NULLIF(bl.BASELINE, 0), 1) AS PCT_CHG,
         vn.RESULT_NUM - bl.BASELINE AS ABS_CHG
  FROM vs_numeric vn
  JOIN vs_bl bl ON vn.{SUBJECT_COL} = bl.{SUBJECT_COL}
    AND vn.{TEST_COL} = bl.{TEST_COL}
  WHERE vn.RESULT_NUM != bl.BASELINE
)
SELECT vp.{SUBJECT_COL}, dm.{SITE_COL}, dm.{ARM_COL},
       vp.{TEST_COL}, vp.{DATE_COL},
       vp.BASELINE, vp.CURRENT_VALUE,
       vp.ABS_CHG, vp.PCT_CHG
FROM vs_post vp
LEFT JOIN {DEMOG_TABLE} dm ON vp.{SUBJECT_COL} = dm.{SUBJECT_COL}
WHERE ABS(vp.PCT_CHG) > 20
   OR (UPPER(CAST(vp.{TEST_COL} AS VARCHAR)) LIKE '%' || UPPER('{SYSBP_VALUE}') || '%'
       AND (vp.CURRENT_VALUE >= 180 OR vp.CURRENT_VALUE <= 90))
   OR (UPPER(CAST(vp.{TEST_COL} AS VARCHAR)) LIKE '%' || UPPER('{DIABP_VALUE}') || '%'
       AND vp.CURRENT_VALUE >= 105)
   OR (UPPER(CAST(vp.{TEST_COL} AS VARCHAR)) LIKE '%' || UPPER('{HR_VALUE}') || '%'
       AND (vp.CURRENT_VALUE >= 120 OR vp.CURRENT_VALUE <= 50))
ORDER BY vp.{SUBJECT_COL}, vp.{TEST_COL}, vp.{DATE_COL}
```

**Notes:**
- Baseline derived from first recorded value per subject per test (no VSBLFL in CDW)
- `TRY_CAST` handles string results — non-numeric values excluded
- If `{VISIT_COL}` exists, include it in the SELECT for context
- If `{UNIT_COL}` exists, include it in the SELECT
- Adapt threshold conditions to match discovered `{TEST_COL}` values

## Findings Output Format

### PDRP Check #4: Vital Sign Abnormalities
**Data source:** CDW (Rave CRF) — `vits` form
**Baseline:** Derived from first recorded value (no VSBLFL in CDW)
**Subjects flagged:** {count}

| Subject | Site | Arm | Vital | Date | Baseline | Current | % Change | Flag |
|---------|------|-----|-------|------|----------|---------|----------|------|

Where Flag = "SBP >=180", "SBP <=90", "DBP >=105", "HR >=120", "HR <=50", or ">20% change".

**Notes:**
- Population flags unavailable in CDW data — all subjects reported.
- Baseline derived from first recorded value (no VSBLFL in CDW).
- Non-numeric vital sign results excluded from analysis.

## Draft Query Text

**Template 1 — Change from baseline:**
"Baseline {vital measurement} was noted to be {baseline}. Patient is noted to
now have a {vital measurement} of {current value} at {date}. Please confirm
if clinically significant and consider reporting an adverse event if clinically
significant."

**Template 2 — Absolute threshold:**
"{Vital measurement} of {current value} recorded at {date} exceeds the
clinically significant threshold. Please review and report as an adverse
event if considered clinically significant."

## Related Skills

- `vital-signs-monitoring` — PCS thresholds, weight change criteria, orthostatic checks
- `cdw-explorer` — CDW/Rave data navigation and column discovery
- `safety-signal-review` — Phase 4 covers vitals in systematic review
