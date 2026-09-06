---
name: skill-authoring-standards
description: >
  Use when creating a new clinical skill, refining an existing skill, or when
  a clinician clicks "Save as Skill" in the platform. Enforces structure, naming,
  description, and SQL conventions so every skill meets quality standards.
---

# Skill Quality Guide

When authoring or refining a clinical skill, follow these standards exactly.

## Structure

Every skill file must have:

```yaml
---
name: skill-name-kebab-case
description: >
  Use when [specific trigger condition]. [What the skill teaches the agent].
  [What other skills it builds on or complements].
---
```

Followed by markdown content sections.

## Required Elements

| Element | What to Include |
|---------|----------------|
| YAML frontmatter | `name` + `description` (starts with "Use when") |
| Clinical context | Why this analysis matters, who needs it |
| Reference data | Thresholds, criteria, classification tables with citations |
| SQL patterns | DuckDB queries for common analysis tasks |
| Interpretation guidance | How to read the results, what to flag |
| Cross-references | Links to related skills by name |

## Naming

- Filename: `kebab-case.md` (e.g., `liver-safety.md`, `lab-shift-tables.md`)
- YAML `name:` must match the filename stem exactly
- Place in the correct category directory: `safety/`, `ta/`, `standards/`,
  `visualization/`, or `workflow/`

## Description Rules

The `description:` field triggers skill selection. It must:

1. Start with "Use when"
2. Include key trigger words (e.g., "Hy's Law", "DILI", "hepatotoxicity")
3. Mention what data is needed (e.g., "Requires ADLB with ALT, AST, BILI")
4. Note scope limitations (e.g., "Only applicable to solid tumor studies")

**Good:** "Use when evaluating hepatotoxicity, drug-induced liver injury (DILI),
Hy's Law, or eDISH analysis. Requires ADLB with ALT, AST, and bilirubin."

**Bad:** "Liver safety skill."

## SQL Rules

- **DuckDB syntax only.** Queries run via `the data-query tool`.
- **Standard CDISC variable names.** PARAMCD, AVAL, AVISIT, TRT01A, etc.
- **Handle NULLs explicitly.** Use `COALESCE`, `NULLIF`, `IS DISTINCT FROM`.
- **Comment each query.** One-line comment explaining the purpose.
- **Graceful degradation.** If a variable might not exist, note the fallback:
  "If ATOXGR is not available, derive grades using `toxicity-grading` skill."

## Content Depth

Scale to the skill's complexity:

| Complexity | Sections | Reference Tables | SQL Examples |
|-----------|----------|-----------------|-------------|
| Simple (navigator) | 4-6 | 1-2 | 2-3 |
| Moderate (shift analysis) | 5-7 | 2-3 | 3-5 |
| Complex (signal detection) | 5-8 | 3-5 | 4-6 |

## What NOT to Do

| Don't | Do Instead |
|-------|-----------|
| Hardcode study-specific values | Use standard CDISC variables |
| Duplicate content from another skill | Cross-reference by name |
| Include >1000 words of background | Link to external reference |
| Write SQL for a specific DB engine | Use DuckDB-compatible syntax |
| Embed PHI or patient data | Use placeholder values (SUBJ-001) |
| Make the skill an encyclopedia | Focus on actionable analysis guidance |
| Wrap a single SQL query as a skill | Save as a query instead |
| Encode personal preferences | Reference clinical standards only |

## Validation Checklist

Before saving or deploying a skill, verify:

- [ ] Valid YAML frontmatter with `name:` matching filename
- [ ] `description:` starts with "Use when" and has trigger words
- [ ] At least 3 substantive content sections
- [ ] SQL examples use DuckDB syntax with CDISC variable names
- [ ] Reference data (thresholds, criteria) is cited or justified
- [ ] Cross-references to related skills are accurate
- [ ] No study-specific content (protocol numbers, site IDs, file paths)
- [ ] No PHI or patient-identifiable data

## Related Skills

- `safety-review-workflow` — structured safety review workflow
- `adam-explorer` — ADaM dataset and variable reference
- `sdtm-explorer` — SDTM domain reference
