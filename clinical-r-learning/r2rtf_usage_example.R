# =============================================================================
# r2rtf 用法示例（免费/开源生成监管级 RTF TLF —— 可替代付费 Aspose）
# -----------------------------------------------------------------------------
# r2rtf 是 Merck 开源、pharmaverse 认可的 R 包，专门把数据框生成符合 eSub
# 要求的 RTF 表格/清单（Tables & Listings）。核心是"管道式"逐层叠加：
#
#   df |>
#     rtf_page(...)       # 页面：纸张/方向/页边距/每页行数
#     rtf_title(...)      # 标题（可多行，含 Title/Subtitle）
#     rtf_colheader(...)  # 列表头（用 "|" 分隔各列；可多层）
#     rtf_body(...)       # 表体：列宽/对齐/边框/分组/分页
#     rtf_footnote(...)   # 脚注
#     rtf_source(...)     # 数据来源行
#   |> rtf_encode() |> write_rtf("output.rtf")
#
# 安装：install.packages("r2rtf")
# 官方文档：https://merck.github.io/r2rtf/
# =============================================================================

library(r2rtf)


# -----------------------------------------------------------------------------
# 示例 1：最小示例 —— 一个数据框直接出 RTF
# -----------------------------------------------------------------------------
example_1_minimal <- function(out = "example1_minimal.rtf") {
  head(iris, 10) |>
    rtf_body() |>          # 用全部默认设置生成表体
    rtf_encode() |>        # 转成 RTF 编码字符串
    write_rtf(out)         # 写文件
  message("已生成: ", normalizePath(out))
}


# -----------------------------------------------------------------------------
# 示例 2：完整的临床汇总表（标题 / 多层列表头 / 列宽 / 对齐 / 脚注 / 来源）
# 这是 TLF 里最典型的形态。
# -----------------------------------------------------------------------------
example_2_full_table <- function(out = "example2_ae_summary.rtf") {
  # r2rtf 自带一个 AE 示例数据集 r2rtf_adae
  ae <- r2rtf::r2rtf_adae

  # 造一个"按 ARM 计数不良事件（按 SOC）"的简单汇总表
  tbl <- table(ae$TRTA, ae$AESOC) |>
    as.data.frame.matrix()
  tbl <- data.frame(SOC = rownames(tbl), tbl, row.names = NULL, check.names = FALSE)

  tbl |>
    rtf_page(
      orientation = "landscape",  # 横向（宽表常用）
      margin = c(1.25, 1.25, 1, 1, 0.5, 0.5),  # 左右上下页眉页脚(英寸)
      nrow = 20                   # 每页最多 20 行数据，自动分页
    ) |>
    rtf_title(
      title = "Table 14.3.1  Adverse Events by System Organ Class",
      subtitle = "Safety Analysis Set",
      text_font_size = 10
    ) |>
    rtf_colheader(
      colheader = paste("System Organ Class",
                        paste(colnames(tbl)[-1], collapse = " | "),
                        sep = " | "),
      # 各列相对宽度（第一列宽，其余等分）
      col_rel_width = c(4, rep(1, ncol(tbl) - 1)),
      text_justification = c("l", rep("c", ncol(tbl) - 1)),
      border_top = "single",
      border_bottom = "single"
    ) |>
    rtf_body(
      col_rel_width = c(4, rep(1, ncol(tbl) - 1)),
      text_justification = c("l", rep("c", ncol(tbl) - 1)),
      border_left = "",
      border_right = ""
    ) |>
    rtf_footnote(
      footnote = c(
        "[1] A subject is counted once within each System Organ Class.",
        "[2] Percentages are based on the number of subjects in the safety population."
      ),
      text_font_size = 8
    ) |>
    rtf_source(
      source = "Program: ae_summary.R | Data cutoff: 2026-08-01",
      text_font_size = 8
    ) |>
    rtf_encode() |>
    write_rtf(out)
  message("已生成: ", normalizePath(out))
}


# -----------------------------------------------------------------------------
# 示例 3：分组 + 分页控制（group_by / page_by）
# 大表按某个分组变量分节、每节可自动换页，这是清单(Listing)常见需求。
# -----------------------------------------------------------------------------
example_3_grouped <- function(out = "example3_grouped.rtf") {
  ae <- r2rtf::r2rtf_adae[1:60, c("USUBJID", "TRTA", "AEDECOD", "AESEV")]

  ae[order(ae$TRTA), ] |>
    rtf_page(nrow = 25) |>
    rtf_title("Listing 16.2.7  Adverse Events by Treatment") |>
    rtf_colheader(
      colheader = "Subject | Treatment | Preferred Term | Severity",
      col_rel_width = c(3, 3, 4, 2)
    ) |>
    rtf_body(
      col_rel_width = c(3, 3, 4, 2),
      text_justification = c("l", "l", "l", "c"),
      # group_by: 同组内重复值只显示一次（如 Treatment 列不重复打印）
      group_by = "TRTA",
      # page_by: 按该变量分页（每个 Treatment 从新页开始）—— 需要该列存在
      page_by = "TRTA"
    ) |>
    rtf_encode() |>
    write_rtf(out)
  message("已生成: ", normalizePath(out))
}


# -----------------------------------------------------------------------------
# 示例 4：从 rtables/tern 表导出 RTF（上面那条链路的正确 RTF 出口）
# -----------------------------------------------------------------------------
# 很多 teal 包都依赖 rtables/tern/formatters。若你已有 tern 建的表，
# 用 formatters::export_as_rtf() 直接落地 RTF —— 不需要 r2rtf。
#
#   library(tern); library(rtables); library(formatters)
#   lyt <- basic_table() |>
#     split_cols_by("ARM") |>
#     add_colcounts() |>
#     analyze_vars("AGE")
#   tbl <- build_table(lyt, DM)            # DM = 你的 ADSL/人口学数据
#   formatters::export_as_rtf(
#     tbl, file = "example4_tern_summary.rtf",
#     page_type = "letter", landscape = FALSE
#   )
#
# 选型建议（针对你替换 Aspose 的目标）：
#   - 已有原始数据、要"从零排版"出 RTF   -> r2rtf（控制力最强，脚注/分页最细）
#   - 已经用 tern/rtables 建了统计表     -> formatters::export_as_rtf（一行落地）
#   - 只是要读/比对已有 RTF 内容          -> r2rtf 不解析 RTF；解析读取用
#                                          striprtf / officer(读 docx) / 正则
# =============================================================================


# 运行全部示例（需已安装 r2rtf）：
# example_1_minimal(); example_2_full_table(); example_3_grouped()
