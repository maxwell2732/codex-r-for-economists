# ------------------------------------------------------------------------------
# File:     R/_utils/paths.R
# Purpose:  Project-relative path helpers. Use here::here() so every script
#           resolves paths from the project root regardless of the script's
#           own directory. Forbids setwd() inside scripts.
# Usage:
#           source("R/_utils/paths.R")
#           raw   <- proj_path("data", "raw", "cps.csv")
#           clean <- proj_path("data", "derived", "clean_cps.rds")
# ------------------------------------------------------------------------------

if (!requireNamespace("here", quietly = TRUE)) {
  stop("Package 'here' is required. Run scripts/setup_r.R or install.packages('here').")
}

proj_path <- function(...) here::here(...)

# Convenience pre-defined roots (read-only constants).
PROJ_ROOT       <- here::here()
DATA_RAW        <- here::here("data", "raw")
DATA_DERIVED    <- here::here("data", "derived")
LOGS_DIR        <- here::here("logs")
OUT_TABLES      <- here::here("output", "tables")
OUT_FIGURES     <- here::here("output", "figures")
