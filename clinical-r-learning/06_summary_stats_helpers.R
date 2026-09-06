# 06_summary_stats_helpers.R
# ============================================================================
# 汇总统计 / 描述性统计辅助函数（A1 类）
#
# 这一组是做 TLF 汇总表时最常用的"算数字"函数：n(%)、Mean(SD)/Median CI 等
# 描述统计、按变量数受试者、箱线图五数概括与离群点。
#
# 其中 count_percentage() + custom_summary_fn() 直接回答了"CDISC n(%) 怎么写"
# 这个问题 —— 它们是喂给 tern::tm_t_summary / rtables 布局的 cell 生成器。
#
# 依赖：dplyr、rtables（in_rows）、tern（tern_default_formats）、forcats、stats
# 可直接 source() 使用。
# ============================================================================


# ---------------------------------------------------------------------------
# count_percentage(): 因子/字符向量 → "n (xx.x%)" 列表
#
# 手段：table() 数频数 → prop.table() 算占比 → 拼成 "count (perc%)" 字符串，
#       返回一个 named list，正好可以塞进 rtables::in_rows(.list = ...)。
#
# 口径 / 假设：
#   - useNA = "no"：默认不把 NA 当成一类计数。想显示缺失就传 "ifany"/"always"，
#     此时 NA 的类名会被替换成 na_level（默认 "<Missing>"）。
#   - 百分比分母 = table() 的合计（即所有被计数的观测），四舍五入到 1 位小数。
#   - 返回的是"记录数"而非"去重受试者数"。若要 subject-level 的 n(%)，
#     先在外层对 USUBJID 去重再传进来。
# ---------------------------------------------------------------------------
count_percentage <- function(x, useNA = "no", na_level = "<Missing>") {
  counts <- table(x, useNA = useNA)
  perc <- prop.table(counts) * 100
  perc[is.na(perc)] <- 0
  names(counts)[is.na(names(counts))] <- na_level
  names(perc)[is.na(names(perc))] <- na_level

  l_cp <- lapply(names(counts), function(nm) {
    paste0(counts[nm], " (", round(perc[nm], 1), "%)")
  })

  names(l_cp) <- names(counts)
  l_cp
}


# ---------------------------------------------------------------------------
# custom_summary_fn(): tern/rtables 通用的"一格统计量"生成器
#
# 手段：
#   - 数值型 x：按 stats 参数选择要算的统计量（n / mean_sd / mean_ci /
#     geom_mean / median / median_ci / quantiles / range），用 tern 的默认
#     格式渲染，返回 rtables::in_rows()。
#   - 因子/字符 x：返回 n + count_percentage() 的类别分布。
#
# 口径 / 假设：
#   - denominator == "N"：n 用总长度（含 NA）；否则用非 NA 个数。分类变量时
#     denominator == "n" 会先把 na_level 从水平里剔除（forcats::fct_drop）。
#   - mean_ci 用正态近似（±1.96 * SE），不是 t 分布。样本量小时口径偏窄，
#     若要与 SAS PROC 对齐（t 分位数），需自行替换成 qt()。
#   - median_ci 走下面的 median_ci()（分布无关的次序统计量法）。
#   - stats 里的名字必须落在 summ_type 里，且顺序即输出顺序。
# ---------------------------------------------------------------------------
custom_summary_fn <- function(x, denominator = "N",
                              stats = c("n", "mean_sd"),
                              na_level = "<Missing>") {
  if (is.numeric(x)) {
    # summ_type 的顺序需与 tern::tern_default_formats 的键一致
    summ_type <- c(
      "n", "mean_sd", "mean_ci", "geom_mean",
      "median", "median_ci", "quantiles", "range"
    )
    summ_label <- c(
      "n", "Mean (SD)", "Mean 95% CI", "Geometric Mean",
      "Median", "Median 95% CI", "25%, 75%", "Min, Max"
    )
    summ_list <- list(
      n         = ifelse(denominator == "N", length(x), length(x[!is.na(x)])),
      mean_sd   = c(mean(x, na.rm = TRUE), stats::sd(x, na.rm = TRUE)),
      mean_ci   = c(
        mean(x, na.rm = TRUE) - 1.96 * stats::sd(x, na.rm = TRUE) / sqrt(length(x[!is.na(x)])),
        mean(x, na.rm = TRUE) + 1.96 * stats::sd(x, na.rm = TRUE) / sqrt(length(x[!is.na(x)]))
      ),
      geom_mean = exp(mean(log(x), na.rm = TRUE)),
      median    = c(stats::median(x, na.rm = TRUE)),
      median_ci = c(median_ci(x)),
      quantiles = stats::quantile(x, probs = c(0.25, 0.75), na.rm = TRUE, type = 2),
      range     = range(x, na.rm = TRUE)
    )
    names(summ_list) <- summ_label

    fmt <- tern::tern_default_formats[stats]
    if ("range" %in% stats) fmt[["range"]] <- c("xx.xx, xx.xx")
    if ("quantiles" %in% stats) fmt[["quantiles"]] <- c("xx.xx, xx.xx")

    rtables::in_rows(
      .list = summ_list[summ_label[summ_type %in% stats]],
      .formats = fmt
    )
  } else if (is.factor(x) || is.character(x)) {
    if (denominator == "n") {
      x <- x[x != na_level]
      if (is.factor(x)) x <- forcats::fct_drop(x, only = na_level)
    }
    rtables::in_rows(
      .list = c(
        list(n = length(x)),
        count_percentage(x)
      ),
      .formats = NULL
    )
  }
}


# ---------------------------------------------------------------------------
# median_ci(): 中位数的置信区间（分布无关，基于二项次序统计量）
#
# 手段：把 CI 的上下界定位到排序后数据的某两个次序位（rank），rank 由
#       qbinom(alpha/2, n, 0.5) 给出。这是教科书里对中位数做的非参数 CI。
#
# 口径 / 假设：
#   - 先剔除 NA。conf_level 默认 0.95。
#   - 返回长度 2 的向量 c(lower, upper)，是"实际观测值"，不是插值。
#   - n 很小时上下界可能落到同一个观测（区间退化），这是方法本身的性质。
# ---------------------------------------------------------------------------
median_ci <- function(data, conf_level = 0.95) {
  data <- data[!is.na(data)]
  sorted_data <- sort(data)
  n <- length(data)
  alpha <- 1 - conf_level
  lower_rank <- floor(stats::qbinom(alpha / 2, n, 0.5))
  upper_rank <- ceiling(stats::qbinom(1 - alpha / 2, n, 0.5))
  lower_bound <- sorted_data[max(1, lower_rank)]
  upper_bound <- sorted_data[min(n, upper_rank)]
  c(lower_bound, upper_bound)
}


# ---------------------------------------------------------------------------
# count_subjects_by_var(): 按某变量数"记录数"
#
# 口径 / 假设：
#   - 名字叫 subject count，但实现是 n()（记录数），若一个受试者在同一类别下
#     有多条记录会被重复计。真要去重受试者数，请把 summarise 改成
#     dplyr::n_distinct(USUBJID)。这里保持原实现，仅提示。
#   - 需要 data 含 USUBJID 与 var 列。
# ---------------------------------------------------------------------------
count_subjects_by_var <- function(data, var = "AEDECOD") {
  data |>
    dplyr::select(dplyr::all_of(c("USUBJID", var))) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(var))) |>
    dplyr::summarise(subj_count = dplyr::n(), .groups = "drop")
}


# ---------------------------------------------------------------------------
# counts_patients_per_category(): 按类别的"去重受试者" n(%)，宽表输出
#
# 手段：对每个类别数 USUBJID 的去重个数，除以总去重受试者数得百分比，
#       格式化成 "n (xx.xx%)"，最后 pivot_wider 成一行宽表。
#
# 口径 / 假设：
#   - 这个才是真正的 subject-level 去重计数（区别于 count_subjects_by_var）。
#   - 分母 = df 里 USUBJID 的去重总数（total_patients）。
#   - full_data 参数：若某些类别在当前 df 里没人，但你希望它们仍作为 0 列出现，
#     传 full_data 用它的类别全集。注意此时分子仍来自 df，分母仍是 df 的总数。
#   - 百分比保留 2 位小数。
#   - 原实现里有一堆 cat() 调试打印，已删除。
# ---------------------------------------------------------------------------
counts_patients_per_category <- function(df, sum_vars, full_data = NULL) {
  var <- sum_vars
  stopifnot(is.character(var), length(var) == 1)

  total_patients <- length(unique(df$USUBJID))

  categories <- as.character(unique(df[[var]]))
  if (!is.null(full_data)) {
    categories <- as.character(unique(full_data[[var]]))
  }

  result <- data.frame(row_label = character(0), count_fraction = character(0))

  for (cat_i in categories) {
    cat_patients <- df[df[[var]] == cat_i, "USUBJID", drop = TRUE]
    unique_cat_patients <- length(unique(cat_patients))
    pct <- if (total_patients > 0) (unique_cat_patients / total_patients) * 100 else 0
    formatted <- sprintf("%d (%.2f%%)", unique_cat_patients, pct)
    result <- rbind(result, data.frame(row_label = cat_i, count_fraction = formatted))
  }

  tidyr::pivot_wider(result, names_from = "row_label", values_from = "count_fraction")
}


# ---------------------------------------------------------------------------
# calc_outliers(): 用 1.5*IQR 规则找离群点，返回逗号分隔字符串
#
# 口径 / 假设：
#   - 边界：Q1 - 1.5*IQR 与 Q3 + 1.5*IQR（Tukey 栅栏），分位用 type = 2
#     （SAS 默认的分位数算法，与 R 默认 type = 7 不同——这是为了对齐 SAS）。
#   - 返回字符串（便于直接放进 tooltip/标签）；空则返回 ""。
#   - 不剔除 NA —— 若 x 含 NA，quantile/IQR 会报错，调用前请自行清理。
# ---------------------------------------------------------------------------
calc_outliers <- function(x) {
  ymin <- stats::quantile(x, 0.25, type = 2) - (1.5 * stats::IQR(x))
  ymax <- stats::quantile(x, 0.75, type = 2) + (1.5 * stats::IQR(x))
  outliers <- x[which(x > ymax | x < ymin)]
  paste(outliers, collapse = ", ")
}


# ---------------------------------------------------------------------------
# calc_boxplot_summary(): 箱线图五数概括 + n + mean + 离群点
#
# 口径 / 假设：
#   - 分位数用 type = 2（对齐 SAS，见上）。
#   - n = 去重值个数（dplyr::n_distinct），不是观测数。
#   - outliers 来自 calc_outliers()（字符串），所以返回的整体会被强制成字符向量。
#     若下游要数值，请把 outliers 单独拿出来处理。
# ---------------------------------------------------------------------------
calc_boxplot_summary <- function(x) {
  checkmate::assert_numeric(x)
  quntiles <- stats::quantile(x, probs = c(0.00, 0.25, 0.5, 0.75, 1), type = 2)
  names(quntiles) <- c("ymin", "q1", "middle", "q3", "ymax")
  c(
    n = dplyr::n_distinct(x),
    quntiles,
    mean = mean(x, na.rm = TRUE),
    outliers = calc_outliers(x)
  )
}
