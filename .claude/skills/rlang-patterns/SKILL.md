---
name: rlang-patterns
description: rlang metaprogramming patterns for data-masking, injection operators, and dynamic dots. Use when writing functions that use tidy evaluation.
---

# Modern rlang Patterns for Data-Masking

*Metaprogramming framework that powers tidyverse data-masking*

## Core Concepts

**Data-masking** allows R expressions to refer to data frame columns as if they were variables. Key tools:

| Operator | Use Case | Example |
|----------|----------|---------|
| `{{ }}` | Forward function arguments | `summarise(mean = mean({{ var }}))` |
| `!!` | Inject single expression/value | `summarise(mean = mean(!!sym(var)))` |
| `!!!` | Inject multiple arguments | `group_by(!!!syms(vars))` |
| `.data[[]]` | Access columns by name | `mean(.data[[var]])` |

## Function Argument Patterns

### Forwarding with `{{}}`

```r
# Single argument
my_summarise <- function(data, var) {
  data |> dplyr::summarise(mean = mean({{ var }}))
}
mtcars |> my_summarise(cyl)
mtcars |> my_summarise(cyl * am)  # expressions work too

# Named output with glue
my_mean <- function(data, var) {
  data |> dplyr::summarise("mean_{{ var }}" := mean({{ var }}))
}
mtcars |> my_mean(cyl)  # creates column "mean_cyl"
```

### Forwarding `...` (no special syntax needed)

```r
my_group_by <- function(.data, ...) {
  .data |> dplyr::group_by(...)
}
my_select <- function(.data, ...) {
  .data |> dplyr::select(...)
}
```

### Programmatic column access via `.data`

```r
# Access by string name — no ambiguity
my_mean <- function(data, var) {
  data |> dplyr::summarise(mean = mean(.data[[var]]))
}
mtcars |> my_mean("cyl")

# Multiple columns
my_select_vars <- function(data, vars) {
  data |> dplyr::select(all_of(vars))
}
mtcars |> my_select_vars(c("cyl", "am"))
```

## Injection Operators

### `!!` — inject a single symbol or value

```r
var <- "cyl"
mtcars |> dplyr::summarise(mean = mean(!!sym(var)))

# Avoid env/data collision
x <- 100
df |> dplyr::mutate(scaled = x / !!x)  # uses both data$x and env x
```

### `!!!` — splice a list

```r
vars <- c("cyl", "am")
mtcars |> dplyr::group_by(!!!syms(vars))

args <- list(na.rm = TRUE, trim = 0.1)
mtcars |> dplyr::summarise(mean = mean(cyl, !!!args))
```

## Dynamic Dots with `list2()`

```r
my_function <- function(...) {
  dots <- list2(...)
  # Enables splicing, name injection, trailing commas
}

# Name injection with glue syntax
name <- "result"
list2("{name}" := 1)  # list(result = 1)

# Allow user to override auto-generated name
my_mean <- function(data, var, name = englue("mean_{{ var }}")) {
  data |> dplyr::summarise("{name}" := mean({{ var }}))
}
mtcars |> my_mean(cyl, name = "cyl_avg")
```

## Disambiguation with `.data` / `.env`

```r
cyl <- 1000  # environment variable

mtcars |> dplyr::summarise(
  data_cyl = mean(.data$cyl),   # column
  env_cyl  = mean(.env$cyl)     # environment (1000)
)
```

## Bridge Patterns

```r
# across() as selection-to-data-mask bridge
my_group_by <- function(data, vars) {
  data |> dplyr::group_by(across({{ vars }}))
}
mtcars |> my_group_by(starts_with("c"))  # tidy selection works

# all_of() as names-to-data-mask bridge
my_means <- function(data, ...) {
  data |> dplyr::summarise(across(c(...), ~ mean(.x, na.rm = TRUE)))
}
```

## Anti-Patterns to Avoid

```r
# WRONG: eval(parse()) — security risk and fragile
var <- "cyl"
eval(parse(text = paste("mean(", var, ")")))

# CORRECT:
mean(!!sym(var))
# or
mean(.data[[var]])

# WRONG: get() in data mask — collision-prone
with(mtcars, mean(get(var)))

# CORRECT:
mtcars |> summarise(mean(.data[[var]]))
```

## Package Development

```r
# DESCRIPTION Imports:
#   rlang

# In roxygen2 docs:
#' @param var <[`data-masked`][dplyr::dplyr_data_masking]> Column to summarize
#' @param ... <[`dynamic-dots`][rlang::dyn-dots]> Additional grouping variables
```
