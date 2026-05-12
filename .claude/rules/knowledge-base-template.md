---
paths:
  - "R/**/*.R"
  - "reports/**/*.qmd"
  - "templates/**/*.R"
---

# Project Knowledge Base: [YOUR PROJECT NAME]

<!-- Fill in the tables below with project-specific content. Claude reads
     this before writing any R script or report so the work matches the
     project's notation, datasets, and identification strategy. -->

## Estimand Registry

| Estimand | Definition | Identifying Assumption | Estimator | Reference |
|---|---|---|---|---|
| ATT | E[Y(1) − Y(0) \| D=1] | Parallel trends + no anticipation | `did::att_gt`, `did2s::did2s` | Callaway–Sant'Anna (2021) |
| | | | | |

## Notation Registry

| Symbol | Meaning | Used in | Anti-pattern |
|---|---|---|---|
| `Y_{it}` | Outcome for unit i in period t | reports/, R/ | don't use `y_it` (different variable) |
| `D_{it}` | Treatment indicator | reports/ | |
| | | | |

## Variable Naming (R)

| Variable | Type | Description | Constructed in |
|---|---|---|---|
| `treated` | int | 1 if ever-treated unit | `R/02_construct/sample.R` |
| `post` | int | 1 if t ≥ treatment year | `R/02_construct/sample.R` |
| `log_y` | num | log(outcome + 1) | `R/02_construct/sample.R` |
| | | | |

## Dataset Registry

| Dataset | Source | Vintage | Unit | N | Restrictions | Used in |
|---|---|---|---|---|---|---|
| Main panel | [agency] | [YYYY] | unit-year | [N] | [restrictions] | `R/03_analysis/*` |
| | | | | | | |

## Identification Assumptions

| Assumption | Where invoked | How tested |
|---|---|---|
| Parallel trends | DiD spec (`R/03_analysis/main_did.R`) | event-study leads, `HonestDiD` sensitivity |
| Exogeneity of Z | IV spec (`R/03_analysis/iv_main.R`) | first-stage F, AR CIs, Hausman |
| | | |

## Sample Restrictions

| Restriction | Rationale | Drops N | Applied in |
|---|---|---|---|
| Drop singletons | `feols(... fixef.rm = "perfect")` | logged at runtime | `R/03_analysis/*` |
| Restrict to balanced panel | for event-study spec | [N] | `R/02_construct/balanced.R` |
| | | | |

## Empirical Applications (if replication-based)

| Application | Paper | Dataset | Stage | Purpose |
|---|---|---|---|---|
| | | | | |

## Design Principles

| Principle | Evidence | Applied where |
|---|---|---|
| Cluster at most aggregate plausible level | BDM 2004; AAIW 2023 | every `R/03_analysis/*` |
| Show pre-trends explicitly | best practice in DiD | event-study figures |
| | | |

## Anti-Patterns (Don't Do This)

| Anti-Pattern | What Happened | Correction |
|---|---|---|
| Used `lm` + HC robust SEs without clustering | within-cluster correlation ignored | switched to `feols(... cluster = ~id)` |
| | | |

## R Pitfalls (Project-Specific)

| Pitfall | Impact | Fix |
|---|---|---|
| `dplyr::left_join(..., by = "id")` without checking unmatched rows | silent dropped rows | always check `n_distinct(df$id)` before/after; use `relationship = "many-to-one"` to assert |
| `fixest::feols(...)` without `cluster =` | wrong SEs | always specify `cluster = ~ <var>` |
| `read_csv(..., col_types = cols())` swallowing parse errors | silent NA introduction | inspect `problems(df)` after read |
| | | |

## Tolerance Thresholds (Project-Specific Override)

If your project needs tighter or looser tolerances than `quality-gates.md` defaults, document them here.

| Quantity | Tolerance | Rationale |
|---|---|---|
| | | |
