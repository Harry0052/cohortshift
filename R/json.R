.json_escape <- function(text) {
  text <- enc2utf8(as.character(text))
  text <- gsub("\\", "\\\\", text, fixed = TRUE)
  text <- gsub("\"", "\\\"", text, fixed = TRUE)
  text <- gsub("\r", "\\r", text, fixed = TRUE)
  text <- gsub("\n", "\\n", text, fixed = TRUE)
  text <- gsub("\t", "\\t", text, fixed = TRUE)
  text
}

# Encode the lists this package builds. Named lists become objects.
# Unnamed lists and atomic vectors become arrays. NA and NULL become null.
to_json <- function(value) {
  if (is.null(value)) {
    return("null")
  }
  if (length(value) == 1L && !is.list(value)) {
    if (is.na(value)) {
      return("null")
    }
    if (is.logical(value)) {
      return(if (isTRUE(value)) "true" else "false")
    }
    if (is.numeric(value)) {
      if (!is.finite(value)) {
        stop("Refusing to encode a non-finite number.", call. = FALSE)
      }
      rounded <- round(value)
      if (abs(value - rounded) < 1e-9) {
        return(format(rounded, scientific = FALSE, trim = TRUE))
      }
      return(format(value, scientific = FALSE, trim = TRUE, digits = 15, nsmall = 1))
    }
    if (is.character(value)) {
      return(paste0("\"", .json_escape(value), "\""))
    }
  }
  if (is.list(value) && !is.null(names(value)) && length(names(value)) == length(value) &&
        !any(names(value) == "")) {
    parts <- vapply(names(value), function(key) {
      paste0("\"", .json_escape(key), "\":", to_json(value[[key]]))
    }, character(1))
    return(paste0("{", paste(parts, collapse = ","), "}"))
  }
  items <- lapply(seq_along(value), function(i) to_json(value[[i]]))
  paste0("[", paste(items, collapse = ","), "]")
}
