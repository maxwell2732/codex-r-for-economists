# ------------------------------------------------------------------------------
# File:     R/03_analysis/main_regression.R
# Project:  [YOUR PROJECT NAME]
# Author:   [YOUR NAME]
# Purpose:  Estimate the main DiD specification on the analysis sample.
# Inputs:   data/derived/sample_main.rds
# Outputs:  output/tables/main_regression.tex
#           output/tables/main_regression.csv
#           output/figures/event_study.pdf
# Log:      logs/03_analysis_main_regression.log
# ------------------------------------------------------------------------------

if (getRversion() < "4.3.0") stop("Requires R >= 4.3.0")

# --- 1. Setup -----------------------------------------------------------------

source("R/_utils/paths.R")
source("R/_utils/logging.R")
start_log("03_analysis_main_regression")

suppressPackageStartupMessages({
  library(tidyverse)
  library(fixest)
  library(modelsummary)
  library(kableExtra)
  library(ggplot2)
})

set.seed(20260428)

# --- 2. Load + restrict sample ------------------------------------------------

sample <- readRDS(proj_path("data", "derived", "sample_main.rds"))

cat("Sample N before restrictions:", nrow(sample), "\n")
sample <- sample %>% filter(year >= 2000)            # ATT cutoff per Section 3
cat("After restriction (year >= 2000):", nrow(sample), "\n")

# --- 3. Estimate models -------------------------------------------------------

# Use a named list so /build-tables can pick estimates up by key.
models <- list()

models[["m_main"]] <- feols(
  log_wage ~ i(post, treated, ref = 0) | state_id + year,
  cluster = ~state_id,
  data = sample
)

models[["m_controls"]] <- feols(
  log_wage ~ i(post, treated, ref = 0) + age + i(educ) | state_id + year,
  cluster = ~state_id,
  data = sample
)

# --- 4. Export tables ---------------------------------------------------------

modelsummary(
  models,
  output = proj_path("output", "tables", "main_regression.tex"),
  stars  = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
  fmt    = 3,
  gof_omit = "AIC|BIC|Log.Lik|RMSE"
)

modelsummary(
  models,
  output = proj_path("output", "tables", "main_regression.csv"),
  stars  = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
  fmt    = 3
)

# --- 5. Export figure ---------------------------------------------------------

p <- iplot(models[["m_main"]], main = "Event-study estimates")
# iplot returns a base R plot; for a ggplot version use fixest::ggiplot()
ggsave(proj_path("output", "figures", "event_study.pdf"),
       plot = last_plot(), width = 6, height = 4)
ggsave(proj_path("output", "figures", "event_study.png"),
       plot = last_plot(), width = 6, height = 4, dpi = 300)

# --- 6. Done ------------------------------------------------------------------

stop_log()
