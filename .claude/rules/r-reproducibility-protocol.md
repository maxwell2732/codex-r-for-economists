# R Reproducibility Protocol

**Bottom line:** anyone with this repo and the raw data must reproduce every committed table and figure with **one command**: `bash scripts/run_pipeline.sh`. No interactive editing, no manual ordering.

---

## The Single Entry Point

`R/00_main.R` is the only legitimate way to run the whole pipeline. It:

1. Sets project-wide options (`options(warn = 1, scipen = 999, stringsAsFactors = FALSE)`)
2. Sets the project-wide seed exactly once: `set.seed(20260428)`
3. Saves an environment snapshot to `logs/00_main.log` (R version, platform, OS, package versions, `renv.lock` presence)
4. Optionally restores `renv` if `INSTALL_DEPS = TRUE` (gated to avoid slowing down every run)
5. Sources each stage's R scripts in dependency order, stopping on first error
6. Exits with non-zero status if any stage fails

Sub-scripts MUST also be **independently runnable** from project root for debugging — never require `00_main.R` to have been executed first.

---

## Version Pinning

- Top of every script: `if (getRversion() < "4.3.0") stop(...)` (or your fork's pin)
- `renv.lock` records the exact version of every CRAN package the project loads. Created by `Rscript scripts/setup_r.R` and updated via `renv::snapshot()` whenever the dependency set changes.
- `R/00_main.R`'s environment snapshot prints the version of every required package; reviewers can diff snapshots across runs to detect drift.

If a forker updates R or any package, they should re-run `scripts/check_reproducibility.sh` and bump the validation comment in `R/00_main.R`.

---

## Randomness

- `set.seed(YYYYMMDD)` exactly **once** per script, near the top
- Never inside loops, functions, or simulations — R's RNG state is global; re-seeding mid-stream defeats reproducibility
- For Monte Carlo work, document the bootstrap reps and seed in the script header AND in the resulting log
- For parallelisation (`future`, `parallel`), use the `future.apply` "future-friendly" RNG (`future_lapply(..., future.seed = TRUE)`) — plain `mclapply()` does not yield reproducible streams

---

## Logging

Every script MUST open and close its own log:

```r
source("R/_utils/logging.R")
start_log("03_analysis_main_regression")
on.exit(stop_log(), add = TRUE)   # closes even if the script errors

# ... script body ...

stop_log()
```

`start_log()` writes plain-text logs (greppable for the `r-log-validator` agent) under `logs/<name>.log` and tees both stdout and `message()` output via `sink()`.

---

## Environment Snapshot

`R/00_main.R` writes the environment snapshot into `logs/00_main.log`:

```r
cat("R version:        ", R.version.string, "\n")
cat("Platform:         ", R.version$platform, "\n")
cat("OS:               ", Sys.info()[["sysname"]], Sys.info()[["release"]], "\n")
cat("Date:             ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")

for (pkg in REQUIRED_PKGS) {
  cat(sprintf("  %-15s %s\n", pkg, packageVersion(pkg)))
}
```

This log is the single artifact a reviewer needs to know whether your environment matches theirs.

---

## Reproducibility Test

`scripts/check_reproducibility.sh` simulates a fresh-clone reproduction:

1. Snapshot current `output/` tree
2. `git clean -dfx` in a tmp worktree (or copy of repo) — preserves `data/raw/`
3. Restore `data/raw/` from the user-configured location
4. `Rscript scripts/setup_r.R` — restores the lockfile if `renv.lock` is present
5. Run `bash scripts/run_pipeline.sh`
6. Diff new `output/` against the snapshot
7. Report drift as PASS / WARN (cosmetic) / FAIL (numerical)

Run before any release, paper submission, or major refactor merge.

---

## Anti-Patterns

| Anti-Pattern | Why It's Wrong |
|---|---|
| Manual editing of `data/derived/*.rds` | breaks the pipeline; intermediate files must be reproducible from raw |
| `setwd()` to absolute path inside a script | runs only on author's machine — forbidden by `r-coding-conventions` |
| Running ad-hoc `print(coef(m))` in console for "the result" | not in any log; not reproducible |
| Editing `output/tables/*.tex` by hand | next pipeline run wipes the edit; put adjustments in the script's `modelsummary()` options |
| Calling `R/00_main.R` from inside a sub-script | infinite recursion risk; obscures dependency direction |
| Loading a package via `library()` inside a function | hides the dependency from `renv::snapshot()`; load at the top |
| `rm(list = ls())` at the top of a script | erases other scripts' state when sourced — never |
