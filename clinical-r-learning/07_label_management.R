# 07_label_management.R
# ============================================================================
# 变量 label 管理（A2 类）
#
# 这一组配合 02_label_preservation.R 使用。02 解决"dplyr 操作丢 label"，
# 这里解决更外围的问题：
#   - 从参考数据框拷 label 过来（SAS→R 迁移常见）
#   - 给没 label 的列补 label（用列名兜底）
#   - label 表（col_name/labels 两列的 data.frame）与命名向量互转
#   - 用 label 表重命名列
#
# 依赖：dplyr、formatters（var_labels）、purrr、stats、checkmate、Hmisc（可选）
# 注：apply_missing_labels() 依赖同项目 02 里的 lbl()；先 source 02 再 source 本文件。
# ============================================================================


# ---------------------------------------------------------------------------
# update_lbls_frm_df(): 从参考数据框按列名拷贝 label 到目标数据框
#
# 手段：按名字对齐两个 df 的列，用 formatters::var_labels() 取参考 label，
#       逐列写回 attr(x, "label")，并把类加上 "labelled"。同时顺手把"看起来
#       是整数的 double 列"降型成 integer（省内存，模仿 Hmisc::upData 的行为）。
#
# 口径 / 假设：
#   - 按"列名匹配"，不是按位置。base_df 里没有的列，label 会变成 NA（unname 后）。
#   - 降型判断：非 Date/POSIX、非矩阵、且所有值都是整数且不超过 .Machine 整型
#     上限（2^31-1）时才降 integer；全 NA 的 double 也降 integer。
#   - 原实现刻意避开了 Hmisc::upData（少一个依赖），这里保留该做法。
# ---------------------------------------------------------------------------
update_lbls_frm_df <- function(df, base_df) {
  matches <- match(names(df), names(base_df))
  df_labels <- formatters::var_labels(base_df[matches])

  for (i in seq_along(df)) {
    x <- df[[i]]
    if (is.double(x) && !inherits(x, c("Date", "POSIXct", "POSIXt")) && !is.matrix(x)) {
      if (all(is.na(x))) {
        storage.mode(x) <- "integer"
      } else if (!any(floor(x) != x, na.rm = TRUE) &&
                 max(abs(x), na.rm = TRUE) <= (2^31 - 1)) {
        storage.mode(x) <- "integer"
      }
    }
    attr(x, "label") <- unname(df_labels[[i]])
    if (!inherits(x, "labelled")) {
      class(x) <- c("labelled", class(x))
    }
    df[[i]] <- x
  }
  df
}


# ---------------------------------------------------------------------------
# update_na_labels(): 缺失的 label 用列名兜底
#
# 口径 / 假设：
#   - 只处理 label 为 NA 的列，用变量名本身作为 label。
#   - 依赖 Hmisc::upData。若不想引入 Hmisc，可改成逐列 attr()<- 写回
#     （参考 update_lbls_frm_df 的写法）。见下方 apply_missing_labels() 的无 Hmisc 版本。
# ---------------------------------------------------------------------------
update_na_labels <- function(df) {
  df_labels <- formatters::var_labels(df)
  df_labels[which(is.na(df_labels))] <- names(df_labels[which(is.na(df_labels))])
  Hmisc::upData(df, labels = df_labels)
}


# ---------------------------------------------------------------------------
# apply_missing_labels(): 给"无 label"的列补上列名作为 label（不依赖 Hmisc）
#
# 手段：找出 label 为 NULL/""/NA 的列，用 lbl(.x, cur_column()) 打上列名。
#
# 口径 / 假设：
#   - 与 update_na_labels() 目的相同，但判定更严（NULL、空串、NA 都算缺失），
#     且走同项目的 lbl()（见 02_label_preservation.R），不引入 Hmisc。
#   - 已有 label 的列一律不动。
# ---------------------------------------------------------------------------
apply_missing_labels <- function(data) {
  checkmate::assert_data_frame(data)

  unlabeled_cols <- names(data)[vapply(names(data), function(col) {
    label_attr <- attr(data[[col]], "label")
    is.null(label_attr) || label_attr == "" || is.na(label_attr)
  }, logical(1))]

  if (length(unlabeled_cols) > 0) {
    data <- data |>
      dplyr::mutate(
        dplyr::across(dplyr::all_of(unlabeled_cols), ~ lbl(.x, dplyr::cur_column()))
      )
  }
  data
}


# ---------------------------------------------------------------------------
# update_column_labels(): 用映射表重命名列（col_name -> labels）
#
# 手段：给一个含 col_name / labels 两列的映射表，把 df 里能匹配到的列名替换成
#       对应 label。做了去重（同一 col_name 多行时取第一个非 NA 的 label）与
#       缺失兜底（label 为 NA 时保持原列名）。
#
# 口径 / 假设：
#   - 这是"改列名"（names(df) <-），不是"打 label 属性"。想打属性用上面几支。
#   - mapping 必须含 col_name、labels 两列（checkmate 会校验）。
#   - col_name 为 NA 的行会被丢弃；映射表为空则原样返回。
# ---------------------------------------------------------------------------
update_column_labels <- function(df, mapping) {
  checkmate::assert_data_frame(df)
  checkmate::assert_data_frame(mapping)
  checkmate::assert_names(names(mapping), must.include = c("col_name", "labels"))

  mapping <- mapping[!is.na(mapping$col_name), , drop = FALSE]
  if (nrow(mapping) == 0L) return(df)

  # 同一 col_name 去重，优先保留第一个非 NA 的 label
  mapping_unique <- stats::aggregate(
    labels ~ col_name,
    data = mapping,
    FUN = function(x) {
      non_na <- x[!is.na(x)]
      if (length(non_na) > 0L) head(non_na, 1L) else head(x, 1L)
    }
  )
  name_map <- stats::setNames(mapping_unique$labels, mapping_unique$col_name)

  new_names <- purrr::map_chr(
    names(df),
    ~ {
      if (.x %in% names(name_map)) {
        new_name <- name_map[[.x]]
        if (!is.na(new_name)) as.character(new_name) else .x
      } else {
        .x
      }
    }
  )
  names(df) <- new_names
  df
}


# ---------------------------------------------------------------------------
# col_labels_to_named_vector(): label 表 -> 命名字符向量
#
# 口径 / 假设：
#   - 输入是含 col_name / labels 两列的 df，输出 setNames(labels, col_name)。
#   - 纯转换，无副作用；常与 update_column_labels() / formatters::var_labels()<- 搭配。
# ---------------------------------------------------------------------------
col_labels_to_named_vector <- function(df) {
  checkmate::assert_data_frame(df)
  checkmate::assert_names(names(df), must.include = c("col_name", "labels"))
  stats::setNames(as.character(df$labels), as.character(df$col_name))
}
