---
name: pdrp-27-death-disposition-reconcile
description: >
  PDRP RO #27: Confirm Death is selected as primary reason for treatment
  discontinuation when AE outcome is death-related. Use when checking death
  data consistency. Primary reviewer: Clinical Reviewer. Automation: full.
---

# PDRP Check #27: Death Outcome vs Disposition Consistency

## Review Objective

Confirm Death is selected as the primary reason for treatment discontinuation
when the cause of death on the AE form is reported as Unknown, Sudden Death,
or Death "not otherwise specified."

Note: This RO is for the TREATMENT disposition page only.

**CDW Forms:** `aesae`, `stat`, `subject`/`demog`
**Primary Reviewer:** Clinical Reviewer
**Automation Level:** Full — pure cross-form consistency check.

## Step 0: Schema Discovery (MANDATORY)

Before running ANY query, call `the schema-discovery tool` on the data folder. Then identify:
1. **Subject ID column** — look for SUBJECT, SUBJID, SUBJECTID across forms
2. **Exact column names** in `aesae` for: AE term, outcome
3. **Exact column names** in `stat` for: disposition reason, disposition category, disposition date
4. **Whether `subject` or `demog` form exists** — needed for site/arm context

Map discovered columns to the `{PLACEHOLDER}` variables in the SQL templates below.
Do NOT proceed until column names are confirmed from the schema.

### CDW Data Notes
- No population flags (SAFFL, ITTFL) — report all subjects
- No DD (Death Details) form in CDW — skip secondary death domain check
- Possible audit trail duplicates — deduplicate on (subject + AE term + start date); if a sequence column exists (AESEQ, SEQ), add it as ORDER BY tiebreaker
- Date columns may vary by study — confirm exact names from schema
- Disposition category values vary — discover from schema (may not contain "TREATMENT")

## Detection Logic

### Placeholder Reference

| Placeholder | Description | Example CDW Columns |
|-------------|-------------|-------------------|
| `{SUBJECT_COL}` | Subject identifier | SUBJECT, SUBJID, SUBJECTID |
| `{AE_TERM_COL}` | AE verbatim term | AETERM, ADVERSE_EVENT |
| `{AE_DECODED_COL}` | AE decoded term (if available) | AEDECOD, AEPT |
| `{AE_OUTCOME_COL}` | AE outcome | AEOUT, OUTCOME |
| `{AE_START_COL}` | AE start date | AESTDAT, AESTDTC |
| `{DISP_REASON_COL}` | Disposition reason | DSDECOD, REASON, DISC_REASON |
| `{DISP_CAT_COL}` | Disposition category (if available) | DSCAT, CATEGORY |
| `{DISP_DATE_COL}` | Disposition date | DSSTDTC, DSDAT, DISC_DATE |
| `{SITE_COL}` | Site ID (from subject/demog) | SITEID, SITE, SITENO |
| `{ARM_COL}` | Treatment arm (from subject/demog) | ARM, TREATMENT, TRT |

### Pre-Query: Discover Disposition Values

Before the main query, run a profiling query to understand the disposition
data values:

```sql
SELECT DISTINCT {DISP_REASON_COL}, {DISP_CAT_COL}, COUNT(*) AS n
FROM stat
GROUP BY {DISP_REASON_COL}, {DISP_CAT_COL}
ORDER BY n DESC
```

Use the results to identify:
- Which value(s) represent "treatment discontinuation" in `{DISP_CAT_COL}`
- Whether "DEATH" appears as a disposition reason value

### Query: Death AE Outcome Without Death Disposition

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
)
SELECT ae.{SUBJECT_COL}, dm.{SITE_COL}, dm.{ARM_COL},
       ae.{AE_TERM_COL}, ae.{AE_OUTCOME_COL}, ae.{AE_START_COL},
       s.{DISP_REASON_COL} AS DISPOSITION_REASON,
       s.{DISP_DATE_COL} AS DISPOSITION_DATE
FROM ae_clean ae
LEFT JOIN {DEMOG_TABLE} dm ON ae.{SUBJECT_COL} = dm.{SUBJECT_COL}
LEFT JOIN stat s ON ae.{SUBJECT_COL} = s.{SUBJECT_COL}
  AND UPPER(CAST(s.{DISP_CAT_COL} AS VARCHAR)) LIKE '%TREATMENT%'
WHERE UPPER(CAST(ae.{AE_OUTCOME_COL} AS VARCHAR)) IN (
    'FATAL', 'DEATH', 'SUDDEN DEATH',
    'DEATH NOT OTHERWISE SPECIFIED', 'DIED')
  AND (s.{DISP_REASON_COL} IS NULL
       OR UPPER(CAST(s.{DISP_REASON_COL} AS VARCHAR)) NOT LIKE '%DEATH%')
ORDER BY ae.{SUBJECT_COL}
```

**Notes:**
- `{DEMOG_TABLE}` = `subject` or `demog` — whichever exists
- If `{DISP_CAT_COL}` doesn't exist, join on `stat` without category filter and note this in output
- If `{AE_DECODED_COL}` exists, include in SELECT

## Findings Output Format

### PDRP Check #27: Death Outcome vs Disposition
**Data source:** CDW (Rave CRF) — `aesae` + `stat` forms
**Subjects flagged:** {count}

| Subject | Site | Arm | AE Term | AE Outcome | Disposition Reason | Mismatch |
|---------|------|-----|---------|-----------|-------------------|----------|

**Note:** No Death Details (DD) form available in CDW — secondary death domain check skipped.

## Draft Query Text

"An Adverse Event has been reported with the outcome of '{AE outcome}'. The
primary reason for treatment discontinuation has NOT been reported as 'Death'.
Please review and consider updating reason for discontinuation to death if
appropriate."

## Related Skills

- `cdw-explorer` — CDW/Rave data navigation and column discovery
