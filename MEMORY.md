# Project Memory

Corrections and learned facts that persist across sessions.
When a mistake is corrected, append a `[LEARN:category]` entry below.

---

<!-- Append new entries below. Most recent at bottom. -->

## Workflow Patterns

[LEARN:workflow] Requirements specification phase catches ambiguity before planning → reduces rework 30-50%. Use spec-then-plan for complex/ambiguous tasks (>1 hour or >3 files).

[LEARN:workflow] Spec-then-plan protocol: AskUserQuestion (3-5 questions) → create `quality_reports/specs/YYYY-MM-DD_description.md` with MUST/SHOULD/MAY requirements → declare clarity status (CLEAR/ASSUMED/BLOCKED) → get approval → then draft plan.

[LEARN:workflow] Context survival before compression: (1) Update MEMORY.md with [LEARN] entries, (2) Ensure session log current (last 10 min), (3) Active plan saved to disk, (4) Open questions documented. The pre-compact hook displays checklist.

[LEARN:workflow] Plans, specs, and session logs must live on disk (not just in conversation) to survive compression and session boundaries. Quality reports only at merge time.

## Documentation Standards

[LEARN:documentation] When adding new features, update README and any user-facing docs immediately to prevent documentation drift. Stale docs break user trust.

[LEARN:documentation] Always document new templates in README's "What's Included" section with purpose description. Template inventory must be complete and accurate.

[LEARN:documentation] Date fields in frontmatter and README must reflect latest significant changes. Users check dates to assess currency.

## Design Philosophy

[LEARN:design] Framework-oriented > Prescriptive rules. Constitutional governance works as a TEMPLATE with examples users customize to their domain. Same for requirements specs.

[LEARN:design] Forkable templates serve a SPECIFIC primary workflow (here: R empirical economics) but keep the underlying governance generic so the lessons transfer. Be opinionated about the workflow, generic about the meta-rules.

## File Organization

[LEARN:files] Specifications go in `quality_reports/specs/YYYY-MM-DD_description.md`, not scattered in root or other directories.

[LEARN:files] Templates belong in `templates/` directory with descriptive names. The R pipeline ships with: session-log.md, quality-report.md, exploration-readme.md, archive-readme.md, requirements-spec.md, constitutional-governance.md, skill-template.md, main-r-template.R, analysis-r-template.R, replication-targets.md, data-dictionary.md, analysis-report.qmd, CONTRIBUTING-FOR-FORKERS.md.

## Constitutional Governance

[LEARN:governance] Constitutional articles distinguish immutable principles (non-negotiable for quality/reproducibility) from flexible user preferences. Keep to 3-7 articles max.

[LEARN:governance] Example articles: Primary Artifact (which file is authoritative — for this template, `R/00_main.R`), Plan-First Threshold (when to plan), Quality Gate (minimum score), Verification Standard (what must pass), File Organization (where files live).

[LEARN:governance] Amendment process: Ask user if deviating from article is "amending Article X (permanent)" or "overriding for this task (one-time exception)". Preserves institutional memory.

## Skill Creation

[LEARN:skills] Effective skill descriptions use trigger phrases users actually say: "run my regression", "build a publication table", "validate this log" → Claude knows when to load skill.

[LEARN:skills] Skills need 3 sections minimum: Instructions (step-by-step), Examples (concrete scenarios), Troubleshooting (common errors) → users can debug independently.

[LEARN:skills] Domain-specific examples beat generic ones: regression formatter (econ), event-study figure builder (causal inference), replication-target tracker (audit) → shows adaptability.

## Memory System

[LEARN:memory] Two-tier memory solves template vs working project tension: MEMORY.md (generic patterns, committed), personal-memory.md (machine-specific, gitignored) → cross-machine sync + local privacy.

[LEARN:memory] Post-merge hooks prompt reflection, don't auto-append → user maintains control while building habit.

## Meta-Governance

[LEARN:meta] Repository dual nature requires explicit governance: what's generic (commit) vs specific (gitignore) → prevents template pollution.

[LEARN:meta] Dogfooding principles must be enforced: plan-first, spec-then-plan, quality gates, session logs → we follow our own rules.

[LEARN:meta] Template development work (building infrastructure, docs) doesn't create session logs in `quality_reports/` → those are for user research work (analysis, replication), not meta-work. Keeps the template clean for forkers.

## R Pipeline (this template's domain)

[LEARN:r-stack] Default stack: `tidyverse` + `haven` + `fixest` + `modelsummary` + `kableExtra` + `ggplot2` + `here` + `fs` + `glue` + `log4r`. `feols` is the `reghdfe` analogue (HDFE + clustered SEs); `modelsummary` is the `esttab` analogue. Pin versions via `renv.lock` (created by `Rscript scripts/setup_r.R`). When migrating from a Stata replication package, the most common silent trap is the cluster-SE df-adjustment (`feols` defaults differ from Stata's; pass `ssc = ssc(adj = TRUE, cluster.adj = TRUE)` to match exactly).

[LEARN:r] No result without a log. Every numerical claim Claude makes about an analysis MUST trace to a `logs/*.log` line or `output/tables/*.csv` cell. The `r-log-validator` agent enforces this; refusal to verify is the correct response when no log exists. See `.claude/rules/log-verification-protocol.md`.

[LEARN:r] `R/00_main.R` is the SINGLE entry point for end-to-end reproduction. Reports include from `output/`, never re-run analysis. See `.claude/rules/single-source-of-truth.md`.

[LEARN:r] R version pin (`if (getRversion() < "4.3.0") stop(...)`) goes at the top of every script. `renv.lock` pins package versions; `Rscript scripts/setup_r.R` creates/refreshes it. The stack is listed in `.claude/rules/r-coding-conventions.md` § 9.

## R API gotchas (recurring time-sinks, learned in May 2026)

[LEARN:r-api] `Rscript` is NOT on PATH by default on Chen's Windows machine. R 4.5.0 lives at `C:\Program Files\R\R-4.5.0\bin\`. For every shell session: `export PATH="/c/Program Files/R/R-4.5.0/bin:$PATH"`. R 4.3.1 and 4.4.1 are also installed but unused — always use 4.5.0.

[LEARN:r-api] `.Rprofile` must guard the `source("renv/activate.R")` line with `if (file.exists("renv/activate.R"))`. On a fresh clone, `renv/activate.R` doesn't exist until `setup_r.R` has been run, and the unconditional source crashes every R session — including the one that's supposed to run setup_r.R. The fix is in the committed `.Rprofile`.

[LEARN:r-api] `summary(ddml::ddml_plm(...))` is a 3-D array indexed as `[coef × stat × ensemble]`, not a 2-D matrix. Correct: `s["D_r", "Estimate", 1]`. Wrong: `s["D_r", "Estimate", drop = TRUE]` (crashes).

[LEARN:r-api] ddml stores stacking weights in `fit$weights$D1_X` (not `D_X`) when there's one treatment column. Shape is `[learner × ensemble × sample_fold]`; average over the third dim for a per-(learner, nuisance) bar plot.

[LEARN:r-api] modelsummary has no `tidy.ddml_plm` method, so DDML LaTeX tables must be built by hand from a tidy data frame, not via `modelsummary(list("DDML" = fit))`.

[LEARN:r-api] `summary(m_sa, agg = "ATT")` (fixest sunab) collapses to a single pooled-ATT row. Plain `summary(m_sa)` already returns per-event-time aggregated effects labelled `period::-2`, `period::0`, etc. Use plain summary for event-study extraction.

[LEARN:r-api] `did2s::did2s` event-study output has one coefficient per event time. `coef(fit)[1]` is the EARLIEST lead (e.g., `e=-2`), NOT a pooled ATT. For pooled, fit a separate `did2s` call with `second_stage = ~ treat`.

[LEARN:r-api] `survival::lung$status` is coded `1 = censored, 2 = dead` — non-canonical. Always recode: `event = as.integer(status == 2)` before `Surv()`. Forgetting this flips every HR.

[LEARN:r-api] `ggsave(plot = print(p_km))` saves a blank file: `print()` on a `ggsurvplot` draws to the active device and returns NULL. Compose via patchwork: `(p_km$plot / p_km$table) + plot_layout(heights = c(4, 1))`, then `ggsave(plot = that_object)`.

[LEARN:r-api] `survminer::ggcoxzph` defaults to red Schoenfeld residual points. Override with `point.col = pal_journal[["navy"]]` to match the project palette.

[LEARN:r-api] xgboost renamed `eta` → `learning_rate` and dropped `verbose`. When configuring `mdl_xgboost` args in ddml, use the new names or you'll get deprecation warnings on every fold.

[LEARN:r-api] In ggplot2, `annotate("text", x = ..., y = 0.6, ...)` crashes when the y axis is discrete (factor levels). Use `geom_text(data = df, aes(y = level_name, ...))` anchored to a factor level instead.

[LEARN:r-api] `theme(axis.title = element_blank())` does NOT override a previously-applied `theme(axis.title.x = element_text(...))` because of theme-element inheritance. Always set both: `axis.title = element_blank()` AND `axis.title.x = element_blank()` AND `axis.title.y = element_blank()`.

[LEARN:r-api] `fwildclusterboot` requires a Rust toolchain to compile from source. If `setup_r.R` can't install it, the user is missing `cargo`. The package is optional; skip if no Rust.

[LEARN:r-api] `parse = TRUE` annotations in ggplot need plotmath-quoted text. Literal text must be in quotes and joined with `*` (no-space) or `~` (gap): `'bold("Union = Yes:  ")*italic(R)^2 == 0.873'`. A bare `"Union = Yes: italic(R)^2 == 0.873"` is interpreted as malformed R code.

## Data Protection (this template's bedrock)

[LEARN:data] Raw data NEVER commits. `data/raw/` and `data/derived/` are blanket-gitignored; the `scripts/check_data_safety.py` pre-commit script enforces it. Forkers wire it into `.git/hooks/pre-commit` per the README. Whitelist exceptions exist for `output/tables/` and `templates/examples/` only.

[LEARN:data] If a leak happens, treat it like a credential leak: stop pushing, scrub history with `git filter-repo` (NOT `git rm`), force-push (with explicit user authorization), and document in `quality_reports/incidents/`. See `.claude/rules/data-protection.md`.
