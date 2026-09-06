---
name: therapeutic-area-template
description: >
  Use when creating a new therapeutic area skill for a TA not yet in the
  skills library (e.g., dermatology, neurology, rheumatology, cardiovascular).
  Provides the required structure and sections for TA-specific clinical skills.
---

# Therapeutic Area Skill Template

When creating a skill for a new therapeutic area, follow this template.
Replace `[TA]` with the therapeutic area name throughout.

## YAML Frontmatter

```yaml
---
name: [ta-name]-[focus]
description: >
  Use when analyzing [therapeutic area] data, evaluating [key endpoints],
  or interpreting [TA-specific measures]. Only applicable to [scope limitation].
---
```

## Required Sections

Every TA skill must include all 7 sections below.

### Section 1: Response / Efficacy Criteria

Define the standard response criteria for this TA with exact thresholds
and citations.

Reference examples by TA:
- Oncology: RECIST 1.1 (CR, PR, SD, PD)
- Rheumatology: ACR20/50/70
- Dermatology: PASI 75/90/100
- Neurology: EDSS change thresholds
- Cardiovascular: MACE composite endpoint

### Section 2: Standard Endpoints

Map the standard primary and secondary endpoints:

```markdown
| Endpoint | Definition | ADaM Dataset |
|----------|-----------|-------------|
| [Primary] | [definition] | [dataset] |
| [Secondary] | [definition] | [dataset] |
```

### Section 3: Key ADaM Variables

Map TA-specific PARAMCD values to their meaning. Include expected datasets
(ADEFF, ADRS, ADTTE, etc.) with standard CDISC variable names.

### Section 4: TA-Specific Safety Concerns

Document safety signals characteristic of this TA:
- Immunology: infections, infusion reactions
- Oncology: cardiac toxicity, secondary malignancies
- Neurology: suicidality, hepatotoxicity
- Dermatology: photosensitivity, skin infections

### Section 5: Standard Visualizations

Which plots are standard for this TA? Include specifications:
- Plot type, axes, grouping variables
- Reference lines or thresholds
- Standard presentation format

### Section 6: DuckDB SQL Patterns

Provide 2-4 SQL examples for common TA-specific analyses. Follow the
SQL rules from the `skill-authoring-standards` skill.

### Section 7: Related Skills

Cross-reference relevant global skills (e.g., `toxicity-grading`,
`safety-signal-review`, `adam-explorer`).

## Review Checklist

Before deploying a new TA skill, verify:

- [ ] Response criteria verified against published guidelines (cite source)
- [ ] Endpoint definitions match standard regulatory expectations
- [ ] SQL examples tested against >= 1 real study dataset
- [ ] Description starts with "Use when" with clear trigger conditions
- [ ] Scope limitations stated in description
- [ ] Cross-references to existing skills are accurate
- [ ] Reviewed by TA clinical expert
- [ ] Follows all conventions from `skill-authoring-standards`

## Related Skills

- `skill-authoring-standards` — quality standards for all skills
- `adam-explorer` — ADaM dataset and variable reference
- `safety-signal-review` — safety signal methodology
- `toxicity-grading` — CTCAE grading criteria
