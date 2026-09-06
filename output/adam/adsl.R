library(dplyr)

adsl <- dm |>
  transmute(
    USUBJID = USUBJID,
    TRT01P = ARM,
    SAFFL = if_else(!is.na(TRTSDT), "Y", "N"),
    AGE = AGE,
    SEX = SEX,
    RACE = if_else(RACE == "MULTIPLE", "MULTIPLE", RACE),
    TRTSDT = min(as.Date(EXSTDTC), na.rm = TRUE),
    TRTEDT = max(as.Date(EXENDTC), na.rm = TRUE)
  )
