[![DOI](https://zenodo.org/badge/1223030023.svg)](https://doi.org/10.5281/zenodo.19852278)

# R Research Pipeline For Economists 经管专业专属 R 工作流

**Author:** 朱 晨 | 遗传社科研究 Chen Zhu | China Agricultural University (CAU)

**Last Updated:** 2026-05-12

> 可复现、基于日志验证的 R 实证研究 Claude Code 工作流 —— 从原始数据 → 清洗 → 分析 → 发表级表格与图形 → Quarto 报告。

> Reproducible, log-verified R empirical workflow — raw data → cleaning → analysis → publication-ready tables, figures, and Quarto reports — orchestrated through Claude Code.

---

## What lives here 工作流简介

本仓库是我用于 R 实证研究的可复现工作空间。原始数据存放于 `data/raw/`（已被 gitignore，绝不提交）。通过一条命令即可运行完整流程 —— 数据清洗 → 构造 → 分析 → 输出 —— 最终生成发表级别的表格（`output/tables/`）与图形（`output/figures/`）。同时使用 Quarto（knitr 引擎）将结果整合为 HTML / PDF / DOCX 报告。

`explorations/` 文件夹是一个实验沙盒，用于放置探索性分析、教学示例、复现练习以及尚未进入正式流程的一次性脚本。该目录下每个子文件夹都是自包含的——拥有独立的 `R/`、`logs/` 和 `output/`，可以运行而不影响主流程 `R/00_main.R`。在该环境中，质量标准较宽松（60/100，相比正式流程的 80/100），具体规则见 `.claude/rules/exploration-fast-track.md`。当某个探索分析成熟后，可以"晋级"：其 R 脚本会迁移到 `R/01_clean/` … `R/04_output/`，并接入 `00_main.R`，同时必须通过 80/100 的质量门槛。

例如，`explorations/hsb2_teaching_demo/` 是一个基于 UCLA HSB2 数据的本科教学示例（描述统计、直方图、三种嵌套 OLS 规格），适用于教学演示。

Claude Code 在本仓库中被配置为一个承包式执行者：用户描述任务，它制定方案，在 batch 模式下运行 R，验证日志，根据质量标准评分脚本，并输出总结。所有数值结论必须能追溯到日志中的具体代码行———严禁捏造结果！！！

This repository is my reproducible empirical-research workspace for R projects. Raw datasets go in `data/raw/` (gitignored, never committed). A single command runs the full pipeline — clean → construct → analyze → output — producing publication-ready tables in `output/tables/` and figures in `output/figures/`. A Quarto report (knitr engine) weaves the results into HTML / PDF / DOCX.

The `explorations/` folder is the **sandbox** for experimental analyses, teaching demos, replication exercises, and one-off scripts that do not yet belong in the production pipeline. Each subfolder under `explorations/` is self-contained — it has its own `R/`, `logs/`, and `output/` — so an experiment can run without touching `R/00_main.R`. Work in `explorations/` runs under a relaxed quality threshold (60/100 vs. 80/100 for production) per `.claude/rules/exploration-fast-track.md`. When an exploration matures and the analysis is worth keeping, it graduates: the scripts move into `R/01_clean/` … `R/04_output/`, get wired into `00_main.R`, and must clear the standard 80/100 gate.

For example, `explorations/hsb2_teaching_demo/` is a compact undergraduate demo on the UCLA HSB2 dataset (summary stats, histogram, OLS in three nested specs) — useful for teaching but not part of any research pipeline.

Claude Code is configured to act as a contractor: I describe a task, Claude plans the approach, runs R in batch mode, validates the log, scores the script against a quality rubric, and presents a summary. Every numerical claim must trace to a log line — no fabrication.

---

## How Claude Code is configured | Claude Code 配置

The `.claude/` folder contains the workflow infrastructure that drives the contractor mode:

- **7 specialized agents** — `r-reviewer`, `r-log-validator`, `econometric-reviewer`, `domain-reviewer`, `proofreader`, `pedagogy-reviewer`, `verifier`
- **Skills** — R workflow (`/run-r`, `/run-pipeline`, `/build-tables`, `/validate-r-log`, `/replicate`, `/render-report`, `/check-reproducibility`, `/review-r`, `/r-data-analysis`) + governance (`/proofread`, `/validate-bib`, `/devils-advocate`, `/lit-review`, `/research-ideation`, `/interview-me`, `/review-paper`, `/pedagogy-review`, `/commit`)
- **Path-scoped rules** — R coding (`r-coding-conventions`), reproducibility (`r-reproducibility-protocol`), data protection, log verification, econometric best practices, plus governance (plan-first workflow, orchestrator protocol, quality gates, single-source-of-truth, …)
- **Hooks** — `protect-files.sh` guards `R/00_main.R`, `references.bib`, `.gitignore`; plus pre-compact, notify, log-reminder

**Quality gates:** 80 (commit) / 90 (PR) / 95 (excellence). Below 80 blocks the action.

---

## The four guarantees 四大保证（避免 AI 幻觉和数据/结果捏造）

| Guarantee | How it is enforced |
|---|---|
| **Reproducibility** | R version + packages pinned via `renv.lock`, `set.seed()` once, every script logs to `logs/`, fresh-clone test via `scripts/check_reproducibility.sh` |
| **Log-verified results** | `log-verification-protocol` rule + `r-log-validator` agent. No claim ships without a log line backing it. |
| **Data privacy** | `.gitignore` blanket-blocks `data/raw/**`, `data/derived/**`, `*.dta`, `*.rds`, `*.csv` outside whitelisted dirs. Pre-commit `check_data_safety.py` enforces it. |
| **Publication standards** | Tables via `modelsummary` (`.tex` + `.csv`); figures via `ggsave` (`.pdf` + `.png`); `econometric-best-practices` rule on clustering, FE, weights, IV |

---

## Repository layout 仓库结构

```
.
├── CLAUDE.md                       # Project memory (always loaded by Claude)
├── MEMORY.md                       # Persistent [LEARN] entries
├── DESCRIPTION                     # Package-style metadata for renv / IDE
├── .Rprofile                       # Activates renv on R startup
├── renv.lock                       # Pinned package versions
├── references.bib                  # Bibliography (PROTECTED)
├── .claude/                        # Skills, agents, rules, hooks
├── R/
│   ├── 00_main.R                   # Pipeline orchestrator (PROTECTED)
│   ├── 01_clean/                   # Raw → clean .rds
│   ├── 02_construct/               # Variable construction, samples
│   ├── 03_analysis/                # Regressions, IV, DiD, event studies
│   ├── 04_output/                  # modelsummary tables + ggplot exports
│   └── _utils/                     # Reusable helpers (logging, paths)
├── data/
│   ├── raw/                        # GITIGNORED — raw datasets
│   ├── derived/                    # GITIGNORED — intermediate .rds
│   └── README.md                   # Data dictionary
├── logs/                           # GITIGNORED — R logs per script run
├── output/
│   ├── tables/                     # modelsummary .tex/.csv (committed)
│   └── figures/                    # ggsave .pdf/.png (committed)
├── reports/                        # Quarto + knitr engine
├── docs/                           # Rendered HTML reports (GitHub Pages)
├── scripts/                        # Wrappers and quality tooling
├── quality_reports/                # Plans, session logs, merge reports
├── explorations/                   # Sandbox for experimental analyses
└── templates/                      # Skeletons (main-r-template.R, replication-targets, ...)
```

---

## How to use

### One-time setup

```bash
Rscript scripts/setup_r.R
```

Installs the required CRAN packages (`tidyverse`, `haven`, `fixest`, `modelsummary`, `kableExtra`, `ggplot2`, `here`, `fs`, `glue`, `log4r`) and snapshots versions to `renv.lock`.

### Run the full pipeline

```bash
bash scripts/run_pipeline.sh
```

Calls `R/00_main.R`, which orchestrates every stage in dependency order and aborts on the first error.

### Run a single script

```bash
bash scripts/run_r.sh R/03_analysis/main_regression.R
```

The wrapper invokes `Rscript --no-save --no-restore`, runs in batch mode, and writes a log to `logs/<stage>_<name>.log`.

### Render the report

```bash
quarto render reports/analysis_report.qmd
```

### Validate before committing

```bash
python scripts/check_data_safety.py --staged $(git diff --cached --name-only)
python scripts/quality_score.py R/path/file.R
```

The data-safety check is also wired as a `.git/hooks/pre-commit` hook, so accidental `git add data/raw/...` is rejected automatically.

---

## Local environment 本地环境

| Tool | Where | Purpose |
|---|---|---|
| Claude Code | global | Task planning + execution |
| R 4.3+ | `Rscript` on PATH | All analysis scripts |
| renv | bootstrapped by `setup_r.R` | Package version pinning |
| Python 3 | `C:\ProgramData\Miniconda3\` (Miniconda) | Quality scoring + data-safety check |
| Quarto + knitr engine | comes with R | Report rendering |
| gh CLI | global | GitHub workflow |

If `Rscript` is not on PATH, either:

```bash
# Per-session (Windows / Git Bash example):
export PATH="/c/Program Files/R/R-4.3.2/bin:$PATH"
```

…or permanently: Windows Settings → System → Advanced system settings → Environment Variables → Path → Add the R `bin` directory, then restart the shell. After that, `bash scripts/run_r.sh ...` works without any prefix.

> **On interactive R:** Claude Code's bash sandbox has no stdin, so it can only run R in **batch mode** (`Rscript`). For interactive exploration, open RStudio or an `R` console yourself and `source()` the file from there.


---

## License

MIT.
