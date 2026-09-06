# 08_date_imputation.R
# ============================================================================
# 日期插补 / TS 参数取日期（A3 类）
#
# 这一组配合 01_adam_derivation_helpers.R 里的日期函数使用。
#
# 依赖：dplyr、checkmate。impute_day() 用到 %!in%（见 01 文件），先 source 01。
#
# 关于 get_anchor_dates()（原包同类第三支）为何未收录：
#   源实现把锚点日期的筛选条件写死了（形如某个固定 VISITNUM、某个固定访视名、
#   某个固定 DATESTCD、DSDECOD == "RANDOMIZED"…），是特定研究的
#   硬编码，不具通用性，属于"别当范本"的那类。若你要类似"随机化日期 + 兜底日期
#   coalesce"的逻辑，自己按研究定义参数化即可，不要照搬那些魔法常量。
# ============================================================================


# ---------------------------------------------------------------------------
# impute_day(): 只有年/年月的部分日期，补成该月/该年第一天
#
# 手段：按字符长度判断精度：
#   - 长度 < 5（形如 "2024"）→ 补 "-01-01"
#   - 长度 < 10（形如 "2024-03"）→ 补 "-01"
#   - 其余（已是完整 "YYYY-MM-DD"）→ 原样
#
# 口径 / 假设：
#   - 这是"最早日期"插补口径（缺月补 1 月、缺日补 1 号），符合很多 ADaM 里
#     "起始日期用最早、结束日期用最晚"的惯例——但本函数只做最早向。若你要
#     结束日期补该月最后一天，需另写逻辑。
#   - 输入按字符处理；空串 "" / " " / NA 不动。
#   - 用 nchar 判精度是启发式：假设输入是规范的 ISO 8601 部分日期
#     （YYYY / YYYY-MM / YYYY-MM-DD）。非规范格式（如 "3/2024"）不适用。
#   - 返回字符向量，不自动转 Date（下游自行 as.Date）。
# ---------------------------------------------------------------------------
impute_day <- function(date_var) {
  dplyr::case_when(
    !is.na(as.character(date_var)) & as.character(date_var) %!in% c("", " ") &
      nchar(as.character(date_var)) < 5  ~ paste0(as.character(date_var), "-01-01"),
    !is.na(as.character(date_var)) & as.character(date_var) %!in% c("", " ") &
      nchar(as.character(date_var)) < 10 ~ paste0(as.character(date_var), "-01"),
    TRUE ~ as.character(date_var)
  )
}


# ---------------------------------------------------------------------------
# get_ts_date(): 从 TS（Trial Summary）域按参数码取一个日期
#
# 手段：在 TS 里按 TSPARMCD 过滤，取非空 TSVAL 的去重值，as.Date() 返回。
#       例：get_ts_date(ts, "DCUTDTC") 取数据切点日期。
#
# 口径 / 假设：
#   - 返回 Date 向量。正常情况下 TS 里一个参数码只有一个值 → 返回长度 1；
#     但若该参数有多个不同 TSVAL，会返回多个——调用方要自己保证唯一性。
#   - 空值（""/NA）会被过滤掉。
#   - 出错（如 TSVAL 不是合法日期）时返回 NULL 并打印 message，不会中断流程。
#     这是"宽容失败"设计；若你希望缺关键日期就报错停下，把 tryCatch 去掉。
# ---------------------------------------------------------------------------
get_ts_date <- function(ts, tsparmcd) {
  tsparmcd <- as.character(tsparmcd)

  tryCatch(
    {
      checkmate::assert_data_frame(ts)
      ts |>
        dplyr::filter(.data[["TSPARMCD"]] %in% tsparmcd) |>
        dplyr::mutate(TSVAL = as.character(.data[["TSVAL"]])) |>
        dplyr::filter(!(.data[["TSVAL"]] == "" | is.na(.data[["TSVAL"]]))) |>
        dplyr::pull(.data[["TSVAL"]]) |>
        unique() |>
        as.Date()
    },
    error = function(cond) {
      message(conditionMessage(cond))
      NULL
    }
  )
}
