# Exploration: Staggered DiD demo (TWFE bias + heterogeneity-robust fixes)

A self-contained R demo of why naive two-way-fixed-effects (TWFE) regressions
are biased under staggered treatment adoption with heterogeneous effects, and
how three modern estimators recover the truth on simulated data.

## What it shows

Four estimators applied to one simulated staggered-treatment panel:

1. **TWFE (naive)** — `fixest::feols(y ~ i(event_time) | id + period)`
2. **Sun–Abraham (2021)** — `fixest::feols(y ~ sunab(cohort, period) | id + period)`
3. **Callaway–Sant'Anna (2021)** — `did::att_gt() %>% aggte("dynamic")`
4. **Borusyak–Jaravel–Spiess (2024)** — `did2s::did2s()`

The simulated DGP has:
- N = 600 units, T = 10 periods
- Three treated cohorts (treated at t = 3, 5, 7) plus a never-treated control
- True ATT heterogeneous in BOTH cohort and event time (early cohorts get
  larger and faster-growing effects)

Under this design, the naive TWFE estimator implicitly compares
already-treated units against not-yet-treated ones, biasing the average
event-study coefficients toward zero. The three heterogeneity-robust
estimators all recover the true ATT(e) within sampling noise.

## How to replicate

From the project root:

```bash
Rscript scripts/setup_r.R                 # one-time, installs did/did2s/staggered/HonestDiD/...
bash scripts/run_r.sh explorations/staggered_did_demo/R/01_demo.R
```

## Outputs

| Path | Contents |
|---|---|
| `output/figures/data_visualisation.{pdf,png}` | Cohort-mean outcomes over time with treatment dates marked |
| `output/figures/event_study_comparison.{pdf,png}` | All four estimators' event-study coefficients overlaid against the truth |
| `output/tables/pooled_att_comparison.csv` | Pooled ATT and bias relative to the truth, one row per estimator |
| `output/tables/pooled_att_comparison.tex` | Same in modelsummary LaTeX form |

## Reading the figure

In `event_study_comparison.{pdf,png}`:
- The dashed black line is the truth, with black dots marking the per-event-time average
- The four estimators are dodged side-by-side at each event time with 95 % CIs
- The TWFE points sit visibly below the truth at large event times — that's the bias

## Status

Exploration (60/100 quality threshold per `.claude/rules/exploration-fast-track.md`).
The simulation is a teaching DGP rather than a calibrated empirical setting; the
goal is to make the bias visible, not to produce a publication-grade Monte
Carlo.

## Scope deliberately omitted

- HonestDiD parallel-trends sensitivity (it's installed and you can call
  `HonestDiD::createSensitivityResults_relativeMagnitudes()` on the
  CS or BJS estimates if you want to extend)
- Wild-cluster bootstrap (`fwildclusterboot`) — requires a Rust toolchain
  that's not always available
- Multiple cluster levels
