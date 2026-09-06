---
name: pdrp-17-related-ae-review
description: >
  PDRP RO #17: Evaluate related/suspected adverse events for safety signals
  and trends. Use when reviewing AE relatedness patterns. Primary reviewer:
  Clinical Reviewer. Automation: semi.
---

# PDRP Check #17: Safety Signal Evaluation for Related Events

## Review Objective

Evaluate reported related/suspected events for potential safety signals and
trends. Review and issue query for events marked as 'Related' or 'Suspected'
in the eCRF but don't actually appear to be related/suspected. Site has final
decision on relatedness.

**CDW Forms:** `aesae`, `subject`/`demog`
**Primary Reviewer:** Clinical Reviewer
**Automation Level:** Semi — agent identifies patterns, clinician evaluates.

## Step 0: Schema Discovery (MANDATORY)

Before running ANY query, call `the schema-discovery tool` on the data folder. Then identify:
1. **Subject ID column** — look for SUBJECT, SUBJID, SUBJECTID across forms
2. **Exact column names** in `aesae` for: AE term, decoded term, SOC/body system, severity, seriousness, relatedness
3. **Relatedness encoding** — discover actual values (RELATED/SUSPECTED vs Y/N vs POSSIBLE/PROBABLE)
4. **Whether `subject` or `demog` form exists** — needed for arm/site context

Map discovered columns to the `{PLACEHOLDER}` variables in the SQL templates below.
Do NOT proceed until column names are confirmed from the schema.

### CDW Data Notes
- No population flags (SAFFL, ITTFL) — report all subjects
- Possible audit trail duplicates — deduplicate on (subject + AE term + start date); if a sequence column exists (AESEQ, SEQ), add it as ORDER BY tiebreaker
- Relatedness values vary by study — always discover encoding first
- CDW may use CAUSEASS instead of AEREL for causality assessment

### Pre-Query: Discover Relatedness Values

```sql
SELECT DISTINCT {RELATEDNESS_COL}, COUNT(*) AS n
FROM aesae
GROUP BY {RELATEDNESS_COL}
ORDER BY n DESC
```

Use results to identify which values mean "related" vs "not related."

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
| `{RELATEDNESS_COL}` | Causality assessment | AEREL, CAUSEASS, RELATEDNESS |
| `{SITE_COL}` | Site ID (from subject/demog) | SITEID, SITE, SITENO |
| `{ARM_COL}` | Treatment arm (from subject/demog) | ARM, TREATMENT, TRT |
| `{RELATED_VALUES}` | Values meaning "related" | 'RELATED', 'SUSPECTED', 'POSSIBLE' |

### Part A: Related Event Profiling

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
related_ae AS (
  SELECT ae.{SUBJECT_COL}, ae.{AE_SOC_COL}, ae.{AE_DECODED_COL},
         ae.{SEVERITY_COL}, ae.{SERIOUS_COL}
  FROM ae_clean ae
  WHERE UPPER(CAST(ae.{RELATEDNESS_COL} AS VARCHAR)) IN ({RELATED_VALUES})
)
SELECT dm.{ARM_COL}, ra.{AE_SOC_COL},
       COUNT(DISTINCT ra.{SUBJECT_COL}) AS N_SUBJ,
       COUNT(*) AS N_EVENTS
FROM related_ae ra
LEFT JOIN {DEMOG_TABLE} dm ON ra.{SUBJECT_COL} = dm.{SUBJECT_COL}
GROUP BY dm.{ARM_COL}, ra.{AE_SOC_COL}
ORDER BY N_SUBJ DESC
```

**Flag SOCs where:**
- Related AE incidence in drug arm >=2x comparator arm
- Any related SAE (`{SERIOUS_COL}` = 'Y' or 'Yes') in drug arm not seen in comparator
- Cluster of related AEs in same SOC not consistent with disease background

**Notes:**
- If `{AE_SOC_COL}` doesn't exist, group by `{AE_DECODED_COL}` or `{AE_TERM_COL}` instead
- If `{AE_DECODED_COL}` doesn't exist, use `{AE_TERM_COL}` for all term references

### Part B: Relatedness Questionability

Identify events marked as related in the comparator/placebo arm:

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
       ae.{AE_TERM_COL}, ae.{AE_SOC_COL},
       ae.{RELATEDNESS_COL}, ae.{SEVERITY_COL}
FROM ae_clean ae
LEFT JOIN {DEMOG_TABLE} dm ON ae.{SUBJECT_COL} = dm.{SUBJECT_COL}
WHERE UPPER(CAST(ae.{RELATEDNESS_COL} AS VARCHAR)) IN ({RELATED_VALUES})
  AND UPPER(CAST(dm.{ARM_COL} AS VARCHAR)) LIKE '%PLACEBO%'
ORDER BY dm.{SITE_COL}, ae.{AE_SOC_COL}
```

**Note:** If arm values don't contain "PLACEBO", discover comparator arm
values from the `subject`/`demog` form first.

## Findings Output Format

### PDRP Check #17: Related Event Safety Signal Evaluation
**Data source:** CDW (Rave CRF) — `aesae` form
**Related AEs:** {count_related} / {count_total} ({pct}%)

**Part A: Related AE Incidence by SOC (flagged SOCs)**

| SOC | Drug Arm n/N (%) | Comparator n/N (%) | Ratio | Signal? |
|-----|------------------|-------------------|-------|---------|

**Part B: Potentially over-attributed relatedness**

| Subject | Site | Arm | AE Term | Relatedness | Note |
|---------|------|-----|---------|-------------|------|

**Note:** Population flags unavailable in CDW data — all subjects reported.

## Draft Query Text

Not applicable — this check generates a summary for the clinical reviewer
to evaluate. No site queries are generated directly. The reviewer uses the
findings to decide whether to query specific sites about relatedness
assessments.

## Related Skills

- `safety-signal-review` — Systematic safety review framework (Phase 2)
- `cdw-explorer` — CDW/Rave data navigation and column discovery
