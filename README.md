# Stata Research Pipeline

> Reproducible, log-verified Stata empirical workflow — raw data → cleaning → analysis → publication-ready tables, figures, and Quarto reports — orchestrated through Claude Code.

**Author:** Chen Zhu | China Agricultural University (CAU)
**Last Updated:** 2026-04-28

---

## What lives here

This repository is my reproducible empirical-research workspace for Stata projects. Raw datasets go in `data/raw/` (gitignored, never committed). A single command runs the full pipeline — clean → construct → analyze → output — producing publication-ready tables in `output/tables/` and figures in `output/figures/`. A Quarto report (Stata engine) weaves the results into HTML / PDF / DOCX.

The `explorations/` folder is the **sandbox** for experimental analyses, teaching demos, replication exercises, and one-off scripts that do not yet belong in the production pipeline. Each subfolder under `explorations/` is self-contained — it has its own `dofiles/`, `logs/`, and `output/` — so an experiment can run without touching `dofiles/00_master.do`. Work in `explorations/` runs under a relaxed quality threshold (60/100 vs. 80/100 for production) per `.claude/rules/exploration-fast-track.md`. When an exploration matures and the analysis is worth keeping, it graduates: the do-files move into `dofiles/01_clean/` … `dofiles/04_output/`, get wired into `master.do`, and must clear the standard 80/100 gate.

For example, `explorations/hsb2_teaching_demo/` is a compact undergraduate demo on the UCLA HSB2 dataset (summary stats, histogram, OLS in three nested specs) — useful for teaching but not part of any research pipeline.

Claude Code is configured to act as a contractor: I describe a task, Claude plans the approach, runs Stata in batch mode, validates the log, scores the do-file against a quality rubric, and presents a summary. Every numerical claim must trace to a log line — no fabrication.

---

## The four guarantees

| Guarantee | How it is enforced |
|---|---|
| **Reproducibility** | `version` pinned, `set seed` once, every do-file logs to `logs/`, fresh-clone test via `scripts/check_reproducibility.sh` |
| **Log-verified results** | `log-verification-protocol` rule + `log-validator` agent. No claim ships without a log line backing it. |
| **Data privacy** | `.gitignore` blanket-blocks `data/raw/**`, `data/derived/**`, `*.dta`, `*.csv` outside whitelisted dirs. Pre-commit `check_data_safety.py` enforces it. |
| **Publication standards** | Tables via `esttab` (`.tex` + `.csv`); figures via `graph export` (`.pdf` + `.png`); `econometric-best-practices` rule on clustering, FE, weights, IV |

---

## How to use

### Run the full pipeline

```bash
bash scripts/run_pipeline.sh
```

Calls `dofiles/00_master.do`, which orchestrates every stage in dependency order and aborts on the first error.

### Run a single do-file

```bash
bash scripts/run_stata.sh dofiles/03_analysis/main_regression.do
```

The wrapper finds Stata on `PATH` (tries `stata-mp`, `stata-se`, `stata`, `StataMP-64`, `StataSE-64`, `Stata-64` in order), runs it in batch mode, and writes a log to `logs/<stage>_<name>.log`.

### Render the report

```bash
quarto render reports/analysis_report.qmd
```

### Validate before committing

```bash
python scripts/check_data_safety.py --staged $(git diff --cached --name-only)
python scripts/quality_score.py dofiles/path/file.do
```

The data-safety check is also wired as a `.git/hooks/pre-commit` hook, so accidental `git add data/raw/...` is rejected automatically.

---

## Repository layout

```
.
├── CLAUDE.md                       # Project memory (always loaded by Claude)
├── MEMORY.md                       # Persistent [LEARN] entries
├── references.bib                  # Bibliography (PROTECTED)
├── .claude/                        # Skills, agents, rules, hooks
├── dofiles/
│   ├── 00_master.do                # Pipeline orchestrator (PROTECTED)
│   ├── 01_clean/                   # Raw → clean .dta
│   ├── 02_construct/               # Variable construction, samples
│   ├── 03_analysis/                # Regressions, IV, DiD, event studies
│   ├── 04_output/                  # esttab tables + graph exports
│   └── _utils/                     # Reusable helpers
├── data/
│   ├── raw/                        # GITIGNORED — raw datasets
│   ├── derived/                    # GITIGNORED — intermediate .dta
│   └── README.md                   # Data dictionary
├── logs/                           # GITIGNORED — Stata logs per do-file run
├── output/
│   ├── tables/                     # esttab .tex/.csv (committed)
│   └── figures/                    # graph export .pdf/.png (committed)
├── reports/                        # Quarto + Stata engine
├── docs/                           # Rendered HTML reports (GitHub Pages)
├── scripts/                        # Wrappers and quality tooling
├── quality_reports/                # Plans, session logs, merge reports
├── explorations/                   # Sandbox for experimental analyses
└── templates/                      # Skeletons (master.do, replication-targets, ...)
```

---

## Local environment

| Tool | Where | Purpose |
|---|---|---|
| Claude Code | global | Task planning + execution |
| Stata 15 | `C:\Program Files (x86)\Stata15\` | All do-files |
| Python 3 | `C:\ProgramData\Miniconda3\` (Miniconda) | Quality scoring + data-safety check |
| Quarto + Stata engine | `pip install nbstata` | Report rendering |
| gh CLI | global | GitHub workflow |

Stata 15 is not on `PATH` by default. To use the wrappers, either:

```bash
# Per-session:
export PATH="/c/Program Files (x86)/Stata15:$PATH"
```

…or permanently: Windows Settings → System → Advanced system settings → Environment Variables → Path → Add `C:\Program Files (x86)\Stata15`, then restart the shell. After that, `bash scripts/run_stata.sh ...` works without any prefix.

User-written Stata commands installed via `ssc install`: `reghdfe`, `ftools`, `estout`, `ivreg2`, `ranktest`, `boottest`. The install recipe is in `dofiles/00_master.do` behind a one-flag toggle.

> **On interactive Stata:** Claude Code's bash sandbox has no stdin, so it can only run Stata in **batch mode** (`stata -b`). For interactive exploration, open a Stata session yourself and `do` the file from there.

---

## How Claude Code is configured

The `.claude/` folder contains the workflow infrastructure that drives the contractor mode:

- **7 specialized agents** — `stata-reviewer`, `log-validator`, `econometric-reviewer`, `domain-reviewer`, `proofreader`, `pedagogy-reviewer`, `verifier`
- **19 skills** — Stata workflow (`/run-stata`, `/run-pipeline`, `/build-tables`, `/validate-log`, `/replicate`, `/render-report`, `/check-reproducibility`, `/review-stata`, `/data-analysis`) + a comprehensive auto-loaded `stata` reference skill (38 core topic guides + 20 community-package guides; vendored from [`dylantmoore/stata-skill`](https://github.com/dylantmoore/stata-skill)) + governance (`/proofread`, `/validate-bib`, `/devils-advocate`, `/lit-review`, `/research-ideation`, `/interview-me`, `/review-paper`, `/pedagogy-review`, `/commit`)
- **18 path-scoped rules** — Stata coding (`stata-coding-conventions`), reproducibility, data protection, log verification, econometric best practices, plus governance (plan-first workflow, orchestrator protocol, quality gates, single-source-of-truth, …)
- **5 hooks** — `protect-files.sh` guards `dofiles/00_master.do`, `references.bib`, `.gitignore`; plus pre-compact, post-merge, notify, log-reminder

**Quality gates:** 80 (commit) / 90 (PR) / 95 (excellence). Below 80 blocks the action.

---

## License

MIT. Use freely.
