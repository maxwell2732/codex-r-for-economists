---
name: run-r
description: Execute a single R script in batch mode via the project wrapper. Captures the log, surfaces any errors, and reports exit code and output paths.
disable-model-invocation: true
argument-hint: "[path/to/file.R]"
allowed-tools: ["Bash", "Read", "Grep", "Glob"]
---

# Run an R script

Execute one R script end-to-end via `scripts/run_r.sh` (POSIX) or `scripts/run_r.bat` (Windows). The wrapper sets the working directory to the project root, invokes `Rscript --no-save --no-restore`, derives the log path automatically, and propagates the exit code.

## Steps

1. **Resolve the script path** from `$ARGUMENTS`:
   - If a full path: use it
   - If just a filename: search `R/**/<name>.R`
   - If no argument: ask the user which script to run

2. **Pre-run checks:**
   - Confirm the file exists
   - Read its header `Inputs:` block — confirm each input file exists
   - Confirm the script opens its own log (grep for `start_log(`, `sink(`, or `log4r::`)

3. **Run the wrapper:**

   ```bash
   bash scripts/run_r.sh R/<stage>/<file>.R
   ```

   Capture both the wrapper's exit code and the path of the produced log.

4. **Validate the log** by delegating to `/validate-r-log` (or running the inline `grep` from the rule):

   ```bash
   grep -E "Error in|Execution halted|Warning message:|cannot open|object .* not found" logs/<stage>_<file>.log
   ```

5. **Verify outputs** referenced in the script's `Outputs:` header block:

   ```bash
   ls -la output/tables/<expected>* output/figures/<expected>*
   ```

6. **Report to user:**

   - Exit code
   - Log path + size
   - Any errors found in log
   - Output files created (with mtimes)
   - Next-step suggestion (e.g., "ready to commit" or "fix log errors first")

## Examples

- `/run-r R/03_analysis/main_regression.R`
  → Runs main_regression.R; reports `logs/03_analysis_main_regression.log` and `output/tables/main_regression.{tex,csv}` produced.

- `/run-r main_regression`
  → Searches `R/**/main_regression.R`; runs the unique match.

- `/run-r` (no argument)
  → Asks user which script.

## Troubleshooting

- **"Rscript: command not found"** — install R or add its `bin/` directory to PATH. On Windows: typically `C:\Program Files\R\R-4.x.x\bin\`.
- **Wrapper exits 0 but log shows errors** — `Rscript` returns the script's last expression status. A `tryCatch()` that swallows an error will exit 0. Always run step 4 — the `validate-r-log` skill catches this.
- **Log file not created** — the script is missing `start_log()`. Add it per `r-coding-conventions.md`; meanwhile, the wrapper's `_console.log` still captures stdout/stderr.
- **"there is no package called 'X'"** — run `Rscript scripts/setup_r.R` to install the stack and snapshot `renv.lock`.
- **Permission denied** — `chmod +x scripts/run_r.sh`.

## Notes

- This skill never runs `R/00_main.R` — use `/run-pipeline` for that.
- Always run from project root; the wrapper enforces this.
- The wrapper writes both `logs/<name>.log` (from `start_log()`) and `logs/<name>_console.log` (raw Rscript stdout+stderr) so you have provenance even if the script forgets to open a log.
