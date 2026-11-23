.cs_error <- function(category, message, hint, location = NULL) {
  list(
    category = category,
    message = message,
    hint = hint,
    location = location
  )
}

.cs_fail <- function(errors) {
  list(ok = FALSE, schema_version = 1L, errors = errors)
}

.cs_field <- function(location, category, message, hint) {
  .cs_error(category, message, hint, location)
}
