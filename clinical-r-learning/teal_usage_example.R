# =============================================================================
# teal 用法示例（从最小可运行 App 到临床模块 + 自定义模块）
# -----------------------------------------------------------------------------
# teal 是 Roche/NEST 开源的 Shiny 框架，用于交互式探索临床试验数据。
# 核心心智模型：
#   teal::init(data = <teal_data/cdisc_data>, modules = modules(<一个个模块>))
#   -> 返回 app$ui / app$server -> shinyApp(app$ui, app$server)
#
# 依赖（按需安装）：
#   install.packages(c("teal", "teal.data"))
#   # 临床模块与示例数据（NEST 生态，通常从内部/pharmaverse 源安装）：
#   #   teal.modules.clinical, teal.modules.general, tern, random.cdisc.data
#
# 说明：本文件是"可读的教学示例"。示例 1 用 base R 内置数据，无需外网即可跑；
#       示例 2/3 需要 NEST 生态包。示例 4 是源包所用的 R6 封装模式讲解。
# =============================================================================


# -----------------------------------------------------------------------------
# 示例 1：最小可运行 teal App（用内置 iris / mtcars，无需临床包）
# -----------------------------------------------------------------------------
example_1_minimal <- function() {
  library(teal)

  # teal_data() 是新版 teal 装数据的容器（替代老的 cdisc_data 的通用版）。
  # 每个具名参数就是一个数据集，之后在模块里用 dataname 引用。
  data <- teal_data(
    IRIS = iris,
    MTCARS = mtcars
  )

  app <- init(
    data = data,
    modules = modules(
      # teal.modules.general 里最常用的两个通用模块：
      #   看数据表 / 变量总览。这里为了零依赖，先只放一个占位说明模块。
      module(
        label = "说明",
        server = function(id, data) {
          moduleServer(id, function(input, output, session) {
            output$msg <- shiny::renderText("这是一个最小 teal App。左侧是全局过滤面板。")
          })
        },
        ui = function(id) {
          ns <- shiny::NS(id)
          shiny::verbatimTextOutput(ns("msg"))
        },
        # datanames 告诉 teal 这个模块用到哪些数据（驱动过滤面板 & 数据传递）
        datanames = "all"
      )
    )
  )

  # 本地运行：
  shiny::shinyApp(app$ui, app$server)
}


# -----------------------------------------------------------------------------
# 示例 2：CDISC 数据 + join_keys + 现成临床模块
# 这是源包 z_app.R 里的真实写法（cdisc_data + join_keys + modules）。
# -----------------------------------------------------------------------------
example_2_cdisc_clinical <- function() {
  library(teal)
  library(teal.modules.general)
  library(teal.modules.clinical)

  # 标准 NEST 示例数据（ADaM 结构）。若无 random.cdisc.data，可换成你自己的
  # ADSL / ADAE 数据框（列名遵循 CDISC ADaM 规范即可）。
  ADSL <- random.cdisc.data::cadsl
  ADAE <- random.cdisc.data::cadae

  # cdisc_data() 会自动识别 ADSL 为主表；join_keys 声明表间关联键（合并/过滤时用）。
  data <- teal.data::cdisc_data(
    ADSL = ADSL,
    ADAE = ADAE,
    join_keys = teal.data::join_keys(
      teal.data::join_key("ADSL", keys = c("STUDYID", "USUBJID")),
      teal.data::join_key("ADAE", keys = c("STUDYID", "USUBJID", "AESEQ")),
      teal.data::join_key("ADSL", "ADAE", keys = c("STUDYID", "USUBJID"))
    )
  )

  app <- init(
    data = data,
    modules = modules(
      # 首页
      tm_front_page(
        header = "临床数据探索示例",
        tables = list(`研究信息` = data.frame(Study = "DEMO-001", Phase = "II"))
      ),
      # 通用：交互式数据表
      tm_data_table("数据表"),
      # 临床：人口学汇总表（tern 引擎，出的是 rtables 结构，可导出 RTF —— 见 r2rtf 示例）
      tm_t_summary(
        label = "人口学汇总",
        dataname = "ADSL",
        arm_var = choices_selected(c("ARM", "ARMCD"), "ARM"),
        summarize_vars = choices_selected(c("AGE", "SEX", "RACE"), c("AGE", "SEX", "RACE"))
      ),
      # 临床：不良事件汇总
      tm_t_events(
        label = "AE 汇总",
        dataname = "ADAE",
        arm_var = choices_selected(c("ARM", "ARMCD"), "ARM"),
        llt = choices_selected("AEDECOD", "AEDECOD"),
        hlt = choices_selected("AEBODSYS", "AEBODSYS")
      )
    ),
    # 全局过滤面板可预设初始过滤条件
    filter = teal_slices(
      teal_slice(dataname = "ADSL", varname = "SEX")
    )
  )

  shiny::shinyApp(app$ui, app$server)
}


# -----------------------------------------------------------------------------
# 示例 3：自定义 teal 模块（这是源包里每个 tm_g_* / tm_t_* 的底层骨架）
# 一个 teal 模块 = teal::module(label, ui, server, datanames)。
# server 拿到经过全局过滤后的 data，做分析并渲染输出。
# -----------------------------------------------------------------------------
example_3_custom_module <- function() {
  library(teal)

  # 把"造模块"封装成一个函数是标准做法：外部传参（如 dataname、分组变量），
  # 内部返回 teal::module()。源包的表格模块封装就是这么写的。
  tm_my_boxplot <- function(label, dataname, x_var, y_var) {
    module(
      label = label,
      datanames = dataname,

      ui = function(id) {
        ns <- shiny::NS(id)
        teal.widgets::standard_layout(
          output = shiny::plotOutput(ns("plot")),
          encoding = shiny::div(
            shiny::selectInput(ns("x"), "分组变量 (X)", choices = x_var, selected = x_var[1]),
            shiny::selectInput(ns("y"), "数值变量 (Y)", choices = y_var, selected = y_var[1])
          )
        )
      },

      server = function(id, data) {
        moduleServer(id, function(input, output, session) {
          output$plot <- shiny::renderPlot({
            # data() 是 reactive，返回 teal_data 对象；用 [["<dataname>"]] 取具体数据框
            df <- data()[[dataname]]
            ggplot2::ggplot(df, ggplot2::aes(x = .data[[input$x]], y = .data[[input$y]])) +
              ggplot2::geom_boxplot() +
              ggplot2::theme_minimal()
          })
        })
      }
    )
  }

  data <- teal_data(IRIS = iris)
  app <- init(
    data = data,
    modules = modules(
      tm_my_boxplot(
        label = "自定义箱线图",
        dataname = "IRIS",
        x_var = "Species",
        y_var = c("Sepal.Length", "Sepal.Width", "Petal.Length", "Petal.Width")
      )
    )
  )
  shiny::shinyApp(app$ui, app$server)
}


# -----------------------------------------------------------------------------
# 示例 4：源包的 R6 封装模式（讲解，不直接运行）
# -----------------------------------------------------------------------------
# 这个包没有把 teal::init 直接写在 app 里，而是用 R6 类做了两层抽象，
# 目的是"一份引擎跑多个研究"。理解这个结构对读懂整个包很关键：
#
#   Settings 类   —— 负责"配置"：读研究数据、填充下拉框/属性映射
#     - <STUDY>Settings$new(data_list)
#     - $update_settings()   : 设置研究特异的参数选项（见 spec_<STUDY>_app.R）
#     - $update_attributes() : 注册研究特异变量到属性映射
#
#   App 类        —— 负责"组装"：把 teal 模块拼起来
#     - <STUDY>App$new(settings)
#     - $update_modules()    : add/remove/replace 默认模块（见 spec_*_app.R）
#     - 最终内部调用 teal::init(cdisc_data(...), modules(...))
#
#   run_app.R::make_app(study) 是入口：
#     1. 按 STUDY 环境变量拼出 <STUDY>Settings / <STUDY>App 类名
#     2. 读 parquet 数据 -> 实例化 Settings -> 实例化 App -> 初始化模块
#     3. 懒加载模式下先画 Welcome 页，后台加载完再换成完整 teal App
#
# 学习价值：这是把"研究特异性"从"通用引擎"里剥离的经典做法。你做 eSub 工具时，
#           如果要一套代码服务多个 study/indication，可以借鉴这个 R6 继承结构；
#           但注意 spec_*.R 那批文件复制粘贴严重，抽象要抽得比它更彻底。
# =============================================================================
