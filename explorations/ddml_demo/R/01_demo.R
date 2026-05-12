# ------------------------------------------------------------------------------
# File:     explorations/ddml_demo/R/01_demo.R
# Project:  Double / Debiased Machine Learning (DDML) demo
# Author:   [Instructor]
# Purpose:  On a simulated DGP where the true treatment effect is theta = 1.5
#           but the controls enter the outcome and treatment equations
#           NON-LINEARLY, show that:
#             (1) Naive OLS (linear-in-X) is biased
#             (2) Naive ML residual-on-residual (no cross-fitting) overfits
#                 and shrinks the coefficient toward zero
#             (3) DDML — cross-fit nuisance estimates plus the partial-linear
#                 moment condition — recovers theta with valid SEs
#                 (Chernozhukov et al. 2018)
#           Compare three DDML learner stacks: lasso-only, random-forest-only,
#           and a stacked ensemble (glmnet + ranger + xgboost) so students see
#           how stacking trades off across nuisance shapes.
# Inputs:   (none — data simulated inside the script)
# Outputs:  output/figures/learner_weights.{pdf,png}
#           output/figures/coefficient_comparison.{pdf,png}
#           output/tables/coefficient_comparison.{tex,csv}
# Log:      logs/explorations_ddml_demo_R_01_demo.log
# ------------------------------------------------------------------------------

if (getRversion() < "4.3.0") stop("Requires R >= 4.3.0; you have ", R.version.string)
options(warn = 1, scipen = 999, stringsAsFactors = FALSE)

source("R/_utils/paths.R")
source("R/_utils/logging.R")
source("R/_utils/theme_journal.R")
start_log("explorations_ddml_demo_R_01_demo")
on.exit(stop_log(), add = TRUE)

set.seed(20260512)

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(scales)
  library(ddml)
  library(sandwich)        # HC1 SE for naive OLS
  library(lmtest)
  library(modelsummary)
})


# --- 1. Simulate a partial-linear DGP with non-linear nuisance --------------
# Outcome equation:    y = theta * D + g(X) + e_y
# Treatment equation:  D = m(X) + e_d
#
# theta = 1.5 is the structural parameter we want to recover.
# g(X) and m(X) are NON-LINEAR functions of high-dimensional X. If we plug
# X linearly into a regression of y on D + X, we mis-specify g (and m, via
# the propagation of residual variance), and OLS picks up the bias from
# omitted non-linear terms in the projection of D on X. DDML lets ML learners
# fit g and m flexibly, then the partial-linear moment condition
#     E[(Y - g(X) - theta * D)(D - m(X))] = 0
# delivers an unbiased theta.

N <- 2000        # sample size
p <- 20          # number of controls (10 relevant, 10 irrelevant noise)

theta_true <- 1.5

# X: standard normal, p columns. The first 5 columns drive g and m; the rest
# are pure noise (a stylised "high-dim controls" setup where the analyst
# doesn't know which are relevant in advance).
X <- matrix(rnorm(N * p), nrow = N)
colnames(X) <- paste0("X", seq_len(p))

# Non-linear nuisance functions. Using only X1..X5 so the rest are pure
# noise — exactly the regime where DDML shines (a sparse truth in a wide
# control set).
#
# Pedagogical design: g and m SHARE the same non-linear features so the
# omitted-variable bias is visible. With strong X1^2, sin(X2), and the
# X4*X5 interaction in BOTH equations, a linear-in-X regression of y on
# D + X cannot residualise the non-linear part of D against X, so the
# OLS residual is correlated with D and theta_hat is biased.
g <- function(Xmat) {
  0.5 * Xmat[, 1] + 2.0 * Xmat[, 1]^2 +
    1.5 * sin(Xmat[, 2]) +
    1.0 * (Xmat[, 3] > 0) -
    0.8 * Xmat[, 4] * Xmat[, 5]
}
m <- function(Xmat) {
  0.4 * Xmat[, 1] + 1.5 * Xmat[, 1]^2 +
    1.2 * sin(Xmat[, 2]) +
    0.8 * (Xmat[, 3] > 0) -
    0.6 * Xmat[, 4] * Xmat[, 5]
}

D <- m(X) + rnorm(N, sd = 1)
y <- theta_true * D + g(X) + rnorm(N, sd = 1)

cat("\n*** DGP summary ***\n")
cat("N =", N, "  p =", p, "  theta_true =", theta_true, "\n")
cat("Var(D) =", round(var(D), 3),
    "  Var(y) =", round(var(y), 3), "\n")


# --- 2. Naive OLS: y on D + X (linear-only spec) ----------------------------
# What an applied researcher does by default: throw all 20 controls in
# linearly and read off the coefficient on D. Because g(X) has squared,
# trigonometric, and indicator terms, the linear projection misses them —
# the residual is correlated with D (which depends on the same non-linear
# X transformations), and OLS picks up the bias.

dat_ols <- as.data.frame(X) %>% mutate(D = D, y = y)
ols_fit <- lm(y ~ D + ., data = dat_ols)
ols_coef <- coef(ols_fit)["D"]
ols_se   <- sqrt(diag(vcovHC(ols_fit, type = "HC1")))["D"]
cat(sprintf("\n*** OLS (linear-in-X): D coef = %.4f (HC1 SE = %.4f) ***\n",
            ols_coef, ols_se))


# --- 3. "Naive ML": residual-on-residual without cross-fitting --------------
# A common trap for newcomers: fit a powerful ML model for E[Y|X] and
# E[D|X] on the FULL sample, residualise, then OLS the residuals. Because
# the nuisance fits use every observation including those whose residuals
# we then regress, the result is biased (overfit residuals understate
# noise; the moment condition is not orthogonal in finite samples).

if (requireNamespace("ranger", quietly = TRUE)) {
  rf_y <- ranger::ranger(y = y, x = X, num.trees = 500)$predictions
  rf_d <- ranger::ranger(y = D, x = X, num.trees = 500)$predictions
  res_y <- y - rf_y
  res_d <- D - rf_d
  naive_fit <- lm(res_y ~ res_d - 1)
  naive_coef <- coef(naive_fit)
  naive_se   <- sqrt(diag(vcovHC(naive_fit, type = "HC1")))
  cat(sprintf("\n*** Naive ML (no cross-fitting): D coef = %.4f (HC1 SE = %.4f) ***\n",
              naive_coef, naive_se))
}


# --- 4. DDML: cross-fit nuisance + partial-linear moment --------------------
# The proper procedure (Chernozhukov, Chetverikov, Demirer, Duflo, Hansen,
# Newey, Robins, 2018):
#   (a) Split the sample into K folds (sample_folds = 5 here).
#   (b) For each fold k: fit g_hat and m_hat on the other (K-1) folds,
#       then predict on fold k.
#   (c) Stack the cross-fit predictions across folds → out-of-sample
#       g_hat(X_i) and m_hat(X_i) for every observation i.
#   (d) Solve the partial-linear moment for theta:
#         theta_hat = sum_i [(D_i - m_hat) * (Y_i - g_hat)] /
#                     sum_i [(D_i - m_hat)^2]
#   (e) The asymptotic SE comes from the influence function — `summary()`
#       on a ddml_plm object reports it directly.
#
# We fit three variants to make the learner-choice point:
#   A. lasso only      (mdl_glmnet)            — sparse linear approximation
#   B. random forest only (mdl_ranger)          — flexible non-linear baseline
#   C. stacked ensemble (ols + glmnet + ranger + xgboost) — let the data
#      decide which learner fits each nuisance via NNLS stacking weights.

run_ddml <- function(label, learners) {
  fit <- ddml_plm(
    y            = y,
    D            = D,
    X            = X,
    learners     = learners,
    sample_folds = 5,
    ensemble_type = "nnls",
    shortstack   = FALSE,
    cv_folds     = 5,
    silent       = TRUE
  )
  # summary(ddml_plm) returns a 3-D array indexed by [coef, stat, ensemble].
  # The third dimension is the ensemble name ("nnls" by default); we always
  # take the first slice.
  s   <- summary(fit)
  est <- s["D_r", "Estimate",   1]
  se  <- s["D_r", "Std. Error", 1]
  cat(sprintf("\n*** DDML (%s): D coef = %.4f (SE = %.4f) ***\n",
              label, est, se))
  list(label = label, fit = fit, est = est, se = se)
}

ddml_lasso  <- run_ddml(
  "lasso only",
  list(list(fun = mdl_glmnet))
)
ddml_rf     <- run_ddml(
  "random forest only",
  list(list(fun = mdl_ranger,
            args = list(num.trees = 500)))
)
ddml_stack  <- run_ddml(
  "stacked (ols + glmnet + ranger + xgboost)",
  list(
    list(fun = ols),
    list(fun = mdl_glmnet),
    list(fun = mdl_ranger,  args = list(num.trees = 500)),
    list(fun = mdl_xgboost, args = list(nrounds = 200, max_depth = 3,
                                        learning_rate = 0.1))
  )
)


# --- 5. Stacking weights diagnostic ----------------------------------------
# When ensemble_type = "nnls", ddml fits non-negative weights on each
# learner's out-of-sample predictions. ddml stores them as a 3-D array
# [learner x ensemble x sample_fold]. We average across folds to get one
# weight per (learner, nuisance) for the figure. With multiple treatments
# the slot is named D1_X, D2_X, etc.; with one D it is just D1_X.

w_y_arr <- ddml_stack$fit$weights$y_X    # learner x ensemble x fold
w_d_arr <- ddml_stack$fit$weights$D1_X
w_y <- apply(w_y_arr[, 1, , drop = FALSE], 1, mean)
w_d <- apply(w_d_arr[, 1, , drop = FALSE], 1, mean)

learner_names <- c("OLS", "glmnet (lasso)", "ranger (RF)", "xgboost")

weights_long <- bind_rows(
  tibble(nuisance = "E[Y | X]", learner = learner_names, weight = w_y),
  tibble(nuisance = "E[D | X]", learner = learner_names, weight = w_d)
) %>%
  mutate(learner = factor(learner, levels = learner_names))

cat("\n*** Stacking weights (NNLS) ***\n")
print(weights_long %>% pivot_wider(names_from = nuisance, values_from = weight))

p_w <- ggplot(weights_long, aes(x = learner, y = weight, fill = nuisance)) +
  geom_col(position = position_dodge(width = 0.7), width = 0.6,
           colour = "grey20", linewidth = 0.3) +
  scale_fill_manual(values = c("E[Y | X]" = pal_journal[["blue"]],
                               "E[D | X]" = pal_journal[["teal"]]),
                    name = "Nuisance") +
  scale_y_continuous(limits = c(0, max(weights_long$weight) * 1.15),
                     expand = c(0, 0)) +
  labs(title    = "DDML stacking weights (NNLS) by learner and nuisance",
       subtitle = sprintf("Stacked ensemble fit on N = %s observations; weights sum to <= 1 within each nuisance",
                          format(N, big.mark = ",")),
       x        = NULL,
       y        = "NNLS weight",
       caption  = "Source: simulated; theta_true = 1.5, p = 20 controls (5 relevant, non-linear).") +
  theme_journal(base_size = 11) +
  theme(legend.position = "right",
        axis.text.x = element_text(angle = 15, hjust = 1))

ggsave(proj_path("explorations", "ddml_demo", "output", "figures",
                 "learner_weights.pdf"),
       plot = p_w, width = 7.5, height = 4)
ggsave(proj_path("explorations", "ddml_demo", "output", "figures",
                 "learner_weights.png"),
       plot = p_w, width = 7.5, height = 4, dpi = 300)


# --- 6. Coefficient comparison: estimate + 95% CI for every estimator -------

est_tbl <- tibble(
  estimator = c("OLS (linear-in-X)",
                "Naive ML (no CF)",
                "DDML — lasso only",
                "DDML — random forest only",
                "DDML — stacked"),
  estimate  = c(unname(ols_coef),
                unname(naive_coef),
                ddml_lasso$est,
                ddml_rf$est,
                ddml_stack$est),
  se        = c(unname(ols_se),
                unname(naive_se),
                ddml_lasso$se,
                ddml_rf$se,
                ddml_stack$se)
) %>%
  mutate(
    estimator = factor(estimator, levels = rev(estimator)),
    ci_lo = estimate - 1.96 * se,
    ci_hi = estimate + 1.96 * se,
    bias  = estimate - theta_true
  )

cat("\n*** Coefficient comparison ***\n")
print(est_tbl %>% mutate(across(c(estimate, se, ci_lo, ci_hi, bias),
                                ~ round(.x, 3))))

write.csv(est_tbl %>% select(-ci_lo, -ci_hi),
          proj_path("explorations", "ddml_demo", "output", "tables",
                    "coefficient_comparison.csv"),
          row.names = FALSE)


# --- 7. Coefficient-comparison figure: forest-style ------------------------
# Forest plot: one row per estimator, point + 95% CI; vertical solid line at
# the true theta. The bias of OLS and naive-ML jump out immediately.

estimator_palette <- c("OLS (linear-in-X)"          = pal_journal[["slate"]],
                       "Naive ML (no CF)"           = pal_journal[["lilac"]],
                       "DDML — lasso only"          = pal_journal[["blue"]],
                       "DDML — random forest only"  = pal_journal[["teal"]],
                       "DDML — stacked"             = pal_journal[["navy"]])

# Annotate "theta_true" anchored to the topmost estimator row. Using annotate()
# with a numeric y would crash because the y-axis is discrete (estimator names).
truth_label_df <- tibble(
  x = theta_true,
  y = levels(est_tbl$estimator)[1],     # topmost row
  label = sprintf("italic(theta)[true] == %.2f", theta_true)
)

p_forest <- ggplot(est_tbl, aes(x = estimate, y = estimator,
                                colour = estimator)) +
  geom_vline(xintercept = theta_true, linetype = "dashed",
             colour = "grey15", linewidth = 0.5) +
  geom_text(data = truth_label_df,
            aes(x = x, y = y, label = label),
            parse = TRUE, inherit.aes = FALSE,
            hjust = -0.08, vjust = -0.9,
            family = "serif", size = 3.6, colour = "grey20") +
  geom_errorbarh(aes(xmin = ci_lo, xmax = ci_hi),
                 height = 0.18, linewidth = 0.6) +
  geom_point(size = 3, shape = 21, fill = "white", stroke = 0.9) +
  scale_colour_manual(values = estimator_palette, guide = "none") +
  labs(title    = expression(bold("Estimating") ~ italic(theta) ~ bold("under non-linear high-dim controls")),
       subtitle = sprintf("Simulated DGP: y = theta * D + g(X) + e; D = m(X) + e; N = %s, p = %d",
                          format(N, big.mark = ","), p),
       x        = expression(hat(theta) ~ "with 95% CI"),
       y        = NULL,
       caption  = "DDML uses 5-fold cross-fitting and the partial-linear moment condition.") +
  theme_journal(base_size = 11)

ggsave(proj_path("explorations", "ddml_demo", "output", "figures",
                 "coefficient_comparison.pdf"),
       plot = p_forest, width = 8, height = 4.5)
ggsave(proj_path("explorations", "ddml_demo", "output", "figures",
                 "coefficient_comparison.png"),
       plot = p_forest, width = 8, height = 4.5, dpi = 300)


# --- 8. Publication-style LaTeX table ---------------------------------------
# `modelsummary` does not have a native tidy.ddml_plm method, so we build the
# LaTeX table by hand from `est_tbl`. The structure is the same as a
# modelsummary output: one column per estimator, coefficient + (SE) + N.

stars <- function(p) ifelse(p < 0.01, "***",
                     ifelse(p < 0.05, "**",
                     ifelse(p < 0.10, "*", "")))

tex_rows <- est_tbl %>%
  arrange(match(estimator,
                c("OLS (linear-in-X)", "Naive ML (no CF)",
                  "DDML — lasso only", "DDML — random forest only",
                  "DDML — stacked"))) %>%
  mutate(
    z       = estimate / se,
    p       = 2 * pnorm(-abs(z)),
    coef_s  = sprintf("%.3f%s", estimate, stars(p)),
    se_s    = sprintf("(%.3f)", se),
    bias_s  = sprintf("%+.3f", bias)
  )

tex_lines <- c(
  sprintf("%% Auto-generated by 01_demo.R; theta_true = %.2f", theta_true),
  "\\begin{tabular}{lccc}",
  "  \\toprule",
  "  Estimator & Estimate & SE & Bias \\\\",
  "  \\midrule",
  paste0("  ", tex_rows$estimator, " & ", tex_rows$coef_s, " & ",
         tex_rows$se_s, " & ", tex_rows$bias_s, " \\\\"),
  "  \\midrule",
  sprintf("  Truth & \\multicolumn{3}{c}{$\\theta = %.2f$} \\\\", theta_true),
  "  \\bottomrule",
  "\\end{tabular}"
)
writeLines(tex_lines,
           proj_path("explorations", "ddml_demo", "output", "tables",
                     "coefficient_comparison.tex"))


# --- 9. Done ----------------------------------------------------------------

cat("\nPipeline finished. Inspect:\n")
cat("  log:     logs/explorations_ddml_demo_R_01_demo.log\n")
cat("  figures: explorations/ddml_demo/output/figures/\n")
cat("  tables:  explorations/ddml_demo/output/tables/\n")

stop_log()
