---
name: safety-review-workflow
description: >
  Use when a medical monitor asks for a complete safety review, "review this
  study," or wants a comprehensive safety assessment. Provides a structured
  checklist that walks through demographics, disposition, AEs, labs, vitals,
  and ECG step by step.
---

# Safety Review Checklist

A structured workflow for conducting a complete safety review of a clinical study.
Present this checklist to the medical monitor and work through it systematically.

## Pre-Review Setup

Before analyzing any safety data, establish the study context:

```
Step 1: Confirm the study ID and data folder with the user
Step 2: Profile available datasets → the schema-discovery tool
Step 3: Identify available domains:
        - Required: ADSL (or DM), ADAE (or AE)
        - Important: ADLB (or LB), ADVS (or VS)
        - Optional: ADEG (or EG), ADEX (or EX), ADPC/ADPP
Step 4: Count safety population → SELECT TRT01A, COUNT(*) FROM adsl WHERE SAFFL='Y' GROUP BY TRT01A
Step 5: Report to user:
        "Study [X]: [N] subjects in safety population across [K] arms.
         Available datasets: [list]. Missing: [list]."
```

## The Review Checklist

Present this checklist at the start. Update status as each item is completed.

```
□ 1. Demographics & Baseline Characteristics
□ 2. Subject Disposition
□ 3. Extent of Exposure
□ 4. Adverse Events Overview
□ 5. Laboratory Assessments
□ 6. Vital Signs
□ 7. ECG Assessment
□ 8. Summary of Findings
```

---

### Step 1: Demographics & Baseline Characteristics

**Goal:** Confirm the population is balanced and understand who is in the study.

**Query:**
```sql
SELECT TRT01A,
       COUNT(*) as N,
       ROUND(AVG(AGE), 1) as MEAN_AGE,
       ROUND(MIN(AGE), 0) as MIN_AGE,
       ROUND(MAX(AGE), 0) as MAX_AGE,
       SUM(CASE WHEN SEX = 'F' THEN 1 ELSE 0 END) as N_FEMALE,
       SUM(CASE WHEN SEX = 'M' THEN 1 ELSE 0 END) as N_MALE,
       SUM(CASE WHEN RACE = 'WHITE' THEN 1 ELSE 0 END) as N_WHITE,
       SUM(CASE WHEN RACE = 'BLACK OR AFRICAN AMERICAN' THEN 1 ELSE 0 END) as N_BLACK,
       SUM(CASE WHEN RACE = 'ASIAN' THEN 1 ELSE 0 END) as N_ASIAN
FROM adsl
WHERE SAFFL = 'Y'
GROUP BY TRT01A
```

**Interpretation:**
- Flag any meaningful imbalances between arms (>10% difference in age, sex, race)
- Note the population characteristics that may affect safety interpretation
  (e.g., elderly population → higher baseline lab abnormalities)
- Check for very small subgroups that limit safety conclusions

**Output:** Summary table + 2-3 sentence assessment.
**Signal flag:** ✓ Balanced | ⚠ Notable imbalance (describe)

---

### Step 2: Subject Disposition

**Goal:** Understand who completed the study and why subjects discontinued.

**Query:**
```sql
-- Completion and discontinuation by arm
SELECT adsl.TRT01A,
       COUNT(*) as N_TOTAL,
       SUM(CASE WHEN adsl.EOSSTT = 'COMPLETED' THEN 1 ELSE 0 END) as N_COMPLETED,
       SUM(CASE WHEN adsl.EOSSTT = 'DISCONTINUED' THEN 1 ELSE 0 END) as N_DISC
FROM adsl
WHERE SAFFL = 'Y'
GROUP BY adsl.TRT01A
```

```sql
-- Discontinuation reasons (from DS domain if ADSL doesn't have detail)
SELECT dm.ARM, ds.DSDECOD, COUNT(DISTINCT ds.USUBJID) as N_SUBJ
FROM ds
JOIN dm ON ds.USUBJID = dm.USUBJID
WHERE ds.DSCAT = 'DISPOSITION EVENT'
  AND ds.DSDECOD != 'COMPLETED'
GROUP BY dm.ARM, ds.DSDECOD
ORDER BY dm.ARM, N_SUBJ DESC
```

**Key red flags:**
- Higher discontinuation rate in drug arm vs placebo
- Discontinuation due to AEs: compare rates across arms
- "Lost to follow-up" imbalance may mask safety events

**Output:** Disposition table + assessment.
**Signal flag:** ✓ No concern | ⚠ Higher discontinuation in drug arm | ⛔ AE-driven discontinuation imbalance

---

### Step 3: Extent of Exposure

**Goal:** Understand how much drug subjects received. This contextualizes safety findings.

**Query:**
```sql
-- Exposure duration from ADSL treatment dates
SELECT TRT01A,
       COUNT(*) as N,
       ROUND(AVG(TRTEDT - TRTSDT), 0) as MEAN_DAYS,
       ROUND(MEDIAN(TRTEDT - TRTSDT), 0) as MEDIAN_DAYS,
       MIN(TRTEDT - TRTSDT) as MIN_DAYS,
       MAX(TRTEDT - TRTSDT) as MAX_DAYS
FROM adsl
WHERE SAFFL = 'Y' AND TRTSDT IS NOT NULL AND TRTEDT IS NOT NULL
GROUP BY TRT01A
```

**If ADEX available:**
```sql
-- Cumulative dose
SELECT adsl.TRT01A,
       ROUND(AVG(adex.AVAL), 1) as MEAN_CUM_DOSE,
       ROUND(MEDIAN(adex.AVAL), 1) as MEDIAN_CUM_DOSE
FROM adex
JOIN adsl ON adex.USUBJID = adsl.USUBJID
WHERE adsl.SAFFL = 'Y' AND adex.PARAMCD = 'TRTDUR'
GROUP BY adsl.TRT01A
```

**Interpretation:**
- Shorter exposure in drug arm may indicate tolerability issues
- Note if exposure is sufficient to detect delayed-onset safety signals
- Dose modifications (reductions, interruptions) may signal tolerability

**Output:** Exposure summary table + assessment.
**Signal flag:** ✓ Comparable exposure | ⚠ Shorter exposure in drug arm

---

### Step 4: Adverse Events Overview

**Goal:** Identify AE signals. This is the most important safety section.

**Invoke the `safety-signal-review` skill for this step.**

Run through Phases 2a-2g of the safety-signal-review framework:
1. Overall AE incidence by arm
2. AEs by SOC — flag arm imbalances
3. Top AEs by PT (≥5% in any arm)
4. Severe (Grade 3+) AEs
5. Serious AEs (SAEs)
6. AEs leading to discontinuation
7. Deaths
8. Related AEs

**Output for each sub-step:** Table/chart + interpretation.
**Signal flag per sub-step:** ✓ No concern | ⚠ Warrants attention | ⛔ Action needed

---

### Step 5: Laboratory Assessments

**Goal:** Identify lab safety signals, particularly hepatotoxicity and hematologic toxicity.

**Invoke the `toxicity-grading` skill for grading criteria.**

**Step 5a: Hepatic Panel**
Parameters: ALT, AST, Bilirubin, ALP
- Grade per CTCAE
- Compare Grade 3+ incidence across arms
- Run Hy's Law screen (ALT >3×ULN AND Bilirubin >2×ULN)

**Step 5b: Hematology**
Parameters: Hemoglobin, WBC, ANC, Platelets
- Grade per CTCAE
- Flag Grade 3+ findings

**Step 5c: Renal**
Parameter: Creatinine
- Grade per CTCAE

**Step 5d: Key Chemistry**
Parameters: Potassium, Sodium, Glucose
- Flag Grade 3+ abnormalities

**Visualization:** For any parameter with signal, show:
- Mean value over time by arm (line plot)
- Individual spaghetti plots for subjects with Grade 3+

**Output:** CTCAE grade summary table + Hy's Law results + interpretation.
**Signal flag:** ✓ No concern | ⚠ Grade 3+ imbalance | ⛔ Hy's Law case identified

---

### Step 6: Vital Signs

**Goal:** Identify clinically meaningful vital sign changes.

**Parameters:** Systolic BP, Diastolic BP, Pulse, Weight

**Step 6a: Mean change from baseline by visit**
```sql
SELECT adsl.TRT01A, advs.AVISIT, advs.AVISITN,
       advs.PARAMCD,
       ROUND(AVG(advs.CHG), 2) as MEAN_CHG,
       COUNT(DISTINCT advs.USUBJID) as N
FROM advs
JOIN adsl ON advs.USUBJID = adsl.USUBJID
WHERE adsl.SAFFL = 'Y' AND advs.ANL01FL = 'Y'
  AND advs.PARAMCD IN ('SYSBP', 'DIABP', 'PULSE', 'WEIGHT')
  AND advs.ABLFL IS NULL
GROUP BY adsl.TRT01A, advs.AVISIT, advs.AVISITN, advs.PARAMCD
ORDER BY advs.PARAMCD, advs.AVISITN
```

**Step 6b: Categorical outliers**
```sql
SELECT adsl.TRT01A,
       SUM(CASE WHEN advs.PARAMCD = 'SYSBP' AND advs.AVAL > 180 THEN 1 ELSE 0 END) as SBP_HIGH,
       SUM(CASE WHEN advs.PARAMCD = 'SYSBP' AND advs.AVAL < 90 THEN 1 ELSE 0 END) as SBP_LOW,
       SUM(CASE WHEN advs.PARAMCD = 'DIABP' AND advs.AVAL > 105 THEN 1 ELSE 0 END) as DBP_HIGH,
       SUM(CASE WHEN advs.PARAMCD = 'PULSE' AND advs.AVAL > 120 THEN 1 ELSE 0 END) as HR_HIGH,
       SUM(CASE WHEN advs.PARAMCD = 'PULSE' AND advs.AVAL < 50 THEN 1 ELSE 0 END) as HR_LOW
FROM advs
JOIN adsl ON advs.USUBJID = adsl.USUBJID
WHERE adsl.SAFFL = 'Y' AND advs.ABLFL IS NULL
GROUP BY adsl.TRT01A
```

**Output:** Mean change table/plot + outlier counts + interpretation.
**Signal flag:** ✓ No concern | ⚠ Dose-dependent trend | ⛔ Clinically significant outliers

---

### Step 7: ECG Assessment

**Goal:** Assess cardiac safety, particularly QTc prolongation.

**Skip if ADEG/EG data not available.** Note: "No ECG dataset available — cardiac safety not assessable from available data."

**If available:**

**Step 7a: QTcF mean change from baseline**
```sql
SELECT adsl.TRT01A, adeg.AVISIT, adeg.AVISITN,
       ROUND(AVG(adeg.CHG), 2) as MEAN_CHG,
       COUNT(DISTINCT adeg.USUBJID) as N
FROM adeg
JOIN adsl ON adeg.USUBJID = adsl.USUBJID
WHERE adsl.SAFFL = 'Y' AND adeg.PARAMCD = 'QTCF'
  AND adeg.ABLFL IS NULL AND adeg.ANL01FL = 'Y'
GROUP BY adsl.TRT01A, adeg.AVISIT, adeg.AVISITN
ORDER BY adeg.AVISITN
```

**Step 7b: QTcF categorical analysis**
```sql
SELECT adsl.TRT01A,
       SUM(CASE WHEN adeg.AVAL > 450 THEN 1 ELSE 0 END) as QTC_GT450,
       SUM(CASE WHEN adeg.AVAL > 480 THEN 1 ELSE 0 END) as QTC_GT480,
       SUM(CASE WHEN adeg.AVAL > 500 THEN 1 ELSE 0 END) as QTC_GT500,
       SUM(CASE WHEN adeg.CHG > 30 THEN 1 ELSE 0 END) as DELTA_GT30,
       SUM(CASE WHEN adeg.CHG > 60 THEN 1 ELSE 0 END) as DELTA_GT60,
       COUNT(DISTINCT adeg.USUBJID) as N_TOTAL
FROM adeg
JOIN adsl ON adeg.USUBJID = adsl.USUBJID
WHERE adsl.SAFFL = 'Y' AND adeg.PARAMCD = 'QTCF'
  AND adeg.ABLFL IS NULL
GROUP BY adsl.TRT01A
```

**Critical:** Any QTcF >500ms in ANY subject = immediate flag.

**Output:** QTcF summary table + categorical analysis + interpretation.
**Signal flag:** ✓ No concern | ⚠ Mean ΔQTcF >10ms | ⛔ Any subject QTcF >500ms or ΔQTcF >60ms

---

### Step 8: Summary of Findings

**Goal:** Consolidate all findings into a prioritized safety summary.

**Format:**

```
## Safety Review Summary — Study [X]

**Population:** [N] subjects in safety population across [K] arms.
**Exposure:** Median [D] days.

### Signals Identified

⛔ [Most concerning finding — describe with n/N (%), both arms]
⚠ [Second finding]
⚠ [Third finding]
...

### Key Safety Observations (No Signal)
✓ [Notable negative finding — e.g., "No hepatotoxicity signal"]
✓ [Another negative finding]

### Recommended Follow-Up Actions
1. [Specific action — e.g., "Patient narratives for 3 subjects with ALT >5×ULN"]
2. [Specific action — e.g., "Subgroup analysis of AEs in patients >65 years"]
3. ...

### Data Limitations
- [Missing data — e.g., "No ECG data available"]
- [Small sample — e.g., "N=30 per arm limits power to detect rare events"]
- [Short exposure — e.g., "Median 12 weeks; long-term signals may not be detected"]
```

---

## Adapting to Data Availability

Not all studies have all datasets. Adapt the checklist:

| Missing Dataset | Impact | What to Tell the User |
|----------------|--------|----------------------|
| ADAE / AE | Cannot assess AEs | "⚠ No adverse event data available — AE safety cannot be assessed" |
| ADLB / LB | Cannot assess lab safety | "⚠ No laboratory data — hepatic, hematologic, renal safety not assessable" |
| ADVS / VS | Cannot assess vitals | "No vital signs data — BP, HR trends not assessable" |
| ADEG / EG | Cannot assess cardiac | "No ECG data — QTc assessment not available" |
| ADEX / EX | Limited exposure info | "No exposure dataset — estimating duration from ADSL treatment dates" |

**If only SDTM (no ADaM) is available:**
- Use DM instead of ADSL (join on USUBJID, use ARM for treatment)
- Use AE instead of ADAE (no TRTEMFL — filter by date relative to first dose)
- Use LB instead of ADLB (no AVAL/BASE/CHG — use LBSTRESN, compute manually)
- Use VS instead of ADVS (use VSSTRESN)
- Use the `sdtm-explorer` skill for variable mappings

## Related Skills

- `safety-signal-review` — Detailed signal detection criteria and methodology
- `toxicity-grading` — CTCAE v5.0 lab grading criteria
- `adam-explorer` — ADaM dataset and variable reference
- `sdtm-explorer` — SDTM domain reference (fallback)
