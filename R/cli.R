.cli_help <- function() {
  paste(
    "cohortshift — compare aggregate study and target subgroup tables",
    "",
    "Usage:",
    "  Rscript bin/cohortshift.R help",
    "  Rscript bin/cohortshift.R validate <marginals.csv> [--joints <joints.csv>]",
    "  Rscript bin/cohortshift.R compare <study.csv> <target.csv> [--joints-study <joints.csv>] [--joints-target <joints.csv>] [--out <directory>]",
    "",
    "validate checks schema version 1, nonnegative counts, explicit missingness,",
    "mutually exclusive age and severity strata, and, when a joint file is given,",
    "that the joint maps the marginal table.",
    "",
    "compare writes result.json and summary.txt. Marginal gaps are study share",
    "minus target share, in percentage points. An intersection is identified,",
    "bounded from the margins, or unavailable. JSON is the machine-readable",
    "result. Explanations go to standard error.",
    "",
    "Exit codes:",
    "  0  success",
    "  2  the command line could not be read",
    "  3  a table is invalid",
    "  4  the tables are valid but cannot be compared",
    sep = "\n"
  )
}

.parse_cli <- function(args) {
  if (length(args) == 0L) {
    return(list(command = "help", positionals = character(), flags = list()))
  }
  command <- args[[1L]]
  if (command %in% c("help", "--help", "-h")) {
    return(list(command = "help", positionals = character(), flags = list()))
  }
  rest <- if (length(args) > 1L) args[-1L] else character()
  positionals <- character()
  flags <- list()
  i <- 1L
  while (i <= length(rest)) {
    item <- rest[[i]]
    if (startsWith(item, "--")) {
      key <- sub("^--", "", item)
      if (!nzchar(key) || grepl("[^A-Za-z0-9-]", key)) {
        return(list(error = sprintf("Unreadable option %s.", item)))
      }
      if (i == length(rest)) {
        return(list(error = sprintf("Option --%s needs a value.", key)))
      }
      flags[[key]] <- rest[[i + 1L]]
      i <- i + 2L
    } else {
      positionals <- c(positionals, item)
      i <- i + 1L
    }
  }
  list(command = command, positionals = positionals, flags = flags)
}

.print_errors <- function(result) {
  message("cohortshift: the aggregate table was rejected.")
  for (err in result$errors) {
    where <- if (is.null(err$location)) "" else sprintf(" (%s)", err$location)
    message(sprintf("[%s]%s %s", err$category, where, err$message))
    message(sprintf("Hint: %s", err$hint))
  }
}

.run_validate_command <- function(parsed) {
  if (length(parsed$positionals) != 1L) {
    message("cohortshift: validate needs exactly one marginal CSV.")
    message(.cli_help())
    return(2L)
  }
  unknown <- setdiff(names(parsed$flags), "joints")
  if (length(unknown)) {
    message(sprintf("cohortshift: unknown option --%s.", unknown[[1L]]))
    return(2L)
  }
  marginal <- validate_marginal_file(parsed$positionals[[1L]])
  if (!isTRUE(marginal$ok)) {
    .print_errors(marginal)
    cat(to_json(marginal), "\n")
    return(3L)
  }
  if (!is.null(parsed$flags$joints)) {
    joint <- validate_joint_file(parsed$flags$joints, marginal = marginal)
    if (!isTRUE(joint$ok)) {
      .print_errors(joint)
      cat(to_json(joint), "\n")
      return(3L)
    }
    marginal$joint <- joint
    marginal$joint$data <- NULL
  }
  marginal$data <- NULL
  cat(to_json(marginal), "\n")
  0L
}

.run_compare_command <- function(parsed) {
  if (length(parsed$positionals) != 2L) {
    message("cohortshift: compare needs a study CSV and a target CSV.")
    message(.cli_help())
    return(2L)
  }
  unknown <- setdiff(names(parsed$flags), c("joints-study", "joints-target", "out"))
  if (length(unknown)) {
    message(sprintf("cohortshift: unknown option --%s.", unknown[[1L]]))
    return(2L)
  }
  result <- compare_files(
    parsed$positionals[[1L]],
    parsed$positionals[[2L]],
    study_joint_path = parsed$flags[["joints-study"]],
    target_joint_path = parsed$flags[["joints-target"]]
  )
  if (!isTRUE(result$ok)) {
    if (!is.null(result$errors)) {
      .print_errors(result)
      cat(to_json(result), "\n")
      return(3L)
    }
    message(sprintf("cohortshift: comparison refused [%s]. %s", result$category, result$message))
    message(sprintf("Hint: %s", result$hint))
    cat(to_json(result), "\n")
    return(4L)
  }
  out_dir <- if (is.null(parsed$flags$out)) "out/cohortshift" else parsed$flags$out
  written <- write_comparison(result, out_dir)
  if (!isTRUE(written$ok)) {
    message(sprintf("cohortshift: %s", written$message))
    message(sprintf("Hint: %s", written$hint))
    cat(to_json(written), "\n")
    return(3L)
  }
  cat(to_json(list(ok = TRUE, output = written$directory, json = written$json, summary = written$summary)), "\n")
  0L
}

run_cohortshift <- function(args) {
  parsed <- .parse_cli(args)
  if (!is.null(parsed$error)) {
    message(paste("cohortshift:", parsed$error))
    message(.cli_help())
    return(2L)
  }
  if (parsed$command == "help") {
    cat(.cli_help(), "\n")
    return(0L)
  }
  if (parsed$command == "validate") {
    return(.run_validate_command(parsed))
  }
  if (parsed$command == "compare") {
    return(.run_compare_command(parsed))
  }
  message(sprintf("cohortshift: unknown command %s.", parsed$command))
  message(.cli_help())
  2L
}
