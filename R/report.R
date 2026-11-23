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

.html_escape <- function(text) {
  text <- enc2utf8(as.character(text))
  text <- gsub("&", "&amp;", text, fixed = TRUE)
  text <- gsub("<", "&lt;", text, fixed = TRUE)
  text <- gsub(">", "&gt;", text, fixed = TRUE)
  text <- gsub("\"", "&quot;", text, fixed = TRUE)
  text
}

.evidence_label <- function(evidence, count_status) {
  if (identical(count_status, "observed_zero")) {
    return("Observed zero")
  }
  if (identical(count_status, "suppressed")) {
    return("Suppressed, not zero")
  }
  if (identical(count_status, "absent")) {
    return("Absent, not zero")
  }
  if (identical(evidence, "identified")) {
    return("Identified")
  }
  if (identical(evidence, "bounded")) {
    return("Bounded, not observed")
  }
  "Unavailable"
}

.describe_marginal <- function(row) {
  if (!identical(row$evidence, "identified")) {
    return(sprintf(
      "The %s stratum %s cannot be differenced because a count is %s.",
      row$variable, row$stratum, row$count_status
    ))
  }
  direction <- if (row$difference_pp < 0) "lower" else if (row$difference_pp > 0) "higher" else "the same"
  sprintf(
    "The study share of %s %s is %s percentage points %s than the target share (%s/%s versus %s/%s).",
    row$variable, row$stratum, .pp_text(abs(row$difference_pp)), direction,
    format(row$study_count, scientific = FALSE, trim = TRUE),
    format(row$study_denominator, scientific = FALSE, trim = TRUE),
    format(row$target_count, scientific = FALSE, trim = TRUE),
    format(row$target_denominator, scientific = FALSE, trim = TRUE)
  )
}

.describe_intersection <- function(row) {
  label <- paste(row$stratum_a, "and", row$stratum_b)
  if (identical(row$evidence, "identified")) {
    zero_note <- if (identical(row$study_count_status, "observed_zero")) {
      " The study count is an observed zero, not a missing cell."
    } else {
      ""
    }
    return(sprintf(
      "The %s intersection is identified. The study-minus-target gap is %s percentage points (study %s, target %s).%s",
      label, .pp_text(row$difference_pp),
      format(row$study_count, scientific = FALSE, trim = TRUE),
      format(row$target_count, scientific = FALSE, trim = TRUE),
      zero_note
    ))
  }
  if (identical(row$evidence, "bounded")) {
    return(sprintf(
      "The %s intersection is not an observed count. The study-minus-target gap can lie from %s to %s percentage points, and that range is not a single observed gap.",
      label, .pp_text(row$difference_pp_low), .pp_text(row$difference_pp_high)
    ))
  }
  sprintf(
    "The %s intersection is unavailable (%s). No gap is reported.",
    label, row$count_status
  )
}

render_html <- function(result) {
  if (!isTRUE(result$ok)) {
    body <- sprintf(
      "<h1>Comparison refused</h1><p class=\"badge unavailable\">%s</p><p>%s</p><p>Recovery: %s</p>",
      .html_escape(result$category), .html_escape(result$message), .html_escape(result$hint)
    )
  } else {
    show_count <- function(count) {
      if (is.null(count) || length(count) == 0L || is.na(count[[1L]])) "not observed" else format(count, scientific = FALSE, trim = TRUE)
    }
    marginal_rows <- vapply(result$marginals, function(row) {
      sprintf(
        "<tr class=\"evidence-%s\"><td>%s</td><td>%s</td><td>%s/%s</td><td>%s/%s</td><td>%s</td><td><span class=\"badge\">%s</span></td><td>%s</td><td>%s</td></tr>",
        .html_escape(row$evidence),
        .html_escape(row$variable), .html_escape(row$stratum),
        .html_escape(show_count(row$study_count)),
        .html_escape(format(row$study_denominator, scientific = FALSE, trim = TRUE)),
        .html_escape(show_count(row$target_count)),
        .html_escape(format(row$target_denominator, scientific = FALSE, trim = TRUE)),
        .html_escape(.pp_text(row$difference_pp)),
        .html_escape(.evidence_label(row$evidence, row$count_status)),
        .html_escape(row$study_source_ref), .html_escape(row$target_source_ref)
      )
    }, character(1))
    observations <- c(
      vapply(result$marginals, .describe_marginal, character(1)),
      vapply(result$intersections, .describe_intersection, character(1))
    )
    observation_html <- paste(sprintf("<li>%s</li>", .html_escape(observations)), collapse = "")
    intersection_rows <- vapply(result$intersections, function(row) {
      range_text <- if (identical(row$evidence, "identified")) {
        .pp_text(row$difference_pp)
      } else if (identical(row$evidence, "bounded")) {
        sprintf("%s to %s", .pp_text(row$difference_pp_low), .pp_text(row$difference_pp_high))
      } else {
        "not reported"
      }
      sprintf(
        "<tr class=\"evidence-%s\"><td>%s × %s</td><td>%s</td><td>%s</td><td><span class=\"badge\">%s</span></td><td>%s</td><td>%s</td></tr>",
        .html_escape(row$evidence),
        .html_escape(row$stratum_a), .html_escape(row$stratum_b),
        .html_escape(if (is.null(row$study_count)) "not observed" else format(row$study_count, scientific = FALSE, trim = TRUE)),
        .html_escape(if (is.null(row$target_count)) "not observed" else format(row$target_count, scientific = FALSE, trim = TRUE)),
        .html_escape(.evidence_label(row$evidence, row$count_status)),
        .html_escape(range_text),
        .html_escape(paste(row$study_source_ref, row$target_source_ref, sep = " | "))
      )
    }, character(1))
    scenario_note <- if (is.null(result$scenario_id)) {
      "No substitute target mix was applied."
    } else {
      sprintf(
        "Scenario %s replaced the target counts. The baseline target source remains %s. Study source %s is unchanged.",
        result$scenario_id,
        result$provenance$baseline_target_source_ref,
        result$provenance$study_source_ref
      )
    }
    body <- paste0(
      "<h1>CohortShift comparison</h1>",
      "<p id=\"status\" role=\"status\">Coverage: ",
      .html_escape(sprintf(
        "%s of %s requested subgroups have identified counts (share %s).",
        result$coverage$identified, result$coverage$requested,
        format(result$coverage$share, scientific = FALSE, trim = TRUE)
      )),
      "</p>",
      "<h2 id=\"findings\">What the tables support</h2>",
      "<ul>", observation_html, "</ul>",
      "<h2>Marginal counts</h2>",
      "<p>Difference is the study share minus the target share, in percentage points. Each count is shown beside its population denominator.</p>",
      "<div class=\"table-wrap\"><table><thead><tr><th>Variable</th><th>Stratum</th><th>Study count/denominator</th><th>Target count/denominator</th><th>Difference (pp)</th><th>Evidence</th><th>Study source</th><th>Target source</th></tr></thead><tbody>",
      paste(marginal_rows, collapse = ""),
      "</tbody></table></div>",
      "<h2>Intersections</h2>",
      "<p>A bounded cell is drawn with a dashed edge and the words “Bounded, not observed”. That range is not a count the source reported.</p>",
      "<div class=\"table-wrap\"><table><thead><tr><th>Intersection</th><th>Study count</th><th>Target count</th><th>Evidence</th><th>Gap or gap range (pp)</th><th>Sources</th></tr></thead><tbody>",
      paste(intersection_rows, collapse = ""),
      "</tbody></table></div>",
      "<h2>Provenance</h2>",
      "<ul>",
      "<li>Study table ", .html_escape(result$provenance$study_table_id), ", source ", .html_escape(result$provenance$study_source_ref), ".</li>",
      "<li>Target table ", .html_escape(result$provenance$target_table_id), ", source ", .html_escape(result$provenance$target_source_ref), ".</li>",
      "<li>", .html_escape(scenario_note), "</li>",
      "<li>Measurement window ", .html_escape(result$provenance$measurement_window), ".</li>",
      "<li>Study digest ", .html_escape(result$provenance$study_marginal_digest), ". Target digest ", .html_escape(result$provenance$target_marginal_digest), ".</li>",
      "</ul>",
      "<h2>Methodology</h2><p>", .html_escape(result$methodology), "</p>",
      "<h2>Limitations</h2><ul>",
      paste(sprintf("<li>%s</li>", .html_escape(unlist(result$limitations))), collapse = ""),
      "</ul>",
      "<h2>If a result is missing</h2>",
      "<p>A bounded intersection means the joint table was absent or incomplete. Add a joint file that reproduces both margins, or leave the range in place. A refused comparison means the age bands, severity definitions, or measurement windows do not match; CohortShift does not interpolate them. Validation errors name the row and a recovery hint on standard error.</p>"
    )
  }
  paste0(
    "<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"utf-8\">",
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
    "<title>CohortShift report</title><style>",
    "body{font-family:Georgia,serif;line-height:1.45;margin:1.5rem;color:#1b1b1b;background:#fff;}",
    "a:focus,summary:focus{outline:3px solid #1b1b1b;outline-offset:2px;}",
    ".skip{position:absolute;left:-999px;} .skip:focus{left:1rem;top:1rem;background:#fff;padding:.5rem;}",
    "table{border-collapse:collapse;width:100%;}",
    "th,td{border:1px solid #444;padding:.4rem;text-align:left;vertical-align:top;}",
    "th{background:#f3f3f3;}",
    ".badge{font-weight:700;}",
    ".evidence-identified{border-left:8px solid #1b1b1b;}",
    ".evidence-bounded{border-left:8px dashed #1b1b1b;background-image:repeating-linear-gradient(45deg,#fff,#fff 6px,#e6e6e6 6px,#e6e6e6 8px);}",
    ".evidence-unavailable{border-left:8px dotted #1b1b1b;}",
    "@media (max-width:40rem){h1{font-size:1.4rem;} .table-wrap{overflow-x:auto;} table,thead,tbody,th,td,tr{display:block;} thead{position:absolute;left:-999px;} td{border-left-width:8px;} td::before{font-weight:700;}}",
    "</style></head><body>",
    "<a class=\"skip\" href=\"#findings\">Skip to findings</a>",
    body,
    "</body></html>"
  )
}

write_comparison <- function(result, out_dir) {
  destination <- .safe_output_dir(out_dir)
  if (!isTRUE(destination$ok)) {
    return(destination)
  }
  json_path <- file.path(destination$path, "result.json")
  text_path <- file.path(destination$path, "summary.txt")
  html_path <- file.path(destination$path, "report.html")
  writeLines(to_json(result), json_path, useBytes = TRUE)
  writeLines(render_summary(result), text_path, useBytes = TRUE)
  writeLines(render_html(result), html_path, useBytes = TRUE)
  list(ok = TRUE, directory = destination$path, json = json_path, summary = text_path, html = html_path)
}
