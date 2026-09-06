# =============================================================================
# 04. 三层配置继承 + 代码 hook 模式（提纯自源包的 config_loader.R）
# -----------------------------------------------------------------------------
# 【思想】
# 把"研究特异性"从代码里彻底剥离到 YAML 配置，用三层继承避免重复：
#     defaults（全局默认） -> therapeutic_area（治療领域） -> study（具体研究）
# 后一层只写它与上一层的**差异**，加载时深合并。这样 100 个研究不用 copy 100 份
# 配置，只维护各自的 delta。
#
# 【三个值得学的细节】
#   1. 深合并用 modifyList(base, override, keep.null=TRUE) —— 只覆盖指定键，
#      其余保留；嵌套 list 递归合并。
#   2. fallback 路径用 purrr::detect(paths, file.exists) —— 给一串候选路径，
#      取第一个存在的，兼容新旧目录结构。
#   3. hook 机制 —— 配置里不仅能放 YAML，还能指向 .R 文件；运行时 source 进来
#      当"研究特异的派生逻辑"。即"把代码也当配置管理"。
#
# 依赖：yaml, purrr, checkmate, cli, tools, utils
#
# 目录约定（config_base 下）：
#   defaults/{data,app}/*.yml
#   therapeutic_areas/<TA>/{data,app}/*.yml
#   studies/<STUDY>/data/1_source.yml   （含 therapeutic_area: <TA>）
#   studies/<STUDY>/data/2_derive_adam.R  （可选 hook）
# =============================================================================


#' 三层加载并合并配置：defaults -> therapeutic_area -> study
load_study_config <- function(study, config_base = "inst/config") {
  checkmate::assert_string(study, min.chars = 1)
  checkmate::assert_string(config_base, min.chars = 1)

  study_dir <- file.path(config_base, "studies", study)
  if (!dir.exists(study_dir)) {
    cli::cli_abort("找不到研究配置：{.path {study_dir}}")
  }

  # study 的 source 配置里声明它属于哪个治療领域
  source_path <- find_config_file(c(
    file.path(study_dir, "data", "1_source.yml"),
    file.path(study_dir, "1_source.yml")
  ))
  if (is.null(source_path)) {
    cli::cli_abort("缺少 source 配置：{.path {study_dir}/data/1_source.yml}")
  }
  study_source <- yaml::read_yaml(source_path)
  therapeutic_area <- study_source$therapeutic_area %||% "default"

  # 逐层加载
  defaults    <- load_tier(config_base, "defaults")
  ta_config   <- load_therapeutic_area(config_base, therapeutic_area)
  study_config <- load_study_tier(study_dir)

  merged <- merge_configs(defaults, ta_config, study_config)
  merged$study <- study
  merged$therapeutic_area <- therapeutic_area
  merged
}


#' 加载治療领域层（缺失则返回空 list，交给继承兜底）
load_therapeutic_area <- function(config_base, therapeutic_area) {
  if (therapeutic_area == "default") return(list())
  ta_path <- file.path("therapeutic_areas", therapeutic_area)
  if (!dir.exists(file.path(config_base, ta_path))) return(list())
  load_tier(config_base, ta_path)
}


#' 加载一层：把该层 data/ 和 app/ 下的所有 yml 读成 named list
load_tier <- function(config_base, tier_path) {
  tier_dir <- file.path(config_base, tier_path)
  if (!dir.exists(tier_dir)) return(list())

  config <- list()
  for (subdir in c("data", "app")) {
    dir_path <- file.path(tier_dir, subdir)
    if (!dir.exists(dir_path)) next
    yml_files <- list.files(dir_path, pattern = "\\.ya?ml$", full.names = TRUE)
    for (yml_file in yml_files) {
      name <- tools::file_path_sans_ext(basename(yml_file))
      config[[name]] <- yaml::read_yaml(yml_file)
    }
  }
  config
}


#' 加载 study 层（含 YAML 配置 + R hook 文件路径）
load_study_tier <- function(study_dir) {
  data_dir <- file.path(study_dir, "data")
  app_dir  <- file.path(study_dir, "app")
  config <- list()

  # 每个配置项给多个候选路径，兼容新旧布局
  yaml_configs <- list(
    data      = c(file.path(data_dir, "1_source.yml"),   file.path(study_dir, "1_source.yml")),
    output    = c(file.path(data_dir, "4_datasets.yml"), file.path(study_dir, "datasets.yml")),
    variables = c(file.path(data_dir, "variables.yml"),  file.path(study_dir, "variables.yml")),
    app       = c(file.path(app_dir,  "1_config.yml"),   file.path(study_dir, "app.yml"))
  )
  for (name in names(yaml_configs)) {
    path <- find_config_file(yaml_configs[[name]])
    if (!is.null(path)) config[[name]] <- yaml::read_yaml(path)
  }

  # hook：把派生 R 脚本路径也纳入配置
  config$hooks <- list(
    adam = find_config_file(c(file.path(data_dir, "2_derive_adam.R"), file.path(study_dir, "2_derive_adam.R"))),
    custom = find_config_file(c(file.path(data_dir, "3_derive_custom.R"), file.path(study_dir, "3_derive_custom.R")))
  )
  config
}


#' 候选路径里取第一个存在的（否则 NULL）
find_config_file <- function(paths) {
  purrr::detect(paths, file.exists)
}


#' 三层合并
merge_configs <- function(defaults, ta, study) {
  merged <- merge_config_tier(defaults, ta)
  merged <- merge_config_tier(merged, study)
  merged
}


#' 深合并两层：同名且都是 list 就递归合并，否则 override 覆盖
merge_config_tier <- function(base, override) {
  for (name in names(override)) {
    both_lists <- is.list(base[[name]]) && is.list(override[[name]])
    if (name %in% names(base) && both_lists) {
      base[[name]] <- utils::modifyList(base[[name]], override[[name]], keep.null = TRUE)
    } else {
      base[[name]] <- override[[name]]
    }
  }
  base
}


#' 加载 hook：把配置里指向的 .R 文件 source 进独立环境，返回其中定义的函数
#' （这里给一个通用实现；原包用的是其内部的 load_hooks）
load_hooks <- function(hook_path) {
  if (is.null(hook_path) || !file.exists(hook_path)) return(list())
  env <- new.env(parent = globalenv())
  sys.source(hook_path, envir = env)
  as.list(env)
}

load_all_hooks <- function(config) {
  list(
    adam = load_hooks(config$hooks$adam),
    custom = load_hooks(config$hooks$custom)
  )
}


`%||%` <- function(x, y) if (is.null(x)) y else x
# =============================================================================
