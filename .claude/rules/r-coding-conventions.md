---
paths:
  - "R/**/*.R"
  - "templates/**/*.R"
  - "explorations/**/*.R"
---

# R Coding Conventions

**Standard:** Top empirical economics replication package. Every R script must run cleanly from a fresh clone, log its actions, and produce outputs that another researcher can audit without asking the author.

---

## 1. File Header

Every R script begins with:

```r
# ------------------------------------------------------------------------------
# File:     R/03_analysis/main_regression.R
# Project:  [Your project name]
# Author:   [Your name]
# Purpose:  Estimate the main DiD specification on the analysis sample
# Inputs:   data/derived/sample_main.rds
# Outputs:  output/tables/main_regression.tex
#           output/tables/main_regression.csv
#           output/figures/event_study.pdf
# Log:      logs/03_analysis_main_regression.log
# ------------------------------------------------------------------------------
```

## 2. Top-of-File Boilerplate

```r
if (getRversion() < "4.3.0") stop("Requires R >= 4.3.0; you have ", R.version.string)

options(warn = 1, scipen = 999, stringsAsFactors = FALSE)

source("R/_utils/paths.R")
source("R/_utils/logging.R")
start_log("03_analysis_main_regression")

set.seed(20260428)             # set ONCE if randomness used (date-style integer)

suppressPackageStartupMessages({
  library(tidyverse)
  library(fixest)
  library(modelsummary)
})
```

## 3. Paths

- **Relative paths only.** Project root is `here::here()` (set automatically by the `here` package looking for the `.Rproj`/`DESCRIPTION` marker).
- **Never** `setwd("C:/Users/...")` or `setwd("/home/...")`. The static checker flags any `setwd(` as a critical error.
- Use `proj_path("data", "derived", "x.rds")` (defined in `R/_utils/paths.R`) instead of string concatenation.
- Use `tempfile()` for intermediate files within a script rather than writing to `data/` mid-script.

## 4. Naming

- Object names: `snake_case`, descriptive (`treated`, `post_2010`, `log_wage`)
- Function names: `snake_case` verbs (`build_sample`, `fit_main_did`)
- Estimation results: store in a named list — `models[["m_main"]] <- feols(...)` — so `modelsummary()` can iterate over them
- File names mirror their stage: `01_clean_cps.R`, `02_construct_sample.R`, `03_analysis_main.R`

## 5. Estimation Output Discipline

After every estimation, capture the result:

```r
models <- list()
models[["m_main"]] <- feols(
  log_wage ~ i(post, treated, ref = 0) | state_id + year,
  cluster = ~state_id,
  data    = sample
)

# Print into the log so the coefficient is greppable.
print(summary(models[["m_main"]]))
```

Save table-ready CSV alongside `.tex`:

```r
modelsummary(
  models,
  output = proj_path("output", "tables", "main_regression.tex"),
  stars  = c("*" = 0.10, "**" = 0.05, "***" = 0.01)
)
modelsummary(
  models,
  output = proj_path("output", "tables", "main_regression.csv"),
  stars  = c("*" = 0.10, "**" = 0.05, "***" = 0.01)
)
```

## 6. Figures

```r
ggsave(proj_path("output", "figures", "event_study.pdf"),
       plot = p, width = 6, height = 4)
ggsave(proj_path("output", "figures", "event_study.png"),
       plot = p, width = 6, height = 4, dpi = 300)
```

Set theme once at the top of a figure-producing script:

```r
theme_set(theme_minimal(base_size = 11))
```

## 7. Comment Quality

- Comments explain **WHY** (sample restriction rationale, identification choice), not WHAT
- Section headers as numbered banners:

```r
# --- 1. Load + restrict sample ----------------------------------------------
# --- 2. Define treatment + outcome ------------------------------------------
# --- 3. Main specification --------------------------------------------------
# --- 4. Robustness ----------------------------------------------------------
# --- 5. Export tables/figures -----------------------------------------------
```

- No commented-out dead code
- No unexplained magic numbers — assign to a named constant with a comment

## 8. Forbidden Patterns

| Forbidden | Why | Use instead |
|---|---|---|
| `setwd("C:/...")` | breaks reproducibility | run from project root; `here::here()` / `proj_path()` |
| `attach(df)` | masks variables silently | `df$col` or `with(df, ...)` |
| `rm(list = ls())` mid-script | nukes other scripts' state when sourced | scope work inside functions |
| Multiple `set.seed()` in one script | fakes reproducibility | once at top only |
| `<<-` (super-assignment) | side effects across environments | return values or named list |
| `T` / `F` instead of `TRUE` / `FALSE` | `T` and `F` are mutable | always spell out |
| Hardcoded dates / cutoffs without a named constant | obscures intent | `cutoff_year <- 2010  # ATT cutoff per Section 3` |

## 9. Required Packages

The pipeline assumes these are installed (recipe in `scripts/setup_r.R`):

- `tidyverse` — data wrangling (`dplyr`, `tidyr`, `readr`, `purrr`)
- `haven` — read `.dta` (legacy Stata datasets)
- `fixest` — high-dimensional FE regression with clustered SEs (`feols`, `feglm`)
- `modelsummary` + `kableExtra` — publication tables
- `ggplot2` — figures
- `here`, `fs`, `glue` — paths and small utilities
- `log4r` — structured logging (the `_utils/logging.R` helpers wrap `sink()` for now; `log4r` is available if you want richer logs)

Document any additional dependencies in the script header and add to `renv.lock` via `renv::snapshot()`.

## 10. Closing

Every script ends with:

```r
stop_log()
```

— so subsequent runs can be matched to their log files. If the script can throw, wrap the body in `on.exit(stop_log(), add = TRUE)` so the log closes even on error.
