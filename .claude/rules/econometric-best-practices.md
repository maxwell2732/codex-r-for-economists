---
paths:
  - "R/03_analysis/**/*.R"
  - "R/04_output/**/*.R"
  - "templates/**/*.R"
  - "explorations/**/*.R"
---

# Econometric Best Practices

A set of defaults aligned with current top empirical economics practice. Every R script may deviate, but every deviation must be **deliberate and documented**.

---

## 1. Standard Errors

**Default: cluster at the most aggregate plausible level.**

| Setting | Default cluster | Rationale |
|---|---|---|
| Panel data | unit (e.g., firm, individual) | within-unit serial correlation |
| DiD with state-level treatment | state | within-state correlation; per Bertrand–Duflo–Mullainathan (2004) |
| Unit-of-treatment varies | level of treatment assignment | per Abadie–Athey–Imbens–Wooldridge (2023) |
| Clustered with few clusters (G < ~30) | wild bootstrap (`fwildclusterboot::boottest`) | t-distribution unreliable |
| IV / 2SLS | same cluster as OLS counterpart | consistency |

In `fixest::feols`, cluster via `cluster = ~ unit_id`; in `estimatr::lm_robust`, via `clusters = unit_id`; in `sandwich`, via `vcovCL(model, cluster = ~unit_id)`.

HC robust SEs without clustering (`sandwich::vcovHC`, `feols(..., vcov = "hetero")`) are the **wrong default** when within-unit correlation is plausible. If using HC robust, the script must comment why clustering is unnecessary.

> Note: `feols` and Stata's `reghdfe` use different cluster df-adjustments by default. To match Stata exactly, pass `ssc = ssc(adj = TRUE, cluster.adj = TRUE)`.

---

## 2. Fixed Effects

- Use `fixest::feols` for high-dimensional FE absorption; document the FE choice in a comment
- Absorb via `| fe1 + fe2`, NOT by entering factors as regressors (slower + worse SEs)
- Drop singletons with `fixef.rm = "perfect"`; report N before/after in the log
- Two-way clustering: `cluster = ~unit_id + year`
- For event studies, prefer `fixest::feols(y ~ i(time_to_treat, treated, ref = -1))`. Avoid the canonical TWFE estimator when treatment timing varies (use Callaway–Sant'Anna via `did::att_gt`, de Chaisemartin–D'Haultfoeuille via `DIDmultiplegt::did_multiplegt`, Sun–Abraham implemented natively in `fixest`, or Borusyak–Jaravel–Spiess via `did2s::did2s` instead)

---

## 3. Sample Selection

Every analysis script logs:

```r
cat("Sample N before restrictions:", nrow(df), "\n")
df <- df %>% filter(<condition_1>)
cat("After restriction 1 (<rationale>):", nrow(df), "\n")
df <- df %>% filter(<condition_2>)
cat("After restriction 2 (<rationale>):", nrow(df), "\n")
```

So a reviewer can reconstruct the funnel from the log alone.

---

## 4. Weights

| Use case | R approach |
|---|---|
| Sampling weights (population inference) | `feols(..., weights = ~svy_wt)` or `survey::svyglm` for full survey design |
| Analytic weights (cell-mean variance) | `lm(..., weights = group_size)` — when the dependent var is a mean over groups |
| Frequency weights (replicated rows) | row-replicate before estimation, or use `fweights` in packages that support them (`data.table` aggregations) |
| Importance weights | rare; package-specific |

**Never** combine sampling weights and clustered SEs without confirming the package supports the combination — `feols` does, `lm` + `sandwich::vcovCL` does, but some specialty packages don't.

---

## 5. Instrumental Variables

- Report **first-stage F** for every IV spec. In `fixest::feols`, the IV syntax is `feols(y ~ x1 | fe | endog ~ z, data = ...)`; use `fitstat(model, type = "ivf")` or `summary(model, stage = 1)`.
- For weak-instrument-robust inference, use `ivmodel::AR.test` or `weakIV` for Anderson–Rubin / Olea–Pflueger
- F < 10 is a red flag; F < ~24 (Lee et al. 2022) requires reporting Anderson–Rubin CIs
- For wild-cluster bootstrap with IV, use `fwildclusterboot::boottest` after fitting via `feols`

---

## 6. Multiple Hypothesis Testing

If the script estimates ≥ 5 coefficients on the same family of outcomes, report:
- **Raw p-values**, AND
- **Adjusted p-values**: Bonferroni / Holm via `p.adjust(p, method = "bonferroni")`, or Romano–Wolf via the `wyoung` package

Document in the table notes which adjustment is used.

---

## 7. DiD-Specific

- **Show pre-trends** explicitly (event-study leads non-significant) — `feols(y ~ i(time_to_treat, treated, ref = -1))` then `iplot()` or `fixest::ggiplot()`
- **Visualize**: event-study plot of leads + lags with 95% CIs
- **Robustness**: at minimum, both TWFE and one heterogeneity-robust estimator: `did::att_gt` (Callaway–Sant'Anna), `DIDmultiplegt::did_multiplegt` (de Chaisemartin–D'Haultfoeuille), Sun–Abraham via `fixest`, or `did2s::did2s`
- **Honest DiD** sensitivity (`HonestDiD` package) when the parallel-trends assumption is plausibly violated

---

## 8. Bootstrap & Simulation

- Reps ≥ 999 for production (use 99 or 199 for development; document in code)
- Wild cluster bootstrap (`fwildclusterboot::boottest`) when G < ~30
- Set seed once at top of the script, never inside the bootstrap loop
- For parallelisation, use `future_lapply(..., future.seed = TRUE)`. Plain `mclapply()` does not yield reproducible streams.
- Save the bootstrap distribution (`saveRDS`) so reviewers can audit

---

## 9. Reporting

Every regression table includes:
- N (always)
- R² (when meaningful — for fixed-effects-absorbed regressions, `fixest` reports within-R² automatically)
- Mean of dependent variable (`modelsummary` exposes via `gof_map`; or compute with `mean(df$y, na.rm = TRUE)` and pass via `add_rows`)
- Cluster level + count
- FE included
- Control set indicator

Use `modelsummary(models, gof_omit = "AIC|BIC|Log.Lik|RMSE", notes = c("Standard errors clustered at <level>.", ...))`.

---

## 10. Robustness Section

Every paper-ready script produces a robustness section that varies one thing at a time:
- Alternative outcome definition
- Alternative sample restriction
- Alternative cluster level
- Alternative SE method (boot / HC / CR1)
- Alternative FE specification
- Drop influential observations / winsorize (`DescTools::Winsorize`)

Pre-commit, the `econometric-reviewer` agent verifies these are present.

---

## 11. Double / Debiased Machine Learning (DDML)

When to reach for DDML (Chernozhukov et al. 2018) instead of OLS-with-controls:
- High-dimensional controls (you have many candidate covariates and don't want to pre-select)
- The first-stage / nuisance functions (E[Y | X], E[D | X]) are plausibly non-linear
- The estimand is a low-dimensional structural parameter (treatment effect, partial coefficient)

### Default workflow

- **Package:** `ddml` (Ahrens-Hansen-Schaffer-Wiemann) for partial-linear and
  partial-IV models. `DoubleML` for more general moment conditions
  (interactive regression, IV-IRM, etc.) and richer mlr3-backed learners.
- **Default learners (stacking is preferred):**
  - `glmnet` — sparse linear baseline (cv-tuned lambda)
  - `ranger` — random forest, robust default for non-linear nuisance
  - `xgboost` — gradient-boosted trees, often the strongest single learner
  - In `ddml`, pass these as a list to `learners = ` and the package stacks them
    via cross-validated weights
- **Cross-fitting:** `n_folds = 5` is the Chernozhukov et al. baseline. Use 10
  for small N (< ~1,000); 5 for production-scale data.
- **Sample-splitting hygiene:** never tune learner hyper-parameters on the same
  fold used for the moment-condition residual. The `ddml` API enforces this;
  if you write a custom DML loop, make sure of it manually.

### Reporting

Every DDML estimate must report:
- Point estimate + asymptotic SE from the cross-fit influence function
- Cross-fit fold count (`n_folds`)
- Learner stack (and final stacking weights, if shown)
- Number of cross-fitting repetitions if `n_rep > 1` (median-aggregation reduces simulation noise)
- Sensitivity check: refit with one alternative learner-stack (e.g., glmnet alone) and document the change in estimate

### Common pitfalls

| Pitfall | Why it bites | Fix |
|---|---|---|
| Tuning learners on the full sample then plugging into DDML | Sample-splitting violated; SEs invalid | Tune inside the cross-fitting loop (`ddml` does this when the learner is wrapped in `mlr3::AutoTuner` or similar) |
| `n_folds = 2` for speed | Bias-variance trade-off lost; estimates noisy | Stick to >= 5; the cost is linear in fold count and most ML learners are O(N log N) anyway |
| Reporting bootstrap SEs instead of the influence-function SE | DDML's SE comes from the moment condition; bootstrapping over folds re-introduces sample-splitting bias | Report `summary(model)`'s default SE, not `boot::boot()`-derived |
| Single learner (e.g., only random forest) | Sensitive to learner mis-specification | Stack at least 2 — `ddml` makes this trivial |

---

## 12. Survival / Cox Hazard Analysis

When the outcome is time-to-event (and some observations are censored): use
the `survival` package (ships with R as a recommended package).

### Specifying the outcome

The outcome is constructed via `Surv()`:
- **Right-censored** (the most common case): `Surv(time, event)` where `event = 1` if the event occurred and `0` if censored at `time`.
- **Left-truncated / counting-process form** (time-varying covariates, late entry): `Surv(start, stop, event)`.
- **Interval-censored**: `Surv(time, time2, event, type = "interval")`.

Document in the script header which censoring pattern applies AND the censoring
rate (`mean(df$event == 0)`).

### Default models

- **Kaplan-Meier survival curves:** `survfit(Surv(time, event) ~ group, data = df)`. Plot via `survminer::ggsurvplot()`.
- **Log-rank test for group differences:** `survdiff(Surv(time, event) ~ group, data = df)`.
- **Cox proportional-hazards model:** `coxph(Surv(time, event) ~ x1 + x2 + strata(z), data = df)`. Report the HR + 95% CI, not just the log-HR.

### Diagnostics

- **Proportional-hazards (PH) assumption:** `cox.zph(model)` returns a per-covariate test plus a global test. Plot via `ggcoxzph()` or the base `plot()`. Reject => the PH assumption fails for that covariate; use `tt()` for a time-varying coefficient or stratify by it.
- **Functional form of continuous covariates:** Martingale residuals via `ggcoxfunctional()`.
- **Influential observations:** dfbeta residuals (`ggcoxdiagnostics(model, type = "dfbeta")`).

### Time-varying covariates

NEVER include `time-by-X` interactions inside `coxph()` directly — that estimates a Cox model with constant coefficients. To allow a coefficient to vary with time, expand the data into start-stop format with `survival::tmerge()` or `survSplit()`, then re-fit on the expanded data.

### Reporting

Every Cox estimate must report:
- N events / N at risk
- HR with 95% CI for every coefficient (`broom::tidy(model, exponentiate = TRUE, conf.int = TRUE)`)
- Concordance index (`summary(model)$concordance`) as a goodness-of-fit metric
- `cox.zph` global p-value in a footnote; per-covariate p-values when the global test rejects
- Censoring rate

### Common pitfalls

| Pitfall | Why it bites | Fix |
|---|---|---|
| Treating censoring as missing-at-random by `na.omit()` then OLS on log(time) | Throws away censored observations; biases everything | Use `Surv()` + `coxph` / `survreg` |
| Reporting log-HR instead of HR | Reviewers always ask for HR | `exp(coef(model))` or `tidy(model, exponentiate = TRUE)` |
| Skipping `cox.zph` | PH violation can flip the sign of the inference | Always run; if violated, stratify or use time-varying coefficients |
| Including `event` itself on the right-hand side | Tautology / data leakage | Don't — the outcome is `Surv(time, event)`, not `event` |
