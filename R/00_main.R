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

options(
  warn = 1,                 # surface warnings as they occur
  scipen = 999,             # avoid scientific notation in console
  stringsAsFactors = FALSE
)

set.seed(20260428)          # project-wide seed (date integer YYYYMMDD)

# --- 1. Load utilities --------------------------------------------------------

source("R/_utils/paths.R")
source("R/_utils/logging.R")

# --- 2. Configuration flags ---------------------------------------------------

# Set to TRUE the first time you clone the repo to install/snapshot packages.
INSTALL_DEPS <- FALSE

# Set to TRUE to run the EDA / exploratory stage. Off by default to keep the
# production pipeline fast and deterministic.
RUN_EDA <- FALSE

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
cat("renv lockfile:    ", if (file.exists("renv.lock")) "present" else "MISSING", "\n")

cat("\n*** Required packages ***\n")
for (pkg in REQUIRED_PKGS) {
  ok <- requireNamespace(pkg, quietly = TRUE)
  cat(sprintf("  %-15s %s\n", pkg,
              if (ok) paste0("OK  (", as.character(packageVersion(pkg)), ")")
              else "MISSING (run scripts/setup_r.R)"))
}

# --- 5. Optional one-time dependency install ---------------------------------

if (isTRUE(INSTALL_DEPS)) {
  cat("\n*** Installing missing packages ***\n")
  if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")
  renv::restore(prompt = FALSE)
}

# --- 6. Stage 01: Clean -------------------------------------------------------

cat("\n==========================================================\n")
cat("  Stage 01: Clean raw data\n")
cat("==========================================================\n")
t0 <- Sys.time()

# Add per-script calls below as you build the pipeline. Each script must be
# independently runnable (open its own log, use here::here() for paths).
#
# Examples:
# source("R/01_clean/01_load_cps.R")
# source("R/01_clean/02_clean_county_panel.R")

cat(sprintf("Stage 01 elapsed: %.2f seconds\n",
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))

# --- 7. Stage 02: Construct ---------------------------------------------------

cat("\n==========================================================\n")
cat("  Stage 02: Construct samples + variables\n")
cat("==========================================================\n")
t0 <- Sys.time()

# source("R/02_construct/01_build_sample.R")
# source("R/02_construct/02_define_treatment.R")

cat(sprintf("Stage 02 elapsed: %.2f seconds\n",
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))

# --- 8. Stage 03: Analysis ----------------------------------------------------

cat("\n==========================================================\n")
cat("  Stage 03: Estimation\n")
cat("==========================================================\n")
t0 <- Sys.time()

# source("R/03_analysis/01_main_regression.R")
# source("R/03_analysis/02_event_study.R")
# source("R/03_analysis/03_iv_specification.R")
# source("R/03_analysis/04_robustness.R")

cat(sprintf("Stage 03 elapsed: %.2f seconds\n",
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))

# --- 9. Stage 04: Output assembly ---------------------------------------------

cat("\n==========================================================\n")
cat("  Stage 04: Assemble tables + figures\n")
cat("==========================================================\n")
t0 <- Sys.time()

# source("R/04_output/01_main_tables.R")
# source("R/04_output/02_main_figures.R")

cat(sprintf("Stage 04 elapsed: %.2f seconds\n",
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))

# --- 10. Optional EDA (off by default) ----------------------------------------

if (isTRUE(RUN_EDA)) {
  cat("\n==========================================================\n")
  cat("  Stage EDA: Exploratory data analysis\n")
  cat("==========================================================\n")
  # source("explorations/<name>/R/eda.R")
}

# --- 11. Done -----------------------------------------------------------------

cat("\n==========================================================\n")
cat("  Pipeline complete\n")
cat("==========================================================\n")
cat("Logs:    logs/\n")
cat("Tables:  output/tables/\n")
cat("Figures: output/figures/\n")
cat("Next:    quarto render reports/analysis_report.qmd\n")

stop_log()
