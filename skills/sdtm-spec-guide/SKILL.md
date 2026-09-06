---
name: sdtm-spec-guide
description: This skill should be used when users need to understand, create, review, or validate CDISC SDTM (Study Data Tabulation Model) datasets for clinical trials. Use for questions about SDTM data structures, domain specifications (DM, AE, LB, VS, EX, etc.), variable naming conventions, observation classes (Interventions, Events, Findings), controlled terminology, or when working with pharmaverse SDTM packages like pharmaversesdtm. Also use when reviewing clinical trial tabulation datasets for regulatory submissions or when creating SDTM datasets from raw clinical data.
---

# SDTM Standard Guide

## Overview

The Study Data Tabulation Model (SDTM) is a CDISC standard for organizing and formatting clinical trial data for regulatory submission. SDTM provides a standardized structure for tabulation data collected during clinical studies, enabling consistent data representation across studies and sponsors.

## SDTM Observation Classes

SDTM organizes domains into three primary observation classes:

### 1. Interventions Class

Records of investigational, therapeutic, or other treatments administered or used by the subject, or planned to be administered or used.

| Domain | Description | Key Topic Variable |
|--------|-------------|-------------------|
| CM | Concomitant Medications | CMTRT |
| EX | Exposure | EXTRT |
| EC | Exposure as Collected | ECTRT |
| SU | Substance Use | SUTRT |
| PR | Procedures | PRTRT |
| AG | Procedure Agents | AGTRT |

### 2. Events Class

Records of incidents independent of planned study evaluations occurring during the study or prior to the study.

| Domain | Description | Key Topic Variable |
|--------|-------------|-------------------|
| AE | Adverse Events | AETERM |
| DS | Disposition | DSTERM |
| MH | Medical History | MHTERM |
| CE | Clinical Events | CETERM |
| DV | Protocol Deviations | DVTERM |
| HO | Healthcare Encounters | HOTERM |

### 3. Findings Class

Records of planned evaluations to address specific tests or questions.

| Domain | Description | Key Topic Variable |
|--------|-------------|-------------------|
| LB | Laboratory Test Results | LBTESTCD/LBTEST |
| VS | Vital Signs | VSTESTCD/VSTEST |
| EG | ECG Test Results | EGTESTCD/EGTEST |
| PE | Physical Examination | PETESTCD/PETEST |
| QS | Questionnaires | QSTESTCD/QSTEST |
| SC | Subject Characteristics | SCTESTCD/SCTEST |
| DA | Drug Accountability | DATESTCD/DATEST |
| FA | Findings About | FATESTCD/FATEST |
| IE | Inclusion/Exclusion | IETESTCD/IETEST |
| MB | Microbiology | MBTESTCD/MBTEST |
| MS | Microbiology Susceptibility | MSTESTCD/MSTEST |
| PC | Pharmacokinetic Concentrations | PCTESTCD/PCTEST |
| PP | Pharmacokinetic Parameters | PPTESTCD/PPTEST |

## Special-Purpose Domains

### DM - Demographics (Required)

One record per subject. Contains demographic and trial identification information.

**Required Variables:**
- STUDYID, DOMAIN, USUBJID, SUBJID
- SITEID, SEX
- ARMCD, ARM (planned treatment arm)
- COUNTRY

**Expected Variables:**
- RFSTDTC, RFENDTC (reference period)
- RFXSTDTC, RFXENDTC (first/last treatment)
- AGE, AGEU, RACE
- ACTARMCD, ACTARM (actual treatment arm)

### CO - Comments

Free-text comments that cannot be placed in other domains.

### SE - Subject Elements

Actual elements (periods of time) for each subject.

### SV - Subject Visits

One record per actual visit per subject.

### RELREC - Related Records

Links records across domains or within a domain.

## Variable Categories

### Identifier Variables

| Variable | Description | Required |
|----------|-------------|----------|
| STUDYID | Study identifier | Yes |
| DOMAIN | Domain abbreviation (2-char) | Yes |
| USUBJID | Unique subject identifier | Yes |
| --SEQ | Sequence number within domain | Yes |
| --GRPID | Grouping identifier | No |
| --REFID | Reference identifier | No |
| --SPID | Sponsor-defined identifier | No |

### Timing Variables

| Variable | Description | Format |
|----------|-------------|--------|
| --DTC | Date/time of collection | ISO 8601 |
| --STDTC | Start date/time | ISO 8601 |
| --ENDTC | End date/time | ISO 8601 |
| --DY | Study day of collection | Integer |
| --STDY | Study day of start | Integer |
| --ENDY | Study day of end | Integer |
| --DUR | Duration | ISO 8601 |
| VISITNUM | Visit number | Numeric |
| VISIT | Visit name | Character |
| EPOCH | Trial epoch | Character |

### Result Variables (Findings Class)

| Variable | Description |
|----------|-------------|
| --ORRES | Result in original units |
| --ORRESU | Original units |
| --STRESC | Standardized character result |
| --STRESN | Standardized numeric result |
| --STRESU | Standard units |
| --ORNRLO/--ORNRHI | Original reference range |
| --STNRLO/--STNRHI | Standard reference range |
| --NRIND | Reference range indicator |

### Common Qualifier Variables

| Variable | Description | Values |
|----------|-------------|--------|
| --LOC | Anatomical location | Controlled terminology |
| --LAT | Laterality | LEFT, RIGHT, BILATERAL |
| --DIR | Directionality | ANTERIOR, POSTERIOR, etc. |
| --METHOD | Method of test/observation | Free text or CT |
| --BLFL | Baseline flag | Y or null |
| --EVAL | Evaluator | Character |
| --STAT | Completion status | NOT DONE |
| --REASND | Reason not done | Character |

## Study Day Calculation

Study day (--DY) is calculated relative to RFSTDTC (reference start date):

```
If date >= RFSTDTC: DY = (date - RFSTDTC) + 1
If date < RFSTDTC:  DY = date - RFSTDTC
```

**Important:** There is no Day 0. The day before Day 1 is Day -1.

## ISO 8601 Date/Time Formats

| Precision | Format | Example |
|-----------|--------|---------|
| Year only | YYYY | 2022 |
| Month | YYYY-MM | 2022-07 |
| Date | YYYY-MM-DD | 2022-07-21 |
| Date/Time | YYYY-MM-DDTHH:MM | 2022-07-21T14:30 |
| Full | YYYY-MM-DDTHH:MM:SS | 2022-07-21T14:30:00 |

Partial dates are allowed when complete information is unavailable.

## Controlled Terminology

### Common Codelists

| Codelist | Example Values |
|----------|----------------|
| SEX | F, M, U, UNDIFFERENTIATED |
| RACE | AMERICAN INDIAN OR ALASKA NATIVE, ASIAN, BLACK OR AFRICAN AMERICAN, WHITE, etc. |
| ETHNIC | HISPANIC OR LATINO, NOT HISPANIC OR LATINO |
| NY | N, Y |
| LAT | LEFT, RIGHT, BILATERAL |
| NRIND | LOW, NORMAL, HIGH, ABNORMAL |
| AEOUT | RECOVERED/RESOLVED, NOT RECOVERED/NOT RESOLVED, FATAL, etc. |
| AESEV | MILD, MODERATE, SEVERE |
| AEACN | DOSE NOT CHANGED, DOSE REDUCED, DRUG WITHDRAWN, etc. |

### MedDRA Coding (Events)

Adverse events and medical history use MedDRA hierarchy:
- LLT (Lowest Level Term)
- PT (Preferred Term)
- HLT (High Level Term)
- HLGT (High Level Group Term)
- SOC (System Organ Class)

### WHO Drug Coding (Interventions)

Concomitant medications use WHO Drug Dictionary:
- Drug name
- ATC classification
- Drug class

## Supplemental Qualifiers (SUPP--)

Use supplemental qualifier domains when:
- A non-standard variable is needed
- Variable doesn't fit standard domain structure
- Sponsor-defined qualifiers are required

**SUPP domain structure:**
| Variable | Description |
|----------|-------------|
| RDOMAIN | Related domain |
| USUBJID | Subject identifier |
| IDVAR | Identifying variable (e.g., --SEQ) |
| IDVARVAL | Value of identifying variable |
| QNAM | Qualifier variable name |
| QLABEL | Qualifier label |
| QVAL | Qualifier value |
| QORIG | Origin of data |
| QEVAL | Evaluator |

## Trial Design Domains

### TA - Trial Arms

Describes planned sequence of elements for each arm.

### TE - Trial Elements

Describes unique elements (treatment periods) in the trial.

### TV - Trial Visits

Describes planned visits.

### TI - Trial Inclusion/Exclusion

Lists inclusion/exclusion criteria.

### TS - Trial Summary

Key trial parameters (e.g., study title, sponsor, indication).

## Domain-Specific Guidelines

### AE - Adverse Events

- One record per adverse event
- Collect start/end dates when available
- Use MedDRA for coding (AEDECOD, AEPT, AESOC)
- Capture severity (AESEV) and seriousness (AESER)
- Document action taken (AEACN) and relationship (AEREL)
- Record outcome (AEOUT)

### LB - Laboratory Test Results

- One record per test per timepoint
- Include both original (LBORRES) and standardized (LBSTRESC/LBSTRESN) results
- Document reference ranges
- Set LBBLFL='Y' for baseline records
- Include specimen type (LBSPEC)

### VS - Vital Signs

- One record per measurement per timepoint
- Include subject position (VSPOS) when relevant
- Include anatomical location (VSLOC) and laterality (VSLAT)
- Set VSBLFL='Y' for baseline records

### EX - Exposure

- One record per treatment per constant-dosing interval
- Include dose, unit, form, frequency, route
- Document start/end dates and study days
- Include lot number when available

## Quick Reference Checklist

### Domain Checklist

- [ ] STUDYID, DOMAIN, USUBJID present in all datasets
- [ ] --SEQ unique within subject within domain
- [ ] One record structure matches domain definition
- [ ] All required variables populated
- [ ] Controlled terminology used where specified

### Data Quality

- [ ] No missing required values
- [ ] Valid ISO 8601 dates
- [ ] Study days calculated correctly (no Day 0)
- [ ] Reference ranges appropriate for tests
- [ ] Baseline flags set correctly

### Naming Standards

- [ ] Variable names ≤ 8 characters
- [ ] Variable labels ≤ 40 characters
- [ ] Character variables ≤ 200 characters
- [ ] Domain prefix used correctly

## Reference Materials

### SDTM Implementation Guide

For detailed specifications, variable tables, and examples, consult:
`references/SDTMIG_v3.4.md`

Search patterns for specific content:
```bash
# Search for domain specifications
grep -i "### DM\|### AE\|### LB" references/SDTMIG_v3.4.md

# Search for variable definitions
grep -i "USUBJID\|STUDYID\|--SEQ" references/SDTMIG_v3.4.md

# Search for controlled terminology
grep -i "codelist\|SEX\|RACE\|ETHNIC" references/SDTMIG_v3.4.md

# Search for timing variables
grep -i "timing\|--DTC\|--DY\|VISIT" references/SDTMIG_v3.4.md
```

### Pharmaverse SDTM Datasets

For example datasets and variable structures, consult:
`references/pharmaverse_datasets.md`

This reference includes:
- Core datasets: DM, AE, CM, DS, EG, EX, LB, MH, PC, PP, SV, VS
- Oncology: TU, TR, RS (RECIST, iRECIST, IMWG, CA-125, PCWG3)
- Ophthalmology: AE_OPHTHA, EX_OPHTHA, OE_OPHTHA, QS_OPHTHA
- Vaccine: DM_VACCINE, VS_VACCINE, CE_VACCINE, EX_VACCINE, IS_VACCINE, FACE_VACCINE
- Pediatrics: DM_PEDS, VS_PEDS
- Metabolic: DM_METABOLIC, VS_METABOLIC, LB_METABOLIC, QS_METABOLIC
- Neurology: DM_NEURO, NV_NEURO, AG_NEURO

### Accessing Example Data in R

```r
library(pharmaversesdtm)

# View demographics
head(dm)

# View adverse events
str(ae)

# View lab data
summary(lb)

# Oncology tumor data
head(tu_onco)
head(tr_onco)
head(rs_onco)
```

## Related Resources

- CDISC SDTM Website: https://www.cdisc.org/standards/foundational/sdtm
- CDISC Controlled Terminology: https://www.cdisc.org/standards/terminology
- Pharmaverse: https://pharmaverse.org/
- pharmaversesdtm Package: https://pharmaverse.github.io/pharmaversesdtm/
