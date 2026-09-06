---
name: ard-cards-builder
description: This skill should be used when users need to create, manipulate, or work with Analysis Results Data (ARD) objects in R using the cards package. Use for CDISC-compliant statistical computations, clinical trial reporting, pre-calculating statistics for tables/figures, QC of existing tables, and building reusable analysis result datasets. Also covers the cardx extension package for statistical tests and regression models.
---

# Analysis Results Data (ARD) with cards

## Overview

Analysis Results Data (ARD) is a CDISC standard format for storing statistical analysis results in a structured, machine-readable way. The `{cards}` package creates these CDISC Analysis Result Data Sets, enabling automation, reproducibility, reusability, and traceability of analysis results.

### Key Use Cases

1. **Quality Control (QC)**: Compare computed statistics against existing tables
2. **Pre-calculation**: Calculate statistics before rendering tables/figures
3. **Medical Writing**: Easy access to statistics for reports without copy-paste
4. **Meta-analysis**: Consistent format for combining results across studies

## ARD Structure

An ARD object is a data frame of class `'card'` with these standard columns:

| Column | Description |
|--------|-------------|
| `group1`, `group1_level` | First grouping variable name and value |
| `group2`, `group2_level` | Second grouping variable (optional) |
| `variable` | Variable being summarized |
| `variable_level` | Level of the variable (for categorical) |
| `context` | Type of ARD (e.g., "summary", "tabulate", "missing") |
| `stat_name` | Name of the statistic (e.g., "mean", "n", "p") |
| `stat_label` | Display label for the statistic |
| `stat` | The computed statistic value (list column) |
| `fmt_fun` | Formatting function for display |
| `warning` | Any warnings during computation |
| `error` | Any errors during computation |

## Core Functions

### Creating ARD Objects

| Function | Purpose | Output Context |
|----------|---------|----------------|
| `ard_summary()` | Continuous variable statistics | "summary" |
| `ard_tabulate()` | Categorical variable counts/percentages | "tabulate" |
| `ard_missing()` | Missing data statistics | "missing" |
| `ard_attributes()` | Variable labels and classes | "attributes" |
| `ard_total_n()` | Total sample size | "total_n" |
| `ard_hierarchical()` | Nested tabulations (e.g., AE SOC/PT) | "hierarchical" |
| `ard_hierarchical_count()` | Hierarchical counts only | "hierarchical_count" |

### Combining and Stacking ARDs

| Function | Purpose |
|----------|---------|
| `ard_stack()` | Stack multiple ARD calls with shared data/by |
| `bind_ard()` | Combine ARDs (like `dplyr::bind_rows()` with duplicate handling) |

### Working with ARD Objects

| Function | Purpose |
|----------|---------|
| `apply_fmt_fun()` | Apply formatting functions to get `stat_fmt` |
| `get_ard_statistics()` | Extract statistics as a named list |
| `shuffle_ard()` | Prepare ARD for display/analysis |
| `tidy_ard_column_order()` | Reorder columns to standard order |
| `tidy_ard_row_order()` | Reorder rows by groups |

## Common Workflows

### 1. Basic Continuous Summary

```r
library(cards)

# Summary statistics for continuous variables
ard_summary(
  data = ADSL,
  variables = c("AGE", "BMIBL"),
  by = "ARM"
)

# Custom statistics
ard_summary(
  data = ADSL,
  variables = "AGE",
  by = "ARM",
  statistic = ~ list(
    mean = \(x) mean(x),
    sd = \(x) sd(x),
    range = \(x) list(min = min(x), max = max(x))
  )
)
```

### 2. Categorical Tabulation

```r
# Counts and percentages
ard_tabulate(
  data = ADSL,
  variables = c("SEX", "RACE"),
  by = "ARM"
)

# Custom denominator
ard_tabulate(
  data = ADSL,
  variables = "AGEGR1",
  by = "ARM",
  denominator = "row"  # "column", "row", "cell", or integer
)
```

### 3. Stacking Multiple ARD Calls

```r
# Stack multiple summaries with common by variable
ard_stack(
  data = ADSL,
  .by = "ARM",
  ard_tabulate(variables = c("SEX", "RACE", "AGEGR1")),
  ard_summary(variables = c("AGE", "BMIBL")),
  .overall = TRUE,      # Include overall (by = NULL)
  .missing = TRUE,      # Include missing statistics
  .attributes = TRUE,   # Include variable attributes
  .total_n = TRUE       # Include total N
)
```

### 4. Hierarchical/Nested Tabulations (Adverse Events)

```r
# AE table: terms nested within system organ class
ard_hierarchical(
  data = ADAE |>
    dplyr::slice_tail(n = 1, by = c(USUBJID, TRTA, AESOC, AEDECOD)),
  variables = c(AESOC, AEDECOD),  # Hierarchy order
  by = TRTA,
  id = USUBJID,                    # For unique subject counting
  denominator = ADSL               # Population for percentages
)

# Count-only version (no percentages)
ard_hierarchical_count(
  data = ADAE,
  variables = c(AESOC, AEDECOD),
  by = TRTA
)
```

### 5. Extracting Statistics

```r
ard <- ard_tabulate(ADSL, by = "ARM", variables = "AGEGR1")

# Get specific statistics as a named list
get_ard_statistics(
  ard,
  group1_level %in% "Placebo",
  variable_level %in% "65-80"
)
# Returns: list(n = 25, N = 86, p = 0.29)
```

### 6. Formatting for Display

```r
# Apply formatting functions
ard |>
  apply_fmt_fun()  # Adds stat_fmt column with formatted values

# Custom formatting
ard_summary(
  data = ADSL,
  variables = "AGE",
  fmt_fun = ~ list(
    mean = 1,                              # 1 decimal place
    sd = 2,                                # 2 decimal places
    median = \(x) sprintf("%.1f", x)       # Custom function
  )
)
```

## By vs Strata Arguments

Both `by` and `strata` are used for grouping, but with important differences:

- **`by`**: Results include **all combinations** including unobserved combinations and factor levels
- **`strata`**: Results include only **observed combinations**

Use `by` for treatment arms (ensuring all arms appear), and `strata` for variables where you only want observed values.

## Selectors for ARD Manipulation

```r
library(dplyr)

ard |>
  select(all_ard_groups())              # All group columns
  select(all_ard_groups("names"))       # Only group1, group2, etc.
  select(all_ard_groups("levels"))      # Only group1_level, etc.
  select(all_ard_variables())           # variable and variable_level
  select(all_ard_group_n(n = 1))        # First group only
  select(all_missing_columns())         # Columns that are all NA
```

## Default Statistics

### `ard_summary()` Default: `continuous_summary_fns()`
- N, mean, sd, median, p25, p75, min, max

### `ard_tabulate()` Default
- n (count), N (denominator), p (proportion)
- Also supports: n_cum, p_cum (cumulative)

### `ard_missing()` Default
- N_obs, N_miss, N_nonmiss, p_miss, p_nonmiss

## Extension Package: cardx

The `{cardx}` package extends `{cards}` with functions for statistical tests and models:

| Function | Purpose |
|----------|---------|
| `ard_ttest()` | T-test results |
| `ard_wilcoxtest()` | Wilcoxon rank-sum test |
| `ard_chisqtest()` | Chi-squared test |
| `ard_fishertest()` | Fisher's exact test |
| `ard_regression()` | Regression model results |
| `ard_survival_survfit()` | Kaplan-Meier estimates |
| `ard_survival_survdiff()` | Log-rank test |

## Tips and Best Practices

1. **Always check for errors**: ARD captures computation errors in the `error` column rather than failing
2. **Use `bind_ard(.update = TRUE)`**: When combining ARDs that may have duplicate statistics
3. **Leverage `ard_stack()`**: More efficient than separate calls when sharing data/by
4. **Format late**: Keep raw values in ARD, apply formatting only before display
5. **Use selectors**: `all_ard_groups()`, `all_ard_variables()` for consistent column selection

## Resources

For detailed function parameters, examples, and advanced patterns, see:
- `references/function_reference.md` - Complete function documentation
- `references/ard_patterns.md` - Common ARD workflow patterns
