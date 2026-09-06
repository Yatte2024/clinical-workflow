# =============================================================================
# 05. 按 label 操纵 teal 模块列表的小 API（提纯自源包的 utils.R）
# -----------------------------------------------------------------------------
# 【思想】
# teal App 的 modules 是一个树状列表（teal_modules 里套 teal_module）。要做"研究
# 特异的增删改"时，用**下标**（modules[[3]]）很脆——一旦 tab 顺序变了就错位。
# 更稳的做法是**按 label 定位**再增删改。这组小函数就是干这个的，设计干净，值得学
# 它"用语义键而非位置索引操纵结构"的思路（不限于 teal）。
#
# 依赖：checkmate；运行需 teal（teal_modules / teal_module 类）
# =============================================================================


# -----------------------------------------------------------------------------
# append_module(): 往一个 teal_modules（tab 组）里追加一个子模块
# 追加后重算 children 的 name（清洗成合法名 + make.unique 去重），保持结构一致。
# -----------------------------------------------------------------------------
append_module <- function(modules, module) {
  checkmate::assert_class(modules, "teal_modules")
  checkmate::assert_class(module, "teal_module")

  modules$children <- c(modules$children, list(module))
  labels <- vapply(modules$children, function(submodule) submodule$label, character(1))
  names(modules$children) <- make.unique(gsub("[^[:alnum:]]", "_", tolower(labels)), sep = "_")
  modules
}


# -----------------------------------------------------------------------------
# find_module_index_by_label(): 在顶层列表里按 label 找到某个 tab 组的下标
# 找不到时报错并列出所有可用 label（好的报错信息 = 好的开发体验）。
# -----------------------------------------------------------------------------
find_module_index_by_label <- function(modules_list, label) {
  checkmate::assert_list(modules_list)
  checkmate::assert_string(label)

  for (i in seq_along(modules_list)) {
    m <- modules_list[[i]]
    if (inherits(m, "teal_modules") && identical(m$label, label)) return(i)
  }
  available <- vapply(modules_list, function(m) if (inherits(m, "teal_modules")) m$label else NA_character_, character(1))
  available <- available[!is.na(available)]
  stop(sprintf("没有 label 为 '%s' 的模块组。可用：%s", label, paste(available, collapse = ", ")))
}


# -----------------------------------------------------------------------------
# append_module_by_label(): 往"指定 label 的 tab 组"里追加子模块
# -----------------------------------------------------------------------------
append_module_by_label <- function(modules_list, label, module) {
  checkmate::assert_list(modules_list)
  checkmate::assert_string(label)
  checkmate::assert_class(module, "teal_module")

  idx <- find_module_index_by_label(modules_list, label)
  modules_list[[idx]] <- append_module(modules_list[[idx]], module)
  modules_list
}


# -----------------------------------------------------------------------------
# replace_module_by_label(): 用新模块替换掉指定 label 位置的模块组
# -----------------------------------------------------------------------------
replace_module_by_label <- function(modules_list, label, new_module) {
  idx <- find_module_index_by_label(modules_list, label)
  modules_list[[idx]] <- new_module
  modules_list
}


# -----------------------------------------------------------------------------
# insert_module_after_label(): 在指定 label 之后插入一个新模块（新增 tab 常用）
# -----------------------------------------------------------------------------
insert_module_after_label <- function(modules_list, after_label, new_module) {
  idx <- find_module_index_by_label(modules_list, after_label)
  if (idx == length(modules_list)) {
    modules_list <- c(modules_list, list(new_module))
  } else {
    modules_list <- c(
      modules_list[1:idx],
      list(new_module),
      modules_list[(idx + 1):length(modules_list)]
    )
  }
  modules_list
}


# -----------------------------------------------------------------------------
# 用法示意（源包的 spec_*_app.R 就靠这个做研究特异的模块增删）
# -----------------------------------------------------------------------------
if (FALSE) {
  # self$modules 是传给 teal::init(modules = ...) 之前的模块列表
  self$modules <- append_module_by_label(
    self$modules,
    "Exploratory",                                  # 目标 tab 组的 label
    tm_g_patient_profile2(label = "Patient Profile")
  )

  self$modules <- insert_module_after_label(
    self$modules, "Safety",
    tm_t_events(label = "New AE Table", dataname = "ADAE")
  )
}
# =============================================================================
