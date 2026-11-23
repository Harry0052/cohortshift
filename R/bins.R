# Exact buckets. Intervals are half-open: [lower, upper).
# age_50_plus is a supported label so a file can be rejected for overlap
# instead of being silently collapsed into age_65_plus.

.age_catalog <- function() {
  list(
    under_65 = c(lower = 0, upper = 65),
    age_65_plus = c(lower = 65, upper = Inf),
    age_50_plus = c(lower = 50, upper = Inf)
  )
}

.severity_catalog <- function() {
  list(
    severity.binary.v1 = c("severe", "not_severe"),
    severity.binary.v2 = c("severe", "not_severe")
  )
}

.intervals_overlap <- function(left, right) {
  left[["lower"]] < right[["upper"]] && right[["lower"]] < left[["upper"]]
}

.interval_label <- function(bounds) {
  upper <- if (is.infinite(bounds[["upper"]])) "Inf" else as.character(bounds[["upper"]])
  sprintf("[%s, %s)", as.character(bounds[["lower"]]), upper)
}

.supported_age_text <- function() {
  paste(names(.age_catalog()), collapse = ", ")
}

.check_age_strata <- function(strata, location_prefix) {
  errors <- list()
  catalog <- .age_catalog()
  unknown <- strata[!strata %in% names(catalog)]
  for (name in unknown) {
    errors[[length(errors) + 1L]] <- .cs_error(
      "partition",
      sprintf(
        "Age stratum %s is not a supported exact bucket. CohortShift does not interpolate age bands.",
        name
      ),
      sprintf("Use one of these exact buckets: %s.", .supported_age_text()),
      location_prefix
    )
  }
  known <- strata[strata %in% names(catalog)]
  if (length(known) >= 2L) {
    for (i in seq_len(length(known) - 1L)) {
      for (j in (i + 1L):length(known)) {
        left <- catalog[[known[[i]]]]
        right <- catalog[[known[[j]]]]
        if (.intervals_overlap(left, right)) {
          errors[[length(errors) + 1L]] <- .cs_error(
            "partition",
            sprintf(
              "Age strata %s %s and %s %s overlap. CohortShift does not interpolate or merge overlapping age bands.",
              known[[i]], .interval_label(left), known[[j]], .interval_label(right)
            ),
            "Choose one exact partition, such as under_65 with age_65_plus.",
            location_prefix
          )
        }
      }
    }
  }
  errors
}

.check_severity_strata <- function(strata, definition_id, location_prefix) {
  errors <- list()
  catalog <- .severity_catalog()
  if (!definition_id %in% names(catalog)) {
    return(list(.cs_error(
      "definition",
      sprintf("Severity definition %s is not supported.", definition_id),
      sprintf(
        "Use one of these definitions: %s. Different definitions are not treated as the same bands.",
        paste(names(catalog), collapse = ", ")
      ),
      location_prefix
    )))
  }
  allowed <- catalog[[definition_id]]
  unknown <- strata[!strata %in% allowed]
  for (name in unknown) {
    errors[[length(errors) + 1L]] <- .cs_error(
      "partition",
      sprintf(
        "Severity stratum %s is not part of definition %s.",
        name, definition_id
      ),
      sprintf("Use these strata for %s: %s.", definition_id, paste(allowed, collapse = ", ")),
      location_prefix
    )
  }
  errors
}

.check_variable_partition <- function(rows) {
  errors <- list()
  variable <- rows$variable[[1L]]
  location <- sprintf("variable %s", variable)
  strata <- rows$stratum
  if (any(duplicated(strata))) {
    dup <- unique(strata[duplicated(strata)])
    errors[[length(errors) + 1L]] <- .cs_error(
      "partition",
      sprintf("Stratum %s is repeated for %s. Strata must be mutually exclusive.", dup[[1L]], variable),
      "Keep one row per stratum and put each person in exactly one stratum.",
      location
    )
  }
  if (variable == "age") {
    errors <- c(errors, .check_age_strata(unique(strata), location))
  } else if (variable == "severity") {
    definition_id <- unique(rows$definition_id)
    if (length(definition_id) != 1L) {
      errors[[length(errors) + 1L]] <- .cs_error(
        "definition",
        sprintf("Severity rows use more than one definition_id (%s).", paste(definition_id, collapse = ", ")),
        "Use one severity definition inside a table.",
        location
      )
    } else {
      errors <- c(errors, .check_severity_strata(unique(strata), definition_id, location))
    }
  }
  observed <- rows$missingness == "observed"
  if (all(observed)) {
    total <- sum(rows$count)
    denominator <- rows$denominator[[1L]]
    if (!isTRUE(all.equal(total, denominator))) {
      errors[[length(errors) + 1L]] <- .cs_error(
        "partition",
        sprintf(
          "Observed %s strata sum to %s, which does not equal denominator %s.",
          variable, format(total, scientific = FALSE, trim = TRUE),
          format(denominator, scientific = FALSE, trim = TRUE)
        ),
        "Include every mutually exclusive stratum, or mark a missing stratum as suppressed or absent instead of dropping it.",
        location
      )
    }
  } else {
    total <- sum(rows$count[observed])
    denominator <- rows$denominator[[1L]]
    if (total > denominator) {
      errors[[length(errors) + 1L]] <- .cs_error(
        "bounds",
        sprintf(
          "Observed %s counts sum to %s, which is already above denominator %s.",
          variable, format(total, scientific = FALSE, trim = TRUE),
          format(denominator, scientific = FALSE, trim = TRUE)
        ),
        "Check the observed counts. Suppressed and absent cells are not zeros and are not added in.",
        location
      )
    }
  }
  errors
}
