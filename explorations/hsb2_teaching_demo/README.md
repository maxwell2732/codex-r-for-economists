# Exploration: HSB2 Teaching Demonstration

A compact, end-to-end R workflow for an undergraduate audience.
Demonstrates summary statistics, a basic histogram, and an OLS regression
on the UCLA "High School and Beyond" sample (`data/raw/hsb2.dta`, 200 obs).

## Goal

Show students:

1. How to load a dataset and inspect its structure (`str`, `summary`, `head`).
2. How to compute summary statistics overall and by subgroup
   (`summary`, `table`, `dplyr::group_by + summarise`).
3. How to draw a histogram with a normal overlay (`ggplot2::geom_histogram` +
   `stat_function`).
4. How to run a series of nested OLS regressions, store the results, and
   present them side-by-side (`lm`, `broom::tidy`, manual table assembly via
   `dplyr::bind_rows`).

## How to replicate

From the project root (one-time):

```bash
Rscript scripts/setup_r.R          # installs the package stack
```

Then run the demo:

```bash
bash scripts/run_r.sh explorations/hsb2_teaching_demo/R/01_demo.R
```

If `Rscript` is not on your `PATH`, add R's `bin/` directory to it first
(Windows: typically `C:\Program Files\R\R-4.x.x\bin`).

Or, from inside an interactive R session:

```r
source("explorations/hsb2_teaching_demo/R/01_demo.R")
```

## Outputs

After a successful run:

| Path | What it contains |
|---|---|
| `logs/explorations_hsb2_teaching_demo_R_01_demo.log` | Full session transcript: every command, every number |
| `output/figures/write_histogram.pdf` (and `.png`) | Histogram of writing scores with normal overlay |
| `output/tables/coef_table.csv` | Side-by-side comparison of three OLS specifications |

The headline regression (Spec 3) regresses `write` on `read`, `math`,
`female`, and indicators for `race` and `prog`. Every coefficient,
standard error, and R² appears verbatim in the log file.

## Files

```
explorations/hsb2_teaching_demo/
├── README.md                 # this file
├── R/
│   ├── 00_inspect.R          # one-off str/summary (used to confirm vars)
│   └── 01_demo.R             # the teaching script
├── logs/                     # written by start_log()
└── output/
    ├── figures/
    │   ├── write_histogram.pdf
    │   └── write_histogram.png
    └── tables/
        └── coef_table.csv
```

## Status

This is an **exploration** (per `.claude/rules/exploration-fast-track.md`).
Quality threshold: 60/100. The script is teaching code, not production
research code, so some niceties (no `feols`, no clustered SEs, no
robustness section) are deliberately omitted to keep it readable.

## Scope deliberately omitted

- Robust / clustered standard errors (`sandwich::vcovHC`, `feols(..., cluster = ~ ...)`)
- Heteroskedasticity diagnostics (Breusch–Pagan, etc.)
- Outlier checks (DFBETA, Cook's distance, leverage)
- Multiple-hypothesis correction
- Causal interpretation of the coefficients

These would be the natural next-week extensions if the course continues.
