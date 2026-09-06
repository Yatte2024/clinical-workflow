library(dplyr)

adae <- ae |>
  left_join(adsl, by = "USUBJID") |>
  mutate(ASTDT = as.Date(AESTDTC)) |>
  mutate(
    USUBJID = USUBJID,
    TRT01P = TRT01P,
    SAFFL = SAFFL,
    TRTEMFL = if_else(ASTDT >= TRTSDT & ASTDT <= TRTEDT, "Y", "N"),
    AEBODSYS = AEBODSYS,
    AEDECOD = AEDECOD
  ) |>
  select(USUBJID, TRT01P, SAFFL, TRTEMFL, AEBODSYS, AEDECOD)
