---
paths:
  - "R/**/*.R"
  - "reports/**/*.qmd"
  - "output/**"
  - "docs/**"
---

# Task Completion Verification Protocol

**At the end of EVERY task, Claude MUST verify the output works correctly.** This is non-negotiable.

---

## For R scripts

1. Run via the wrapper: `bash scripts/run_r.sh R/<stage>/<file>.R`
2. Confirm exit code is 0 (the wrapper exposes Rscript's status)
3. Confirm `logs/<stage>_<file>.log` exists and is non-empty (the wrapper also writes a `_console.log` even if the script forgot `start_log()`)
4. Scan the log tail for error indicators:
   ```bash
   grep -nE "Error in|Execution halted|cannot open|object '.+' not found|could not find function" logs/<stage>_<file>.log
   ```
   …or delegate to the `/validate-r-log` skill.
5. Confirm expected output files exist with non-trivial size:
   - `output/tables/<expected>.tex` and `.csv`
   - `output/figures/<expected>.pdf` and `.png`
6. Spot-check estimates for plausible magnitude and sign
7. If the task adds or changes a numerical claim in any committed document, run the `r-log-validator` agent
8. Report the verification results to the user with paths

## For Quarto Reports (`reports/*.qmd`)

1. Run `quarto render reports/<file>.qmd` (or via `/render-report`)
2. Confirm the rendered HTML/PDF in `docs/` (or report-local `_files/`) has been updated
3. Open / inspect the rendered output for missing figures (broken paths)
4. Confirm every numerical claim in the rendered output traces to a log line
5. Verify no inline analysis: report should `read_csv()` from `output/tables/` or `knitr::include_graphics()` from `output/figures/`, never re-run regressions inside `{r}` chunks

## For Pipeline Runs (`bash scripts/run_pipeline.sh`)

1. Confirm exit code 0
2. Stage-by-stage timings printed
3. `logs/00_main.log` exists with the environment snapshot (R version, package versions, OS)
4. Final `output/` tree contains the expected artifacts (compare to a manifest if one exists)

## Common Pitfalls

- **Assuming silent success:** always check the wrapper's exit code; `tryCatch()` can swallow an error and let the script exit 0. The `validate-r-log` skill catches this.
- **Stale outputs:** if `output/tables/foo.tex` is older than `R/03_analysis/foo.R`, the table is stale → re-run.
- **Missing logs:** if a script ran without `start_log()`, the wrapper still writes a `_console.log` — but the script is in violation of `r-coding-conventions`; treat as failure.
- **Quarto render in offline mode:** check that `quarto check` reports R as OK; skip cleanly if not, with a documented message.

## Verification Checklist

```
[ ] R script exit code is 0
[ ] Log file created and non-empty
[ ] No `Error in` / `Execution halted` in log
[ ] All expected output files exist (tables + figures)
[ ] Output files newer than the script
[ ] Numerical claims (if any) cited to log lines
[ ] r-log-validator agreed (if numerical claims in commit/report)
[ ] Quarto report rendered successfully (if applicable)
[ ] Reported verification results to user with file paths
```
