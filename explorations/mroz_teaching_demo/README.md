# Mroz Teaching Demo

This exploration uses `data/raw/MROZ.csv`, the classic Mroz married women's
labor-supply data, for an introductory econometrics classroom demo.

Run from the repository root:

```bash
bash scripts/run_r.sh explorations/mroz_teaching_demo/R/01_mroz_tutorial.R
```

On Windows PowerShell:

```powershell
scripts\run_r.bat explorations\mroz_teaching_demo\R\01_mroz_tutorial.R
```

The script produces:

- Descriptive statistics and group summaries.
- One-way and two-way ANOVA tables.
- Pearson correlation matrix and heatmap.
- OLS wage equations.
- IV wage equations using parents' education as instruments for the woman's
  education.
- PNG/PDF figures and a short `teaching_notes.md` explaining how to read the
  outputs.
