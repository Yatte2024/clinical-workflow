library(dplyr)

t14_1_1 <- adsl |>
  filter(SAFFL == "Y") |>
  filter(SAFFL == "Y") |>
  group_by(TRT01P) |>
  summarise(n = n_distinct(USUBJID), .groups = "drop")
