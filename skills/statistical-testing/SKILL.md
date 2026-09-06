---
name: statistical-testing
description: >
  Use when performing hypothesis tests, group comparisons, regression, correlation,
  power analysis, or effect size calculation on clinical trial data. Covers test
  selection, assumption checking, remedial actions, and interpretation for treatment
  arm comparisons, baseline characteristics, and endpoint analysis. Complements
  safety-signal-review (which uses statistical thresholds but not general tests).
---

# Statistical Analysis for Clinical Trials

## Test Selection Guide

Choose the test based on the research question and data characteristics.

### Comparing Two Treatment Arms

| Data | Normal | Non-Normal |
|------|--------|------------|
| Independent, continuous | Independent t-test (Welch's) | Mann-Whitney U |
| Paired / repeated measure | Paired t-test | Wilcoxon signed-rank |
| Binary outcome | Chi-square / Fisher's exact | — |

### Comparing 3+ Arms (Dose Groups)

| Data | Normal | Non-Normal |
|------|--------|------------|
| Independent, continuous | One-way ANOVA | Kruskal-Wallis |
| Repeated measure | Repeated measures ANOVA | Friedman |

### Relationships

| Question | Test |
|----------|------|
| Two continuous variables | Pearson r (normal) or Spearman ρ |
| Continuous outcome + predictors | Linear regression |
| Binary outcome + predictors | Logistic regression |
| Time-to-event | Cox PH → see `time-to-event-analysis` skill |

### Multiple Comparisons

When testing multiple endpoints or subgroups, correct for family-wise error:
- **Bonferroni**: Conservative, divide α by number of tests
- **Holm-Bonferroni**: Step-down, less conservative
- **Benjamini-Hochberg**: Controls FDR, preferred for exploratory subgroup analyses
- **No correction needed**: Pre-specified primary endpoint tested once

## Assumption Checking

**Always check assumptions before interpreting results.**

### Normality

```python
from scipy import stats

# Shapiro-Wilk (n < 5000)
stat, p = stats.shapiro(values)
# If p < 0.05: normality violated
```

**Remedial actions:**
- Mild violation + n > 30 per arm → proceed with parametric test (CLT)
- Moderate violation → use non-parametric alternative
- Severe violation → transform data (log, sqrt) or use non-parametric

### Homogeneity of Variance

```python
from scipy import stats

# Levene's test across treatment arms
stat, p = stats.levene(arm_a_values, arm_b_values)
# If p < 0.05: variances unequal
```

**Remedial actions:**
- t-test → use Welch's t-test (default in most libraries)
- ANOVA → use Welch's ANOVA
- Regression → use robust standard errors (HC3)

### Linearity (Regression)

Plot residuals vs fitted values. If pattern is visible:
- Add polynomial terms
- Transform the predictor
- Use GAM (generalized additive model)

## Running Tests on Clinical Data

### Baseline Characteristics Comparison

Query baseline data, then test for imbalance across arms:

```sql
-- Continuous variable: age by treatment arm
SELECT TRT01A,
       COUNT(*) AS n,
       ROUND(AVG(AGE), 1) AS mean_age,
       ROUND(STDDEV(AGE), 1) AS sd_age
FROM adsl
WHERE ITTFL = 'Y'
GROUP BY TRT01A
```

```python
from scipy import stats

# Test continuous baseline variable
t_stat, p_val = stats.ttest_ind(arm_a_age, arm_b_age, equal_var=False)

# Test categorical baseline variable (e.g., sex)
contingency = pd.crosstab(df['TRT01A'], df['SEX'])
chi2, p_val, dof, expected = stats.chi2_contingency(contingency)
# If any expected cell < 5, use Fisher's exact instead
```

### Treatment Effect on Continuous Endpoint

```sql
-- Change from baseline for a lab parameter
SELECT TRT01A, PARAMCD,
       COUNT(DISTINCT USUBJID) AS n,
       ROUND(AVG(CHG), 2) AS mean_chg,
       ROUND(STDDEV(CHG), 2) AS sd_chg
FROM adlb
WHERE AVISIT = 'Week 12' AND ANL01FL = 'Y'
GROUP BY TRT01A, PARAMCD
```

```python
# ANCOVA: change from baseline adjusted for baseline value
import statsmodels.formula.api as smf

model = smf.ols('CHG ~ C(TRT01A) + BASE', data=df).fit()
print(model.summary())
# Treatment effect = coefficient on C(TRT01A)[T.Drug]
```

### Binary Endpoint Comparison

```sql
-- Response rate by arm
SELECT TRT01A,
       COUNT(DISTINCT CASE WHEN AVALC = 'Y' THEN USUBJID END) AS responders,
       COUNT(DISTINCT USUBJID) AS n
FROM adrs
WHERE PARAMCD = 'OVRLRESP' AND ANL01FL = 'Y'
GROUP BY TRT01A
```

```python
from scipy import stats

# Fisher's exact for small samples
odds_ratio, p_val = stats.fisher_exact([[a_resp, a_nonresp],
                                         [b_resp, b_nonresp]])
```

## Effect Sizes

**Always report effect sizes alongside p-values.** P-values indicate existence;
effect sizes quantify magnitude.

### Quick Reference

| Test | Effect Size | Small | Medium | Large |
|------|-------------|-------|--------|-------|
| t-test | Cohen's d | 0.20 | 0.50 | 0.80 |
| ANOVA | η²_p | 0.01 | 0.06 | 0.14 |
| Correlation | r | 0.10 | 0.30 | 0.50 |
| Regression | R² | 0.02 | 0.13 | 0.26 |
| Chi-square | Cramér's V | 0.07 | 0.21 | 0.35 |

Benchmarks are guidelines — clinical context determines what matters.

### Calculation with pingouin

```python
import pingouin as pg

# t-test with effect size
result = pg.ttest(arm_a, arm_b, correction='auto')
d = result['cohen-d'].values[0]
ci = result['CI95%'].values[0]

# ANOVA with effect size
aov = pg.anova(dv='CHG', between='TRT01A', data=df, detailed=True)
eta_p2 = aov['np2'].values[0]

# Post-hoc with Tukey HSD (if ANOVA significant)
posthoc = pg.pairwise_tukey(dv='CHG', between='TRT01A', data=df)
```

## Power Analysis

### A Priori (Study Planning)

```python
from statsmodels.stats.power import tt_ind_solve_power, FTestAnovaPower

# t-test: sample size to detect d = 0.5
n = tt_ind_solve_power(effect_size=0.5, alpha=0.05, power=0.80,
                       ratio=1.0, alternative='two-sided')

# ANOVA: sample size for 3 dose groups
anova_power = FTestAnovaPower()
n_per_group = anova_power.solve_power(effect_size=0.25, ngroups=3,
                                      alpha=0.05, power=0.80)
```

### Sensitivity (Post-Study)

Determine the minimum detectable effect given the actual sample size:

```python
# With n=50 per arm, what effect could we detect?
detectable_d = tt_ind_solve_power(effect_size=None, nobs1=50,
                                  alpha=0.05, power=0.80,
                                  ratio=1.0, alternative='two-sided')
```

**Note:** Post-hoc power (calculating power after results) is discouraged.
Use sensitivity analysis instead: "This study had 80% power to detect d ≥ X."

## Interpretation Rules

1. **State the finding factually.** "Mean change from baseline in LDL was
   -15.2 mg/dL (drug) vs -3.1 mg/dL (placebo), difference -12.1 mg/dL
   (95% CI: -16.8, -7.4), p < 0.001, d = 0.62."
2. **Report both arms side-by-side** with n, mean, SD.
3. **Report effect size with CI** — not just p-value.
4. **Distinguish statistical from clinical significance.** A p < 0.001 with
   d = 0.15 may be statistically significant but clinically meaningless.
5. **Do NOT use p-value as a gate** for safety findings — see
   `safety-signal-review` for clinical signal criteria.

## Common Pitfalls

- **Multiple testing without correction**: Testing 20 endpoints at α=0.05
  yields ~1 false positive on average
- **Ignoring assumptions**: Unequal variance inflates Type I error for pooled t-test
- **P-hacking**: Testing multiple subgroups until one is significant —
  always pre-specify primary analysis
- **Confusing significance with importance**: Report effect sizes
- **Post-hoc power**: Circular — use sensitivity analysis instead

## Related Skills

- `safety-signal-review` — statistical thresholds for safety signals (IR ≥2.0, RD ≥5pp)
- `time-to-event-analysis` — time-to-event methods (Cox PH, KM, C-index)
- `oncology-endpoints` — outcome metric definitions (OS, PFS, ORR, RECIST 1.1)
- `adam-explorer` — ADaM dataset and variable reference
- `clinical-graphics` — forest plots, line plots for presenting results
