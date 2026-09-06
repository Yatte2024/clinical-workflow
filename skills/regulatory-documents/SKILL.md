---
name: regulatory-documents
description: >
  Use when preparing regulatory documents, clinical study report sections,
  SAE narratives, protocol deviation summaries, or de-identification reviews.
  Covers ICH-E3 CSR structure, SAE reporting with FDA timelines (7-day/15-day),
  HIPAA 18-identifier de-identification checklist, and protocol deviation
  documentation. Complements safety-review-workflow (analysis workflow) and
  safety-signal-review (signal criteria).
---

# Regulatory Reporting Reference

## ICH-E3 Clinical Study Report Structure

The ICH E3 guideline defines the structure for clinical study reports (CSRs)
submitted to regulatory agencies. Key sections relevant to data analysis:

### Synopsis (Section 1) — 5–15 pages

Must stand alone. Contains:
- Study objectives (primary and secondary)
- Design summary (randomized, blinded, controlled, parallel/crossover)
- Key efficacy results with primary endpoint outcome
- Key safety results (most common AEs, SAEs, deaths)
- Conclusions and benefit-risk statement

### Efficacy Evaluation (Section 7)

| Subsection | Content |
|-----------|---------|
| 7.1 Analysis populations | ITT, mITT, PP, safety — define and justify |
| 7.2 Primary endpoint | Full results with CI, p-value, effect size |
| 7.3 Secondary endpoints | Pre-specified analyses per SAP |
| 7.4 Subgroup analyses | Forest plot, interaction tests |
| 7.5 Sensitivity analyses | Robustness checks per SAP |
| 7.6 Missing data | Methods used (MMRM, multiple imputation, LOCF) |

### Safety Evaluation (Section 8)

| Subsection | Content |
|-----------|---------|
| 8.1 Extent of exposure | Duration, dose, compliance by arm |
| 8.2 Adverse events | Overall, by SOC/PT, severity, relatedness |
| 8.3 Deaths and SAEs | Narratives for every death, all SAEs listed |
| 8.4 Laboratory | Shift tables, outlier analyses, Hy's Law |
| 8.5 Vital signs | Mean change, categorical outliers |
| 8.6 ECG | QTcF analysis per ICH E14 |

**Data queries for CSR sections:**

```sql
-- Section 7.1: Analysis populations
SELECT TRT01A,
       SUM(CASE WHEN ITTFL = 'Y' THEN 1 ELSE 0 END) AS itt_n,
       SUM(CASE WHEN PPROTFL = 'Y' THEN 1 ELSE 0 END) AS pp_n,
       SUM(CASE WHEN SAFFL = 'Y' THEN 1 ELSE 0 END) AS safety_n
FROM adsl
GROUP BY TRT01A
```

```sql
-- Section 8.1: Exposure summary
SELECT TRT01A,
       COUNT(DISTINCT USUBJID) AS n,
       ROUND(AVG(TRTDURD), 1) AS mean_exposure_days,
       ROUND(MEDIAN(TRTDURD), 1) AS median_exposure_days,
       MIN(TRTDURD) AS min_days,
       MAX(TRTDURD) AS max_days
FROM adsl
WHERE SAFFL = 'Y'
GROUP BY TRT01A
```

## Serious Adverse Event (SAE) Reporting

### SAE Criteria

An adverse event is **serious** if it:
- Results in death
- Is life-threatening
- Requires inpatient hospitalization or prolongs existing hospitalization
- Results in persistent or significant disability/incapacity
- Is a congenital anomaly/birth defect
- Requires intervention to prevent permanent impairment

### FDA Reporting Timelines

| Event Type | Timeline | Report To |
|-----------|----------|-----------|
| Fatal or life-threatening, unexpected, related | **7 calendar days** (preliminary) | FDA (IND Safety Report) |
| Fatal or life-threatening, unexpected, related | **15 calendar days** (complete) | FDA (IND Safety Report) |
| Other serious, unexpected, related | **15 calendar days** | FDA (IND Safety Report) |
| Annual safety report | **Within 60 days** of IND anniversary | FDA |
| IRB notification | Per institutional policy (typically 5–10 days) | IRB/IEC |

### SAE Narrative Components

Each SAE narrative must include:

1. **Subject demographics** — ID, age, sex, arm (de-identified)
2. **Event description** — onset date, presenting symptoms, diagnosis
3. **Relevant medical history** — comorbidities, concomitant medications
4. **Clinical course** — hospitalization, treatments administered, response
5. **Causality assessment** — investigator's assessment with rationale
   (unrelated / unlikely / possible / probable / definite)
6. **Action taken** — dose modification, drug withdrawn, study discontinued
7. **Outcome** — recovered, recovering, not recovered, fatal, unknown
8. **Seriousness criteria met** — which of the 6 criteria above

```sql
-- Identify SAEs for narrative writing
SELECT s.USUBJID, s.TRT01A, s.AGE, s.SEX,
       a.AEDECOD, a.AEBODSYS, a.AESTDTC, a.AEENDTC,
       a.AESER, a.AESEV, a.AEREL, a.AEACN, a.AEOUT,
       a.AETOXGR
FROM adae a
JOIN adsl s ON a.USUBJID = s.USUBJID
WHERE a.AESER = 'Y' AND s.SAFFL = 'Y'
ORDER BY s.TRT01A, a.AEDECOD
```

## HIPAA De-Identification Checklist

Safe Harbor method — remove or generalize all 18 identifiers before any
data leaves the secure environment.

| # | Identifier | Action |
|---|-----------|--------|
| 1 | Names | Remove — use subject ID only |
| 2 | Geographic subdivisions < state | Generalize to state or region |
| 3 | Dates (except year) | Use study day or interval; keep year if needed |
| 4 | Telephone numbers | Remove |
| 5 | Fax numbers | Remove |
| 6 | Email addresses | Remove |
| 7 | Social Security numbers | Remove — never present in study data |
| 8 | Medical record numbers | Replace with USUBJID |
| 9 | Health plan beneficiary numbers | Remove |
| 10 | Account numbers | Remove |
| 11 | Certificate/license numbers | Remove |
| 12 | Vehicle identifiers | Remove |
| 13 | Device identifiers | Remove (unless study device ID) |
| 14 | Web URLs | Remove |
| 15 | IP addresses | Remove |
| 16 | Biometric identifiers | Remove |
| 17 | Full-face photographs | Remove or redact |
| 18 | Any other unique identifier | Assess and remove |

**In clinical trial data:** Most identifiers are already absent. The common
risks are dates (convert to study days), site numbers (may identify small
sites), and rare conditions (small subgroups may be re-identifiable).

```sql
-- Verify no raw dates leak into exports (ADaM should use numeric AVAL)
SELECT DISTINCT PARAMCD
FROM adtte
WHERE ADT IS NOT NULL  -- ADT is a date; AVAL (numeric) is preferred for exports
```

## Protocol Deviation Documentation

### Categories

| Category | Definition | Impact |
|----------|-----------|--------|
| **Minor** | Does not affect safety or data integrity | Document only |
| **Major** | May affect safety, data integrity, or rights | Requires CAPA |
| **Violation** | Serious — threatens subject safety or data | Immediate action + reporting |

### Required Documentation

For each deviation:
1. **Description** — what happened, factually
2. **Subject(s) affected** — USUBJID(s)
3. **Date of occurrence**
4. **Category** — minor / major / violation
5. **Impact assessment** — effect on safety and data integrity
6. **Root cause** — why it happened
7. **CAPA** — corrective and preventive actions taken
8. **Reporting** — who was notified (sponsor, IRB, regulatory)

### Common Deviation Types

| Type | Example | Typical Category |
|------|---------|-----------------|
| Eligibility | Subject enrolled who didn't meet inclusion criteria | Major |
| Informed consent | Consent form signed after study procedures | Major/Violation |
| Visit window | Visit conducted outside protocol-specified window | Minor |
| Dose modification | Dose not reduced per protocol for toxicity | Major |
| Prohibited medication | Subject took excluded concomitant medication | Minor–Major |
| Missing assessment | Required safety lab not collected | Minor |

```sql
-- Protocol deviations often tracked in a supplemental dataset
-- or can be identified from data discrepancies
-- Example: subjects with visit dates outside windows
SELECT USUBJID, AVISIT, ADT, AVISIT_TARGET_DT,
       ABS(DATEDIFF('day', ADT, AVISIT_TARGET_DT)) AS days_from_target
FROM advs
WHERE ABS(DATEDIFF('day', ADT, AVISIT_TARGET_DT)) > 7  -- example: 7-day window
ORDER BY days_from_target DESC
```

## Related Skills

- `safety-review-workflow` — structured safety review workflow
- `safety-signal-review` — signal criteria and phased safety analysis
- `oncology-endpoints` — endpoint definitions for CSR efficacy sections
- `adam-explorer` — ADaM dataset and variable reference
- `sdtm-explorer` — SDTM domain reference (source data for CSR appendices)
