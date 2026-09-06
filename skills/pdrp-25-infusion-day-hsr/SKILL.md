---
name: pdrp-25-infusion-day-hsr
description: >
  PDRP RO #25: Identify AEs occurring on the same day or +1 day post-infusion
  that may represent hypersensitivity or infusion-related reactions. Use when
  reviewing infusion-day safety. Primary reviewer: Clinical Reviewer. Automation: semi.
---

# PDRP Check #25: Potential Hypersensitivity on Dosing Day

## Review Objective

Ensure there are no missed hypersensitivity adverse events on day 0 to +1
post-infusion. Review AEs to assess for possible hypersensitivity reaction
event terms/signs or symptoms which are related and occur on the same day
(or +1 day) as dosing.

If suspected hypersensitivity reaction, query site to report using one of:
'hypersensitivity', 'anaphylactic reaction', 'anaphylactic shock', 'infusion
related reaction', or 'bronchospasm'.

**CDW Forms:** `aesae`, `exposure`, `subject`/`demog`
**Primary Reviewer:** Clinical Reviewer
**Automation Level:** Semi — agent identifies temporal associations, clinician
determines if hypersensitivity.

## Step 0: Schema Discovery (MANDATORY)

Before running ANY query, call `the schema-discovery tool` on the data folder. Then identify:
1. **Subject ID column** — look for SUBJECT, SUBJID, SUBJECTID across forms
2. **Exact column names** in `aesae` for: AE term, decoded term, SOC, start date, severity, seriousness, relatedness
3. **Exact column names** in `exposure` for: start date, treatment name, dose, route
4. **Whether `subject` or `demog` form exists** — needed for site/arm context

Map discovered columns to the `{PLACEHOLDER}` variables in the SQL templates below.
Do NOT proceed until column names are confirmed from the schema.

### CDW Data Notes
- No population flags (SAFFL, ITTFL) — report all subjects
- Possible audit trail duplicates — deduplicate on (subject + AE term + start date); if a sequence column exists (AESEQ, SEQ), add it as ORDER BY tiebreaker
- Date columns may vary by study — confirm exact names from schema
- CDW may not have decoded terms — match on verbatim term if needed

## Hypersensitivity Indicator Terms

AEs that may indicate hypersensitivity even if not coded as such:

| Category | Terms to Match (LIKE patterns on `{MATCH_COL}`) |
|----------|------------------------------------------------|
| Skin | %RASH%, %URTICARIA%, %PRURITUS%, %ERYTHEMA%, %FLUSHING% |
| Respiratory | %DYSPNOEA%, %DYSPNEA%, %BRONCHOSPASM%, %WHEEZING%, %STRIDOR% |
| Cardiovascular | %HYPOTENSION%, %TACHYCARDIA% |
| GI | %NAUSEA%, %VOMITING% (when temporal with infusion) |
| Systemic | %ANAPHYLA%, %HYPERSENSITIVITY%, %INFUSION%, %INJECTION%REACT%, %FEVER%, %CHILLS%, %RIGORS% |

## Detection Logic

### Placeholder Reference

| Placeholder | Description | Example CDW Columns |
|-------------|-------------|-------------------|
| `{SUBJECT_COL}` | Subject identifier | SUBJECT, SUBJID, SUBJECTID |
| `{AE_TERM_COL}` | AE verbatim term | AETERM, ADVERSE_EVENT |
| `{AE_DECODED_COL}` | AE decoded term (if available) | AEDECOD, AEPT |
| `{AE_SOC_COL}` | Body system / SOC (if available) | AEBODSYS, AESOC |
| `{AE_START_COL}` | AE start date | AESTDAT, AESTDTC |
| `{SEVERITY_COL}` | AE severity | AESEV, SEVERITY |
| `{SERIOUS_COL}` | Serious flag | AESER, SERIOUS |
| `{RELATEDNESS_COL}` | Causality assessment | AEREL, CAUSEASS |
| `{EX_START_DATE_COL}` | Exposure start date | EXSTDAT, EXSTDTC, DOSE_DATE |
| `{TREATMENT_COL}` | Treatment name | EXTRT, TREATMENT, DRUG |
| `{DOSE_COL}` | Dose amount (if available) | EXDOSE, DOSE |
| `{ROUTE_COL}` | Route of admin (if available) | EXROUTE, ROUTE |
| `{SITE_COL}` | Site ID (from subject/demog) | SITEID, SITE |
| `{ARM_COL}` | Treatment arm (from subject/demog) | ARM, TREATMENT, TRT |
| `{MATCH_COL}` | Column for term matching | `{AE_DECODED_COL}` or `{AE_TERM_COL}` |
| `{NOT_RELATED_VALUES}` | Values meaning "not related" | 'NOT RELATED', 'UNRELATED' |

### Query: Related AEs Starting Within 0-1 Days of Dosing

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
dosing_dates AS (
  SELECT {SUBJECT_COL}, CAST({EX_START_DATE_COL} AS DATE) AS DOSE_DT,
         {TREATMENT_COL}
  FROM exposure
),
ae_near_dose AS (
  SELECT ae.{SUBJECT_COL}, ae.{AE_TERM_COL}, ae.{MATCH_COL},
         ae.{AE_START_COL}, ae.{SEVERITY_COL}, ae.{SERIOUS_COL}, ae.{RELATEDNESS_COL},
         dd.DOSE_DT, dd.{TREATMENT_COL},
         DATEDIFF('day', dd.DOSE_DT, CAST(ae.{AE_START_COL} AS DATE)) AS DAYS_FROM_DOSE
  FROM ae_clean ae
  JOIN dosing_dates dd ON ae.{SUBJECT_COL} = dd.{SUBJECT_COL}
  WHERE DATEDIFF('day', dd.DOSE_DT, CAST(ae.{AE_START_COL} AS DATE)) BETWEEN 0 AND 1
)
SELECT and_d.*, dm.{SITE_COL}, dm.{ARM_COL},
       CASE
         WHEN UPPER(CAST(and_d.{MATCH_COL} AS VARCHAR)) LIKE '%ANAPHYLA%' THEN 'Anaphylaxis term'
         WHEN UPPER(CAST(and_d.{MATCH_COL} AS VARCHAR)) LIKE '%HYPERSENSITIVITY%' THEN 'Hypersensitivity term'
         WHEN UPPER(CAST(and_d.{MATCH_COL} AS VARCHAR)) LIKE '%INFUSION%REACT%' THEN 'IRR term'
         WHEN UPPER(CAST(and_d.{MATCH_COL} AS VARCHAR)) LIKE '%INJECTION%REACT%' THEN 'Injection reaction term'
         WHEN UPPER(CAST(and_d.{MATCH_COL} AS VARCHAR)) LIKE '%RASH%'
           OR UPPER(CAST(and_d.{MATCH_COL} AS VARCHAR)) LIKE '%URTICARIA%'
           OR UPPER(CAST(and_d.{MATCH_COL} AS VARCHAR)) LIKE '%FLUSHING%' THEN 'Skin - possible HSR sign'
         WHEN UPPER(CAST(and_d.{MATCH_COL} AS VARCHAR)) LIKE '%DYSPNO%'
           OR UPPER(CAST(and_d.{MATCH_COL} AS VARCHAR)) LIKE '%BRONCHOSPASM%' THEN 'Respiratory - possible HSR sign'
         WHEN UPPER(CAST(and_d.{MATCH_COL} AS VARCHAR)) LIKE '%HYPOTENSION%' THEN 'CV - possible HSR sign'
         ELSE 'Temporal association only'
       END AS HSR_SIGNAL
FROM ae_near_dose and_d
LEFT JOIN {DEMOG_TABLE} dm ON and_d.{SUBJECT_COL} = dm.{SUBJECT_COL}
WHERE (and_d.{RELATEDNESS_COL} IS NULL
       OR UPPER(CAST(and_d.{RELATEDNESS_COL} AS VARCHAR)) NOT IN ({NOT_RELATED_VALUES}))
   OR UPPER(CAST(and_d.{MATCH_COL} AS VARCHAR)) LIKE '%ANAPHYLA%'
   OR UPPER(CAST(and_d.{MATCH_COL} AS VARCHAR)) LIKE '%HYPERSENSITIVITY%'
   OR UPPER(CAST(and_d.{MATCH_COL} AS VARCHAR)) LIKE '%INFUSION%REACT%'
ORDER BY and_d.{SUBJECT_COL}, and_d.DOSE_DT
```

**Notes:**
- If `{DOSE_COL}` and `{ROUTE_COL}` exist, include them in the SELECT for richer context
- `{MATCH_COL}` = `{AE_DECODED_COL}` if available, otherwise `{AE_TERM_COL}`

## Findings Output Format

### PDRP Check #25: Potential Hypersensitivity on Dosing Day
**Data source:** CDW (Rave CRF) — `aesae` + `exposure` forms
**Subjects flagged:** {count}

| Subject | Site | Arm | AE Term | AE Start | Dose Date | Drug | HSR Signal | Relatedness |
|---------|------|-----|---------|----------|-----------|------|-----------|-------------|

**Note:** Population flags unavailable in CDW data — all subjects reported.

## Draft Query Text

"A related event ({AE term}, started {AE start date}) has been reported with
an Onset Date equal to a dosing date ({dose date}) or within 1 day of
infusion. Please review and determine if this event is considered a
hypersensitivity/infusion reaction to study medication. If yes, please
consider changing the adverse event term to one of: INFUSION RELATED
REACTION, INJECTION RELATED REACTION, HYPERSENSITIVITY, ANAPHYLACTIC
REACTION, BRONCHOSPASM, or ANAPHYLACTIC SHOCK, as appropriate."

## Related Skills

- `cdw-explorer` — CDW/Rave data navigation and column discovery
- `safety-signal-review` — Phase 2 AE analysis
