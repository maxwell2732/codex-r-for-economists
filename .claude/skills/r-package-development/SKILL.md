---
name: r-package-development
description: R package development guide covering dependencies, API design, testing, and documentation. Use when developing R packages.
---

# R Package Development Decision Guide

*Dependencies, API design, testing, documentation, and best practices for R packages*

## Dependency Strategy

### When to Add Dependencies vs Base R

```r
# Add dependency when:
# - Significant functionality gain
# - Maintenance burden reduction
# - User experience improvement
# - Complex implementation (regex, dates, web)

# Use base R when:
# - Simple utility functions
# - Package will be widely used (minimize deps)
# - Dependency is large for small benefit
# - Base R solution is straightforward

# Example decisions:
str_detect(x, "pattern")    # Worth stringr dependency
length(x) > 0              # Don't need purrr for this
parse_dates(x)             # Worth lubridate dependency
x + 1                      # Don't need dplyr for this
```

### Tidyverse Dependency Guidelines

```r
# Core tidyverse (usually worth it):
dplyr     # Complex data manipulation
purrr     # Functional programming, parallel
stringr   # String manipulation
tidyr     # Data reshaping

# Specialized tidyverse (evaluate carefully):
lubridate # If heavy date manipulation
forcats   # If many categorical operations
readr     # If specific file reading needs
ggplot2   # If package creates visualizations

# Heavy dependencies (use sparingly):
tidyverse # Meta-package, very heavy
shiny     # Only for interactive apps
```

### Dependency Specification in DESCRIPTION

```
# Strong dependencies (required)
Imports:
    dplyr (>= 1.1.0),
    rlang (>= 1.0.0)

# Suggested dependencies (optional)
Suggests:
    testthat (>= 3.0.0),
    knitr,
    rmarkdown

# Enhanced functionality (optional but loaded if available)
Enhances:
    data.table
```

## API Design Patterns

### Function Design Strategy

```r
# Modern tidyverse API patterns

# 1. Use .by for per-operation grouping
my_summarise <- function(.data, ..., .by = NULL) {
  # Support modern grouped operations
}

# 2. Use {{ }} for user-provided columns
my_select <- function(.data, cols) {
  .data |> select({{ cols }})
}

# 3. Use ... for flexible arguments
my_mutate <- function(.data, ..., .by = NULL) {
  .data |> mutate(..., .by = {{ .by }})
}

# 4. Return consistent types (tibbles, not data.frames)
my_function <- function(.data) {
  result |> tibble::as_tibble()
}
```

### Input Validation Strategy

```r
# User-facing functions - comprehensive validation
user_function <- function(x, threshold = 0.5) {
  if (!is.numeric(x)) stop("x must be numeric")
  if (!is.numeric(threshold) || length(threshold) != 1) {
    stop("threshold must be a single number")
  }
}

# Internal functions - minimal validation
.internal_function <- function(x, threshold) {
  # Assume inputs are valid (document assumptions)
}
```

## Error Handling Patterns

```r
# Good error messages - specific and actionable
if (length(x) == 0) {
  cli::cli_abort(
    "Input {.arg x} cannot be empty.",
    "i" = "Provide a non-empty vector."
  )
}

# Include caller env so error points to user call
validate_input <- function(x, call = caller_env()) {
  if (!is.numeric(x)) {
    cli::cli_abort("Input must be numeric", call = call)
  }
}

# Custom error classes for programmatic handling
validation_error <- function(message, ..., call = caller_env()) {
  cli::cli_abort(
    message,
    ...,
    class = c("validation_error", "my_package_error"),
    call = call
  )
}
```

## Internal vs Exported Functions

```r
# Export when:
# - Users will call it directly
# - Part of the core package functionality
# - Stable API that won't change often

#' @export
process_data <- function(.data, ...) { ... }

# Keep internal when:
# - Implementation detail that may change
# - Only used within package
# Prefix with . for internal functions
.validate_input <- function(x, y) { ... }
```

## Documentation (roxygen2)

```r
#' Process and summarize data
#'
#' @param data A data frame or tibble.
#' @param vars <[`tidy-select`][dplyr::dplyr_tidy_select]> Columns to summarize.
#' @param .by <[`data-masking`][dplyr::dplyr_data_masking]> Optional grouping variable.
#'
#' @return A tibble with summary statistics.
#'
#' @examples
#' mtcars |> process_data(mpg, .by = cyl)
#'
#' @export
process_data <- function(data, vars, .by = NULL) { ... }
```

## Package Structure

```
mypackage/
  DESCRIPTION
  NAMESPACE
  R/
    utils.R           # Internal utilities
    validation.R      # Input validation
    core.R            # Core functionality
    methods.R         # S3/S7 methods
    zzz.R             # .onLoad, .onAttach
  tests/
    testthat/
    testthat.R
  vignettes/
  data/               # Lazy-loaded package data
  data-raw/           # Scripts to create package data
```

### DESCRIPTION Template

```
Package: mypackage
Title: What The Package Does (One Line)
Version: 0.1.0
Authors@R:
    person("First", "Last", email = "email@example.com",
           role = c("aut", "cre"))
Description: A longer description.
License: MIT + file LICENSE
Encoding: UTF-8
Roxygen: list(markdown = TRUE)
RoxygenNote: 7.2.3
Imports:
    dplyr (>= 1.1.0),
    rlang (>= 1.0.0)
Suggests:
    testthat (>= 3.0.0)
Config/testthat/edition: 3
```

## Release Checklist

```r
devtools::check()         # 0 errors, warnings, notes
devtools::test()          # All tests pass
devtools::document()      # Documentation up to date
usethis::use_version("minor")  # Bump version
# Update NEWS.md
devtools::check(remote = TRUE, manual = TRUE)
```

## Common Mistakes

```r
# WRONG: library() in package code
library(dplyr)

# CORRECT: namespace qualification or @importFrom
dplyr::filter(data, x > 0)
#' @importFrom dplyr filter mutate

# WRONG: Modifying global state without restoring
options(my_option = TRUE)

# CORRECT: Restore state
old_opts <- options(my_option = TRUE)
on.exit(options(old_opts), add = TRUE)

# WRONG: Hardcoded paths
read.csv("/home/user/data.csv")

# CORRECT: Use system.file for package data
system.file("extdata", "data.csv", package = "mypackage")
```
