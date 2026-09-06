# Clinical Programming Automation & Lineage Explorer

## 1. Project Vision

构建一个面向 Clinical Statistical Programming 的自动化与数据血缘（lineage）平台，将：

**SDTM → ADaM → Output**

整个 clinical programming lifecycle 串联起来。

项目不以“复制 BeOne”或“重新实现 teal”为目标，而是参考公开行业实践，解决一个更具体的问题：

> **How can a programmer understand an unfamiliar study in 5 minutes?**

当 programmer 接手一个新的或已经开发多年的 study 时，可以快速理解：

- 有哪些 SDTM datasets
- 如何生成 ADaM datasets
- 某个 ADaM variable 来自哪里
- Derivation rule 是什么
- 哪些 downstream variables 依赖它
- 哪些 TFL outputs 使用它
- 修改一个 variable/spec 后可能影响什么

---

# 2. Overall Concept

```text
                  Clinical Programming Platform

                           Study
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼

          Automation       Lineage       Exploration
             Skills         Explorer        Layer

              │              │              │
              ▼              ▼              ▼

SDTM ───────────────→ ADaM ───────────────→ TFL
        Skill 1              Skill 2
```

项目由三个主要部分组成：

1. Automation Skills
2. Clinical Lineage Explorer
3. R Package / Metadata Engine

teal 可以作为额外的 ADaM exploration layer，但不是整个系统的核心。

---

# 3. Automation Skills

## Skill 1 — SDTM → ADaM

目标：

根据 ADaM specification、SDTM data 和 predefined clinical programming rules，辅助完成 ADaM dataset development。

基本流程：

```text
SDTM
  │
  ▼
Read ADaM Specification
  │
  ▼
Identify Source Variables
  │
  ▼
Understand Derivation
  │
  ▼
Generate Derivation Plan
  │
  ▼
Generate / Assemble Code
  │
  ▼
ADaM
```

第一阶段不需要覆盖全部 ADaM。

建议从典型 datasets 开始：

```text
DM + EX + DS
      ↓
     ADSL

AE + ADSL
      ↓
     ADAE

RS/TU/TR + ADSL
      ↓
     ADRS

ADSL + response/death/progression data
      ↓
     ADTTE
```

---

## Skill 2 — ADaM → Output

目标：

从 ADaM + TFL specification 自动构建分析 output。

```text
ADaM
  │
  ▼
Read TFL Specification
  │
  ▼
Identify Analysis Population
  │
  ▼
Identify Variables / Statistics
  │
  ▼
Generate Analysis Logic
  │
  ▼
Generate R/SAS Code
  │
  ▼
Table / Listing / Figure
```

第一阶段可以选择：

```text
ADSL → Demographic Table

ADAE → AE Summary Table

ADTTE → KM Plot
```

作为 proof of concept。

---

# 4. Clinical Lineage Explorer

这是项目最重要的可视化部分。

目标不是简单展示 dataset，而是展示：

> **SDTM → ADaM → TFL dependency / lineage**

例如：

```text
SDTM                 ADaM                    OUTPUT

DM ───────────────→ ADSL ───────────────→ Demographics
                        │
EX ────────────────────┘
                        │
AE ─────────────────→ ADAE ───────────────→ AE Summary
                        │
                        └──────────────────→ AE Listing

RS ─────┐
TU ─────┼────────────→ ADRS ───────────────→ Response Table
TR ─────┘

ADSL + ADRS ────────→ ADTTE ──────────────→ KM Plot
```

---

# 5. Dataset-Level Study Map

进入一个 study 后，首先看到整个 Study Map。

例如：

```text
Study ABC123

SDTM                 ADaM                   TFL

DM ────────────────→ ADSL ───────────────→ T14.1.1
 │                      │
EX ─────────────────────┘
                        │
AE ─────────────────→ ADAE ───────────────→ T14.3.1
                        ├──────────────────→ T14.3.2
                        └──────────────────→ L16.2.1

RS ─────┐
TU ─────┼────────────→ ADRS ───────────────→ T14.2.1
TR ─────┘
```

Programmer 可以快速理解整个 study 的数据结构。

---

# 6. Variable Search

Study 很大以后，不可能只依靠浏览 graph。

因此需要：

```text
Search Variable:

[ TRTEMFL                         ]
```

搜索结果：

```text
ADAE.TRTEMFL
```

点击后直接进入该 variable 的 lineage。

---

# 7. Derivation Explorer

例如点击：

```text
ADAE.TRTEMFL
```

展示：

```text
                AE.AESTDTC
                     │
                     │
                ADSL.TRTSDT
                     │
                     │
                ADSL.TRTEDT
                     │
                     ▼
               ADAE.TRTEMFL
                     │
          ┌──────────┼──────────┐
          ▼          ▼          ▼
       T14.3.1    T14.3.2    L16.2.1
```

同时展示 metadata：

```text
Target
────────────────────
ADAE.TRTEMFL


Source
────────────────────
AE.AESTDTC
ADSL.TRTSDT
ADSL.TRTEDT


Derivation
────────────────────
Treatment-emergent flag based on
AE start date and treatment period.


Downstream Usage
────────────────────
T14.3.1
T14.3.2
L16.2.1
```

核心回答三个问题：

> Where does it come from?

> How is it derived?

> Where is it used?

---

# 8. Impact Analysis

这是 lineage graph 自然产生的能力，因此应该保留在 MVP。

例如 programmer 搜索：

```text
ADSL.TRTSDT
```

系统不仅显示它来自哪里，还可以显示：

```text
Downstream Impact

ADSL.TRTSDT
      │
      ├────→ ADAE.TRTEMFL
      │           │
      │           ├────→ T14.3.1
      │           └────→ T14.3.2
      │
      └────→ ADTTE.STARTDT
                  │
                  └────→ KM Plot
```

并总结：

```text
Used by:

4 ADaM datasets
17 ADaM variables
8 Tables
2 Listings
1 Figure
```

这样 programmer 修改 specification 前就能快速判断潜在影响。

---

# 9. Visualization Choice

## Sankey

BeOne 的公开方案使用过 interactive Sankey diagram 展示 metadata association。

Sankey 特别适合：

```text
Source → Intermediate → Destination
```

例如：

```text
SDTM → ADaM → TFL
```

但是 Sankey 原本主要用于表达“flow”，通常线条宽度具有 quantity 的含义。

Clinical metadata 实际表达的是：

> dependency / lineage

因此我们不需要照搬 Sankey。

---

## Preferred: DAG / Network Graph

我们的第一选择可以是：

**Directed Acyclic Graph (DAG)**

例如：

```text
DM ──────→ ADSL ──────→ ADAE ──────→ AE Table
              │
EX ───────────┘
              │
              └────────→ ADTTE ─────→ KM Plot
```

优势：

- dependency 表达更自然
- upstream/downstream 更清晰
- variable-level lineage 更容易扩展
- 支持 node click / drill-down
- 支持 search/highlight
- 不需要人为赋予 edge “宽度”
- 与 BeOne Sankey 在视觉和交互设计上形成区别

前端技术可以进一步评估：

- Cytoscape.js
- React Flow
- D3.js
- visNetwork
- DiagrammeR

---

# 10. teal 的角色

teal 不是必须的。

teal 的核心优势是：

> Interactive clinical data exploration / analysis

例如：

```text
ADSL
ADAE
ADTTE
  │
  ▼
teal
  │
  ├── Demographics
  ├── AE Explorer
  ├── KM
  ├── Labs
  └── Patient Profile
```

但我们的核心问题是：

```text
SDTM
 ↓
ADaM
 ↓
TFL
```

之间的 metadata dependency。

因此 teal 可以作为：

```text
Optional ADaM Exploration Layer
```

而不是整个系统的 UI framework。

---

# 11. Why Not Build Everything in teal?

teal 基于 Shiny。

对于 interactive statistical analysis，这是合理的架构。

但如果未来系统主要是：

- metadata search
- dependency graph
- lineage traversal
- variable search
- multi-user access

则没有必要让每个功能都依赖 R/Shiny session。

长期可以考虑：

```text
                  Frontend
          React / Cytoscape / D3
                      │
                      ▼
                     API
                      │
          ┌───────────┴───────────┐
          ▼                       ▼
     Metadata Store           R Package
                             Clinical Logic
```

这样 UI、metadata 和 clinical computation 可以解耦。

---

# 12. R Package

项目底层可以初始化一个 R package，例如：

```text
clinicalflow/
│
├── DESCRIPTION
├── NAMESPACE
│
├── R/
│   ├── read_spec.R
│   ├── build_lineage.R
│   ├── dependency_graph.R
│   ├── impact_analysis.R
│   ├── run_sdtm_to_adam.R
│   └── run_adam_to_output.R
│
├── inst/
│   ├── skills/
│   │   ├── sdtm_to_adam/
│   │   └── adam_to_output/
│   │
│   └── metadata/
│
├── tests/
│
├── vignettes/
│
└── README.md
```

R package 主要负责：

```text
Read Metadata
     ↓
Normalize Metadata
     ↓
Build Dependency Graph
     ↓
Provide Clinical Logic
     ↓
Expose Lineage / Impact Information
```

---

# 13. Relationship with BeOne

BeOne 的公开 SpecMaster / ACIRA architecture 提供了很好的行业参考，包括：

- ADaM specification automation
- code generation
- metadata association
- SDTM → ADaM → TFL lineage
- bidirectional traceability
- interactive Sankey
- change impact
- reusable skills / tools
- AI-assisted clinical programming

我们的目标不是复制该系统。

核心区别是：

### BeOne

更偏：

> AI-assisted metadata/spec/code management platform

### Our Project

第一阶段更聚焦：

> **Clinical Study Understanding + Lineage**

核心问题：

> **Can a programmer understand an unfamiliar study in 5 minutes?**

因此不会通过堆叠功能来制造差异。

---

# 14. MVP

第一版只做四件事情。

## 1. Study Map

```text
SDTM → ADaM → TFL
```

快速理解 study architecture。

## 2. Variable Search

```text
Search: TRTEMFL
```

快速找到 dataset / variable。

## 3. Derivation Explorer

回答：

```text
Where from?
How derived?
Where used?
```

## 4. Impact Analysis

回答：

```text
If this variable changes,
what downstream objects may be affected?
```

因此 MVP 可以概括为：

```text
              Clinical Lineage Explorer

                       STUDY
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼

      STUDY MAP        SEARCH         IMPACT

   SDTM→ADaM→TFL      TRTEMFL      downstream
                         │
                         ▼
                 DERIVATION VIEW

                  Where from?
                  How derived?
                  Where used?
```

---

# 15. Not in MVP

第一版暂时不做：

- QC status dashboard
- Unit test integration
- Run code directly from graph
- AI automatic repair
- Complex what-if simulation
- Full submission management
- Full teal replacement
- Full enterprise metadata platform

这些功能并非没有价值，而是会导致第一版 scope 快速扩大。

先验证：

> **Study Map + Search + Derivation + Impact**

是否真的能够帮助 programmer。

---

# 16. Future Extensions

如果 MVP 有价值，再逐步考虑：

### Phase 2 — Automation

```text
SDTM → ADaM Skill

ADaM → Output Skill
```

将 lineage metadata 与 automation skills 连接。

### Phase 3 — Validation

增加：

```text
Spec
 ↓
Code
 ↓
Dataset
 ↓
QC
 ↓
Output
```

状态追踪。

### Phase 4 — Interactive Analysis

可选择集成 teal：

```text
ADaM
 ↓
teal
 ↓
Interactive Clinical Exploration
```

### Phase 5 — AI Assistant

AI 可以基于整个 lineage graph 回答：

```text
Where does TRTEMFL come from?

Which outputs use TRTSDT?

Why is T14.3.1 affected?

Which datasets depend on ADSL?

Explain ADRS derivation.

What should I review if TRTSDT changes?
```

AI 的角色是帮助 programmer 理解系统，而不是第一阶段直接取代 programmer。

---

# 17. Proposed Development Roadmap

```text
Phase 1
────────────────────
Init R Package
      ↓
Define Metadata Model
      ↓
Create Example Study
      ↓
Build Dataset-level DAG


Phase 2
────────────────────
Variable-level Lineage
      ↓
Variable Search
      ↓
Derivation Explorer


Phase 3
────────────────────
Downstream Dependency
      ↓
Impact Analysis


Phase 4
────────────────────
SDTM → ADaM Skill
      ↓
ADaM → Output Skill


Phase 5
────────────────────
Optional teal Integration
      ↓
Optional AI Assistant
```

---

# 18. One-Sentence Project Definition

> **A metadata-driven Clinical Lineage Explorer and automation framework that helps programmers understand and navigate SDTM → ADaM → TFL dependencies across a clinical study.**

更偏产品的表达：

> **Understand a clinical study in five minutes — from SDTM source data to ADaM derivations and final outputs.**

---

# 19. Core Principle

项目第一阶段不追求：

> More AI.

也不追求：

> More dashboards.

而是追求：

> **Better understanding of clinical programming logic.**

最终希望 programmer 从传统的：

```text
Search specs
→ Open programs
→ Find variables
→ Trace datasets
→ Find outputs
→ Manually reconstruct dependencies
```

变成：

```text
Search variable
      ↓
See the whole story.
```