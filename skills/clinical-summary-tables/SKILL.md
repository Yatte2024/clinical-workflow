---
name: clinical-summary-tables
description: >
  Use when creating clinical summary tables (demographics, AE, lab, survival,
  disposition) with gtsummary in R. Provides complete runnable
  examples with CDISC ADaM variables and output sentinel markers.
---

# Clinical Tables (gtsummary + R)

Apply `r-coding-style` conventions when writing R code. Every example below follows
the same pattern: **load Parquet → build table → save HTML → emit sentinel**.

## Tool Call Pattern

Always declare packages in the `packages` parameter:

```
packages = "arrow,dplyr,gtsummary,gt"
```

Add `flextable` when producing Word output. Add `survival` for survival tables.

## Mandatory Boilerplate

```r
# 1. Load data
adsl <- arrow::read_parquet(file.path(DATA_DIR, "adsl.parquet"))

# 2. Filter population
adsl <- adsl |> filter(.data$SAFFL == "Y")

# 3. Set compact theme
theme_gtsummary_compact()

# 4. Build table (see examples below)
tbl <- adsl |> tbl_summary(...)

# 5. Save + sentinel
tbl |> as_gt() |> gt::gtsave(file.path(OUTPUT_DIR, "table.html"))
cat("[OUTPUT_TABLE:", file.path(OUTPUT_DIR, "table.html"), "]", sep = "")
```

## Workflow Decision Tree

```
What table is needed?
│
├─► Demographics/Baseline → tbl_summary(by = TRT01A)
├─► AE incidence (SOC/PT) → tbl_hierarchical()
├─► Lab summary by visit  → tbl_summary() with filtered ADLB
├─► Survival estimates     → tbl_survfit()
├─► Disposition            → tbl_summary(by = TRT01A) on ADSL disposition vars
├─► Cross-tabulation       → tbl_cross()
└─► Regression results     → tbl_regression()
```

## Example 1: Demographics Table

```r
adsl <- arrow::read_parquet(file.path(DATA_DIR, "adsl.parquet")) |>
  filter(.data$SAFFL == "Y")

theme_gtsummary_compact()

tbl <- adsl |>
  tbl_summary(
    by = .data$TRT01A,
    include = c(AGE, AGEGR1, SEX, RACE, ETHNIC, WEIGHTBL, HEIGHTBL, BMIBL),
    statistic = list(
      all_continuous() ~ "{mean} ({sd})",
      all_categorical() ~ "{n} ({p}%)"
    ),
    digits = all_continuous() ~ 1,
    missing = "ifany"
  ) |>
  add_overall() |>
  add_p() |>
  add_n() |>
  bold_labels() |>
  modify_header(label = "**Characteristic**")

tbl |> as_gt() |> gt::gtsave(file.path(OUTPUT_DIR, "demog.html"))
cat("[OUTPUT_TABLE:", file.path(OUTPUT_DIR, "demog.html"), "]", sep = "")
```

## Example 2: AE Incidence Table

```r
adsl <- arrow::read_parquet(file.path(DATA_DIR, "adsl.parquet")) |>
  filter(.data$SAFFL == "Y")
adae <- arrow::read_parquet(file.path(DATA_DIR, "adae.parquet")) |>
  inner_join(adsl |> select(USUBJID, TRT01A), by = "USUBJID") |>
  filter(.data$TRTEMFL == "Y")

theme_gtsummary_compact()

tbl <- adae |>
  tbl_hierarchical(
    variables = c(AEBODSYS, AEDECOD),
    by = TRT01A,
    denominator = adsl,
    id = USUBJID,
    include = AEDECOD
  ) |>
  add_overall() |>
  modify_header(all_stat_cols() ~ "**{level}**\nN = {n}")

tbl |> as_gt() |> gt::gtsave(file.path(OUTPUT_DIR, "ae_table.html"))
cat("[OUTPUT_TABLE:", file.path(OUTPUT_DIR, "ae_table.html"), "]", sep = "")
```

## Example 3: Lab Summary

```r
adlb <- arrow::read_parquet(file.path(DATA_DIR, "adlb.parquet"))
adsl <- arrow::read_parquet(file.path(DATA_DIR, "adsl.parquet")) |>
  filter(.data$SAFFL == "Y")

adlb <- adlb |>
  inner_join(adsl |> select(USUBJID, TRT01A), by = "USUBJID") |>
  filter(.data$PARAMCD == "ALT", .data$ANL01FL == "Y")

theme_gtsummary_compact()

tbl <- adlb |>
  tbl_summary(
    by = TRT01A,
    include = c(BASE, AVAL, CHG),
    statistic = all_continuous() ~ "{mean} ({sd})",
    digits = all_continuous() ~ 1,
    label = list(BASE ~ "Baseline", AVAL ~ "Post-baseline", CHG ~ "Change")
  ) |>
  add_n() |>
  bold_labels()

tbl |> as_gt() |> gt::gtsave(file.path(OUTPUT_DIR, "lab_table.html"))
cat("[OUTPUT_TABLE:", file.path(OUTPUT_DIR, "lab_table.html"), "]", sep = "")
```

## Example 4: Survival Table

```r
adtte <- arrow::read_parquet(file.path(DATA_DIR, "adtte.parquet"))
adsl <- arrow::read_parquet(file.path(DATA_DIR, "adsl.parquet")) |>
  filter(.data$ITTFL == "Y")

adtte <- adtte |>
  inner_join(adsl |> select(USUBJID, TRT01A), by = "USUBJID") |>
  filter(.data$PARAMCD == "OS")

theme_gtsummary_compact()

surv_fit <- survfit(
  Surv(.data$AVAL, 1 - .data$CNSR) ~ .data$TRT01A,
  data = adtte
)

tbl <- surv_fit |>
  tbl_survfit(
    times = c(180, 365, 730),
    label_header = "**{time} Days**"
  ) |>
  add_n() |>
  add_nevent()

tbl |> as_gt() |> gt::gtsave(file.path(OUTPUT_DIR, "surv_table.html"))
cat("[OUTPUT_TABLE:", file.path(OUTPUT_DIR, "surv_table.html"), "]", sep = "")
```

`packages = "arrow,dplyr,gtsummary,gt,survival"`

## Example 5: Disposition Table

```r
adsl <- arrow::read_parquet(file.path(DATA_DIR, "adsl.parquet")) |>
  filter(.data$SAFFL == "Y")

theme_gtsummary_compact()

tbl <- adsl |>
  tbl_summary(
    by = TRT01A,
    include = c(DCSREAS, EOSSTT),
    statistic = all_categorical() ~ "{n} ({p}%)",
    missing = "ifany",
    label = list(DCSREAS ~ "Reason for Discontinuation", EOSSTT ~ "End of Study Status")
  ) |>
  add_overall() |>
  add_n() |>
  bold_labels()

tbl |> as_gt() |> gt::gtsave(file.path(OUTPUT_DIR, "disp_table.html"))
cat("[OUTPUT_TABLE:", file.path(OUTPUT_DIR, "disp_table.html"), "]", sep = "")
```

## Common Modifications

```r
# Add overall column
tbl |> add_overall()

# Add p-values
tbl |> add_p()

# Bold labels, italicize levels
tbl |> bold_labels() |> italicize_levels()

# Custom header
tbl |> modify_header(label = "**Variable**")

# Spanning header over treatment columns
tbl |> modify_spanning_header(c(stat_1, stat_2) ~ "**Treatment Groups**")

# Footnote
tbl |> modify_footnote(all_stat_cols() ~ "Values are n (%) or mean (SD)")

# Multi-line continuous stats
tbl_summary(type = list(AGE ~ "continuous2"),
            statistic = all_continuous2() ~ c("{mean} ({sd})", "{median} ({p25}, {p75})"))
```

## Word/DOCX Output

When the user requests Word format, use flextable instead of gt:

```r
# packages = "arrow,dplyr,gtsummary,flextable"
tbl |> as_flex_table() |>
  flextable::save_as_docx(path = file.path(OUTPUT_DIR, "table.docx"))
cat("[OUTPUT_FILE:", file.path(OUTPUT_DIR, "table.docx"), "]", sep = "")
```

## Common Failures and Fixes

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Error: column not found` | Variable not in dataset | Check with `names(adsl)` first |
| Empty table / 0 rows | Population filter too strict | Verify `SAFFL`/`ITTFL` values exist |
| Missing by-group levels | Factor levels dropped | Use `forcats::fct_drop()` or check `TRT01A` values |
| `Error in tbl_hierarchical` | Denominator mismatch | Ensure `denominator = adsl` has same subjects |
| Sentinel not rendered | Spaces in marker | Use `cat(..., sep = "")` — never `paste()` or `print()` |
| `library() not found` | Package not declared | Add to `packages` param, not in code |

## Related Skills

- `r-coding-style` — R coding conventions (apply always)
- `adam-explorer` — ADaM dataset and variable lookup
- `clinical-graphics` — Plot type specifications
