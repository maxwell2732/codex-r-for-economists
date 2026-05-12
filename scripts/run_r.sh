#!/usr/bin/env bash
#
# run_r.sh — Wrapper around `Rscript` for the R Research Pipeline.
#
# Usage:
#   bash scripts/run_r.sh <path/to/file.R> [<log/path.log>]
#
# Behavior:
#   * Runs from project root (whatever directory you invoke it from)
#   * Picks up Rscript from PATH
#   * Derives the log path from the script path if not given
#   * Captures Rscript's exit code and propagates it
#   * Prints log tail on failure so the error is visible
#
# Exit codes:
#   0  — success
#   1  — usage error
#   2  — Rscript not found on PATH
#   3  — script not found
#   N  — Rscript exit code on failure

set -euo pipefail

# --- 1. Argument parsing ------------------------------------------------------
if [ $# -lt 1 ]; then
  echo "usage: bash scripts/run_r.sh <path/to/file.R> [<log/path.log>]" >&2
  exit 1
fi

RFILE="$1"
LOG_PATH="${2:-}"

if [ ! -f "$RFILE" ]; then
  echo "error: R script not found: $RFILE" >&2
  exit 3
fi

# --- 2. Derive log path if not given -----------------------------------------
# R/03_analysis/main_regression.R -> logs/03_analysis_main_regression.log
if [ -z "$LOG_PATH" ]; then
  REL="${RFILE#R/}"                 # strip leading R/
  REL="${REL%.R}"                   # strip trailing .R
  REL="${REL%.r}"                   # also tolerate .r
  REL="${REL//\//_}"                # replace / with _
  LOG_PATH="logs/${REL}.log"
fi

mkdir -p "$(dirname "$LOG_PATH")"

# --- 3. Locate Rscript --------------------------------------------------------
if ! command -v Rscript >/dev/null 2>&1; then
  echo "error: Rscript not found on PATH" >&2
  echo "       install R or add its bin/ directory to PATH; see AGENTS.md prerequisites." >&2
  exit 2
fi

# --- 4. Run Rscript -----------------------------------------------------------
# We run from project root and let the script open its own log via start_log().
# We ALSO redirect Rscript's console output so that even scripts that forget
# start_log() still produce something to inspect.

R_EXTRA_LOG="${LOG_PATH%.log}_console.log"

echo "[run_r] Rscript:   $(command -v Rscript)"
echo "[run_r] script:    $RFILE"
echo "[run_r] log:       $LOG_PATH"
echo "[run_r] console:   $R_EXTRA_LOG"
echo "[run_r] starting:" "$(date '+%Y-%m-%d %H:%M:%S')"

set +e
Rscript --no-save --no-restore "$RFILE" >"$R_EXTRA_LOG" 2>&1
RC=$?
set -e

echo "[run_r] exit:      $RC"
echo "[run_r] finished:" "$(date '+%Y-%m-%d %H:%M:%S')"

# --- 5. On failure, tail the logs --------------------------------------------
if [ "$RC" -ne 0 ]; then
  echo "[run_r] --- last 30 lines of $LOG_PATH ---" >&2
  if [ -f "$LOG_PATH" ]; then
    tail -n 30 "$LOG_PATH" >&2
  else
    echo "[run_r] (start_log() log not produced; see $R_EXTRA_LOG)" >&2
    tail -n 30 "$R_EXTRA_LOG" >&2
  fi
fi

exit "$RC"
