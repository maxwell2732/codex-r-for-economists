---
paths:
  - "R/**"
  - "output/**"
  - "reports/**/*.qmd"
---

# Single Source of Truth: Enforcement Protocol

**`R/00_main.R` is the authoritative source for every analytical artifact in the repo.** Tables, figures, and reports are derived. NEVER edit a derived artifact directly.

---

## The SSOT Chain

```
data/raw/                            (immutable inputs — never edited)
   ↓
R/01_clean/*.R                       → data/derived/clean_*.rds
   ↓
R/02_construct/*.R                   → data/derived/sample_*.rds
   ↓
R/03_analysis/*.R                    → output/tables/*.{tex,csv}
                                        output/figures/*.{pdf,png}
   ↓
R/04_output/*.R                      (assembly / extra polishing if needed)
   ↓
reports/*.qmd                        (read_csv from output/, never re-runs analysis)
   ↓
docs/*.html (rendered)
```

`R/00_main.R` calls each stage in this order via `source()`.

---

## Hard Rules

1. **Never hand-edit `output/tables/*.tex` or `*.csv`.** The next pipeline run wipes the change. Adjustments go in the script's `modelsummary()` options or in an `R/04_output/` polish script.
2. **Never hand-edit `output/figures/`.** Same reason. Adjust the `ggplot()` and `ggsave()` calls in the source script.
3. **Never hand-edit `data/derived/`.** Reproducible from `01_clean` + `02_construct`; manual edits leave the project unreproducible.
4. **Reports include from `output/`, not from `data/derived/`.** The report's job is narrative, not analysis. If you find yourself running a regression inside a `{r}` chunk, refactor it into `R/03_analysis/`.
5. **Tables and figures referenced in a report must exist in `output/`.** The `verifier` agent enforces this.

---

## Freshness Check (MANDATORY before report render)

Before `quarto render reports/<file>.qmd`:

1. For every `output/tables/X.{tex,csv}` and `output/figures/X.{pdf,png}` referenced in the report:
2. Find the script that produces it (grep `output/tables/X` in `R/`)
3. Compare timestamps: if the script's mtime is newer than the output's mtime, the output is **stale**
4. Stale output → re-run the producing script before rendering

The `/render-report` skill performs this check automatically.

---

## When SSOT Can Bend (Documented Exceptions)

Two narrow cases:

- **Manual figure annotations** that R can't produce cleanly (e.g., a hand-drawn callout). In this case: produce the base figure via R to `output/figures/_base/`, post-process to `output/figures/`, and document the post-processing step in the producing script's header.
- **External tables** (e.g., one cell from another paper). Place in `output/tables/external/` and cite the source in the cell's CSV header.

Both exceptions require documentation. Otherwise, no edits to derived artifacts.

---

## Content-Fidelity Checklist (Before any commit touching reports)

```
[ ] Every table in the report exists in output/tables/
[ ] Every figure in the report exists in output/figures/
[ ] No inline regressions / data computations in .qmd {r} chunks
[ ] All output files are newer than the scripts that produced them
[ ] Every numerical claim cites a logs/ line
[ ] References.bib has every cited key
```
