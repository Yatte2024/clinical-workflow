# =============================================================================
# 01. 可复用的 ADaM/SDTM 派生辅助函数（提纯自一个 teal/Shiny 临床数据探索包的 utils.R）
# -----------------------------------------------------------------------------
# 这些是从那个包 8000 行的 utils.R 里挑出来的、能直接搬进你自己项目的临床数据
# 处理函数。我做了清理：去掉了对源包内部命名空间的引用、去掉函数体里
# 的 library() 坏习惯、把依赖都显式 pkg:: 限定。逻辑与原实现一致。
#
# 依赖：dplyr, tidyr, lubridate, stringr, checkmate, tibble, purrr,
#       labelled, formatters（add_ae_flags 用到 var_relabel）
#
# 注意：临床派生高度依赖列命名约定（SDTM/ADaM）。每个函数上方标了它假设的列名，
#       用到你自己的数据前先核对列名，或改成参数传入。
# =============================================================================

`%!in%` <- function(x, table) !(x %in% table)


# -----------------------------------------------------------------------------
# dtc_to_dtm(): ISO8601 日期时间字符串 -> POSIXct
# 处理两个常见坑：NA/空串；只有日期没有时间（补 T00:00）。
# 这是 SAS --DTC 字符日期转 R 时间对象的标准入口。
# -----------------------------------------------------------------------------
dtc_to_dtm <- function(dtc) {
  checkmate::assert_character(dtc)
  dtc <- ifelse(is.na(dtc) | dtc == "", NA, dtc)
  # 纯日期（yyyy-mm-dd）补一个零点时间，避免解析成 NA
  dtc <- ifelse(grepl("^\\d{4}-\\d{2}-\\d{2}$", dtc, perl = TRUE), paste0(dtc, "T00:00"), dtc)
  lubridate::ymd_hm(dtc, tz = "UTC", quiet = TRUE)
}


# -----------------------------------------------------------------------------
# add_date_vars(): 为所有 *DTC 列自动派生 *DTM / *DT / *TM 三个伴随变量
# 妙处：用 across() + .names 模板一次性批量派生，不用为每个域手写。
# -----------------------------------------------------------------------------
add_date_vars <- function(df) {
  dtc_vars <- grep("DTC$", names(df), value = TRUE)
  dtm_vars <- grep("DTM$", names(df), value = TRUE)

  if (length(dtm_vars) == 0) {
    df <- df |>
      dplyr::mutate(dplyr::across(dplyr::all_of(dtc_vars), as.character)) |>
      dplyr::mutate(dplyr::across(
        dplyr::all_of(dtc_vars),
        list(
          DTM = ~ dtc_to_dtm(.),
          DT  = ~ as.Date(.),
          TM  = ~ format(dtc_to_dtm(.), "%H:%M")
        ),
        .names = "{stringr::str_remove(.col, 'DTC')}{.fn}"
      ))
  }
  df
}


# -----------------------------------------------------------------------------
# studyDay(): 计算 study day，正确处理"没有第 0 天"这个 CDISC 规则
# ADY = 评估日 - 参考日 (+1 当评估日 >= 参考日)。参考日当天 = Day 1，前一天 = Day -1。
# 输入 date/refdate 需为 Date（数值差）。
# -----------------------------------------------------------------------------
studyDay <- function(date, refdate) {
  (date - refdate + (date >= refdate)) |> as.integer()
}


# -----------------------------------------------------------------------------
# calc_ex_dur(): 按分组算暴露时长（首剂到末剂）
# tdur = 末剂日 - 首剂日 + 1；末剂缺失时回退到首剂。用 {{ }} 支持不加引号传列名。
# 默认列：STUDYID, USUBJID, EXSTDY, EXENDY（也可传日期列 EXSTDT/EXENDT）。
# -----------------------------------------------------------------------------
calc_ex_dur <- function(df, group = c(STUDYID, USUBJID), start_day = EXSTDY, end_day = EXENDY) {
  df |>
    dplyr::group_by(dplyr::across({{ group }})) |>
    dplyr::summarize(
      fdose = min({{ start_day }}, na.rm = TRUE),
      ldose = max({{ end_day }}, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      ldose = ifelse(is.infinite(ldose), NA, ldose),
      fdose = ifelse(is.infinite(fdose), NA, fdose),
      tdur  = as.numeric(dplyr::coalesce(ldose, fdose)) - as.numeric(fdose) + 1
    )
}


# -----------------------------------------------------------------------------
# add_supp(): 把 SUPPQUAL（SDTM 补充域）反规范化合并回主域
# QNAM/QVAL 长表 -> 宽表，并保留 QLABEL 作为变量 label，再按 IDVAR/IDVARVAL 关联。
# 这是 SDTM 处理里最烦人的一步，值得直接复用。
# 假设列：STUDYID, USUBJID, QNAM, QVAL, QLABEL, IDVAR, IDVARVAL。
# -----------------------------------------------------------------------------
add_supp <- function(df, suppdf = NULL, id_cols = c("STUDYID", "USUBJID"),
                     name_col = "QNAM", value_col = "QVAL", label_col = "QLABEL") {
  if (is.null(suppdf)) return(df)

  label_mapping <- suppdf |>
    dplyr::select({{ name_col }}, {{ label_col }}) |>
    dplyr::distinct()

  suppdf <- suppdf |>
    tidyr::pivot_wider(
      id_cols = c(id_cols, "IDVAR", "IDVARVAL"),
      names_from = {{ name_col }}, values_from = {{ value_col }}
    )

  supp_wide <- suppdf |>
    dplyr::select(-c(dplyr::all_of(id_cols), "IDVAR", "IDVARVAL")) |>
    labelled::set_variable_labels(.labels = as.vector(label_mapping[[label_col]])) |>
    cbind(suppdf[c(id_cols, "IDVAR", "IDVARVAL")]) |>
    dplyr::mutate(id = dplyr::row_number(), IDVARVAL = as.numeric(as.character(IDVARVAL)))

  if (all(supp_wide[["IDVAR"]] %!in% c("", NA)) && all(supp_wide[["IDVARVAL"]] %!in% c("", NA))) {
    supp_wide <- supp_wide |>
      tidyr::pivot_wider(
        id_cols = setdiff(names(supp_wide), c("IDVAR", "IDVARVAL")),
        names_from = "IDVAR", values_from = "IDVARVAL"
      ) |>
      dplyr::select(-c("id"))
  } else {
    warning("IDVAR/IDVARVAL 未对所有记录填充，假设每个患者只有一个 IDVAR。")
  }

  dplyr::left_join(df, supp_wide)  # 生产代码建议显式写 by=，避免 by 猜测
}


# -----------------------------------------------------------------------------
# add_ae_flags(): 派生 TEAE / 治療前 / 随访期 / SAE / 致死 / 停药 等 AE 标记
# source="adam" 时直接读现成 flag；否则按 SDTM 日期窗口（治療开始 ~ 末剂+N天）判定。
# 假设列：AESTDTC, RFSTDTC, RFXENDTC, DCTFL, AESER, AESDTH, AEACN, AEREL 等。
# -----------------------------------------------------------------------------
add_ae_flags <- function(dat, trtst_var = "RFSTDTC", trtend_var = "RFXENDTC",
                         source = "sdtm", days_post_trt = 30) {
  checkmate::assert_data_frame(dat, min.rows = 1)
  checkmate::assert_number(days_post_trt, lower = 1)

  if (toupper(source) == "ADAM") {
    data <- dat |>
      dplyr::mutate(
        TMPFL_TEAE = TRTEMFL == "Y",
        PREFL = PREFL == "Y",
        FUPFL = FUPFL == "Y"
      )
  } else {
    data <- dat |>
      dplyr::mutate(
        TMPFL_TEAE = (as.Date(as.character(AESTDTC)) >= as.Date(as.character(!!rlang::sym(trtst_var))) &
          (as.Date(as.character(AESTDTC)) <= as.Date(as.character(!!rlang::sym(trtend_var))) + days_post_trt) &
          DCTFL == "Y") |
          (as.Date(as.character(AESTDTC)) >= as.Date(as.character(!!rlang::sym(trtst_var))) & DCTFL == "N"),
        PREFL = as.Date(as.character(AESTDTC)) < as.Date(as.character(!!rlang::sym(trtst_var))),
        FUPFL = (as.Date(as.character(AESTDTC)) > as.Date(as.character(RFXENDTC)) + days_post_trt) & DCTFL == "Y"
      )
  }

  data <- data |>
    dplyr::mutate(
      TRTEMFL = TMPFL_TEAE,
      TMPFL_SER = AESER == "Y",
      TMPFL_DTH = AESDTH == "Y",
      TMPFL_DISC = AEACN == "DRUG WITHDRAWN"
    ) |>
    dplyr::mutate(
      PREFL = ifelse(is.na(PREFL), FALSE, PREFL),
      TRTEMFL = ifelse(is.na(TRTEMFL), FALSE, TRTEMFL),
      FUPFL = ifelse(is.na(FUPFL), FALSE, FUPFL)
    ) |>
    formatters::var_relabel(
      TMPFL_TEAE = "Treatment Emergent AEs",
      PREFL = "Pre-treatment flag",
      TRTEMFL = "Treatment Emergent flag",
      FUPFL = "Follow-up flag",
      TMPFL_SER = "Any Serious AEs",
      TMPFL_DTH = "Death due to AEs",
      TMPFL_DISC = "Permanent Treatment Discontinuation"
    )

  if ("MULTIPLE" %!in% unique(data$AEREL)) {
    data <- data |>
      dplyr::mutate(TMPFL_REL = AEREL %in% c("RELATED", "SUSPECTED")) |>
      formatters::var_relabel(TMPFL_REL = "Any Drug Related AEs")
  }
  data
}


# -----------------------------------------------------------------------------
# lbl(): 给变量打 label 的小工具（下面几个派生函数会用到；与 02 文件里的同名）
# -----------------------------------------------------------------------------
lbl <- function(var, label) structure(var, label = label)


# -----------------------------------------------------------------------------
# add_baseline_flag(): 派生基线标记 xxBLFL（LOCF 风格，取参考日前最后一次评估）
# 逻辑：过滤评估日 <= 参考日的记录 -> 每个 test 取最晚日期 -> 打 "Y"，再 join 回主表。
# 假设列名前缀由 df_name 决定（如 FA -> FASEQ/FADTC/FASTRESN/FATEST/FACAT/FABLFL），
# 参考日由 reference 指定（默认 RFXSTDTC），另需 USUBJID / VISIT 列。
#
# ★ 已修复源包的 bug：原实现把缺列校验包在 tryCatch 里、报错后仍继续跑，等于校验
#   形同虚设。这里改成真正的 stop()。
# -----------------------------------------------------------------------------
add_baseline_flag <- function(data, df_name = "FA", reference = "RFXSTDTC", ...) {
  checkmate::assert_data_frame(data, min.rows = 1)
  checkmate::assert_string(df_name)
  checkmate::assert_string(reference)

  make_name <- function(x) paste0(df_name, x)
  seq_var  <- make_name("SEQ")
  dtc_var  <- make_name("DTC")
  resn_var <- make_name("STRESN")
  test_var <- make_name("TEST")
  cat_var  <- make_name("CAT")
  ref_var  <- reference
  blfl_var <- make_name("BLFL")

  # 真正的缺列校验（缺列直接中止，不再吞掉）
  required_cols <- c(seq_var, dtc_var, resn_var, test_var, cat_var, ref_var)
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("add_baseline_flag() 缺少必需列：", paste(missing_cols, collapse = ", "))
  }

  # 若已有该 BLFL 列，先删掉重算
  if (blfl_var %in% names(data)) data <- dplyr::select(data, -dplyr::all_of(blfl_var))

  # 日期比较用字符串比较：若评估无时间但治療有时间，评估算作 pre-dose（见源码注释推演）
  bl_data <- data |>
    dplyr::filter(!is.na(.data[[dtc_var]]), !is.na(.data[[ref_var]]), !is.na(.data[[resn_var]])) |>
    dplyr::filter(as.character(.data[[dtc_var]]) <= as.character(.data[[ref_var]])) |>
    dplyr::arrange(USUBJID, .data[[cat_var]], .data[[test_var]], .data[[dtc_var]], .data[[seq_var]]) |>
    dplyr::group_by(USUBJID, .data[[cat_var]], .data[[test_var]]) |>
    # 取该 test 最晚的评估日期；同日多条时，筛选期取最后一条、其余取第一条
    dplyr::filter(as.Date(.data[[dtc_var]]) == max(as.Date(.data[[dtc_var]]), na.rm = TRUE)) |>
    dplyr::filter(ifelse(toupper(VISIT) == "SCREENING", dplyr::row_number() == dplyr::n(), dplyr::row_number() == 1)) |>
    dplyr::ungroup() |>
    dplyr::select(USUBJID, .data[[test_var]], .data[[seq_var]]) |>
    dplyr::mutate(!!blfl_var := "Y")

  dplyr::left_join(data, bl_data, by = c("USUBJID", test_var, seq_var))
}


# -----------------------------------------------------------------------------
# add_change_from_baseline_adam(): ADaM 派生 BASE / CHG / PCHG + 基线后标记 PBLFL
# 对每个 (USUBJID, test) 取基线记录（xxBLFL == "Y"），把基线值/访视/天数改名成
# BASE/BASEVISIT/... 再 join 回主表；随后派生基线后标记。
#
# ⚠ 注意：源实现的"打 label"那一段把 AVAL/CHG/PCHG/PARAM/AVISIT 等列名写死了，
#   与它自己的参数化前缀不完全一致。这里保留原逻辑但用 any_of 容错——如果你的列名
#   不同，改 rename_mapping / 那段 mutate 即可。
# -----------------------------------------------------------------------------
add_change_from_baseline_adam <- function(data,
                                          usubjid_var = "USUBJID",
                                          param_var = "PARAM",
                                          test_var = "EFTEST",
                                          baseline_flag_var = "EFBLFL",
                                          analysis_value_var = "AVAL",
                                          visit_var = "VISIT",
                                          visitnum_var = "VISITNUM",
                                          day_var = "ADY",
                                          sequence_var = "EFSEQ",
                                          change_var = "CHG",
                                          pct_change_var = "PCHG",
                                          rename_mapping = c(
                                            BASE = "AVAL",
                                            BASEVISIT = "VISIT",
                                            BASEVISITNUM = "VISITNUM",
                                            BASEDAY = "ADY",
                                            BASESEQ = "EFSEQ"
                                          )) {
  required_vars <- c(usubjid_var, test_var, baseline_flag_var)
  missing_vars <- setdiff(required_vars, names(data))
  if (length(missing_vars) > 0) {
    stop("缺少必需列：", paste(missing_vars, collapse = ", "))
  }

  grouped_data <- data |>
    dplyr::group_by(dplyr::across(dplyr::any_of(c(usubjid_var, test_var))))

  baselines <- grouped_data |>
    dplyr::filter(
      .data[[baseline_flag_var]] %in% "Y",
      if (analysis_value_var %in% names(grouped_data)) !is.na(.data[[analysis_value_var]]) else TRUE
    ) |>
    dplyr::select(dplyr::any_of(c(usubjid_var, param_var, visitnum_var, visit_var,
                                  analysis_value_var, day_var, sequence_var))) |>
    dplyr::filter(dplyr::row_number() == dplyr::n()) |>  # 多条基线候选取最后一条
    dplyr::rename(!!!rename_mapping)

  result <- data |>
    dplyr::left_join(baselines, by = intersect(names(data), names(baselines))) |>
    dplyr::ungroup() |>
    # 给标准 ADaM 列打 label（列不存在时用 any_of 容错跳过）
    dplyr::mutate(dplyr::across(dplyr::any_of("BASE"),  ~ lbl(.x, "Baseline Value"))) |>
    dplyr::mutate(dplyr::across(dplyr::any_of("AVAL"),  ~ lbl(.x, "Analysis Value"))) |>
    dplyr::mutate(dplyr::across(dplyr::any_of("CHG"),   ~ lbl(.x, "Change from Baseline"))) |>
    dplyr::mutate(dplyr::across(dplyr::any_of("PCHG"),  ~ lbl(.x, "Percent Change from Baseline"))) |>
    dplyr::mutate(dplyr::across(dplyr::any_of("PARAM"), ~ lbl(.x, "Efficacy Assessment"))) |>
    dplyr::mutate(dplyr::across(dplyr::any_of("AVISIT"), ~ lbl(.x, "Visit Name")))

  # 基线后标记 PBLFL：访视/天数/序号在基线之后，且本身不是基线
  if (all(c("BASEVISITNUM", day_var, "BASEDAY", sequence_var, "BASESEQ") %in% names(result))) {
    result <- result |>
      dplyr::mutate(
        PBLFL = dplyr::if_else(
          !is.na(.data[["BASEVISITNUM"]]) &
            (.data[[day_var]] > .data[["BASEDAY"]] |
              (.data[[day_var]] == .data[["BASEDAY"]] & .data[[sequence_var]] > .data[["BASESEQ"]])) &
            !(.data[[baseline_flag_var]] %in% "Y"),
          "Y", NA_character_
        ) |> lbl("Post Baseline Flag")
      ) |>
      dplyr::group_by(.data[[usubjid_var]], .data[[param_var]]) |>
      dplyr::mutate(
        NO_PBLFL_FLAG = dplyr::if_else(any(.data[["PBLFL"]] %in% "Y", na.rm = TRUE),
                                       NA_character_, "Y") |> lbl("No Post Baseline Flag")
      ) |>
      dplyr::ungroup()
  }
  result
}


# -----------------------------------------------------------------------------
# disp_adam(): 派生分期 disposition 的编码标记/编码原因（支持一次处理多个 phase）
# 每个 phase 生成 {prefix}CODFL（状态，缺失填占位）和 {prefix}COD（原因，缺失回退到状态）。
# status_col / reason_col / prefix 三个向量长度必须一致（一一对应各 phase）。
# -----------------------------------------------------------------------------
disp_adam <- function(data, status_col, reason_col, prefix = "DSTRT") {
  checkmate::assert_data_frame(data, min.rows = 1)
  checkmate::assert_character(status_col, min.chars = 1, min.len = 1)
  checkmate::assert_character(reason_col, min.chars = 1, min.len = 1)
  checkmate::assert_character(prefix, min.chars = 1, min.len = 1)

  if (length(status_col) != length(reason_col) || length(status_col) != length(prefix)) {
    stop("status_col、reason_col、prefix 三者长度必须一致")
  }
  missing_cols <- setdiff(c(status_col, reason_col), names(data))
  if (length(missing_cols) > 0) {
    stop("缺少必需列：", paste(missing_cols, collapse = ", "))
  }

  result <- data
  for (i in seq_along(status_col)) {
    codfl_col <- paste0(prefix[i], "CODFL")
    cod_col   <- paste0(prefix[i], "COD")
    result <- result |>
      dplyr::mutate(
        !!codfl_col := dplyr::if_else(
          is.na(!!rlang::sym(status_col[i])) | as.character(!!rlang::sym(status_col[i])) == "",
          "PATIENT WITHOUT DISPOSITION EVENT REPORTED",
          as.character(!!rlang::sym(status_col[i]))
        ),
        !!cod_col := toupper(dplyr::if_else(
          is.na(!!rlang::sym(reason_col[i])) | as.character(!!rlang::sym(reason_col[i])) == "",
          !!rlang::sym(codfl_col),
          as.character(!!rlang::sym(reason_col[i]))
        ))
      )
  }
  result
}


# -----------------------------------------------------------------------------
# death_adam(): 把死亡归到"结束日 >= 死亡日"的最早那个研究阶段，生成 {prefix}COD
# 死亡日缺失、或死于所有阶段之后 -> 不归属（COD 全 NA）；阶段结束日缺失则忽略该阶段。
# phase_end_dt 与 prefix 一一对应。
# -----------------------------------------------------------------------------
death_adam <- function(data,
                       death_dt = "DTHDT",
                       death_cause = "DTHCAUS",
                       phase_end_dt = "DCTDT",
                       prefix = "DDTRT") {
  checkmate::assert_data_frame(data, min.rows = 1)
  checkmate::assert_string(death_dt)
  checkmate::assert_string(death_cause)
  checkmate::assert_character(phase_end_dt, min.len = 1)
  checkmate::assert_character(prefix, len = length(phase_end_dt))

  missing_cols <- setdiff(c(death_dt, death_cause, phase_end_dt), names(data))
  if (length(missing_cols) > 0) {
    stop("缺少必需列：", paste(missing_cols, collapse = ", "))
  }

  is_missing <- function(x) is.na(x) | (trimws(as.character(x)) == "")
  convert_to_date <- function(x) {
    if (is_missing(x)) return(NA)
    tryCatch(suppressWarnings(as.Date(x)), error = function(e) NA)
  }

  cod_cols <- paste0(prefix, "COD")
  data[cod_cols] <- NA_character_

  for (i in which(!is_missing(data[[death_dt]]))) {
    death_date <- convert_to_date(data[[death_dt]][i])
    if (is.na(death_date)) {
      warning(sprintf("第 %d 行：死亡日 '%s' 解析失败，跳过。", i, as.character(data[[death_dt]][i])), call. = FALSE)
      next
    }

    phase_dates <- lapply(seq_along(phase_end_dt), function(j) {
      val <- data[[phase_end_dt[j]]][i]
      if (is_missing(val)) return(NA)
      convert_to_date(val)
    })
    valid_idx <- which(!is.na(phase_dates))
    if (length(valid_idx) == 0) next

    eligible <- valid_idx[vapply(valid_idx, function(j) {
      !is.na(phase_dates[[j]]) && phase_dates[[j]] >= death_date
    }, logical(1))]
    if (length(eligible) == 0) next  # 死于所有阶段之后

    earliest <- eligible[which.min(vapply(eligible, function(j) as.numeric(phase_dates[[j]]), numeric(1)))]
    data[[cod_cols[earliest]]][i] <- as.character(data[[death_cause]][i])
  }
  data
}


# -----------------------------------------------------------------------------
# extract_grade(): 从 "GRADE 3" 之类的字符串里提取数字等级
# -----------------------------------------------------------------------------
extract_grade <- function(input_vector) {
  grade <- stringr::str_extract(as.character(input_vector), "(?<=GRADE )\\d")
  as.numeric(grade)
}
# =============================================================================
