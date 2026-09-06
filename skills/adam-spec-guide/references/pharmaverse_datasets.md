# Pharmaverse ADaM Datasets Reference

This document describes the example ADaM datasets available in the `{pharmaverseadam}` R package, which provides test data following the CDISC ADaM standard.

## Installation

```r
# From CRAN
install.packages("pharmaverseadam")

# Development version from GitHub
pak::pkg_install("pharmaverse/pharmaverseadam", dependencies = TRUE)
```

## Core ADaM Datasets

### ADSL - Subject-Level Analysis Dataset
The foundational ADaM dataset with one record per subject.

**Key Variables:**
- Identifiers: STUDYID, USUBJID, SUBJID, SITEID
- Demographics: AGE, AGEU, SEX, RACE, ETHNIC
- Treatment: ARM, ACTARM, TRT01P, TRT01A
- Timing: TRTSDT, TRTEDT, TRTDURD
- Population flags: SAFFL (Safety Population Flag)
- Death info: DTHDT, DTHFL, DTHCAUS

**Usage:**
```r
data("adsl")
```

### ADAE - Adverse Events Analysis Dataset
Contains adverse event data following OCCDS (Occurrence Data Structure).

**Key Variables:**
- Identifiers: STUDYID, USUBJID, AESEQ
- AE coding: AETERM, AEDECOD, AEBODSYS, AESOC
- Timing: ASTDT, AENDT, ASTDY, AENDY
- Severity: AESEV, ASEV, ASEVN
- Flags: TRTEMFL (Treatment Emergent)
- Seriousness: AESER, AESDTH, AESLIFE

**Usage:**
```r
data("adae")
```

### ADVS - Vital Signs Analysis Dataset
BDS dataset for vital signs parameters.

**Parameters:**
- BMI - Body Mass Index (kg/m^2)
- BSA - Body Surface Area (m^2)
- DIABP - Diastolic Blood Pressure (mmHg)
- HEIGHT - Height (cm)
- MAP - Mean Arterial Pressure (mmHg)
- PULSE - Pulse Rate (beats/min)
- SYSBP - Systolic Blood Pressure (mmHg)
- TEMP - Temperature (C)
- WEIGHT - Weight (kg)

**Key Variables:**
- Identifiers: STUDYID, USUBJID, PARAMCD, PARAM
- Analysis: AVAL, BASE, CHG, PCHG
- Timing: ADT, ADY, AVISIT, AVISITN, ATPT
- Flags: ABLFL, ANL01FL, ONTRTFL
- Ranges: ANRIND, BNRIND, ANRLO, ANRHI

**Usage:**
```r
data("advs")
```

### ADLB - Laboratory Analysis Dataset
BDS dataset for laboratory parameters.

**Parameters (47 total):** ALB, ALT, AST, BILI, BUN, CA, CHOLES, CK, CL, CREAT, GGT, GLUC, HBA1C, HCT, HGB, PLAT, POTAS, PROT, RBC, SODIUM, TSH, WBC, and more.

**Key Variables:**
- Identifiers: STUDYID, USUBJID, PARAMCD, PARAM, PARCAT1
- Analysis: AVAL, AVALC, BASE, BASEC, CHG, PCHG, R2BASE
- Toxicity: ATOXGR, BTOXGR, ATOXGRL, ATOXGRH
- Timing: ADT, ADY, AVISIT, AVISITN
- Flags: ABLFL, ANL01FL, ONTRTFL, LVOTFL
- Shifts: SHIFT1, SHIFT2

**Usage:**
```r
data("adlb")
```

## Specialized ADaM Datasets

### ADEG - ECG Analysis Dataset
BDS dataset for electrocardiogram data.

**Usage:**
```r
data("adeg")
```

### ADCM - Concomitant Medications Analysis Dataset
For concomitant medication data.

**Usage:**
```r
data("adcm")
```

### ADMH - Medical History Analysis Dataset
For medical history data.

**Usage:**
```r
data("admh")
```

### ADEX - Exposure Analysis Dataset
For study drug exposure data.

**Usage:**
```r
data("adex")
```

## Therapeutic Area Extensions

### Oncology
- **ADRS** - Response Analysis (adrs_onco)
- **ADTR** - Tumor Results Analysis (adtr_onco)
- **ADTTE** - Time-to-Event Analysis (adtte_onco)

```r
data("adrs_onco")
data("adtr_onco")
data("adtte_onco")
```

### Ophthalmology
- **ADBCVA** - Best Corrected Visual Acuity (adbcva_ophtha)
- **ADVFQ** - Visual Function Questionnaire (advfq_ophtha)
- **ADOE** - Ophthalmic Examination (adoe_ophtha)

```r
data("adbcva_ophtha")
data("advfq_ophtha")
data("adoe_ophtha")
```

### Vaccine
- **ADSL** - Subject Level (adsl_vaccine)
- **ADIS** - Immunogenicity Specimen (adis_vaccine)
- **ADCE** - Clinical Events (adce_vaccine)
- **ADFACE** - Finding About Clinical Events (adface_vaccine)

```r
data("adsl_vaccine")
data("adis_vaccine")
data("adce_vaccine")
data("adface_vaccine")
```

### Metabolic
- **ADCOEQ** - Clinical Outcome Questionnaire (adcoeq_metabolic)
- **ADLB** - Laboratory (adlb_metabolic)
- **ADVS** - Vital Signs (advs_metabolic)

```r
data("adcoeq_metabolic")
data("adlb_metabolic")
data("advs_metabolic")
```

### Pediatric
- **ADVS** - Vital Signs Pediatric (advs_peds)

```r
data("advs_peds")
```

### Pharmacokinetics
- **ADPC** - Pharmacokinetic Concentrations
- **ADPP** - Pharmacokinetic Parameters
- **ADPPK** - Population PK

```r
data("adpc")
data("adpp")
data("adppk")
```

## Hy's Law Dataset

### ADLBHY - Laboratory Hy's Law
Special dataset for Hy's Law analysis (drug-induced liver injury).

**Usage:**
```r
data("adlbhy")
```

## Common Variable Patterns

### BDS Dataset Key Variables

| Variable | Description |
|----------|-------------|
| PARAM | Parameter description (with units) |
| PARAMCD | Parameter code (short name) |
| PARAMN | Numeric parameter identifier |
| AVAL | Analysis value (numeric) |
| AVALC | Analysis value (character) |
| BASE | Baseline value |
| CHG | Change from baseline (AVAL - BASE) |
| PCHG | Percent change from baseline |
| ABLFL | Baseline record flag (Y/null) |
| ADT | Analysis date |
| ADY | Analysis relative day |
| AVISIT | Analysis visit |
| AVISITN | Analysis visit (numeric) |

### Treatment Variables

| Variable | Description |
|----------|-------------|
| TRTP | Planned treatment (record-level) |
| TRTA | Actual treatment (record-level) |
| TRT01P | Planned treatment for Period 01 |
| TRT01A | Actual treatment for Period 01 |

### Population Flags

| Variable | Description |
|----------|-------------|
| SAFFL | Safety population flag |
| ITTFL | Intent-to-treat population flag |
| FASFL | Full analysis set population flag |
| PPROTFL | Per-protocol population flag |

## Source

These datasets are generated from the admiral family of packages:
- `{admiral}` - Core ADaM programming
- `{admiralonco}` - Oncology extension
- `{admiralophtha}` - Ophthalmology extension
- `{admiralvaccine}` - Vaccine extension
- `{admiralpeds}` - Pediatric extension
- `{admiralmetabolic}` - Metabolic extension

All source SDTM data comes from `{pharmaversesdtm}`.
