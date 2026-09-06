# Reference-Guided Clinical Programming Assistant MVP

## Product Positioning

The MVP is a reference-guided clinical programming assistant for clinical statistical programmers.

It generates R code for SDTM to ADaM and ADaM to output workflows, but does not ask users to blindly trust AI-generated code. The core product loop is:

```text
new study spec -> reference spec/code match -> generated or adapted R code -> reviewer decision
```

The intended first user is a clinical statistical programmer taking over or starting a study. The secondary goal is a portfolio/proof-of-concept demo.

## First Scope

The first study scope is:

- ADaM datasets: `ADSL`, `ADAE`
- Outputs: demographic table and AE by SOC/PT table
- Data source baseline: `kbd0011/cdisc-pilot-replication`
- Implementation language for generated programs: R
- Frontend direction: React-style web UI, with a lightweight static mockup first

The first version focuses on variables and outputs required for the two selected TFLs. Other ADSL/ADAE variables can exist in the UI, but do not need generation support yet.

## Trust Model

The trust model is based on comparing the new study variable spec against a reference variable spec.

Status semantics:

- Green: reference spec matches exactly, or reviewer approved the generated/adapted code
- Yellow: partial reference spec match; reviewer must review
- Red: no reference spec; AI generated code must be reviewed

For MVP simplicity, exact match is based on variable name plus the variable definition/derivation text from the spec. Study-specific context such as treatment windows must be written into the spec text if it matters.

Review approval changes the visible state to green. The MVP does not preserve origin badges after approval.

Review trail must record:

- reviewer
- timestamp
- status
- comment
- reviewed code hash
- reviewed spec hash

## Code Generation Model

ADaM generation is variable-centered in the UI but dataset-centered at runtime.

For each ADaM variable:

```text
variable spec -> reference match -> variable R code snippet
```

For each ADaM dataset:

```text
dataset template + approved/generated snippets -> complete dataset R script
```

The dataset page should display generated/reference dataset code by default. Output R code should be hidden by default and shown only when the user expands it.

When there is no reference variable spec, the system uses the new study spec to generate R code and marks the variable red until review.

## Runtime Execution

The MVP should expose a Run action, but should not automatically execute code.

The first execution mode is local `Rscript`. Study setup should collect:

- SDTM data folder
- ADaM spec Excel
- TFL spec Excel or output DPP YAML
- reference library location
- generated code output folder

The Run action initially returns success/failure and log output. Passing execution does not automatically approve code.

## Metadata Format

For ADaM specs, the first version should support Excel because that matches common pharmaceutical workflows.

For outputs, the MVP uses a hand-written DPP YAML file. The DPP YAML defines output intent and drives the Output Lab preview.

Minimum DPP fields:

- output id
- title
- type
- source ADaM dataset
- population
- filters
- grouping variables
- required variables
- columns
- row/statistic definitions
- decimals by column
- footnotes

The DPP YAML is not responsible for ADaM variable review status. It only defines outputs.

## UI Structure

The full product can be organized as:

```text
Study
├── Overall
│   ├── Study DAG
│   ├── coverage summary
│   └── review status summary
├── ADaM
│   ├── ADSL
│   └── ADAE
└── Output
    ├── Demographic Table
    └── AE by SOC/PT Table
```

The immediate mockup should include the full product skeleton: Overall, ADaM, and Output. The Output area includes an Output Lab with a DPP YAML editor and live preview.

Overall must show real dependency relationships, not only independent columns. The primary graph should be variable-level, not dataset-level:

```text
SDTM/source variables -> ADaM variables -> outputs
```

The Overall view should make downstream impact visible when an ADaM variable is yellow or red. A dataset-level map can exist as high-level navigation, but it should not be the main evidence view because it hides which exact variable change affects an output.

Overall should not split the DAG by output/table tabs. It should show one variable-level lineage map across the study scope, with ADaM dataset aggregation before outputs:

```text
SDTM/source variables -> ADSL/ADAE variables -> ADaM dataset nodes -> all downstream outputs
```

Clicking an ADaM variable opens the ADaM variable workbench. Clicking an ADaM dataset node opens the dataset page. Clicking an output opens the Output Lab detail for that output.

The visual style should not imitate published Sankey-style clinical lineage figures. Use a distinct dependency-board style: compact variable cards, thin orthogonal connector lines, and status rails on nodes. Avoid wide translucent flow bands.

If a free-form graph creates ambiguous crossings, prefer grouped lineage rows:

```text
source variables -> one ADaM variable
all required ADaM variables -> ADaM dataset node -> outputs
```

The Overall view must not visually imply false relationships such as `ADSL.AGE -> ADAE.SAFFL`. Cross-dataset dependencies should be shown only when they are explicitly part of a selected variable's source list.

The active Overall prototype uses dataset-scoped swimlanes. Each ADaM dataset gets its own section. Source variables are repeated inside the specific variable row they feed, instead of being merged into one shared source column. This makes the relationship local and prevents users from visually tracing the wrong edge.

The merged Overall design uses a two-level DAG:

```text
Level 1: input groups inferred from required variables -> outputs
Level 2: selected input group -> variable-level lineage
```

This keeps outputs readable when the study has many tables while still allowing the user to inspect variable-level lineage for a selected ADaM or SDTM group.

The Output Lab should show:

- required ADaM variables and their current status
- output shell preview generated from YAML
- decimal formatting from column settings
- population/filter/grouping logic
- output R code collapsed by default

The ADaM dataset view should show:

- dataset tabs for `ADSL` and `ADAE`
- variable status list with green/yellow/red states
- reference spec versus current study spec diff for the selected variable
- editable variable-level R code
- manual review action that changes the selected variable to green
- a separate dataset script assembly panel built from variable-level snippets

The full dataset script should not be repeated inside every variable as if it belonged to that field. Each variable owns a separate code snippet; the dataset owns the assembled program.

## MVP Happy Path

```text
1. Open the full mockup.
2. Review Overall DAG and status summary.
3. Open ADaM > ADAE and inspect variable-level spec/code/review state.
4. Open Output Lab.
5. Edit DPP YAML for an output.
6. See required variables, table shell, decimal formatting, and hidden R code update.
```

The first full product happy path remains:

```text
import Excel spec -> see variable status -> inspect ADAE.TRTEMFL -> generate/adapt R code -> reviewer approve -> status turns green -> output dependency becomes ready
```

## Prototype IO Contract

The prototype has two user-editable inputs:

- `adam-specs.yaml`: ADaM variable specs, including source variables, reference spec, current spec, review status, similarity, and variable-level R code
- `output-dpp.yaml`: output definitions, including required ADaM variables, population, filters, groups, columns, decimals, rows, and footnotes

The generated output folder contains:

- `output/dag.json`: lineage graph result derived from the ADaM specs and output DPP
- `output/adam/adsl.R`
- `output/adam/adae.R`
- `output/output/T14_1_1.R`
- `output/output/T14_3_1.R`

When the user saves an ADaM variable code edit in the UI, the prototype updates `adam-specs.yaml` and regenerates the ADaM dataset script plus `output/dag.json`.

When the user saves the DPP YAML in the UI, the prototype updates `output-dpp.yaml` and regenerates the output R code plus `output/dag.json`.

The prototype can be opened as a static local HTML file for read-only viewing, but save/regenerate behavior requires the local server. Browser pages opened through `file://` cannot directly write arbitrary files on disk, so the server owns file writes and artifact generation.
