---
name: adam-explorer
description: >
  Use when querying ADaM (analysis) data. Maps clinical questions to ADaM
  datasets and key analysis variables. Prefer ADaM over SDTM for analysis.
---

# ADaM Data Navigator

## First Query Pattern

Establish context in ONE query before diving into specifics:

```sql
SELECT TRT01A,
       COUNT(*) as N,
       SUM(CASE WHEN SAFFL = 'Y' THEN 1 ELSE 0 END) as N_SAFETY,
       SUM(CASE WHEN ITTFL = 'Y' THEN 1 ELSE 0 END) as N_ITT,
       ROUND(AVG(TRTEDT - TRTSDT), 0) as MEAN_EXPOSURE_DAYS
FROM adsl GROUP BY TRT01A
```

Use these numbers throughout — do NOT re-query population counts.

## Quick Dataset Lookup

ADaM datasets are analysis-ready. Prefer them over SDTM whenever available.

| Clinical Question | Dataset | Key Variables |
|-------------------|---------|---------------|
| Demographics, baseline characteristics | ADSL | AGE, AGEU, SEX, RACE, ETHNIC, TRT01P, TRT01A, SAFFL, ITTFL, PPROTFL, TRTSDT, TRTEDT |
| Adverse events | ADAE | AEDECOD, AEBODSYS, AESEV, AESER, AEREL, AEOUT, AEACN, TRTEMFL, ASTDT, AENDT, CQ01NAM, SMQ01NAM |
| Lab results | ADLB | PARAMCD, PARAM, AVAL, BASE, CHG, PCHG, ANRIND, BNRIND, ATOXGR, BTOXGR, A1LO, A1HI, ANL01FL, ABLFL |
| Vital signs | ADVS | PARAMCD, PARAM, AVAL, BASE, CHG, AVISIT, AVISITN, ABLFL, ANL01FL, ONTRTFL |
| ECG results | ADEG | PARAMCD, PARAM, AVAL, BASE, CHG, AVISIT, AVISITN, ABLFL |
| Exposure | ADEX | PARAMCD, AVAL, ASTDT, AENDT (cumulative dose, treatment duration) |
| Time-to-event (survival) | ADTTE | PARAMCD, AVAL (time in days), CNSR (0=event, 1=censored), EVNTDESC, STARTDT |
| PK concentrations | ADPC | PARAMCD, AVAL, ATPT, ATPTN, ARELTM |
| PK parameters | ADPP | PARAMCD, AVAL (AUC, Cmax, Tmax, T½) |
| Efficacy response (oncology) | ADRS | PARAMCD, AVALC (CR, PR, SD, PD), RSEVAL |
| Tumor measurements (oncology) | ADTR | PARAMCD, AVAL, CHG, PCHG |
| Concomitant medications | ADCM | CMDECOD, CMCLAS, ASTDT, AENDT |
| Medical history | ADMH | MHDECOD, MHBODSYS |

## The Analysis Variable Triad

Every BDS (Basic Data Structure) dataset uses this core pattern:

```
AVAL   = numeric analysis value (the measurement)
AVALC  = character analysis value (for categorical results)
BASE   = baseline value (the record where ABLFL = 'Y')
CHG    = change from baseline = AVAL - BASE
PCHG   = percent change from baseline = 100 * (AVAL - BASE) / BASE
```

**Critical flags:**
- `ABLFL = 'Y'` — this record IS the baseline value
- `ANL01FL = 'Y'` — this record is included in the primary analysis
- `ONTRTFL = 'Y'` — this record is on-treatment
- `TRTEMFL = 'Y'` — this AE is treatment-emergent (ADAE-specific)

## Population Flags (ADSL)

Population flags live in ADSL. Join ADSL to any analysis dataset for filtering.
**Values are Y/N (never null for subject-level flags).**

| Flag | Population | Typical Definition |
|------|-----------|-------------------|
| SAFFL | Safety | Received any amount of study drug |
| ITTFL | Intent-to-Treat | All randomized subjects |
| FASFL | Full Analysis Set | Modified ITT (randomized + ≥1 post-baseline) |
| PPROTFL | Per-Protocol | Completed without major deviations |
| RANDFL | Randomized | Randomized (may not have received drug) |
| COMPLFL | Completers | Completed the study |

```sql
-- Safety population count by arm
SELECT TRT01A, COUNT(*) as N
FROM adsl WHERE SAFFL = 'Y'
GROUP BY TRT01A

-- Join any dataset to ADSL for population + arm
SELECT adsl.TRT01A, adsl.AGEGR1, adsl.SEX, adae.*
FROM adae
JOIN adsl ON adae.USUBJID = adsl.USUBJID
WHERE adsl.SAFFL = 'Y'
```

## Treatment Variables

ADaM uses indexed treatment variables for multi-period studies:

| Variable | Meaning |
|----------|---------|
| TRT01P | Planned treatment — Period 01 |
| TRT01A | Actual treatment — Period 01 |
| TRT01PN | Planned treatment (numeric code) |
| TRT01AN | Actual treatment (numeric code) |
| TRTP | Analysis treatment (in BDS datasets, may equal TRT01P) |
| TRTPN | Analysis treatment (numeric) |

**Use TRT01A (actual) for safety analyses. Use TRT01P (planned) for efficacy (ITT).**

## Common PARAMCD Values

### ADLB (Laboratory)
**Hepatic:** ALT, AST, BILI, BILITOT, ALP, GGT, LDH, ALB
**Hematology:** HGB, HCT, WBC, RBC, PLAT, ANC, LYMPH, MONO, EOS, BASO, NEUT
**Chemistry:** CREAT, BUN, GLUC, SODIUM, K, CALCIUM, PHOS, URATE, CK, CO2, CL, MG
**Lipids:** CHOL, TRIG, HDL, LDL
**Coagulation:** PT, APTT, INR
**Urinalysis:** URPROT, URGLUC

### ADVS (Vital Signs)
SYSBP, DIABP, PULSE, TEMP, WEIGHT, HEIGHT, BMI, RESP

### ADEG (ECG)
QTCF (QTc Fridericia), QTCB (QTc Bazett), HR, QT, PR, QRS, RR

### ADTTE (Time-to-Event)
OS (overall survival), PFS (progression-free survival), EFS (event-free survival),
DOR (duration of response), TTR (time to response), TTDE (time to discontinuation)

### ADRS (Tumor Response — Oncology)
BOR (best overall response), OVRLRESP (overall response per visit),
CB (clinical benefit: CR+PR+SD≥24wk)

## ADAE-Specific Patterns

ADAE is the most-queried dataset for safety. Key patterns:

```sql
-- Treatment-emergent AE incidence by SOC and arm
SELECT adsl.TRT01A, adae.AEBODSYS,
       COUNT(DISTINCT adae.USUBJID) as N_SUBJ
FROM adae
JOIN adsl ON adae.USUBJID = adsl.USUBJID
WHERE adsl.SAFFL = 'Y' AND adae.TRTEMFL = 'Y'
GROUP BY adsl.TRT01A, adae.AEBODSYS
ORDER BY adae.AEBODSYS

-- AE incidence by PT within a SOC
SELECT adsl.TRT01A, adae.AEBODSYS, adae.AEDECOD,
       COUNT(DISTINCT adae.USUBJID) as N_SUBJ
FROM adae
JOIN adsl ON adae.USUBJID = adsl.USUBJID
WHERE adsl.SAFFL = 'Y' AND adae.TRTEMFL = 'Y'
GROUP BY adsl.TRT01A, adae.AEBODSYS, adae.AEDECOD
ORDER BY adae.AEBODSYS, N_SUBJ DESC

-- Serious AEs
SELECT adsl.TRT01A, adae.AEDECOD, adae.AEBODSYS,
       adae.USUBJID, adae.AESEV, adae.AEOUT
FROM adae
JOIN adsl ON adae.USUBJID = adsl.USUBJID
WHERE adsl.SAFFL = 'Y' AND adae.AESER = 'Y'

-- AEs leading to drug discontinuation
SELECT adsl.TRT01A, adae.AEDECOD,
       COUNT(DISTINCT adae.USUBJID) as N_SUBJ
FROM adae
JOIN adsl ON adae.USUBJID = adsl.USUBJID
WHERE adsl.SAFFL = 'Y' AND adae.AEACN = 'DRUG WITHDRAWN'
GROUP BY adsl.TRT01A, adae.AEDECOD

-- Deaths
SELECT adae.USUBJID, adsl.TRT01A, adae.AEDECOD, adae.AEBODSYS
FROM adae
JOIN adsl ON adae.USUBJID = adsl.USUBJID
WHERE adae.AEOUT = 'FATAL'

-- Grade 3+ AEs (if ATOXGR available)
SELECT adsl.TRT01A, adae.AEDECOD,
       COUNT(DISTINCT adae.USUBJID) as N_SUBJ
FROM adae
JOIN adsl ON adae.USUBJID = adsl.USUBJID
WHERE adsl.SAFFL = 'Y' AND adae.TRTEMFL = 'Y'
  AND CAST(adae.ATOXGR AS INTEGER) >= 3
GROUP BY adsl.TRT01A, adae.AEDECOD
```

## ADLB-Specific Patterns

```sql
-- Lab values over time for a specific parameter
SELECT adsl.TRT01A, adlb.AVISIT, adlb.AVISITN,
       AVG(adlb.AVAL) as MEAN_VAL,
       AVG(adlb.CHG) as MEAN_CHG
FROM adlb
JOIN adsl ON adlb.USUBJID = adsl.USUBJID
WHERE adsl.SAFFL = 'Y' AND adlb.PARAMCD = 'ALT' AND adlb.ANL01FL = 'Y'
GROUP BY adsl.TRT01A, adlb.AVISIT, adlb.AVISITN
ORDER BY adlb.AVISITN

-- Subjects with values above ULN (using reference range)
SELECT USUBJID, AVISIT, AVAL, A1HI,
       ROUND(AVAL / A1HI, 1) as XULN
FROM adlb
WHERE PARAMCD = 'ALT' AND AVAL > A1HI AND ANL01FL = 'Y'
ORDER BY XULN DESC

-- Baseline to worst post-baseline shift (simplified)
SELECT adsl.TRT01A, adlb.BNRIND as BASELINE_CAT, adlb.ANRIND as POST_BL_CAT,
       COUNT(DISTINCT adlb.USUBJID) as N_SUBJ
FROM adlb
JOIN adsl ON adlb.USUBJID = adsl.USUBJID
WHERE adsl.SAFFL = 'Y' AND adlb.PARAMCD = 'ALT'
  AND adlb.ABLFL IS NULL  -- post-baseline records
  AND adlb.ANRIND IS NOT NULL
GROUP BY adsl.TRT01A, adlb.BNRIND, adlb.ANRIND

-- CTCAE toxicity grade distribution (if ATOXGR present)
SELECT adsl.TRT01A, adlb.PARAMCD,
       adlb.ATOXGR as GRADE,
       COUNT(DISTINCT adlb.USUBJID) as N_SUBJ
FROM adlb
JOIN adsl ON adlb.USUBJID = adsl.USUBJID
WHERE adsl.SAFFL = 'Y' AND adlb.PARAMCD IN ('ALT', 'AST', 'BILI')
  AND adlb.ABLFL IS NULL AND adlb.ATOXGR IS NOT NULL
GROUP BY adsl.TRT01A, adlb.PARAMCD, adlb.ATOXGR
```

## ADTTE-Specific Patterns

```sql
-- Kaplan-Meier input data
SELECT adsl.TRT01A, adtte.AVAL as TIME_DAYS, adtte.CNSR,
       adtte.EVNTDESC
FROM adtte
JOIN adsl ON adtte.USUBJID = adsl.USUBJID
WHERE adtte.PARAMCD = 'OS'  -- overall survival
ORDER BY adsl.TRT01A, adtte.AVAL

-- Median time-to-event by arm (approximate)
SELECT adsl.TRT01A,
       COUNT(*) as N,
       SUM(CASE WHEN adtte.CNSR = 0 THEN 1 ELSE 0 END) as N_EVENTS,
       MEDIAN(adtte.AVAL) as MEDIAN_TIME
FROM adtte
JOIN adsl ON adtte.USUBJID = adsl.USUBJID
WHERE adtte.PARAMCD = 'PFS'
GROUP BY adsl.TRT01A
```

## Derived Record Types (DTYPE)

When DTYPE is populated, the record is derived (not directly observed):

| DTYPE | Meaning |
|-------|---------|
| LOCF | Last observation carried forward |
| WOCF | Worst observation carried forward |
| BOCF | Baseline observation carried forward |
| AVERAGE | Average of multiple values |
| MINIMUM | Minimum value in window |
| MAXIMUM | Maximum value in window |

**For analysis, check which DTYPE records are included in ANL01FL = 'Y'.**

## ADaM vs SDTM Decision

- **Use ADaM when:** performing any analysis, computing rates, making
  tables/figures. ADaM has pre-derived analysis variables (AVAL, CHG, BASE),
  population flags, and analysis record flags.
- **Use SDTM when:** ADaM datasets are not available, or you need raw collected
  data (verbatim terms, original units, visit-level detail not in ADaM).
- **How to tell which is available:** Call `the schema-discovery tool`. ADaM files
  start with `AD` (adsl.xpt, adae.xpt, adlb.xpt). SDTM files are 2-character
  codes (dm.xpt, ae.xpt, lb.xpt).

## Related Skills

- Use `sdtm-explorer` when ADaM is unavailable and you must work with SDTM
- Use `toxicity-grading` for CTCAE toxicity grade criteria and thresholds
- Use `safety-signal-review` for systematic safety review framework
- Use `safety-review-workflow` for step-by-step medical monitor review workflow
