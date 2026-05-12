# ------------------------------------------------------------------------------
# File:     R/00_main.R
# Project:  [YOUR PROJECT NAME]
# Author:   [YOUR NAME]
# Purpose:  Pipeline orchestrator. Sources every stage of the analysis in
#           dependency order. This is the single canonical entry point for
#           reproducing the project end-to-end.
#
# Usage:    From project root:
#               bash scripts/run_pipeline.sh
#           or, equivalently:
#               Rscript R/00_main.R
#
# Inputs:   data/raw/**     (gitignored; provide your own)
# Outputs:  data/derived/**
#           output/tables/**, output/figures/**
#           logs/**
# Log:      logs/00_main.log + per-stage logs
# ------------------------------------------------------------------------------

if (getRversion() < "4.3.0") stop("Requires R >= 4.3.0; you have ", R.version.string)

# --- 0. Boilerplate -----------------------------------------------------------

options(warn = 1, scipen = 999, stringsAsFactors = FALSE)
set.seed(20260428)          # project-wide seed (date integer YYYYMMDD)

# --- 1. Load utilities --------------------------------------------------------

source("R/_utils/paths.R")
source("R/_utils/logging.R")

# --- 2. Configuration flags ---------------------------------------------------

INSTALL_DEPS <- FALSE       # set TRUE on first clone to bootstrap renv
RUN_EDA      <- FALSE       # set TRUE to run optional EDA stage

REQUIRED_PKGS <- c(
  "tidyverse", "haven", "fixest", "modelsummary", "kableExtra",
  "ggplot2", "here", "fs", "glue", "log4r"
)

# --- 3. Open master log -------------------------------------------------------

start_log("00_main")

# --- 4. Environment snapshot --------------------------------------------------

cat("*** Environment snapshot ***\n")
cat("R version:        ", R.version.string, "\n")
cat("Platform:         ", R.version$platform, "\n")
cat("OS:               ", Sys.info()[["sysname"]], Sys.info()[["release"]], "\n")
cat("Username:         ", Sys.info()[["user"]], "\n")
cat("Date:             ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "\n")
cat("Working dir:      ", getwd(), "\n")
cat("renv lockfile:    ", if (file.exists("renv.lock")) "present" else "MISSING", "\n\n")

cat("*** Required packages ***\n")
for (pkg in REQUIRED_PKGS) {
  ok <- requireNamespace(pkg, quietly = TRUE)
  cat(sprintf("  %-15s %s\n", pkg,
              if (ok) paste0("OK  (", as.character(packageVersion(pkg)), ")")
              else "MISSING (run scripts/setup_r.R)"))
}

if (isTRUE(INSTALL_DEPS)) {
  if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")
  renv::restore(prompt = FALSE)
}

# --- 5. Stage 01: Clean -------------------------------------------------------

cat("\n=== Stage 01: Clean raw data ===\n")
t0 <- Sys.time()

# source("R/01_clean/01_load_<dataset>.R")
# source("R/01_clean/02_clean_<dataset>.R")

cat(sprintf("Stage 01 elapsed: %.2f s\n",
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))

# --- 6. Stage 02: Construct ---------------------------------------------------

cat("\n=== Stage 02: Construct samples + variables ===\n")
t0 <- Sys.time()

# source("R/02_construct/01_build_sample.R")
# source("R/02_construct/02_define_treatment.R")

cat(sprintf("Stage 02 elapsed: %.2f s\n",
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))

# --- 7. Stage 03: Analysis ----------------------------------------------------

cat("\n=== Stage 03: Estimation ===\n")
t0 <- Sys.time()

# source("R/03_analysis/01_main_regression.R")
# source("R/03_analysis/02_event_study.R")

cat(sprintf("Stage 03 elapsed: %.2f s\n",
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))

# --- 8. Stage 04: Output assembly ---------------------------------------------

cat("\n=== Stage 04: Assemble tables + figures ===\n")
t0 <- Sys.time()

# source("R/04_output/01_main_tables.R")
# source("R/04_output/02_main_figures.R")

cat(sprintf("Stage 04 elapsed: %.2f s\n",
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))

# --- 9. Optional EDA ----------------------------------------------------------

if (isTRUE(RUN_EDA)) {
  cat("\n=== Stage EDA ===\n")
  # source("explorations/<name>/R/eda.R")
}

# --- 10. Done -----------------------------------------------------------------

cat("\n=== Pipeline complete ===\n")
cat("Logs:    logs/\n")
cat("Tables:  output/tables/\n")
cat("Figures: output/figures/\n")
cat("Next:    quarto render reports/analysis_report.qmd\n")

stop_log()
