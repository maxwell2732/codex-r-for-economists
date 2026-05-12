# R/ — analysis pipeline

This directory holds every R script that participates in the production pipeline.
`R/00_main.R` is the single canonical entry point — `bash scripts/run_pipeline.sh`
calls it via `Rscript`.

```
R/
├── 00_main.R          # PROTECTED — pipeline orchestrator (sources stages 1–4)
├── 01_clean/          # raw data → data/derived/clean_*.rds
├── 02_construct/      # samples + variables → data/derived/sample_*.rds
├── 03_analysis/       # regressions → output/tables/, output/figures/
├── 04_output/         # final table/figure assembly
└── _utils/            # logging.R, paths.R, and other reusable helpers
```

## Conventions

- Every script begins with a header block (`File:`, `Project:`, `Author:`,
  `Purpose:`, `Inputs:`, `Outputs:`, `Log:`).
- First line of code: `if (getRversion() < "4.3.0") stop(...)`.
- Open a log with `start_log("<name>")` from `_utils/logging.R`; close with
  `stop_log()`. The log lands at `logs/<name>.log`.
- All paths via `proj_path(...)` (a thin `here::here()` wrapper). Never `setwd()`.
- After every estimation, store the result in a named list (`models[["m_main"]] <- feols(...)`)
  so `modelsummary()` can assemble tables.
- See `.claude/rules/r-coding-conventions.md` for the full standard.

## Adding a new script

1. Copy `templates/analysis-r-template.R` into the appropriate stage folder.
2. Fill in the header, body, and outputs.
3. Wire it into `R/00_main.R` by uncommenting / adding a `source()` line in the
   correct stage block.
4. Run it standalone first (`bash scripts/run_r.sh R/<stage>/<file>.R`),
   inspect the log, then run the full pipeline.
