---
name: r-oop
description: R object-oriented programming guide for S7, S3, S4, and vctrs. Use when designing R classes or choosing an OOP system.
---

# R Object-Oriented Programming

*S7, S3, S4, vctrs — choosing the right system*

## Decision Matrix

| What are you building? | Use |
|---|---|
| Vector-like objects (date-like, factor-like, units) | **vctrs** |
| New complex objects with validation + multiple dispatch | **S7** |
| Simple classes, quick prototyping, existing S3 ecosystem | **S3** |
| Bioconductor or complex multiple inheritance required | **S4** |

## S7 — Modern OOP (Recommended for New Projects)

S7 = S3 simplicity + S4 structure. Available via `library(S7)`.

```r
library(S7)

# Define class
Range <- new_class("Range",
  properties = list(
    start = class_double,
    end   = class_double
  ),
  validator = function(self) {
    if (self@end < self@start) "@end must be >= @start"
  }
)

# Create instance — automatic validation
x <- Range(start = 1, end = 10)
x@start   # 1
x@end <- 5   # validated assignment

# Define generic + method
inside <- new_generic("inside", "x")
method(inside, Range) <- function(x, y) {
  y >= x@start & y <= x@end
}

# Multiple dispatch
combine <- new_generic("combine", c("x", "y"))
method(combine, list(Range, Range)) <- function(x, y) { ... }

# Inheritance
BoundedRange <- new_class("BoundedRange", parent = Range,
  properties = list(label = class_character)
)
```

## S7 vs S3 Comparison

| Feature | S3 | S7 |
|---|---|---|
| Class definition | Informal (`structure()`) | Formal (`new_class()`) |
| Property access | `$` or `attr()` (unsafe) | `@` (validated) |
| Validation | Manual | Built-in |
| Multiple dispatch | Limited | Full |
| Inheritance | `NextMethod()` | `super()` |
| S3 compatibility | — | Full |
| Performance | Fastest | ~Same as S3 |

## S3 — Simple Classes

```r
# Constructor
new_person <- function(name, age) {
  stopifnot(is.character(name), length(name) == 1)
  stopifnot(is.numeric(age),   length(age)  == 1)
  structure(list(name = name, age = age), class = "person")
}

# Generic + method
greet         <- function(x, ...) UseMethod("greet")
greet.person  <- function(x, ...) cat("Hello,", x$name, "\n")
greet.default <- function(x, ...) cat("Hello!\n")

print.person  <- function(x, ...) { cat("Person:", x$name, "(age", x$age, ")\n"); invisible(x) }

# Inheritance
new_employee <- function(name, age, company) {
  obj          <- new_person(name, age)
  obj$company  <- company
  class(obj)   <- c("employee", class(obj))
  obj
}
print.employee <- function(x, ...) { NextMethod(); cat("Works at:", x$company, "\n"); invisible(x) }
```

## vctrs — Vector-Like Classes

```r
library(vctrs)

# New vector class
new_percent <- function(x = double()) {
  vec_assert(x, double())
  new_vctr(x, class = "percent")
}
percent <- function(x) new_percent(as.double(x))

format.percent <- function(x, ...) paste0(round(unclass(x) * 100, 1), "%")

# Type-stable coercion
vec_ptype2.percent.percent <- function(x, y, ...) new_percent()
vec_cast.percent.double    <- function(x, to, ...) new_percent(x)

# Works in data frames seamlessly
tibble(x = 1:3, pct = percent(c(0.1, 0.2, 0.3)))
```

## When NOT to Use OOP

```r
# For simple data — use named vectors or lists, not classes
point <- c(x = 1.5, y = 2.3)
distance <- function(p1, p2) sqrt(sum((p1 - p2)^2))

# For one-off operations — use functions directly
```

## Migration Path

- **S3 → S7**: 1–2 hours, backward compatible, recommended whenever possible
- **S4 → S7**: More involved; only if S4-specific features are truly needed
- **Base R → vctrs**: For vector-like types; significant benefit for data-frame integration
