---
name: replicate
description: Apply the replication protocol to a paper. Inventory the replication package, record gold-standard targets with tolerances, translate the analysis into this project's R pipeline, and report a tolerance-by-tolerance comparison.
disable-model-invocation: true
argument-hint: "[paper short-name or target file]"
allowed-tools: ["Bash", "Read", "Edit", "Write", "Grep", "Glob", "Task"]
---

# Replicate a Paper's Results

Apply `.claude/rules/replication-protocol.md` end-to-end.

## When to Use

- Starting from a published paper whose results you want to extend or audit
- Validating a method on a known benchmark
- Onboarding a new analysis (replicate first, extend second)

## Phases

### Phase 1: Inventory & Targets

1. **Identify the paper** from `$ARGUMENTS` and locate any provided replication package (often in `master_supporting_docs/supporting_papers/`). Replication packages frequently ship as Stata `.do` files — that is fine; we will translate to R.

2. **Record gold-standard targets** in `quality_reports/<paper>_replication_targets.md` (use `templates/replication-targets.md`):

   - Each target: name, table/figure reference, value, SE/CI, MUST/SHOULD/MAY tier
   - Each target has an explicit tolerance (per `quality-gates.md` defaults, or override per project)

3. Get user approval on the target list.

### Phase 2: Translate

1. **Translate the original code line-by-line** into R under `R/03_analysis/<paper>_replication.R`. Do NOT "improve" during this phase — match the original specification exactly.

2. Apply `r-coding-conventions` for header, version pin, log, etc.

3. Use `replication-protocol`'s translation pitfall table (see § Stata ↔ R and § R ↔ R) to avoid silent divergences (e.g., `cluster()` df-adjust differences between Stata and `fixest`, or between `fixest::feols` and `lmtest::coeftest`).

### Phase 3: Execute & Compare

1. Run via `/run-r R/03_analysis/<paper>_replication.R`.

2. For each target, locate the corresponding number in the log (or in `output/tables/`) and compare to the gold standard via the `r-log-validator` agent + the tolerance from Phase 1.

3. **Build a comparison table** in `quality_reports/<paper>_replication_report.md`:

   ```markdown
   | Target | Paper | Ours | Diff | Within tolerance? | Status |
   |--------|-------|------|------|-------------------|--------|
   | ATT (Tab 2 col 3) | -1.632 | -1.6321 | 0.0001 | yes | PASS |
   | First-stage F | 28.4 | 27.9 | 0.5 | yes | PASS |
   | Sample N | 12,453 | 12,420 | 33 | NO | INVESTIGATE |
   ```

### Phase 4: Investigate Discrepancies (if any)

For any FAIL or INVESTIGATE row:

1. Walk the funnel: sample restrictions, missing-value handling, variable construction
2. Check SE method: cluster level, df adjustment, weights
3. Check command defaults: many R commands have changed defaults across major versions; some (e.g., `feols` SE method, `lm` HC variant) differ from their Stata equivalents
4. Document the investigation IN THE REPORT even if unresolved — never suppress

### Phase 5: Conclude

- **All MUST targets PASS** → mark replication SUCCESSFUL; commit as `Replicate <Paper>: all MUST targets within tolerance`
- **Some MUST targets FAIL** → mark PARTIAL; commit but flag in report; do NOT proceed to extensions until resolved
- **Most MUST targets FAIL** → mark FAILED; investigate before any further work

## Examples

- `/replicate AbadieDiamondHainmueller2010`
  → Inventories targets from the paper, translates from Stata to R, compares.

- `/replicate quality_reports/CallawaySantanna2021_replication_targets.md`
  → Resumes from an already-recorded target list.

## Troubleshooting

- **Original code is in Stata** — translate per `replication-protocol`'s § Stata ↔ R table. The most common silent traps:
  - `xtreg ... fe` vs `feols(... | unit)` — different small-sample df adjustment
  - `reghdfe ..., cluster(id)` vs `feols(..., cluster = ~ id)` — `feols` defaults to `t(n-1)/(n-k)` correction; Stata uses `(n-1)/(n-k) * G/(G-1)`
  - `probit` vs `glm(family = binomial(link = "probit"))` — match link explicitly
  - `bootstrap, reps(999)` vs `boot::boot()` — match seed, reps, AND bootstrap type (pairs vs wild)
- **Original code is in Matlab/Python** — translate carefully; HC variants differ between `linearmodels` (HC0 default) and `sandwich` (HC3 default for `vcovHC`)
- **Original SEs differ by ~3-5%** — likely a cluster df-adjust difference between the source language's command and `fixest`. Try `feols(..., cluster = ~ id, ssc = ssc(adj = TRUE, cluster.adj = TRUE))` to mimic Stata's adjustment exactly.
- **Sample N off by ~1-3%** — almost always a missing-value or join-handling difference. Walk the funnel.

## Notes

- Replication is binary in spirit (it works or it doesn't), but tolerance-respecting in practice (display rounding, SE simulation noise).
- Never round-and-claim. If the paper reports `−1.632` and you get `−1.521`, you have NOT replicated, even if both are negative and "look similar."
- The `r-log-validator` agent enforces this strictly.
