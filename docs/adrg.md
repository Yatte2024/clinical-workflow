# eSub Composer — ADRG 生成规则规格书

> 目的:把工具里**只有业务专家才懂**的规则提纯成可读、可审阅、可复用的资产。这份文档独立成篇——不依赖任何源码,只看它就能理解工具每一块内容"从哪来、怎么算出来、哪里会出错"。
>
> 组织方式:以 **ADRG 文档本身**为主线,每个章节回答三件事——**是 ADRG 的哪一部分 / 输入是什么 / 生成逻辑是什么**,外加**哪里会静默失败**(⚠️ = 出错但不报错、不告警,风险最高)。
> 深层机器处理(宏解析、执行顺序、依赖图算法)下沉到[第二部分·算表机制]。

---

## 总览:ADRG Builder 在做什么

**它不新建 ADRG,而是在你上传的 P21E ADRG 模板(Word 文档)上原地填空**——工具直接改 Word 文档内部结构,把表格和内容插进去,所以模板原有的样式、页眉页脚、目录、套话全部保留,只有原本空着的表和章节被填上。

工具填的内容分两类:
- **机器算出来的表**(4.2、5.2.x、7.1/7.2/7.3、8-DLKA):从真实程序日志 / ADaM spec 算出,自动化收益最大、最不易错——这是工具真正的 payload。
- **从文档抽取转录的叙述**(2.1、2.2、3.1、3.5):从 SAP / spec 里定位并搬运,强依赖源文档格式规整。

分工:P21E 已从 `define.xml` 填好 CDISC 标准骨架和变量级元数据;本工具补的是 P21E 不可能知道的东西——程序↔数据集↔宏的可追溯性、数据集依赖结构、SAP 里的研究设计与插补规则。

### 本工具填充的 ADRG 章节一览

| ADRG 章节 | 填什么 | 输入 | 类型 |
|---|---|---|---|
| 2.1 修订史 | protocol amendments 表 | SAP(Word) | 抽取 |
| 2.2 研究设计 | study design 叙述 | SAP(Word) | 抽取 |
| 3.1 核心变量 | core variables 表 | ADaM Spec(Excel) | 算表 |
| 3.5 偏日期插补 | partial date imputation 规则 | SAP(Word) | 抽取 |
| 4.2 依赖图 | ADaM 数据集依赖图 | Dependency Diagram 标签页(源自 ADaM 日志) | 算表 |
| 5.2.x 参数/分类表 | PARAMCD / PARCATn 取值表 | ADaM Spec(Excel) | 算表 |
| 7.1 ADaM 程序清单 | ADaM 程序表 | ADaM Programs 标签页(日志 + 宏库) | 算表 |
| 7.2 Output 程序清单 | Output 程序表 | Output Programs 标签页(日志 + DPP Excel) | 算表 |
| 7.3 唯一宏清单 | 去重宏表 | Macro Programs 标签页(两侧合并) | 算表 |
| 8 附录(含 DLKA) | 附录表 + Date Last Known Alive | ADaM Spec(Excel) | 算表 |

---

# 第一部分:逐章节生成规则

---

## ADRG 2.1 — 修订史(Protocol Amendments)

**输入**:SAP(Word 文档)。里面应含一张"协议修订史"表格。

**生成逻辑**:
1. 遍历 SAP 里的**所有表格**。
2. 对每张表看**表头行**:表头单元格文字里必须**同时**出现三个词组(大小写不敏感)——`document`、`date of issue`、`summary of change`,且该表至少 3 列。命中即认定为"修订史表"。
3. 记住这三个词组分别落在第几列。
4. 从表头行往下,逐行按这三列的列号抽出 `{文档号, 签发日期, 变更摘要}` 一条条记录。
5. 若有**多张**表都命中表头条件:**优先选**表格附近文字里出现 `protocol amendment` 的那张;都没有则取第一张命中的。
6. 抽出的记录填入 ADRG 2.1 的修订史表。

⚠️ **脆弱点**:全靠三个**英文表头字段名**加 `protocol amendment` 关键字来定位。SAP 换模板、表头改措辞(哪怕改成 "Date Issued")就整表抽不到——而且不报错,ADRG 2.1 直接空着。

---

## ADRG 2.2 — 研究设计(Study Design)

**输入**:SAP(Word 文档)。研究设计叙述所在的那一(几)节。

**生成逻辑**:
1. **按标题定位章节**:扫描所有用了 Word 标准标题样式(Heading 1~9)的段落;把标题文字做归一(去空格、统一大小写)后,匹配到目标章节名。
2. 从该标题开始,**一直收集到下一个同级或更高级标题为止**,这中间的内容就是本节正文。
3. 收集时按段落样式分别识别并处理:
   - **内嵌图**:段落里含图形对象的,顺着 Word 文档的图片关联关系找到真正的图片文件,抽出来插进 ADRG。
   - **图注**:样式名为 `BMSFigureCaption` 的段落 → 当作图的标题。
   - **项目符号**:样式名为 `BMSBullets` 的段落 → 当作 bullet 列表项,保留层级。
   - **样式为 `BMSTableInfo` 的表格 → 跳过**(不搬)。
4. 把正文(含图、图注、bullet)填入 ADRG 2.2。


---

## ADRG 3.1 — 核心变量(Core Variables)

**输入**:ADaM Spec(Excel),读其中名为 **Variable Metadata** 的 sheet(sheet 名大小写不敏感)。

**生成逻辑**:
1. 逐行读 Variable Metadata。
2. 取该行 **A 列**,去掉所有非字母字符后转大写;若结果 **== `ALL`**,则这一行是一个"核心变量"(表示该变量适用于所有数据集)。否则跳过。
3. 变量名取 **D 列**,变量说明取 **F 列**。
4. 按变量名(大写)去重。
5. 汇总成核心变量表填入 ADRG 3.1。

⚠️ **脆弱点**:**列位置是写死的(A / D / F),按位置取值,不认表头名。** ADaM spec 模板一旦调整列顺序,取到的就是错列的值,而且不会报错。

**待补 Why**:"A 列 == ALL 即核心变量"背后对应的是哪份 ADaM spec 填写约定?请补出处便于验证追溯。

---

## ADRG 3.5 — 偏日期插补(Partial Date Imputation)

**输入**:SAP(Word 文档)。

**生成逻辑**:
1. 找标题文字归一后 **== `partialdateimputation`** 的标题(Heading),从它收集到同级或更高级标题为止。
2. **兜底**:若没找到该标题,则找一个**以 "All conventions for imputing partial…" 开头**的段落作为起点。
3. 保留其中的项目符号层级和编号符号,原样搬进 ADRG 3.5。

⚠️ **脆弱点**:靠固定标题文字或固定开头句定位。SAP 里这段的标题/首句措辞一变就抽不到。

---

## ADRG 4.2 — 数据集依赖图

**输入**:Dependency Diagram 标签页生成的图(该图由 ADaM 程序的输入/输出关系构建,见[第二部分·M6])。

**生成逻辑**:把 Dependency Diagram 标签页里已经画好的依赖图,重置成全尺寸、紧裁边距后,作为图片插入 ADRG 4.2。构图规则详见 M6。

⚠️ **脆弱点**(来自 M6):图里有**两个写死的结构节点** `ADCORE`(强制置顶)、`ADSL`(强制置底、不可删),以及一个**写死的合并组** `ADLB/ADZL/ADLC`(三者合并显示成一个节点)。换一个数据集结构不同的研究,这些硬编码可能就不成立。

---

## ADRG 5.2.x — 参数 / 受控术语表

**输入**:ADaM Spec(Excel),读 **Variable Metadata** sheet。

**生成逻辑**:
1. 逐行读:**A 列 = 数据集名**,**D 列 = 变量名**,**K 列 = 术语/取值(decode)内容**。
2. 看变量名(D 列)判定它属于哪一类,只处理两类,其余变量跳过:
   - **PARAMCD 类**:参数编码变量。编码列用 `PARAMCD`,对应的解码/说明列用 `Parameters`。
   - **PARCATn 类**:参数分类变量(PARCAT1/PARCAT2…)。用**变量名本身**当编码列。
3. 按数据集分组产出取值表;同一数据集里 **PARAMCD 表排在最前**。
4. 填入 ADRG 5.2 下对应的各小节。

⚠️ **脆弱点**:列位置写死 A / D / K;且只认名字符合 PARAMCD / PARCATn 规律的变量,别的命名一律不收。

**待补 Why**:只认 PARAMCD/PARCATn 的判定,对应哪份 spec 约定?

---

## ADRG 7.1 — ADaM 程序清单

**输入**:ADaM Programs 标签页 = 一批 ADaM 程序的 SAS 日志文件(`.log`)+ 已在第 1 步加载好的宏库。

**生成逻辑**:对每个日志,抽出一行程序记录,含七个字段——**程序名、输出数据集、说明(label)、输入数据集、直接调用的宏、子宏、执行顺序**。每个字段的详细抽取规则见[第二部分·M2~M5]。汇总成 ADaM 程序表填入 ADRG 7.1。

⚠️ **脆弱点**:
- 识别输入数据集时,**只认库前缀 `sdtm` / `adam` / `misc`**;用别的库名(如 raw/crf/derive)的输入会被漏掉。
- 子宏解析**要求宏库先加载且解析完整**;宏库缺失或没加载全,子宏会被静默漏掉、不报错。

---

## ADRG 7.2 — Output 程序清单

**输入**:Output Programs 标签页 = DPP Tool 的 Excel(输出清单)+ 一批 Output 程序的 SAS 日志。

**生成逻辑**:
1. **先读 DPP Excel 定"本次提交要进 ADRG 的 output 全集"**:只保留 Excel 里 `ADRG` 列标为 `Y` 的行(详见 M7)。
2. 扫日志找出实际产出的 output。
3. 以 **DPP Excel 清单为准**,用文件名主干(stem)精确匹配日志里扫到的 output(无模糊匹配)。分成三态:两边都有 / Excel 有但日志没有 / 日志有但 Excel 没有。
4. 表号(Table No.)和标题(Title)**以 DPP Excel 为准**,覆盖从日志里解析到的值。
5. 汇总成 Output 程序表填入 ADRG 7.2。

⚠️ **脆弱点**:
- 完全绑定 DPP Tool 模板:sheet 名、列名、`ADRG=Y` 标记都写死,模板一改就崩(这是整个 Output 分析的命门)。
- 文件名**以 `rl-` 开头的日志会被直接跳过**;若正式程序用了这个前缀就会被漏掉。

---

## ADRG 7.3 — 唯一宏清单

**输入**:Macro Programs 标签页 = ADaM 侧扫出的宏清单 + Output 侧扫出的宏清单。

**生成逻辑**:把两侧的宏合并、去重,**重名时保留带 purpose(用途说明)的那条**。宏怎么从程序里识别、子宏怎么递归展开,见[第二部分·M3~M4]。汇总成唯一宏清单填入 ADRG 7.3。

---

## ADRG 8 — 附录(含 DLKA)

**输入**:ADaM Spec(Excel),读两个 sheet:**For Reviewer's Guide**(附录内容)、**Date Last Known Alive**(DLKA 表)。

**生成逻辑**:

*附录(For Reviewer's Guide sheet)*:
1. 逐行看 **D 列**,只有 D 列**以 `Appendix <编号>` 开头**(编号可为罗马数字或阿拉伯数字)的行才收。
2. 从 D 列文字里去掉 `(part N of M)` 这种分段标记得到附录标题,并取出段号 N(默认 1)。
3. 其余列:**A 列 = 数据集**,**B 列 = 变量/参数**,**C 列 = 描述**。
4. 按 `编号‖数据集‖变量` 分组;同一附录若被拆成多 part,按 part 号顺序合并。
5. 每个附录标题 = `编号: 数据集.变量`。

*DLKA(Date Last Known Alive sheet)*:逐行取 **A / B / C / D 四列**为一行,整行全空则跳过。

⚠️ **脆弱点**:两个 sheet 名、附录的 `Appendix` 开头正则、以及所有列位置(A/B/C/D)都写死。

---

# 第二部分:算表机制细节

> 4.2 与 7.1/7.2/7.3 背后"机器怎么从日志/宏库/DPP 算出那些表"的详细逻辑。第一部分的算表章节指到这里。

## M1. 宏库:三级分级与优先级

- 宏库分三级,优先级 **Study > Therapeutic > Global**。
  - **跨级重名**:保留高优先级版本(按 Study → Therapeutic → Global 顺序加载,后来的同名宏视为重复、跳过)。
  - **同级重名**:保留**先加载**的那个。
- **只读每个宏库文件夹的顶层 `.sas` 文件,不进子目录**。
- 一个 `.sas` 文件里定义多个宏时:
  - 文件开头(第一个 `%macro` 之前)的注释块,只归给文件里**第一个**宏。
  - 若文件名与其中某个宏同名(专用文件),该注释块优先归给这个同名宏。
  - 同文件内互相调用的"兄弟宏",会从彼此的调用清单里剔除(不算外部依赖)。

## M2. 从日志抽字段(7.1 每行的七个字段)

- **程序名**:直接由日志文件名派生,不解析日志内容——`xxx.log → xxx-sas.txt`(转小写)。
- **输出数据集**(两级优先):
  1. 扫程序内容里的 `adsname=`(如 `%adbase(adsname=adsl, …)`),做宏变量解析 → `adsl.xpt`;
  2. 兜底从程序名派生:去扩展名 → 去结尾 `-sas` → 去掉首个 `-` 之前的前缀 → 转小写加 `.xpt`。
- **说明 / label**(四级优先,取到即止):① `adslabel=` 参数;② `adam.xxx(label=…)`;③ 任意 data step 的 `(label=…)`;④ `%let (lbl|label|adslabel|dslabel|dslbl)=…`。
- **输入数据集**:匹配 `sdtm.X` / `adam.X` / `misc.X` → `X.xpt`。抽取前先剥离注释(`/*…*/`、`%*…;`、`*…;`、成排星号装饰块)和 `%str(...)` 里 `||` 拼出来的名字(那是宏展开产物,不是真输入);跳过 `&` 开头的(宏变量引用);特例:`%genmsupp(inlib=…, indset=XX)` 会额外算上 `XX.xpt` 和 `suppXX.xpt`;最后把等于自身输出的项剔掉。
- **Purpose(用途)**:从宏源码/文件头注释里抓 `Purpose:` 之后的文字,遇到下列任一即停:`{`、`@xxx`、`*/`、`/*`、`%macro`、空行,或一批停止关键字(parameters / param / input / output / usage / note / author / date …)。

## M3. 宏使用解析 + 子宏递归

- **源码清洗**:去掉日志行号前缀、去掉 NOTE/WARNING/ERROR/计时行、去掉各类注释与装饰块、把字符串常量清空,得到干净代码再分析。
- **直接宏**:匹配 `%name`(排除 `%name:` 这种标签写法),再排除 SAS 内置宏(见 M9)和本程序自己定义的宏,剩下就是它直接调用的自定义宏。
- **子宏(传递闭包)**:对每个直接宏,在宏库里查它调用了哪些宏,层层展开(广度优先),记成 `子宏 (via 父宏)`。
- Output 侧还会额外从日志的 `MLOGIC(宏名)` 跟踪行里补收宏。
- ⚠️ 子宏解析完全依赖宏库已加载且解析正确——**这就是为什么必须先加载宏库(第 1 步)**。宏库缺失时子宏被漏掉且不报错。

## M4. 宏变量解析

- 从清洗后的源码里收集所有 `%let X = Y;` 定义;解析 `&X` / `&X.` 引用时**最多迭代 20 次**处理层层嵌套;若 20 次后仍有未解析的引用,就判为"解析不了"(回退用文件名派生)。

## M5. 执行顺序推算

- 建立"输出数据集 → 生产它的程序"映射;若程序 A 的输入是程序 B 的输出,则 A 依赖 B。
- 用**最长路径分层**:某程序的层号 = 它所有依赖里最大层号 + 1(若成环则该点记 0);同一层内按程序名字母序排,再从 1 顺序编号。
- 注意:这给的是"可并行的批次顺序",不是唯一真实运行顺序;**循环依赖被静默记为第 0 层**,不告警。

## M6. 依赖关系图(喂 4.2)

- **连边判定**:程序读了 `adam.B`,就认为 B 是输入,连一条 `B → A`("B 喂给 A");跳过 `&adam.`(宏变量)和自己指向自己。
- 从结构化表格来的数据:某个输入只有在"它本身也是表里某程序的输出"时才连边,借此过滤掉 SDTM 等外部输入。
- **两个写死的结构节点**:`ADCORE`(置顶,所有没有父节点的孤儿挂到它下面)、`ADSL`(置底、作为根,单独降到最高真实节点的下一层);两者不可删。
- **写死的合并组**:`ADLB` / `ADZL` / `ADLC` 合并显示成一个节点。
- **命名归一**:去 `.xpt`、`库名.数据集` 只取数据集名、转大写。
- **环检测**:用三色 DFS 去掉回边保持有向无环,超出的环告警。
- 只作为输入、从没作为任何输出出现的数据集 → 画成灰色 ghost 节点(表示外部或未解析的生产者)。
- **导出**:SVG(按内容紧裁,留边 4px)或 RTF(位图放大 4 倍,最大 8192px,强制 Letter 纵向,只缩小不放大)。

## M7. Output 程序 + DPP Tool 交叉匹配(7.2)

- **DPP Excel 解析**:
  - 目标 sheet 名为 **"List of Outputs"**(大小写/空格不敏感);找不到就报错。
  - 在前 15 行内自动找表头,按列名匹配:**"Output File Name"**(必需)、**"ADRG"**(必需)、"Table No."(可选)、"Title and Population"(可选)。
  - **只保留 `ADRG` 列 == `Y` 的行**,这就是本次要进 ADRG 的 output 全集。
  - 匹配主干(stem)= 文件名转小写、去掉已知扩展名(`.rtf/.pdf/.xlsx/.html/.txt`);按 stem 去重,先出现的优先,保留清单顺序。
- **匹配**:以 Excel 清单为准,用 stem 精确匹配日志扫到的 output(无模糊)。显示名优先级:DPP 文件名(带扩展名时)> 日志 `NOTE: Writing` 名 > `<stem>.rtf`。**Excel 的表号/标题覆盖日志解析值。**
- **日志扫描**:靠 `NOTE: Writing … .(rtf|pdf|xlsx|html|txt)` 行识别产出的 output,取文件名主干(一个日志可产出多个 output);编号/标题:定位 `OUT_FILENAME='<stem>'` 锚点,在其后约 1 万字符窗口内扫 `TITLE1=`(编号)和 `TITLE2..N=`(标题)。**文件名以 `rl-` 开头的日志整个跳过。**

## M8. eSub 打包 / 交付物命名约定

- `.sas` 复制到目标文件夹时改名为 **`-sas.txt`**(FDA eSub 命名约定;可在 eSub Programs 标签页关闭)。
- 所有文件**平铺,不建子目录**。
- 去重合并宏清单时,保留带 purpose 说明的那条。
- 输出数据集统一 `.xpt` 扩展名。

## M9. SAS 内置宏排除清单(硬清单 — 纯领域知识)

抽"程序用到的宏"时,要排除 SAS 语言自带的宏/函数,只留自定义宏。工具内部维护了一份内置名清单(ADaM 侧和 Output 侧各一份,**内容几乎相同**)。合并去重后(小写):

```
abort bquote cats catt catx cmpres cv datatyp display do else end eval exist
finish geo global goto if inc include index init kindex kleft klength
klowcase kscan ksubstr ktrim kupcase label left length let local lowcase macro
mend nrbquote nrquote nrstr put qscan qsubstr qlowcase qsysfunc symdel
syscc sysdate sysdate9 qupcase quit quote return right symexist
scan str substr superq syslibrc sysexec sysexist sysevalf
syscall sysfunc sysget sysmacexec sysmacexist sysfilrc syslput endit sysparm
sysrput sysrc then to trim until unquote upcase verify while window
```

⚠️ 这份清单是人工整理的,可能不完整或有偏差;而且分散在两处维护,容易漂移。

---

# 第三部分:待专家补充的 Why(按价值排序)

以下"为什么"是无法从代码/逻辑恢复、也是这份资产真正核心的部分:

1. **7.2 DPP Tool 模板契约** — sheet 名 / 列名 / `ADRG=Y` 标记与 DPP 模板版本的绑定关系(整个 Output 分析的命门)。
2. **4.2 结构节点与合并组** — `ADCORE`/`ADSL` 为何是结构性根节点?`ADLB/ADZL/ADLC` 为何合并?是否随研究变化?(现在写死)
3. **M9 SAS 内置宏清单** — 谁维护、是否完整、两份是否应合并为单一权威来源。
4. **M1 三级优先级** — Study > Therapeutic > Global 对应的组织 SOP;同级"先加载优先"是有意约定还是实现细节。
5. **7.2 `rl-` 前缀日志排除** — `rl-` 是什么含义、为何排除。
6. **3.1 / 5.2.x spec 判定约定** — "核心变量 = A 列 ALL"、"只认 PARAMCD/PARCATn" 对应哪份 ADaM spec 填写规范。
7. **M2 字段约定** — `adsname=` 是否标准输出参数名;label 四来源的优先级是否有意;`-sas.txt` 命名出自哪份 FDA 指南。
8. **列位置写死风险** — 3.1 / 5.2.x / 8 按列位置(A/D/F/K)而非表头名取值,当前绑定的是哪个版本的 spec 模板。
