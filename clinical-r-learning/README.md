# clinical-r-learning —— 从一个 teal 临床数据探索包学到的东西

这个文件夹是本次对话的全部产出：对一个 R Shiny/teal 临床数据探索包的代码学习笔记
+ 提纯出来的可复用代码 + teal / r2rtf 用法示例。

来源是一个基于 teal/Shiny 的临床数据探索类工具包。

## 文件地图

| 文件 | 内容 | 你能拿它干嘛 |
|------|------|--------------|
| `teal_usage_example.R` | teal 用法示例：最小 App → CDISC+临床模块 → 自定义模块 → R6 封装讲解 | 学 teal 怎么搭 |
| `r2rtf_usage_example.R` | 用免费开源的 r2rtf / formatters 生成监管级 RTF TLF | 替代付费 Aspose 的 RTF 生成方案 |
| `01_adam_derivation_helpers.R` | 可复用 ADaM/SDTM 派生函数（日期转换、study day、暴露时长、SUPP 合并、AE 标记、基线标记、CHG/PCHG、disposition、死亡归属、grade 提取） | 直接搬进你自己的 ADaM 项目 |
| `02_label_preservation.R` | 变量 label 保留模式（dplyr 会丢 label 的解法） | 所有 SAS→R 迁移都用得上 |
| `03_lazy_loading_visibility_probe.R` | 懒加载"可见性探针"（元素可见才初始化重模块） | 大型 Shiny 提速的通用技巧 |
| `04_config_3tier_loader.R` | 三层 YAML 配置继承 + R hook 机制 | 一套引擎跑多个研究的配置架构 |
| `05_module_list_helpers.R` | 按 label（而非下标）增删改 teal 模块列表 | teal 模块的稳健增删；通用"语义键操纵结构"思路 |
| `06_summary_stats_helpers.R` | 汇总统计：n(%)（count_percentage）、tern/rtables 单格统计生成器（custom_summary_fn）、中位数 CI、按变量计数、箱线图五数概括+离群点 | 写 CDISC 描述性 TLF 表；`count_percentage`+`custom_summary_fn` 正是"n(%) 怎么写"的答案 |
| `07_label_management.R` | 变量 label 管理：从参考表拷 label、缺失 label 兜底、label 表↔命名向量互转、按映射表重命名列 | 配合 02 用；SAS→R 迁移时管 label 的外围工具 |
| `08_date_imputation.R` | 部分日期插补（impute_day，缺月/日补最早）、从 TS 域取日期（get_ts_date） | ADaM 日期派生常用；配合 01 的日期函数 |
| `09_more_adam_derivations.R` | 更多 ADaM 派生：处置事件/死亡原因/治疗中止标记/处置研究日、访视号规整（UNSCH/EOT/基线访视）、肿瘤 BOR 反应映射 | 直接搬进 ADaM 项目；肿瘤 BOR 两支是领域词典，需按瘤种核对 |
| `10_small_utils.R` | 小工具：round_any、all_na、文本标准化、去连字符、抠 N=值、因子水平折行、纯空白转 NA | 被 01/06/09 反复调用的通用底座 |

## 对源包的总体评价（一句话版）

架构扎实（模块化、配置驱动、懒加载、并行 I/O、测试完整）值得学；但 `spec_*.R`
那 100+ 个研究特异文件是 AI 套模板的重复代码，**别当范本**。整个包重度 AI 生成——若要把
任何部分用进 eSub 提交链路，先过治理审查（硬编码路径、吞异常的 tryCatch 等）。

## 提纯说明

01–05 的代码忠实于原实现，但做了清理：去掉源包内部命名空间引用、去掉函数体里的
`library()`、依赖显式 `pkg::` 限定、报错信息改中文。可直接 `source()` 使用（需装对应依赖包）。

## 已知问题标注

- `add_baseline_flag()`：源包用 tryCatch 把缺列校验的报错吞掉后仍继续执行，缺列不会真正
  中止。**本仓库的提纯版已修复**（改成真正 stop）。
- `add_change_from_baseline_adam()`：源实现"打 label"那段把 AVAL/CHG/PCHG/PARAM/AVISIT 列名
  写死了，与其参数化前缀不完全一致。提纯版用 `any_of` 容错（列不存在就跳过），但如果你的
  列名不同，仍需按注释调整 `rename_mapping` 和那段 label 逻辑。
- `update_bor_values()`（09 文件）：源实现有一行 `!!bor_var %in% "DISEASE PROGRESSION"`，
  其中 `bor_var` 是字符串而非符号，等价于 `"BEST_OVERALL_RESPONSE" %in% "DISEASE PROGRESSION"`，
  **恒为 FALSE**——即"DISEASE PROGRESSION → PD"这条规则在源码里从不生效。**提纯版已修复**
  （改成 `!!rlang::sym(bor_var) %in% ...`）。
- `06/07` 里的 `count_subjects_by_var()` / `update_na_labels()` 等保留了源实现口径，但在注释里
  标了"记录数 vs 去重受试者数""依赖 Hmisc"等提示，搬用前请看每支函数头的"口径/假设"段。

## 未收录（刻意不提纯）

从源包 `utils.R` 的 A 大类里，有两支明确没有收进来，原因写在这，免得你以为漏了：

- `add_disp_cont_flag()`：用 `eval(parse(text = ...))` 拼过滤条件，且把 CRF 厂商类型和大量业务
  字符串写死。既有注入/可维护性问题，又不可移植——典型"别当范本"。要"研究阶段延续标记"请用
  参数化 `grepl` 重写。
- `get_anchor_dates()`：锚点日期的筛选条件全是特定研究的魔法常量（某个固定访视号、某个固定
  访视名、某个固定 DATESTCD 等），毫无通用性。思路（随机化日期 + 兜底日期 `coalesce`）可借鉴，
  实现别照搬。
