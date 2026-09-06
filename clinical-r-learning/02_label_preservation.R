# =============================================================================
# 02. 变量 label 保留模式（提纯自源包的 utils.R）
# -----------------------------------------------------------------------------
# 【为什么重要】
# SAS 里变量 label 是天然跟着数据走的。R 里不是：dplyr 的很多操作（mutate、
# summarize、join、across 等）会**丢掉** attr(x, "label")。从 SAS 迁到 R 的人
# 经常一路处理下来发现 label 全没了，导出 RTF/PDF 时列名变成裸变量名。
#
# 【解法】
# 处理前用 store_labels() 存一份 "列名 -> label" 查找表，管道跑完再用
# map_labels() 把 label 贴回去。这是一个非常实用、可以套进任何 SAS→R 流程的模式。
#
# 依赖：dplyr, tibble, purrr
# =============================================================================


# -----------------------------------------------------------------------------
# store_labels(): 抽取一个数据框里所有变量的 label，存成查找表
# 没有 label 的列，label 回退为列名本身（保证贴回时不会变 NA）。
# -----------------------------------------------------------------------------
store_labels <- function(df) {
  lbl_df <- tibble::tibble(
    col_name = names(df),
    labels = purrr::map_chr(df, ~ if (!is.null(attr(.x, "label"))) attr(.x, "label") else NA_character_)
  )
  # 提示哪些列没有 label（便于发现上游 label 缺失）
  missing <- lbl_df$col_name[is.na(lbl_df$labels)]
  if (length(missing)) {
    message("以下变量没有 label：", paste(missing, collapse = ", "))
  }
  dplyr::mutate(lbl_df, labels = ifelse(is.na(labels), col_name, labels))
}


# -----------------------------------------------------------------------------
# map_labels(): 把查找表里的 label 贴回数据框
# 只处理 df 里存在的列；查找表里多出来的列忽略，df 里没被记录的列保持原样。
# -----------------------------------------------------------------------------
map_labels <- function(df, lkup) {
  for (i in seq_along(lkup$col_name)) {
    if (lkup$col_name[i] %in% names(df)) {
      attr(df[[lkup$col_name[i]]], "label") <- lkup$labels[i]
    }
  }
  df
}


# -----------------------------------------------------------------------------
# lbl(): 给单个变量就地打 label（小工具）
# -----------------------------------------------------------------------------
lbl <- function(var, label) structure(var, label = label)


# -----------------------------------------------------------------------------
# 用法示例
# -----------------------------------------------------------------------------
if (FALSE) {
  library(dplyr)

  adsl <- tibble::tibble(USUBJID = c("001", "002"), AGE = c(45, 60))
  attr(adsl$AGE, "label") <- "Age (years)"

  # 1) 处理前先存 label
  labels <- store_labels(adsl)

  # 2) 一通 dplyr 操作后 label 丢了
  adsl2 <- adsl |>
    mutate(AGEGR = ifelse(AGE >= 65, ">=65", "<65")) |>
    filter(AGE > 40)
  attr(adsl2$AGE, "label")  # NULL —— 被丢了

  # 3) 贴回来
  adsl2 <- map_labels(adsl2, labels)
  attr(adsl2$AGE, "label")  # "Age (years)" —— 回来了

  # 新派生的列（如 AGEGR）不在查找表里，可用 lbl() 单独补：
  adsl2$AGEGR <- lbl(adsl2$AGEGR, "Age Group")
}

# 提示：也可以考虑 labelled 包（set_variable_labels / var_label）或 gtsummary 生态，
#       但 store/map 这套的好处是零额外依赖、透明、易调试。
# =============================================================================
