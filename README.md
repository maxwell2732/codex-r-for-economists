# Stata Research Pipeline for Economists

> A forkable Claude Code template for **reproducible, log-verified Stata research workflows** — from raw data to publication-ready tables, figures, and Markdown / PDF reports.

**Author:** Chen Zhu | China Agricultural University (CAU)
**Last Updated:** 2026-04-28

---

## What this template gives you

You fork this repository, drop your raw datasets into `data/raw/` (which is `.gitignore`'d), and run **one command**:

```bash
bash scripts/run_pipeline.sh
```

`dofiles/00_master.do` orchestrates four stages — **clean → construct → analyze → output** — producing publication-ready tables in `output/tables/` and figures in `output/figures/`. A Quarto report (with the Stata engine) weaves the results into Markdown / HTML / PDF. Every claimed number traces to a log line. Raw data never leaves your machine.

Claude Code (with this template's configuration) acts as a **contractor**: you describe a task; Claude plans the approach, runs Stata in batch mode, validates the log, scores the do-file against a quality rubric, and presents a summary. It only commits when the score passes the gate.

---

## The four guarantees

| Guarantee | How it is enforced |
|---|---|
| **Reproducibility** | `version` pinned, `set seed` once, every do-file logs to `logs/`, fresh-clone test via `scripts/check_reproducibility.sh` |
| **Log-verified results** | `log-verification-protocol` rule + `log-validator` agent. No claim ships without a log line backing it. |
| **Data privacy** | `.gitignore` blanket-blocks `data/raw/**`, `data/derived/**`, `*.dta`, `*.csv` outside whitelisted dirs. Pre-commit `check_data_safety.py` enforces it. |
| **Publication standards** | Tables via `esttab` (`.tex` + `.csv`); figures via `graph export` (`.pdf` + `.png`); `econometric-best-practices` rule on clustering, FE, weights, IV |

---

## Quick start (10 minutes)

### Step 1 — Fork and clone

Fork this repo on GitHub (click "Fork"), then:

```bash
git clone https://github.com/YOUR_USERNAME/claudecode-stata-for-economists.git my-paper
cd my-paper
```

Replace `YOUR_USERNAME` and `my-paper` with your values.

### Step 2 — Verify your environment (one minute)

Claude Code uses your shell's `PATH` to find Stata, Python, and Quarto. Run these checks first; if any fails, see [Troubleshooting](#troubleshooting) below.

```bash
# Stata: at least one of these should print a version
stata-mp -h | head -1     # macOS / Linux Stata-MP
stata-se -h | head -1     # macOS / Linux Stata-SE
stata    -h | head -1     # any Stata
StataMP-64 -h | head -1   # Windows Stata-MP
StataSE-64 -h | head -1   # Windows Stata-SE

# Python 3
python --version          # or: python3 --version (need 3.8+)

# Quarto
quarto --version
quarto check stata        # confirms the Stata engine is installed
```

The `scripts/run_stata.sh` wrapper tries `stata-mp`, `stata-se`, `stata`, `StataMP-64`, `StataSE-64`, `Stata-64` in order and uses the first one it finds. As long as one of these is on your `PATH`, Claude Code will find it.

If Stata is installed but not on your `PATH`, add the install directory to your shell config (`~/.bashrc`, `~/.zshrc`, or Windows System Environment Variables → PATH).

### Step 3 — Open Claude Code

```bash
claude
```

Or open the Claude Code panel in VS Code / Cursor / your IDE.

### Step 4 — Paste the initialization prompt

Copy the block below into Claude Code, **filling in the bracketed placeholders** with your project's specifics. This is the canonical first prompt; it tells Claude what you are building, how strict to be, and what workflow to use.

```text
I am building **[YOUR PROJECT NAME]** in this repository — a Stata-based
empirical study of **[your research question, in one sentence]**.

The data are: **[describe your raw datasets — sources, periods, units]**.
They live in `data/raw/` (gitignored). Public-use / restricted /
proprietary: **[which]**.

I want our collaboration to be structured, precise, and consistent with top
empirical economics standards. All outputs must be verifiable through logs
and scripts. Never fabricate results, and never claim an analysis was run
unless it appears in a log file or output artifact. Tables and figures must
be clean, publication-ready, and follow the conventions in
`.claude/rules/econometric-best-practices.md`.

Your first task is to:

1. Read `CLAUDE.md`, `MEMORY.md`, the rules under `.claude/rules/`, and the
   skills under `.claude/skills/` to understand the workflow that is already
   in place for this template.

2. Fill in the project-specific placeholders:
   - `CLAUDE.md` (project name, my name + institution, Stata version pin if
     not 17)
   - `data/README.md` (data dictionary for my datasets)
   - `.claude/rules/knowledge-base-template.md` (estimands, notation,
     identification assumptions for my project)
   - `.claude/agents/domain-reviewer.md` (review lenses for my sub-field)

3. Wire the data-safety pre-commit hook per
   `templates/CONTRIBUTING-FOR-FORKERS.md`.

After that, switch to plan-first workflow for all non-trivial tasks. Once I
approve a plan, switch to contractor mode — coordinate scripts, do-files,
and outputs autonomously. Only return to me if there is genuine ambiguity
or a decision that needs my judgment.

Enter plan mode now and propose how to handle steps 1–3.
```

Claude reads the configuration, asks any clarifying questions, presents a plan, and after your approval executes it. From that point on you describe what you want; Claude plans, runs Stata, validates logs, scores the work, and reports back.

If you prefer to configure manually before talking to Claude, see [`templates/CONTRIBUTING-FOR-FORKERS.md`](templates/CONTRIBUTING-FOR-FORKERS.md) for the step-by-step checklist.

---

## How it works

### Contractor mode

You describe a task. For non-trivial work Claude first writes a requirements spec (MUST / SHOULD / MAY), then a plan (saved to `quality_reports/plans/`). After approval, Claude implements, runs the do-file, validates the log, scores the result, and presents a summary. Say "just do it" and it auto-commits when the score passes.

### Specialized agents

| Agent | Mission |
|---|---|
| `stata-reviewer` | Reviews `.do` files: header, version pin, logging, naming, magic numbers, polish |
| `log-validator` | Confirms claimed results actually appear in `logs/*.log` — refuses fabrication |
| `econometric-reviewer` | Spec review: clustering level, FE, weights, IV first-stage F, sample selection |
| `domain-reviewer` | Field-specific substance (template — adapt for your sub-discipline) |
| `proofreader` | Grammar / typos in reports |
| `pedagogy-reviewer` | Narrative and notation clarity in the report |
| `verifier` | End-to-end: do-files run, logs exist, outputs render |

### Quality gates

Every artifact gets a 0–100 score. Below threshold blocks the action.

| Score | Gate |
|---|---|
| 80 | Commit |
| 90 | PR |
| 95 | Excellence (aspirational) |

### Context survival

Plans, specs, and session logs survive auto-compression. `MEMORY.md` accumulates `[LEARN]` entries across sessions.

---

## Repository layout

```
.
├── CLAUDE.md                       # Project memory (always loaded)
├── MEMORY.md                       # Persistent [LEARN] entries
├── references.bib                  # Bibliography (PROTECTED)
├── .claude/                        # Skills, agents, rules, hooks
├── dofiles/
│   ├── 00_master.do                # Orchestrator (PROTECTED)
│   ├── 01_clean/                   # Raw → clean .dta
│   ├── 02_construct/               # Variable construction, samples
│   ├── 03_analysis/                # Regressions, IV, DiD, event studies
│   ├── 04_output/                  # esttab tables + graph exports
│   └── _utils/                     # Reusable helpers
├── data/
│   ├── raw/                        # GITIGNORED — your raw datasets
│   ├── derived/                    # GITIGNORED — intermediate .dta
│   └── README.md                   # Data dictionary
├── logs/                           # GITIGNORED — Stata logs per do-file
├── output/
│   ├── tables/                     # esttab .tex/.csv (committed)
│   └── figures/                    # graph export .pdf/.png (committed)
├── reports/                        # Quarto + Stata engine
├── docs/                           # Rendered HTML reports (GitHub Pages)
├── scripts/                        # Wrappers and quality tooling
├── quality_reports/                # Plans, session logs, merge reports
├── explorations/                   # Sandbox for experimental analyses
└── templates/                      # Master.do, replication-targets, …
```

---

## Prerequisites

| Tool | Required for | Install |
|---|---|---|
| [Claude Code](https://code.claude.com/docs/en/overview) | Everything | `npm install -g @anthropic-ai/claude-code` |
| Stata 17+ | All do-files | [stata.com](https://www.stata.com/) — must be on PATH |
| [Quarto](https://quarto.org) | Report rendering | [quarto.org/docs/get-started](https://quarto.org/docs/get-started/) |
| Stata Quarto engine | Quarto + Stata reports | `pip install jupyter nbstata` (or `pystata`) |
| Python 3.8+ | Quality scoring + data-safety check | [python.org](https://www.python.org/) — see Windows note in Troubleshooting |
| [gh CLI](https://cli.github.com/) | PR workflow (optional) | platform-dependent |

Required user-written Stata commands (install once via `ssc install`): `reghdfe`, `ftools`, `estout`, `ivreg2`, `ranktest`, `boottest`. The orchestrator's `templates/master-do-template.do` includes the full install recipe behind a one-flag toggle.

---

## Troubleshooting

### "Stata not found on PATH"

The wrapper `scripts/run_stata.sh` tries six common Stata executable names. If none works:

- **macOS:** Stata installs to `/Applications/Stata/`. Add the bin to PATH:
  ```bash
  echo 'export PATH="/Applications/Stata:$PATH"' >> ~/.zshrc && source ~/.zshrc
  ```
  Confirm with `which stata-mp`.

- **Linux:** typical install path is `/usr/local/stata17/`. Add to PATH similarly.

- **Windows:** Stata installs to `C:\Program Files\Stata17\`. Either:
  - Add it to System PATH (Control Panel → System → Environment Variables → Path → Edit → New), then restart your shell. Confirm with `where StataMP-64`.
  - Or run Claude Code from an Anaconda Prompt / Git Bash shell that has Stata on PATH already.

After fixing, re-run `stata-mp -h` (or your flavor) to confirm before continuing.

### `python` opens the Microsoft Store on Windows

Windows ships a stub at `C:\Users\<you>\AppData\Local\Microsoft\WindowsApps\python.exe` that opens the Store instead of running Python. If `python --version` exits silently or prints nothing:

- **Easiest:** install Python from [python.org](https://www.python.org/downloads/windows/) (check "Add to PATH" in the installer). It also installs the `py` launcher; `py --version` will work.
- **Or** install Anaconda / Miniconda; activate the base environment so `conda run python` works.
- **Or** disable the Store stub: Settings → Apps → Advanced app settings → App execution aliases → turn off `python.exe` and `python3.exe`.

After fixing, the scripts in `scripts/*.py` work via `python` or `python3`. The pre-commit data-safety hook in `templates/CONTRIBUTING-FOR-FORKERS.md` uses `python`; substitute `py` if you prefer.

### "Quarto Stata engine not installed"

`quarto check stata` prints `Stata: NOT OK` if the engine is missing. Install it:

```bash
pip install jupyter nbstata     # most common path
# or
pip install pystata             # alternative; requires a Stata license link
```

Then `quarto check stata` should print `Stata: OK`. The `/render-report` skill performs this check before rendering and emits an actionable message if missing.

### Pre-commit hook does not block raw data

If you can `git add data/raw/something.dta` without an error, the hook is not wired:

```bash
cat > .git/hooks/pre-commit <<'EOF'
#!/bin/bash
python scripts/check_data_safety.py --staged $(git diff --cached --name-only)
EOF
chmod +x .git/hooks/pre-commit
```

Test by `touch data/raw/test_blocker.dta && git add -f data/raw/test_blocker.dta && git commit -m "should-fail"`. The commit must be rejected.

### Claude Code says it cannot find a tool

Claude Code's bash sandbox uses your shell's `PATH`. If `stata-mp`, `quarto`, or `python` works in your terminal but Claude Code says it cannot find them, check that you launched `claude` from the same shell. If you launched from a system menu, the GUI process may not have your custom PATH; restart your terminal and run `claude` from there.

---

## Adapting for your project

After forking, walk through `templates/CONTRIBUTING-FOR-FORKERS.md`. The short version:

1. **Fill in placeholders** in `CLAUDE.md` (project name, your name / institution)
2. **Update Stata version pin** in `dofiles/00_master.do` and `templates/master-do-template.do` if not 17
3. **Drop raw data** into `data/raw/` — confirm `git status` does not list it
4. **Document the data** in `data/README.md` (source, vintage, access restrictions)
5. **Customize the domain reviewer** (`.claude/agents/domain-reviewer.md`) for your sub-field
6. **Fill in the knowledge base** (`.claude/rules/knowledge-base-template.md`) with notation, estimands, datasets
7. **Set replication targets** in `templates/replication-targets.md` (if replicating a paper)
8. **Wire the data-safety hook** as a git pre-commit (one-line install — see Troubleshooting above)

Or just paste the [initialization prompt](#step-4--paste-the-initialization-prompt) and let Claude do most of these for you.

---

## What's included

<details>
<summary><strong>Click to expand inventory</strong></summary>

**Skills** (Stata-focused): `/run-stata`, `/run-pipeline`, `/build-tables`, `/validate-log`, `/replicate`, `/render-report`, `/check-reproducibility`, `/review-stata`, `/data-analysis`, plus generic skills (`/proofread`, `/validate-bib`, `/devils-advocate`, `/lit-review`, `/research-ideation`, `/interview-me`, `/review-paper`, `/pedagogy-review`, `/commit`).

**Agents:** `stata-reviewer`, `log-validator`, `econometric-reviewer`, `domain-reviewer`, `proofreader`, `pedagogy-reviewer`, `verifier`.

**Rules:** Stata-specific (`stata-coding-conventions`, `stata-reproducibility-protocol`, `data-protection`, `log-verification-protocol`, `econometric-best-practices`) + generic governance (`plan-first-workflow`, `orchestrator-protocol`, `session-logging`, `quality-gates`, `verification-protocol`, `replication-protocol`, `single-source-of-truth`, `meta-governance`, `proofreading-protocol`, `exploration-fast-track`, `exploration-folder-protocol`, `orchestrator-research`, `knowledge-base-template`).

**Hooks:** `protect-files.sh` (guards `00_master.do`, `references.bib`, `.gitignore`); `pre-compact.sh`, `post-merge.sh`, `notify.sh`, `log-reminder.py`.

**Scripts:** `run_stata.sh` / `.bat`, `run_pipeline.sh`, `check_data_safety.py`, `check_reproducibility.sh`, `quality_score.py`.

**Templates:** `master-do-template.do`, `replication-targets.md`, `data-dictionary.md`, `analysis-report.qmd`, plus governance templates (`requirements-spec`, `constitutional-governance`, `session-log`, `quality-report`, `exploration-readme`, `archive-readme`, `skill-template`, `CONTRIBUTING-FOR-FORKERS`).

</details>

---

## License

MIT License. Use freely for research, teaching, or any academic purpose.
