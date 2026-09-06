---
name: dataset-profiling
description: Clinical data profiling configuration for SDTM and ADaM datasets. Use when profiling a clinical data folder, interpreting schema results, classifying domains, categorizing lab/vital sign parameters, or understanding dataset grain (primary keys). Provides the CDISC domain knowledge that data access tools need to profile intelligently.
---

# Data Profile

Provide CDISC-aware interpretation when profiling clinical datasets.
The structured configuration lives in `references/cdisc_config.yaml` —
load it when you need column mappings, parameter categories, or domain
classification rules.

## When Profiling a Data Folder

1. Read `references/cdisc_config.yaml` for the full column/category/domain config
2. Use `the schema-discovery tool` to get raw schema
3. Interpret results using the config: classify domains, categorize parameters,
   identify grain columns

## Parameter Categorization

When a user asks about lab categories (liver function, renal, hematology, etc.),
consult `references/cdisc_config.yaml` → `parameter_categories` for the mapping.

## Domain Classification

SDTM domains fall into: special_purpose, events, interventions, findings,
trial_design. ADaM structures: BDS (PARAMCD + AVAL), OCCDS (seq columns
without AVAL), ADSL (subject-level). See `references/cdisc_config.yaml` →
`domain_types` and `adam_detection`.

## Grain Detection

Each structure type has characteristic primary key patterns.
See `references/cdisc_config.yaml` → `grain_rules`.
