---
name: r-data-analysis
description: End-to-end R workflow for empirical analysis — load, explore, clean, estimate, and produce publication output. Anchored to the project's pipeline stages and conventions.
disable-model-invocation: true
argument-hint: "[topic or stage]"
allowed-tools: ["Bash", "Read", "Edit", "Write", "Grep", "Glob", "Task"]
---

# R Data Analysis (End-to-End)

Apply the project's standard analysis flow on a new dataset or research question. Produces R scripts that fit `R/01_clean/` … `R/04_output/` and conform to `r-coding-conventions.md`.

## When to Use

- A new exploratory question that may graduate into the production pipeline
- A new dataset that needs cleaning + sample construction + a first round of regressions
- A teaching demo (often goes in `explorations/<name>/` first)

## Phases

### Phase 1: Frame

1. **Clarify the question** in 1-2 sentences (estimand, treatment, outcome). If ambiguous, use AskUserQuestion.
2. **Identify the data:** file path under `data/raw/`, format (`.csv` / `.dta` / `.parquet`), unit of observation, key identifiers.
3. **Decide where the work lives:**
   - Quick exploration → `explorations/<name>/R/`
   - Production analysis → `R/01_clean/`, `R/02_construct/`, `R/03_analysis/`

### Phase 2: Clean (`R/01_clean/`)

```r
source("R/_utils/paths.R")
source("R/_utils/logging.R")
start_log("01_clean_<dataset>")

library(tidyverse)
library(haven)

raw <- read_dta(proj_path("data", "raw", "<file>.dta"))   # or read_csv()
glimpse(raw)
summary(raw)

clean <- raw %>%
  filter(!is.na(key_id)) %>%
  mutate(year = as.integer(year))

saveRDS(clean, proj_path("data", "derived", "clean_<dataset>.rds"))
stop_log()
```

### Phase 3: Construct (`R/02_construct/`)

```r
start_log("02_construct_sample_main")

clean   <- readRDS(proj_path("data", "derived", "clean_<dataset>.rds"))
sample  <- clean %>%
  filter(year >= 2000) %>%
  mutate(
    treated   = as.integer(group == "T"),
    post      = as.integer(year >= treatment_year),
    log_y     = log(outcome + 1)
  )

saveRDS(sample, proj_path("data", "derived", "sample_main.rds"))
stop_log()
```

### Phase 4: Estimate (`R/03_analysis/`)

```r
start_log("03_analysis_main_regression")

library(fixest)
library(modelsummary)

sample <- readRDS(proj_path("data", "derived", "sample_main.rds"))
set.seed(20260428)

models <- list()
models[["m_main"]] <- feols(
  log_y ~ i(post, treated, ref = 0) | unit_id + year,
  cluster = ~unit_id,
  data    = sample
)

modelsummary(models,
             output = proj_path("output", "tables", "main_regression.tex"),
             stars  = c("*" = 0.10, "**" = 0.05, "***" = 0.01))
stop_log()
```

### Phase 5: Output (`R/04_output/`)

Assemble multi-spec tables via `modelsummary()` and figures via `ggsave()`. Save `.tex` + `.csv` for tables and `.pdf` + `.png` for figures.

### Phase 6: Verify

1. Run each stage via `/run-r R/<stage>/<file>.R`.
2. `/validate-r-log` on each produced log.
3. `python scripts/quality_score.py R/<stage>/<file>.R` — confirm ≥ 80.
4. If extending the production pipeline, wire the new scripts into `R/00_main.R`.

## Examples

- `/r-data-analysis main DiD on county wages` → drafts the four stages with placeholders.
- `/r-data-analysis explorations/hsb2_demo` → writes a teaching example under `explorations/`.

## Notes

- Default stack: `tidyverse` (`dplyr`, `tidyr`, `readr`), `haven` (`.dta` import), `fixest` (`feols` for HDFE + clustered SEs), `modelsummary` (tables), `ggplot2` (figures), `here` (paths). Anything else: justify in the script header.
- Cluster SEs at the most aggregate plausible level; document the choice in a comment.
- For MUST/SHOULD/MAY-style replication work, prefer `/replicate` over this skill.
