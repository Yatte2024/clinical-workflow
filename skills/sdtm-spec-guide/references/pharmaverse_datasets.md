# Pharmaverse SDTM Test Datasets

The `pharmaversesdtm` R package provides standardized SDTM test datasets for use with pharmaverse packages. This reference documents available datasets and their structure.

## Installation

```r
# From CRAN
install.packages("pharmaversesdtm")

# Development version
remotes::install_github("pharmaverse/pharmaversesdtm", ref = "main")
```

## Usage

```r
library(pharmaversesdtm)

# Access datasets directly
head(dm)
str(ae)

# View available datasets
data(package = "pharmaversesdtm")
```

## Core SDTM Datasets (Generic/TA-Agnostic)

### DM - Demographics

One record per subject with demographic information.

**Variables:** STUDYID, DOMAIN, USUBJID, SUBJID, RFSTDTC, RFENDTC, RFXSTDTC, RFXENDTC, RFICDTC, RFPENDTC, DTHDTC, DTHFL, SITEID, AGE, BRTHDTC, AGEU, SEX, RACE, ETHNIC, ARMCD, ARM, ACTARMCD, ACTARM, COUNTRY, DMDTC, DMDY

**Source:** CDISC pilot project

### AE - Adverse Events

One record per adverse event per subject.

**Variables:** STUDYID, DOMAIN, USUBJID, AESEQ, AETERM, AELLT, AELLTCD, AEDECOD, AEPTCD, AEHLT, AEHLTCD, AEHLGT, AEHLGTCD, AEBODSYS, AEBDSYCD, AESOC, AESOCCD, AESEV, AESER, AEACN, AEREL, AEOUT, AESCAN, AESCONG, AESDISAB, AESDTH, AESHOSP, AESLIFE, AESOD, AESTDTC, AEENDTC, AESTDY, AEENDY

**Source:** CDISC pilot project (updated)

### CM - Concomitant Medications

One record per medication per constant-dosing interval per subject.

**Variables:** STUDYID, DOMAIN, USUBJID, CMSEQ, CMSPID, CMTRT, CMMODIFY, CMDECOD, CMCAT, CMINDC, CMCLAS, CMCLASCD, CMDOSE, CMDOSU, CMDOSFRQ, CMROUTE, CMSTDTC, CMENDTC, CMSTDY, CMENDY

**Source:** CDISC pilot project

### DS - Disposition

One record per disposition status per subject.

**Variables:** STUDYID, DOMAIN, USUBJID, DSSEQ, DSTERM, DSDECOD, DSCAT, DSSCAT, EPOCH, DSSTDTC, DSSTDY

**Source:** CDISC pilot project (updated)

### EG - Electrocardiogram

One record per ECG observation per timepoint per subject.

**Variables:** STUDYID, DOMAIN, USUBJID, EGSEQ, EGTESTCD, EGTEST, EGCAT, EGORRES, EGORRESU, EGSTRESC, EGSTRESN, EGSTRESU, EGSTAT, EGLOC, EGLAT, EGBLFL, EGEVAL, EGDTC, EGDY, EGTPT, EGTPTNUM, EGELTM, EGTPTREF, VISITNUM, VISIT, VISITDY, EPOCH

**Source:** Generated dataset

### EX - Exposure

One record per treatment per constant-dosing interval per subject.

**Variables:** STUDYID, DOMAIN, USUBJID, EXSEQ, EXTRT, EXCAT, EXDOSE, EXDOSU, EXDOSFRM, EXDOSFRQ, EXROUTE, EXSTDTC, EXENDTC, EXSTDY, EXENDY

**Source:** CDISC pilot project

### LB - Laboratory Test Results

One record per lab test per visit per subject.

**Variables:** STUDYID, DOMAIN, USUBJID, LBSEQ, LBGRPID, LBREFID, LBTESTCD, LBTEST, LBCAT, LBORRES, LBORRESU, LBORNRLO, LBORNRHI, LBSTRESC, LBSTRESN, LBSTRESU, LBSTNRLO, LBSTNRHI, LBNRIND, LBSTAT, LBREASND, LBLOINC, LBSPEC, LBSPCCND, LBMETHOD, LBBLFL, LBFAST, LBDRVFL, LBDTC, LBDY, VISITNUM, VISIT, VISITDY, EPOCH

**Source:** CDISC pilot project (updated)

### MH - Medical History

One record per medical history event per subject.

**Variables:** STUDYID, DOMAIN, USUBJID, MHSEQ, MHSPID, MHTERM, MHMODIFY, MHDECOD, MHCAT, MHSCAT, MHPRESP, MHOCCUR, MHBODSYS, MHSEV, MHSTDTC, MHENDTC, MHSTDY, MHENDY, MHENRF

**Source:** CDISC pilot project (updated)

### PC - Pharmacokinetic Concentrations

One record per analyte per timepoint per subject.

**Variables:** STUDYID, DOMAIN, USUBJID, PCSEQ, PCGRPID, PCREFID, PCTESTCD, PCTEST, PCCAT, PCSCAT, PCORRES, PCORRESU, PCSTRESC, PCSTRESN, PCSTRESU, PCSTAT, PCREASND, PCSPEC, PCSPCCND, PCMETHOD, PCBLFL, PCLLOQ, PCDTC, PCDY, PCTPT, PCTPTNUM, PCELTM, PCTPTREF, PCRFTDTC, VISITNUM, VISIT

**Source:** Generated dataset (Antonio Rodriguez Contesti)

### PP - Pharmacokinetic Parameters

One record per parameter per analyte per subject.

**Variables:** STUDYID, DOMAIN, USUBJID, PPSEQ, PPGRPID, PPSPID, PPTESTCD, PPTEST, PPCAT, PPSCAT, PPORRES, PPORRESU, PPSTRESC, PPSTRESN, PPSTRESU, PPSPEC, PPRFTDTC

**Source:** Generated dataset (Antonio Rodriguez Contesti)

### SV - Subject Visits

One record per visit per subject.

**Variables:** STUDYID, DOMAIN, USUBJID, SVSEQ, VISITNUM, VISIT, VISITDY, SVSTDTC, SVENDTC, SVSTDY, SVENDY, SVUPDES, SVMENT

**Source:** CDISC pilot project (corrected)

### TS - Trial Summary

One record per trial parameter.

**Variables:** STUDYID, DOMAIN, TSSEQ, TSGRPID, TSPARMCD, TSPARM, TSVAL, TSVALNF, TSVALCD, TSVCDREF, TSVCDVER

**Source:** CDISC pilot project

### VS - Vital Signs

One record per vital sign per timepoint per subject.

**Variables:** STUDYID, DOMAIN, USUBJID, VSSEQ, VSTESTCD, VSTEST, VSCAT, VSPOS, VSORRES, VSORRESU, VSSTRESC, VSSTRESN, VSSTRESU, VSSTAT, VSREASND, VSLOC, VSLAT, VSBLFL, VSDTC, VSDY, VSTPT, VSTPTNUM, VSELTM, VSTPTREF, VISITNUM, VISIT, VISITDY, EPOCH

**Source:** Generated dataset

## Supplemental Qualifiers

### SUPPAE - Supplemental AE

Supplemental qualifiers for adverse events.

**Structure:** STUDYID, RDOMAIN, USUBJID, IDVAR, IDVARVAL, QNAM, QLABEL, QVAL, QORIG, QEVAL

### SUPPDM - Supplemental DM

Supplemental qualifiers for demographics.

### SUPPDS - Supplemental DS

Supplemental qualifiers for disposition.

## Oncology Datasets

### TU_ONCO - Tumor Identification

Identifies tumors/lesions at baseline and follow-up.

**Variables:** STUDYID, DOMAIN, USUBJID, TUSEQ, TULNKID, TUTESTCD, TUTEST, TUORRES, TUSTRESC, TUNAM, TULOC, TULAT, TUDIR, TUPORTOT, TUMETHOD, TULOBXFL, TUEVAL, TUEVALID, TUACPTFL, VISITNUM, VISIT, VISITDY, EPOCH, TUDTC, TUDY

**Source:** Generated dataset (Gopi Vegesna)

### TU_ONCO_RECIST - Tumor Identification (RECIST 1.1)

RECIST 1.1 compliant tumor identification.

**Source:** Generated dataset (Stefan Bundfuss)

### TR_ONCO - Tumor Results

Tumor measurement results.

**Variables:** STUDYID, DOMAIN, USUBJID, TRSEQ, TRGRPID, TRREFID, TRLNKID, TRLNKGRP, TRTESTCD, TRTEST, TRCAT, TRORRES, TRORRESU, TRSTRESC, TRSTRESN, TRSTRESU, TRSTAT, TRREASND, TRNAM, TRLOC, TRLAT, TRDIR, TRPORTOT, TRMETHOD, TRLOBXFL, TRDRVFL, TREVAL, TREVALID, TRACPTFL, VISITNUM, VISIT, VISITDY, EPOCH, TRDTC, TRDY

**Source:** Generated dataset (Gopi Vegesna)

### TR_ONCO_RECIST - Tumor Results (RECIST 1.1)

RECIST 1.1 compliant tumor results.

**Source:** Generated dataset (Stefan Bundfuss)

### RS_ONCO - Disease Response

Overall disease response assessments.

**Variables:** STUDYID, DOMAIN, USUBJID, RSSEQ, RSGRPID, RSREFID, RSLNKID, RSLNKGRP, RSTESTCD, RSTEST, RSCAT, RSORRES, RSSTRESC, RSSTAT, RSREASND, RSEVAL, RSEVALID, RSACPTFL, VISITNUM, VISIT, VISITDY, EPOCH, RSDTC, RSDY

**Source:** Generated dataset (Gopi Vegesna)

### RS_ONCO_RECIST - Disease Response (RECIST 1.1)

**Source:** Generated dataset (Stefan Bundfuss)

### RS_ONCO_IRECIST - Disease Response (iRECIST)

iRECIST criteria for immunotherapy trials.

**Source:** Generated dataset (Rohan Thampi)

### RS_ONCO_IMWG - Disease Response (IMWG)

IMWG criteria for multiple myeloma studies.

**Source:** Derived from tr_onco_recist (Vinh Nguyen)

### RS_ONCO_CA125 - Disease Response (GCIG)

GCIG criteria for ovarian cancer (CA-125 based).

**Source:** Generated dataset (Vinh Nguyen)

### RS_ONCO_PCWG3 - Disease Response (PCWG3)

PCWG3 criteria for prostate cancer studies.

**Source:** Generated dataset (Tomoyuki Namai)

### SUPPTR_ONCO - Supplemental Tumor Results

Supplemental qualifiers for tumor results.

## Ophthalmology Datasets

### AE_OPHTHA - Adverse Events for Ophthalmology

AE dataset with ophthalmology-specific variable `AELAT` (laterality).

**Source:** Constructed from ae

### EX_OPHTHA - Exposure for Ophthalmology

Exposure dataset with ophthalmology-specific variables: `EXLOC`, `EXLAT`.

**Source:** Constructed from ex

### OE_OPHTHA - Ophthalmic Examinations

**Variables:** STUDYID, DOMAIN, USUBJID, OESEQ, OEGRPID, OESPID, OETESTCD, OETEST, OECAT, OESCAT, OEPOS, OEBODSYS, OEORRES, OEORRESU, OESTRESC, OESTRESN, OESTRESU, OESTAT, OEREASND, OELOC, OELAT, OEDIR, OEMETHOD, OEEVAL, OEDTC, OEDY, VISITNUM, VISIT, VISITDY, EPOCH

**Source:** Generated dataset (Gordon Miller)

### QS_OPHTHA - Questionnaire for Ophthalmology

NEI VFQ-25 questionnaire data.

**Source:** Constructed from qs

### SC_OPHTHA - Subject Characteristics for Ophthalmology

**Source:** Generated dataset (Gordon Miller)

## Vaccine Datasets

### DM_VACCINE - Demographics for Vaccine

**Source:** Constructed by {admiralvaccine} developers

### VS_VACCINE - Vital Signs for Vaccine

**Source:** Constructed by {admiralvaccine} developers

### CE_VACCINE - Clinical Events for Vaccine

**Source:** Constructed by {admiralvaccine} developers

### EX_VACCINE - Exposures for Vaccine

**Source:** Constructed by {admiralvaccine} developers

### IS_VACCINE - Immunogenicity Specimen Assessments

**Source:** Constructed by {admiralvaccine} developers

### FACE_VACCINE - Findings About Clinical Events

**Source:** Constructed by {admiralvaccine} developers

### SUPPCE_VACCINE, SUPPDM_VACCINE, SUPPEX_VACCINE, SUPPFACE_VACCINE, SUPPIS_VACCINE

Supplemental qualifiers for vaccine domains.

## Pediatrics Datasets

### DM_PEDS - Demographics for Pediatrics

SDTM DM dataset with pediatric patients.

**Source:** Constructed by {admiralpeds} developers

### VS_PEDS - Vital Signs for Pediatrics

SDTM VS dataset with anthropometric measurements for pediatric patients.

**Source:** Constructed by {admiralpeds} developers

## Metabolic Datasets

### DM_METABOLIC - Demographics for Metabolic

**Source:** Constructed by {admiralmetabolic} developers

### VS_METABOLIC - Vital Signs for Metabolic

**Source:** Constructed by {admiralmetabolic} developers

### LB_METABOLIC - Laboratory Measurements for Metabolic

**Source:** Constructed by {admiralmetabolic} developers

### QS_METABOLIC - Questionnaire for Metabolic

COEQ (Control of Eating Questionnaire) data.

**Note:** COEQ is copyrighted by University of Leeds. Test data is for not-for-profit use only.

**Source:** Constructed by {admiralmetabolic} developers

## Neurology Datasets

### DM_NEURO - Demographics for Neurology

SDTM DM dataset for Alzheimer's disease studies.

**Source:** Constructed by {admiralneuro} developers

### NV_NEURO - Neurological Assessments

Neurological test results (e.g., cognitive assessments).

**Source:** Constructed by {admiralneuro} developers

### SUPPNV_NEURO - Supplemental Neurological Assessments

**Source:** Constructed by {admiralneuro} developers

### AG_NEURO - Procedure Agents

Details of agents (e.g., PET tracers) used in procedures.

**Source:** Constructed by {admiralneuro} developers

## Utility Datasets

### SMQ_DB - Standardized MedDRA Queries

Example SMQ lookup dataset.

**Source:** Generated dataset

### SDG_DB - SDG Database

Example SDG (Standardized Drug Grouping) dataset.

**Source:** Generated dataset

## Naming Conventions

- **Generic/TA-Agnostic datasets**: Same as SDTM domain name (e.g., `dm`, `ae`, `lb`)
- **TA-Specific datasets**: `domain_TA` or `domain_TA_other` (e.g., `oe_ophtha`, `rs_onco`, `rs_onco_irecist`)

## Related Packages

- **admiral**: ADaM dataset derivation
- **admiralonco**: Oncology ADaM datasets
- **admiralophtha**: Ophthalmology ADaM datasets
- **admiralvaccine**: Vaccine ADaM datasets
- **admiralpeds**: Pediatrics ADaM datasets
- **admiralmetabolic**: Metabolic ADaM datasets
- **admiralneuro**: Neurology ADaM datasets
