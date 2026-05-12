---
name: r-bayes
description: Patterns for Bayesian inference in R using brms, including multilevel models, DAG validation, and marginal effects. Use when performing Bayesian analysis.
---

# Bayesian Analysis in R

*brms, DAGs, multilevel models, marginal effects*

## Core Packages

```r
library(brms)           # Bayesian regression via Stan
library(cmdstanr)       # Stan backend (faster than rstan)
library(dagitty)        # DAG definition and validation
library(ggdag)          # DAG visualization
library(marginaleffects) # AME and predictions
library(tidybayes)      # Tidy posterior extraction
library(bayesplot)      # MCMC diagnostics
```

## Causal DAGs (dagitty + ggdag)

```r
dag <- dagitty('dag {
  exposure  [pos="0,1"]
  mediator  [pos="1,1"]
  outcome   [pos="2,1"]
  confounder [pos="1,0"]

  confounder -> exposure
  confounder -> outcome
  exposure -> mediator -> outcome
  exposure -> outcome
}')

# Identify adjustment sets
adjustmentSets(dag, exposure = "exposure", outcome = "outcome", effect = "total")

# Validate DAG against data
ci_results <- localTests(dag, data = df, type = "cis")
pct_supported <- 100 * mean(as.data.frame(ci_results)$p.value > 0.05, na.rm = TRUE)
cat(sprintf("DAG support: %.1f%% of implied CIs hold\n", pct_supported))
```

## Standard brms Model

```r
options(mc.cores = 4)

priors <- c(
  prior(normal(0, 2),    class = "Intercept"),
  prior(normal(0, 1),    class = "b"),
  prior(exponential(1),  class = "sd"),
  prior(lkj(2),          class = "cor")
)

model <- brm(
  formula    = outcome ~ predictor + (1 | group_id),
  data       = df,
  family     = gaussian(),
  prior      = priors,
  sample_prior = "yes",   # enables prior-posterior comparison
  chains     = 4,
  cores      = 4,
  iter       = 4000,
  warmup     = 1000,
  seed       = 20260428,
  backend    = "cmdstanr",
  file       = "models/model_name",   # caches compiled model
  file_refit = "on_change"
)
```

### Common Families

```r
bernoulli(link = "logit")   # binary outcome
poisson(link = "log")       # count
negbinomial(link = "log")   # overdispersed count
gaussian()                  # continuous
student()                   # robust to outliers
cumulative(link = "logit")  # ordinal
```

## Multilevel Structures

```r
# Random intercepts
outcome ~ predictors + (1 | participant_id)

# Random intercept + slope
outcome ~ time + (1 + time | participant_id)

# Crossed random effects
response ~ predictors + (1 | participant_id) + (1 | item_id)
```

## Within-Person Centering (panel / longitudinal)

```r
df <- df |>
  group_by(id) |>
  mutate(
    pred_mean = mean(predictor, na.rm = TRUE),
    pred_dev  = predictor - pred_mean,
    pred_lag  = lag(predictor, order_by = time)
  ) |>
  ungroup() |>
  mutate(
    pred_mean_z = scale(pred_mean)[, 1],
    pred_dev_z  = scale(pred_dev)[, 1]
  )

# Separate between- and within-person effects
model <- brm(outcome ~ pred_mean_z + pred_dev_z + (1 | id), ...)
```

## Extracting Posteriors

```r
posterior <- as_draws_df(model)
samples <- posterior$b_predictor_z

tibble(
  estimate   = median(samples),
  lower_95   = quantile(samples, 0.025),
  upper_95   = quantile(samples, 0.975),
  prob_pos   = mean(samples > 0),
  prob_neg   = mean(samples < 0)
)

# Odds ratios for logistic models
exp(median(samples))
```

## Marginal Effects (marginaleffects)

```r
# Average marginal effect
avg_slopes(model, variables = "predictor_z", type = "response")

# Predictions at specific values
predictions(model,
  newdata   = datagrid(predictor_z = c(-1, 0, 1)),
  type      = "response",
  re_formula = NA   # population-level
)

# Plot
plot_predictions(model, by = "predictor_z", type = "response", re_formula = NA)
```

## Diagnostics

```r
# Convergence
summary(model)$fixed$Rhat       # should be < 1.01
summary(model)$fixed$Bulk_ESS   # should be > 400

# Trace plots
mcmc_trace(model, pars = c("b_Intercept", "b_predictor_z"))

# Posterior predictive checks
pp_check(model)
pp_check(model, type = "stat", stat = "mean")
```

## tidybayes Integration

```r
draws <- model |>
  spread_draws(b_predictor1_z, b_predictor2_z) |>
  mutate(OR_1 = exp(b_predictor1_z))

draws |>
  median_qi(OR_1, .width = c(0.80, 0.95))

draws |>
  ggplot(aes(x = OR_1)) +
  stat_halfeye() +
  geom_vline(xintercept = 1, linetype = "dashed")
```

## Workflow Checklist

1. Define causal DAG with dagitty
2. Validate DAG against data (`localTests`)
3. Identify adjustment sets
4. Specify priors from domain knowledge
5. Fit brms model with appropriate random effects
6. Check convergence (Rhat, ESS, trace plots)
7. Posterior predictive checks
8. Extract posteriors and compute marginal effects
9. Visualize effects with uncertainty

## Anti-Patterns

```r
# WRONG: contemporaneous predictor when temporal order matters
outcome_t ~ predictor_t

# CORRECT: lagged predictor
outcome_t ~ predictor_lag  # establishes temporal precedence

# WRONG: ignoring clustering in panel data
brm(outcome ~ predictor, data = panel_data)

# CORRECT:
brm(outcome ~ predictor + (1 | id), data = panel_data)
```
