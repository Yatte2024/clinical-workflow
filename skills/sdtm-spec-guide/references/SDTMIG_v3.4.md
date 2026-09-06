# SDTM Implementation Guide v3.4 Reference

## Introduction

The Study Data Tabulation Model (SDTM) is a CDISC standard for organizing clinical trial data for regulatory submission. SDTM provides a standardized format for tabulation data collected during clinical studies.

## SDTM Fundamental Principles

### 1. Core Concepts

- **Observations**: Each row in an SDTM dataset represents a single observation
- **Variables**: Columns represent attributes of observations
- **Domains**: Datasets organized by topic (e.g., Demographics, Adverse Events)

### 2. Observation Classes

SDTM organizes domains into three observation classes based on the type of data:

| Class | Description | Domains |
|-------|-------------|---------|
| **Interventions** | Study treatments and other interventions | CM, EX, EC, SU, PR, AG |
| **Events** | Events that occur during the study | AE, DS, MH, CE, DV, HO |
| **Findings** | Planned evaluations and assessments | LB, VS, EG, PE, QS, SC, DA, FA, etc. |

### 3. Special-Purpose Domains

- **DM** - Demographics (required)
- **CO** - Comments
- **SE** - Subject Elements
- **SV** - Subject Visits
- **RELREC** - Related Records

### 4. Trial Design Domains

- **TA** - Trial Arms
- **TE** - Trial Elements
- **TI** - Trial Inclusion/Exclusion Criteria
- **TS** - Trial Summary
- **TV** - Trial Visits

## Variable Categories

### Identifier Variables

Variables that uniquely identify each observation.

| Variable | Label | Core | Type |
|----------|-------|------|------|
| STUDYID | Study Identifier | Req | Char |
| DOMAIN | Domain Abbreviation | Req | Char |
| USUBJID | Unique Subject Identifier | Req | Char |
| --SEQ | Sequence Number | Req | Num |
| --GRPID | Group ID | Perm | Char |
| --REFID | Reference ID | Perm | Char |
| --SPID | Sponsor-Defined Identifier | Perm | Char |

### Timing Variables

Variables that describe when observations occurred.

| Variable | Label | Type | Format |
|----------|-------|------|--------|
| --DTC | Date/Time of Collection | Char | ISO 8601 |
| --STDTC | Start Date/Time | Char | ISO 8601 |
| --ENDTC | End Date/Time | Char | ISO 8601 |
| --DY | Study Day | Num | |
| --STDY | Study Day of Start | Num | |
| --ENDY | Study Day of End | Num | |
| --DUR | Duration | Char | ISO 8601 |
| VISITNUM | Visit Number | Num | |
| VISIT | Visit Name | Char | |
| VISITDY | Planned Study Day of Visit | Num | |
| EPOCH | Epoch | Char | |
| --TPT | Planned Time Point Name | Char | |
| --TPTNUM | Planned Time Point Number | Num | |
| --ELTM | Planned Elapsed Time from Time Point Ref | Char | ISO 8601 |
| --TPTREF | Time Point Reference | Char | |
| --RFTDTC | Date/Time of Reference Time Point | Char | ISO 8601 |

### Topic Variables

Variables that specify the focus of an observation (class-specific).

**Interventions:**
| Variable | Label | Description |
|----------|-------|-------------|
| --TRT | Treatment Name | Verbatim treatment name |
| --DECOD | Standardized Treatment Name | Dictionary-decoded name |

**Events:**
| Variable | Label | Description |
|----------|-------|-------------|
| --TERM | Reported Term | Verbatim event term |
| --DECOD | Dictionary-Derived Term | Standardized event term |
| --MODIFY | Modified Term | Modified verbatim term |
| --LLT | Lowest Level Term | MedDRA LLT |
| --PT | Preferred Term | MedDRA PT |
| --HLT | High Level Term | MedDRA HLT |
| --HLGT | High Level Group Term | MedDRA HLGT |
| --SOC | System Organ Class | MedDRA SOC |

**Findings:**
| Variable | Label | Description |
|----------|-------|-------------|
| --TESTCD | Test Short Name | Abbreviated test name (8 chars max) |
| --TEST | Test Name | Full test name |
| --CAT | Category | User-defined category |
| --SCAT | Subcategory | User-defined subcategory |
| --POS | Position | Position of subject during observation |
| --BODSYS | Body System or Organ Class | Body system |
| --ORRES | Result or Finding in Original Units | Result as collected |
| --ORRESU | Original Units | Units for --ORRES |
| --ORNRLO | Reference Range Lower Limit | Normal range low |
| --ORNRHI | Reference Range Upper Limit | Normal range high |
| --STRESC | Character Result/Finding in Std Format | Standardized character result |
| --STRESN | Numeric Result/Finding in Standard Units | Standardized numeric result |
| --STRESU | Standard Units | Units for --STRESN |
| --STNRLO | Reference Range Lower Limit-Std Units | Normal range low (standard) |
| --STNRHI | Reference Range Upper Limit-Std Units | Normal range high (standard) |
| --NRIND | Reference Range Indicator | LOW, NORMAL, HIGH, ABNORMAL |
| --RESCAT | Result Category | Categorization of result |
| --STAT | Completion Status | NOT DONE |
| --REASND | Reason Not Done | Reason test not performed |
| --XFN | External File Path | Path to external file |

### Qualifier Variables

Variables that provide additional context.

**Record Qualifiers:**
| Variable | Label | Description |
|----------|-------|-------------|
| --SEV | Severity/Intensity | Severity rating |
| --SER | Serious Event | Y/N |
| --ACN | Action Taken with Study Treatment | Dose change actions |
| --REL | Causality | Relationship to treatment |
| --OUT | Outcome | Event outcome |
| --SCAN | Involves Cancer | Y/N |
| --SCONG | Congenital Anomaly | Y/N |
| --SDISAB | Disability or Incapacity | Y/N |
| --SDTH | Death | Y/N |
| --SHOSP | Hospitalization | Y/N |
| --SLIFE | Life Threatening | Y/N |
| --SOD | Other Medically Important | Y/N |
| --SMIE | Other Serious Event | Y/N |

**Variable Qualifiers:**
| Variable | Label | Description |
|----------|-------|-------------|
| --LOC | Location | Anatomical location |
| --LAT | Laterality | LEFT, RIGHT, BILATERAL |
| --DIR | Directionality | Direction (ANTERIOR, POSTERIOR, etc.) |
| --PORTOT | Portion or Totality | ENTIRE, PARTIAL |
| --METHOD | Method | Method of measurement/observation |
| --LOBXFL | Last Observation Before Exposure Flag | Y/null |
| --BLFL | Baseline Flag | Y/null |
| --DRVFL | Derived Flag | Y/null |
| --EVAL | Evaluator | Who made the assessment |
| --EVALID | Evaluator Identifier | ID of evaluator |
| --ACPTFL | Accepted Record Flag | Y/null |

## Core Domains

### DM - Demographics (Required)

One record per subject. Contains demographic and identification data.

**Key Variables:**
| Variable | Label | Type | Core |
|----------|-------|------|------|
| STUDYID | Study Identifier | Char | Req |
| DOMAIN | Domain Abbreviation | Char | Req |
| USUBJID | Unique Subject Identifier | Char | Req |
| SUBJID | Subject Identifier for the Study | Char | Req |
| RFSTDTC | Subject Reference Start Date/Time | Char | Exp |
| RFENDTC | Subject Reference End Date/Time | Char | Exp |
| RFXSTDTC | Date/Time of First Study Treatment | Char | Exp |
| RFXENDTC | Date/Time of Last Study Treatment | Char | Exp |
| RFICDTC | Date/Time of Informed Consent | Char | Perm |
| RFPENDTC | Date/Time of End of Participation | Char | Perm |
| DTHDTC | Date/Time of Death | Char | Perm |
| DTHFL | Subject Death Flag | Char | Perm |
| SITEID | Study Site Identifier | Char | Req |
| BRTHDTC | Date/Time of Birth | Char | Perm |
| AGE | Age | Num | Exp |
| AGEU | Age Units | Char | Exp |
| SEX | Sex | Char | Req |
| RACE | Race | Char | Exp |
| ETHNIC | Ethnicity | Char | Perm |
| ARMCD | Planned Arm Code | Char | Req |
| ARM | Description of Planned Arm | Char | Req |
| ACTARMCD | Actual Arm Code | Char | Exp |
| ACTARM | Description of Actual Arm | Char | Exp |
| COUNTRY | Country | Char | Req |
| DMDTC | Date/Time of Collection | Char | Perm |
| DMDY | Study Day of Collection | Num | Perm |

### AE - Adverse Events

One record per adverse event per subject.

**Key Variables:**
| Variable | Label | Type | Core |
|----------|-------|------|------|
| AETERM | Reported Term for the Adverse Event | Char | Req |
| AELLT | Lowest Level Term | Char | Exp |
| AELLTCD | Lowest Level Term Code | Num | Exp |
| AEDECOD | Dictionary-Derived Term | Char | Req |
| AEPTCD | Preferred Term Code | Num | Exp |
| AEHLT | High Level Term | Char | Exp |
| AEHLTCD | High Level Term Code | Num | Exp |
| AEHLGT | High Level Group Term | Char | Exp |
| AEHLGTCD | High Level Group Term Code | Num | Exp |
| AEBODSYS | Body System or Organ Class | Char | Exp |
| AESOC | Primary System Organ Class | Char | Exp |
| AESOCCD | Primary System Organ Class Code | Num | Exp |
| AESEV | Severity/Intensity | Char | Exp |
| AESER | Serious Event | Char | Exp |
| AEACN | Action Taken with Study Treatment | Char | Exp |
| AEREL | Causality | Char | Exp |
| AEOUT | Outcome of Adverse Event | Char | Exp |
| AESTDTC | Start Date/Time of Adverse Event | Char | Exp |
| AEENDTC | End Date/Time of Adverse Event | Char | Exp |
| AESTDY | Study Day of Start of Adverse Event | Num | Perm |
| AEENDY | Study Day of End of Adverse Event | Num | Perm |
| AEDUR | Duration of Adverse Event | Char | Perm |

### CM - Concomitant Medications

One record per medication per constant-dosing interval per subject.

**Key Variables:**
| Variable | Label | Type | Core |
|----------|-------|------|------|
| CMTRT | Reported Name of Drug | Char | Req |
| CMMODIFY | Modified Reported Name | Char | Perm |
| CMDECOD | Standardized Medication Name | Char | Exp |
| CMCAT | Category for Medication | Char | Perm |
| CMINDC | Indication | Char | Exp |
| CMCLAS | Medication Class | Char | Perm |
| CMDOSE | Dose | Num | Exp |
| CMDOSTXT | Dose Description | Char | Perm |
| CMDOSU | Dose Units | Char | Exp |
| CMDOSFRM | Dose Form | Char | Perm |
| CMDOSFRQ | Dosing Frequency | Char | Exp |
| CMROUTE | Route of Administration | Char | Exp |
| CMSTDTC | Start Date/Time | Char | Exp |
| CMENDTC | End Date/Time | Char | Exp |
| CMSTDY | Study Day of Start | Num | Perm |
| CMENDY | Study Day of End | Num | Perm |
| CMDUR | Duration | Char | Perm |
| CMONGO | Ongoing | Char | Perm |

### EX - Exposure

One record per protocol-specified study treatment per constant-dosing interval per subject.

**Key Variables:**
| Variable | Label | Type | Core |
|----------|-------|------|------|
| EXTRT | Name of Treatment | Char | Req |
| EXCAT | Category of Treatment | Char | Perm |
| EXDOSE | Dose | Num | Exp |
| EXDOSTXT | Dose Description | Char | Perm |
| EXDOSU | Dose Units | Char | Exp |
| EXDOSFRM | Dose Form | Char | Exp |
| EXDOSFRQ | Dosing Frequency | Char | Exp |
| EXROUTE | Route of Administration | Char | Exp |
| EXLOT | Lot Number | Char | Perm |
| EXLOC | Location of Dose Administration | Char | Perm |
| EXLAT | Laterality | Char | Perm |
| EXFAST | Fasting Status | Char | Perm |
| EXADJ | Reason for Dose Adjustment | Char | Perm |
| EXSTDTC | Start Date/Time of Treatment | Char | Exp |
| EXENDTC | End Date/Time of Treatment | Char | Exp |
| EXSTDY | Study Day of Start of Treatment | Num | Perm |
| EXENDY | Study Day of End of Treatment | Num | Perm |
| EXDUR | Duration of Treatment | Char | Perm |

### DS - Disposition

One record per disposition status per subject.

**Key Variables:**
| Variable | Label | Type | Core |
|----------|-------|------|------|
| DSTERM | Reported Term for Disposition Event | Char | Req |
| DSDECOD | Standardized Disposition Term | Char | Req |
| DSCAT | Category for Disposition Event | Char | Exp |
| DSSCAT | Subcategory for Disposition Event | Char | Perm |
| EPOCH | Epoch | Char | Perm |
| DSSTDTC | Start Date/Time of Disposition Event | Char | Exp |
| DSSTDY | Study Day of Start of Event | Num | Perm |

### LB - Laboratory Test Results

One record per lab test per visit per subject.

**Key Variables:**
| Variable | Label | Type | Core |
|----------|-------|------|------|
| LBTESTCD | Lab Test Short Name | Char | Req |
| LBTEST | Lab Test Name | Char | Req |
| LBCAT | Category for Lab Test | Char | Exp |
| LBSCAT | Subcategory for Lab Test | Char | Perm |
| LBORRES | Result or Finding in Original Units | Char | Exp |
| LBORRESU | Original Units | Char | Exp |
| LBORNRLO | Reference Range Lower Limit | Char | Exp |
| LBORNRHI | Reference Range Upper Limit | Char | Exp |
| LBSTRESC | Character Result/Finding in Std Format | Char | Exp |
| LBSTRESN | Numeric Result/Finding in Std Units | Num | Exp |
| LBSTRESU | Standard Units | Char | Exp |
| LBSTNRLO | Reference Range Lower Limit-Std Units | Num | Exp |
| LBSTNRHI | Reference Range Upper Limit-Std Units | Num | Exp |
| LBNRIND | Reference Range Indicator | Char | Exp |
| LBSPEC | Specimen Type | Char | Exp |
| LBMETHOD | Method of Test | Char | Perm |
| LBBLFL | Baseline Flag | Char | Perm |
| LBFAST | Fasting Status | Char | Perm |
| LBDTC | Date/Time of Specimen Collection | Char | Exp |
| LBDY | Study Day of Specimen Collection | Num | Perm |

### VS - Vital Signs

One record per vital sign measurement per visit per subject.

**Key Variables:**
| Variable | Label | Type | Core |
|----------|-------|------|------|
| VSTESTCD | Vital Signs Test Short Name | Char | Req |
| VSTEST | Vital Signs Test Name | Char | Req |
| VSCAT | Category for Vital Signs | Char | Perm |
| VSSCAT | Subcategory for Vital Signs | Char | Perm |
| VSPOS | Vital Signs Position of Subject | Char | Perm |
| VSORRES | Result or Finding in Original Units | Char | Exp |
| VSORRESU | Original Units | Char | Exp |
| VSSTRESC | Character Result/Finding in Std Format | Char | Exp |
| VSSTRESN | Numeric Result/Finding in Std Units | Num | Exp |
| VSSTRESU | Standard Units | Char | Exp |
| VSSTAT | Completion Status | Char | Perm |
| VSREASND | Reason Not Done | Char | Perm |
| VSLOC | Location of Vital Signs Measurement | Char | Perm |
| VSLAT | Laterality | Char | Perm |
| VSBLFL | Baseline Flag | Char | Perm |
| VSDTC | Date/Time of Measurements | Char | Exp |
| VSDY | Study Day of Measurements | Num | Perm |
| VSTPT | Planned Time Point Name | Char | Perm |
| VSTPTNUM | Planned Time Point Number | Num | Perm |
| VSELTM | Planned Elapsed Time from Time Point Ref | Char | Perm |
| VSTPTREF | Time Point Reference | Char | Perm |
| VSRFTDTC | Date/Time of Reference Time Point | Char | Perm |

### EG - ECG Test Results

One record per ECG observation per visit per subject.

**Key Variables:**
| Variable | Label | Type | Core |
|----------|-------|------|------|
| EGTESTCD | ECG Test Short Name | Char | Req |
| EGTEST | ECG Test Name | Char | Req |
| EGCAT | Category for ECG | Char | Perm |
| EGSCAT | Subcategory for ECG | Char | Perm |
| EGPOS | ECG Position of Subject | Char | Perm |
| EGORRES | Result or Finding in Original Units | Char | Exp |
| EGORRESU | Original Units | Char | Exp |
| EGSTRESC | Character Result/Finding in Std Format | Char | Exp |
| EGSTRESN | Numeric Result/Finding in Std Units | Num | Exp |
| EGSTRESU | Standard Units | Char | Exp |
| EGSTAT | Completion Status | Char | Perm |
| EGREASND | Reason Not Done | Char | Perm |
| EGLEAD | Lead Identification | Char | Perm |
| EGMETHOD | Method of ECG Test | Char | Perm |
| EGBLFL | Baseline Flag | Char | Perm |
| EGDRVFL | Derived Flag | Char | Perm |
| EGEVAL | Evaluator | Char | Perm |
| EGDTC | Date/Time of ECG | Char | Exp |
| EGDY | Study Day of ECG | Num | Perm |
| EGTPT | Planned Time Point Name | Char | Perm |
| EGTPTNUM | Planned Time Point Number | Num | Perm |

### MH - Medical History

One record per medical history event per subject.

**Key Variables:**
| Variable | Label | Type | Core |
|----------|-------|------|------|
| MHTERM | Reported Term for the Medical History | Char | Req |
| MHMODIFY | Modified Reported Term | Char | Perm |
| MHDECOD | Dictionary-Derived Term | Char | Exp |
| MHCAT | Category for Medical History | Char | Perm |
| MHSCAT | Subcategory for Medical History | Char | Perm |
| MHPRESP | Pre-Specified | Char | Perm |
| MHOCCUR | Medical History Occurrence | Char | Perm |
| MHBODSYS | Body System or Organ Class | Char | Exp |
| MHSEV | Severity/Intensity | Char | Perm |
| MHSTDTC | Start Date/Time of Medical History Event | Char | Perm |
| MHENDTC | End Date/Time of Medical History Event | Char | Perm |
| MHSTDY | Study Day of Start | Num | Perm |
| MHENDY | Study Day of End | Num | Perm |
| MHENRF | End Relative to Reference Period | Char | Perm |

## Supplemental Qualifiers (SUPP--)

Used for variables not in standard domain models.

**Structure:**
| Variable | Label | Type |
|----------|-------|------|
| STUDYID | Study Identifier | Char |
| RDOMAIN | Related Domain Abbreviation | Char |
| USUBJID | Unique Subject Identifier | Char |
| IDVAR | Identifying Variable | Char |
| IDVARVAL | Identifying Variable Value | Char |
| QNAM | Qualifier Variable Name | Char |
| QLABEL | Qualifier Variable Label | Char |
| QVAL | Data Value | Char |
| QORIG | Origin | Char |
| QEVAL | Evaluator | Char |

## Date/Time Format (ISO 8601)

SDTM uses ISO 8601 format for date/time variables:

| Format | Example | Description |
|--------|---------|-------------|
| YYYY | 2022 | Year only |
| YYYY-MM | 2022-07 | Year and month |
| YYYY-MM-DD | 2022-07-21 | Complete date |
| YYYY-MM-DDTHH:MM | 2022-07-21T14:30 | Date and time (hours:minutes) |
| YYYY-MM-DDTHH:MM:SS | 2022-07-21T14:30:00 | Complete date/time |

## Study Day Calculation

Study day (--DY, --STDY, --ENDY) is calculated relative to RFSTDTC:
- **Day 1** = RFSTDTC (reference start date)
- **Positive days** = dates on or after RFSTDTC
- **Negative days** = dates before RFSTDTC
- **No Day 0**: Day before Day 1 is Day -1

Formula:
```
If DTC >= RFSTDTC: DY = (DTC - RFSTDTC) + 1
If DTC < RFSTDTC:  DY = DTC - RFSTDTC
```

## Controlled Terminology

SDTM uses CDISC Controlled Terminology for standardized values:

### Common Codelists

| Codelist | Example Values |
|----------|----------------|
| SEX | F, M, U, UNDIFFERENTIATED |
| RACE | AMERICAN INDIAN OR ALASKA NATIVE, ASIAN, BLACK OR AFRICAN AMERICAN, NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER, WHITE, NOT REPORTED, UNKNOWN |
| ETHNIC | HISPANIC OR LATINO, NOT HISPANIC OR LATINO, NOT REPORTED, UNKNOWN |
| COUNTRY | USA, GBR, DEU, JPN (ISO 3166-1 alpha-3) |
| NY | N, Y |
| LAT | LEFT, RIGHT, BILATERAL |
| LOC | Multiple anatomical locations |
| METHOD | Test/procedure methods |
| POSITION | SITTING, STANDING, SUPINE |
| UNIT | Measurement units |

### Action Taken (AEACN)

- DOSE NOT CHANGED
- DOSE RATE REDUCED
- DOSE REDUCED
- DRUG INTERRUPTED
- DRUG WITHDRAWN
- NOT APPLICABLE
- UNKNOWN

### Outcome (AEOUT)

- RECOVERED/RESOLVED
- RECOVERING/RESOLVING
- NOT RECOVERED/NOT RESOLVED
- RECOVERED/RESOLVED WITH SEQUELAE
- FATAL
- UNKNOWN

### Severity (AESEV)

- MILD
- MODERATE
- SEVERE

## Trial Design Model

### Trial Arms (TA)

Describes the planned sequence of elements for each arm.

| Variable | Label | Type |
|----------|-------|------|
| STUDYID | Study Identifier | Char |
| DOMAIN | Domain Abbreviation | Char |
| ARMCD | Planned Arm Code | Char |
| ARM | Description of Planned Arm | Char |
| TAETORD | Planned Order of Element | Num |
| ETCD | Element Code | Char |
| ELEMENT | Description of Element | Char |
| TABRANCH | Branch | Char |
| TATRANS | Transition Rule | Char |
| EPOCH | Epoch | Char |

### Trial Elements (TE)

Describes each unique element in the trial.

| Variable | Label | Type |
|----------|-------|------|
| STUDYID | Study Identifier | Char |
| DOMAIN | Domain Abbreviation | Char |
| ETCD | Element Code | Char |
| ELEMENT | Description of Element | Char |
| TESTRL | Rule for Start of Element | Char |
| TEENRL | Rule for End of Element | Char |
| TEDUR | Planned Duration of Element | Char |

### Trial Summary (TS)

Contains summary information about the trial.

| Variable | Label | Type |
|----------|-------|------|
| STUDYID | Study Identifier | Char |
| DOMAIN | Domain Abbreviation | Char |
| TSSEQ | Sequence Number | Num |
| TSGRPID | Group ID | Char |
| TSPARMCD | Trial Summary Parameter Short Name | Char |
| TSPARM | Trial Summary Parameter | Char |
| TSVAL | Parameter Value | Char |
| TSVALNF | Parameter Null Flavor | Char |
| TSVALCD | Parameter Value Code | Char |
| TSVCDREF | Name of Reference Terminology | Char |
| TSVCDVER | Version of Reference Terminology | Char |

## Oncology Domains

### TU - Tumor Identification

Identifies tumors/lesions for tracking.

| Variable | Label | Type |
|----------|-------|------|
| TULNKID | Link ID | Char |
| TUTESTCD | Tumor Identification Test Short Name | Char |
| TUTEST | Tumor Identification Test Name | Char |
| TUORRES | Result or Finding in Original Units | Char |
| TUSTRESC | Character Result | Char |
| TULOC | Location of Tumor | Char |
| TULAT | Laterality of Tumor | Char |
| TUMETHOD | Method of Identification | Char |
| TUEVAL | Evaluator | Char |
| TUEVALID | Evaluator Identifier | Char |
| TUDTC | Date/Time of Collection | Char |
| TUDY | Study Day | Num |

### TR - Tumor/Lesion Results

Contains tumor measurement results.

| Variable | Label | Type |
|----------|-------|------|
| TRLNKID | Link ID | Char |
| TRTESTCD | Tumor Results Test Short Name | Char |
| TRTEST | Tumor Results Test Name | Char |
| TRORRES | Result or Finding in Original Units | Char |
| TRORRESU | Original Units | Char |
| TRSTRESC | Character Result | Char |
| TRSTRESN | Numeric Result | Num |
| TRSTRESU | Standard Units | Char |
| TRMETHOD | Method of Test | Char |
| TREVAL | Evaluator | Char |
| TREVALID | Evaluator Identifier | Char |
| TRDTC | Date/Time of Collection | Char |
| TRDY | Study Day | Num |

### RS - Disease Response

Contains overall disease response assessments.

| Variable | Label | Type |
|----------|-------|------|
| RSTESTCD | Response Test Short Name | Char |
| RSTEST | Response Test Name | Char |
| RSCAT | Category | Char |
| RSORRES | Result or Finding in Original Units | Char |
| RSSTRESC | Character Result | Char |
| RSEVAL | Evaluator | Char |
| RSEVALID | Evaluator Identifier | Char |
| RSDTC | Date/Time of Assessment | Char |
| RSDY | Study Day | Num |

## Best Practices

### General Guidelines

1. **Use controlled terminology** whenever available
2. **Be consistent** in applying variable naming conventions
3. **Document derivations** in define.xml
4. **Include all collected data**, even if not analyzed
5. **Use SUPP domains** sparingly for truly sponsor-defined variables

### Variable Naming

1. Maximum 8 characters for variable names
2. Start with domain prefix for domain-specific variables
3. Use standard suffixes (DTC, DY, FL, etc.)
4. Use uppercase only

### Data Quality

1. No missing required variables
2. Valid ISO 8601 dates
3. Controlled terminology where specified
4. Referential integrity between domains

## Related Resources

- CDISC SDTM Website: https://www.cdisc.org/standards/foundational/sdtm
- CDISC Controlled Terminology: https://www.cdisc.org/standards/terminology
- Pharmaverse SDTM Packages: https://pharmaverse.org/
