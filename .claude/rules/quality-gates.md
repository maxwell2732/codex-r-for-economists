---
paths:
  - "R/**/*.R"
  - "reports/**/*.qmd"
  - "scripts/**/*.py"
  - "templates/**/*.R"
---

# Quality Gates & Scoring Rubrics

## Thresholds

- **80/100 = Commit** — good enough to save
- **90/100 = PR** — ready for deployment
- **95/100 = Excellence** — aspirational

Run `python scripts/quality_score.py <file>` to score a single artifact.

---

## R Scripts (`R/**/*.R`)

| Severity | Issue | Deduction |
|---|---|---|
| Critical | `Error in` / `Execution halted` in most recent log | -100 |
| Critical | Hardcoded absolute path (`"C:\..."` or `"/home/..."`) | -25 |
| Critical | `setwd()` call (forbidden — use `here::here()` / `proj_path()`) | -25 |
| Critical | Missing R version pin (`if (getRversion() < ...) stop(...)`) | -15 |
| Critical | No log opened (no `start_log()` / `sink()` / `log4r::`) | -15 |
| Major | Missing file header block (7 fields) | -8 |
| Major | Missing `set.seed()` when randomness used | -10 |
| Major | Magic number (4+ digits) inside an estimation call | -3 each (cap -15) |
| Major | Estimation result not assigned to a name (`models[["m"]] <- feols(...)`) | -5 |
| Minor | Section banners missing or inconsistent | -2 |
| Minor | Commented-out dead code (`# library(...)`, `# feols(...)`) | -2 each (cap -8) |
| Minor | Lines > 100 chars | -1 each (cap -10) |

## Quarto Reports (`reports/*.qmd` with knitr / R engine)

| Severity | Issue | Deduction |
|---|---|---|
| Critical | Render failure | -100 |
| Critical | Numerical claim without log citation (per `log-verification-protocol`) | -30 each |
| Critical | Inline analysis call (`feols`/`lm`/`glm`/`ivreg`/`did2s`) inside an `{r}` chunk — analysis belongs in `R/`, not in the report | -30 |
| Critical | Broken citation key | -15 |
| Critical | Missing required section (Abstract, Data, Method, Results) | -10 each |
| Major | Table not read from `output/tables/` | -10 |
| Major | Figure built inline rather than read from `output/figures/` | -10 |
| Major | Stale output reference (output file older than producing R script) | -5 |
| Minor | Long uncommented code block in narrative | -2 |

## Python Scripts (`scripts/*.py`)

| Severity | Issue | Deduction |
|---|---|---|
| Critical | Syntax error | -100 |
| Critical | Hardcoded absolute path | -25 |
| Major | Missing module docstring | -5 |
| Major | No CLI arg parsing in user-facing scripts | -5 |
| Minor | Lines > 100 chars | -1 each |

---

## Tolerance Thresholds (Replication)

| Quantity | Tolerance | Rationale |
|---|---|---|
| Integer counts (N, observations) | exact | no reason for difference |
| Point estimates (coefficients) | < 0.01 absolute, or < 1% relative | rounding in paper display |
| Standard errors | < 0.05 absolute, or < 5% relative | bootstrap / cluster variation |
| p-values | same significance star | exact may differ |
| Percentages reported in text | < 0.1pp | display rounding |
| R² | < 0.005 | display precision |

Document any deviation in `quality_reports/<lecture>_replication_report.md`.

---

## Enforcement

- **Score < 80:** block commit; list blocking issues with file:line references
- **80 ≤ Score < 90:** allow commit, warn user with recommendations
- **Score ≥ 90:** ready for PR
- User may override with documented justification in commit message

## Quality Reports

Generated **only at merge time** (not per commit). Use `templates/quality-report.md`. Save to `quality_reports/merges/YYYY-MM-DD_<branch>.md`.
