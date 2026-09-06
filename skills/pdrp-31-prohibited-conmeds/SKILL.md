---
name: pdrp-31-prohibited-conmeds
description: >
  PDRP RO #31: Identify subjects with potential prohibited concomitant
  medications per protocol. Use when reviewing ConMed data for protocol
  compliance. Primary reviewer: Clinical Reviewer. Automation: semi.
---

# PDRP Check #31: Prohibited Concomitant Medications

## Review Objective

Identify subjects with potential prohibited concomitant medications. Review
potential prohibited medications; query to confirm or report protocol
deviation as required per protocol.

**CDW Forms:** `conmed`, `exposure`, `subject`/`demog`
**Primary Reviewer:** Clinical Reviewer
**Automation Level:** Semi — requires a protocol-specific prohibited
medication list as input. Agent matches against the list; clinician
confirms and classifies any protocol deviations.

## Step 0: Schema Discovery (MANDATORY)

Before running ANY query, call `the schema-discovery tool` on the data folder. Then identify:
1. **Subject ID column** — look for SUBJECT, SUBJID, SUBJECTID across forms
2. **Exact column names** in `conmed` for: medication name, decoded name (if available), drug class (if available), start date, end date, indication
3. **Exact column names** in `exposure` for: start date, end date (for treatment period)
4. **Whether `subject` or `demog` form exists** — needed for site/arm context

Map discovered columns to the `{PLACEHOLDER}` variables in the SQL templates below.
Do NOT proceed until column names are confirmed from the schema.

### CDW Data Notes
- No population flags (SAFFL, ITTFL) — report all subjects
- Possible audit trail duplicates — deduplicate on (subject + medication + start date); if a sequence column exists, add it as ORDER BY tiebreaker
- CDW `conmed` may not have decoded medication names or drug class columns — handle gracefully
- Date columns may vary by study — confirm exact names from schema

## Prerequisites

This check requires a **prohibited medications input list** specific to
the protocol. The list should contain drug names or drug classes that are
prohibited per protocol.

**How to obtain the list:**
1. Check if a study-specific skill already has the prohibited meds list
2. Ask the clinician: "What medications are prohibited per this protocol?"
3. Reference the protocol's exclusion criteria / prohibited medication section
4. The list should include both generic names and drug class names

## Detection Logic

### Placeholder Reference

| Placeholder | Description | Example CDW Columns |
|-------------|-------------|-------------------|
| `{SUBJECT_COL}` | Subject identifier | SUBJECT, SUBJID, SUBJECTID |
| `{MED_NAME_COL}` | Medication name (verbatim) | CMTRT, MEDICATION, DRUG_NAME |
| `{MED_DECODED_COL}` | Decoded/generic name (if available) | CMDECOD, GENERIC_NAME |
| `{MED_CLASS_COL}` | Drug class (if available) | CMCLAS, DRUG_CLASS |
| `{CM_START_COL}` | Medication start date | CMSTDAT, CMSTDTC, MED_START |
| `{CM_END_COL}` | Medication end date | CMENDAT, CMENDTC, MED_END |
| `{INDICATION_COL}` | Indication (if available) | CMINDC, INDICATION |
| `{EX_START_DATE_COL}` | Exposure start date | EXSTDAT, EXSTDTC |
| `{EX_END_DATE_COL}` | Exposure end date | EXENDAT, EXENDTC |
| `{SITE_COL}` | Site ID (from subject/demog) | SITEID, SITE |
| `{ARM_COL}` | Treatment arm (from subject/demog) | ARM, TREATMENT, TRT |

### Query: Match ConMeds Against Prohibited List

Replace `{prohibited_list}` with actual drug names from the input list.

```sql
WITH cm_dedup AS (
  SELECT *, ROW_NUMBER() OVER (
    PARTITION BY {SUBJECT_COL}, {MED_NAME_COL}, {CM_START_COL}
    ORDER BY {CM_START_COL}
  ) AS rn
  FROM conmed
),
cm_clean AS (
  SELECT * FROM cm_dedup WHERE rn = 1
)
SELECT cm.{SUBJECT_COL}, dm.{SITE_COL}, dm.{ARM_COL},
       cm.{MED_NAME_COL},
       cm.{CM_START_COL}, cm.{CM_END_COL},
       'Prohibited medication' AS FLAG
FROM cm_clean cm
LEFT JOIN {DEMOG_TABLE} dm ON cm.{SUBJECT_COL} = dm.{SUBJECT_COL}
WHERE ({prohibited_like_patterns})
ORDER BY cm.{SUBJECT_COL}, cm.{CM_START_COL}
```

**Notes:**
- `{prohibited_like_patterns}` = generate LIKE patterns from the prohibited list, e.g.:
  `UPPER(CAST(cm.{MED_NAME_COL} AS VARCHAR)) LIKE '%IBUPROFEN%' OR UPPER(CAST(cm.{MED_NAME_COL} AS VARCHAR)) LIKE '%METHOTREXATE%'`
  Use LIKE (not exact IN-match) because CDW verbatim med names include dose/form (e.g., "IBUPROFEN 200MG TABLET")
- If `{MED_DECODED_COL}` exists, add OR clauses matching on that column too
- If `{MED_CLASS_COL}` exists, add OR clauses matching on drug class
- If `{INDICATION_COL}` exists, include it in the SELECT for context

### Query: Check Timing vs Treatment Period

For flagged medications, determine if they were taken during treatment.
Only run if `exposure` form exists:

```sql
WITH trt_period AS (
  SELECT {SUBJECT_COL},
         MIN(CAST({EX_START_DATE_COL} AS DATE)) AS TRT_START,
         MAX(CAST({EX_END_DATE_COL} AS DATE)) AS TRT_END
  FROM exposure
  GROUP BY {SUBJECT_COL}
),
cm_dedup AS (
  SELECT *, ROW_NUMBER() OVER (
    PARTITION BY {SUBJECT_COL}, {MED_NAME_COL}, {CM_START_COL}
    ORDER BY {CM_START_COL}
  ) AS rn
  FROM conmed
),
cm_clean AS (
  SELECT * FROM cm_dedup WHERE rn = 1
)
SELECT cm.{SUBJECT_COL}, cm.{MED_NAME_COL},
       cm.{CM_START_COL}, cm.{CM_END_COL},
       tp.TRT_START, tp.TRT_END,
       CASE
         WHEN CAST(cm.{CM_START_COL} AS DATE) >= tp.TRT_START
          AND CAST(cm.{CM_START_COL} AS DATE) <= tp.TRT_END
         THEN 'During treatment'
         WHEN CAST(cm.{CM_START_COL} AS DATE) < tp.TRT_START
         THEN 'Prior to treatment'
         ELSE 'After treatment'
       END AS TIMING
FROM cm_clean cm
JOIN trt_period tp ON cm.{SUBJECT_COL} = tp.{SUBJECT_COL}
WHERE ({prohibited_like_patterns})
ORDER BY cm.{SUBJECT_COL}
```

## Findings Output Format

### PDRP Check #31: Prohibited Concomitant Medications
**Data source:** CDW (Rave CRF) — `conmed` form
**Subjects flagged:** {count}

| Subject | Site | Arm | Medication | Start Date | Timing | Indication |
|---------|------|-----|-----------|-----------|--------|-----------|

**Note:** Population flags unavailable in CDW data — all subjects reported.

## Draft Query Text

"Medication '{medication}' is reported for the subject; however, it is a
prohibited medication per protocol. Please confirm the medication and
associated information is correctly entered, or update."

## Related Skills

- `cdw-explorer` — CDW/Rave data navigation and column discovery
