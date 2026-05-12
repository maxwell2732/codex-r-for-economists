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
