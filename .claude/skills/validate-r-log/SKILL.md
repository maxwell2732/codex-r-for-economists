---
name: validate-r-log
description: Scan an R log file for errors, warnings, and silent failures, and (optionally) verify that a numerical claim appears in the log. Mode A scans; Mode B verifies a specific claim.
disable-model-invocation: true
argument-hint: "[logs/<name>.log] [optional: <claim>]"
allowed-tools: ["Bash", "Read", "Grep", "Glob", "Task"]
---

# Validate an R Log

Two modes:

**Mode A — Log scan.** Argument is a log file. Output: pass/fail with a list of error indicators and a brief summary.

**Mode B — Claim verification.** Arguments are a log file AND a numerical claim. Output: VERIFIED / MISMATCH / UNVERIFIED. Delegates to the `r-log-validator` agent.

## Mode A: Scan

For the given log, grep these patterns and report each match with line number:

```bash
LOG=$1
grep -nE "Error in|Execution halted|cannot open the connection|object '.+' not found|could not find function|subscript out of bounds|undefined columns selected|argument is of length zero|missing value where TRUE/FALSE needed|non-numeric argument|^Warning messages?:" "$LOG"
```

Severity classification:

| Pattern | Severity | What it means |
|---|---|---|
| `Execution halted` | CRITICAL | Script aborted; no further output trustworthy |
| `Error in <fn>(...)` | CRITICAL | An expression failed; if not inside `tryCatch`, halts the script |
| `cannot open the connection` / `cannot open file` | CRITICAL | I/O failure (missing input or unwritable output) |
| `object '<x>' not found` | CRITICAL | Typo or missing assignment |
| `could not find function` | CRITICAL | Missing `library()` call or package not installed |
| `Warning messages?:` (NA coercion, etc.) | WARN | Often benign, but inspect — silent NA introduction is a common bug |
| `Loading required package: <X> failed` | CRITICAL | Dependency missing |

Also check:

- **Did the script actually finish?** Look for the closing `=== Log closed ===` banner from `stop_log()`. Absence implies the script aborted before normal exit.
- **Length sanity:** a log under ~10 lines for a script that should do real work indicates early abort.

Report: PASS (no errors) / WARN (only warnings) / FAIL (any critical).

## Mode B: Claim verification

If `$ARGUMENTS` includes a numerical claim, delegate to the `r-log-validator` agent. Its protocol:

1. Read the log file
2. Search for the claimed value within plausible neighborhoods (e.g., `feols`/`lm` output blocks, `modelsummary` printout)
3. Compare to the claim within tolerance (per `quality-gates.md`)
4. Return `VERIFIED — found at <log>:<line>` or `UNVERIFIED — <reason>`

A `VERIFIED` is required before any commit message containing the claim.

## Examples

- `/validate-r-log logs/03_analysis_main_regression.log`
  → Mode A scan; reports any errors / warnings.

- `/validate-r-log logs/03_analysis_main_regression.log "ATT = -1.632 (SE 0.584)"`
  → Mode B; delegates to `r-log-validator`; returns VERIFIED / UNVERIFIED.

## Troubleshooting

- **"log not found"** — the producing script never ran or `start_log()` is missing. Run via `/run-r`.
- **Many warnings about NA coercion** — usually a `as.numeric()` on a string column with non-numeric entries. Re-inspect the cleaning step.
- **`Error in library(X) : there is no package called 'X'`** — `Rscript scripts/setup_r.R` to install/restore.
- **No closing "Log closed" banner** — script aborted; look for `Execution halted` or the last `Error in` and start debugging from there.

## Notes

- The R wrapper writes two logs per script: `logs/<name>.log` (the `start_log()` capture) and `logs/<name>_console.log` (raw `Rscript` stdout+stderr). Mode A should scan whichever exists; if the script forgot `start_log()`, only the console log is present.
- Per `log-verification-protocol`, EVERY numerical claim in a report or commit message must pass Mode B. No log line, no claim.
