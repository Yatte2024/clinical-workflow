---
name: pdrp-19-imae-causality
description: >
  PDRP RO #19: Review immune-mediated adverse events (IMAEs) marked as not
  related and/or occurring late after last dose. Use when reviewing IMAE
  data. Primary reviewer: Clinical Reviewer. Automation: semi.
---

# PDRP Check #19: IMAE Relatedness Review

## Review Objective

Review all immune-mediated adverse events (IMAEs) which are marked as not
related to study drug and/or reported after last dose of study drug, and
query for confirmation of immune-relatedness.

**CDW Forms:** `aesae`, `exposure`, `subject`/`demog`
**Primary Reviewer:** Clinical Reviewer
**Automation Level:** Semi — agent identifies candidate IMAEs, clinician
confirms immune-relatedness assessment.

## Step 0: Schema Discovery (MANDATORY)

Before running ANY query, call `the schema-discovery tool` on the data folder. Then identify:
1. **Subject ID column** — look for SUBJECT, SUBJID, SUBJECTID across forms
2. **Exact column names** in `aesae` for: AE term, decoded term (if available), SOC, start date, end date, severity, seriousness, relatedness, outcome
3. **Exact column names** in `exposure` for: end date (last dose date)
4. **Relatedness encoding** — discover actual values for "not related"
5. **Whether `subject` or `demog` form exists** — needed for site/arm context

Map discovered columns to the `{PLACEHOLDER}` variables in the SQL templates below.
Do NOT proceed until column names are confirmed from the schema.

### CDW Data Notes
- No population flags (SAFFL, ITTFL) — report all subjects
- Possible audit trail duplicates — deduplicate on (subject + AE term + start date); if a sequence column exists (AESEQ, SEQ), add it as ORDER BY tiebreaker
- CDW may not have decoded (MedDRA preferred) terms — if `{AE_DECODED_COL}` absent, match on `{AE_TERM_COL}` instead
- Relatedness values vary by study — discover encoding first

## Immune-Mediated Event Reference List

Match AE terms against this list. Match is case-insensitive and uses LIKE
patterns. If `{AE_DECODED_COL}` exists, match on that; otherwise use
`{AE_TERM_COL}`.

| Category | MedDRA Preferred Terms |
|----------|----------------------|
| GI | Colitis, Diarrhoea (immune), Enterocolitis |
| Hepatic | Hepatitis, Autoimmune hepatitis, Hepatotoxicity |
| Pulmonary | Pneumonitis, Interstitial lung disease |
| Renal | Nephritis, Tubulointerstitial nephritis |
| Skin | Dermatitis, Rash (severe/extensive), Stevens-Johnson, TEN |
| Endocrine | Thyroiditis, Hypothyroidism, Hyperthyroidism, Adrenal insufficiency |
| Pituitary | Hypophysitis |
| Cardiac | Myocarditis |
| Ocular | Uveitis, Iritis |
| Neurologic | Myasthenia gravis, Guillain-Barre, Encephalitis, Meningitis |
| Musculoskeletal | Myositis, Rhabdomyolysis, Arthritis (immune) |
| Hematologic | Hemolytic anemia, Immune thrombocytopenia, Aplastic anemia |
| Pancreatic | Pancreatitis (type 1 diabetes) |
| Other | Sarcoidosis, Vasculitis, Cytokine release syndrome |

## Detection Logic

### Placeholder Reference

| Placeholder | Description | Example CDW Columns |
|-------------|-------------|-------------------|
| `{SUBJECT_COL}` | Subject identifier | SUBJECT, SUBJID, SUBJECTID |
| `{AE_TERM_COL}` | AE verbatim term | AETERM, ADVERSE_EVENT |
| `{AE_DECODED_COL}` | AE decoded term (if available) | AEDECOD, AEPT |
| `{AE_SOC_COL}` | Body system / SOC (if available) | AEBODSYS, AESOC |
| `{AE_START_COL}` | AE start date | AESTDAT, AESTDTC |
| `{AE_END_COL}` | AE end date | AEENDAT, AEENDTC |
| `{SEVERITY_COL}` | AE severity | AESEV, SEVERITY |
| `{SERIOUS_COL}` | Serious flag | AESER, SERIOUS |
| `{RELATEDNESS_COL}` | Causality assessment | AEREL, CAUSEASS, RELATEDNESS |
| `{OUTCOME_COL}` | AE outcome | AEOUT, OUTCOME |
| `{EX_END_DATE_COL}` | Exposure end date | EXENDAT, EXENDTC, DOSE_END_DATE |
| `{SITE_COL}` | Site ID (from subject/demog) | SITEID, SITE |
| `{ARM_COL}` | Treatment arm (from subject/demog) | ARM, TREATMENT, TRT |
| `{NOT_RELATED_VALUES}` | Values meaning "not related" | 'NOT RELATED', 'UNRELATED' |
| `{MATCH_COL}` | Column to match IMAE terms against | `{AE_DECODED_COL}` or `{AE_TERM_COL}` |

### Query: IMAEs Marked as Not Related

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
imae_terms AS (
  SELECT ae.{SUBJECT_COL}, ae.{AE_TERM_COL}, ae.{MATCH_COL},
         ae.{AE_START_COL}, ae.{AE_END_COL},
         ae.{SEVERITY_COL}, ae.{SERIOUS_COL}, ae.{RELATEDNESS_COL}, ae.{OUTCOME_COL}
  FROM ae_clean ae
  WHERE (UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%COLITIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%HEPATITIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%PNEUMONITIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%INTERSTITIAL LUNG%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%NEPHRITIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%THYROID%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%HYPOPHYSITIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%MYOCARDITIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%UVEITIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%IRITIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%MYASTHENIA%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%GUILLAIN%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%ENCEPHALITIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%MYOSITIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%RHABDOMYOLYSIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%ADRENAL INSUFFICIENCY%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%PANCREATITIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%SARCOIDOSIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%VASCULITIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%STEVENS-JOHNSON%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%TOXIC EPIDERMAL%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%HAEMOLYTIC ANAEMIA%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%HEMOLYTIC ANEMIA%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%IMMUNE THROMBOCYTOP%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%APLASTIC ANAEMIA%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%CYTOKINE RELEASE%')
)
SELECT it.*, dm.{SITE_COL}, dm.{ARM_COL}
FROM imae_terms it
LEFT JOIN {DEMOG_TABLE} dm ON it.{SUBJECT_COL} = dm.{SUBJECT_COL}
WHERE UPPER(CAST(it.{RELATEDNESS_COL} AS VARCHAR)) IN ({NOT_RELATED_VALUES})
ORDER BY it.{SUBJECT_COL}, it.{AE_START_COL}
```

### Query: IMAEs Occurring Late After Last Dose

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
last_dose AS (
  SELECT {SUBJECT_COL}, MAX(CAST({EX_END_DATE_COL} AS DATE)) AS LAST_DOSE_DT
  FROM exposure
  GROUP BY {SUBJECT_COL}
),
imae_late AS (
  SELECT ae.{SUBJECT_COL}, ae.{AE_TERM_COL}, ae.{MATCH_COL},
         ae.{AE_START_COL}, ae.{RELATEDNESS_COL},
         ld.LAST_DOSE_DT,
         DATEDIFF('day', ld.LAST_DOSE_DT, CAST(ae.{AE_START_COL} AS DATE)) AS DAYS_POST_DOSE
  FROM ae_clean ae
  JOIN last_dose ld ON ae.{SUBJECT_COL} = ld.{SUBJECT_COL}
  WHERE (UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%COLITIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%HEPATITIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%PNEUMONITIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%INTERSTITIAL LUNG%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%NEPHRITIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%THYROID%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%HYPOPHYSITIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%MYOCARDITIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%UVEITIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%IRITIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%MYASTHENIA%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%GUILLAIN%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%ENCEPHALITIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%MYOSITIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%RHABDOMYOLYSIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%ADRENAL INSUFFICIENCY%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%PANCREATITIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%SARCOIDOSIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%VASCULITIS%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%STEVENS-JOHNSON%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%TOXIC EPIDERMAL%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%HAEMOLYTIC ANAEMIA%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%HEMOLYTIC ANEMIA%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%IMMUNE THROMBOCYTOP%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%APLASTIC ANAEMIA%'
     OR UPPER(CAST(ae.{MATCH_COL} AS VARCHAR)) LIKE '%CYTOKINE RELEASE%')
    AND DATEDIFF('day', ld.LAST_DOSE_DT, CAST(ae.{AE_START_COL} AS DATE)) > 90
)
SELECT il.*, dm.{SITE_COL}, dm.{ARM_COL}
FROM imae_late il
LEFT JOIN {DEMOG_TABLE} dm ON il.{SUBJECT_COL} = dm.{SUBJECT_COL}
ORDER BY il.DAYS_POST_DOSE DESC
```

Note: 90 days is a conservative default. For IO agents with long half-lives,
IMAEs can occur >6 months after last dose. Adjust threshold per protocol
(5x half-life of study drug).

## Findings Output Format

### PDRP Check #19: IMAE Relatedness Review
**Data source:** CDW (Rave CRF) — `aesae` + `exposure` forms

**Part A: IMAEs marked NOT related**

| Subject | Site | Arm | AE Term | Decoded | Severity | Relatedness | Outcome |
|---------|------|-----|---------|---------|----------|-------------|---------|

**Part B: IMAEs occurring >90 days after last dose**

| Subject | Site | Arm | AE Term | AE Start | Last Dose | Days Post-Dose | Relatedness |
|---------|------|-----|---------|----------|-----------|----------------|-------------|

**Note:** Population flags unavailable in CDW data — all subjects reported.

## Draft Query Text

**For not-related IMAEs:**
"An immune-mediated adverse event ({AE term}) has been reported as not related
to study drug. Given the immune-mediated nature of this event, please review
and confirm the causality assessment."

**For late-onset IMAEs:**
"An immune-mediated adverse event ({AE term}) has been reported {N} days after
the last dose of study drug. Please review and confirm whether this event
may be immune-related to prior study drug exposure."

## Related Skills

- `safety-signal-review` — Phase 2 AE analysis
- `cdw-explorer` — CDW/Rave data navigation and column discovery
