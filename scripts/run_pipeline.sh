#!/usr/bin/env bash
#
# run_pipeline.sh — Execute the full R pipeline via R/00_main.R.
#
# Usage:
#   bash scripts/run_pipeline.sh
#
# Behavior:
#   * Runs from project root
#   * Calls scripts/run_r.sh on R/00_main.R
#   * Prints total wall time at the end
#   * Aborts on first non-zero exit
#
# Exit codes:
#   0 — pipeline succeeded
#   N — exit code from the failing stage (propagated from run_r.sh)

set -euo pipefail

MAIN="R/00_main.R"

if [ ! -f "$MAIN" ]; then
  echo "error: $MAIN not found." >&2
  echo "       The pipeline orchestrator is missing. See templates/main-r-template.R." >&2
  exit 3
fi

START_EPOCH=$(date +%s)
echo "============================================================"
echo "  R Research Pipeline"
echo "  Main:     $MAIN"
echo "  Started:  $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"

set +e
bash scripts/run_r.sh "$MAIN"
RC=$?
set -e

END_EPOCH=$(date +%s)
ELAPSED=$((END_EPOCH - START_EPOCH))

echo "============================================================"
echo "  Pipeline finished"
echo "  Exit code: $RC"
echo "  Elapsed:   ${ELAPSED}s"
echo "  Logs:      logs/"
echo "============================================================"

if [ "$RC" -ne 0 ]; then
  echo ""
  echo "Pipeline FAILED. Inspect logs/ for the first failing stage." >&2
  echo "  $ ls -lt logs/*.log | head -5" >&2
fi

exit "$RC"
