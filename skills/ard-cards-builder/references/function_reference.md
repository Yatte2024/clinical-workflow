# cards Package Function Reference

This document provides detailed parameter information for all core `{cards}` package functions.

## ARD Creation Functions

### ard_summary()

Compute Analysis Results Data (ARD) for continuous summary statistics.

```r
ard_summary(
  data,
  variables,
  by = dplyr::group_vars(data),
  strata = NULL,
  statistic = everything() ~ continuous_summary_fns(),
  fmt_fun = NULL,
  stat_label = everything() ~ default_stat_labels()
)
```

**Parameters:**
- `data`: A data frame
- `variables`: (tidy-select) Columns to include in summaries
- `by`: (tidy-select) Columns to tabulate by. Results include **all combinations** including unobserved factor levels
- `strata`: (tidy-select) Columns to stratify by. Results include only **observed combinations**
- `statistic`: (formula-list-selector) Named list of functions, e.g., `list(AGE = list(mean = \(x) mean(x)))`
- `fmt_fun`: (formula-list-selector) Formatting functions for each statistic
- `stat_label`: (formula-list-selector) Labels for statistics

**Default Statistics (continuous_summary_fns):**
- `N`: Count of non-missing values
- `mean`: Arithmetic mean
- `sd`: Standard deviation
- `median`: Median
- `p25`: 25th percentile (uses `quantile(type = 2)` matching SAS)
- `p75`: 75th percentile (uses `quantile(type = 2)` matching SAS)
- `min`: Minimum (returns NA for empty vectors, not Inf)
- `max`: Maximum (returns NA for empty vectors, not -Inf)

---

### ard_tabulate()

Compute Analysis Results Data (ARD) for categorical summary statistics.

```r
ard_tabulate(
  data,
  variables,
  by = dplyr::group_vars(data),
  strata = NULL,
  statistic = everything() ~ c("n", "p", "N"),
  denominator = "column",
  fmt_fun = NULL,
  stat_label = everything() ~ default_stat_labels()
)
```

**Parameters:**
- `data`: A data frame
- `variables`: (tidy-select) Columns to include in summaries
- `by`, `strata`: Same as `ard_summary()`
- `statistic`: Statistics to compute: `"n"`, `"N"`, `"p"`, `"n_cum"`, `"p_cum"`
- `denominator`: Controls percentage calculation:
  - `"column"` (default): Within-variable percentages after by/strata subsetting
  - `"row"`: Row percentages (by/strata columns as "top" of cross table)
  - `"cell"`: Cell percentages (denominator = total non-missing rows)
  - An integer: Custom fixed denominator
  - A data frame: Custom denominator data

**Statistics:**
- `n`: Count for each level
- `N`: Denominator (non-missing count)
- `p`: Proportion (n/N), bounded [0, 1]
- `n_cum`: Cumulative count
- `p_cum`: Cumulative proportion

---

### ard_missing()

Compute Analysis Results Data (ARD) for missing data statistics.

```r
ard_missing(
  data,
  variables,
  by = dplyr::group_vars(data),
  statistic = everything() ~ c("N_obs", "N_miss", "N_nonmiss", "p_miss", "p_nonmiss"),
  fmt_fun = NULL,
  stat_label = everything() ~ default_stat_labels()
)
```

**Statistics:**
- `N_obs`: Total observations
- `N_miss`: Missing count
- `N_nonmiss`: Non-missing count
- `p_miss`: Proportion missing
- `p_nonmiss`: Proportion non-missing

---

### ard_attributes()

Add variable attributes (labels, classes) to an ARD.

```r
ard_attributes(
  data,
  variables = everything(),
  label = NULL
)
```

**Parameters:**
- `label`: Named list of variable labels, e.g., `list(AGE = "Age (years)")`

**Returns:**
- `label`: Variable label (from data attribute or column name)
- `class`: Variable class
- Any other attributes from `attributes()`

---

### ard_total_n()

Compute total sample size.

```r
ard_total_n(data)
```

**Returns:**
- Single row ARD with `N` (total rows in data)

---

### ard_hierarchical()

Perform hierarchical/nested tabulations (e.g., AE terms within SOC).

```r
ard_hierarchical(
  data,
  variables,
  by = dplyr::group_vars(data),
  statistic = everything() ~ c("n", "N", "p"),
  denominator = NULL,
  fmt_fun = NULL,
  stat_label = everything() ~ default_stat_labels(),
  id = NULL
)
```

**Parameters:**
- `variables`: (tidy-select) Variables for nested hierarchy (order matters: SOC, then PT)
- `id`: (tidy-select) Unique identifier column (e.g., USUBJID) for asserting no duplicates
- `denominator`: Required for percentages. Data frame for population counts.

**Key Behavior:**
- Returns summaries for the **last** variable listed, nested within preceding variables
- Use `id` to ensure each subject counted once per term

---

### ard_hierarchical_count()

Count-only version of hierarchical tabulations.

```r
ard_hierarchical_count(
  data,
  variables,
  by = dplyr::group_vars(data),
  fmt_fun = NULL,
  stat_label = everything() ~ default_stat_labels()
)
```

**Key Difference from ard_hierarchical():**
- Returns counts for **all** variables in hierarchy, not just the last
- No percentages (denominator not needed)

---

## ARD Combination Functions

### ard_stack()

Stack multiple ARD calls sharing common data and by variables.

```r
ard_stack(
  data,
  ...,
  .by = NULL,
  .overall = FALSE,
  .missing = FALSE,
  .attributes = FALSE,
  .total_n = FALSE,
  .by_stats = TRUE
)
```

**Parameters:**
- `...`: Series of ARD function calls (without `data` or `by` arguments)
- `.by`: (tidy-select) Common by variable for all calls
- `.overall`: Re-run all calls with `by = NULL` for overall statistics
- `.missing`: Include `ard_missing()` for all variables
- `.attributes`: Include `ard_attributes()` for all variables
- `.total_n`: Include `ard_total_n()`
- `.by_stats`: Include univariate tabulation of by variable

**Note:** Rows with NA/NaN in `.by` columns are automatically removed.

---

### bind_ard()

Combine multiple ARD objects.

```r
bind_ard(
  ...,
  .distinct = TRUE,
  .update = FALSE,
  .order = FALSE,
  .quiet = FALSE
)
```

**Parameters:**
- `...`: ARDs to combine (can be individual ARDs or lists of ARDs)
- `.distinct`: Remove rows with duplicate statistic **values** (default TRUE)
- `.update`: Remove rows with duplicate statistic **names** (default FALSE)
- `.order`: Reorder rows by groups/variables
- `.quiet`: Suppress informational messages

**Duplicate Handling:**
- Checked across: grouping variables, primary variables, context, stat_name
- More recently added statistics are retained when duplicates found

---

## ARD Processing Functions

### apply_fmt_fun()

Apply formatting functions to statistics.

```r
apply_fmt_fun(x, replace = FALSE)
```

**Parameters:**
- `x`: ARD object
- `replace`: Overwrite existing `stat_fmt` column

**Returns:** ARD with added `stat_fmt` column containing formatted values.

---

### get_ard_statistics()

Extract statistics from ARD as a named list.

```r
get_ard_statistics(
  x,
  ...,
  .column = "stat",
  .attributes = NULL
)
```

**Parameters:**
- `...`: Filtering conditions (e.g., `group1_level %in% "Placebo"`)
- `.column`: Column to return (default "stat")
- `.attributes`: Column names to include as attributes

---

### shuffle_ard()
(experimental)
Prepare ARD for analysis by combining groups, back-filling missing values.

```r
shuffle_ard(x, trim = TRUE)
```

**Parameters:**
- `trim`: Remove statistics-level metadata (fmt_fun, warning, error)

**Processing:**
- Combines group/group_level into single columns
- Back-fills missing grouping values from variable levels
- Fills overall group values with "Overall <variable>"

---

### tidy_ard_column_order()

Relocate columns to standard order.

```r
tidy_ard_column_order(x, group_order = "ascending")
```

**Standard Order:**
1. Group columns (group1, group1_level, group2, ...)
2. Variable columns (variable, variable_level)
3. Context
4. Statistics (stat_name, stat_label, stat, stat_fmt, fmt_fun)
5. Conditions (warning, error)
6. Everything else

---

### tidy_ard_row_order()

Order rows by grouping variables.

```r
tidy_ard_row_order(x)
```

Orders by: group1, group1_level, group2, group2_level, etc.

---

## Selector Functions

For use with `dplyr::select()` and similar functions:

| Selector | Description |
|----------|-------------|
| `all_ard_groups()` | All group columns |
| `all_ard_groups("names")` | Only group1, group2, etc. |
| `all_ard_groups("levels")` | Only group1_level, group2_level, etc. |
| `all_ard_variables()` | variable and variable_level columns |
| `all_ard_variables("names")` | Only variable column |
| `all_ard_variables("levels")` | Only variable_level column |
| `all_ard_group_n(n)` | Specific group number(s) |
| `all_missing_columns()` | Columns that are all NA/empty |

---

## Formatting Utilities

### label_round()

Generate formatting function with specified rounding.

```r
label_round(digits = 1, scale = 1, width = NULL)
```

**Parameters:**
- `digits`: Decimal places
- `scale`: Scaling factor (e.g., 100 for percentages)
- `width`: Minimum width (adds leading spaces)

### alias_as_fmt_fun()

Convert formatting aliases to functions.

**Accepted aliases:**
- Non-negative integer: Number of decimal places (e.g., `2` → 2 decimal places)
- String format: `"xx.x"`, `"xx.x%"`
  - `x` after decimal = decimal places
  - `x` before decimal = leading spaces
  - `%` suffix = scale by 100

**Examples:**
```r
alias_as_fmt_fun(1)       # 1 decimal place
alias_as_fmt_fun("xx.x")  # 1 decimal, 4 char width
alias_as_fmt_fun("xx.x%") # Percentage with 1 decimal
```

---

## Example Data

The cards package includes example ADaM datasets:

- `ADSL`: Subject-level analysis dataset
- `ADAE`: Adverse events analysis dataset
- `ADTTE`: Time-to-event analysis dataset
- `ADLB`: Laboratory analysis dataset

These are imported from the CDISC SDTM/ADaM Pilot Project.
