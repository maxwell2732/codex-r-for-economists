---
name: render-report
description: Render a Quarto report (knitr / R engine) to HTML / PDF / DOCX. Performs freshness check on included tables/figures, verifies that Quarto + R are available, and validates numerical claims before rendering.
disable-model-invocation: true
argument-hint: "[reports/file.qmd]"
allowed-tools: ["Bash", "Read", "Grep", "Glob", "Task"]
---

# Render a Quarto Report

Render a `.qmd` report that uses the `knitr` (R) engine. Pre-flight checks ensure the report is **complete**, **fresh**, and **honest** (no unverified numerical claims).

## When to Use

- After completing an analysis, to assemble the writeup
- Before sharing with coauthors / advisors
- Before a paper-submission deadline

## Steps

### 1. Resolve the file

From `$ARGUMENTS` find the `.qmd`. If just a basename, search `reports/`. If empty, list `reports/*.qmd` and ask.

### 2. Pre-flight checks

a) **Quarto + R available:**

   ```bash
   quarto check
   ```

   Confirm "R: OK" (or that the `knitr` engine resolves). If R is missing, emit a clear setup instruction:

   > "R or the `rmarkdown` package is not on the system. Install R and run `Rscript -e \"install.packages('rmarkdown')\"`, then re-run."

   Do NOT attempt to render without the engine — it will fail confusingly.

b) **No inline analysis** — grep the `.qmd` for analysis calls inside `{r}` chunks:

   ```bash
   grep -nE "feols|fixest::|estimatr::|sandwich::|\\blm\\(|\\bglm\\(|ivreg|did2s" reports/<file>.qmd
   ```

   If found inside ```{r}``` chunks → flag and refuse to render. Analysis lives in `R/`, not in reports. The report should `read_csv()` from `output/tables/` or include a pre-built figure.

c) **Freshness check** for every included artifact (per `single-source-of-truth`):

   - For each `output/tables/X` or `output/figures/X` referenced in the `.qmd`
   - Find the producing R script (grep for the path in `R/`)
   - If script mtime > artifact mtime → STALE → re-run via `/run-r` BEFORE rendering

d) **Citation completeness:**

   - Extract every `@key` from the `.qmd`
   - Confirm each appears in `references.bib`

e) **Numerical-claim validation:**

   - Identify text claims with numbers (regex on the Markdown narrative outside code chunks)
   - Delegate each to the `r-log-validator` agent against the relevant `logs/*.log`
   - If any claim is `UNVERIFIED` → refuse to render until either the script re-runs or the claim is removed

### 3. Render

```bash
quarto render reports/<file>.qmd
```

By default, produces HTML in `docs/` (or report-local `_files/`). For PDF or DOCX, the `.qmd` needs the `format` block to declare them.

### 4. Post-render verification

- Confirm output exists and is non-empty
- Open the rendered HTML and confirm figures and tables display (read the rendered file's image references)
- No "Could not render" placeholders

### 5. Report to user

- Path of rendered output
- Freshness verdict
- Numerical-claim verdict (N verified, 0 unverified)
- Citation completeness (N keys, 0 missing)
- Next step (commit / share / revise)

## Examples

- `/render-report reports/analysis_report.qmd`
  → Full pre-flight + render.

- `/render-report analysis_report` → resolves to `reports/analysis_report.qmd`.

## Troubleshooting

- **"No engine for r" / "R not found"** — install R (≥ 4.3) and the `rmarkdown` + `knitr` packages.
- **Render hangs** — typically a `{r}` chunk doing heavy computation. Reports should NOT do analysis; refactor into `R/`.
- **Broken figure path** — the `.qmd` references `output/figures/X.pdf` but the file doesn't exist. Re-run the producing R script.
- **`Bibliography file not found`** — the `_quarto.yml` should point to `bibliography: ../references.bib` (relative from `reports/`).
- **`there is no package called 'X'`** — the report's chunks need the package; either add to `renv.lock` via `renv::snapshot()` or include a `library()` block in a setup chunk.

## Notes

- Reports are output, not source. They should NOT contain analysis logic. If a result is ad-hoc, put it in an R script first, then `read_csv()` from `output/tables/` or `knitr::include_graphics()` from `output/figures/`.
- Numerical-claim validation is a HARD GATE. If a claim cannot be verified, the report does not render. This is per `log-verification-protocol`.
- Output goes to `docs/` for GitHub Pages compatibility (set in `_quarto.yml`).
