---
paths:
  - "R/**/*.R"
  - "templates/replication-targets.md"
  - "quality_reports/**"
---

# Replication-First Protocol

**Core principle:** replicate the original results to the dot BEFORE extending. No extension makes sense if the baseline is wrong.

---

## Phase 1: Inventory & Baseline

Before writing any R script:

- [ ] Read the paper's replication README
- [ ] Inventory the replication package: language (Stata / R / Matlab / Python), data files, scripts, outputs
- [ ] Record gold-standard numbers in `templates/replication-targets.md` → save to `quality_reports/<paper>_replication_targets.md`:

```markdown
## Replication Targets: [Paper Author (Year)]

| Target | Table/Figure | Value | SE/CI | Notes |
|--------|--------------|-------|-------|-------|
| Main ATT | Table 2, Col 3 | -1.632 | (0.584) | Primary specification, clustered at state |
| First-stage F | Table 3, Panel A | 28.4 |  — | Weak-instrument test |
| Sample size | Table 1 | 12,453 |  — | After all restrictions |
```

- [ ] Mark each target MUST / SHOULD / MAY (per `templates/requirements-spec.md` framework)

---

## Phase 2: Translate & Execute

- [ ] Follow `r-coding-conventions` for all scripts
- [ ] Translate **line-by-line** initially — don't "improve" during replication
- [ ] Match the original specification exactly: covariates, sample restrictions, clustering, SE method, weights
- [ ] Save all intermediate results as `.rds` in `data/derived/` (gitignored)

### Common Translation Pitfalls

#### Stata → R

This is the most common direction (most empirical replication packages ship as `.do` files).

| Stata | R equivalent | Trap |
|---|---|---|
| `reg y x, cluster(id)` | `feols(y ~ x, cluster = ~id, data = df)` (`fixest`) | `feols` defaults to `t(n-1)/(n-k)` correction; Stata also multiplies by `G/(G-1)`. To match Stata exactly: `ssc = ssc(adj = TRUE, cluster.adj = TRUE)`. |
| `areg y x, absorb(id)` | `feols(y ~ x \| id, data = df)` | Different demeaning method; small-sample df differs |
| `reghdfe y x, absorb(id1 id2) cluster(id1)` | `feols(y ~ x \| id1 + id2, cluster = ~id1, data = df)` | Singleton drop default differs (`reghdfe` drops; `feols` keeps unless `fixef.rm = "perfect"`) |
| `ivreg2 y (x = z), cluster(id)` | `feols(y ~ 1 \| 0 \| x ~ z, cluster = ~id, data = df)` or `AER::ivreg(y ~ x \| z, data = df)` | First-stage F definition differs |
| `probit y x` | `glm(y ~ x, family = binomial(link = "probit"), data = df)` | R default link in `glm(family = binomial)` is logit — set explicitly |
| `bootstrap "reg ...", reps(999)` | `boot::boot()` / `fwildclusterboot::boottest` | Match seed, reps, AND bootstrap type (pairs vs wild) |

#### R → R (cross-package)

| Source | Target | Trap |
|---|---|---|
| `lm` + `sandwich::vcovHC` | `feols(... vcov = "hetero")` | `vcovHC` defaults to HC3; `feols` `"hetero"` is HC1 |
| `lm` + `lmtest::coeftest(..., vcov = vcovCL(..., cluster = ~id))` | `feols(... cluster = ~id)` | Cluster df-adjustment differs by ~G/(G-1) factor |
| `plm(..., model = "within")` | `feols(... \| unit)` | `plm` uses different small-sample correction |

#### R → Python

| R | Python equivalent | Trap |
|---|---|---|
| `feols(y ~ x, cluster = ~id)` | `linearmodels.PanelOLS(...).fit(cov_type="clustered", clusters=id)` | df adjustment differences; `linearmodels` defaults to HC0 for non-clustered |
| `glm(family = binomial(link = "probit"))` | `statsmodels.Probit(...)` | `Probit` has its own SE calculation; for clustered SEs use `cov_kwds={"groups": id, "use_correction": True}` |

---

## Phase 3: Verify Match

Use tolerances from `quality-gates.md`. If outside tolerance:

**Do NOT proceed to extensions.** Isolate which step introduces the difference:

1. Sample size — check `filter`/`drop_na` ordering and missing-value handling
2. SE computation — check cluster level, df adjustment, weights
3. Default options — many functions have changed defaults across major versions
4. Variable definitions — log-of-zero handling, winsorization, top-coding

Document the investigation in the replication report **even if unresolved**. An unreplicated result is informative; a glossed-over discrepancy is fraud.

### Replication Report

Save to `quality_reports/<paper>_replication_report.md` (template in `templates/`):

```markdown
# Replication Report: [Paper Author (Year)]
**Date:** [YYYY-MM-DD]
**Original language:** [Stata 15 / R 4.x / etc.]
**Our implementation:** R/<path>

## Summary
- **Targets checked / Passed / Failed:** N / M / K
- **Overall:** [REPLICATED / PARTIAL / FAILED]

## Results Comparison

| Target | Paper | Ours | Diff | Status |
|--------|-------|------|------|--------|

## Discrepancies (if any)
- **Target:** X
  - **Investigation:** ...
  - **Resolution:** [resolved / unresolved with documented hypothesis]

## Environment
- R version + key package versions (from `logs/00_main.log`)
- `renv.lock` snapshot date
- Data source + vintage
```

---

## Phase 4: Only Then Extend

After replication is verified (all MUST targets PASS):

- [ ] Commit the replication: `Replicate <Paper> Tables 2–4: all targets within tolerance`
- [ ] Now extend with project-specific modifications (alternative estimators, new outcomes, robustness)
- [ ] Each extension builds on the verified baseline
- [ ] If an extension's result diverges in spirit from the replication baseline, that's a research finding worth understanding — not a bug to suppress
