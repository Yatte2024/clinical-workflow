---
name: adam-spec-guide
description: This skill should be used when users need to understand, create, review, or validate CDISC ADaM (Analysis Data Model) datasets for clinical trials. Use for questions about ADaM data structures (ADSL, BDS, OCCDS), variable naming conventions, traceability requirements, or when working with pharmaverse ADaM packages like admiral. Also use when reviewing clinical trial analysis datasets for regulatory submissions.
---

# ADaM Standard Guide

## Overview

The Analysis Data Model (ADaM) is a CDISC standard for organizing clinical trial data for statistical analysis and regulatory submission. ADaM datasets are derived from SDTM (Study Data Tabulation Model) data and are designed to be analysis-ready, traceable, and clearly documented.

## ADaM Data Structures

### 1. ADSL - Subject-Level Analysis Dataset

ADSL contains exactly **one record per subject** and is required in every CDISC-conformant submission.

**Required Variables:**
- STUDYID, USUBJID, SUBJID, SITEID
- AGE, AGEU, SEX, RACE
- ARM (planned arm)
- TRT01P (planned treatment for period 01)
- At least one population flag (e.g., SAFFL, ITTFL, FASFL)

**Common Variables:**
- TRTSDT, TRTEDT (treatment start/end dates)
- RANDDT (randomization date)
- EOSSTT, EOSDT (end of study status/date)
- TRT01A (actual treatment)
- Demographic groupings (AGEGRy, RACEGRy)

### 2. BDS - Basic Data Structure

BDS contains **one or more records per subject, per parameter, per analysis timepoint**.

**Required Variables:**
- STUDYID, USUBJID
- PARAMCD, PARAM (parameter code and description)
- At least one treatment variable (TRT01P or TRTP)

**Core Analysis Variables:**
- AVAL (numeric analysis value)
- AVALC (character analysis value)
- BASE (baseline value)
- CHG (change from baseline = AVAL - BASE)
- PCHG (percent change from baseline)

**Timing Variables:**
- ADT (analysis date)
- ADY (analysis relative day)
- AVISIT, AVISITN (analysis visit)
- ATPT, ATPTN (analysis timepoint)

**Flag Variables:**
- ABLFL (baseline record flag: Y/null)
- ANLzzFL (analysis flag)
- ONTRTFL (on treatment flag)

### 3. OCCDS - Occurrence Data Structure

OCCDS is used for adverse events and other occurrence data. Contains one record per occurrence per subject.

## Variable Naming Conventions

### General Rules

1. Maximum 8 characters, start with a letter (A-Z)
2. Only letters, underscore, and numerals (0-9)
3. Labels maximum 40 characters
4. Character variables maximum 200 characters

### Required Suffix Fragments

| Fragment | Purpose | Example |
|----------|---------|---------|
| DT | Numeric date | TRTSDT, ADT |
| TM | Numeric time | TRTSTM |
| DTM | Numeric datetime | TRTSDTM |
| DTF | Date imputation flag | TRTSDTF |
| TMF | Time imputation flag | TRTSTMF |
| DY | Relative day (no day 0) | ADY, ASTDY |
| FL | Character flag (Y/N/null) | ABLFL, SAFFL |
| GRy | Grouping variable | AGEGR1, RACEGR1 |

### Naming Patterns

**Indexed Variables:**
- `y` = single digit [1-9] for groupings/criteria (e.g., AGEGR1, AVALCATy)
- `xx` = zero-padded 2-digit for periods [01-99] (e.g., TRT01P, TR01SDT)
- `zz` = zero-padded 2-digit counter [01-99] (e.g., ANL01FL)

**Variable Pairs:**
- Primary variable without suffix: TRTP (character)
- Secondary variable with N suffix: TRTPN (numeric)
- One-to-one relationship required when both present

### Same Name, Same Meaning Rule

Any variable with the same name as an SDTM variable must be an exact copy. To modify SDTM values, create a new ADaM variable name.

## Population Flags

| Flag | Description | Values |
|------|-------------|--------|
| SAFFL | Safety Population | Y/N (required, no nulls) |
| ITTFL | Intent-to-Treat | Y/N |
| FASFL | Full Analysis Set | Y/N |
| PPROTFL | Per-Protocol | Y/N |
| RANDFL | Randomized | Y/N |
| COMPLFL | Completers | Y/N |

Subject-level flags cannot have null values. Record-level flags can use Y/null scheme.

## Traceability Requirements

### Metadata Traceability (Required)

Document the algorithm or derivation method for every analysis variable in define.xml metadata.

### Datapoint Traceability (Recommended)

Include source variables to link back to SDTM:
- --SEQ variables from source domains
- SRCDOM (source domain name)
- SRCVAR (source variable name)
- SRCSEQ (source sequence number)

### Best Practices

1. Include all SDTM variables used in derivations when practical
2. Use DTYPE to indicate derivation type for derived records
3. Document imputation methods in variable metadata

## Date/Time Imputation

When imputing dates or times, set imputation flags:

**Date Imputation (DTF):**
- Y = year imputed
- M = year present, month imputed
- D = only day imputed
- null = no imputation

**Time Imputation (TMF):**
- H = entire time imputed
- M = minutes and seconds imputed
- S = only seconds imputed
- null = no imputation

## PARAM and AVAL Guidelines

### PARAM Requirements

- Must uniquely identify the analysis parameter
- Include units when applicable: "Systolic Blood Pressure (mmHg)"
- One-to-one relationship with PARAMCD

### AVAL Rules

1. AVAL contains numeric analysis value
2. AVALC contains character analysis value
3. If both present, must have one-to-one mapping when both populated
4. BASE and CHG only apply to AVAL (not AVALC)

## Row vs Column Rules

### Add as Column (New Variable)

Use when transformation is **parameter-invariant** (same formula for all parameters):
- CHG = AVAL - BASE (change from baseline)
- PCHG = 100 * (AVAL - BASE) / BASE (percent change)
- R2BASE = AVAL / BASE (ratio to baseline)

### Add as Row (New Record)

Use when:
- Creating new parameters (log transformation, derived scores)
- Creating analysis timepoint summaries (LOCF, WOCF, averages)
- Transformation varies by parameter

Set DTYPE to indicate the derivation type.

## Common DTYPE Values

| DTYPE | Description |
|-------|-------------|
| LOCF | Last observation carried forward |
| WOCF | Worst observation carried forward |
| BOCF | Baseline observation carried forward |
| AVERAGE | Average of values |
| MINIMUM | Minimum value |
| MAXIMUM | Maximum value |

## Reference Materials

### ADaM Implementation Guide

For detailed specifications, variable tables, and examples, consult:
`references/ADaMIG_v1.3.md`

To search for specific variables or concepts:
```
# Search for variable specifications
grep -i "ABLFL\|baseline" references/ADaMIG_v1.3.md

# Search for timing variables
grep -i "timing\|AVISIT\|ADT\|ADY" references/ADaMIG_v1.3.md

# Search for population flags
grep -i "population\|SAFFL\|ITTFL" references/ADaMIG_v1.3.md
```

### Pharmaverse ADaM Datasets

For example datasets and variable structures, consult:
`references/pharmaverse_datasets.md`

This reference includes:
- Core datasets: ADSL, ADAE, ADVS, ADLB, ADEG, ADCM, ADMH, ADEX
- Oncology: ADRS, ADTR, ADTTE
- Ophthalmology: ADBCVA, ADVFQ, ADOE
- Vaccine: ADIS, ADCE, ADFACE
- Pharmacokinetics: ADPC, ADPP, ADPPK

## Quick Reference Checklist

### ADSL Checklist

- [ ] One record per subject
- [ ] STUDYID, USUBJID, SUBJID, SITEID present
- [ ] AGE, AGEU, SEX, RACE present
- [ ] ARM and TRT01P present
- [ ] At least one population flag (values Y/N, no nulls)
- [ ] TRTSDT and TRTEDT if treatment exists

### BDS Checklist

- [ ] STUDYID, USUBJID present
- [ ] PARAMCD and PARAM with one-to-one relationship
- [ ] At least one treatment variable
- [ ] AVAL and/or AVALC as appropriate
- [ ] Timing variables (ADT, ADY, AVISIT) for multiple records per parameter
- [ ] ABLFL for baseline identification
- [ ] BASE and CHG populated correctly (CHG = AVAL - BASE)
- [ ] DTYPE set for derived records

### Variable Compliance

- [ ] Names ≤ 8 characters
- [ ] Labels ≤ 40 characters
- [ ] Character variables ≤ 200 characters
- [ ] SDTM variable names have identical values to source
- [ ] Date imputation flags set when dates imputed
- [ ] One-to-one relationships maintained for variable pairs

## Related Resources

- CDISC ADaM Website: https://www.cdisc.org/standards/foundational/adam
- Admiral R Package: https://pharmaverse.github.io/admiral/
- Pharmaverse: https://pharmaverse.org/
