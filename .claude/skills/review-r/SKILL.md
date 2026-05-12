---
name: review-r
description: Run a structured code-quality review on an R script. Delegates to the `r-reviewer` subagent; produces a report covering reproducibility, logging, naming, magic numbers, table/figure quality, and convention adherence.
disable-model-invocation: true
argument-hint: "[path/to/file.R]"
allowed-tools: ["Read", "Grep", "Glob", "Task"]
---

# Review an R Script

Delegate to the `r-reviewer` subagent for a thorough, opinionated review against `r-coding-conventions.md` and `quality-gates.md`.

## Steps

1. **Resolve the script path** from `$ARGUMENTS`. If absent, ask the user.

2. **Confirm the file exists** and is under `R/` or `explorations/`.

3. **Invoke the `r-reviewer` agent** with the script path. The agent:
   - Reads the script
   - Reads the most recent log if it exists at `logs/<derived-name>.log`
   - Walks its 10-category checklist (header, version pin, logging, paths, naming, estimation discipline, table/figure quality, magic numbers, comments, closing)
   - Writes its report to `quality_reports/<script>_r_review.md`
   - Does NOT modify the source file

4. **Surface the report to the user.** Print:
   - Verdict (READY / NEEDS REVISION / MAJOR REVISION)
   - Total issue count by severity
   - Top 3 blocking issues (Critical first)
   - Path to the full report

5. **(Optional) Run the static scorer** for an objective number:

   ```bash
   python scripts/quality_score.py R/<stage>/<file>.R
   ```

   Report the 0–100 score alongside the agent's qualitative review.

## Examples

- `/review-r R/03_analysis/main_regression.R`
  → Reviews the script; saves `quality_reports/main_regression_r_review.md`.

## Notes

- The agent never edits files. If the user wants fixes applied, they invoke `/run-r` or edit by hand after seeing the report.
- For econometric / specification review (clustering, IV strength, DiD assumptions), use the `econometric-reviewer` agent instead — it complements `r-reviewer`.
- For numerical-claim verification, use `/validate-r-log`.
