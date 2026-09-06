# 09_more_adam_derivations.R
# ============================================================================
# 更多 ADaM / SDTM 派生函数（A4 类）
#
# 这是 01_adam_derivation_helpers.R 的延伸，聚焦三类派生：
#   1) Disposition（处置）：add_disp_events / add_death_reason /
#      add_trt_discont_flag / add_disp_study_days
#   2) Visit（访视号规整）：add_baseline_visit / overwrite_baseline_flag /
#      create_blfl_var / update_unsch_visit_number / update_eot_visit_number
#   3) 肿瘤最佳总体反应（BOR）：add_bor_category / update_bor_values
#
# 依赖（外部）：dplyr、tidyr、stringr、forcats、checkmate、cli、rlang
# 依赖（同项目）：
#   - lbl()            见 02_label_preservation.R
#   - studyDay()       见 01_adam_derivation_helpers.R
#   - %!in%            见 01_adam_derivation_helpers.R
#   - all_na()、clean_column_text()、rm_white_spaces()、extract_num_after_N()
#                      见 10_small_utils.R
#   - add_baseline_flag()  见 01_adam_derivation_helpers.R（overwrite_baseline_flag 用）
#
# ★ 未收录说明：原包还有一支 add_disp_cont_flag()，用 eval(parse(text=...)) 拼
#   过滤条件、且把若干 CRF 厂商代号和一大堆业务字符串
#   写死，属于典型反面教材（注入风险 + 不可移植），本仓库刻意不提纯。若你确实
#   需要"研究阶段延续标记"，请用参数化的 grepl 条件重写，别用 eval(parse)。
# ============================================================================


# ===========================================================================
# 1) DISPOSITION（处置事件 / 死亡原因 / 治疗中止 / 处置研究日）
# ===========================================================================

# ---------------------------------------------------------------------------
# add_disp_events(): 从 DS 域按研究阶段抽取每人最新的处置事件原因
#
# 手段：过滤 DSCAT == "DISPOSITION EVENT" → 在 DSREFID/PERIOD/DSSCAT/EPOCH 中
#       找第一个可用列做"研究阶段"筛选（EPOCH 用精确匹配，其余可精确或模糊）→
#       每受试者按 DSSTDTC 降序取最新一条 → 缺失记为 "ONGOING"。
#
# 口径 / 假设：
#   - "最新" = DSSTDTC 最大（字符降序，ISO 日期字符串可直接比大小）。
#   - study_phase 会先 clean_column_text() 标准化（大写去标点）。
#   - exact_match 只影响非 EPOCH 的筛选列；EPOCH 恒精确匹配。
#   - 找不到任何可筛选列 → 返回 0 行的空框（带 new_col_name 空因子），并 warning。
#   - 返回的是 USUBJID + new_col_name 两列的"查找表"，需你自己 left_join 回主表。
# ---------------------------------------------------------------------------
add_disp_events <- function(data, disp_cat_col = "DSCAT", study_phase,
                            disp_reason_col = "DSDECOD", new_col_name,
                            exact_match = FALSE) {
  checkmate::assert_data_frame(data, min.rows = 1)
  checkmate::assert_character(disp_cat_col, min.chars = 1)
  checkmate::assert_character(disp_reason_col, min.chars = 1)
  checkmate::assert_character(study_phase, min.chars = 1)
  checkmate::assert_character(new_col_name, min.chars = 1)

  required_cols <- c("USUBJID", disp_cat_col, "DSSTDTC")
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("add_disp_events() 缺少必需列：", paste(missing_cols, collapse = ", "))
  }

  if (nrow(data) == 0) {
    warning("输入数据为空")
    empty_result <- data.frame(USUBJID = character(0))
    empty_result[[new_col_name]] <- factor()
    return(empty_result)
  }

  disp_cat_col <- rlang::sym(disp_cat_col)
  new_col_name <- rlang::sym(new_col_name)
  disp_reason_col <- rlang::sym(disp_reason_col)

  study_phase <- clean_column_text(study_phase)

  # 若这些列存在则一并标准化
  columns_to_clean <- c("EPOCH", "DSREFID", "PERIOD", "DSSCAT")
  for (col in columns_to_clean) {
    if (col %in% names(data)) data[[col]] <- clean_column_text(data[[col]])
  }

  filtered_data <- data |>
    dplyr::filter({{ disp_cat_col }} %in% c("DISPOSITION EVENT"))

  # 按优先级找第一个可用的筛选列
  filter_columns <- c("DSREFID", "PERIOD", "DSSCAT", "EPOCH")
  filter_column <- NULL
  for (col in filter_columns) {
    if (col %in% names(filtered_data)) {
      filter_column <- col
      break
    }
  }

  if (!is.null(filter_column)) {
    if (filter_column == "EPOCH" || exact_match) {
      filtered_data <- filtered_data |>
        dplyr::filter(toupper(!!rlang::sym(filter_column)) %in% toupper(study_phase))
    } else {
      filtered_data <- filtered_data |>
        dplyr::filter(grepl(paste(study_phase, collapse = "|"), !!rlang::sym(filter_column)))
    }
  } else {
    warning("找不到可用于筛选的列（DSREFID / PERIOD / DSSCAT / EPOCH）。")
    empty <- data.frame(USUBJID = character(0))
    empty[[as.character(new_col_name)]] <- factor()
    return(empty)
  }

  if (nrow(filtered_data) == 0) {
    warning("按研究阶段筛选后无记录：", paste(study_phase, collapse = ", "))
    empty <- data.frame(USUBJID = character(0))
    empty[[as.character(new_col_name)]] <- factor()
    return(empty)
  }

  processed_data <- filtered_data |>
    dplyr::mutate(NEW_COL = !!disp_reason_col) |>
    dplyr::select(USUBJID, NEW_COL, DSSTDTC) |>
    dplyr::filter(!is.na(NEW_COL) & NEW_COL != "") |>
    dplyr::group_by(USUBJID) |>
    dplyr::arrange(USUBJID, dplyr::desc(DSSTDTC)) |>
    dplyr::slice(1) |>
    dplyr::ungroup() |>
    dplyr::select(USUBJID, NEW_COL) |>
    dplyr::distinct()

  result_df <- processed_data |>
    dplyr::mutate(
      TEMP_COL = factor(ifelse(is.na(NEW_COL) | NEW_COL == "", "ONGOING", toupper(NEW_COL)))
    ) |>
    dplyr::select(-NEW_COL)
  names(result_df)[names(result_df) == "TEMP_COL"] <- as.character(new_col_name)

  result_df
}


# ---------------------------------------------------------------------------
# add_death_reason(): 从 DD（死亡细节）域取主死因，并合并回主表
#
# 手段：DD 里过滤 DDTESTCD == "PRCDTH"（主死因）且 EPOCH 落在 study_phase →
#       缺失记为 "UNKNOWN" → left_join 回 data，打上 label。
#
# 口径 / 假设：
#   - 只取"主要死因"（PRCDTH）。study_phase 用 clean_column_text 标准化后做
#     前缀匹配（^(phase1|phase2)）。
#   - label 必填：DD 非空时若没给 label 会 stop（强制你显式命名，避免裸列）。
#   - DD 为空时，新列填 NA 因子（保证列存在，下游布局不缺列）。
#   - 合并键 USUBJID；用 suffix + 删 .y 列的方式避免撞名。
# ---------------------------------------------------------------------------
add_death_reason <- function(data, death_domain, death_reason_col = "DDSTRESC",
                             study_phase = NULL, new_col_name = NULL, label = NULL) {
  checkmate::assert_data_frame(data, min.rows = 1)
  checkmate::assert_data_frame(death_domain, min.rows = 1)
  checkmate::assert_character(death_reason_col, min.chars = 1)
  checkmate::assert_character(new_col_name, min.chars = 1)
  checkmate::assert_character(study_phase, min.chars = 1, null.ok = TRUE)

  new_col_name <- rlang::sym(new_col_name)
  study_phase <- clean_column_text(study_phase)
  death_domain[["EPOCH"]] <- clean_column_text(death_domain[["EPOCH"]])

  death_domain <- death_domain |>
    dplyr::filter(
      toupper(.data[["DDTESTCD"]]) == "PRCDTH",
      grepl(paste0("^(", paste(study_phase, collapse = "|"), ")"),
            as.character(.data[["EPOCH"]]), ignore.case = TRUE)
    ) |>
    dplyr::select(USUBJID, {{ death_reason_col }}) |>
    dplyr::mutate(
      !!new_col_name := dplyr::if_else(
        is.na(as.character(.data[[death_reason_col]])), "UNKNOWN",
        as.character(.data[[death_reason_col]])
      ) |> toupper() |> as.factor() |> droplevels()
    ) |>
    dplyr::distinct()

  if (!is.null(label) & nrow(death_domain) > 0) {
    data <- data |>
      dplyr::left_join(death_domain, by = "USUBJID", suffix = c("", ".y")) |>
      dplyr::select(-dplyr::ends_with(".y")) |>
      dplyr::select(!{{ death_reason_col }})
  } else if (!is.null(label) & nrow(death_domain) == 0) {
    data <- data |>
      dplyr::mutate(!!new_col_name := NA_character_ |> as.factor() |> droplevels())
  } else {
    stop("DD 域非空时必须提供非 NULL 的 label。")
  }

  if (!is.null(label)) {
    data[[new_col_name]] <- lbl(data[[new_col_name]], label)
  }
  data
}


# ---------------------------------------------------------------------------
# add_trt_discont_flag(): 从（可多个）处置编码列派生治疗中止标记 DCTFL
#
# 手段：逐行把若干处置列的值按 "|" 拆开、trim、去空，然后：
#   - 含 "ONGOING"               → "N"（未中止）
#   - 含 "COMPLETED"/"DISCONTINUED" → "Y"（已中止/完成治疗阶段）
#   - 全为 NA/空/"PATIENT WITHOUT DISPOSITION EVENT" → NA
#
# 口径 / 假设：
#   - ONGOING 优先级最高（只要有一个阶段还在进行，就算未中止 "N"）。
#   - 大小写敏感、精确匹配这几个关键词；你的编码表不同就改这几个常量。
#   - treatment_disp_col 可传多列（多治疗阶段），值是 "|" 分隔的复合串。
#   - rowwise + c_across 实现，行多时较慢；大数据可考虑向量化重写。
# ---------------------------------------------------------------------------
add_trt_discont_flag <- function(data, treatment_disp_col = c("DSTRTCODFL")) {
  checkmate::assert_data_frame(data)
  checkmate::assert_character(treatment_disp_col, min.len = 1, null.ok = FALSE)

  missing_cols <- setdiff(treatment_disp_col, names(data))
  if (length(missing_cols) > 0) {
    stop("add_trt_discont_flag() 缺少必需列：", paste(missing_cols, collapse = ", "))
  }

  data |>
    dplyr::rowwise() |>
    dplyr::mutate(
      DCTFL = {
        row_values <- dplyr::c_across(dplyr::all_of(treatment_disp_col))
        all_values <- unlist(strsplit(as.character(row_values), "\\|", fixed = FALSE))
        all_values <- trimws(all_values)
        non_empty_values <- all_values[nchar(all_values) > 0]

        if (any(non_empty_values %in% c("ONGOING"))) {
          "N"
        } else if (any(non_empty_values %in% c("COMPLETED", "DISCONTINUED"))) {
          "Y"
        } else if (all(is.na(row_values) | row_values == "" |
                       row_values %in% c("PATIENT WITHOUT DISPOSITION EVENT"))) {
          NA_character_
        } else {
          NA_character_
        }
      }
    ) |>
    dplyr::ungroup()
}


# ---------------------------------------------------------------------------
# add_disp_study_days(): 把一批 *DTC 处置日期列批量转成对应的 *DY 研究日列
#
# 手段：对每个 date_col 用 studyDay(date, refdate = RFXSTDTC) 算研究日，新列名
#       把结尾 "DTC" 换成 "DY"。再按前缀给新列打默认 label（可被 dy_labels 覆盖）。
#
# 口径 / 假设：
#   - 参照日期恒为 RFXSTDTC（首次给药日期）；数据必须含此列。
#   - 所有 date_cols 必须以 "DTC" 结尾（否则 stop）——这是列名约定的护栏。
#   - studyDay 的口径见 01 文件（首日通常为 1，无第 0 天，视其实现而定）。
#   - 默认 label 表覆盖 DSFU/DSLFU/DSLGFU/DSEOS/DSSUFU 等常见处置日；用户传的
#     dy_labels 优先级更高（按 named 向量合并）。
# ---------------------------------------------------------------------------
add_disp_study_days <- function(data, date_cols, dy_labels = NULL) {
  checkmate::assert_data_frame(data, min.rows = 1)
  checkmate::assert_character(date_cols, min.len = 1, any.missing = FALSE)
  checkmate::assert_names(names(data), must.include = "RFXSTDTC")
  checkmate::assert(
    checkmate::check_null(dy_labels),
    checkmate::check_character(dy_labels, min.len = 1, names = "named"),
    .var.name = "dy_labels"
  )

  non_dtc <- date_cols[!grepl("DTC$", date_cols)]
  if (length(non_dtc) > 0) {
    stop("以下列不以 'DTC' 结尾，无法转成研究日列：", paste(non_dtc, collapse = ", "))
  }
  missing_cols <- setdiff(date_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("处置数据集中不存在以下列：", paste(missing_cols, collapse = ", "))
  }

  result <- data |>
    dplyr::mutate(
      dplyr::across(
        .cols = dplyr::all_of(date_cols),
        .fns = ~ studyDay(
          date    = as.Date(as.character(.x)),
          refdate = as.Date(as.character(RFXSTDTC))
        ),
        .names = "{gsub('DTC$', 'DY', .col)}"
      )
    )

  default_dy_labels <- c(
    DSFU   = "Disposition Follow Up Days",
    DSLFU  = "Disposition Long Term Follow Up Days",
    DSLGFU = "Disposition Long Term Follow Up Days",
    DSEOS  = "Disposition End of Study Days",
    DSSUFU = "Disposition Survival Follow Up Days"
  )
  active_labels <- if (is.null(dy_labels)) {
    default_dy_labels
  } else {
    c(dy_labels, default_dy_labels[!names(default_dy_labels) %in% names(dy_labels)])
  }

  result_dy_cols <- names(result)[grepl("DY$", names(result))]
  input_dy_cols <- names(data)[grepl("DY$", names(data))]
  created_dy_cols <- result_dy_cols[!result_dy_cols %in% input_dy_cols]

  for (col in created_dy_cols) {
    for (pattern in names(active_labels)) {
      if (startsWith(col, pattern) && endsWith(col, "DY")) {
        attr(result[[col]], "label") <- active_labels[[pattern]]
        break
      }
    }
  }
  result
}


# ===========================================================================
# 2) VISIT（访视号 / 基线访视 规整）
# ===========================================================================

# ---------------------------------------------------------------------------
# create_blfl_var(): 按域名拼基线标记变量名
#
# 口径 / 假设：疗效域（ADEFTM/ADEFF 等）用 "EFBLFL"，其余用 <域名>BLFL。
#   纯字符串工具，配合下面几支函数使用。
# ---------------------------------------------------------------------------
create_blfl_var <- function(domain_name) {
  if (domain_name %in% c("ADEFTM", "ADEFTM1", "ADEFF", "ADEFF_CDEX")) {
    "EFBLFL"
  } else {
    paste0(domain_name, "BLFL")
  }
}


# ---------------------------------------------------------------------------
# add_baseline_visit(): 派生 AVISIT / AVISITN（含时间点后缀、非计划访视处理）
#
# 手段：若域内有 <域>TPT/<域>TPTNUM（时间点），把时间点拼进访视名并给 VISITNUM
#       加小数偏移；否则直接用 VISIT。最后 AVISIT 转成按 AVISITN + 采样日期排序
#       的因子。
#
# 口径 / 假设：
#   - 需要 USUBJID / VISIT / VISITNUM / <域>DTC；缺列即 cli_abort。
#   - 时间点偏移把 TPTNUM 缩放到小数位（除以 10^位数），非计划访视（VISIT 含
#     "Unsch"）再加 0.009，保证排序里排在同名计划访视之后。这套编号是"为了排序
#     好看"的启发式，不是 CDISC 规定口径——若你所在项目对 AVISITN 有硬性定义，
#     请按项目 SAP 重写。
#   - 源码里"若 BLFL=='Y' 则 AVISIT='BASELINE'"那行是被注释掉的，这里保持注释
#     状态（即基线不单独命名为 BASELINE），需要就打开。
#   - 结尾 distinct()，注意会去重。
# ---------------------------------------------------------------------------
add_baseline_visit <- function(data, domain_name = "VS") {
  domain_name <- trimws(domain_name)
  checkmate::assert_data_frame(data, min.rows = 1)
  checkmate::assert_character(domain_name, min.chars = 1)

  make_name <- function(x) paste0(domain_name, x)
  tpt_var <- make_name("TPT")
  tptnum_var <- make_name("TPTNUM")
  dtc_var <- make_name("DTC")

  req_vars <- c("USUBJID", "VISIT", "VISITNUM", dtc_var)
  mis_vars <- req_vars[!req_vars %in% names(data)]
  if (length(mis_vars) > 0) {
    cli::cli_abort(c(
      "数据框缺少必需列：",
      "x" = "{length(mis_vars)} 个缺失列：{mis_vars}"
    ))
  }

  if (all(c(tpt_var, tptnum_var) %in% names(data))) {
    checkmate::assert_false(all(sapply(data[c(tpt_var, tptnum_var)], function(col) all(is.na(col)))))
    data |>
      dplyr::mutate(
        new_visit = paste(
          as.character(VISIT),
          ifelse(as.character(.data[[tpt_var]]) == "" | is.na(.data[[tpt_var]]) |
                   as.character(VISIT) == as.character(.data[[tpt_var]]) |
                   stringr::str_detect(VISIT, "UNSCH"),
                 "", paste0("(", as.character(.data[[tpt_var]]), ")"))
        ) |> trimws(),
        new_visit_num = VISITNUM +
          ifelse(is.na(.data[[tptnum_var]]), 0,
                 .data[[tptnum_var]] / (10^stringr::str_length(max(.data[[tptnum_var]], na.rm = TRUE)))) +
          ifelse(!stringr::str_detect(VISIT, "Unsch"), 0, .009)
      ) |>
      dplyr::mutate(
        VISIT = new_visit,
        VISITNUM = new_visit_num,
        AVISIT = VISIT,
        AVISITN = new_visit_num |> lbl("Visit Number"),
        AVISIT = factor(.data[["AVISIT"]],
                        levels = unique(.data[["AVISIT"]][order(.data[["AVISITN"]], .data[[dtc_var]])])) |>
          lbl("Visit Name")
      ) |>
      dplyr::select(-c(new_visit, new_visit_num)) |>
      dplyr::distinct()
  } else {
    data |>
      dplyr::mutate(
        AVISIT = trimws(as.character(VISIT)),
        AVISITN = VISITNUM |> lbl("Visit Number"),
        AVISIT = factor(.data[["AVISIT"]],
                        levels = unique(.data[["AVISIT"]][order(.data[["AVISITN"]], .data[[dtc_var]])])) |>
          lbl("Visit Name")
      ) |>
      dplyr::distinct()
  }
}


# ---------------------------------------------------------------------------
# overwrite_baseline_flag(): 仅当整组基线标记全缺失时，用派生基线标记回填
#
# 手段：先 rm_white_spaces 清洗 → 找出按 (USUBJID, <域>TEST) 分组后 <域>BLFL
#       全为 NA 的那些记录 → 对它们跑 add_baseline_flag() 重新派生 → left_join 回。
#
# 口径 / 假设：
#   - 只回填"该受试者该指标完全没有基线标记"的情况，不覆盖已有标记。
#   - 依赖 add_baseline_flag()（01 文件，已修复缺列吞异常的 bug）。
#   - left_join 未显式指定 by，会按所有同名列连接（dplyr 会打印 message）；
#     若列结构复杂建议显式指定 by 以免意外多对多。
# ---------------------------------------------------------------------------
overwrite_baseline_flag <- function(data, df_name = NULL) {
  checkmate::assert_data_frame(data, min.rows = 1)
  checkmate::assert_character(df_name, min.chars = 1)

  make_name <- function(x) as.name(paste0(df_name, x))
  blfl_var <- make_name("BLFL")
  test_var <- make_name("TEST")

  data <- data |> rm_white_spaces()

  data1 <- data |>
    dplyr::group_by(USUBJID, !!rlang::sym(test_var)) |>
    dplyr::filter(all_na(as.character(!!rlang::sym(blfl_var)))) |>
    dplyr::ungroup()

  data2 <- data1 |>
    dplyr::mutate(original_BLFL = as.character(!!rlang::sym(blfl_var))) |>
    dplyr::select(-!!rlang::sym(blfl_var)) |>
    add_baseline_flag(df_name = df_name) |>
    dplyr::mutate(!!blfl_var := as.factor(!!rlang::sym(blfl_var))) |>
    dplyr::mutate(!!blfl_var := lbl(!!rlang::sym(blfl_var), "Baseline Flag")) |>
    dplyr::select(-original_BLFL)

  data |>
    dplyr::left_join(data2) |>
    dplyr::distinct()
}


# ---------------------------------------------------------------------------
# update_unsch_visit_number(): 给非计划访视（UNSCH / EOT）重编 VISITNUM 与 VISIT
#
# 手段：每受试者每指标内，按采样日/日期排序 → 计划访视保留原号，非计划访视
#       在其"前一个计划访视号"基础上按出现次序加小数（1/10^位数）→ 生成新访视名。
#       可选 use_subjid_format 把非计划访视名写成 "Unscheduled <SUBJID> (Day X)"。
#
# 口径 / 假设：
#   - "非计划"判定：VISIT（大写）含 UNSCH / END OF TREAT / EOT。
#   - 需要 USUBJID/VISIT/VISITNUM/SUBJID 以及 <域>DY、<域>DTC。缺列即 cli_abort。
#   - 小数编号是排序启发式（同前）；不是监管口径，按项目定义可能要改。
#   - 原实现里的 cat("All required columns...") 调试打印已删除。
#   - EOT 与真正的 unscheduled 在这支里共用一个计数器；若你要 EOT 单独编号，
#     用下面的 update_eot_visit_number()。
# ---------------------------------------------------------------------------
update_unsch_visit_number <- function(data, df_name = "LB", use_subjid_format = FALSE, ...) {
  checkmate::assert_data_frame(data, min.rows = 1)
  checkmate::assert_string(df_name, null.ok = TRUE)
  checkmate::assert_logical(use_subjid_format, len = 1)

  study_day <- as.name(paste0(df_name, "DY"))
  study_date <- as.name(paste0(df_name, "DTC"))
  test_var <- as.name(paste0(df_name, "TEST"))

  req_vars <- c("USUBJID", "VISIT", "VISITNUM", "SUBJID",
                sapply(c(study_day, study_date), as.character))
  mis_vars <- req_vars[!req_vars %in% names(data)]
  if (length(mis_vars) > 0) {
    cli::cli_abort(c(
      "数据框缺少必需列：",
      "x" = "{length(mis_vars)} 个缺失列：{mis_vars}"
    ))
  }
  checkmate::assert_false(all(sapply(data[req_vars], function(col) all(is.na(col)))))

  new_sv <- data |>
    dplyr::arrange(!!study_day, !!study_date) |>
    dplyr::distinct(.data[["USUBJID"]], !!test_var, .data[["VISITNUM"]], .data[["VISIT"]], !!study_day, !!study_date) |>
    dplyr::group_by(.data[["USUBJID"]], !!test_var) |>
    dplyr::mutate(row_id = dplyr::row_number()) |>
    dplyr::mutate(
      is_unscheduled = stringr::str_detect(toupper(.data[["VISIT"]]),
                                           stringr::regex("UNSCH|END OF TREAT|EOT", ignore_case = TRUE)),
      new_vis = dplyr::case_when(
        is_unscheduled & row_id == 1 ~ .data[["VISITNUM"]],
        is_unscheduled & row_id != 1 ~ NA_integer_,
        !is_unscheduled ~ .data[["VISITNUM"]]
      )
    ) |>
    tidyr::fill(new_vis, .direction = "down") |>
    dplyr::ungroup() |>
    dplyr::mutate(
      unsch_counter = cumsum(is_unscheduled),
      unsch_decimal_places = stringr::str_length(max(unsch_counter, na.rm = TRUE)),
      updated_visit_number = dplyr::case_when(
        is_unscheduled ~ new_vis + unsch_counter / (10^unsch_decimal_places),
        TRUE ~ new_vis
      ),
      new_visit = as.factor(dplyr::case_when(
        is_unscheduled ~ paste(gsub("\\d+(\\.\\d+)?", "", VISIT), updated_visit_number),
        TRUE ~ as.character(VISIT)
      ))
    ) |>
    dplyr::distinct()

  data <- data |>
    dplyr::left_join(new_sv, by = c("USUBJID", "VISIT", "VISITNUM",
                                    paste(study_day), paste(test_var), paste(study_date)))

  if (use_subjid_format) {
    data <- data |>
      dplyr::mutate(
        SUBJID1 = stringr::str_extract(USUBJID, "[^-]+-[^-]+$"),
        new_visit = dplyr::case_when(
          is_unscheduled ~ paste("Unscheduled",
                                 paste(stringr::str_replace(as.character(.data[["SUBJID1"]]), " ", "-")),
                                 "(Day", !!study_day, ")"),
          TRUE ~ as.character(.data[["VISIT"]])
        ) |> as.factor()
      ) |>
      dplyr::select(-SUBJID1)
  } else {
    data <- data |>
      dplyr::mutate(
        new_visit = dplyr::case_when(
          is_unscheduled ~ paste(gsub("\\d+(\\.\\d+)?", "", .data[["VISIT"]]), updated_visit_number),
          TRUE ~ as.character(.data[["VISIT"]])
        ) |> as.factor()
      )
  }

  data |>
    dplyr::mutate(
      VISIT = new_visit,
      VISITNUM = updated_visit_number
    ) |>
    dplyr::select(-c(updated_visit_number, new_visit, is_unscheduled,
                     unsch_counter, new_vis, unsch_decimal_places, row_id)) |>
    dplyr::ungroup()
}


# ---------------------------------------------------------------------------
# update_eot_visit_number(): 专门给 EOT / 随访访视重编号（EOT 单独计数）
#
# 手段：每受试者每指标每治疗组内，按研究日排序 → EOT 访视号置 NA 后向下填其
#       前一个访视号 → EOT 按出现次序加 counter/100 → 同时派生 AVISIT/AVISITN
#       （BLFL=='Y' 记为 "BASELINE"）。
#
# 口径 / 假设：
#   - "EOT" 判定：VISIT（大写）含 "END OF TREATMENT" 或 "EOT"。
#   - 需要 <域>DY、<域>TEST、<域>BLFL、以及 USUBJID/VISIT/VISITNUM/TRT。
#   - EOT 偏移用 /100（最多 99 个 EOT 不冲突）；与 unsch 函数的 /10^位数 口径不同。
#   - 这支保留了"BLFL=='Y' → AVISIT='BASELINE'"（与 add_baseline_visit 的注释态相反），
#     用哪支取决于你要不要把基线单独命名。
# ---------------------------------------------------------------------------
update_eot_visit_number <- function(data, df_name = "LB", ...) {
  checkmate::assert_data_frame(data, min.rows = 1)
  checkmate::assert_string(df_name, null.ok = TRUE)

  study_day <- as.name(paste0(df_name, "DY"))
  test_var <- as.name(paste0(df_name, "TEST"))
  blfl_var <- as.name(paste0(df_name, "BLFL"))

  new_sv <- data |>
    dplyr::arrange(USUBJID, !!study_day) |>
    dplyr::distinct(USUBJID, !!test_var, TRT, VISITNUM, VISIT) |>
    dplyr::group_by(USUBJID, !!test_var, TRT) |>
    dplyr::mutate(
      is_eot = stringr::str_detect(toupper(VISIT), stringr::regex("END OF TREATMENT|EOT")),
      new_visitnum = ifelse(is_eot, NA_integer_, VISITNUM),
      new_order = dplyr::row_number()
    ) |>
    tidyr::fill(new_visitnum, .direction = "down") |>
    dplyr::mutate(
      unsch_counter = cumsum(is_eot),
      new_visitnum = ifelse(is.na(new_visitnum), 0, new_visitnum),
      updated_eot_visit_number = ifelse(is_eot, new_visitnum + unsch_counter / 100, new_visitnum),
      updted_visit = as.factor(ifelse(is_eot, paste(VISIT, updated_eot_visit_number), as.character(VISIT))) |> droplevels(),
      VISIT1 = updted_visit,
      VISITNUM1 = updated_eot_visit_number
    ) |>
    dplyr::ungroup() |>
    dplyr::distinct()

  data |>
    dplyr::left_join(new_sv, by = c("USUBJID", "VISIT", "VISITNUM", paste(test_var), "TRT")) |>
    dplyr::mutate(
      VISIT = VISIT1,
      VISITNUM = VISITNUM1,
      AVISIT = ifelse(.data[[blfl_var]] %in% c("Y"), "BASELINE", trimws(as.character(VISIT))),
      AVISITN = VISITNUM |> lbl("Visit Number")
    ) |>
    dplyr::select(-c(updated_eot_visit_number, updted_visit, is_eot, new_visitnum, VISIT1, VISITNUM1))
}


# ===========================================================================
# 3) 肿瘤最佳总体反应（RECIST / 反应评估映射）
#    注：这两支是肿瘤疗效专用口径（RESPONSE / RECIST 家族），非肿瘤研究用不上。
#        映射的是自由文本反应 → 标准缩写，属于领域词典，直接搬用前请核对你所在
#        瘤种 / 评估标准（RECIST 1.1 vs 免疫相关 vs 血液瘤等）的取值。
# ===========================================================================

# ---------------------------------------------------------------------------
# add_bor_category(): 把 RSSTRESC / RSORRES 的自由文本反应归一到标准缩写/全称
#
# 口径 / 假设：
#   - RSSTRESC → 标准缩写（SD/PR/CR/PD/VGPR/MR/sCR/NE/…，含 PET 代谢反应与
#     CT-based 变体）；RSORRES → 标准全称。
#   - 归类规则是一长串 case_when，覆盖多种瘤种的写法；未命中的保持原值/大写。
#   - 依赖 %!in%（01 文件）。这份映射本质是"数据字典硬编码"，是领域知识不是 bug，
#     但**务必**对照你项目的反应取值清单增删，别假设它覆盖你的场景。
# ---------------------------------------------------------------------------
add_bor_category <- function(data) {
  data |>
    dplyr::mutate(
      RSSTRESC = dplyr::case_when(
        stringr::str_starts(toupper(RSSTRESC), "STABLE") & (toupper(RSSTRESC) %!in% c("STABLE METABOLIC DISEASE", "STABLE DISEASE, CT-BASED")) ~ "SD",
        stringr::str_starts(toupper(RSSTRESC), "PARTIAL") & (toupper(RSSTRESC) %!in% c("PARTIAL METABOLIC RESPONSE", "PARTIAL RESPONSE, CT-BASED")) ~ "PR",
        stringr::str_starts(toupper(RSSTRESC), "COMPLETE") & (toupper(RSSTRESC) %!in% c("COMPLETE METABOLIC RESPONSE", "COMPLETE RESPONSE, CT-BASED")) ~ "CR",
        stringr::str_starts(toupper(RSSTRESC), "PROGRESSIVE") & (toupper(RSSTRESC) %!in% c("PROGRESSIVE METABOLIC DISEASE", "PROGRESSIVE DISEASE, CT-BASED")) ~ "PD",
        toupper(RSSTRESC) %in% c("VERY GOOD PARTIAL RESPONSE") ~ "VGPR",
        toupper(RSSTRESC) %in% c("MINIMAL RESPONSE") ~ "MR",
        toupper(RSSTRESC) %in% c("STRINGENT COMPLETE RESPONSE") ~ "sCR",
        toupper(RSSTRESC) %in% c("MORPHOLOGIC CR") ~ "CR",
        toupper(RSSTRESC) %in% c("TREATMENT FAILURE") ~ "TF",
        toupper(RSSTRESC) %in% c("MORPHOLOGIC LEUKEMIA-FREE STATE") ~ "MLFS",
        toupper(RSSTRESC) %in% c("NOT EVALUABLE") ~ "NE",
        toupper(RSSTRESC) %in% c("REFRACTORY DISEASE") ~ "OTH-RD",
        toupper(RSSTRESC) %in% c("NO METABOLIC RESPONSE") ~ "NMR",
        toupper(RSSTRESC) %in% c("COMPLETE METABOLIC RESPONSE") ~ "CMR",
        toupper(RSSTRESC) %in% c("PARTIAL METABOLIC RESPONSE") ~ "PMR",
        toupper(RSSTRESC) %in% c("STABLE METABOLIC DISEASE") ~ "SMD",
        toupper(RSSTRESC) %in% c("PROGRESSIVE METABOLIC DISEASE") ~ "PMD",
        toupper(RSSTRESC) %in% c("PARTIAL RESPONSE, CT-BASED") ~ "PRCT",
        toupper(RSSTRESC) %in% c("COMPLETE RESPONSE, CT-BASED") ~ "CRCT",
        toupper(RSSTRESC) %in% c("STABLE DISEASE, CT-BASED") ~ "SDCT",
        toupper(RSSTRESC) %in% c("PROGRESSIVE DISEASE, CT-BASED") ~ "PDCT",
        toupper(RSSTRESC) %in% c("NOT EVALUABLE", "NON-EVALUABLE FOR RESPONSE") | stringr::str_starts(toupper(RSSTRESC), "NOT EVALUABLE") ~ "NE",
        TRUE ~ RSSTRESC
      ) |> as.factor(),
      RSORRES = dplyr::case_when(
        (stringr::str_starts(toupper(RSORRES), "STABLE") | toupper(RSORRES) == "SD" | ((is.na(RSORRES) | RSORRES == "") & toupper(RSSTRESC) == "SD")) & (toupper(RSORRES) %!in% c("STABLE METABOLIC DISEASE", "STABLE DISEASE, CT-BASED")) ~ "STABLE DISEASE",
        (stringr::str_starts(toupper(RSORRES), "PARTIAL") & stringr::str_detect(toupper(RSORRES), "RESPONSE") | ((is.na(RSORRES) | RSORRES == "") & toupper(RSSTRESC) == "PR")) & (toupper(RSORRES) %!in% c("PARTIAL METABOLIC RESPONSE", "PARTIAL RESPONSE, CT-BASED")) ~ "PARTIAL RESPONSE",
        stringr::str_starts(toupper(RSORRES), "PARTIAL REMISSION") ~ "PARTIAL REMISSION",
        (stringr::str_starts(toupper(RSORRES), "PARTIAL") | toupper(RSORRES) == "PR") & (toupper(RSORRES) %!in% c("PARTIAL METABOLIC RESPONSE", "PARTIAL RESPONSE, CT-BASED")) ~ "PARTIAL RESPONSE",
        (stringr::str_starts(toupper(RSORRES), "COMPLETE") | toupper(RSORRES) == "CR" | ((is.na(RSORRES) | RSORRES == "") & toupper(RSSTRESC) == "CR")) & (toupper(RSORRES) %!in% c("COMPLETE METABOLIC RESPONSE", "COMPLETE RESPONSE, CT-BASED")) ~ "COMPLETE RESPONSE",
        (stringr::str_starts(toupper(RSORRES), "PROGRESSIVE") | toupper(RSORRES) == "PD" | ((is.na(RSORRES) | RSORRES == "") & toupper(RSSTRESC) == "PD")) & (toupper(RSORRES) %!in% c("PROGRESSIVE METABOLIC DISEASE", "PROGRESSIVE DISEASE, CT-BASED")) ~ "PROGRESSIVE DISEASE",
        stringr::str_starts(toupper(RSORRES), "REFRACTORY DISEASE") ~ "OTHER - REFRACTORY DISEASE",
        toupper(RSORRES) == "VGPR" | ((is.na(RSORRES) | RSORRES == "") & toupper(RSSTRESC) == "VGPR") ~ "VERY GOOD PARTIAL RESPONSE",
        toupper(RSORRES) == "MR" | ((is.na(RSORRES) | RSORRES == "") & toupper(RSSTRESC) == "MR") ~ "MINIMAL RESPONSE",
        toupper(RSORRES) == "SCR" | ((is.na(RSORRES) | RSORRES == "") & toupper(RSSTRESC) == "SCR") ~ "STRINGENT COMPLETE RESPONSE",
        toupper(RSORRES) == "NE" | ((is.na(RSORRES) | RSORRES == "") & toupper(RSSTRESC) == "NE") ~ "NOT EVALUABLE",
        TRUE ~ toupper(RSORRES)
      ) |> as.factor()
    )
}


# ---------------------------------------------------------------------------
# update_bor_values(): 规整"最佳总体反应"变量的取值并按临床顺序排水平
#
# 手段：NA/UNKNOWN → "UN"；以 "OTHER" 开头 → "OTH"；"DISEASE PROGRESSION" → "PD"；
#       然后按 response_order + "UN" 设因子水平顺序。
#
# 口径 / 假设：
#   - 默认顺序 c("CR","PR","SD","PD")，UN 垫底——这是最常见的 RECIST 排序；
#     血液瘤/其他标准请传自己的 response_order。
#   - droplevels 会丢掉数据里没出现的水平。
# ---------------------------------------------------------------------------
update_bor_values <- function(data,
                              response_order = c("CR", "PR", "SD", "PD"),
                              bor_var = "BEST_OVERALL_RESPONSE") {
  checkmate::assert_data_frame(data, min.rows = 1)

  data |>
    dplyr::mutate(!!bor_var := dplyr::case_when(
      is.na(!!rlang::sym(bor_var)) | !!rlang::sym(bor_var) %in% "UNKNOWN" ~ "UN",
      stringr::str_starts(!!rlang::sym(bor_var), "OTHER") ~ "OTH",
      !!rlang::sym(bor_var) %in% "DISEASE PROGRESSION" ~ "PD",
      TRUE ~ as.character(!!rlang::sym(bor_var))
    ) |> as.factor() |> droplevels()) |>
    dplyr::mutate(!!bor_var := factor(!!rlang::sym(bor_var), levels = c(response_order, "UN")) |>
                    droplevels() |> lbl("Best Overall Response"))
}
