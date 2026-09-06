---
name: pdrp-14-lab-ae-grade-consistency
description: >
  PDRP RO #14: Ensure lab-related AE terms have corresponding lab values
  and that AE grades align with CTCAE v5.0 criteria. Use when reviewing
  AE-lab consistency. Primary reviewer: Clinical Reviewer. Automation: semi.
---

# PDRP Check #14: Lab AE vs CTCAE Grading Alignment

## Review Objective

1. Review to ensure lab-related AE terms for protocol-specified labs have
   corresponding lab data values reported in the lab dataset.
2. Review protocol-specified lab data to ensure AEs are reported when
   appropriate.
3. Ensure lab-related AE grades are aligned to CTCAE grading (Grade 1-5)
   or intensity grading (mild, moderate, severe) as appropriate.

**CDW Forms:** `aesae`, `lab`, `subject`/`demog`
**Primary Reviewer:** Clinical Reviewer
**Automation Level:** Semi — agent identifies mismatches, clinician confirms.

## Step 0: Schema Discovery (MANDATORY)

Before running ANY query, call `the schema-discovery tool` on the data folder. Then identify:
1. **Subject ID column** — look for SUBJECT, SUBJID, SUBJECTID across forms
2. **Exact column names** in `aesae` for: AE term, decoded term (if available), start date, end date, severity, toxicity grade (if available)
3. **Exact column names** in `lab` for: test name/code, result value, result unit, normal range high/low (if available), collection date
4. **Whether `subject` or `demog` form exists** — needed for site/arm context

Map discovered columns to the `{PLACEHOLDER}` variables in the SQL templates below.
Do NOT proceed until column names are confirmed from the schema.

### CDW Data Notes
- No population flags (SAFFL, ITTFL) — report all subjects
- Possible audit trail duplicates — deduplicate on (subject + test + date) for labs; if a sequence column exists, add it as ORDER BY tiebreaker
- Lab results may be stored as strings — use TRY_CAST to numeric
- CDW lab forms may not have standard normal ranges (STNRHI/STNRLO) — check schema
- No ADLB/ATOXGR available — compute CTCAE grades from raw values
- Lab test identifiers may be full names (not LBTESTCD codes) — adapt matching

### Pre-Query: Profile Lab Test Names

```sql
SELECT DISTINCT {LAB_TEST_COL}, COUNT(*) AS n
FROM lab
GROUP BY {LAB_TEST_COL}
ORDER BY n DESC
```

Use results to identify which test name values correspond to ALT, AST,
bilirubin, ALP, neutrophils, platelets, hemoglobin, creatinine, etc.

## Detection Logic

### Placeholder Reference

| Placeholder | Description | Example CDW Columns |
|-------------|-------------|-------------------|
| `{SUBJECT_COL}` | Subject identifier | SUBJECT, SUBJID, SUBJECTID |
| `{AE_TERM_COL}` | AE verbatim term | AETERM, ADVERSE_EVENT |
| `{AE_DECODED_COL}` | AE decoded term (if available) | AEDECOD, AEPT |
| `{AE_START_COL}` | AE start date | AESTDAT, AESTDTC |
| `{AE_END_COL}` | AE end date | AEENDAT, AEENDTC |
| `{SEVERITY_COL}` | AE severity | AESEV, SEVERITY |
| `{TOXGRADE_COL}` | AE toxicity grade (if available) | AETOXGR, GRADE |
| `{LAB_TEST_COL}` | Lab test name/code | LBTEST, LBTESTCD, TEST_NAME |
| `{LAB_RESULT_COL}` | Lab result value | LBORRES, LBSTRESN, RESULT |
| `{LAB_HIGH_COL}` | Upper normal range (if available) | LBSTNRHI, UPPER_NORMAL |
| `{LAB_LOW_COL}` | Lower normal range (if available) | LBSTNRLO, LOWER_NORMAL |
| `{LAB_DATE_COL}` | Lab collection date | LBDTC, LBDAT, COLLECT_DATE |
| `{SITE_COL}` | Site ID (from subject/demog) | SITEID, SITE |
| `{ARM_COL}` | Treatment arm (from subject/demog) | ARM, TREATMENT, TRT |
| `{MATCH_COL}` | AE column for term matching | `{AE_DECODED_COL}` or `{AE_TERM_COL}` |
| `{ALT_TEST_VALUE}` | Lab test value for ALT | Discovered from pre-query (e.g., 'Alanine Aminotransferase') |
| `{AST_TEST_VALUE}` | Lab test value for AST | Discovered from pre-query (e.g., 'Aspartate Aminotransferase') |
| `{BILI_TEST_VALUE}` | Lab test value for bilirubin | Discovered from pre-query |
| `{ALP_TEST_VALUE}` | Lab test value for ALP | Discovered from pre-query |
| `{NEUT_TEST_VALUE}` | Lab test value for neutrophils | Discovered from pre-query |
| `{PLAT_TEST_VALUE}` | Lab test value for platelets | Discovered from pre-query |
| `{HGB_TEST_VALUE}` | Lab test value for hemoglobin | Discovered from pre-query |
| `{CREAT_TEST_VALUE}` | Lab test value for creatinine | Discovered from pre-query |

### Step 0b: Profile Lab Test Names (run BEFORE Step 1)

Run this query and map discovered values to the `{*_TEST_VALUE}` placeholders above.
These are **required** — the Step 1 query will match nothing without them.

### AE-to-Lab Mapping Table

Match AEs to lab parameters. Use discovered `{LAB_TEST_COL}` values:

| AE Preferred Term Pattern | Expected Lab Test (adapt to study values) |
|--------------------------|------------------------------------------|
| %TRANSAMINASE%, %ALT%, %SGPT%, %ALANINE AMINO% | ALT / Alanine Aminotransferase |
| %AST%, %SGOT%, %ASPARTATE AMINO% | AST / Aspartate Aminotransferase |
| %BILIRUBIN% | Bilirubin |
| %ALKALINE PHOSPHATASE% | ALP / Alkaline Phosphatase |
| %NEUTROP%, %NEUTROPHIL% | Neutrophils |
| %THROMBOCYTOP%, %PLATELET% | Platelets |
| %ANAEMIA%, %ANEMIA%, %HAEMOGLOBIN% | Hemoglobin |
| %LEUKOP%, %LEUCOP%, %WHITE BLOOD% | WBC / White Blood Cells |
| %CREATININE%, %RENAL% | Creatinine |
| %HYPONATR%, %SODIUM% DECREASED | Sodium |
| %HYPOKALA%, %POTASSIUM% DECREASED | Potassium |
| %HYPERGLYCAE%, %GLUCOSE% INCREASED | Glucose |

### Step 1: Query — AEs Without Corresponding Lab Values

```sql
WITH ae_dedup AS (
  SELECT *, ROW_NUMBER() OVER (
    PARTITION BY {SUBJECT_COL}, {AE_TERM_COL}, {AE_START_COL}
    ORDER BY {AE_START_COL}
  ) AS rn
  FROM aesae
),
ae_clean AS (
  SELECT * FROM ae_dedup WHERE rn = 1
),
lab_dedup AS (
  SELECT *, ROW_NUMBER() OVER (
    PARTITION BY {SUBJECT_COL}, {LAB_TEST_COL}, {LAB_DATE_COL}
    ORDER BY {LAB_DATE_COL}
  ) AS rn
  FROM lab
),
lab_clean AS (
  SELECT * FROM lab_dedup WHERE rn = 1
),
lab_ae_terms AS (
  SELECT ae.{SUBJECT_COL}, ae.{AE_TERM_COL}, ae.{MATCH_COL},
         ae.{AE_START_COL}, ae.{AE_END_COL}, ae.{SEVERITY_COL},
         CASE
           WHEN UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%TRANSAMINASE%'
             OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%ALANINE AMINO%'
             OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%ALT %'
             OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%SGPT%' THEN '{ALT_TEST_VALUE}'
           WHEN UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%ASPARTATE AMINO%'
             OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%AST %'
             OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%SGOT%' THEN '{AST_TEST_VALUE}'
           WHEN UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%BILIRUBIN%' THEN '{BILI_TEST_VALUE}'
           WHEN UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%ALKALINE PHOSPHATASE%' THEN '{ALP_TEST_VALUE}'
           WHEN UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%NEUTROP%' THEN '{NEUT_TEST_VALUE}'
           WHEN UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%THROMBOCYTOP%'
             OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%PLATELET%DECR%' THEN '{PLAT_TEST_VALUE}'
           WHEN UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%ANAEMIA%'
             OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%ANEMIA%' THEN '{HGB_TEST_VALUE}'
           WHEN UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%CREATININE%'
             OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%RENAL%' THEN '{CREAT_TEST_VALUE}'
         END AS EXPECTED_LAB_TEST
  FROM ae_clean ae
  WHERE UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%TRANSAMINASE%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%ALANINE AMINO%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%ALT %'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%ASPARTATE AMINO%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%AST %'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%BILIRUBIN%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%ALKALINE PHOSPHATASE%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%NEUTROP%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%THROMBOCYTOP%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%PLATELET%DECR%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%ANAEMIA%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%ANEMIA%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%CREATININE%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%RENAL%'
)
SELECT lat.{SUBJECT_COL}, lat.{AE_TERM_COL}, lat.{MATCH_COL},
       lat.{SEVERITY_COL}, lat.EXPECTED_LAB_TEST, lat.{AE_START_COL},
       TRY_CAST(lb.{LAB_RESULT_COL} AS DOUBLE) AS LAB_VALUE
FROM lab_ae_terms lat
LEFT JOIN lab_clean lb ON lat.{SUBJECT_COL} = lb.{SUBJECT_COL}
  AND UPPER(CAST(lb.{LAB_TEST_COL} AS VARCHAR)) = UPPER(lat.EXPECTED_LAB_TEST)
  AND CAST(lb.{LAB_DATE_COL} AS DATE) BETWEEN
      CAST(lat.{AE_START_COL} AS DATE) - INTERVAL '7' DAY
      AND CAST(lat.{AE_START_COL} AS DATE) + INTERVAL '7' DAY
WHERE lat.EXPECTED_LAB_TEST IS NOT NULL
ORDER BY lat.{SUBJECT_COL}, lat.{AE_START_COL}
```

**Notes:**
- `{ALT_TEST_VALUE}`, `{AST_TEST_VALUE}`, etc. = actual test name values discovered from the `lab` form profile query
- `TRY_CAST` handles string lab results gracefully — returns NULL for non-numeric
- `{MATCH_COL}` = `{AE_DECODED_COL}` if available, otherwise `{AE_TERM_COL}`

### Step 2: CTCAE Grade vs AE Severity Comparison

For records WITH lab values, compare computed CTCAE grade to AE severity.
Use the `toxicity-grading` skill for grading criteria. Key mismatches:
- AE severity = MILD but lab CTCAE grade >= 3
- AE severity = MODERATE but lab CTCAE grade >= 4
- Lab CTCAE grade >= 3 with no corresponding AE reported

If `{LAB_HIGH_COL}` and `{LAB_LOW_COL}` exist, compute xULN:

```sql
SELECT lb.{SUBJECT_COL}, lb.{LAB_TEST_COL},
       TRY_CAST(lb.{LAB_RESULT_COL} AS DOUBLE) AS LAB_VALUE,
       TRY_CAST(lb.{LAB_HIGH_COL} AS DOUBLE) AS ULN,
       ROUND(TRY_CAST(lb.{LAB_RESULT_COL} AS DOUBLE)
             / NULLIF(TRY_CAST(lb.{LAB_HIGH_COL} AS DOUBLE), 0), 2) AS xULN
FROM lab_clean lb
WHERE TRY_CAST(lb.{LAB_RESULT_COL} AS DOUBLE) IS NOT NULL
  AND TRY_CAST(lb.{LAB_HIGH_COL} AS DOUBLE) > 0
```

If normal range columns don't exist, note this in the output and compute
CTCAE grades from absolute values only (less precise but still informative).

## Findings Output Format

### PDRP Check #14: Lab AE / CTCAE Grading Alignment
**Data source:** CDW (Rave CRF) — `aesae` + `lab` forms
**Subjects flagged:** {count}

**Part A: Lab AEs without corresponding lab values**

| Subject | AE Term | AE Decoded | AE Start | Expected Lab | Lab Found? |
|---------|---------|-----------|----------|-------------|-----------|

**Part B: Grade mismatches (AE severity vs CTCAE lab grade)**

| Subject | AE Term | AE Severity | Lab Test | Lab Value | xULN | CTCAE Grade | Mismatch |
|---------|---------|-------------|----------|-----------|------|-------------|----------|

**Notes:**
- Population flags unavailable in CDW data — all subjects reported.
- Lab results coerced from string to numeric via TRY_CAST; non-numeric results excluded.

## Draft Query Text

"Lab-related adverse event '{AE term}' is reported as '{severity}'. The
corresponding lab value ({lab test} = {value}, {x}xULN, CTCAE Grade {grade})
suggests a different severity. Please review and confirm the adverse event
severity, or clarify."

## Related Skills

- `toxicity-grading` — CTCAE v5.0 grading tables for hepatic, hematology, chemistry
- `cdw-explorer` — CDW/Rave data navigation and column discovery
- `safety-signal-review` — Phase 3 covers lab safety
