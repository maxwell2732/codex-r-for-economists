# ------------------------------------------------------------------------------
# File:     explorations/hsb2_teaching_demo/R/00_inspect.R
# Purpose:  Print structure of hsb2.dta so we know which variables to use
#           in the teaching demo. Throwaway script.
# ------------------------------------------------------------------------------

if (getRversion() < "4.3.0") stop("Requires R >= 4.3.0")

source("R/_utils/paths.R")
source("R/_utils/logging.R")
start_log("explorations_hsb2_teaching_demo_R_00_inspect")

suppressPackageStartupMessages({
  library(haven)
  library(dplyr)
})

hsb2 <- read_dta(proj_path("data", "raw", "hsb2.dta"))

cat("\n*** str() ***\n")
str(hsb2)

cat("\n*** summary() ***\n")
print(summary(hsb2))

cat("\n*** first 5 rows ***\n")
print(head(hsb2, 5))

cat("\n*** variable labels (haven::attributes) ***\n")
for (nm in names(hsb2)) {
  lab <- attr(hsb2[[nm]], "label", exact = TRUE)
  if (!is.null(lab)) cat(sprintf("  %-12s %s\n", nm, lab))
}

stop_log()
