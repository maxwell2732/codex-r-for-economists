---
name: tdd-workflow
description: Test-driven development workflow for R using testthat 3. Use when writing new functions, fixing bugs, or refactoring analysis code.
---

# Test-Driven Development for R

*testthat 3 edition — write tests first, then implementation*

## Setup

```r
usethis::use_testthat(3)        # initialize testing
usethis::use_test("function_name")  # create test file
devtools::load_all()            # exposes unexported functions; prefer over library()
```

Ensure `DESCRIPTION` contains: `Config/testthat/edition: 3`

## TDD Cycle

### 1 — Write failing tests first

```r
# tests/testthat/test-calculate_ci.R
test_that("returns named numeric vector", {
  set.seed(123)
  result <- calculate_ci(1:100)
  expect_type(result, "double")
  expect_named(result, c("lower", "upper"))
  expect_true(result["lower"] < result["upper"])
})

test_that("handles NA values", {
  set.seed(123)
  result <- calculate_ci(c(1:100, NA, NA))
  expect_false(any(is.na(result)))
})

test_that("validates inputs", {
  expect_error(calculate_ci("text"),     class = "validation_error")
  expect_error(calculate_ci(numeric(0)), class = "validation_error")
})
```

### 2 — Run tests (they should fail)

```r
devtools::test()
```

### 3 — Implement minimal code

```r
calculate_ci <- function(x, conf_level = 0.95, n_boot = 1000) {
  if (!is.numeric(x))   cli::cli_abort("{.arg x} must be numeric", class = "validation_error")
  if (length(x) == 0)   cli::cli_abort("{.arg x} cannot be empty",  class = "validation_error")
  if (conf_level <= 0 || conf_level >= 1)
    cli::cli_abort("{.arg conf_level} must be in (0, 1)", class = "validation_error")

  x <- x[!is.na(x)]
  alpha <- 1 - conf_level
  boot_means <- replicate(n_boot, mean(sample(x, replace = TRUE)))
  c(lower = unname(quantile(boot_means, alpha / 2)),
    upper = unname(quantile(boot_means, 1 - alpha / 2)))
}
```

### 4 — Re-run; refactor while keeping tests green

### 5 — Verify coverage

```r
covr::package_coverage()  # target: ≥ 80% overall, 100% for stats/validation
```

## Coverage Requirements

| Code type | Minimum coverage |
|---|---|
| Statistical calculations | 100% |
| Input validation | 100% |
| Overall | 80% |

## Key Test Types

### Unit — individual functions

```r
test_that("rescale01 normalizes to [0, 1]", {
  expect_equal(rescale01(c(0, 5, 10)), c(0, 0.5, 1))
  expect_equal(rescale01(c(5, 5, 5)),  c(NaN, NaN, NaN))
  expect_equal(rescale01(numeric(0)),  numeric(0))
})
```

### Integration — full pipeline

```r
test_that("pipeline produces expected output", {
  result <- raw_data |> clean_data() |> transform_features() |> summarize_results()
  expect_s3_class(result, "tbl_df")
  expect_named(result, c("group", "mean", "sd", "n"))
})
```

### Snapshot — complex outputs

```r
test_that("summary format is stable", {
  expect_snapshot(print(summary(fit_model(test_data))))
})
# Accept changes: testthat::snapshot_accept("test_name")
```

## Key Expectations

```r
# Equality
expect_equal(x, y)
expect_equal(x, y, tolerance = 0.001)
expect_equal(x, y, ignore_attr = TRUE)
expect_identical(x, y)

# Conditions
expect_error(code, class = "my_error_class")
expect_warning(code)
expect_no_warning(code)
expect_message(code)

# Type / structure
expect_type(x, "double")
expect_s3_class(x, "tbl_df")
expect_named(x, c("a", "b"))
expect_length(x, 10)
expect_true(x); expect_false(x); expect_null(x)
```

## Self-Contained Tests

Each test must contain its own setup — never rely on shared state:

```r
# GOOD
test_that("handles grouped data", {
  data <- tibble(x = 1:10, group = rep(c("A","B"), 5))  # setup here
  result <- my_function(data)
  expect_equal(nrow(result), 2)
})
```

## Temporary State with withr

```r
withr::local_options(list(digits = 2))   # restored after test
withr::local_envvar(MY_VAR = "test")
tmp <- withr::local_tempfile(fileext = ".csv")
```

## Mocking (Edition 3)

```r
local_mocked_bindings(
  external_call = function(...) "mocked_result"
)
result <- my_function_that_calls_external()
```

## File Organization

```
tests/
  testthat/
    test-validation.R     # mirrors R/validation.R
    test-processing.R     # mirrors R/processing.R
    helper-fixtures.R     # shared helpers (auto-sourced)
    fixtures/             # static data files
  testthat.R
```

Access fixtures: `test_path("fixtures", "sample_data.csv")`

## Running Tests

```r
devtools::test()                         # full suite
devtools::test(reporter = "slow")        # find slow tests
devtools::test(shuffle = TRUE)           # verify independence
testthat::test_file("tests/testthat/test-validation.R")  # single file
testthat::auto_test_package()            # watch mode
devtools::check()                        # full package check
```

## Anti-Patterns

```r
# WRONG: change test to make it pass
expect_equal(my_func(), 41)   # changed from 42 — WRONG

# CORRECT: fix the implementation, not the test

# WRONG: test depends on another test
test_that("uses data", { process(global_data) })  # global_data set elsewhere

# CORRECT: each test sets up its own data
```
