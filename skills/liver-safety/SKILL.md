---
name: liver-safety
description: >
  Use when evaluating hepatotoxicity, drug-induced liver injury (DILI), Hy's Law,
  or eDISH analysis. Provides the complete evaluation algorithm including
  differential diagnosis, Temple's Corollary, and eDISH plot specification.
  Builds on toxicity-grading for hepatic grading criteria.
---

# Hy's Law / eDISH Evaluation

## Core Criteria

Hy's Law (Hyman Zimmerman, 1978) predicts that a drug causing hepatocellular
injury (elevated ALT) combined with impaired liver function (elevated bilirubin)
carries a 10-50% risk of fatal outcome. The FDA operationalizes this as:

**Hy's Law Case Definition:**
A subject meets Hy's Law criteria when ALL of the following are true:
1. ALT or AST > 3× ULN (evidence of hepatocellular injury)
2. Total bilirubin > 2× ULN (evidence of impaired liver function)
3. No other explanation for the combination (see Evaluation Algorithm below)

**Important:** The ALT and bilirubin elevations do NOT need to occur on the
same day. DILI typically shows ALT rising first, with bilirubin following
days to weeks later. Evaluate each subject's full trajectory.

**Temple's Corollary:**
If a drug causes ALT >3× ULN at a rate significantly higher than comparator,
it has the potential to cause Hy's Law cases. The absence of actual Hy's Law
cases in a small trial does NOT mean the drug is safe — it means the trial
was too small to detect them.

Implication: Even if no subject meets full Hy's Law criteria, a cluster of
ALT >3× ULN subjects is a warning signal.

## eDISH Plot (Evaluation of Drug-Induced Serious Hepatotoxicity)

**Axes:**
- X-axis: Peak ALT (or AST) as multiples of ULN (xULN), **log scale**
- Y-axis: Peak total bilirubin as multiples of ULN (xULN), **log scale**

**Quadrant reference lines:**
- Vertical line at ALT = 3× ULN
- Horizontal line at bilirubin = 2× ULN

**Quadrant definitions:**

```
                    ALT < 3×ULN          |    ALT ≥ 3×ULN
                  _______________________|_______________________
TBILI ≥ 2×ULN   | Temple's Corollary    |  Hy's Law Quadrant
                 | (isolated bilirubin   |  (POTENTIAL DILI)
                 |  ↑ without ALT ↑)     |  → Evaluate per Sec 3
                  _______________________|_______________________
TBILI < 2×ULN   | Normal                |  Hepatocellular
                 | (no concern)          |  (ALT ↑ without bili ↑
                 |                       |   — liver adapting)
```

**Plot specification:**
- Each point = one subject (peak post-baseline values)
- Color/shape by treatment arm
- Log scale on both axes (range: 0.1 to max observed × 1.5)
- Optional: trajectory lines connecting sequential visits per subject

**DuckDB SQL for eDISH data:**

```sql
-- Extract peak ALT and peak bilirubin per subject
WITH peak_alt AS (
  SELECT USUBJID, MAX(AVAL / NULLIF(A1HI, 0)) AS peak_alt_xuln
  FROM adlb
  WHERE PARAMCD IN ('ALT', 'SGPT')
    AND ANL01FL = 'Y' AND ABLFL IS DISTINCT FROM 'Y'
  GROUP BY USUBJID
),
peak_bili AS (
  SELECT USUBJID, MAX(AVAL / NULLIF(A1HI, 0)) AS peak_bili_xuln
  FROM adlb
  WHERE PARAMCD IN ('BILI', 'BILITOT')
    AND ANL01FL = 'Y' AND ABLFL IS DISTINCT FROM 'Y'
  GROUP BY USUBJID
)
SELECT
  adsl.USUBJID, adsl.TRT01A,
  a.peak_alt_xuln, b.peak_bili_xuln,
  CASE
    WHEN a.peak_alt_xuln >= 3 AND b.peak_bili_xuln >= 2 THEN 'Hy''s Law'
    WHEN a.peak_alt_xuln >= 3 AND b.peak_bili_xuln < 2  THEN 'Hepatocellular'
    WHEN a.peak_alt_xuln < 3  AND b.peak_bili_xuln >= 2 THEN 'Temple''s Corollary'
    ELSE 'Normal'
  END AS edish_quadrant
FROM adsl
LEFT JOIN peak_alt a ON adsl.USUBJID = a.USUBJID
LEFT JOIN peak_bili b ON adsl.USUBJID = b.USUBJID
WHERE adsl.SAFFL = 'Y'
```

## Hy's Law Evaluation Algorithm

When a subject falls in the Hy's Law quadrant (ALT ≥3× ULN AND TBILI ≥2× ULN),
apply this differential diagnosis algorithm:

```
Step 1: CONFIRM THE VALUES
  → Verify ALT and bilirubin are from the same subject
  → Check for data entry errors, unit inconsistencies
  → Review the time course (ALT peak → bilirubin peak)

Step 2: RULE OUT BILIARY OBSTRUCTION
  → Check ALP: if ALP > 2× ULN, obstruction possible
  → If ALP/ALT ratio (R-value) < 2: hepatocellular (Hy's Law still applies)
  → If R-value 2-5: mixed pattern (investigate further)
  → If R-value > 5: cholestatic (less likely DILI, but don't dismiss)
  → R-value = (ALT / ALT_ULN) / (ALP / ALP_ULN)

Step 3: RULE OUT GILBERT SYNDROME
  → Check if bilirubin is predominantly indirect/unconjugated
  → Gilbert's: mild bilirubin ↑ (usually <3× ULN), no ALT ↑
  → If direct bilirubin available: direct/total ratio >0.35 suggests
    hepatocellular damage (not Gilbert's)

Step 4: RULE OUT OTHER HEPATOTOXINS
  → Check concomitant medications (CM domain):
    acetaminophen, statins, methotrexate, isoniazid, phenytoin,
    amoxicillin-clavulanate, herbal supplements
  → Check medical history (MH domain):
    chronic hepatitis B/C, alcoholic liver disease, NAFLD,
    autoimmune hepatitis
  → Check for acute viral hepatitis (if serology available)

Step 5: TEMPORAL RELATIONSHIP
  → Did the ALT rise start AFTER drug initiation?
  → Latency: typical DILI is 5-90 days after first dose
  → Did values improve after drug discontinuation (dechallenge)?
  → Did values worsen after rechallenge (if applicable)?

Step 6: CLASSIFY
  → Definite Hy's Law case: criteria met, no alternative explanation
  → Probable: criteria met, alternative explanation unlikely
  → Possible: criteria met, alternative explanation present but uncertain
  → Unlikely: clear alternative explanation accounts for findings
```

## Key Thresholds Summary

| Measure | Threshold | Significance |
|---------|-----------|-------------|
| ALT > 3× ULN | Hy's Law criterion 1 | Hepatocellular injury |
| ALT > 5× ULN | CTCAE Grade 3 | Severe hepatotoxicity |
| ALT > 8× ULN | — | "Hy's Law plus" — very high concern |
| ALT > 10× ULN | — | Severe DILI signal |
| ALT > 20× ULN | CTCAE Grade 4 | Life-threatening |
| TBILI > 2× ULN | Hy's Law criterion 2 | Impaired liver function |
| TBILI > 3× ULN | CTCAE Grade 3 | Severe |
| ALP > 2× ULN | Cholestasis flag | Evaluate R-value |
| R-value < 2 | — | Hepatocellular (Hy's Law applies) |
| R-value > 5 | — | Cholestatic (less likely DILI) |

## Monitoring Recommendations

When Hy's Law signal detected:
1. **Immediate:** Pull all liver function data for affected subjects (ALT, AST,
   ALP, TBILI, direct bilirubin, albumin, INR if available)
2. **Subject-level:** Generate spaghetti plots of ALT and TBILI over time
3. **Compare arms:** Count subjects with ALT >3× ULN, >5× ULN, >10× ULN per arm
4. **Temporal analysis:** Time from first dose to peak ALT per subject
5. **Dechallenge:** Did values recover after dose reduction or discontinuation?

## Related Skills

- Use `toxicity-grading` for hepatic parameter grading criteria
- Use `adam-explorer` for ADLB variable lookup
- Use `safety-signal-review` Phase 3 for the broader lab safety review
- Use `clinical-graphics` for eDISH plot visual specification
