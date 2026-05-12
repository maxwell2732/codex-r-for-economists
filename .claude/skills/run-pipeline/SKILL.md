---
name: run-pipeline
description: Execute the full R pipeline via R/00_main.R. Runs every stage in dependency order, aborts on first error, prints stage timings, and reports the final output tree.
disable-model-invocation: true
argument-hint: ""
allowed-tools: ["Bash", "Read", "Grep", "Glob"]
---

# Run the Full Pipeline

Execute `R/00_main.R` end-to-end via `scripts/run_pipeline.sh`. This is the canonical "rebuild everything" command.

## Steps

1. **Pre-flight checks:**
   - Confirm `R/00_main.R` exists
   - Confirm `data/raw/` is non-empty (otherwise the cleaning stage will fail with no inputs)
   - Confirm `Rscript` is on PATH (`command -v Rscript`)
   - Confirm `renv.lock` exists; if not, run `Rscript scripts/setup_r.R` first

2. **Run the pipeline:**

   ```bash
   bash scripts/run_pipeline.sh
   ```

   The wrapper:
   - Records start time
   - Runs `R/00_main.R` via `Rscript --no-save --no-restore`
   - The orchestrator prints stage banners and elapsed seconds for each stage
   - Aborts on first non-zero exit code
   - Prints total wall time at the end

3. **Inspect the environment snapshot:** `logs/00_main.log` should contain R version, platform, OS, and `packageVersion()` for each required package.

4. **Validate stage logs:**
   For each `logs/<stage>_*.log` produced, grep for errors:

   ```bash
   for L in logs/*.log; do
     N=$(grep -cE "Error in|Execution halted|cannot open|object '.+' not found" "$L")
     [ "$N" -gt 0 ] && echo "$L: $N error matches"
   done
   ```

5. **Verify expected outputs:**
   - `output/tables/` and `output/figures/` populated
   - Spot-check that key tables/figures referenced in `reports/*.qmd` exist and are newer than the producing scripts (freshness check from `single-source-of-truth`)

6. **Report:**
   - Total runtime
   - Per-stage timings (from the orchestrator output)
   - Logs produced + any errors
   - Output files created
   - Next step (re-run a single stage, render report, commit)

## Examples

- `/run-pipeline`
  → Builds the entire pipeline; reports timing + outputs.

- After data refresh: `/run-pipeline` then `/render-report reports/analysis_report.qmd`.

## Troubleshooting

- **Pipeline aborts at stage 02_construct** — check the log of the LAST script in stage 01_clean; merge errors are common when raw data shape changes.
- **`there is no package called 'X'`** — run `Rscript scripts/setup_r.R` once to install the stack and snapshot `renv.lock`.
- **Rscript not found** — see `/run-r` troubleshooting; install R or add its `bin/` directory to PATH.
- **Permission denied** — `chmod +x scripts/run_pipeline.sh scripts/run_r.sh`.
- **renv reports library out of sync** — `Rscript -e "renv::restore()"` to bring the local library back to the lockfile state.

## Notes

- This skill is destructive: it overwrites everything in `output/`. Commit any in-progress work before running.
- Long-running: for typical empirical work, expect minutes to tens of minutes. The wrapper does not background — run it and wait.
- For partial re-runs (one stage), use `/run-r` instead.
