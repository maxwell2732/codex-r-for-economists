# Exploration: DDML demo (Double / Debiased Machine Learning)

A self-contained R demo showing why a linear regression with controls is
biased when the controls enter the outcome and treatment equations
non-linearly — and how DDML (Chernozhukov et al. 2018) fixes it.

## What it shows

Five estimators applied to one simulated partial-linear DGP:

1. **OLS (linear-in-X)** — `lm(y ~ D + X)` with HC1 robust SEs
2. **Naive ML (no cross-fitting)** — random-forest residuals on the FULL
   sample, residual-on-residual OLS. Demonstrates that ML alone, without
   cross-fitting, also biases inference (overfit residuals).
3. **DDML — lasso only** — `ddml::ddml_plm` with a single `mdl_glmnet`
   learner and 5-fold cross-fitting. Shows that the choice of learner
   matters: lasso can only fit linear approximations, so this DDML
   variant doesn't help much against non-linear nuisance.
4. **DDML — random forest only** — `mdl_ranger` learner; cuts bias roughly
   in half by fitting the non-linearity.
5. **DDML — stacked** — OLS + glmnet + ranger + xgboost with NNLS stacking
   weights. Lets the data decide which learner is best for each nuisance;
   typically the strongest single estimator.

## DGP

- N = 2,000 observations, p = 20 controls (only 5 relevant, the rest are noise)
- True structural parameter: θ = 1.5
- `g(X) = 0.5·X₁ + 2.0·X₁² + 1.5·sin(X₂) + 1.0·𝟙{X₃ > 0} − 0.8·X₄·X₅`
- `m(X)` has the SAME non-linear features (with slightly different
  coefficients), guaranteeing that the omitted-variable bias from
  linear-in-X is large
- y = θ·D + g(X) + ε_y
- D = m(X) + ε_d

## How to replicate

```bash
Rscript scripts/setup_r.R                 # one-time, installs ddml + learner stack
bash scripts/run_r.sh explorations/ddml_demo/R/01_demo.R
```

## Headline results

| Estimator | θ̂ | Bias |
|---|---|---|
| OLS (linear-in-X) | 2.590 | +1.090 |
| Naive ML (no CF) | 2.189 | +0.689 |
| DDML — lasso only | 2.589 | +1.089 |
| DDML — random forest only | 2.161 | +0.661 |
| **DDML — stacked** | **1.791** | **+0.291** |
| Truth | 1.500 | 0 |

Each stronger learner cuts the bias. Stacking dominates here because xgboost
captures the non-linear terms; the stacking weights plot makes this concrete.

## Outputs

| Path | Contents |
|---|---|
| `output/figures/coefficient_comparison.{pdf,png}` | Forest plot — θ̂ ± 95% CI for each estimator, dashed line at truth |
| `output/figures/learner_weights.{pdf,png}` | NNLS stacking weights by learner × nuisance (E[Y\|X] vs E[D\|X]) |
| `output/tables/coefficient_comparison.csv` | Estimate / SE / 95% CI / bias per estimator |
| `output/tables/coefficient_comparison.tex` | Same as a LaTeX table |

## Status

Exploration (60/100 quality threshold per `.claude/rules/exploration-fast-track.md`).
The simulation is a teaching DGP — strong, deliberately egregious non-linearity
so the bias is visible. Real applications usually see smaller biases but the
same direction.

## Scope deliberately omitted

- Monte Carlo over many simulation draws (would average out the single-draw noise)
- Alternative DDML estimands: `ddml::ddml_ate`, `ddml_late`, `ddml_pliv`
- Cross-fitting fold count > 5 (the standard `n_folds = 10` would be tighter
  but slower; 5 makes the demo run in ~3 minutes)
- HonestDiD-style sensitivity bounds (would be a separate sensitivity exercise)

## Notes for the curious

The biggest pedagogical surprise in this demo is **DDML lasso ≈ OLS**. Many
intro courses present "DDML = ML + cross-fitting" as a unitary recipe, but
the LEARNER inside matters. Lasso can only fit a sparse linear approximation;
if the truth is non-linear, lasso DDML inherits OLS's bias. The figure makes
this concrete by ranking learners from worst to best for this DGP.
