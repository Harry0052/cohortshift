.count_text <- function(count, denominator, status) {
  if (status %in% c("observed_zero", "observed_positive") && !is.null(count)) {
    sprintf("%s/%s", format(count, scientific = FALSE, trim = TRUE), format(denominator, scientific = FALSE, trim = TRUE))
  } else if (status == "suppressed") {
    sprintf("suppressed (denominator %s)", format(denominator, scientific = FALSE, trim = TRUE))
  } else if (status == "absent") {
    sprintf("absent (denominator %s)", format(denominator, scientific = FALSE, trim = TRUE))
  } else {
    "not an observed count"
  }
}

.pp_text <- function(value) {
  if (is.null(value)) {
    return("not identified")
  }
  format(round(value, 6), scientific = FALSE, trim = TRUE, nsmall = 0)
}

render_summary <- function(result) {
  if (!isTRUE(result$ok)) {
    return(sprintf(
      "Comparison refused [%s]. %s\nHint: %s\n",
      result$category, result$message, result$hint
    ))
  }
  lines <- c(
    "CohortShift comparison",
    "",
    paste("Methodology:", result$methodology),
    "",
    "Limitations:"
  )
  for (item in result$limitations) {
    lines <- c(lines, paste("-", item))
  }
  lines <- c(lines, "", "Marginal gaps (study share minus target share):")
  for (row in result$marginals) {
    lines <- c(lines, sprintf(
      "- %s / %s: study %s, target %s, difference %s percentage points. Evidence: %s. Count status: %s. Sources: %s | %s.",
      row$variable, row$stratum,
      .count_text(row$study_count, row$study_denominator, if (row$study_missingness == "observed") "observed_positive" else row$study_missingness),
      .count_text(row$target_count, row$target_denominator, if (row$target_missingness == "observed") "observed_positive" else row$target_missingness),
      .pp_text(row$difference_pp),
      row$evidence, row$count_status,
      row$study_source_ref, row$target_source_ref
    ))
  }
  lines <- c(lines, "", "Intersections:")
  for (row in result$intersections) {
    if (identical(row$evidence, "identified")) {
      detail <- sprintf(
        "observed gap %s percentage points (study %s, target %s).",
        .pp_text(row$difference_pp),
        format(row$study_count, scientific = FALSE, trim = TRUE),
        format(row$target_count, scientific = FALSE, trim = TRUE)
      )
    } else if (identical(row$evidence, "bounded")) {
      detail <- sprintf(
        "not an observed gap. The study-minus-target gap can lie from %s to %s percentage points (study count %s to %s, target count %s to %s).",
        .pp_text(row$difference_pp_low), .pp_text(row$difference_pp_high),
        format(row$study_count_low, scientific = FALSE, trim = TRUE),
        format(row$study_count_high, scientific = FALSE, trim = TRUE),
        format(row$target_count_low, scientific = FALSE, trim = TRUE),
        format(row$target_count_high, scientific = FALSE, trim = TRUE)
      )
    } else {
      detail <- "unavailable. The margins do not identify a count or a bound."
    }
    lines <- c(lines, sprintf(
      "- %s x %s: %s Evidence: %s. Count status: %s (study %s, target %s). Sources: %s | %s.",
      row$stratum_a, row$stratum_b, detail, row$evidence, row$count_status,
      row$study_count_status, row$target_count_status,
      row$study_source_ref, row$target_source_ref
    ))
  }
  lines <- c(lines, "", sprintf(
    "Coverage: %s of %s requested subgroups have identified counts (share %s).",
    result$coverage$identified, result$coverage$requested,
    format(result$coverage$share, scientific = FALSE, trim = TRUE, nsmall = 0)
  ))
  paste(lines, collapse = "\n")
}

.safe_output_dir <- function(path) {
  if (!is.character(path) || length(path) != 1L || !nzchar(path)) {
    return(.refuse("resource", "An output directory is required.", "Pass --out with a directory path."))
  }
  if (any(strsplit(path, "/|\\\\", perl = TRUE)[[1L]] == "..")) {
    return(.refuse(
      "resource",
      "The output path is not allowed.",
      "Pass a directory that does not contain a parent-directory segment."
    ))
  }
  if (!dir.exists(path)) {
    created <- dir.create(path, recursive = TRUE, showWarnings = FALSE)
    if (!isTRUE(created) && !dir.exists(path)) {
      return(.refuse("resource", sprintf("Could not create output directory %s.", path), "Choose a writable directory."))
    }
  }
  info <- file.info(path)
  if (is.na(info$isdir) || !isTRUE(info$isdir)) {
    return(.refuse("resource", sprintf("Output path %s is not a directory.", path), "Pass a directory to --out."))
  }
  list(ok = TRUE, path = normalizePath(path, mustWork = TRUE))
}

write_comparison <- function(result, out_dir) {
  destination <- .safe_output_dir(out_dir)
  if (!isTRUE(destination$ok)) {
    return(destination)
  }
  json_path <- file.path(destination$path, "result.json")
  text_path <- file.path(destination$path, "summary.txt")
  writeLines(to_json(result), json_path, useBytes = TRUE)
  writeLines(render_summary(result), text_path, useBytes = TRUE)
  list(ok = TRUE, directory = destination$path, json = json_path, summary = text_path)
}
