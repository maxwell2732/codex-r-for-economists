---
paths:
  - "R/**/*.R"
  - "explorations/**"
---

# Research Project Orchestrator (Simplified)

**For R scripts, simulations, and exploratory data analysis** — use this simplified loop instead of the full multi-agent orchestrator.

## The Simple Loop

```
Plan approved → orchestrator activates
  │
  Step 1: IMPLEMENT — Write/edit the R script
  │
  Step 2: VERIFY — Run the script via scripts/run_r.sh
  │         • Rscript exit code 0
  │         • Log file created and non-empty
  │         • No `Error in` / `Execution halted` in log (use /validate-r-log)
  │         • Expected output files exist with sensible size
  │         If verification fails → fix → re-verify (max 2 attempts)
  │
  Step 3: SCORE — Apply quality-gates rubric (python scripts/quality_score.py)
  │
  └── Score >= 80?
        YES → Done (commit when user signals)
        NO  → Fix blocking issues, re-verify, re-score
```

**No 5-round critic-fixer loops here. No multi-agent reviews. Just: write, run, validate log, done.**

For production scripts that ship results in a paper, escalate to the full `orchestrator-protocol` and run `econometric-reviewer` + `r-log-validator` + `r-reviewer`.

---

## Verification Checklist

- [ ] Script runs without errors (Rscript exit code 0)
- [ ] R version pin present (`if (getRversion() < ...) stop(...)`)
- [ ] All packages loaded at top via `library()` / `requireNamespace()`
- [ ] No hardcoded absolute paths; no `setwd()`
- [ ] `set.seed()` once at top if stochastic
- [ ] Log file produced and non-empty
- [ ] Output files created at expected paths
- [ ] Tolerance checks pass (if replication target exists)
- [ ] Quality score ≥ 80
