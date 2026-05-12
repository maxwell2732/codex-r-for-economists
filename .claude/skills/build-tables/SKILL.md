---
name: build-tables
description: Combine saved R model results into publication-ready tables via modelsummary. Produces both .tex (for paper) and .csv (for audit) with consistent formatting.
disable-model-invocation: true
argument-hint: "[table-name or models-list]"
allowed-tools: ["Bash", "Read", "Edit", "Write", "Grep", "Glob"]
---

# Build Publication-Ready Tables

Take a set of saved model objects (typically a named list in an analysis script) and produce a single table in `.tex` (for the paper) and `.csv` (for audit / sharing) with the project's standard formatting.

## When to Use

- After running `R/03_analysis/*.R` that fit `models[["m_name"]] <- feols(...)` results
- When assembling a multi-spec table (main + alt outcome + alt cluster + alt FE)
- Before rendering the report — tables must exist in `output/tables/` first

## Steps

1. **Identify the models** in `$ARGUMENTS`:
   - If a table name (e.g., `main_regression`): search `R/03_analysis/` for `models[["m_main..."]] <-` assignments and assemble
   - If an explicit model list (e.g., `m_ols m_iv m_did`): use those names
   - If empty: ask the user which table to build

2. **Locate the producing R script** that has the estimation calls. The script should also do the `modelsummary()` export. If it doesn't, write a helper script in `R/04_output/<table>_assemble.R`.

3. **Compose the `modelsummary()` call** with project conventions:

   ```r
   library(modelsummary)
   library(kableExtra)

   models <- list(
     "Main"        = readRDS(proj_path("R", "03_analysis", "m_main.rds")),
     "Alt cluster" = readRDS(proj_path("R", "03_analysis", "m_alt_cluster.rds")),
     "Alt FE"      = readRDS(proj_path("R", "03_analysis", "m_alt_fe.rds"))
   )

   modelsummary(
     models,
     output = proj_path("output", "tables", "<name>.tex"),
     stars  = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
     fmt    = 3,
     gof_omit = "AIC|BIC|Log.Lik|RMSE",
     coef_omit = "Intercept",
     title  = "<table title>",
     notes  = c("Standard errors clustered at <level>.",
                "Significance: * p<0.10, ** p<0.05, *** p<0.01.")
   )

   modelsummary(
     models,
     output = proj_path("output", "tables", "<name>.csv"),
     stars  = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
     fmt    = 3
   )
   ```

   Note: pre-store each fitted model with `saveRDS(model, ...)` in the producing analysis script so the assembly step does not re-estimate.

4. **Run the script** via `/run-r`.

5. **Verify outputs:**
   - Both `.tex` and `.csv` exist in `output/tables/`
   - Read the `.csv` and spot-check coefficients are sensible
   - Confirm the `.tex` includes N, R², mean dep var, cluster info, significance stars

6. **Report:** path of new `.tex` and `.csv`, the spec each column represents, a one-line summary of the headline coefficient.

## Examples

- `/build-tables main_regression` → assembles `output/tables/main_regression.{tex,csv}` from `m_main`-prefixed models.
- `/build-tables m_ols m_iv m_did` → assembles a 3-column table from those specific saved models.

## Troubleshooting

- **"object 'm_main' not found"** — the model was never saved. Either keep it in the same R session (don't run scripts in separate `Rscript` invocations) or `saveRDS()` it after the `feols()` call.
- **`modelsummary` not installed** — `Rscript -e "install.packages('modelsummary')"` and `renv::snapshot()`.
- **Long term names break LaTeX** — pass `coef_map = c("treated:post" = "Treated $\\times$ Post")` to rename for the table.
- **Stars do not appear** — check that `stars = c("*" = 0.10, ...)` is set; default `modelsummary()` does not show them.

## Notes

- Tables ALWAYS go to BOTH `.tex` and `.csv` — `.tex` is for the paper, `.csv` is for reviewers / coauthors who don't speak LaTeX.
- Never hand-edit the produced `.tex`; the next pipeline run will overwrite it. Adjust `modelsummary()` options instead.
- Significance stars: `* p<0.10, ** p<0.05, *** p<0.01` is the project default. Override only if the journal requires different.
- For HTML output (e.g., embedded in a Quarto report), pass `output = "<name>.html"` as a third call — the report `include`s it.
