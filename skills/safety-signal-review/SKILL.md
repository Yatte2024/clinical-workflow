---
name: safety-signal-review
description: >
  Use when asked to review safety, find signals, assess drug safety, or
  perform a safety analysis. Provides systematic framework covering AEs,
  labs, vitals, ECG, and exposure-response. Always use with adam-explorer.
---

# Safety Signal Detection Framework

## Systematic Safety Review

When asked about safety signals, follow this structured approach. Do NOT skip
phases. Do NOT jump to conclusions before completing the orientation.

### Phase 1: ORIENTATION

Before analyzing, understand the study context:

```
1. What study? What drug? What comparator (placebo, active, dose groups)?
2. What population? → Query ADSL: SELECT TRT01A, COUNT(*) FROM adsl WHERE SAFFL='Y' GROUP BY TRT01A
3. What is the exposure duration? → Query ADSL: SELECT TRT01A, MEDIAN(TRTEDT - TRTSDT) FROM adsl GROUP BY TRT01A
4. What datasets are available? → the schema-discovery tool
5. Report to user: "Study X: N subjects in safety population, K treatment arms, median exposure D days"
```

### Phase 2: ADVERSE EVENTS

Query ADAE joined to ADSL (SAFFL = 'Y'). Focus on treatment-emergent AEs (TRTEMFL = 'Y').

**Step 2a: Overall AE incidence**
```sql
SELECT adsl.TRT01A,
       COUNT(DISTINCT CASE WHEN adae.TRTEMFL = 'Y' THEN adae.USUBJID END) as N_WITH_AE,
       COUNT(DISTINCT adsl.USUBJID) as N_TOTAL
FROM adsl
LEFT JOIN adae ON adsl.USUBJID = adae.USUBJID
WHERE adsl.SAFFL = 'Y'
GROUP BY adsl.TRT01A
```

**Step 2b: AEs by System Organ Class (SOC)**
Look for SOCs where drug arm incidence is ≥2× placebo or risk difference ≥5%.

**Step 2c: Drill into flagged SOCs by Preferred Term (PT)**
For any SOC with signal, show the top PTs driving the imbalance.

**Step 2d: Severe and Serious AEs**
```sql
-- Grade 3+ or Serious
SELECT adsl.TRT01A, adae.AEDECOD, adae.AEBODSYS,
       COUNT(DISTINCT adae.USUBJID) as N_SUBJ
FROM adae
JOIN adsl ON adae.USUBJID = adsl.USUBJID
WHERE adsl.SAFFL = 'Y' AND (adae.AESER = 'Y' OR adae.AESEV = 'SEVERE')
GROUP BY adsl.TRT01A, adae.AEDECOD, adae.AEBODSYS
```

**Step 2e: AEs leading to discontinuation**
Query WHERE AEACN = 'DRUG WITHDRAWN'. Compare rates across arms.

**Step 2f: Deaths**
Query WHERE AEOUT = 'FATAL'. List every death with PT, SOC, and arm.

**Step 2g: Related AEs**
Query WHERE AEREL contains 'RELATED' or 'PROBABLE' or 'POSSIBLE'.
These are the investigator's assessment of causality.

### Phase 3: LABORATORY

Query ADLB joined to ADSL (SAFFL = 'Y'). Use `toxicity-grading` skill for grade criteria.

**Step 3a: Hepatic panel**
Parameters: ALT, AST, BILI, ALP. These are the most safety-critical labs.
- Compute CTCAE grades (use ATOXGR if available, else grade from AVAL/A1HI)
- Compare Grade 3+ incidence across arms
- Look for ALT or AST >3×ULN in drug arm without comparable rate in placebo

**Step 3b: Hy's Law screen**
This is CRITICAL. Even one case may be a signal for drug-induced liver injury (DILI).
```sql
SELECT lb_alt.USUBJID, lb_alt.AVISIT,
       lb_alt.AVAL as ALT_VAL, lb_alt.A1HI as ALT_ULN,
       ROUND(lb_alt.AVAL / lb_alt.A1HI, 1) as ALT_XULN,
       lb_bili.AVAL as BILI_VAL, lb_bili.A1HI as BILI_ULN,
       ROUND(lb_bili.AVAL / lb_bili.A1HI, 1) as BILI_XULN
FROM adlb lb_alt
JOIN adlb lb_bili ON lb_alt.USUBJID = lb_bili.USUBJID
WHERE lb_alt.PARAMCD = 'ALT' AND lb_bili.PARAMCD IN ('BILI', 'BILITOT')
  AND lb_alt.AVAL > 3.0 * lb_alt.A1HI
  AND lb_bili.AVAL > 2.0 * lb_bili.A1HI
```
If ANY subjects meet criteria: this is a potential Hy's Law case. Flag immediately.

**Step 3c: Hematology**
Parameters: HGB, WBC, ANC, PLAT. Grade per CTCAE.
- Neutropenia (ANC <0.5 = Grade 4) in drug arm is a serious signal
- Thrombocytopenia (PLAT <25 = Grade 4) is a serious signal

**Step 3d: Renal**
Parameter: CREAT. Grade per CTCAE.
- Creatinine >3×ULN (Grade 3) is a signal

**Step 3e: Other chemistry**
Check: potassium, sodium, calcium, glucose for Grade 3+ shifts.

### Phase 4: VITAL SIGNS

Query ADVS joined to ADSL (SAFFL = 'Y').

**Step 4a: Mean change from baseline by visit and arm**
For SYSBP, DIABP, PULSE, WEIGHT.

**Step 4b: Categorical outliers**
Flag subjects meeting these criteria at any post-baseline visit:

| Parameter | Outlier Criteria |
|-----------|-----------------|
| SBP | >180 mmHg or <90 mmHg |
| DBP | >105 mmHg or <60 mmHg |
| Pulse | >120 bpm or <50 bpm |
| Weight | >10% change from baseline |

Compare outlier rates across arms.

**Step 4c: Dose-dependent trends**
If multiple dose groups: plot mean change by visit overlaid by dose.
A dose-dependent pattern strengthens a signal.

### Phase 5: ECG (if ADEG available)

Query ADEG joined to ADSL (SAFFL = 'Y').

**Step 5a: QTcF analysis** (most important ECG parameter)
- Mean change from baseline by visit and arm
- Categorical analysis:

| Category | Threshold | Clinical Significance |
|----------|-----------|----------------------|
| Absolute QTcF >450 ms | Low concern threshold | |
| Absolute QTcF >480 ms | Moderate concern | Warrants close monitoring |
| Absolute QTcF >500 ms | HIGH concern | Risk of torsade de pointes |
| ΔQTcF >30 ms | Notable change | |
| ΔQTcF >60 ms | Clinically significant change | Signal |

**Step 5b: Any individual subject with QTcF >500ms is a signal regardless of arm comparison.**

### Phase 6: EXPOSURE-SAFETY (if PK/exposure data available)

If ADPC, ADPP, or ADEX datasets exist:

**Step 6a: AE incidence by exposure quartile**
Create exposure quartiles from ADPP (AUC or Cmax) or ADEX (cumulative dose).
Compare AE incidence across quartiles for key safety findings from Phases 2-5.

**Step 6b: Dose-response**
If multiple dose arms: plot AE incidence vs dose for flagged events.
A monotonic dose-response relationship strongly suggests a drug effect.

## Signal Detection Criteria

A finding warrants investigation if ANY of these are true:

### Statistical Signals
- Incidence ratio ≥2.0 (drug vs comparator for a specific AE or lab finding)
- Risk difference ≥5 percentage points (absolute)
- Dose-response trend across ≥3 dose levels
- Fisher's exact p < 0.1 (flag for attention, do NOT use as a gate)

### Clinical Signals (Even Without Statistical Significance)
These override statistics — even a single case matters:
- **Death** — any drug-related death
- **Hy's Law** — ALT >3×ULN AND Bilirubin >2×ULN (even one subject)
- **QTc >500ms** — even in one subject
- **Severe neutropenia** — ANC <0.5 ×10⁹/L
- **Severe thrombocytopenia** — Platelets <25 ×10⁹/L
- **Anaphylaxis or severe hypersensitivity** — even one case
- **Suicidal ideation or behavior** — even one, if not expected for population
- **Rhabdomyolysis** — CK >10×ULN with renal impairment
- **Pancreatitis** — lipase >3×ULN with symptoms

### Pattern Signals
- Temporal clustering: events concentrated in first weeks of treatment
- Resolution on dose reduction or discontinuation (positive dechallenge)
- Recurrence on rechallenge (strongest causal evidence)
- Higher severity in drug arm (Grade 1 in placebo → Grade 3 in drug)
- Events in a single SOC absent from comparator arm
- Known mechanism-of-action risk (e.g., immunosuppressant → infections)

## Presenting Safety Findings

### Prioritization
Lead with the MOST CLINICALLY CONCERNING finding, not alphabetical order.

Priority order:
1. Deaths
2. Hy's Law cases
3. Other SAEs with arm imbalance
4. Grade 3+ lab abnormalities with arm imbalance
5. Common AEs (≥10%) with ≥2× incidence ratio
6. QTc findings
7. Vital sign trends
8. Other notable findings

### Required Format for Each Finding

Always present safety data with these elements:
- **n/N (%)** — subjects with event / total in population, with percentage
- **Both arms side-by-side** — never show drug arm alone
- **Risk difference** with 95% CI when sample size permits
- **Denominators always stated** — "5 of 30 patients (16.7%)", not "5 patients"

### Visualization Preferences

| Finding Type | Best Visualization |
|-------------|-------------------|
| AE incidence by SOC | Horizontal bar chart, arms side-by-side |
| AE incidence by PT | Forest plot of risk differences |
| Lab trends over time | Line plot, mean ± SE by visit and arm |
| Hepatotoxicity | eDISH plot (ALT ×ULN vs Bilirubin ×ULN) |
| Individual lab trajectories | Spaghetti plot for flagged subjects |
| Max change from baseline | Waterfall plot |
| QTc over time | Line plot with horizontal lines at 450, 480, 500ms |

### Interpretation Rules

1. **State the finding factually first.** "ALT >3×ULN occurred in 8/120 (6.7%) drug vs 1/60 (1.7%) placebo subjects."
2. **Contextualize.** "This is consistent with the known hepatotoxic potential of [drug class]."
3. **Note confounders.** "Three of the 8 subjects had baseline ALT >ULN."
4. **Do NOT make causal claims.** Say "warrants further investigation" or "suggests a potential signal."
5. **Recommend specific follow-up.** "Recommend patient narratives for the 8 subjects with ALT >3×ULN."

## Related Skills

- `toxicity-grading` — CTCAE v5.0 grading criteria for lab parameters
- `adam-explorer` — ADaM dataset and variable reference
- `sdtm-explorer` — SDTM domain reference (if ADaM unavailable)
- `liver-safety` — Detailed DILI assessment (Wave 2)
- `lab-shift-tables` — Shift table methodology (Wave 2)
- `safety-review-workflow` — Step-by-step medical monitor review workflow
