# Data Dictionary

> Use this template for `data/README.md` in your fork. Document every dataset
> in `data/raw/` and `data/derived/`. Keep entries concise — one block per file.

## Conventions

- **Variable names:** snake_case
- **Missing values:** `NA` (R default); for `.dta` ingest via `haven::read_dta` Stata's `.` is converted to `NA` automatically
- **Date format:** `YYYY-MM-DD` (ISO 8601) — store as `Date` class via `as.Date()` or `lubridate::ymd()`
- **Currency:** specify nominal vs. real, base year for real, currency code

---

## Raw Datasets

### `data/raw/[FILENAME].{csv,dta,parquet}`

| Field | Value |
|---|---|
| **Source** | [Full URL, agency, paper, etc.] |
| **Vintage** | [Date downloaded] |
| **License** | [Public / Restricted / Proprietary — terms] |
| **Unit of observation** | [Person / firm / county-year / etc.] |
| **Sample period** | [YYYY–YYYY] |
| **N rows** | [Count] |
| **N variables** | [Count] |
| **Loaded by** | `R/01_clean/[script].R` |
| **Documentation** | [Link to codebook, if external] |
| **Notes** | [Quirks: known missingness, encoding issues, surveys/waves] |

#### Key variables

| Variable | Type | Description | Notes |
|---|---|---|---|
| `id` | int | Unit identifier | unique within year |
| `year` | int | Survey year | 2000–2020 |
| `outcome_var` | num | Outcome of interest | in $ thousands |

---

## Derived Datasets

### `data/derived/[FILENAME].rds`

| Field | Value |
|---|---|
| **Produced by** | `R/02_construct/[script].R` |
| **Inputs** | `data/raw/...`, `data/derived/...` |
| **Sample restrictions** | [What's been dropped/kept and why] |
| **N rows** | [After restrictions] |
| **Used by** | `R/03_analysis/[scripts].R` |

#### Constructed variables

| Variable | Construction | Comment |
|---|---|---|
| `treated` | `as.integer(group == "T")` — 1 if ever in treatment group | per Section 3 of paper |
| `post` | `as.integer(year >= treatment_year)` — 1 if year ≥ treatment year | |
| `log_y` | `log(outcome + 1)` | smooths zeros |
