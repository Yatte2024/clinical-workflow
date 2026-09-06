# =============================================================================
# 03. 懒加载"可见性探针"模式（提纯自源包的 lazy_teal_modules.R）
# -----------------------------------------------------------------------------
# 【解决什么问题】
# 大型 Shiny/teal App 如果启动时就把每个 tab、每张图、每个表都建好，首屏会非常慢，
# 内存也爆。理想做法是"按需初始化"：只有当用户真的切到某个 tab、那块内容真的出现在
# 屏幕上时，才去做那个模块的重活。
#
# 【核心技巧】
# 往前端注入一段 JS，用浏览器原生的 IntersectionObserver 监听目标元素是否"可见"，
# 一旦可见就通过 Shiny.setInputValue() 回传一个事件给后端，后端收到才开始初始化。
# 配合 measure_initialisation() 记录每个模块的耗时/内存增量，便于做性能分析。
#
# 依赖：shiny；测内存建议装 lobstr（否则回退 NA）
# =============================================================================


# -----------------------------------------------------------------------------
# mem_used_mb(): 当前 R 进程内存占用（MB）。lobstr 不可用时返回 NA。
# -----------------------------------------------------------------------------
mem_used_mb <- function() {
  if (requireNamespace("lobstr", quietly = TRUE)) {
    as.numeric(lobstr::mem_used()) / 1024^2
  } else {
    NA_real_
  }
}


# -----------------------------------------------------------------------------
# measure_initialisation(): 包住一段表达式，返回结果 + 耗时(秒) + 内存增量(MB)
# 关键：用 force(expr) 强制在这里求值（惰性求值下不 force 就测不到真实耗时）。
# -----------------------------------------------------------------------------
measure_initialisation <- function(expr) {
  started_at <- Sys.time()
  mem_before <- mem_used_mb()

  value <- force(expr)  # 强制求值，否则 promise 不会在此执行

  list(
    value = value,
    elapsed_secs = as.numeric(difftime(Sys.time(), started_at, units = "secs")),
    mem_delta_mb = mem_used_mb() - mem_before
  )
}


# -----------------------------------------------------------------------------
# lazy_visibility_probe(): 生成一段前端 JS，元素首次可见时通知后端
# 三重保险：IntersectionObserver（滚入视口）+ bootstrap 的 shown.bs.tab 事件
#          （切 tab）+ 400ms 轮询兜底。只发一次（sent 标志位去抖）。
#
# @param ns  Shiny 模块的 NS() 命名空间函数
# 约定：UI 里要有一个 id = ns("root") 的容器；后端监听 input[[ns_id("activate")]]。
# -----------------------------------------------------------------------------
lazy_visibility_probe <- function(ns) {
  shiny::tags$script(shiny::HTML(sprintf(
    "
    (function() {
      const rootId = '%s';
      const inputId = '%s';
      let sent = false;

      function isVisible(el) {
        if (!el) return false;
        const style = window.getComputedStyle(el);
        return (
          style.display !== 'none' &&
          style.visibility !== 'hidden' &&
          el.getClientRects().length > 0 &&
          el.offsetParent !== null
        );
      }

      function notify() {
        if (sent || !window.Shiny) return;
        const el = document.getElementById(rootId);
        if (!isVisible(el)) return;
        sent = true;
        Shiny.setInputValue(inputId, Date.now(), { priority: 'event' });
      }

      function boot() {
        const el = document.getElementById(rootId);
        if (!el) { setTimeout(boot, 100); return; }

        notify();

        const io = new IntersectionObserver(function(entries) {
          entries.forEach(function(entry) { if (entry.isIntersecting) notify(); });
        }, { threshold: 0.05 });
        io.observe(el);

        document.addEventListener('shown.bs.tab', notify, true);

        const poll = setInterval(function() {
          if (sent) { clearInterval(poll); } else { notify(); }
        }, 400);
      }

      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', boot, { once: true });
      } else {
        boot();
      }
    })();
    ",
    ns("root"),
    ns("activate")
  )))
}


# -----------------------------------------------------------------------------
# 用法骨架：一个"点到才初始化"的 Shiny 模块
# -----------------------------------------------------------------------------
if (FALSE) {
  library(shiny)

  lazy_module_ui <- function(id) {
    ns <- NS(id)
    tagList(
      lazy_visibility_probe(ns),                 # 注入探针
      div(id = ns("root"),                       # 探针监听的容器
          uiOutput(ns("content")))
    )
  }

  lazy_module_server <- function(id, heavy_builder) {
    moduleServer(id, function(input, output, session) {
      initialised <- reactiveVal(FALSE)

      # 只有前端回传 activate 事件（元素可见）才干重活，且只干一次
      observeEvent(input$activate, once = TRUE, {
        m <- measure_initialisation(heavy_builder())
        message(sprintf("模块初始化：%.2fs，内存 +%.1fMB", m$elapsed_secs, m$mem_delta_mb))
        output$content <- renderUI(m$value)
        initialised(TRUE)
      })
    })
  }
}

# 迁移到 teal：源包在此基础上还做了"先画 Welcome 壳、后台进程加载完再 swap
# 成完整 teal App"（见其 run_app.R 的 make_app_shell）。核心思想一样：延迟重活。
# =============================================================================
