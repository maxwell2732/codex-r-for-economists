# Archive Note: educwages_tutorial (legacy Stata)

**Archived on:** 2026-05-12
**Reason:** Repository converted from Stata to R; this tutorial was written
in Stata and predates the conversion.

## What this was

An end-to-end Stata tutorial covering OLS, ANOVA, and IV estimation on a
synthetic education/wages dataset. See `dofiles/01_tutorial.do` for the
original content.

## Why it was archived rather than converted

- The hsb2_teaching_demo (a smaller, self-contained example) is the
  canonical worked example for the R template.
- The educwages tutorial is substantial (~300 lines of Stata teaching code
  plus ANOVA-specific commentary) and a faithful R port would require
  decisions about `stats::aov` vs `car::Anova`, IV via `AER::ivreg` vs
  `fixest::feols(... | endog ~ z, ...)`, etc. — better done deliberately
  than batched into a conversion.

## If you want to port it

1. Copy `dofiles/01_tutorial.do` into a new `explorations/educwages_tutorial/R/01_tutorial.R`.
2. Translate Stata commands per `.claude/rules/replication-protocol.md` § Stata → R.
3. Follow `r-coding-conventions` (header, log open/close, `set.seed`, etc.).
4. Re-run from a clean clone; verify the OLS / ANOVA / IV results match.
