---
name: sdtm-explorer
description: >
  Use when querying SDTM (tabulation) data. Maps clinical questions to SDTM
  domains, variables, and join patterns. Covers all observation classes.
---

# SDTM Data Navigator

## Quick Domain Lookup

When a clinician asks about clinical data, map their question to the right SDTM domain:

| Clinical Question | Domain | Key Variables |
|-------------------|--------|---------------|
| Subject demographics, enrollment | DM | AGE, AGEU, SEX, RACE, ETHNIC, ARM, ACTARM, COUNTRY, RFSTDTC, RFENDTC |
| Adverse events | AE | AETERM, AEDECOD, AEBODSYS, AESEV, AESER, AEREL, AEOUT, AEACN, AESTDTC, AEENDTC |
| Lab results | LB | LBTESTCD, LBTEST, LBORRES, LBSTRESN, LBSTRESU, LBSTNRLO, LBSTNRHI, LBNRIND, LBSPEC |
| Vital signs | VS | VSTESTCD, VSTEST, VSORRES, VSSTRESN, VSSTRESU, VSPOS, VSLOC |
| ECG results | EG | EGTESTCD, EGTEST, EGORRES, EGSTRESN, EGSTRESU, EGTPT |
| Drug exposure / dosing | EX | EXTRT, EXDOSE, EXDOSU, EXDOSFRM, EXDOSFRQ, EXROUTE, EXSTDTC, EXENDTC |
| Concomitant medications | CM | CMTRT, CMDECOD, CMCLAS, CMCLASCD, CMSTDTC, CMENDTC, CMDOSE, CMDOSU |
| Medical history | MH | MHTERM, MHDECOD, MHBODSYS, MHCAT, MHSTDTC, MHENDTC |
| Disposition (completion, withdrawal) | DS | DSTERM, DSDECOD, DSCAT, DSSCAT, DSSTDTC |
| Physical examination | PE | PETESTCD, PETEST, PEORRES, PESTRESC, PELOC |
| PK concentrations | PC | PCTESTCD, PCTEST, PCSTRESN, PCSTRESU, PCTPT, PCSPEC |
| PK parameters | PP | PPTESTCD, PPTEST, PPSTRESN, PPSTRESU, PPCAT |
| Subject visits | SV | VISITNUM, VISIT, SVSTDTC, SVENDTC |
| Inclusion/exclusion | IE | IETESTCD, IETEST, IEORRES, IESTRESC |
| Protocol deviations | DV | DVTERM, DVDECOD, DVCAT, DVSTDTC |
| Questionnaires | QS | QSTESTCD, QSTEST, QSORRES, QSSTRESN, QSCAT |
| Tumor measurements (oncology) | TU | TUTESTCD, TUTEST, TUORRES, TULOC, TULAT |
| Tumor response (oncology) | RS | RSTESTCD, RSTEST, RSORRES, RSSTRESC, RSEVAL |
| Subject characteristics | SC | SCTESTCD, SCTEST, SCORRES, SCSTRESC |
| Study design, endpoints, protocol metadata | TS | TSPARMCD, TSVAL (one row per parameter, no USUBJID) |
| Treatment arms and epochs | TA | ARM, ARMCD, EPOCH, ELEMENT, TAETORD |

## Observation Classes

SDTM organizes domains into three classes. This determines the row structure:

### Events Class (one row per event)
Domains: **AE**, **DS**, **MH**, **CE**, **DV**, **HO**

Query pattern: filter by `--TERM` (verbatim) or `--DECOD` (dictionary-coded).
Each row is one occurrence. Use `--STDTC` / `--ENDTC` for timing.

### Findings Class (one row per test per timepoint)
Domains: **LB**, **VS**, **EG**, **PE**, **QS**, **SC**, **DA**, **FA**, **IE**, **MB**, **MS**, **PC**, **PP**

Query pattern: filter by `--TESTCD` (short code) or `--TEST` (full name).
Numeric result in `--STRESN`, character in `--STRESC`, units in `--STRESU`.
Reference range: `--STNRLO` (low), `--STNRHI` (high), `--NRIND` (indicator).

### Interventions Class (one row per treatment per interval)
Domains: **CM**, **EX**, **EC**, **SU**, **PR**, **AG**

Query pattern: filter by `--TRT` (treatment name) or `--DECOD` (coded name).
Duration via `--STDTC` / `--ENDTC`. Dose in `--DOSE`, units in `--DOSU`.

## Variable Naming Convention

SDTM uses a `domain prefix + suffix` pattern. The `--` represents the 2-character domain code.

| Suffix | Meaning | Example |
|--------|---------|---------|
| `--TERM` | Verbatim/reported term | AETERM = "headache" |
| `--DECOD` | Dictionary-coded term | AEDECOD = "Headache" (MedDRA PT) |
| `--BODSYS` | Body system (SOC) | AEBODSYS = "Nervous system disorders" |
| `--SEV` | Severity | AESEV = "MODERATE" |
| `--SER` | Serious (Y/N) | AESER = "Y" |
| `--REL` | Relationship to drug | AEREL = "RELATED" |
| `--OUT` | Outcome | AEOUT = "RECOVERED/RESOLVED" |
| `--ACN` | Action taken | AEACN = "DRUG WITHDRAWN" |
| `--TESTCD` | Short test code | LBTESTCD = "ALT" |
| `--TEST` | Full test name | LBTEST = "Alanine Aminotransferase" |
| `--ORRES` | Original result | LBORRES = "45" |
| `--STRESN` | Standardized numeric result | LBSTRESN = 45.0 |
| `--STRESC` | Standardized character result | LBSTRESC = "45" |
| `--STRESU` | Standard units | LBSTRESU = "U/L" |
| `--STNRLO` | Standard reference range low | LBSTNRLO = 7.0 |
| `--STNRHI` | Standard reference range high | LBSTNRHI = 56.0 |
| `--NRIND` | Reference range indicator | LBNRIND = "NORMAL" |
| `--BLFL` | Baseline flag (Y/null) | LBBLFL = "Y" |
| `--DTC` | Date/time of collection (ISO 8601) | AESTDTC = "2024-03-15" |
| `--STDTC` | Start date/time | EXSTDTC |
| `--ENDTC` | End date/time | EXENDTC |
| `--DY` | Study day (no Day 0) | AESTDY = 15 |
| `--TRT` | Treatment name | EXTRT = "Drug A 100mg" |
| `--DOSE` | Dose amount | EXDOSE = 100 |
| `--DOSU` | Dose units | EXDOSU = "mg" |
| `--STAT` | Completion status | LBSTAT = "NOT DONE" |

## Common Join Patterns

```sql
-- Join any domain to demographics for arm/population info
SELECT dm.USUBJID, dm.ARM, dm.ACTARM, dm.AGE, dm.SEX, ae.*
FROM dm
JOIN ae ON dm.USUBJID = ae.USUBJID

-- Filter findings by specific test
SELECT * FROM lb WHERE LBTESTCD = 'ALT'

-- Time-series for a single subject
SELECT VISITNUM, VISIT, VSSTRESN
FROM vs
WHERE USUBJID = 'SUBJ-001' AND VSTESTCD = 'SYSBP'
ORDER BY VISITNUM

-- AE incidence by SOC and arm
SELECT dm.ARM, ae.AEBODSYS, COUNT(DISTINCT ae.USUBJID) as N_SUBJ
FROM ae
JOIN dm ON ae.USUBJID = dm.USUBJID
GROUP BY dm.ARM, ae.AEBODSYS
ORDER BY ae.AEBODSYS

-- Lab values with reference range context
SELECT USUBJID, VISITNUM, LBTESTCD, LBSTRESN, LBSTRESU,
       LBSTNRLO, LBSTNRHI, LBNRIND
FROM lb
WHERE LBTESTCD IN ('ALT', 'AST', 'BILI')
ORDER BY USUBJID, LBTESTCD, VISITNUM

-- Concomitant medications by class
SELECT dm.ARM, cm.CMCLAS, COUNT(DISTINCT cm.USUBJID) as N_SUBJ
FROM cm
JOIN dm ON cm.USUBJID = dm.USUBJID
GROUP BY dm.ARM, cm.CMCLAS

-- Subjects who discontinued due to AEs
SELECT ds.USUBJID, ds.DSDECOD, ae.AEDECOD, ae.AESEV
FROM ds
JOIN dm ON ds.USUBJID = dm.USUBJID
LEFT JOIN ae ON ds.USUBJID = ae.USUBJID AND ae.AEACN = 'DRUG WITHDRAWN'
WHERE ds.DSCAT = 'DISPOSITION EVENT' AND ds.DSDECOD LIKE '%ADVERSE%'
```

## Trial Design Domains (No USUBJID)

TS and TA are trial-level. They have NO USUBJID — query them directly.
**For study design questions, query TS first.**

### TS (Trial Summary) — Key-Value Pairs

| TSPARMCD | Meaning |
|----------|---------|
| TITLE | Study title |
| TPHASE | Trial phase |
| INDIC | Indication |
| OBJPRIM | Primary objective |
| OBJSEC | Secondary objective |
| OUTMSPRI | Primary outcome measure |
| OUTMSSEC | Secondary outcome measure |
| STYPE | Study type (Interventional, Observational) |
| PCLAS | Pharmacological class |
| PLESSION | Planned number of subjects |

```sql
-- Study design overview
SELECT TSPARMCD, TSVAL FROM ts
WHERE TSPARMCD IN ('TITLE','TPHASE','INDIC','OBJPRIM','OBJSEC',
                   'OUTMSPRI','OUTMSSEC','STYPE','PCLAS')

-- All endpoints
SELECT TSPARMCD, TSVAL FROM ts
WHERE TSPARMCD LIKE 'OUTMS%' OR TSPARMCD LIKE 'OBJ%'
```

### TA (Trial Arms)

```sql
SELECT DISTINCT ARM, ARMCD FROM ta ORDER BY ARMCD
```

**TS/TA vs ADSL:** TS for protocol metadata (endpoints, phase). ADSL for
subject-level data (actual arm assignments, population counts).

## Controlled Terminology Reference

### AE Severity (AESEV)
MILD, MODERATE, SEVERE

### AE Seriousness (AESER)
Y, N

### AE Relationship (AEREL)
NOT RELATED, UNLIKELY RELATED, POSSIBLY RELATED, RELATED, PROBABLY RELATED

### AE Outcome (AEOUT)
RECOVERED/RESOLVED, RECOVERING/RESOLVING, NOT RECOVERED/NOT RESOLVED,
RECOVERED/RESOLVED WITH SEQUELAE, FATAL, UNKNOWN

### AE Action Taken (AEACN)
DOSE NOT CHANGED, DOSE REDUCED, DRUG INTERRUPTED, DRUG WITHDRAWN, NOT APPLICABLE

### Reference Range Indicator (NRIND)
LOW, NORMAL, HIGH, ABNORMAL, CLINICALLY SIGNIFICANT

### Sex
F, M, U, UNDIFFERENTIATED

### Race
AMERICAN INDIAN OR ALASKA NATIVE, ASIAN, BLACK OR AFRICAN AMERICAN,
NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER, WHITE, MULTIPLE, OTHER, UNKNOWN

### MedDRA Hierarchy (for AEs and Medical History)
- **SOC** (System Organ Class) — broadest: "Nervous system disorders"
- **HLGT** (High Level Group Term)
- **HLT** (High Level Term)
- **PT** (Preferred Term) — standard reporting level: "Headache"
- **LLT** (Lowest Level Term) — most specific

### Common Lab Test Codes (LBTESTCD)
**Hepatic:** ALT, AST, BILI, BILITOT, ALP, GGT, LDH, ALB
**Hematology:** HGB, HCT, WBC, RBC, PLAT, ANC, LYMPH, MONO, EOS, BASO
**Chemistry:** CREAT, BUN, GLUC, SODIUM, K (potassium), CALCIUM, PHOS, URATE, CK
**Lipids:** CHOL, TRIG, HDL, LDL
**Coagulation:** PT (prothrombin time), APTT, INR
**Urinalysis:** URPROT, URGLUC, UBLOOD

### Common Vital Sign Test Codes (VSTESTCD)
SYSBP (systolic BP), DIABP (diastolic BP), PULSE, TEMP, WEIGHT, HEIGHT, BMI, RESP

### Common ECG Test Codes (EGTESTCD)
HR, QT, QTCF (Fridericia), QTCB (Bazett), PR, QRS, RR

## Data Discovery Strategy

When you encounter unfamiliar study data:

1. **Profile first:** Call `the schema-discovery tool` to see available files
2. **Identify format:** SDTM uses 2-character domain codes (AE.xpt, DM.xpt, LB.xpt)
3. **Check for ADaM:** If files starting with AD exist (ADSL, ADAE, ADLB), prefer those for analysis — use the `adam-explorer` skill instead
4. **Check for SUPP domains:** SUPPAE, SUPPLB etc. contain supplemental qualifiers
5. **Join through USUBJID:** This is the universal subject key across all domains
6. **DM is always the anchor:** Start from DM for population counts, arm assignments, demographics
