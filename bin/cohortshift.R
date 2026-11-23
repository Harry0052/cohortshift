#!/usr/bin/env Rscript

args_all <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args_all, value = TRUE)
if (length(file_arg) != 1L) {
  message("cohortshift: run this file with Rscript.")
  quit(status = 2L)
}
script <- sub("^--file=", "", file_arg[[1L]])
root <- normalizePath(file.path(dirname(script), ".."), mustWork = TRUE)
sources <- c(
  "limits.R", "errors.R", "json.R", "bins.R", "schema.R",
  "margins.R", "bounds.R", "compare.R", "report.R", "cli.R"
)
for (name in sources) {
  source(file.path(root, "R", name), local = FALSE)
}
status <- run_cohortshift(commandArgs(trailingOnly = TRUE))
quit(status = status)
