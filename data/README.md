# Data Directory

This directory holds **raw** and **derived** datasets for the R pipeline.

> **Privacy guarantee:** Everything under `data/raw/` and `data/derived/` is gitignored. Only this README and `.gitkeep` files reach GitHub. The pre-commit hook `scripts/check_data_safety.py` enforces this before every commit.

## Layout

```
data/
├── raw/                # Untouched source datasets — never edited, never committed
├── derived/            # Intermediate .rds produced by R/01_clean and R/02_construct
└── README.md           # This file (the data dictionary)
```

## Data dictionary template

Replace this placeholder with one entry per dataset.

### `data/raw/[FILENAME].{csv,dta,parquet}`

| Field | Value |
|---|---|
| **Source** | [Where it came from — URL, agency, paper, etc.] |
| **Vintage** | [Date downloaded / version] |
| **Access restrictions** | [Public / restricted / proprietary — license terms] |
| **Unit of observation** | [Person / firm / county-year / etc.] |
| **Sample period** | [YYYY–YYYY] |
| **N rows** | [count] |
| **Loaded by** | `R/01_clean/[script].R` |
| **Notes** | [Quirks, missingness, known issues] |

### `data/derived/[FILENAME].rds`

| Field | Value |
|---|---|
| **Produced by** | `R/02_construct/[script].R` |
| **Inputs** | `data/raw/...`, `data/derived/...` |
| **Sample restrictions** | [What's been dropped/kept] |
| **N rows** | [after restrictions] |
| **Used by** | `R/03_analysis/...` |
