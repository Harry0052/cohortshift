.read_csv_bounded <- function(path) {
  if (!is.character(path) || length(path) != 1L || !nzchar(path)) {
    return(.cs_fail(list(.cs_error(
      "schema", "A single CSV path is required.", "Pass the path of an aggregate table."
    ))))
  }
  if (!file.exists(path) || dir.exists(path)) {
    return(.cs_fail(list(.cs_error(
      "schema", sprintf("File not found: %s.", path),
      "Check the path. CohortShift reads local CSV files only.", path
    ))))
  }
  info <- file.info(path)
  if (is.na(info$size) || info$size > .CS_MAX_BYTES) {
    return(.cs_fail(list(.cs_error(
      "resource",
      sprintf("File %s exceeds the %s byte limit.", path, .CS_MAX_BYTES),
      "Split the table or remove columns that are not part of the aggregate schema.",
      path
    ))))
  }
  raw <- tryCatch(
    utils::read.csv(
      path,
      stringsAsFactors = FALSE,
      colClasses = "character",
      na.strings = character(0),
      check.names = FALSE,
      comment.char = "",
      fileEncoding = "UTF-8"
    ),
    error = function(err) err
  )
  if (inherits(raw, "error")) {
    return(.cs_fail(list(.cs_error(
      "schema", sprintf("Could not read CSV: %s", conditionMessage(raw)),
      "Provide a UTF-8 CSV with a header row.", path
    ))))
  }
  if (ncol(raw) == 0L || (nrow(raw) == 0L && length(names(raw)) == 0L)) {
    return(.cs_fail(list(.cs_error(
      "schema", "The CSV has no header.", "Use the version 1 aggregate columns.", path
    ))))
  }
  names(raw) <- trimws(names(raw))
  if (nrow(raw) > .CS_MAX_ROWS) {
    return(.cs_fail(list(.cs_error(
      "bounds",
      sprintf("The CSV has %s rows. The limit is %s.", nrow(raw), .CS_MAX_ROWS),
      "Aggregate tables are stratum counts, not individual records.",
      path
    ))))
  }
  if (nrow(raw) < 1L) {
    return(.cs_fail(list(.cs_error(
      "schema", "The CSV has a header and no rows.",
      "Include at least one stratum row.", path
    ))))
  }
  list(ok = TRUE, data = raw, path = path)
}

.column_errors <- function(raw, required) {
  errors <- list()
  names_now <- names(raw)
  if (any(duplicated(names_now))) {
    errors[[length(errors) + 1L]] <- .cs_error(
      "schema",
      sprintf("Column %s is duplicated.", names_now[duplicated(names_now)][[1L]]),
      "Keep one header cell per column."
    )
  }
  lower <- tolower(names_now)
  blocked <- lower[lower %in% .CS_ROW_LEVEL_COLUMNS]
  if (length(blocked)) {
    errors[[length(errors) + 1L]] <- .cs_error(
      "row_level",
      sprintf(
        "Column %s is an individual identifier. This release accepts aggregate counts only.",
        blocked[[1L]]
      ),
      "Remove individual-level columns and provide one row per stratum."
    )
  }
  missing <- setdiff(required, names_now)
  if (length(missing)) {
    errors[[length(errors) + 1L]] <- .cs_error(
      "schema",
      sprintf("Missing required column %s.", paste(missing, collapse = ", ")),
      sprintf("Version 1 requires these columns: %s.", paste(required, collapse = ", "))
    )
  }
  extra <- setdiff(names_now, required)
  extra <- extra[!tolower(extra) %in% .CS_ROW_LEVEL_COLUMNS]
  if (length(extra)) {
    errors[[length(errors) + 1L]] <- .cs_error(
      "schema",
      sprintf("Unexpected column %s.", paste(extra, collapse = ", ")),
      "Remove columns that are not in the version 1 schema."
    )
  }
  errors
}

.token <- function(value, pattern, label, location, category = "schema") {
  if (length(value) != 1L || is.na(value) || !nzchar(value)) {
    return(.cs_field(location, category, sprintf("%s is required.", label), sprintf("Fill in %s.", label)))
  }
  if (nchar(value) > .CS_MAX_FIELD) {
    return(.cs_field(
      location, "bounds",
      sprintf("%s is longer than %s characters.", label, .CS_MAX_FIELD),
      "Shorten the field."
    ))
  }
  if (!grepl(pattern, value)) {
    return(.cs_field(
      location, category,
      sprintf("%s has unsupported characters: %s.", label, value),
      "Use letters, digits, and the punctuation shown in the fixture."
    ))
  }
  NULL
}

.parse_whole_count <- function(text, missingness, location) {
  if (missingness %in% c("suppressed", "absent")) {
    if (nzchar(text)) {
      return(list(error = .cs_field(
        location, "missingness",
        sprintf(
          "missingness %s cannot carry count %s. A suppressed or absent cell is not an observed count, including zero.",
          missingness, text
        ),
        "Leave count blank when the cell is suppressed or absent. Use count 0 only when the source observed zero."
      )))
    }
    return(list(value = NA_real_))
  }
  if (!nzchar(text)) {
    return(list(error = .cs_field(
      location, "missingness",
      "missingness observed requires a count. A blank count is not treated as zero.",
      "Enter the observed nonnegative count, or change missingness to suppressed or absent."
    )))
  }
  if (grepl("^-", text)) {
    return(list(error = .cs_field(
      location, "bounds",
      sprintf("count %s is negative. Counts are nonnegative.", text),
      "Use a blank count with missingness suppressed or absent when the count is unknown."
    )))
  }
  if (!grepl("^[0-9]+$", text)) {
    return(list(error = .cs_field(
      location, "bounds",
      sprintf("count %s is not a nonnegative integer.", text),
      "Use a whole number of people, with no decimal point."
    )))
  }
  value <- as.numeric(text)
  if (!is.finite(value) || value > .CS_MAX_DENOMINATOR) {
    return(list(error = .cs_field(
      location, "bounds",
      sprintf("count %s exceeds the limit of %s.", text, .CS_MAX_DENOMINATOR),
      "Check the units. The count is a number of people in the stratum."
    )))
  }
  list(value = value)
}

.parse_denominator <- function(text, location) {
  if (!grepl("^[0-9]+$", text)) {
    return(list(error = .cs_field(
      location, "bounds",
      sprintf("denominator %s is not a positive integer.", text),
      "Use the number of people in the population for this table."
    )))
  }
  value <- as.numeric(text)
  if (!is.finite(value) || value < 1 || value > .CS_MAX_DENOMINATOR) {
    return(list(error = .cs_field(
      location, "bounds",
      sprintf("denominator must be from 1 to %s.", .CS_MAX_DENOMINATOR),
      "CohortShift divides counts by this population denominator."
    )))
  }
  list(value = value)
}

.normalize_marginal <- function(raw) {
  errors <- .column_errors(raw, .CS_MARGINAL_COLUMNS)
  if (length(errors)) {
    return(.cs_fail(errors))
  }
  n <- nrow(raw)
  count <- rep(NA_real_, n)
  denominator <- rep(NA_real_, n)
  for (i in seq_len(n)) {
    location <- sprintf("row %s", i + 1L)
    row_errors <- list()
    version <- .token(raw$schema_version[[i]], "^1$", "schema_version", location)
    if (!is.null(version)) {
      row_errors[[length(row_errors) + 1L]] <- version
    }
    population <- .token(raw$population[[i]], "^[A-Za-z][A-Za-z0-9_-]*$", "population", location)
    if (!is.null(population)) row_errors[[length(row_errors) + 1L]] <- population
    variable <- .token(raw$variable[[i]], "^(age|severity)$", "variable", location)
    if (!is.null(variable)) row_errors[[length(row_errors) + 1L]] <- variable
    stratum <- .token(raw$stratum[[i]], "^[A-Za-z0-9_+.-]+$", "stratum", location)
    if (!is.null(stratum)) row_errors[[length(row_errors) + 1L]] <- stratum
    missingness <- .token(
      raw$missingness[[i]], "^(observed|suppressed|absent)$", "missingness", location, "missingness"
    )
    if (!is.null(missingness)) row_errors[[length(row_errors) + 1L]] <- missingness
    window <- .token(
      raw$measurement_window[[i]], "^[A-Za-z0-9._:-]+$", "measurement_window", location
    )
    if (!is.null(window)) row_errors[[length(row_errors) + 1L]] <- window
    definition <- .token(raw$definition_id[[i]], "^[A-Za-z0-9._:-]+$", "definition_id", location)
    if (!is.null(definition)) row_errors[[length(row_errors) + 1L]] <- definition
    table_id <- .token(raw$table_id[[i]], "^[A-Za-z0-9._:-]+$", "table_id", location)
    if (!is.null(table_id)) row_errors[[length(row_errors) + 1L]] <- table_id
    source_ref <- .token(raw$source_ref[[i]], "^[A-Za-z0-9._:+/-]+$", "source_ref", location)
    if (!is.null(source_ref)) row_errors[[length(row_errors) + 1L]] <- source_ref
    if (!is.null(missingness)) {
      errors <- c(errors, row_errors)
      next
    }
    parsed_count <- .parse_whole_count(raw$count[[i]], raw$missingness[[i]], location)
    if (!is.null(parsed_count$error)) row_errors[[length(row_errors) + 1L]] <- parsed_count$error
    parsed_den <- .parse_denominator(raw$denominator[[i]], location)
    if (!is.null(parsed_den$error)) row_errors[[length(row_errors) + 1L]] <- parsed_den$error
    if (is.null(parsed_count$error) && is.null(parsed_den$error) &&
          raw$missingness[[i]] == "observed" && parsed_count$value > parsed_den$value) {
      row_errors[[length(row_errors) + 1L]] <- .cs_field(
        location, "bounds",
        sprintf("count %s is larger than denominator %s.", raw$count[[i]], raw$denominator[[i]]),
        "The stratum count cannot exceed the population denominator."
      )
    }
    if (length(row_errors) == 0L) {
      count[[i]] <- parsed_count$value
      denominator[[i]] <- parsed_den$value
    }
    errors <- c(errors, row_errors)
  }
  if (length(errors)) {
    return(.cs_fail(errors))
  }
  data <- data.frame(
    schema_version = raw$schema_version,
    population = raw$population,
    variable = raw$variable,
    stratum = raw$stratum,
    count = count,
    denominator = denominator,
    table_id = raw$table_id,
    source_ref = raw$source_ref,
    missingness = raw$missingness,
    measurement_window = raw$measurement_window,
    definition_id = raw$definition_id,
    stringsAsFactors = FALSE
  )
  table_errors <- .table_constants(data)
  if (length(table_errors)) {
    return(.cs_fail(table_errors))
  }
  part_errors <- list()
  for (variable in unique(data$variable)) {
    part_errors <- c(part_errors, .check_variable_partition(data[data$variable == variable, , drop = FALSE]))
  }
  age_rows <- data[data$variable == "age", , drop = FALSE]
  if (nrow(age_rows) && any(age_rows$definition_id != "age.exact.v1")) {
    part_errors[[length(part_errors) + 1L]] <- .cs_error(
      "definition",
      "Age rows must use definition_id age.exact.v1.",
      "Age comparisons use the exact buckets in that definition and do not interpolate."
    )
  }
  if (length(part_errors)) {
    return(.cs_fail(part_errors))
  }
  list(ok = TRUE, data = data)
}

.table_constants <- function(data) {
  errors <- list()
  if (length(unique(data$population)) != 1L) {
    errors[[length(errors) + 1L]] <- .cs_error(
      "schema",
      "A table contains more than one population.",
      "Write the study and the target as separate CSV files."
    )
  }
  if (length(unique(data$table_id)) != 1L) {
    errors[[length(errors) + 1L]] <- .cs_error(
      "schema",
      "A table contains more than one table_id.",
      "Use one table_id so the export can cite a single source table."
    )
  }
  if (length(unique(data$measurement_window)) != 1L) {
    errors[[length(errors) + 1L]] <- .cs_error(
      "definition",
      "Rows in one table use different measurement_window values.",
      "Use one measurement window per table. CohortShift does not align different windows."
    )
  }
  if (length(unique(data$denominator)) != 1L) {
    errors[[length(errors) + 1L]] <- .cs_error(
      "bounds",
      "Rows in one table use different denominators.",
      "Every stratum in a population table must share that population's denominator."
    )
  }
  if (length(unique(data$source_ref)) != 1L) {
    errors[[length(errors) + 1L]] <- .cs_error(
      "schema",
      "Rows in one table use different source_ref values.",
      "Cite one source reference per table."
    )
  }
  split_def <- tapply(data$definition_id, data$variable, function(values) length(unique(values)) != 1L)
  if (any(split_def)) {
    errors[[length(errors) + 1L]] <- .cs_error(
      "definition",
      "One variable uses more than one definition_id.",
      "Keep a single definition_id for each variable."
    )
  }
  errors
}

.file_digest <- function(path) {
  if (requireNamespace("tools", quietly = TRUE)) {
    unname(tools::md5sum(path))
  } else {
    NA_character_
  }
}

.summary_from <- function(data, path, kind) {
  list(
    ok = TRUE,
    schema_version = 1L,
    kind = kind,
    path = path,
    rows = nrow(data),
    population = data$population[[1L]],
    table_id = data$table_id[[1L]],
    digest = .file_digest(path)
  )
}

validate_marginal_file <- function(path) {
  loaded <- .read_csv_bounded(path)
  if (!isTRUE(loaded$ok)) {
    return(loaded)
  }
  parsed <- .normalize_marginal(loaded$data)
  if (!isTRUE(parsed$ok)) {
    return(parsed)
  }
  result <- .summary_from(parsed$data, loaded$path, "marginal")
  result$data <- parsed$data
  result
}

.normalize_joint <- function(raw) {
  errors <- .column_errors(raw, .CS_JOINT_COLUMNS)
  if (length(errors)) {
    return(.cs_fail(errors))
  }
  n <- nrow(raw)
  count <- rep(NA_real_, n)
  denominator <- rep(NA_real_, n)
  for (i in seq_len(n)) {
    location <- sprintf("row %s", i + 1L)
    row_errors <- list()
    checks <- list(
      .token(raw$schema_version[[i]], "^1$", "schema_version", location),
      .token(raw$population[[i]], "^[A-Za-z][A-Za-z0-9_-]*$", "population", location),
      .token(raw$variable_a[[i]], "^age$", "variable_a", location),
      .token(raw$variable_b[[i]], "^severity$", "variable_b", location),
      .token(raw$stratum_a[[i]], "^[A-Za-z0-9_+.-]+$", "stratum_a", location),
      .token(raw$stratum_b[[i]], "^[A-Za-z0-9_+.-]+$", "stratum_b", location),
      .token(raw$missingness[[i]], "^(observed|suppressed|absent)$", "missingness", location, "missingness"),
      .token(raw$measurement_window[[i]], "^[A-Za-z0-9._:-]+$", "measurement_window", location),
      .token(raw$definition_id_a[[i]], "^age\\.exact\\.v1$", "definition_id_a", location, "definition"),
      .token(raw$definition_id_b[[i]], "^severity\\.binary\\.v[12]$", "definition_id_b", location, "definition"),
      .token(raw$table_id[[i]], "^[A-Za-z0-9._:-]+$", "table_id", location),
      .token(raw$source_ref[[i]], "^[A-Za-z0-9._:+/-]+$", "source_ref", location),
      .token(raw$margin_table_id[[i]], "^[A-Za-z0-9._:-]+$", "margin_table_id", location)
    )
    for (item in checks) {
      if (!is.null(item)) row_errors[[length(row_errors) + 1L]] <- item
    }
    missingness_ok <- grepl("^(observed|suppressed|absent)$", raw$missingness[[i]])
    if (!missingness_ok) {
      errors <- c(errors, row_errors)
      next
    }
    parsed_count <- .parse_whole_count(raw$count[[i]], raw$missingness[[i]], location)
    if (!is.null(parsed_count$error)) row_errors[[length(row_errors) + 1L]] <- parsed_count$error
    parsed_den <- .parse_denominator(raw$denominator[[i]], location)
    if (!is.null(parsed_den$error)) row_errors[[length(row_errors) + 1L]] <- parsed_den$error
    if (is.null(parsed_count$error) && is.null(parsed_den$error) &&
          raw$missingness[[i]] == "observed" && parsed_count$value > parsed_den$value) {
      row_errors[[length(row_errors) + 1L]] <- .cs_field(
        location, "bounds",
        sprintf("count %s is larger than denominator %s.", raw$count[[i]], raw$denominator[[i]]),
        "A joint cell cannot exceed the population denominator."
      )
    }
    if (length(row_errors) == 0L) {
      count[[i]] <- parsed_count$value
      denominator[[i]] <- parsed_den$value
    }
    errors <- c(errors, row_errors)
  }
  if (length(errors)) {
    return(.cs_fail(errors))
  }
  data <- data.frame(
    schema_version = raw$schema_version,
    population = raw$population,
    variable_a = raw$variable_a,
    stratum_a = raw$stratum_a,
    variable_b = raw$variable_b,
    stratum_b = raw$stratum_b,
    count = count,
    denominator = denominator,
    table_id = raw$table_id,
    source_ref = raw$source_ref,
    missingness = raw$missingness,
    measurement_window = raw$measurement_window,
    definition_id_a = raw$definition_id_a,
    definition_id_b = raw$definition_id_b,
    margin_table_id = raw$margin_table_id,
    stringsAsFactors = FALSE
  )
  if (length(unique(data$population)) != 1L || length(unique(data$table_id)) != 1L ||
        length(unique(data$margin_table_id)) != 1L || length(unique(data$denominator)) != 1L ||
        length(unique(data$measurement_window)) != 1L || length(unique(data$source_ref)) != 1L ||
        length(unique(data$definition_id_a)) != 1L || length(unique(data$definition_id_b)) != 1L) {
    return(.cs_fail(list(.cs_error(
      "schema",
      "A joint table must use one population, table id, margin table, denominator, window, source, and definition pair.",
      "Split mixed joint tables. One joint table maps one pair of marginal definitions."
    ))))
  }
  key <- paste(data$stratum_a, data$stratum_b, sep = "\t")
  if (any(duplicated(key))) {
    return(.cs_fail(list(.cs_error(
      "partition",
      "A joint cell is repeated.",
      "Keep one row for each age stratum and severity stratum pair."
    ))))
  }
  age_errors <- .check_age_strata(unique(data$stratum_a), "joint age strata")
  sev_errors <- .check_severity_strata(
    unique(data$stratum_b), data$definition_id_b[[1L]], "joint severity strata"
  )
  if (length(age_errors) || length(sev_errors)) {
    return(.cs_fail(c(age_errors, sev_errors)))
  }
  list(ok = TRUE, data = data)
}

.joint_against_marginal <- function(joint, marginal) {
  errors <- list()
  if (joint$population[[1L]] != marginal$population[[1L]]) {
    errors[[length(errors) + 1L]] <- .cs_error(
      "schema",
      sprintf(
        "Joint population %s does not match marginal population %s.",
        joint$population[[1L]], marginal$population[[1L]]
      ),
      "Pair each joint table with the marginal table for the same population."
    )
  }
  if (joint$margin_table_id[[1L]] != marginal$table_id[[1L]]) {
    errors[[length(errors) + 1L]] <- .cs_error(
      "schema",
      sprintf(
        "margin_table_id %s does not match marginal table_id %s.",
        joint$margin_table_id[[1L]], marginal$table_id[[1L]]
      ),
      "Set margin_table_id to the table_id of the marginal file this joint maps."
    )
  }
  if (joint$measurement_window[[1L]] != marginal$measurement_window[[1L]]) {
    errors[[length(errors) + 1L]] <- .cs_error(
      "definition",
      "The joint measurement_window differs from the marginal table.",
      "Use the same measurement window. CohortShift does not align different windows."
    )
  }
  if (joint$denominator[[1L]] != marginal$denominator[[1L]]) {
    errors[[length(errors) + 1L]] <- .cs_error(
      "bounds",
      "The joint denominator differs from the marginal denominator.",
      "A joint table has to describe the same population denominator as its margins."
    )
  }
  age_def <- unique(marginal$definition_id[marginal$variable == "age"])
  sev_def <- unique(marginal$definition_id[marginal$variable == "severity"])
  if (length(age_def) != 1L || joint$definition_id_a[[1L]] != age_def) {
    errors[[length(errors) + 1L]] <- .cs_error(
      "definition",
      "The joint age definition does not match the marginal age definition.",
      "Use age.exact.v1 on both files."
    )
  }
  if (length(sev_def) != 1L || joint$definition_id_b[[1L]] != sev_def) {
    errors[[length(errors) + 1L]] <- .cs_error(
      "definition",
      "The joint severity definition does not match the marginal severity definition.",
      "Keep the same severity definition on the joint and the margins."
    )
  }
  age_strata <- marginal$stratum[marginal$variable == "age"]
  sev_strata <- marginal$stratum[marginal$variable == "severity"]
  for (age in age_strata) {
    for (sev in sev_strata) {
      hit <- joint$stratum_a == age & joint$stratum_b == sev
      if (!any(hit)) {
        errors[[length(errors) + 1L]] <- .cs_error(
          "joint",
          sprintf("Joint table is missing cell %s x %s.", age, sev),
          "Include every combination, using missingness suppressed or absent when the source does not give a count. Omit the joint file entirely when no joint was published."
        )
      }
    }
  }
  if (length(errors)) {
    return(errors)
  }
  for (variable in c("age", "severity")) {
    margin_rows <- marginal[marginal$variable == variable, , drop = FALSE]
    for (i in seq_len(nrow(margin_rows))) {
      stratum <- margin_rows$stratum[[i]]
      if (margin_rows$missingness[[i]] != "observed") {
        next
      }
      if (variable == "age") {
        cells <- joint[joint$stratum_a == stratum, , drop = FALSE]
      } else {
        cells <- joint[joint$stratum_b == stratum, , drop = FALSE]
      }
      if (any(cells$missingness != "observed")) {
        observed_sum <- sum(cells$count[cells$missingness == "observed"])
        if (observed_sum > margin_rows$count[[i]]) {
          errors[[length(errors) + 1L]] <- .cs_error(
            "joint",
            sprintf(
              "Observed joint cells for %s stratum %s already sum to %s, above marginal count %s.",
              variable, stratum,
              format(observed_sum, scientific = FALSE, trim = TRUE),
              format(margin_rows$count[[i]], scientific = FALSE, trim = TRUE)
            ),
            "A partial joint still cannot exceed the declared marginal count."
          )
        }
        next
      }
      joint_sum <- sum(cells$count)
      if (!isTRUE(all.equal(joint_sum, margin_rows$count[[i]]))) {
        errors[[length(errors) + 1L]] <- .cs_error(
          "joint",
          sprintf(
            "Joint table %s does not reproduce marginal %s for %s stratum %s: joint sum %s, marginal count %s.",
            joint$table_id[[1L]], marginal$table_id[[1L]], variable, stratum,
            format(joint_sum, scientific = FALSE, trim = TRUE),
            format(margin_rows$count[[i]], scientific = FALSE, trim = TRUE)
          ),
          "Check the joint cells against both margins, or omit the joint file."
        )
      }
    }
  }
  errors
}

validate_joint_file <- function(path, marginal = NULL) {
  loaded <- .read_csv_bounded(path)
  if (!isTRUE(loaded$ok)) {
    return(loaded)
  }
  parsed <- .normalize_joint(loaded$data)
  if (!isTRUE(parsed$ok)) {
    return(parsed)
  }
  if (!is.null(marginal)) {
    if (!isTRUE(marginal$ok)) {
      return(marginal)
    }
    linked <- .joint_against_marginal(parsed$data, marginal$data)
    if (length(linked)) {
      return(.cs_fail(linked))
    }
  }
  result <- .summary_from(parsed$data, loaded$path, "joint")
  result$data <- parsed$data
  result
}
