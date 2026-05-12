# Logs Directory

Plain-text logs from every R script run land here, named to mirror the script path.

> **Not committed:** `*.log` is in `.gitignore`. Only this README and `.gitkeep` reach GitHub. Logs may contain raw-data echo and so are treated as private.

## Naming convention

A script at `R/03_analysis/main_regression.R` writes its log to:

```
logs/03_analysis_main_regression.log
```

The wrapper `scripts/run_r.sh` derives the log path automatically; the helper `start_log("03_analysis_main_regression")` (from `R/_utils/logging.R`) writes the structured log header.

## Why logs matter

Every numerical result claimed in a report or commit message must trace to a log line. The `r-log-validator` agent enforces this before any commit. If a number does not appear in a log file, it does not get reported.

See `.claude/rules/log-verification-protocol.md`.
