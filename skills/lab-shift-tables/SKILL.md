---
name: lab-shift-tables
description: >
  Use when creating shift tables for laboratory data, analyzing baseline-to-worst
  post-baseline shifts, or assessing treatment-emergent laboratory changes.
  Covers both reference-range (Low/Normal/High) and CTCAE-graded shift tables.
  Builds on toxicity-grading for grading criteria and adam-explorer for ADLB variables.
---

# Lab Shift Analysis

## What Is a Shift Table?

A shift table cross-tabulates a subject's category at **baseline** against their
**worst post-baseline** category. The off-diagonal cells (especially upper-right
for worsening) are the clinically important ones.

**Reference-range shift table (3×3):**

```
                        Worst Post-Baseline
                        Low     Normal   High    Total
Baseline  Low            n        n       n       n
          Normal         n        n      [n]      n     ← worsening
          High           n        n       n       n
          Total          n        n       n       n
```

Cells of concern: **Normal→High**, **Low→High** (any upward shift for parameters
where high = bad), and **Normal→Low**, **High→Low** (for parameters where low = bad).

**CTCAE-graded shift table (5×5):**

```
                        Worst Post-Baseline Grade
                        0     1     2     3     4    Total
Baseline   0            n     n     n    [n]   [n]     n
Grade      1            n     n     n    [n]   [n]     n    ← worsening
           2            n     n     n    [n]   [n]     n
           3            n     n     n     n    [n]     n
           4            n     n     n     n     n      n
           Total        n     n     n     n     n      n
```

**Most concerning:** Grade 0→3, Grade 0→4, Grade 1→3, Grade 1→4 (any jump ≥2 grades).

## Defining Baseline

Per CDISC ADaM conventions:
- **Baseline record:** `ABLFL = 'Y'` in ADLB
- **Definition:** Last non-missing value on or before first dose date (TRTSDT)
- **Baseline category:** `ANRIND` at baseline (Low/Normal/High) or `BTOXGR` (CTCAE grade)
- If ADLB lacks pre-derived baseline category, derive from `ANRIND` where `ABLFL = 'Y'`

**ADaM variables:**
| Variable | Purpose |
|----------|---------|
| `ABLFL` | Baseline flag ('Y' = baseline record) |
| `BASE` | Numeric baseline value |
| `BNRIND` | Baseline reference range indicator (Low/Normal/High) |
| `BTOXGR` | Baseline CTCAE toxicity grade |

## Defining Worst Post-Baseline

**For CTCAE-graded parameters:**
- Worst = **maximum** `ATOXGR` across all post-baseline on-treatment records
- Filter: `ABLFL IS DISTINCT FROM 'Y'` AND `ANL01FL = 'Y'` (or `ONTRTFL = 'Y'`)

**For reference-range categories (Low/Normal/High):**
- Worst depends on **directionality**:
  - **Parameters where HIGH is worse** (ALT, AST, BILI, creatinine, glucose, potassium-high):
    worst = max(rank) where LOW=1, NORMAL=2, HIGH=3
  - **Parameters where LOW is worse** (hemoglobin, platelets, WBC, ANC, sodium-low):
    worst = min(rank) where LOW=1, NORMAL=2, HIGH=3
  - **Bidirectional parameters** (sodium, potassium, calcium):
    compute BOTH worst-high and worst-low separately

**Pre-derived flags (if available):**
- `WORS01FL = 'Y'` — worst post-baseline flag (use directly if present)
- `AENTMTFL = 'Y'` or `TRTEMFL = 'Y'` — treatment-emergent flag

## Handling Missing Data

| Situation | Approach |
|-----------|----------|
| No baseline value | Exclude subject from shift table OR show as "Missing" row |
| No post-baseline value | Exclude subject OR show as "Missing" column |
| Missing reference ranges (no ULN/LLN) | Cannot classify — flag for clinical review |
| Partially missing CTCAE grade | Use available values; do not impute |
| Multiple baseline values | Use the one with `ABLFL = 'Y'` (latest pre-dose) |

## DuckDB SQL for Shift Tables

**Reference-range shift table:**

```sql
-- Step 1: Get baseline category per subject per parameter
WITH baseline AS (
  SELECT USUBJID, PARAMCD, PARAM,
         ANRIND AS baseline_cat
  FROM adlb
  WHERE ABLFL = 'Y'
),
-- Step 2: Get worst post-baseline category (HIGH direction)
worst_post AS (
  SELECT USUBJID, PARAMCD,
         CASE
           WHEN MAX(CASE ANRIND
                      WHEN 'HIGH' THEN 3
                      WHEN 'NORMAL' THEN 2
                      WHEN 'LOW' THEN 1
                    END) = 3 THEN 'HIGH'
           WHEN MAX(CASE ANRIND
                      WHEN 'HIGH' THEN 3
                      WHEN 'NORMAL' THEN 2
                      WHEN 'LOW' THEN 1
                    END) = 2 THEN 'NORMAL'
           ELSE 'LOW'
         END AS worst_cat
  FROM adlb
  WHERE ABLFL IS DISTINCT FROM 'Y'
    AND ANL01FL = 'Y'
    AND ANRIND IS NOT NULL
  GROUP BY USUBJID, PARAMCD
),
-- Step 3: Join and cross-tabulate
shift_data AS (
  SELECT
    b.PARAMCD, b.PARAM, adsl.TRT01A,
    COALESCE(b.baseline_cat, 'MISSING') AS baseline_cat,
    COALESCE(w.worst_cat, 'MISSING') AS worst_cat
  FROM baseline b
  JOIN adsl ON b.USUBJID = adsl.USUBJID
  LEFT JOIN worst_post w ON b.USUBJID = w.USUBJID AND b.PARAMCD = w.PARAMCD
  WHERE adsl.SAFFL = 'Y'
)
SELECT TRT01A, PARAMCD, PARAM, baseline_cat, worst_cat,
       COUNT(*) AS n
FROM shift_data
GROUP BY TRT01A, PARAMCD, PARAM, baseline_cat, worst_cat
ORDER BY PARAMCD,
  CASE baseline_cat WHEN 'LOW' THEN 1 WHEN 'NORMAL' THEN 2
                    WHEN 'HIGH' THEN 3 WHEN 'MISSING' THEN 4 END,
  CASE worst_cat    WHEN 'LOW' THEN 1 WHEN 'NORMAL' THEN 2
                    WHEN 'HIGH' THEN 3 WHEN 'MISSING' THEN 4 END
```

**CTCAE-graded shift table:**

```sql
WITH baseline AS (
  SELECT USUBJID, PARAMCD,
         COALESCE(CAST(ATOXGR AS INTEGER), 0) AS baseline_grade
  FROM adlb
  WHERE ABLFL = 'Y'
),
worst_post AS (
  SELECT USUBJID, PARAMCD,
         MAX(COALESCE(CAST(ATOXGR AS INTEGER), 0)) AS worst_grade
  FROM adlb
  WHERE ABLFL IS DISTINCT FROM 'Y' AND ANL01FL = 'Y'
  GROUP BY USUBJID, PARAMCD
)
SELECT adsl.TRT01A, b.PARAMCD, b.baseline_grade, w.worst_grade,
       COUNT(*) AS n
FROM baseline b
JOIN adsl ON b.USUBJID = adsl.USUBJID
LEFT JOIN worst_post w ON b.USUBJID = w.USUBJID AND b.PARAMCD = w.PARAMCD
WHERE adsl.SAFFL = 'Y'
GROUP BY adsl.TRT01A, b.PARAMCD, b.baseline_grade, w.worst_grade
ORDER BY b.PARAMCD, b.baseline_grade, w.worst_grade
```

## Interpretation Guidance

**Signals to flag:**
- Any subject shifting from Grade 0 → Grade 3 or 4 in drug arm but not comparator
- Higher incidence of Normal → High shifts in drug arm vs. comparator
- Dose-dependent shift patterns (more worsening at higher doses)

**Context matters:**
- Shift from Grade 0 → Grade 1 is common and often clinically insignificant
- Focus on Grade ≥3 shifts, especially if absent in comparator arm
- For hepatic panel: combine shift analysis with Hy's Law screening (use `liver-safety` skill)
- For hematology: Grade 4 neutropenia (ANC <0.5) or thrombocytopenia (Plt <25) —
  even single subjects warrant investigation

**Presentation:**
- Show one shift table per parameter per treatment arm
- Highlight cells representing worsening (bold or shading)
- Include arm N denominators
- Key parameters to present: ALT, AST, BILI, ALP, Hgb, WBC, ANC, Plt, Creatinine

## Related Skills

- Use `toxicity-grading` for grade thresholds and grading SQL
- Use `adam-explorer` for ADLB variable names
- Use `liver-safety` for hepatic panel deep-dive
- Use `safety-signal-review` Phase 3 for where shift analysis fits in the review
