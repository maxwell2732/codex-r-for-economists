# ------------------------------------------------------------------------------
# File:     R/_utils/logging.R
# Purpose:  Per-script logging helpers. start_log() opens a plain-text log
#           under logs/<name>.log; stop_log() closes it. The logs are
#           greppable by the r-log-validator agent.
# Usage:
#           source("R/_utils/logging.R")
#           start_log("03_analysis_main_regression")
#           ... script body ...
#           stop_log()
# ------------------------------------------------------------------------------

# Internal connection handle. Held in a package-style environment so it survives
# across calls without polluting the global namespace.
.logging_state <- new.env(parent = emptyenv())
.logging_state$conn <- NULL
.logging_state$path <- NULL

start_log <- function(name) {
  if (!is.null(.logging_state$conn)) {
    warning("A log is already open at ", .logging_state$path,
            "; closing it before opening a new one.")
    stop_log()
  }

  log_dir <- "logs"
  if (!dir.exists(log_dir)) dir.create(log_dir, recursive = TRUE)

  path <- file.path(log_dir, paste0(name, ".log"))
  conn <- file(path, open = "wt")

  # Tee both stdout and messages into the log file. type = "output" captures
  # cat() / print(); type = "message" captures warning() / message().
  sink(conn, split = TRUE, type = "output")
  sink(conn, type = "message")

  .logging_state$conn <- conn
  .logging_state$path <- path

  cat("=========================================================================\n")
  cat(sprintf("Log opened: %s\n", path))
  cat(sprintf("R version:  %s\n", R.version.string))
  cat(sprintf("Started:    %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")))
  cat("=========================================================================\n")
  invisible(path)
}

stop_log <- function() {
  if (is.null(.logging_state$conn)) {
    warning("stop_log() called but no log is open.")
    return(invisible(NULL))
  }

  cat("=========================================================================\n")
  cat(sprintf("Finished:   %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")))
  cat(sprintf("Log closed: %s\n", .logging_state$path))
  cat("=========================================================================\n")

  # Unwind the two sinks in LIFO order.
  sink(type = "message")
  sink(type = "output")
  close(.logging_state$conn)

  path <- .logging_state$path
  .logging_state$conn <- NULL
  .logging_state$path <- NULL
  invisible(path)
}
