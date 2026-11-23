.METHODOLOGY <- paste(
  "Shares are the stratum count divided by that population's denominator.",
  "The marginal gap is the study share minus the target share, in percentage points.",
  "For an intersection, the feasible count is at least max(0, count A + count B - N)",
  "and at most min(count A, count B). The gap bounds subtract opposite endpoints.",
  "An exact joint count replaces those bounds only when every joint cell is observed",
  "and the cells sum to both declared margins. These figures describe cohort composition.",
  "They are not a treatment effect, not an imputed outcome, and not evidence that a result generalizes."
)

.LIMITATIONS <- c(
  "Aggregate counts only. Individual records are rejected.",
  "An observed zero is a source count of zero. Suppressed, absent, and unevaluable cells are not zeros.",
  "A bounded intersection is the set of counts consistent with the margins. It is not an observed gap.",
  "Equal marginal shares do not imply an equal intersection.",
  "No clinical recommendation and no claim of treatment generalizability is made."
)

.refuse <- function(category, message, hint) {
  list(
    ok = FALSE,
    schema_version = 1L,
    category = category,
    message = message,
    hint = hint
  )
}

.strata_of <- function(data, variable) {
  rows <- data[data$variable == variable, , drop = FALSE]
  rows[order(rows$stratum), , drop = FALSE]
}

.same_strata <- function(study, target, variable) {
  a <- sort(study$stratum[study$variable == variable])
  b <- sort(target$stratum[target$variable == variable])
  identical(a, b)
}

.observed_status <- function(count) {
  if (count == 0) "observed_zero" else "observed_positive"
}

.margins_support_bounds <- function(age_row, severity_row) {
  !is.null(age_row) && !is.null(severity_row) &&
    age_row$missingness == "observed" && severity_row$missingness == "observed"
}

.lookup_margin <- function(data, variable, stratum) {
  hit <- data$variable == variable & data$stratum == stratum
  if (!any(hit)) {
    return(NULL)
  }
  data[which(hit)[[1L]], , drop = FALSE]
}

.joint_is_complete <- function(joint) {
  !is.null(joint) && all(joint$data$missingness == "observed")
}

.joint_cell <- function(joint, age, severity) {
  if (is.null(joint)) {
    return(NULL)
  }
  hit <- joint$data$stratum_a == age & joint$data$stratum_b == severity
  if (!any(hit)) {
    return(NULL)
  }
  joint$data[which(hit)[[1L]], , drop = FALSE]
}

.side_from_joint <- function(joint, age, severity, marginal_low, marginal_high) {
  cell <- .joint_cell(joint, age, severity)
  complete <- .joint_is_complete(joint)
  if (is.null(cell)) {
    return(list(
      count = NULL,
      low = marginal_low,
      high = marginal_high,
      status = "unevaluable",
      exact = FALSE,
      table_id = NULL,
      source_ref = if (is.null(joint)) NULL else joint$data$source_ref[[1L]]
    ))
  }
  if (isTRUE(complete) && cell$missingness == "observed") {
    count <- cell$count
    return(list(
      count = count,
      low = count,
      high = count,
      status = .observed_status(count),
      exact = TRUE,
      table_id = cell$table_id,
      source_ref = cell$source_ref
    ))
  }
  status <- if (cell$missingness == "observed") "unevaluable" else cell$missingness
  list(
    count = NULL,
    low = marginal_low,
    high = marginal_high,
    status = status,
    exact = FALSE,
    table_id = cell$table_id,
    source_ref = cell$source_ref
  )
}

.combine_status <- function(study_status, target_status) {
  if (study_status == "suppressed" || target_status == "suppressed") {
    return("suppressed")
  }
  if (study_status == "absent" || target_status == "absent") {
    return("absent")
  }
  exact <- c("observed_zero", "observed_positive")
  if (study_status %in% exact && target_status %in% exact) {
    if (study_status == "observed_zero" || target_status == "observed_zero") {
      return("observed_zero")
    }
    return("observed_positive")
  }
  "unevaluable"
}

.compare_marginal_row <- function(study_row, target_row) {
  both <- study_row$missingness == "observed" && target_row$missingness == "observed"
  status <- .combine_status(
    if (study_row$missingness == "observed") .observed_status(study_row$count) else study_row$missingness,
    if (target_row$missingness == "observed") .observed_status(target_row$count) else target_row$missingness
  )
  gap <- if (both) {
    .gap_pp(study_row$count, study_row$denominator, target_row$count, target_row$denominator)
  } else {
    NULL
  }
  list(
    variable = study_row$variable,
    stratum = study_row$stratum,
    study_count = if (study_row$missingness == "observed") study_row$count else NULL,
    study_denominator = study_row$denominator,
    target_count = if (target_row$missingness == "observed") target_row$count else NULL,
    target_denominator = target_row$denominator,
    difference_pp = gap,
    study_table_id = study_row$table_id,
    target_table_id = target_row$table_id,
    study_source_ref = study_row$source_ref,
    target_source_ref = target_row$source_ref,
    study_missingness = study_row$missingness,
    target_missingness = target_row$missingness,
    evidence = if (both) "identified" else "unavailable",
    count_status = status,
    definition_id = study_row$definition_id,
    measurement_window = study_row$measurement_window
  )
}

.compare_intersection <- function(age, severity, study, target, study_joint, target_joint) {
  study_age <- .lookup_margin(study$data, "age", age)
  study_sev <- .lookup_margin(study$data, "severity", severity)
  target_age <- .lookup_margin(target$data, "age", age)
  target_sev <- .lookup_margin(target$data, "severity", severity)
  study_bounds <- if (.margins_support_bounds(study_age, study_sev)) {
    .frechet_counts(study_age$count, study_sev$count, study_age$denominator)
  } else {
    NULL
  }
  target_bounds <- if (.margins_support_bounds(target_age, target_sev)) {
    .frechet_counts(target_age$count, target_sev$count, target_age$denominator)
  } else {
    NULL
  }
  study_side <- .side_from_joint(
    study_joint, age, severity,
    if (is.null(study_bounds)) NULL else unname(study_bounds[["low"]]),
    if (is.null(study_bounds)) NULL else unname(study_bounds[["high"]])
  )
  target_side <- .side_from_joint(
    target_joint, age, severity,
    if (is.null(target_bounds)) NULL else unname(target_bounds[["low"]]),
    if (is.null(target_bounds)) NULL else unname(target_bounds[["high"]])
  )
  both_exact <- isTRUE(study_side$exact) && isTRUE(target_side$exact)
  bounds_ok <- !is.null(study_side$low) && !is.null(study_side$high) &&
    !is.null(target_side$low) && !is.null(target_side$high)
  gap <- NULL
  gap_low <- NULL
  gap_high <- NULL
  evidence <- "unavailable"
  if (both_exact) {
    gap <- .gap_pp(
      study_side$count, study$data$denominator[[1L]],
      target_side$count, target$data$denominator[[1L]]
    )
    gap_low <- gap
    gap_high <- gap
    evidence <- "identified"
  } else if (bounds_ok) {
    bounded <- .gap_bound_pp(
      study_side$low, study_side$high, target_side$low, target_side$high,
      study$data$denominator[[1L]], target$data$denominator[[1L]]
    )
    gap_low <- unname(bounded[["low"]])
    gap_high <- unname(bounded[["high"]])
    evidence <- "bounded"
  }
  list(
    variable_a = "age",
    stratum_a = age,
    variable_b = "severity",
    stratum_b = severity,
    study_count = study_side$count,
    study_count_low = study_side$low,
    study_count_high = study_side$high,
    target_count = target_side$count,
    target_count_low = target_side$low,
    target_count_high = target_side$high,
    difference_pp = gap,
    difference_pp_low = gap_low,
    difference_pp_high = gap_high,
    evidence = evidence,
    count_status = .combine_status(study_side$status, target_side$status),
    study_count_status = study_side$status,
    target_count_status = target_side$status,
    study_source_ref = if (!is.null(study_side$source_ref)) study_side$source_ref else study$data$source_ref[[1L]],
    target_source_ref = if (!is.null(target_side$source_ref)) target_side$source_ref else target$data$source_ref[[1L]],
    study_joint_table_id = study_side$table_id,
    target_joint_table_id = target_side$table_id
  )
}

compare_populations <- function(study, target, study_joint = NULL, target_joint = NULL) {
  if (!isTRUE(study$ok) || !isTRUE(target$ok)) {
    return(.refuse("schema", "Both marginal tables have to validate before they can be compared.", "Run validate on each CSV and fix the reported errors."))
  }
  if (!is.null(study_joint) && !isTRUE(study_joint$ok)) {
    return(.refuse("joint", "The study joint table did not validate against its margins.", "Fix the joint file or omit it to keep the intersection bounded."))
  }
  if (!is.null(target_joint) && !isTRUE(target_joint$ok)) {
    return(.refuse("joint", "The target joint table did not validate against its margins.", "Fix the joint file or omit it to keep the intersection bounded."))
  }
  if (study$data$measurement_window[[1L]] != target$data$measurement_window[[1L]]) {
    return(.refuse(
      "definition",
      sprintf(
        "Measurement windows differ (%s versus %s). Joint analysis is refused.",
        study$data$measurement_window[[1L]], target$data$measurement_window[[1L]]
      ),
      "Use the same measurement_window on both populations. CohortShift does not align different windows."
    ))
  }
  for (variable in c("age", "severity")) {
    study_def <- unique(study$data$definition_id[study$data$variable == variable])
    target_def <- unique(target$data$definition_id[target$data$variable == variable])
    if (length(study_def) != 1L || length(target_def) != 1L || study_def != target_def) {
      return(.refuse(
        "definition",
        sprintf(
          "%s definitions differ (%s versus %s). Joint analysis is refused.",
          variable, paste(study_def, collapse = ","), paste(target_def, collapse = ",")
        ),
        "Use the same definition_id in the study and the target. CohortShift does not recode or interpolate strata."
      ))
    }
    if (!.same_strata(study$data, target$data, variable)) {
      return(.refuse(
        "partition",
        sprintf(
          "The study and target do not use the same %s strata. Joint analysis is refused.",
          variable
        ),
        "Use the same exact strata on both sides. CohortShift does not interpolate one age band into another."
      ))
    }
  }
  if (!all(c("age", "severity") %in% study$data$variable)) {
    return(.refuse(
      "schema",
      "The comparison needs both an age table and a severity table.",
      "Include age and severity strata for each population."
    ))
  }
  marginals <- list()
  for (variable in c("age", "severity")) {
    study_rows <- .strata_of(study$data, variable)
    for (i in seq_len(nrow(study_rows))) {
      target_row <- .lookup_margin(target$data, variable, study_rows$stratum[[i]])
      marginals[[length(marginals) + 1L]] <- .compare_marginal_row(study_rows[i, , drop = FALSE], target_row)
    }
  }
  ages <- sort(unique(study$data$stratum[study$data$variable == "age"]))
  severities <- sort(unique(study$data$stratum[study$data$variable == "severity"]))
  intersections <- list()
  for (age in ages) {
    for (severity in severities) {
      intersections[[length(intersections) + 1L]] <- .compare_intersection(
        age, severity, study, target, study_joint, target_joint
      )
    }
  }
  identified <- sum(vapply(marginals, function(row) row$evidence == "identified", logical(1))) +
    sum(vapply(intersections, function(row) row$evidence == "identified", logical(1)))
  requested <- length(marginals) + length(intersections)
  list(
    ok = TRUE,
    schema_version = 1L,
    kind = "comparison",
    methodology = .METHODOLOGY,
    limitations = as.list(.LIMITATIONS),
    scenario_id = NULL,
    marginals = marginals,
    intersections = intersections,
    coverage = list(
      requested = requested,
      identified = identified,
      share = identified / requested
    ),
    provenance = list(
      study_table_id = study$data$table_id[[1L]],
      target_table_id = target$data$table_id[[1L]],
      study_source_ref = study$data$source_ref[[1L]],
      target_source_ref = target$data$source_ref[[1L]],
      study_marginal_digest = study$digest,
      target_marginal_digest = target$digest,
      study_joint_digest = if (is.null(study_joint)) NULL else study_joint$digest,
      target_joint_digest = if (is.null(target_joint)) NULL else target_joint$digest,
      measurement_window = study$data$measurement_window[[1L]]
    )
  )
}

compare_files <- function(study_path, target_path, study_joint_path = NULL, target_joint_path = NULL) {
  study <- validate_marginal_file(study_path)
  if (!isTRUE(study$ok)) {
    return(study)
  }
  target <- validate_marginal_file(target_path)
  if (!isTRUE(target$ok)) {
    return(target)
  }
  study_joint <- NULL
  if (!is.null(study_joint_path)) {
    study_joint <- validate_joint_file(study_joint_path, study)
    if (!isTRUE(study_joint$ok)) {
      return(study_joint)
    }
  }
  target_joint <- NULL
  if (!is.null(target_joint_path)) {
    target_joint <- validate_joint_file(target_joint_path, target)
    if (!isTRUE(target_joint$ok)) {
      return(target_joint)
    }
  }
  compare_populations(study, target, study_joint, target_joint)
}
