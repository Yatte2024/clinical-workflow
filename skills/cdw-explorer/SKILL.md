---
name: cdw-explorer
description: Use when working with CDW (Clinical Data Warehouse) source data. Guides navigation of raw Rave CRF datasets.
---

# CDW / Rave Data Navigator

## What is CDW Data?

CDW contains raw clinical data as captured in Rave EDC (Electronic Data Capture).
Unlike SDTM or ADaM, CDW data is **not standardized** — dataset and variable
names follow Rave form conventions, not CDISC domains.

## Key Differences from SDTM/ADaM

- **No derived variables** — no population flags (SAFFL, ITTFL), no relative
  day calculations (ADY), no baseline flags
- **No CDISC naming** — variables may use Rave field names rather than
  standard --TERM, --STDT patterns
- **Raw CRF structure** — datasets correspond to eCRF forms, not analysis
  domains. One form may contain data spanning multiple SDTM domains
- **Possible duplicates** — data may include query responses, audit trail
  entries, or unvalidated records

## Common Rave Form Patterns

These are typical but **study-specific** — always confirm with the schema-discovery tool:

| Rave Form | Clinical Domain | Typical Variables |
|-----------|----------------|-------------------|
| `aesae` | Adverse Events (AE+SAE combined) | AETERM, AESTDAT, AEENDAT, AESEV, AESER |
| `conmed` | Concomitant Medications | CMTRT, CMSTDAT, CMENDAT |
| `subject` / `demog` | Demographics | SEX, AGE, RACE, ETHNIC, ARM |
| `stat` | Status / Disposition | DSDECOD, DSDAT |
| `exposure` | Drug Exposure | EXTRT, EXSTDAT, EXENDAT, EXDOSE |
| `lab` | Labs | LBTEST, LBORRES, LBORRESU, LBDAT |
| `vits` | Vital Signs | VSTEST, VSORRES, VSORRESU, VSDAT |
| MH | Medical History | MHTERM, MHSTDAT |
| PE | Physical Exam | PETEST, PEORRES |

## Profiling Strategy

When working with CDW data:
1. **Start with the lite profile** already in your context (dataset names + row counts)
2. **Profile specific datasets** using the schema-discovery tool — only the ones
   relevant to the user's question
3. **For safety questions** → profile AE, LB, VS first
4. **For demographics** → profile DM, DS first
5. **For efficacy** → profile the study-specific endpoint forms

## Querying CDW Data

- CDW data lives in parquet files in the data folder
- Use the data-query tool with SQL as normal
- Be prepared for non-standard column names — check the schema first
- Do NOT assume CDISC variable names exist
- CDW data may not have a USUBJID — look for SUBJECT or SUBJID

## PDRP Checks on CDW Data

All PDRP checks (`pdrp-orchestrator` + 8 individual checks) are designed to work
with CDW data. They use schema-first discovery — no hardcoded SDTM column
names. Each check:
1. Calls `the schema-discovery tool` to discover column names
2. Maps columns to `{PLACEHOLDER}` syntax in SQL templates
3. Includes deduplication CTEs for audit trail duplicates
4. Reports all subjects (no population flags available)

Use `pdrp-orchestrator` to orchestrate checks, or run individual checks directly.
