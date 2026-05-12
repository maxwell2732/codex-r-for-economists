# ------------------------------------------------------------------------------
# File:     explorations/educwages_r_tutorial/R/00_inspect.R
# Purpose:  Quick one-off look at data/raw/educwages.csv so we know the column
#           types, ranges, and missingness before writing the teaching script.
#           Throwaway: never wired into the production pipeline.
# Inputs:   data/raw/educwages.csv
# Outputs:  (none — log only)
# Log:      logs/explorations_educwages_r_tutorial_R_00_inspect.log
# ------------------------------------------------------------------------------

if (getRversion() < "4.3.0") stop("Requires R >= 4.3.0; you have ", R.version.string)

source("R/_utils/paths.R")
source("R/_utils/logging.R")
start_log("explorations_educwages_r_tutorial_R_00_inspect")

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

dat <- read_csv(proj_path("data", "raw", "educwages.csv"),
                show_col_types = FALSE)

cat("\n*** dim() ***\n");      print(dim(dat))
cat("\n*** str() ***\n");      str(dat)
cat("\n*** summary() ***\n");  print(summary(dat))
cat("\n*** head(10) ***\n");   print(head(dat, 10))
cat("\n*** missingness per column ***\n")
print(sapply(dat, function(x) sum(is.na(x))))
cat("\n*** distinct values of `union` ***\n")
print(table(dat$union, useNA = "ifany"))

stop_log()
