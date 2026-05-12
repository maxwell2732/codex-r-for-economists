# ------------------------------------------------------------------------------
# File:     explorations/hsb2_teaching_demo/R/01_demo.R
# Project:  HSB2 teaching demonstration
# Author:   [Instructor]
# Purpose:  Walk an undergraduate audience through a complete (but compact)
#           R workflow:
#             (1) load + describe data
#             (2) summary statistics — overall and by group
#             (3) a histogram of writing scores
#             (4) OLS regression: how do test scores in other subjects
#                 predict writing performance?
# Inputs:   data/raw/hsb2.dta   (UCLA "High School and Beyond" sample, 200 obs)
# Outputs:  explorations/hsb2_teaching_demo/output/figures/write_histogram.pdf
#           explorations/hsb2_teaching_demo/output/figures/write_histogram.png
#           explorations/hsb2_teaching_demo/output/tables/coef_table.csv
# Log:      logs/explorations_hsb2_teaching_demo_R_01_demo.log
#
# HOW TO RUN (from the project root):
#     bash scripts/run_r.sh explorations/hsb2_teaching_demo/R/01_demo.R
#
# Or, inside an interactive R session:
#     source("explorations/hsb2_teaching_demo/R/01_demo.R")
# ------------------------------------------------------------------------------

if (getRversion() < "4.3.0") stop("Requires R >= 4.3.0; you have ", R.version.string)

# --- 0. Boilerplate -----------------------------------------------------------

options(warn = 1, scipen = 999, stringsAsFactors = FALSE)

source("R/_utils/paths.R")
source("R/_utils/logging.R")
start_log("explorations_hsb2_teaching_demo_R_01_demo")

set.seed(20260428)            # no randomness here, but a habit worth teaching

suppressPackageStartupMessages({
  library(dplyr)
  library(haven)              # read_dta
  library(ggplot2)
  library(readr)              # write_csv
  library(broom)              # tidy / glance for the coef table
})

# Make sure output folders exist (idempotent; safe to re-run).
dir.create(proj_path("explorations", "hsb2_teaching_demo", "output", "figures"),
           recursive = TRUE, showWarnings = FALSE)
dir.create(proj_path("explorations", "hsb2_teaching_demo", "output", "tables"),
           recursive = TRUE, showWarnings = FALSE)

# --- 1. Load the data --------------------------------------------------------
# hsb2 is the UCLA "High School and Beyond" teaching dataset: 200 students
# with five test scores plus demographic / school-type variables.

hsb2 <- read_dta(proj_path("data", "raw", "hsb2.dta"))

cat("\n*** Observations:", nrow(hsb2), "***\n")
str(hsb2)

# --- 2. Summary statistics ---------------------------------------------------

# 2a. Overall summary of every test score. `summary()` gives min/Q1/median/
#     mean/Q3/max — enough to spot outliers and check near-normality before OLS.
cat("\n>>> Summary of all test scores <<<\n")
print(summary(hsb2[, c("read", "write", "math", "science", "socst")]))

# 2b. Categorical breakdowns. table() with prop.table() reads like a pivot.
cat("\n>>> Counts by sex / race / SES / school type / program <<<\n")
for (v in c("female", "race", "ses", "schtyp", "prog")) {
  cat("\n--", v, "--\n")
  print(table(hsb2[[v]], useNA = "ifany"))
}

# 2c. Conditional means. group_by + summarise mirrors Stata's `tabstat, by()`.
cat("\n>>> Mean writing score, by program type <<<\n")
print(
  hsb2 %>%
    group_by(prog) %>%
    summarise(N    = dplyr::n(),
              mean = mean(write, na.rm = TRUE),
              sd   = sd(write,   na.rm = TRUE),
              min  = min(write,  na.rm = TRUE),
              max  = max(write,  na.rm = TRUE),
              .groups = "drop")
)

cat("\n>>> Mean test scores, by sex <<<\n")
print(
  hsb2 %>%
    group_by(female) %>%
    summarise(across(c(read, write, math, science, socst),
                     list(mean = ~mean(.x, na.rm = TRUE),
                          sd   = ~sd(.x,   na.rm = TRUE))),
              .groups = "drop")
)

# --- 3. Histogram of writing scores ------------------------------------------
# Overlay a normal density so students can see how close (or not) the
# distribution is to the normal assumption that OLS inference relies on.

write_mean <- mean(hsb2$write, na.rm = TRUE)
write_sd   <- sd(hsb2$write,   na.rm = TRUE)

p_hist <- ggplot(hsb2, aes(x = write)) +
  geom_histogram(binwidth = 3, fill = "#4477AA", colour = "white", boundary = 0) +
  stat_function(
    fun  = function(x) dnorm(x, mean = write_mean, sd = write_sd) * nrow(hsb2) * 3,
    geom = "line",
    colour = "#CC3311",
    linewidth = 0.9
  ) +
  labs(title    = "Distribution of writing scores (HSB2, n = 200)",
       subtitle = "Overlay shows the matched-moments normal density",
       x        = "Writing score",
       y        = "Frequency",
       caption  = "Source: UCLA High School and Beyond sample, 200 students.") +
  theme_minimal(base_size = 11)

ggsave(proj_path("explorations", "hsb2_teaching_demo", "output", "figures",
                 "write_histogram.pdf"),
       plot = p_hist, width = 6, height = 4)
ggsave(proj_path("explorations", "hsb2_teaching_demo", "output", "figures",
                 "write_histogram.png"),
       plot = p_hist, width = 6, height = 4, dpi = 300)

# --- 4. OLS: how do other test scores predict writing? -----------------------
# Build the model in three stages so students can see what each addition does
# to the coefficients and the model fit.
#
#   Spec 1: write = a + b1*read + e             (simple bivariate)
#   Spec 2: + math + female                     (add controls)
#   Spec 3: + indicators for race and program   (add categoricals via factor())

# Make categoricals explicit so lm() expands them into dummies.
hsb2 <- hsb2 %>%
  mutate(female = factor(female),
         race   = factor(race),
         prog   = factor(prog))

cat("\n>>> Spec 1: simple bivariate regression <<<\n")
m1 <- lm(write ~ read, data = hsb2)
print(summary(m1))

cat("\n>>> Spec 2: add math + female <<<\n")
m2 <- lm(write ~ read + math + female, data = hsb2)
print(summary(m2))

cat("\n>>> Spec 3: add race and program (categorical) <<<\n")
m3 <- lm(write ~ read + math + female + race + prog, data = hsb2)
print(summary(m3))

# Side-by-side coefficient table. broom::tidy gets us a tidy frame per model;
# we cherry-pick the `read` coefficient + N + R² and stitch them together.
coef_table <- bind_rows(
  tibble(spec = "m1: write ~ read",
         coef_read = coef(m1)[["read"]],
         se_read   = sqrt(diag(vcov(m1)))[["read"]],
         r2        = summary(m1)$r.squared,
         n         = nobs(m1)),
  tibble(spec = "m2: + math + female",
         coef_read = coef(m2)[["read"]],
         se_read   = sqrt(diag(vcov(m2)))[["read"]],
         r2        = summary(m2)$r.squared,
         n         = nobs(m2)),
  tibble(spec = "m3: + math + female + race + prog",
         coef_read = coef(m3)[["read"]],
         se_read   = sqrt(diag(vcov(m3)))[["read"]],
         r2        = summary(m3)$r.squared,
         n         = nobs(m3))
)

cat("\n>>> Coefficient comparison (Specs 1-3) <<<\n")
print(coef_table)

write_csv(coef_table,
          proj_path("explorations", "hsb2_teaching_demo", "output", "tables",
                    "coef_table.csv"))

# --- 5. Done -----------------------------------------------------------------

cat("\nPipeline finished. Inspect:\n")
cat("  log:    logs/explorations_hsb2_teaching_demo_R_01_demo.log\n")
cat("  figure: explorations/hsb2_teaching_demo/output/figures/write_histogram.pdf\n")
cat("  table:  explorations/hsb2_teaching_demo/output/tables/coef_table.csv\n")

stop_log()
