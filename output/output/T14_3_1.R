library(dplyr)

t14_3_1 <- adae |>
  filter(SAFFL == "Y") |>
  filter(TRTEMFL == "Y") |>
  group_by(TRT01P, AEBODSYS, AEDECOD) |>
  summarise(n = n_distinct(USUBJID), .groups = "drop")
