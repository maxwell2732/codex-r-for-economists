# AGENTS.md - Codex Guide for This R Research Pipeline

This repository is a Codex-ready template for reproducible empirical research in R. It was originally developed from economics and management research workflows, but is also suitable for social science, medicine, public health, epidemiology, health economics, agricultural economics, and other data-intensive empirical fields.

The legacy `.claude/` directory is retained as reference material, but Codex should treat this file as the operational source of truth.

## Repository Purpose

- `R/00_main.R` is the canonical pipeline orchestrator.
- `R/01_clean/`, `R/02_construct/`, `R/03_analysis/`, and `R/04_output/` are the intended production stages.
- `R/_utils/` contains shared helpers for paths, logging, and plot styling.
- `explorations/` contains self-contained demos and sandbox analyses. These may be looser than production code but should still run from the project root and write logs.
- `reports/` contains Quarto report sources. Rendered reports belong in `docs/` when publishing.
- `data/raw/` and `data/derived/` are private, gitignored data areas. Never commit their contents except marker files and documentation.
- `output/tables/` and `output/figures/` are committed research outputs when they are lightweight and intentionally produced.

## Codex Operating Rules

1. Read the relevant script, README, and existing helper code before editing.
2. Keep changes scoped to the requested task. Do not refactor unrelated pipeline stages.
3. Do not fabricate empirical results. Every numerical claim in a response, report, table note, or README update must trace to a log line or an output table cell.
4. Preserve data privacy. Do not inspect, print, summarize, stage, or commit private raw data unless the user explicitly asks for a local analysis of it. Even then, do not include row-level private values in responses.
5. Do not commit files under `data/raw/`, `data/derived/`, or `logs/`.
6. Prefer project helpers over ad hoc code: use `proj_path()` / `here::here()` for paths, `start_log()` / `stop_log()` for logging, and `theme_journal()` for figures when appropriate.
7. Do not use `setwd()` or absolute local paths in R scripts.
8. For stochastic code, set one reproducible seed near the top of the script.
9. After editing analysis code, run the smallest relevant script first, then broader checks if the change affects shared behavior.
10. If R, Python, Quarto, or package dependencies are missing, report the exact blocker and the command that failed.
11. Exploration scripts must write their main verification log inside their own exploration folder, e.g. `explorations/<name>/logs/<script>.log`. A wrapper console log under root `logs/` is useful for failures, but it does not replace the exploration-local log.

## Commands

Use PowerShell from the repository root unless the user asks otherwise.

```powershell
# Run one R script on Windows
scripts\run_r.bat R\00_main.R

# Run one R script on Git Bash / WSL / macOS / Linux
bash scripts/run_r.sh R/00_main.R

# Run the full pipeline
bash scripts/run_pipeline.sh

# Render the Quarto report
quarto render reports/analysis_report.qmd

# Check the tree for unsafe data files
python scripts/check_data_safety.py --scan-tree

# Run data-safety policy regression tests
python scripts/check_data_safety.py --self-test

# Score one R script
python scripts/quality_score.py R/00_main.R
```

For staged-file data checks in PowerShell:

```powershell
$files = git diff --cached --name-only
python scripts/check_data_safety.py --staged $files
```

If `Rscript.exe` is not on `PATH`, locate the installed R version first:

```powershell
where.exe Rscript.exe
Get-ChildItem "C:\Program Files\R" -Directory
```

Then run with a session-local `PATH` update, for example:

```powershell
$env:PATH = "C:\Program Files\R\R-4.5.0\bin;$env:PATH"
scripts\run_r.bat R\00_main.R
```

## R Script Requirements

Production `.R` scripts should include:

```r
if (getRversion() < "4.3.0") stop("Requires R >= 4.3.0; you have ", R.version.string)

source("R/_utils/paths.R")
source("R/_utils/logging.R")

start_log("<stage>_<name>")
on.exit(stop_log(), add = TRUE)
```

Use a file header that records purpose, inputs, outputs, and log path. Scripts should be runnable from a fresh clone with `Rscript` from the project root.

For scripts under `explorations/<name>/R/`, create `explorations/<name>/logs/` and pass it explicitly to `start_log()`:

```r
demo_dir <- proj_path("explorations", "<name>")
log_dir <- file.path(demo_dir, "logs")
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

start_log("<script_name>", dir = log_dir)
on.exit(stop_log(), add = TRUE)
```

This exploration-local log is the canonical audit trail for classroom demos and sandbox analyses. Do not rely only on the root-level wrapper console log.

## Verification Workflow

For any substantive R change:

1. Run the edited script with `scripts\run_r.bat` or `bash scripts/run_r.sh`.
2. Confirm the expected `logs/*.log` file exists.
3. Inspect the last lines of the log and any warnings or errors.
4. Confirm expected `output/tables/` and `output/figures/` files exist when the task produces outputs.
5. Run `python scripts/quality_score.py <changed-file>` for changed R scripts when practical.
6. Run `python scripts/check_data_safety.py --scan-tree` before committing or when new files are created.

For documentation-only edits, at minimum check `git diff --check` and the data-safety scan if new files were added.

## Quality Gates

- `80/100`: minimum score for committing production analysis code.
- `90/100`: target for pull-request-ready scripts.
- `95/100`: aspirational standard for polished reusable code.
- Exploration scripts may be accepted at `60/100` only when they are clearly sandbox work and the limitations are documented.

## Data Safety

Blocked by policy:

- `data/raw/**` except `.gitkeep` and README-style documentation.
- `data/derived/**` except `.gitkeep` and README-style documentation.
- `logs/**`.
- Raw data-like files such as `.dta`, `.sav`, `.parquet`, `.feather`, `.rds`, `.RData`, `.xls`, `.xlsx`, global `*.csv`, and global `*.json` outside explicit table-output or example directories.
- `explorations/**/output/**/*.dta` and similar binary outputs are blocked by default because sandbox output can contain temporary cleaned panels or restricted microdata.

Run `scripts/check_data_safety.py` before staging broad changes.

## Reports and Outputs

- Tables should generally be exported as `.csv` plus publication formats such as `.tex` or `.html`.
- Figures should generally be exported as `.png` plus `.pdf`.
- Reports should consume saved outputs, not silently recompute unrelated analyses.
- If a report states a statistic, verify it against logs or saved tables.

## Existing Claude Assets

The `.claude/` folder contains useful historical rules, agents, and skills. Codex may consult those markdown files for domain guidance, especially:

- `.claude/rules/r-coding-conventions.md`
- `.claude/rules/r-reproducibility-protocol.md`
- `.claude/rules/log-verification-protocol.md`
- `.claude/rules/data-protection.md`
- `.claude/rules/econometric-best-practices.md`
- `.claude/rules/quality-gates.md`

These files are advisory for Codex; `AGENTS.md` governs how to operate in this repository.
