# Workflow Quick Reference — R Pipeline

**Model:** Contractor (you direct, Claude orchestrates)

---

## The Loop

```
Your instruction
    ↓
[PLAN] (if multi-file or unclear) → Show plan → Your approval
    ↓
[EXECUTE] Implement, run R script, validate log, done
    ↓
[REPORT] Summary + log path + output files + quality score
    ↓
Repeat
```

---

## I Ask You When

- **Identification choice:** "DiD with two-way FE vs. Callaway-Sant'Anna — which?"
- **Sample restriction:** "Drop singletons in FE absorption? Adopters only?"
- **Cluster level ambiguity:** "Cluster at firm vs. industry × year?"
- **Replication edge case:** "Just outside tolerance — investigate or document?"
- **Data acquisition:** "Raw data not in `data/raw/` — do I download or wait?"

---

## I Just Execute When

- R syntax fix is obvious (typo, missing `library()`, wrong pipe operator)
- Verification (log scan, output file existence, tolerance comparison)
- Documentation (session logs, commit messages, replication report rows)
- Table assembly (`modelsummary`) per established standards
- Figure export (`ggsave`) per established theme

---

## Quality Gates (No Exceptions)

| Score | Action |
|-------|--------|
| ≥ 80  | Ready to commit |
| < 80  | Fix blocking issues first |

---

## Non-Negotiables

- `if (getRversion() < "4.3.0") stop(...)` at the top of every R script
- `set.seed(YYYYMMDD)` once at top if any randomness
- `start_log("<name>")` / `stop_log()` per script
- Relative paths only — never `setwd("C:/...")` or `setwd("/home/...")`; use `here::here()` / `proj_path()`
- Cluster SEs at the most aggregate plausible level by default
- Nothing under `data/raw/` or `data/derived/` is ever committed
- Every claimed numerical result must trace to a log line — refuse to commit otherwise
- Tables exported via `modelsummary()` to both `.tex` (paper) and `.csv` (audit)
- Figures exported via `ggsave()` to `.pdf` (paper) and `.png` (web)

---

## Preferences

**Visual:** publication-grade, colorblind-friendly palette, 300 DPI for raster, `theme_minimal()` or project-defined theme
**Reporting:** terse bullets unless asked for narrative; always cite the log path for any number stated
**Session logs:** always (post-plan, incremental, end-of-session)
**Replication:** strict — flag any near-miss; never round-and-claim

---

## Exploration Mode

For experimental analyses, use the **Fast-Track** workflow:

- Work in `explorations/[name]/` folder
- 60/100 quality threshold (vs. 80/100 for production)
- No plan needed — just a 2-min research-value check
- See `.claude/rules/exploration-fast-track.md`

---

## Next Step

You provide task → I plan (if needed) → Your approval → Execute → Report.
