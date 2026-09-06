---
name: r-coding-style
description: >
  Use when writing R code for the R execution tool. Enforces tidyverse style, pure
  functions, Parquet-first data access, and output sentinel patterns.
---

# R Style Guide

## Script Contract

Every R script runs inside the R execution tool. The tool preamble provides:

- `DATA_DIR` — path to study Parquet files (read-only)
- `OUTPUT_DIR` — path for saved outputs (write here)
- `library()` calls — handled by the `packages` param, not in your code

Do NOT hardcode paths. Do NOT call `library()` — declare packages in the
tool call's `packages` parameter instead.

## Output Sentinels

The UI renders outputs via sentinel markers in stdout. Use `cat()` with
`sep=""` — never `message()`, never `print()`, never add spaces.

### HTML table
```r
tbl |> as_gt() |> gt::gtsave(file.path(OUTPUT_DIR, "table.html"))
cat("[OUTPUT_TABLE:", file.path(OUTPUT_DIR, "table.html"), "]", sep = "")
```

### PNG image
```r
ggsave(file.path(OUTPUT_DIR, "plot.png"), p, width = 10, height = 6, dpi = 150, bg = "white")
cat("[OUTPUT_IMAGE:", file.path(OUTPUT_DIR, "plot.png"), "]", sep = "")
```

### Downloadable file (DOCX, CSV, PPTX, etc.)
```r
flextable::save_as_docx(ft, path = file.path(OUTPUT_DIR, "table.docx"))
cat("[OUTPUT_FILE:", file.path(OUTPUT_DIR, "table.docx"), "]", sep = "")
```

### Plotly HTML
```r
htmlwidgets::saveWidget(widget, file.path(OUTPUT_DIR, "chart.html"), selfcontained = FALSE)
cat("[OUTPUT_PLOTLY:", file.path(OUTPUT_DIR, "chart.html"), "]", sep = "")
```

## Data Loading

Always load from Parquet via arrow:

```r
adsl <- arrow::read_parquet(file.path(DATA_DIR, "adsl.parquet"))
adae <- arrow::read_parquet(file.path(DATA_DIR, "adae.parquet"))

# Join analysis dataset to ADSL for population flags + treatment
adae <- adae |>
  inner_join(
    adsl |> select(USUBJID, TRT01A, SAFFL),
    by = "USUBJID"
  ) |>
  filter(SAFFL == "Y")
```

## ggplot2 Defaults

All plots must have white backgrounds and dark text.

```r
clinical_theme <- function() {
  theme_minimal(base_size = 12) +
    theme(
      plot.background = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA),
      text = element_text(color = "#333333"),
      plot.title = element_text(face = "bold", size = 14)
    )
}

p <- ggplot(data, aes(x = .data$TRT01A, y = .data$AGE)) +
  geom_boxplot() +
  clinical_theme() +
  labs(title = "Age by Treatment Arm")

ggsave(file.path(OUTPUT_DIR, "plot.png"), p,
       width = 10, height = 6, dpi = 150, bg = "white")
cat("[OUTPUT_IMAGE:", file.path(OUTPUT_DIR, "plot.png"), "]", sep = "")
```

## Style Rules

- **Pipes:** Use `|>` (base pipe), not `%>%`
- **Column refs:** Use `.data$COL` inside dplyr verbs, never bare symbols
- **Pure functions:** No `<<-`, no `assign()`, no global side effects
- **Immutable data:** Transform and reassign, never mutate in place
- **Small functions:** <20 lines, single responsibility
- **Naming:** snake_case for variables and functions

```r
# Good
result <- adsl |>
  filter(.data$SAFFL == "Y") |>
  mutate(age_group = case_when(
    .data$AGE < 65 ~ "<65",
    .data$AGE >= 65 ~ ">=65"
  ))

# Bad — global assignment, bare symbols
result <<- adsl %>% filter(SAFFL == "Y")
```

## Error Handling

Wrap risky operations in `tryCatch`. Print diagnostics to stdout.

```r
tryCatch({
  adsl <- arrow::read_parquet(file.path(DATA_DIR, "adsl.parquet"))
  # ... analysis ...
}, error = function(e) {
  cat("Error:", conditionMessage(e), "\n")
})
```

## Related Skills

- Use `clinical-summary-tables` for gtsummary table patterns
- Use `clinical-graphics` for plot type specifications
- Use `adam-explorer` for ADaM dataset/variable lookup
