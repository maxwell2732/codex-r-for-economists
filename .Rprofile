# ~/.Rprofile — project-level
# Activates renv on R startup so library paths point at the project lock.
# Do not edit unless you know what you are doing.

source("renv/activate.R")

# Use a sensible default CRAN mirror so install.packages() works non-interactively.
options(repos = c(CRAN = "https://cloud.r-project.org"))

# Quieter, more reproducible printing in batch mode.
options(
  warn = 1,                 # surface warnings as they occur, not at the end
  scipen = 999,             # avoid scientific notation in console output
  stringsAsFactors = FALSE  # belt and braces (default since R 4.0, but explicit)
)
