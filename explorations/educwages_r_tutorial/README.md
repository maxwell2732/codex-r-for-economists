# Exploration: educwages R tutorial

A complete, heavily-annotated R walk-through of the `educwages.csv` returns-to-schooling
dataset for an undergraduate audience. Companion to (and replacement for) the legacy
Stata version archived at `explorations/ARCHIVE/legacy_stata_educwages_tutorial/`.

## Goal

Show students, in one runnable script:

1. How to load a CSV into R and inspect its structure.
2. How to compute summary statistics overall and by subgroup (`dplyr::summarise`).
3. How to compute Pearson correlation coefficients (the matrix + per-pair `cor.test`).
4. How to run one-way and two-way ANOVA (`aov` + `summary`), and the bridge to OLS.
5. How to draw publication-quality figures with `ggplot2` (histogram with normal overlay;
   scatter with OLS fit and 95% CI ribbon; correlation heatmap).
6. How to estimate OLS (`fixest::feols` with HC-robust SEs).
7. How to estimate IV / 2SLS (`feols(... | endog ~ instrument)`), interpret the
   first-stage F, and compare OLS vs IV side-by-side.
8. How to assemble a publication-ready table with `modelsummary` (`.tex` + `.csv` + `.html`).

## How to replicate

From the project root (one-time):

```bash
Rscript scripts/setup_r.R          # installs the package stack, snapshots renv.lock
```

Then run the demo:

```bash
bash scripts/run_r.sh explorations/educwages_r_tutorial/R/01_tutorial.R
```

Or, from inside an interactive R session:

```r
source("explorations/educwages_r_tutorial/R/01_tutorial.R")
```

## Outputs

After a successful run:

| Path | What it contains |
|---|---|
| `logs/explorations_educwages_r_tutorial_R_01_tutorial.log` | Full session transcript: every command, every printed number |
| `output/figures/edu_histogram.{pdf,png}` | Histogram of years of education with normal-density overlay |
| `output/figures/edu_wage_scatter.{pdf,png}` | Scatter of wages vs education with OLS fit + 95% CI ribbon |
| `output/figures/correlation_heatmap.{pdf,png}` | Pearson correlation matrix as a heatmap |
| `output/tables/summary_stats.csv` | N / mean / sd / min / quartiles / max for each numeric variable |
| `output/tables/correlations.csv` | Pairwise Pearson r, t-statistic, df, p-value, 95% CI |
| `output/tables/anova_oneway.csv` | One-way ANOVA: wages ~ edu_cat |
| `output/tables/anova_twoway.csv` | Two-way ANOVA: wages ~ edu_cat + union |
| `output/tables/ols_vs_iv.tex` | OLS vs IV comparison table (LaTeX, for the paper) |
| `output/tables/ols_vs_iv.csv` | Same in CSV (for spreadsheets) |
| `output/tables/ols_vs_iv.html` | Same in HTML (for browser preview / Quarto inclusion) |

The headline IV regression (Section 8) regresses `wages` on `education` instrumented
by `feducation` (father's education). Every coefficient, standard error, and the
first-stage F appear verbatim in the log file.

## Files

```
explorations/educwages_r_tutorial/
├── README.md                 # this file
├── R/
│   ├── 00_inspect.R          # one-off str/summary on the raw CSV
│   └── 01_tutorial.R         # the teaching script
├── logs/                     # written by start_log() at run time
└── output/
    ├── figures/              # ggsave PDF + PNG outputs
    └── tables/               # CSV / TeX / HTML outputs
```

## Status

This is an **exploration** (per `.claude/rules/exploration-fast-track.md`).
Quality threshold: 60/100. The script is teaching code rather than production
research code, so some niceties (no clustered SEs — no panel structure;
no formal weak-instrument-robust inference; no causal interpretation in the
narrative) are deliberately omitted to keep it readable.

## Scope deliberately omitted

- Clustered / two-way clustered SEs (no panel structure in this cross-section)
- Formal weak-IV-robust inference (Anderson-Rubin CIs, Olea-Pflueger)
- Multiple-hypothesis correction across the cor.test results
- Outlier checks (DFBETA, leverage, Cook's distance)
- Causal interpretation of the IV coefficient (the exclusion restriction is
  not credible here; see Section 8 narrative)

These would be the natural next-week extensions if the course continues.

## Reading the log

The log under `logs/` is plain text and structured by section banners
(`*--- N. ... ---`). Useful greps:

```bash
grep -nE "^>>>" logs/explorations_educwages_r_tutorial_R_01_tutorial.log   # section headlines
grep -nE "^Coefficients:|Estimate" logs/explorations_educwages_r_tutorial_R_01_tutorial.log
```
