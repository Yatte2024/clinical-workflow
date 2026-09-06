---
name: skill-router
description: Always invoke first for clinical questions. Routes to the right domain skill(s).
---

# Skill Router

Before answering any clinical question, select the right skill(s) from this
manifest. For simple queries (counts, single-column lookups, greetings),
skip skill selection entirely.

## Hard Rules (check first)

These patterns always map to a specific skill — no need to scan the manifest:

| Pattern in question | Load skill |
|---------------------|------------|
| SDTM domains: DM, AE, LB, VS, EX, DS, MH, CM, SV, TI, TA, TS, IE, SUPPDM | `sdtm-explorer` |
| ADaM datasets: ADSL, ADAE, ADLB, ADVS, ADTTE, ADEX | `adam-explorer` |
| CDW, Rave, CRF source data | `cdw-explorer` |
| "plot", "chart", "curve", "graph", "figure", "visuali" | `clinical-graphics` |
| "table", "listing", "demographics", "summary table" | `clinical-summary-tables` |
| Kaplan-Meier, forest plot, waterfall, survival curve | `clinical-graphics` |
| Safety signal, disproportionality, SMQ, PRR, ROR | `safety-signal-review` |
| Lab grading, CTCAE, toxicity grade, NCI grade | `toxicity-grading` |
| Hy's Law, DILI, hepatotoxicity, ALT/bilirubin ratio | `liver-safety` |
| "run PDRP", "PDRP check", protocol data review | `pdrp-orchestrator` |
| Shift table, baseline shift, lab shift | `lab-shift-tables` |
| ClinicalTrials.gov, NCT, competing trials | `clinicaltrials-gov-lookup` |
| FAERS, FDA, drug label, recall | `fda-openfda-lookup` |
| PubMed, literature search, citation | `pubmed-lookup` |
| Word document, .docx, Word doc, memo as Word, letter as Word | `docx` |
| PowerPoint, .pptx, slides, deck, presentation | `pptx` |
| CSR, SAE narrative, ICH-E3, de-identification, HIPAA | `regulatory-documents` |
| p-value, hypothesis test, chi-square, power analysis, ANOVA | `statistical-testing` |
| OS, PFS, ORR, DOR, DCR, RECIST, tumor response, best overall response | `oncology-endpoints` |
| Cox regression, hazard ratio, concordance, survival modeling, competing risks | `time-to-event-analysis` |
| vital signs review, PCS criteria, BP outlier, orthostatic | `vital-signs-monitoring` |
| profile data, domain classification, dataset grain, primary keys | `dataset-profiling` |
| ARD, cards package, analysis results data | `ard-cards-builder` |
| PDF, .pdf file | `pdf` |
| co-author, draft together, collaborative writing, document outline | `doc-coauthoring` |
| Spreadsheet, .xlsx, .csv, Excel | `xlsx` |
| Risk assessment, risk signals, enrollment drift, safety monitoring, BII, EDD | `risk-monitor` |
| "what can you do", capabilities, help | `agent-overview` |
| "save as skill", create a skill, make this reusable, save approach | `skill-creator` + `skill-authoring-standards` |

<!-- Boundary notes:
  - "KM curve for PFS" → clinical-graphics (visualization), but "model PFS" → time-to-event-analysis
  - "OS definition" → oncology-endpoints, but "Cox PH for OS" → time-to-event-analysis
-->

## Skill Manifest

If no hard rule matches, scan this table for the best match. Load at most
3 skills per question.

### Data Navigation

| Skill | Tags | When to use |
|-------|------|-------------|
| `adam-explorer` | adam, derived, flags, population, ADSL | Analysis-ready datasets, population flags |
| `sdtm-explorer` | sdtm, domains, cdisc, raw, tabulation | Raw study data structure, trial design |
| `cdw-explorer` | cdw, rave, crf, source | CDW/Rave Clinical Data Warehouse source data |
| `dataset-profiling` | profile, schema, domain, keys, grain | Data profiling, domain classification, primary keys |

### Standards & Reference

| Skill | Tags | When to use |
|-------|------|-------------|
| `adam-spec-guide` | adam, cdisc, spec, validation, admiral | ADaM spec questions, variable naming, traceability |
| `sdtm-spec-guide` | sdtm, cdisc, spec, validation, terminology | SDTM spec questions, observation classes, controlled terms |

### Safety & Signal Detection

| Skill | Tags | When to use |
|-------|------|-------------|
| `safety-signal-review` | safety, ae, signal, disproportionality | Safety signal detection, systematic safety review |
| `safety-review-workflow` | safety, review, checklist, comprehensive | Complete safety review of a study |
| `liver-safety` | hys, dili, hepatotoxicity, alt, bili, edish | Hy's Law evaluation, liver safety |
| `toxicity-grading` | ctcae, lab, toxicity, grade, severity | Lab/AE grading per CTCAE v5.0 |
| `risk-monitor` | risk, enrollment, safety, bii, edd, triage, ledger | Automated risk detection across enrollment + safety domains |

### Analysis

| Skill | Tags | When to use |
|-------|------|-------------|
| `statistical-testing` | stats, hypothesis, regression, power | Hypothesis tests, group comparisons, effect sizes |
| `time-to-event-analysis` | survival, tte, kaplan-meier, cox, hazard | Time-to-event analysis, survival modeling |
| `oncology-endpoints` | efficacy, os, pfs, orr, recist, response | Efficacy outcomes, tumor response, RECIST |
| `lab-shift-tables` | lab, shift, baseline, ctcae, grade | Shift tables, baseline-to-worst-post-baseline |
| `vital-signs-monitoring` | vitals, bp, hr, temp, weight, pcs | Vital signs review, PCS thresholds |
| `ard-cards-builder` | ard, cards, r, cdisc, statistics | Analysis Results Data objects with cards package |

### PDRP (Protocol Data Review Plan)

PDRP checks work with CDW (Rave CRF) data. Each check uses schema-first
discovery to find column names before running queries — no hardcoded SDTM
column names.

| Skill | Tags | When to use |
|-------|------|-------------|
| `pdrp-orchestrator` | pdrp, protocol, review, batch, cdw | Orchestrate PDRP checks (run all or individual) |
| `pdrp-04-vital-sign-outliers` | pdrp, vitals, abnormality, vits | RO #4: Vital sign changes (CDW `vits` form) |
| `pdrp-14-lab-ae-grade-consistency` | pdrp, lab, ae, grading, aesae | RO #14: Lab-AE consistency (CDW `aesae` + `lab`) |
| `pdrp-17-related-ae-review` | pdrp, safety, signal, relatedness, aesae | RO #17: Related AE signals (CDW `aesae`) |
| `pdrp-19-imae-causality` | pdrp, imae, immune, relatedness, aesae | RO #19: IMAE relatedness (CDW `aesae` + `exposure`) |
| `pdrp-20-prolonged-ae` | pdrp, ae, ongoing, duration, aesae | RO #20: Ongoing AEs >30 days (CDW `aesae`) |
| `pdrp-25-infusion-day-hsr` | pdrp, hypersensitivity, infusion, aesae | RO #25: Dosing-day HSR (CDW `aesae` + `exposure`) |
| `pdrp-27-death-disposition-reconcile` | pdrp, death, disposition, stat | RO #27: Death vs disposition (CDW `aesae` + `stat`) |
| `pdrp-31-prohibited-conmeds` | pdrp, conmed, prohibited | RO #31: Prohibited meds (CDW `conmed`) |

### Visualization & Output

| Skill | Tags | When to use |
|-------|------|-------------|
| `clinical-graphics` | plot, forest, km, edish, waterfall, spider | Clinical trial visualizations (all types) |
| `clinical-summary-tables` | table, gtsummary, demographics, ae, r | Clinical summary tables with gtsummary |
| `r-coding-style` | r, tidyverse, style, parquet, sentinel | R code style enforcement for the R runtime |
| `regulatory-documents` | csr, sae, narrative, ich-e3, deidentify | Regulatory documents, CSR sections, SAE narratives |

### External Databases

| Skill | Tags | When to use |
|-------|------|-------------|
| `clinicaltrials-gov-lookup` | clinicaltrials, nct, trial, competing | ClinicalTrials.gov queries, trial design lookup |
| `fda-openfda-lookup` | fda, faers, label, recall, openfda | FDA/FAERS queries, drug labels, safety benchmarking |
| `pubmed-lookup` | pubmed, literature, mesh, citation | PubMed literature search, citation management |

### Document & File

| Skill | Tags | When to use |
|-------|------|-------------|
| `pdf` | pdf, extract, merge, split, ocr | PDF manipulation (read, merge, split, create) |
| `xlsx` | xlsx, csv, spreadsheet, excel | Spreadsheet creation, editing, conversion |
| `docx` | docx, word, document, memo, letter, report | Word document creation, editing, tracked changes |
| `pptx` | pptx, slides, deck, presentation, powerpoint | PowerPoint creation, editing, content extraction |

### Meta & Admin

| Skill | Tags | When to use |
|-------|------|-------------|
| `agent-overview` | help, capabilities, what can you do | User asks what the agent can do |
| `skill-creator` | skill, create, save, template | Creating or saving new skills |
| `skill-authoring-standards` | skill, quality, standards, naming | Skill quality standards and conventions |
| `therapeutic-area-template` | ta, therapeutic area, template | Creating new therapeutic area skills |

## Selection Rules

1. Check hard rules first — if matched, load that skill immediately
2. If no hard rule matches, scan the manifest for tag overlap
3. Load at most 3 skills per question
4. For PDRP questions, always load `pdrp-orchestrator` — it orchestrates individual checks
5. For follow-up questions in the same domain, reuse the skill already loaded
6. For simple queries (counts, lookups, greetings) — skip skills entirely
7. When combining R output + domain knowledge, load domain skill + `r-coding-style`
