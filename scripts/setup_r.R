# ------------------------------------------------------------------------------
# File:     scripts/setup_r.R
# Purpose:  One-time bootstrap. Installs the required CRAN stack and snapshots
#           versions to renv.lock so collaborators get the same environment.
#
# Usage (from project root):
#           Rscript scripts/setup_r.R
# ------------------------------------------------------------------------------

if (getRversion() < "4.3.0") stop("Requires R >= 4.3.0; you have ", R.version.string)

REQUIRED_PKGS <- c(
  "renv",                       # environment locking (must be first)
  "tidyverse", "haven",         # data wrangling + .dta import
  "fixest",                     # high-dim FE regression + clustered SEs
  "modelsummary", "kableExtra", # publication tables
  "ggplot2",                    # figures
  "here", "fs", "glue",         # paths + small utilities
  "log4r"                       # structured logging
)

cat("== R Research Pipeline: setup ==\n")
cat("R version:  ", R.version.string, "\n")
cat("Library:    ", .libPaths()[[1]], "\n\n")

missing <- REQUIRED_PKGS[!vapply(REQUIRED_PKGS, requireNamespace,
                                 logical(1), quietly = TRUE)]

if (length(missing) > 0) {
  cat("Installing:", paste(missing, collapse = ", "), "\n")
  install.packages(missing, repos = c(CRAN = "https://cloud.r-project.org"))
} else {
  cat("All required packages already installed.\n")
}

# Initialize renv if not already initialized; otherwise snapshot the current
# library state so the lockfile stays in sync.
if (!file.exists("renv.lock")) {
  cat("\nInitializing renv (creating renv.lock + renv/activate.R) ...\n")
  renv::init(bare = TRUE, restart = FALSE)
} else {
  cat("\nrenv.lock present; snapshotting current library state ...\n")
}
renv::snapshot(prompt = FALSE)

cat("\n== Setup complete ==\n")
cat("Next:  bash scripts/run_pipeline.sh\n")
