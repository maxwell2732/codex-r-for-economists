# ------------------------------------------------------------------------------
# File:     explorations/educwages_r_tutorial/R/01_tutorial.R
# Project:  educwages tutorial — returns to schooling for R beginners
# Author:   [Instructor]
# Purpose:  A complete, heavily-commented walk-through for someone new to
#           R. Teaches:
#             (1) load + inspect a CSV
#             (2) summary statistics (overall and by group)
#             (3) Pearson correlation matrix + tests
#             (4) one-way and two-way ANOVA on a categorical recode
#             (5) histogram of education years (ggplot2)
#             (6) scatter of wages vs education with OLS fit (ggplot2)
#             (7) OLS regression of wages on education (HC-robust SEs)
#             (8) 2SLS IV regression — father's education as the instrument
#             (9) side-by-side OLS vs IV publication table (modelsummary)
# Inputs:   data/raw/educwages.csv  (1,000 obs; 5 columns)
# Outputs:  explorations/educwages_r_tutorial/output/figures/edu_histogram.{pdf,png}
#           explorations/educwages_r_tutorial/output/figures/edu_wage_scatter.{pdf,png}
#           explorations/educwages_r_tutorial/output/figures/correlation_heatmap.{pdf,png}
#           explorations/educwages_r_tutorial/output/tables/summary_stats.csv
#           explorations/educwages_r_tutorial/output/tables/correlations.csv
#           explorations/educwages_r_tutorial/output/tables/anova_oneway.csv
#           explorations/educwages_r_tutorial/output/tables/anova_twoway.csv
#           explorations/educwages_r_tutorial/output/tables/ols_vs_iv.{tex,csv,html}
# Log:      logs/explorations_educwages_r_tutorial_R_01_tutorial.log
#
# HOW TO RUN (from the project root):
#     bash scripts/run_r.sh explorations/educwages_r_tutorial/R/01_tutorial.R
#
# Or, inside an interactive R session:
#     source("explorations/educwages_r_tutorial/R/01_tutorial.R")
# ------------------------------------------------------------------------------

# R is picky about a few things at the top of every script. We do them in
# order so the rest behaves predictably:
#
#   getRversion() < "4.3.0"  → halt early if R is too old (avoids cryptic
#                              errors on missing-pipe-syntax or package-API
#                              changes that arrived in 4.x).
#   options(warn = 1)        → surface warnings as they occur, not at the end.
#   options(scipen = 999)    → never print numbers in scientific notation
#                              (so logs stay greppable).
#   set.seed(...)            → set ONCE if any randomness is used. None here,
#                              but it's a habit worth keeping.

if (getRversion() < "4.3.0") stop("Requires R >= 4.3.0; you have ", R.version.string)

options(warn = 1, scipen = 999, stringsAsFactors = FALSE)
set.seed(20260512)

# Project utilities. proj_path() is a thin wrapper around here::here() that
# resolves any path relative to the project root (no setwd() ever).
# start_log() / stop_log() open a plain-text log under logs/ that captures
# both stdout (print, cat) and message()/warning() output.
source("R/_utils/paths.R")
source("R/_utils/logging.R")
start_log("explorations_educwages_r_tutorial_R_01_tutorial")
on.exit(stop_log(), add = TRUE)   # closes even on error

# Library block. `suppressPackageStartupMessages` keeps the log clean — the
# tidyverse banner is informative the first time and noise after that.
suppressPackageStartupMessages({
  library(readr)         # read_csv
  library(dplyr)         # data wrangling
  library(tidyr)         # pivot_longer for the heatmap
  library(ggplot2)       # figures
  library(broom)         # tidy(model) -> data frame
  library(fixest)        # feols + IV (the project default for regressions)
  library(modelsummary)  # publication-quality side-by-side tables
})


# --- 1. Load the data --------------------------------------------------------
# read_csv is the tidyverse CSV reader. It handles the UTF-8 BOM at the
# start of the file automatically and infers column types from the first
# 1,000 rows. show_col_types = FALSE keeps the log tidy.

dat <- read_csv(proj_path("data", "raw", "educwages.csv"),
                show_col_types = FALSE)

cat("\n*** Observations:", nrow(dat), "***\n")

# str() is the rough R analogue of Stata's `describe`: variable names,
# types, and the first few values. glimpse() (from dplyr) is similar but
# easier to read for wide tables.
cat("\n*** str(dat) ***\n")
str(dat)


# --- 2. Summary statistics ---------------------------------------------------
# 2a. Overall summary of every numeric variable.
#     summary() reports min/Q1/median/mean/Q3/max for each numeric column.
#     For a richer "Stata-like" `summarize, detail` view we use a custom
#     summarise() with quantiles, sd, skewness, kurtosis.
cat("\n>>> Summary of all numeric variables <<<\n")
print(summary(dat[, c("wages", "education", "meducation", "feducation")]))

# A more publication-friendly summary table: one row per variable, columns
# for N / mean / sd / min / p25 / p50 / p75 / max. We assemble it with
# dplyr because it's transparent — students can read every step.
summary_tbl <- dat %>%
  select(wages, education, meducation, feducation) %>%
  tidyr::pivot_longer(everything(), names_to = "variable", values_to = "value") %>%
  group_by(variable) %>%
  summarise(
    N    = sum(!is.na(value)),
    mean = mean(value, na.rm = TRUE),
    sd   = sd(value,   na.rm = TRUE),
    min  = min(value,  na.rm = TRUE),
    p25  = quantile(value, 0.25, na.rm = TRUE),
    p50  = quantile(value, 0.50, na.rm = TRUE),
    p75  = quantile(value, 0.75, na.rm = TRUE),
    max  = max(value,  na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(across(c(mean, sd, min, p25, p50, p75, max), ~ round(.x, 2)))

cat("\n>>> Summary table (saved to CSV) <<<\n")
print(summary_tbl)

write_csv(summary_tbl,
          proj_path("explorations", "educwages_r_tutorial", "output",
                    "tables", "summary_stats.csv"))

# 2b. Categorical breakdown for `union`. table() is base R; tidyverse users
#     prefer count(), which returns a tibble.
cat("\n>>> Union membership <<<\n")
print(dat %>% count(union) %>% mutate(pct = round(100 * n / sum(n), 1)))

# 2c. Conditional means: how do wages and education differ by union status?
cat("\n>>> Mean wages and education, by union status <<<\n")
print(
  dat %>%
    group_by(union) %>%
    summarise(
      N         = dplyr::n(),
      mean_wage = round(mean(wages,     na.rm = TRUE), 2),
      sd_wage   = round(sd(wages,       na.rm = TRUE), 2),
      mean_edu  = round(mean(education, na.rm = TRUE), 2),
      sd_edu    = round(sd(education,   na.rm = TRUE), 2),
      .groups = "drop"
    )
)


# --- 3. Pearson correlation coefficients -------------------------------------
# The Pearson correlation r is in [-1, 1] and measures the strength of a
# *linear* association between two numeric variables. We compute it for
# every pair of numeric columns (the matrix), then run a formal cor.test()
# for each pair to get p-values. cor.test() returns a t-statistic and a
# 95% CI under the null r = 0; we extract them via broom::tidy().

num_vars <- c("wages", "education", "meducation", "feducation")

cor_mat <- cor(dat[, num_vars], use = "complete.obs", method = "pearson")
cat("\n>>> Pearson correlation matrix <<<\n")
print(round(cor_mat, 3))

# Flat (long) form of the same matrix, with significance tests for each
# unordered pair. We loop over upper-triangle index pairs and call
# cor.test(), then bind the rows.
pair_grid <- expand.grid(x = num_vars, y = num_vars,
                         stringsAsFactors = FALSE) %>%
  filter(x < y)   # upper triangle only (alphabetical order on the names)

cor_tests <- purrr::map2_dfr(pair_grid$x, pair_grid$y, function(xn, yn) {
  ct <- cor.test(dat[[xn]], dat[[yn]], method = "pearson")
  tibble(
    var1     = xn,
    var2     = yn,
    pearson  = round(unname(ct$estimate), 3),
    t_stat   = round(unname(ct$statistic), 3),
    df       = unname(ct$parameter),
    p_value  = signif(ct$p.value, 3),
    ci_lo    = round(ct$conf.int[1], 3),
    ci_hi    = round(ct$conf.int[2], 3)
  )
})
# purrr::map2_dfr is lazy-loaded with tidyverse but `purrr` is not
# explicitly attached above; the namespace-qualified call avoids surprises.

cat("\n>>> Pairwise Pearson correlations with tests (saved to CSV) <<<\n")
print(cor_tests)

write_csv(cor_tests,
          proj_path("explorations", "educwages_r_tutorial", "output",
                    "tables", "correlations.csv"))

# Visualise the correlation matrix as a heatmap. Long form is what ggplot
# wants. Round to 2 decimals for the cell labels so the figure stays clean.
cor_long <- as.data.frame(cor_mat) %>%
  tibble::rownames_to_column("var1") %>%
  pivot_longer(-var1, names_to = "var2", values_to = "r") %>%
  mutate(r_label = sprintf("%.2f", r))

p_corr <- ggplot(cor_long, aes(x = var2, y = var1, fill = r)) +
  geom_tile(colour = "white") +
  geom_text(aes(label = r_label), size = 4) +
  scale_fill_gradient2(low      = "#3B4CC0",
                       mid      = "white",
                       high     = "#B40426",
                       midpoint = 0,
                       limits   = c(-1, 1),
                       name     = "Pearson r") +
  labs(title    = "Pearson correlation matrix",
       subtitle = "educwages.csv (n = 1,000)",
       x        = NULL, y = NULL) +
  coord_fixed() +
  theme_minimal(base_size = 11) +
  theme(panel.grid = element_blank(),
        axis.text.x = element_text(angle = 30, hjust = 1))

ggsave(proj_path("explorations", "educwages_r_tutorial", "output",
                 "figures", "correlation_heatmap.pdf"),
       plot = p_corr, width = 5.5, height = 5)
ggsave(proj_path("explorations", "educwages_r_tutorial", "output",
                 "figures", "correlation_heatmap.png"),
       plot = p_corr, width = 5.5, height = 5, dpi = 300)


# --- 4. ANOVA: do mean wages differ across education tiers? ------------------
# ANOVA generalises the two-sample t-test to >= 2 groups. The null is
#     H0: mu_1 = mu_2 = ... = mu_k     (all group means are equal)
# and the alternative is "at least one differs". The F statistic compares
# between-group variation to within-group variation; a large F (small p)
# rejects the null.
#
# For ANOVA we need a categorical predictor. `education` is continuous
# (years), so we first bin it into three tiers — Low / Mid / High — using
# dplyr::case_when. case_when reads top-to-bottom; the first matching
# condition wins, so order matters.

dat <- dat %>%
  mutate(
    edu_cat = case_when(
      education <  13 ~ "Low (<13)",
      education <= 16 ~ "Mid (13-16)",
      education >  16 ~ "High (>16)",
      TRUE            ~ NA_character_
    ),
    # Set the factor levels explicitly so the ANOVA reference category is
    # "Low" and the table prints in pedagogical order.
    edu_cat = factor(edu_cat, levels = c("Low (<13)", "Mid (13-16)", "High (>16)")),
    union   = factor(union,   levels = c("No", "Yes"))
  )

cat("\n>>> Wage means by education tier <<<\n")
print(
  dat %>%
    group_by(edu_cat) %>%
    summarise(N        = dplyr::n(),
              mean_wage = round(mean(wages, na.rm = TRUE), 2),
              sd_wage   = round(sd(wages,   na.rm = TRUE), 2),
              .groups = "drop")
)

# 4a. One-way ANOVA: wages explained by edu_cat alone.
# aov() is the base-R formula interface; summary() prints the standard
# ANOVA table (Df, Sum Sq, Mean Sq, F, Pr(>F)).
cat("\n>>> One-way ANOVA: wages ~ edu_cat <<<\n")
anova1 <- aov(wages ~ edu_cat, data = dat)
print(summary(anova1))

# Save the ANOVA table to CSV for sharing. broom::tidy(anova1) returns a
# tibble with one row per term + the residual row.
anova1_tbl <- broom::tidy(anova1) %>%
  mutate(
    sumsq   = round(sumsq,   2),
    meansq  = round(meansq,  2),
    statistic = round(statistic, 3),
    p.value = signif(p.value, 3)
  )
write_csv(anova1_tbl,
          proj_path("explorations", "educwages_r_tutorial", "output",
                    "tables", "anova_oneway.csv"))

# 4b. Two-way ANOVA: add union as a second categorical predictor.
# This tests whether wages vary by edu_cat *and* by union, treating each
# as a main effect. (For an interaction, write `edu_cat * union`.)
cat("\n>>> Two-way ANOVA: wages ~ edu_cat + union (main effects) <<<\n")
anova2 <- aov(wages ~ edu_cat + union, data = dat)
print(summary(anova2))

anova2_tbl <- broom::tidy(anova2) %>%
  mutate(
    sumsq   = round(sumsq,   2),
    meansq  = round(meansq,  2),
    statistic = round(statistic, 3),
    p.value = signif(p.value, 3)
  )
write_csv(anova2_tbl,
          proj_path("explorations", "educwages_r_tutorial", "output",
                    "tables", "anova_twoway.csv"))

# Bridge: ANOVA = OLS with categorical predictors. The F statistic from
# aov() equals the F statistic for the joint significance test of the
# group dummies in lm() with the same right-hand side. Show this so
# students see the connection.
cat("\n>>> Bridge: aov() and lm() are the same model — same F, same p <<<\n")
print(summary(lm(wages ~ edu_cat + union, data = dat)))


# --- 5. Histogram of education years -----------------------------------------
# ggplot2's geom_histogram is the workhorse. binwidth = 1 gives one bin
# per year of education (the variable is continuous but in year units).
# We overlay a normal density (matched to the sample mean and SD) so
# students can compare the empirical shape to the normal benchmark that
# OLS inference relies on.

edu_mean <- mean(dat$education, na.rm = TRUE)
edu_sd   <- sd(dat$education,   na.rm = TRUE)

p_hist <- ggplot(dat, aes(x = education)) +
  geom_histogram(binwidth = 1, fill = "#4477AA",
                 colour = "white", boundary = 0) +
  stat_function(
    fun  = function(x) dnorm(x, mean = edu_mean, sd = edu_sd) * nrow(dat) * 1,
    geom = "line", colour = "#CC3311", linewidth = 0.9
  ) +
  labs(title    = "Distribution of education (educwages, n = 1,000)",
       subtitle = "Bin width = 1 year; overlay = matched-moments normal density",
       x        = "Years of education",
       y        = "Frequency",
       caption  = "Source: data/raw/educwages.csv") +
  theme_minimal(base_size = 11)

ggsave(proj_path("explorations", "educwages_r_tutorial", "output",
                 "figures", "edu_histogram.pdf"),
       plot = p_hist, width = 6, height = 4)
ggsave(proj_path("explorations", "educwages_r_tutorial", "output",
                 "figures", "edu_histogram.png"),
       plot = p_hist, width = 6, height = 4, dpi = 300)


# --- 6. Scatter: education vs wages, with OLS fit ----------------------------
# Visual preview of what OLS in the next section will estimate. If the
# best-fit line slopes up, the OLS coefficient on education will be
# positive; if the cloud is wide around the line, R^2 will be small.
# geom_smooth(method = "lm") computes and overlays the OLS regression
# line plus a 95% confidence ribbon.

p_scatter <- ggplot(dat, aes(x = education, y = wages)) +
  geom_point(shape = 1, colour = "#4477AA", alpha = 0.6) +
  geom_smooth(method = "lm", formula = y ~ x,
              colour = "#CC3311", fill = "#CC3311", alpha = 0.15,
              linewidth = 0.9) +
  labs(title    = "Education vs wages, with OLS fit",
       subtitle = "Each dot is one worker (n = 1,000); ribbon = 95% CI of the fitted line",
       x        = "Years of education",
       y        = "Annual wages",
       caption  = "Source: data/raw/educwages.csv") +
  theme_minimal(base_size = 11)

ggsave(proj_path("explorations", "educwages_r_tutorial", "output",
                 "figures", "edu_wage_scatter.pdf"),
       plot = p_scatter, width = 6, height = 4)
ggsave(proj_path("explorations", "educwages_r_tutorial", "output",
                 "figures", "edu_wage_scatter.png"),
       plot = p_scatter, width = 6, height = 4, dpi = 300)


# --- 7. OLS regression: wages on education -----------------------------------
# The simplest "Mincer-style" regression:
#
#     wages_i = a + b * education_i + e_i
#
# We fit it with fixest::feols (the project default; same syntax as lm()
# but with built-in robust / clustered SE options). vcov = "hetero" asks
# for heteroskedasticity-robust (Eicker-Huber-White) standard errors.
# With i.i.d. cross-sectional data we don't need clustered SEs (no panel
# structure), but robust is a sensible default.
#
# We store the result in a NAMED LIST so modelsummary can pick it up for
# the comparison table later. Skipping the assignment ("just print it")
# means the model is gone after the function call and table assembly
# fails — see r-coding-conventions § 7.

models <- list()

cat("\n>>> OLS: wages on education (HC-robust SE) <<<\n")
models[["OLS"]] <- feols(wages ~ education, data = dat, vcov = "hetero")
print(summary(models[["OLS"]]))

# Interpretation (the instructor will narrate this in class):
#   - The coefficient on `education` is the OLS estimate of the *average*
#     change in annual wages associated with one additional year of
#     schooling, holding nothing else constant.
#   - It is a *correlation* story, not necessarily a *causal* story:
#     unobserved ability, family background, and motivation may drive
#     both schooling choice and wages, biasing OLS. That is why we run
#     IV next.


# --- 8. IV (2SLS): instrument education with father's education --------------
# Endogeneity worry: workers with higher unobserved ability (or richer
# families, or more motivation) tend to acquire more schooling. So the
# OLS slope mixes the *causal* return to schooling with bias from these
# unobservables. If ability raises both education and wages, OLS will
# overstate the return.
#
# Instrumental variables (IV) tries to isolate variation in `education`
# that is *unrelated* to the unobservables, by using a third variable Z
# (the "instrument") that satisfies two conditions:
#   (R) RELEVANCE: Z is correlated with `education` (testable; we want
#       the first-stage F statistic to be large, conventionally > 10).
#   (E) EXCLUSION: Z affects wages ONLY through its effect on `education`
#       (NOT testable; argued from theory and context).
#
# Here we use father's education (`feducation`) as Z.
#   - Relevance is plausible: workers with more-educated fathers tend
#     to get more schooling themselves. We verify with the first-stage F.
#   - Exclusion is *not* clean: father's education correlates with family
#     income, social networks, and parenting environment, all of which
#     can plausibly affect wages directly. So treat this as a teaching
#     example of HOW to run 2SLS, not as a credible causal estimate.
#     Real papers rely on compulsory-schooling laws, distance to college,
#     twin differences, etc.
#
# fixest's IV syntax is:
#     feols(Y ~ exog | fe | endog ~ z, data = ..., vcov = ...)
# The `| 0 |` in our case means "no fixed effects". You read the formula
# left-to-right as: outcome | exogenous regressors | FE block | (endogenous
# variable ~ instrument).

cat("\n>>> First stage (manual): education on feducation <<<\n")
# Pedagogically useful to show the first stage explicitly first. The
# F statistic on `feducation` should be large; if not, the instrument
# is weak and the IV estimate is unreliable.
first_stage <- feols(education ~ feducation, data = dat, vcov = "hetero")
print(summary(first_stage))

cat("\n>>> 2SLS: wages = a + b*education + e, instrument = feducation <<<\n")
models[["IV"]] <- feols(wages ~ 1 | education ~ feducation,
                        data = dat, vcov = "hetero")
print(summary(models[["IV"]]))

# fitstat(model, "ivf") prints the (Cragg-Donald, Kleibergen-Paap when
# clusters are used) first-stage F statistic from inside the IV fit
# itself — the gold-standard reference for whether the instrument is
# strong enough to trust the second stage.
cat("\n>>> First-stage F (from fixest::fitstat) <<<\n")
fitstat(models[["IV"]], type = c("ivf", "ivwald"))

# Interpretation:
#   - Under (R) and (E), the IV/2SLS slope on `education` recovers the
#     *causal* return to schooling for the subgroup of workers whose
#     education is shifted by their father's education (a "Local Average
#     Treatment Effect" if effects are heterogeneous).
#   - Compare to OLS:
#       * If IV is *smaller* than OLS, ability bias was likely upward
#         (smart kids both got more schooling and earn more).
#       * If IV is *larger* than OLS, measurement error in education or
#         a compliers-vs-population effect may dominate.
#       * Bigger SE on IV is normal — IV throws away variation, so it is
#         less precise than OLS by construction.


# --- 9. Side-by-side OLS vs IV comparison table ------------------------------
# modelsummary takes a named list of models and renders one column per
# model with a tidy bottom panel of fit statistics. We export to .tex
# (for LaTeX papers), .csv (for spreadsheets), and .html (for previewing
# in a browser or embedding in a Quarto report).
#
#   - stars: significance markers at the 10% / 5% / 1% level
#   - fmt:   3 decimal places for coefficients
#   - gof_omit: drop the noisy goodness-of-fit rows (AIC/BIC/RMSE/etc.)
#              that aren't meaningful for these particular fits
#   - notes: footnote shown under the table

cat("\n>>> Coefficient comparison: OLS vs IV (printed) <<<\n")
modelsummary(
  models,
  stars   = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
  fmt     = 3,
  gof_omit = "AIC|BIC|Log.Lik|RMSE|Std.Errors|FE",
  notes   = c(
    "HC-robust standard errors in parentheses.",
    "IV: feols(wages ~ 1 | education ~ feducation).",
    "Significance: * p<0.10, ** p<0.05, *** p<0.01."
  )
)

# Same thing, written to disk in three formats.
ols_iv_tex <- proj_path("explorations", "educwages_r_tutorial", "output",
                        "tables", "ols_vs_iv.tex")
ols_iv_csv <- proj_path("explorations", "educwages_r_tutorial", "output",
                        "tables", "ols_vs_iv.csv")
ols_iv_html <- proj_path("explorations", "educwages_r_tutorial", "output",
                         "tables", "ols_vs_iv.html")

modelsummary(models, output = ols_iv_tex,
             stars = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
             fmt = 3, gof_omit = "AIC|BIC|Log.Lik|RMSE|Std.Errors|FE",
             title = "Returns to schooling: OLS vs IV (father's education as instrument)",
             notes = "HC-robust standard errors in parentheses. * p<0.10, ** p<0.05, *** p<0.01.")

modelsummary(models, output = ols_iv_csv,
             stars = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
             fmt = 3, gof_omit = "AIC|BIC|Log.Lik|RMSE|Std.Errors|FE")

modelsummary(models, output = ols_iv_html,
             stars = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
             fmt = 3, gof_omit = "AIC|BIC|Log.Lik|RMSE|Std.Errors|FE",
             title = "Returns to schooling: OLS vs IV",
             notes = "HC-robust SEs in parentheses. * p<0.10, ** p<0.05, *** p<0.01.")


# --- 10. Done ----------------------------------------------------------------

cat("\nPipeline finished. Inspect:\n")
cat("  log:     logs/explorations_educwages_r_tutorial_R_01_tutorial.log\n")
cat("  figures: explorations/educwages_r_tutorial/output/figures/\n")
cat("           - edu_histogram.{pdf,png}\n")
cat("           - edu_wage_scatter.{pdf,png}\n")
cat("           - correlation_heatmap.{pdf,png}\n")
cat("  tables:  explorations/educwages_r_tutorial/output/tables/\n")
cat("           - summary_stats.csv\n")
cat("           - correlations.csv\n")
cat("           - anova_oneway.csv, anova_twoway.csv\n")
cat("           - ols_vs_iv.{tex,csv,html}\n")

# stop_log() is also called by on.exit() above; calling it explicitly here
# is harmless and makes the closing banner show up in the normal-exit
# branch of the log.
stop_log()
