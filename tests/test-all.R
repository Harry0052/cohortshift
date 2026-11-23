args_all <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args_all, value = TRUE)
if (length(file_arg) != 1L) {
  stop("Run tests with Rscript tests/test-all.R")
}
root <- normalizePath(file.path(dirname(sub("^--file=", "", file_arg[[1L]])), ".."))
sources <- c(
  "limits.R", "errors.R", "json.R", "bins.R", "schema.R",
  "margins.R", "bounds.R", "compare.R", "report.R", "cli.R"
)
for (name in sources) {
  source(file.path(root, "R", name), local = FALSE)
}

failures <- character()
pass <- 0L
check <- function(expr, label) {
  value <- tryCatch(expr, error = function(err) err)
  if (inherits(value, "error") || !isTRUE(value)) {
    detail <- if (inherits(value, "error")) conditionMessage(value) else "was not TRUE"
    failures <<- c(failures, sprintf("%s (%s)", label, detail))
  } else {
    pass <<- pass + 1L
  }
}

has_category <- function(result, category) {
  any(vapply(result$errors, function(err) identical(err$category, category), logical(1)))
}
has_text <- function(result, pattern) {
  any(vapply(result$errors, function(err) grepl(pattern, err$message), logical(1)))
}

fixture <- function(...) file.path(root, "inst", "fixtures", ...)
study <- validate_marginal_file(fixture("proof", "study_marginals.csv"))
target <- validate_marginal_file(fixture("proof", "target_marginals.csv"))
check(isTRUE(study$ok), "study marginals are valid")
check(isTRUE(target$ok), "target marginals are valid")
check(identical(study$population, "study"), "study population label")
check(identical(sum(study$data$count[study$data$variable == "age"]), 100), "study age counts sum to 100")

study_joint <- validate_joint_file(fixture("proof", "study_joint.csv"), study)
target_joint <- validate_joint_file(fixture("proof", "target_joint.csv"), target)
check(isTRUE(study_joint$ok), "study joint reproduces margins")
check(isTRUE(target_joint$ok), "target joint reproduces margins")
zero_cell <- study_joint$data$count[study_joint$data$stratum_a == "age_65_plus" & study_joint$data$stratum_b == "severe"]
check(identical(zero_cell, 0), "exact study intersection keeps the observed zero")

suppressed <- validate_joint_file(fixture("status", "suppressed_joint.csv"), study)
check(isTRUE(suppressed$ok), "suppressed joint cell is accepted and is not rewritten")
suppressed_count <- suppressed$data$count[suppressed$data$stratum_a == "age_65_plus" & suppressed$data$stratum_b == "severe"]
check(length(suppressed_count) == 1L && is.na(suppressed_count), "suppressed cell has no numeric count")

overlap <- validate_marginal_file(fixture("invalid", "overlapping_age.csv"))
check(!isTRUE(overlap$ok) && has_category(overlap, "partition") && has_text(overlap, "overlap"), "overlapping age bands are rejected")

unsupported <- validate_marginal_file(fixture("invalid", "unsupported_age.csv"))
check(!isTRUE(unsupported$ok) && has_text(unsupported, "does not interpolate"), "unsupported age bucket is rejected")

negative <- validate_marginal_file(fixture("invalid", "negative_count.csv"))
check(!isTRUE(negative$ok) && has_category(negative, "bounds") && has_text(negative, "negative"), "negative count is rejected")

row_level <- validate_marginal_file(fixture("invalid", "row_level.csv"))
check(!isTRUE(row_level$ok) && has_category(row_level, "row_level"), "individual identifier column is rejected")

mismatch <- validate_joint_file(fixture("invalid", "joint_mismatch.csv"), study)
check(!isTRUE(mismatch$ok) && has_category(mismatch, "joint") && has_text(mismatch, "severe"), "joint that misses the severe margin is rejected")

missing_file <- validate_marginal_file(fixture("proof", "no-such.csv"))
check(!isTRUE(missing_file$ok) && has_category(missing_file, "schema"), "missing file is rejected")

big <- tempfile(fileext = ".csv")
writeLines(c("schema_version", paste(rep("x", .CS_MAX_BYTES), collapse = "")), big)
oversize <- validate_marginal_file(big)
check(!isTRUE(oversize$ok) && has_category(oversize, "resource"), "oversized file is rejected")
unlink(big)

manifest_path <- fixture("manifest.json")
manifest <- paste(readLines(manifest_path, warn = FALSE), collapse = "\n")
for (rel in c(
  "proof/study_marginals.csv",
  "proof/target_marginals.csv",
  "proof/study_joint.csv",
  "proof/target_joint.csv",
  "invalid/overlapping_age.csv",
  "invalid/joint_mismatch.csv",
  "status/suppressed_joint.csv"
)) {
  digest <- unname(tools::md5sum(file.path(root, "inst", "fixtures", rel)))
  check(grepl(digest, manifest, fixed = TRUE), paste("manifest lists", rel))
}

cli <- function(args) {
  err <- tempfile()
  out <- suppressWarnings(system2(
    "Rscript",
    c(file.path(root, "bin", "cohortshift.R"), args),
    stdout = TRUE,
    stderr = err
  ))
  status <- attr(out, "status")
  if (is.null(status)) status <- 0L
  list(status = status, stdout = paste(out, collapse = "\n"), stderr = paste(readLines(err, warn = FALSE), collapse = "\n"))
}

valid_cli <- cli(c("validate", fixture("proof", "study_marginals.csv")))
check(valid_cli$status == 0L && grepl("\"ok\":true", valid_cli$stdout, fixed = TRUE), "CLI accepts the valid fixture")
check(!grepl("rejected", valid_cli$stderr), "valid fixture does not write a rejection")

invalid_cli <- cli(c("validate", fixture("invalid", "overlapping_age.csv")))
check(invalid_cli$status == 3L && grepl("\"ok\":false", invalid_cli$stdout, fixed = TRUE), "CLI rejects overlapping ages")
check(grepl("overlap", invalid_cli$stderr) && grepl("Hint:", invalid_cli$stderr), "CLI explains the overlap on stderr")

joint_cli <- cli(c(
  "validate", fixture("proof", "study_marginals.csv"),
  "--joints", fixture("invalid", "joint_mismatch.csv")
))
check(joint_cli$status == 3L && grepl("joint", joint_cli$stderr), "CLI rejects the mismatched joint")

help_cli <- cli("help")
check(help_cli$status == 0L && grepl("Usage:", help_cli$stdout), "help exits 0")
usage_cli <- cli("not-a-command")
check(usage_cli$status == 2L, "unknown command exits 2")

near <- function(actual, expected) {
  isTRUE(all.equal(actual, expected, tolerance = 0))
}
find_margin <- function(result, variable, stratum) {
  for (row in result$marginals) {
    if (identical(row$variable, variable) && identical(row$stratum, stratum)) {
      return(row)
    }
  }
  NULL
}
find_cell <- function(result, age, severity) {
  for (row in result$intersections) {
    if (identical(row$stratum_a, age) && identical(row$stratum_b, severity)) {
      return(row)
    }
  }
  NULL
}

withheld <- compare_files(fixture("proof", "study_marginals.csv"), fixture("proof", "target_marginals.csv"))
check(isTRUE(withheld$ok), "withheld-joint comparison runs")
age_gap <- find_margin(withheld, "age", "age_65_plus")
severe_gap <- find_margin(withheld, "severity", "severe")
check(near(age_gap$difference_pp, -20) && near(severe_gap$difference_pp, -20), "marginal gaps are -20 percentage points")
check(near(find_margin(withheld, "age", "under_65")$difference_pp, 20), "under-65 gap is +20")
check(near(find_margin(withheld, "severity", "not_severe")$difference_pp, 20), "not-severe gap is +20")
headline <- find_cell(withheld, "age_65_plus", "severe")
check(identical(headline$evidence, "bounded"), "withheld intersection is bounded")
check(is.null(headline$study_count) && is.null(headline$difference_pp), "withheld intersection has no point count")
check(near(headline$study_count_low, 0) && near(headline$study_count_high, 20), "study joint bound is 0 to 20")
check(near(headline$target_count_low, 0) && near(headline$target_count_high, 40), "target joint bound is 0 to 40")
check(near(headline$difference_pp_low, -40) && near(headline$difference_pp_high, 20), "joint gap bound is -40 to +20")
check(near(withheld$coverage$requested, 8) && near(withheld$coverage$identified, 4) && near(withheld$coverage$share, 0.5), "withheld coverage is 1/2")
complement <- find_cell(withheld, "under_65", "not_severe")
check(near(complement$study_count_low, 50) && near(complement$study_count_high, 70), "complement study bound")
check(near(complement$difference_pp_low, 0) && near(complement$difference_pp_high, 60), "complement gap bound")

exact <- compare_files(
  fixture("proof", "study_marginals.csv"),
  fixture("proof", "target_marginals.csv"),
  fixture("proof", "study_joint.csv"),
  fixture("proof", "target_joint.csv")
)
exact_cell <- find_cell(exact, "age_65_plus", "severe")
check(identical(exact_cell$evidence, "identified"), "exact joint is identified")
check(near(exact_cell$study_count, 0) && near(exact_cell$target_count, 25), "exact joint counts are 0 and 25")
check(near(exact_cell$difference_pp, -25), "exact joint gap is -25")
check(identical(exact_cell$study_count_status, "observed_zero"), "study zero stays an observed zero")
check(near(exact$coverage$identified, 8) && near(exact$coverage$share, 1), "exact coverage is 1")
check(near(find_cell(exact, "age_65_plus", "not_severe")$difference_pp, 5), "age 65+ and not severe gap is 5")
check(near(find_cell(exact, "under_65", "severe")$difference_pp, 5), "under 65 and severe gap is 5")
check(near(find_cell(exact, "under_65", "not_severe")$difference_pp, 15), "under 65 and not severe gap is 15")

suppressed_cmp <- compare_files(
  fixture("proof", "study_marginals.csv"),
  fixture("proof", "target_marginals.csv"),
  fixture("status", "suppressed_joint.csv"),
  NULL
)
suppressed_cell <- find_cell(suppressed_cmp, "age_65_plus", "severe")
check(identical(suppressed_cell$study_count_status, "suppressed"), "suppressed cell is not rewritten")
check(!identical(suppressed_cell$study_count_status, "observed_zero"), "suppressed cell is not an observed zero")
check(is.null(suppressed_cell$study_count), "suppressed cell has no numeric count")
check(identical(suppressed_cell$evidence, "bounded"), "suppressed cell keeps the marginal bounds")
check(near(suppressed_cell$difference_pp_low, -40) && near(suppressed_cell$difference_pp_high, 20), "suppressed cell does not collapse the bound")

severity_mismatch <- compare_files(
  fixture("proof", "study_marginals.csv"),
  fixture("invalid", "target_other_severity.csv")
)
check(!isTRUE(severity_mismatch$ok) && identical(severity_mismatch$category, "definition"), "different severity definitions are refused")
window_mismatch <- compare_files(
  fixture("proof", "study_marginals.csv"),
  fixture("invalid", "target_other_window.csv")
)
check(!isTRUE(window_mismatch$ok) && identical(window_mismatch$category, "definition"), "different measurement windows are refused")
bad_joint <- compare_files(
  fixture("proof", "study_marginals.csv"),
  fixture("proof", "target_marginals.csv"),
  fixture("invalid", "joint_mismatch.csv"),
  NULL
)
check(!isTRUE(bad_joint$ok) && has_category(bad_joint, "joint"), "compare rejects a joint that misses its margin")

summary_text <- render_summary(withheld)
check(grepl("Methodology:", summary_text, fixed = TRUE) && grepl("not an observed gap", summary_text, fixed = TRUE), "summary states methodology and that a bound is not observed")
check(grepl("-40", summary_text, fixed = TRUE) && grepl("synthetic:study-margins-v1", summary_text, fixed = TRUE), "summary keeps the bound and the source reference")

out_dir <- tempfile("cohortshift-proof-")
written <- write_comparison(withheld, out_dir)
proof_json <- paste(readLines(written$json, warn = FALSE), collapse = "\n")
check(isTRUE(written$ok) && grepl("\"difference_pp\":-20", proof_json, fixed = TRUE), "JSON export contains the marginal gap")
check(grepl("\"difference_pp_low\":-40", proof_json, fixed = TRUE) && grepl("\"difference_pp_high\":20", proof_json, fixed = TRUE), "JSON export contains the joint gap bounds")
escaped <- write_comparison(withheld, file.path(out_dir, "..", "escape"))
check(!isTRUE(escaped$ok) && identical(escaped$category, "resource"), "output path cannot climb out with ..")

compare_cli <- cli(c(
  "compare",
  fixture("proof", "study_marginals.csv"),
  fixture("proof", "target_marginals.csv"),
  "--out",
  tempfile("cohortshift-cli-")
))
check(compare_cli$status == 0L && grepl("\"ok\":true", compare_cli$stdout, fixed = TRUE), "CLI compare writes the proof case")
exact_cli <- cli(c(
  "compare",
  fixture("proof", "study_marginals.csv"),
  fixture("proof", "target_marginals.csv"),
  "--joints-study", fixture("proof", "study_joint.csv"),
  "--joints-target", fixture("proof", "target_joint.csv"),
  "--out", tempfile("cohortshift-exact-")
))
check(exact_cli$status == 0L, "CLI compare accepts the exact joint")
exact_dir <- sub(".*\"output\":\"([^\"]+)\".*", "\\1", exact_cli$stdout)
exact_body <- paste(readLines(file.path(exact_dir, "result.json"), warn = FALSE), collapse = "\n")
check(grepl("\"difference_pp\":-25", exact_body, fixed = TRUE) && grepl("observed_zero", exact_body, fixed = TRUE), "CLI exact joint reports -25 and an observed zero")
refuse_cli <- cli(c(
  "compare",
  fixture("proof", "study_marginals.csv"),
  fixture("invalid", "target_other_severity.csv"),
  "--out",
  tempfile("cohortshift-refuse-")
))
check(refuse_cli$status == 4L && grepl("refused", refuse_cli$stderr), "CLI refuses mismatched severity definitions")

cat(sprintf("Passed %s checks\n", pass))
if (length(failures)) {
  cat(paste(failures, collapse = "\n"), "\n", sep = "")
  quit(status = 1L)
}
quit(status = 0L)
