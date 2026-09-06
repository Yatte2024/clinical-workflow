---
name: pdrp-20-prolonged-ae
description: >
  PDRP RO #20: Identify adverse events where 'Is the adverse event still
  ongoing' = Yes for more than 30 days. Use when reviewing long-duration AEs.
  Primary reviewer: Clinical Reviewer. Automation: full.
---

# PDRP Check #20: Ongoing Adverse Events >30 Days

## Review Objective

Review any events where the response to 'Is the adverse event still ongoing'
= Yes for more than 30 days.

**CDW Forms:** `aesae`, `stat`, `subject`/`demog`
**Primary Reviewer:** Clinical Reviewer
**Automation Level:** Full — pure date calculation, no clinical judgment needed
for detection.

## Step 0: Schema Discovery (MANDATORY)

Before running ANY query, call `the schema-discovery tool` on the data folder. Then identify:
1. **Subject ID column** — look for SUBJECT, SUBJID, SUBJECTID across forms
2. **Exact column names** in the `aesae` form for: AE term, start date, end date, ongoing flag, severity, seriousness, relatedness, outcome
3. **Whether `stat` form exists** — needed for disposition context
4. **Whether `subject` or `demog` form exists** — needed for site/arm context

Map discovered columns to the `{PLACEHOLDER}` variables in the SQL templates below.
Do NOT proceed until column names are confirmed from the schema.

### CDW Data Notes
- No population flags (SAFFL, ITTFL) — report all subjects
- Possible audit trail duplicates — deduplicate on (subject + AE term + start date); if a sequence column exists (AESEQ, SEQ), add it as ORDER BY tiebreaker
- Date columns may vary by study — confirm exact names from schema
- Ongoing flag values may be Y/N, Yes/No, or 1/0 — check actual values

## Detection Logic

### Placeholder Reference

| Placeholder | Description | Example CDW Columns |
|-------------|-------------|-------------------|
| `{SUBJECT_COL}` | Subject identifier | SUBJECT, SUBJID, SUBJECTID |
| `{AE_TERM_COL}` | AE verbatim term | AETERM, ADVERSE_EVENT |
| `{AE_DECODED_COL}` | AE decoded/preferred term (if available) | AEDECOD, AEPT |
| `{AE_SOC_COL}` | Body system / SOC (if available) | AEBODSYS, AESOC |
| `{AE_START_COL}` | AE start date | AESTDAT, AESTDTC, ONSET_DATE |
| `{AE_END_COL}` | AE end date | AEENDAT, AEENDTC, RESOLVE_DATE |
| `{ONGOING_COL}` | Ongoing flag | AEONGO, ONGOING, AE_ONGOING |
| `{SEVERITY_COL}` | AE severity | AESEV, SEVERITY |
| `{SERIOUS_COL}` | Serious flag | AESER, SERIOUS |
| `{RELATEDNESS_COL}` | Causality assessment | AEREL, CAUSEASS, RELATEDNESS |
| `{OUTCOME_COL}` | AE outcome | AEOUT, OUTCOME |
| `{SITE_COL}` | Site ID (from subject/demog) | SITEID, SITE, SITENO |
| `{ARM_COL}` | Treatment arm (from subject/demog) | ARM, TREATMENT, TRT |
| `{ONGOING_YES}` | Value meaning "ongoing" | Y, Yes, 1 |

### Query: Ongoing AEs >30 Days

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
       ae.{AE_TERM_COL},
       ae.{AE_START_COL}, ae.{AE_END_COL},
       ae.{SEVERITY_COL}, ae.{SERIOUS_COL},
       ae.{RELATEDNESS_COL}, ae.{OUTCOME_COL}, ae.{ONGOING_COL},
       DATEDIFF('day', CAST(ae.{AE_START_COL} AS DATE), CURRENT_DATE) AS DAYS_ONGOING
FROM ae_clean ae
LEFT JOIN {DEMOG_TABLE} dm ON ae.{SUBJECT_COL} = dm.{SUBJECT_COL}
WHERE (ae.{ONGOING_COL} = '{ONGOING_YES}'
       OR (ae.{AE_END_COL} IS NULL OR TRIM(CAST(ae.{AE_END_COL} AS VARCHAR)) = ''))
  AND DATEDIFF('day', CAST(ae.{AE_START_COL} AS DATE), CURRENT_DATE) > 30
ORDER BY DAYS_ONGOING DESC, ae.{SUBJECT_COL}
```

**Notes:**
- `{DEMOG_TABLE}` = `subject` or `demog` — whichever exists in the study
- If `{AE_DECODED_COL}` exists, include it in the SELECT for richer output
- If `{AE_SOC_COL}` exists, include it as well

### Additional Context Query: Check if Subject is Still on Study

Only run if `stat` form exists:

```sql
SELECT s.{SUBJECT_COL}, s.{DISP_REASON_COL}, s.{DISP_DATE_COL}
FROM stat s
WHERE s.{SUBJECT_COL} IN ({flagged_subjects})
```

If subject has completed/discontinued, an ongoing AE may indicate a missing
end date rather than a truly ongoing event.

## Findings Output Format

### PDRP Check #20: Ongoing AEs >30 Days
**Data source:** CDW (Rave CRF) — `aesae` form
**Subjects flagged:** {count}

| Subject | Site | Arm | AE Term | Start Date | Days Ongoing | Severity | Serious | Related | Still on Study? |
|---------|------|-----|---------|-----------|-------------|----------|---------|---------|----------------|

**Note:** Population flags unavailable in CDW data — all subjects reported.

## Draft Query Text

"Adverse event '{AE term}' (started {start date}) has been ongoing for {N}
days with no end date recorded. Please review and confirm the event is still
ongoing, or update the end date if the event has resolved."

## Related Skills

- `cdw-explorer` — CDW/Rave data navigation and column discovery
