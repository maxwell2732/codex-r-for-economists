# CLAUDE.md — R Research Pipeline for Economists (Template)

<!-- HOW TO USE: Replace [BRACKETED PLACEHOLDERS] when forking this template.
     Keep this file under ~150 lines — Claude loads it every session.
     See README.md for setup instructions. -->

**Project:** [YOUR PROJECT NAME] — R Research Pipeline (forked from `claudecode-r-for-economists`)
**Maintainer:** [YOUR NAME] — [YOUR INSTITUTION]
**Template author:** Chen Zhu — China Agricultural University (CAU)
**Branch:** main

---

## Core Principles

- **Plan first** — enter plan mode before non-trivial tasks; save plans to `quality_reports/plans/`
- **Verify after** — run the script, inspect the log, confirm output exists at the end of every task
- **Single source of truth** — `R/00_main.R` is authoritative; reports include only outputs it produces
- **Log-verified results** — every numerical claim must trace to a `logs/*.log` line or `output/tables/*.csv` cell. **No log, no claim.**
- **Data privacy** — nothing under `data/raw/` or `data/derived/` is ever committed. Pre-commit safety check enforced.
- **Reproducibility** — R version + packages pinned via `renv.lock`, `set.seed(YYYYMMDD)` once, `.R` files runnable from a fresh clone via `Rscript`
- **Quality gates** — nothing ships below 80/100
- **[LEARN] tags** — when corrected, save `[LEARN:category] wrong → right` to MEMORY.md

---

## Folder Structure

```
[YOUR-PROJECT]/
├── CLAUDE.md                       # This file
├── .claude/                        # Rules, skills, agents, hooks
├── DESCRIPTION                     # Package-style metadata for renv / IDE
├── .Rprofile                       # Activates renv on R startup
├── renv.lock                       # Pinned package versions
├── references.bib                  # Centralized bibliography
├── R/
│   ├── 00_main.R                   # Pipeline orchestrator (PROTECTED)
│   ├── 01_clean/                   # Raw → clean .rds / .parquet
│   ├── 02_construct/               # Variable construction, samples
│   ├── 03_analysis/                # Regressions, IV, DiD, event studies
│   ├── 04_output/                  # modelsummary tables + ggplot figures
│   └── _utils/                     # Reusable helpers (logging, paths, …)
├── data/
│   ├── raw/                        # GITIGNORED — raw datasets (never committed)
│   ├── derived/                    # GITIGNORED — intermediate .rds / .parquet
│   └── README.md                   # Data dictionary + provenance
├── logs/                           # GITIGNORED — *.log per script run
├── output/
│   ├── tables/                     # modelsummary .tex/.csv/.html (committed)
│   └── figures/                    # ggsave .pdf/.png/.svg (committed)
├── reports/
│   ├── analysis_report.qmd         # Quarto + knitr (R) engine
│   └── _quarto.yml
├── docs/                           # Rendered HTML reports (GitHub Pages)
├── scripts/                        # run_r.sh, setup_r.R, quality_score.py, …
├── quality_reports/                # Plans, session logs, merge reports
├── explorations/                   # Sandbox (see exploration rules)
├── templates/                      # main-r-template.R, replication-targets, …
└── master_supporting_docs/         # Reference papers
```

---

## Commands

```bash
# One-time: install the R stack and snapshot renv
Rscript scripts/setup_r.R

# Run a single R script (creates logs/<name>.log, returns Rscript exit code)
bash scripts/run_r.sh R/03_analysis/main_regression.R

# Run the full pipeline (calls R/00_main.R, aborts on first error)
bash scripts/run_pipeline.sh

# Render the Markdown/PDF report (Quarto + knitr engine)
quarto render reports/analysis_report.qmd

# Pre-commit data-safety check (recommended as git pre-commit hook)
python scripts/check_data_safety.py --staged $(git diff --cached --name-only)

# Quality score for an R script (0–100)
python scripts/quality_score.py R/03_analysis/main_regression.R
```

---

## R Conventions (Non-Negotiable)

- **R version on this machine:** R 4.3 or newer (check `R.version.string`).
  Required: `Rscript` resolvable on PATH; `renv` package installed (the `setup_r.R` bootstrap handles this).
- **Pin R version + packages** via `renv.lock`. The first non-comment line of every script declares the minimum R version: `if (getRversion() < "4.3.0") stop("Requires R >= 4.3.0")`.
- **Required CRAN packages:** `tidyverse`, `haven`, `fixest`, `modelsummary`, `kableExtra`, `ggplot2`, `here`, `fs`, `glue`, `log4r`. See `templates/main-r-template.R` for the bootstrap recipe.
- **Per-script logging:** `start_log("<name>")` at the top, `stop_log()` at the bottom (helpers in `R/_utils/logging.R`). Writes `logs/<stage>_<name>.log`.
- **Reproducible randomness:** `set.seed(YYYYMMDD)` near the top of any script using `rnorm/runif/sample/bootstrap/simulate`, never inside loops.
- **Relative paths only** — never `setwd()` to absolute paths; always reference from project root via `here::here()`.
- **Cluster SEs** at the most aggregate plausible level by default (`fixest::feols(... cluster = ~ id)`); document the choice.

---

## Quality Thresholds

| Score | Gate | Meaning |
|-------|------|---------|
| 80 | Commit | Good enough to save |
| 90 | PR | Ready for deployment |
| 95 | Excellence | Aspirational |

---

## Skills Quick Reference

| Command | What It Does |
|---------|-------------|
| `/run-r [file.R]` | Execute R script in batch mode + tail log |
| `/run-pipeline` | Run `R/00_main.R` end-to-end |
| `/build-tables` | Combine saved `models[[...]]` results into publication `modelsummary` output |
| `/validate-r-log [file.log]` | Scan log for errors; cross-check claimed results |
| `/replicate [paper]` | Replication protocol against a paper's reported results |
| `/render-report [report.qmd]` | Render Quarto report (knitr engine) |
| `/check-reproducibility` | Fresh-clone simulation: run pipeline + diff outputs |
| `/review-r [file.R]` | R code-quality review |
| `/r-data-analysis [topic]` | End-to-end R analysis workflow |
| `/proofread [file]` | Grammar / typo / consistency review |
| `/validate-bib` | Cross-reference citations against `references.bib` |
| `/devils-advocate` | Challenge analytical decisions before committing |
| `/lit-review [topic]` | Literature search + synthesis |
| `/research-ideation [topic]` | Research questions + empirical strategies |
| `/interview-me [topic]` | Interactive research interview |
| `/review-paper [file]` | Manuscript review |
| `/pedagogy-review [file]` | Narrative + notation review (for reports) |
| `/commit [msg]` | Stage, commit, PR, merge |

---

## Pipeline Stages

| # | Stage Folder | Inputs | Outputs |
|---|--------------|--------|---------|
| 1 | `R/01_clean/` | `data/raw/*` | `data/derived/clean_*.rds` |
| 2 | `R/02_construct/` | `data/derived/clean_*.rds` | `data/derived/sample_*.rds` |
| 3 | `R/03_analysis/` | `data/derived/sample_*.rds` | `output/tables/*.tex`, `output/figures/*.pdf`, saved model lists |
| 4 | `R/04_output/` | `output/tables/*`, `output/figures/*` | rendered `reports/analysis_report.qmd` → `docs/*.html` |

---

## Protected Files (do not edit without intent)

`R/00_main.R`, `references.bib`, `.gitignore` are guarded by a PreToolUse hook (`.claude/hooks/protect-files.sh`). Edit manually if you must, or relax the protection list there.
