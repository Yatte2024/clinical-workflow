# Common ARD Workflow Patterns

This document provides comprehensive examples and patterns for working with ARD objects in clinical trial reporting.

## Pattern 1: Demographics Table (Table 1)

Create ARD for a standard demographics table with treatment arms.

```r
library(cards)

# Build complete demographics ARD
ard_demographics <- ard_stack(
  data = ADSL,
  .by = "ARM",

  # Categorical variables
  ard_tabulate(variables = c("SEX", "RACE", "ETHNIC", "AGEGR1")),

  # Continuous variables
  ard_summary(variables = c("AGE", "BMIBL", "HEIGHTBL", "WEIGHTBL")),

  # Options
  .overall = TRUE,      # Include overall column
  .missing = TRUE,      # Show missing counts
  .attributes = TRUE,   # Include variable labels
  .total_n = TRUE       # Include total N
)

# View structure
print(ard_demographics, n = 20)
```

### Demographics with Custom Statistics

```r
ard_summary(
  data = ADSL,
  variables = "AGE",
  by = "ARM",
  statistic = ~ list(
    n = \(x) length(x),
    mean = \(x) mean(x, na.rm = TRUE),
    sd = \(x) sd(x, na.rm = TRUE),
    median = \(x) median(x, na.rm = TRUE),
    q1_q3 = \(x) list(
      q1 = quantile(x, 0.25, na.rm = TRUE),
      q3 = quantile(x, 0.75, na.rm = TRUE)
    ),
    min_max = \(x) list(
      min = min(x, na.rm = TRUE),
      max = max(x, na.rm = TRUE)
    )
  ),
  fmt_fun = ~ list(
    n = 0,
    mean = 1,
    sd = 2,
    median = 1,
    q1 = 1,
    q3 = 1,
    min = 0,
    max = 0
  )
)
```

---

## Pattern 2: Adverse Event Tables

### Basic AE Summary

```r
# Prepare data: one row per subject per AE term
ae_data <- ADAE |>
  dplyr::slice_tail(n = 1, by = c(USUBJID, TRTA, AESOC, AEDECOD))

# Hierarchical AE table
ard_ae <- ard_hierarchical(
  data = ae_data,
  variables = c(AESOC, AEDECOD),  # SOC → Preferred Term
  by = TRTA,
  id = USUBJID,
  denominator = ADSL
)
```

### AE with Multiple Severity Levels

```r
# AEs by maximum severity grade per subject
ae_max_grade <- ADAE |>
  dplyr::group_by(USUBJID, TRTA, AESOC, AEDECOD) |>
  dplyr::slice_max(AESEV, n = 1, with_ties = FALSE) |>
  dplyr::ungroup()

# Stack hierarchical and grade tabulations
ard_ae_complete <- bind_ard(
  # Subject counts by term
  ard_hierarchical(
    data = ae_max_grade,
    variables = c(AESOC, AEDECOD),
    by = TRTA,
    id = USUBJID,
    denominator = ADSL
  ),

  # Severity distribution
  ard_tabulate(
    data = ADAE,
    variables = "AESEV",
    by = "TRTA"
  )
)
```

### Any AE / Treatment-Related AE Rows

```r
# "Any AE" row: subjects with at least one AE
any_ae_data <- ADAE |>
  dplyr::distinct(USUBJID, TRTA) |>
  dplyr::mutate(AE_FLAG = "Any Adverse Event")

ard_any_ae <- ard_tabulate(
  data = any_ae_data,
  variables = "AE_FLAG",
  by = "TRTA",
  denominator = ADSL
)
```

---

## Pattern 3: Efficacy Analysis

### Response Rates with Confidence Intervals

```r
# Using cardx for exact binomial CI
library(cardx)

ard_response <- ard_categorical_ci(
  data = ADRS,
  variables = "AVALC",
  by = "ARM",
  method = "clopper-pearson"  # Exact method
)

# Or manually calculate components
ard_response_manual <- bind_ard(
  # Basic counts
  ard_tabulate(
    data = ADRS,
    variables = "AVALC",
    by = "ARM"
  ),

  # N per arm for denominator
  ard_tabulate(
    data = ADSL,
    variables = "ARM"
  )
)
```

### Time-to-Event Summary

```r
library(cardx)

# Kaplan-Meier estimates at specific timepoints
ard_tte <- ard_survival_survfit(
  data = ADTTE,
  variables = "AVAL",
  by = "ARM",
  times = c(6, 12, 18, 24)  # Months
)

# Median survival
ard_median <- ard_survival_survfit(
  data = ADTTE,
  variables = "AVAL",
  by = "ARM",
  probs = 0.5
)
```

---

## Pattern 4: Laboratory Tables

### Shift Tables (Baseline to Post-Baseline)

```r
# Create shift data
shift_data <- ADLB |>
  dplyr::filter(PARAMCD == "ALT") |>
  dplyr::select(USUBJID, ARM, BNRIND, ANRIND) |>
  dplyr::filter(!is.na(BNRIND), !is.na(ANRIND))

# Cross-tabulate baseline by post-baseline
ard_shift <- ard_tabulate(
  data = shift_data,
  variables = "ANRIND",       # Post-baseline (rows)
  by = c("ARM", "BNRIND"),    # Treatment × Baseline (columns)
  denominator = "column"
)
```

### Lab Summary Statistics

```r
ard_lab <- ard_stack(
  data = ADLB |> dplyr::filter(PARAMCD == "ALT"),
  .by = c("ARM", "AVISIT"),

  ard_summary(
    variables = "AVAL",
    statistic = ~ list(
      n = \(x) sum(!is.na(x)),
      mean = \(x) mean(x, na.rm = TRUE),
      sd = \(x) sd(x, na.rm = TRUE),
      median = \(x) median(x, na.rm = TRUE),
      min = \(x) min(x, na.rm = TRUE),
      max = \(x) max(x, na.rm = TRUE)
    )
  ),

  ard_summary(
    variables = "CHG",
    statistic = ~ list(
      n = \(x) sum(!is.na(x)),
      mean = \(x) mean(x, na.rm = TRUE),
      sd = \(x) sd(x, na.rm = TRUE)
    )
  )
)
```

---

## Pattern 5: QC and Validation

### Comparing ARD Statistics to Existing Values

```r
# Extract specific statistic for QC
ard <- ard_summary(ADSL, variables = "AGE", by = "ARM")

# Get mean for Placebo arm
stats <- get_ard_statistics(
  ard,
  group1_level %in% "Placebo",
  stat_name == "mean"
)

# Compare to expected
expected_mean <- 75.2
tolerance <- 0.01
abs(stats$mean - expected_mean) < tolerance
```

### Checking for Computation Errors

```r
# ARD captures errors without failing
ard <- ard_summary(
  data = ADSL,
  variables = "AGE",
  by = "ARM",
  statistic = ~ list(
    risky_stat = \(x) {
      if (length(x) < 10) stop("Too few observations")
      mean(x)
    }
  )
)

# Check for errors
errors <- ard |>
  dplyr::filter(!sapply(error, is.null))

if (nrow(errors) > 0) {
  warning("ARD computation errors detected")
  print_ard_conditions(ard)
}
```

---

## Pattern 6: Combining Multiple ARDs

### Merge Across Studies

```r
# Study 1 ARD
ard_study1 <- ard_summary(
  data = study1_data,
  variables = "AGE",
  by = "ARM"
) |>
  dplyr::mutate(study = "Study 1")

# Study 2 ARD
ard_study2 <- ard_summary(
  data = study2_data,
  variables = "AGE",
  by = "ARM"
) |>
  dplyr::mutate(study = "Study 2")

# Combine
ard_pooled <- bind_ard(
  ard_study1,
  ard_study2,
  .order = TRUE
)
```

### Update ARD with New Statistics

```r
# Base ARD
ard_base <- ard_tabulate(ADSL, variables = "SEX", by = "ARM")

# Add overall without by
ard_overall <- ard_tabulate(ADSL, variables = "SEX")

# Combine, keeping most recent on duplicates
ard_final <- bind_ard(
  ard_base,
  ard_overall,
  .update = TRUE
)
```

---

## Pattern 7: Custom Denominators

### Fixed Denominator

```r
# Use randomized N as denominator (not observed N)
randomized_n <- 100

ard_tabulate(
  data = ADSL,
  variables = "SEX",
  by = "ARM",
  denominator = randomized_n
)
```

### Denominator from Different Population

```r
# AE percentages based on safety population
safety_pop <- ADSL |>
  dplyr::filter(SAFFL == "Y")

ard_hierarchical(
  data = ADAE,
  variables = c(AESOC, AEDECOD),
  by = TRTA,
  id = USUBJID,
  denominator = safety_pop
)
```

### Pre-Calculated Denominator

```r
# Custom denominator data frame
denom_df <- data.frame(
  ARM = c("Placebo", "Treatment A", "Treatment B"),
  ...ard_N... = c(86, 84, 84)
)

ard_tabulate(
  data = ADSL,
  variables = "SEX",
  by = "ARM",
  denominator = denom_df
)
```

---

## Pattern 8: Formatting and Display Preparation

### Apply Formatting

```r
ard <- ard_summary(
  data = ADSL,
  variables = "AGE",
  by = "ARM",
  fmt_fun = ~ list(
    N = 0,
    mean = 1,
    sd = 2,
    median = 1,
    p25 = 1,
    p75 = 1,
    min = 0,
    max = 0
  )
)

# Apply formatting
ard_formatted <- apply_fmt_fun(ard)

# View formatted values
ard_formatted |>
  dplyr::select(group1_level, variable, stat_name, stat, stat_fmt)
```

### Prepare for Table Display

```r
# Shuffle for easier manipulation
ard_display <- ard |>
  shuffle_ard(trim = TRUE) |>
  dplyr::select(-any_of(c("context")))

# Pivot wider for table structure
ard_wide <- ard_display |>
  tidyr::pivot_wider(
    id_cols = c(variable, variable_level, stat_name, stat_label),
    names_from = group1_level,
    values_from = stat
  )
```

---

## Best Practices Summary

1. **Use `ard_stack()` for efficiency** when multiple summaries share data and by variables
2. **Always specify `id` in hierarchical** functions to ensure correct unique subject counts
3. **Set `denominator` explicitly** in AE tables to use the correct population
4. **Check for errors** in the `error` column before using ARD results
5. **Apply formatting late** - keep raw values in ARD until final display
6. **Use `.update = TRUE` in `bind_ard()`** when combining ARDs that may overlap
7. **Document custom statistics** with clear `stat_label` values
8. **Validate ARD results** by extracting and comparing key statistics
