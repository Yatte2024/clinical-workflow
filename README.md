# Clinical AI

Reference-guided clinical programming prototype for SDTM-to-ADaM code generation, output generation, lineage impact review, and ADRG drafting.

## Run

```bash
node server.mjs
```

Open `http://localhost:4173`.

## Structure

- `public/`: main browser UI
- `src/`: local Node server and generation logic
- `data/`: editable prototype inputs, including ADaM specs and DPP output definitions
- `output/`: generated DAG and R code artifacts
- `prototypes/`: standalone test pages used to validate UI ideas before merging
- `docs/`: project notes and product/spec thinking
- `skills/`: local clinical and agent skills used as reference material
- `clinical-r-learning/`: R examples and learning notes
