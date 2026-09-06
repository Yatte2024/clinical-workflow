---
name: pdrp-orchestrator
description: >
  Use when asked to "run PDRP checks", "run PDRP", or review data using the
  Protocol Data Review Plan. Lists available PDRP checks and orchestrates
  individual or batch execution. Supports "run all", "run check #N", or
  "run all AE checks".
---

# PDRP Runner — Protocol Data Review Plan Check Orchestrator

## Available Checks

### Clinical Reviewer Checks

| RO# | Skill | CDW Forms | Auto | Description |
|-----|-------|-----------|------|-------------|
| 4 | `pdrp-04-vital-sign-outliers` | `vits` | Semi | Vital sign changes from baseline |
| 14 | `pdrp-14-lab-ae-grade-consistency` | `aesae` + `lab` | Semi | Lab AE vs CTCAE grading |
| 17 | `pdrp-17-related-ae-review` | `aesae` | Semi | Related events safety signals |
| 19 | `pdrp-19-imae-causality` | `aesae` + `exposure` | Semi | Immune-mediated AE relatedness |
| 20 | `pdrp-20-prolonged-ae` | `aesae` + `stat` | Full | Ongoing AEs >30 days |
| 25 | `pdrp-25-infusion-day-hsr` | `aesae` + `exposure` | Semi | Dosing day hypersensitivity |
| 27 | `pdrp-27-death-disposition-reconcile` | `aesae` + `stat` | Full | Death AE vs disposition |
| 31 | `pdrp-31-prohibited-conmeds` | `conmed` + `exposure` | Semi | Prohibited ConMeds |

## How to Run Checks

### Run a Single Check

When the user asks to run a specific check by number or description:
1. Identify the matching skill from the table above
2. Invoke the skill using `/skill pdrp-{nn}-{name}`
3. Present findings in the skill's defined output format

**Examples:**
- "Run PDRP check 27" → invoke `pdrp-27-death-disposition-reconcile`
- "Check death vs disposition" → invoke `pdrp-27-death-disposition-reconcile`
- "Any ongoing AEs?" → invoke `pdrp-20-prolonged-ae`

### Run All Clinical Reviewer Checks

When asked to "run all PDRP checks" or "run all clinical checks":

```
Step 1: Call the schema-discovery tool to discover available CDW forms and columns
Step 2: Identify available CDW forms (aesae, vits, lab, conmed, exposure, stat, subject, demog)
Step 3: Identify the subject ID column (SUBJECT, SUBJID, SUBJECTID — varies by study)
Step 4: Run each applicable check in order (skip if required form is missing)
Step 5: Present consolidated summary
```

**Consolidated Summary Format:**

```markdown
## PDRP Review Summary — Study {study_id}
**Date:** {date}
**Reviewer:** Clinical Reviewer
**Data source:** CDW (Rave CRF)
**Checks completed:** {N} / 8

| RO# | Check | Subjects Flagged | Status |
|-----|-------|-----------------|--------|
| 4 | Vital sign abnormalities | {n} | {status} |
| 14 | Lab AE grading alignment | {n} | {status} |
| 17 | Safety signal evaluation | {n} | {status} |
| 19 | IMAE relatedness | {n} | {status} |
| 20 | Ongoing AE >30 days | {n} | {status} |
| 25 | Hypersensitivity dosing day | {n} | {status} |
| 27 | Death vs disposition | {n} | {status} |
| 31 | Prohibited medications | {n} | {status} |

Status: ✓ No findings | ⚠ Findings for review | ⛔ Critical findings | — Skipped (data unavailable)

### Findings Requiring Action
[List only checks with findings, showing the findings tables]
```

### Run by Domain

- "Run all AE checks" → ROs 14, 17, 19, 20, 25
- "Run all disposition checks" → RO 27
- "Run all ConMed checks" → RO 31
- "Run all vitals checks" → RO 4

## CDW Form Requirements

| Check | Required CDW Forms | Optional |
|-------|-------------------|----------|
| RO #4 | `vits`, `subject` or `demog` | — |
| RO #14 | `aesae`, `lab`, `subject` or `demog` | — |
| RO #17 | `aesae`, `subject` or `demog` | — |
| RO #19 | `aesae`, `exposure`, `subject` or `demog` | — |
| RO #20 | `aesae`, `subject` or `demog` | `stat` |
| RO #25 | `aesae`, `exposure`, `subject` or `demog` | — |
| RO #27 | `aesae`, `stat`, `subject` or `demog` | — |
| RO #31 | `conmed`, `subject` or `demog` | `exposure` (for timing) |

## CDW Data Notes

- No population flags (SAFFL, ITTFL) — report all subjects
- No USUBJID — discover the subject ID column from schema (SUBJECT, SUBJID, etc.)
- Possible audit trail duplicates — each check includes deduplication guidance
- Column names are study-specific — every check discovers columns via schema first
- No ADaM datasets available — all checks work directly from CDW forms

## Error Handling

If a required CDW form is missing:
- Skip the check
- Report: "Check #{N} skipped — `{form}` form not found in study data"
- Continue with remaining checks

If SQL query fails:
- Report the error
- Continue with remaining checks
- Suggest the user check data format compatibility
