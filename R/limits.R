# Resource bounds for aggregate tables. Counts stay inside exact integer
# arithmetic for the denominators used by the demo and for products up to
# about 1e15, which is below the 53-bit mantissa.

.CS_MAX_BYTES <- 5 * 1024 * 1024
.CS_MAX_ROWS <- 10000
.CS_MAX_DENOMINATOR <- 1000000000
.CS_MAX_FIELD <- 200L

.CS_MARGINAL_COLUMNS <- c(
  "schema_version", "population", "variable", "stratum", "count",
  "denominator", "table_id", "source_ref", "missingness",
  "measurement_window", "definition_id"
)

.CS_JOINT_COLUMNS <- c(
  "schema_version", "population", "variable_a", "stratum_a",
  "variable_b", "stratum_b", "count", "denominator", "table_id",
  "source_ref", "missingness", "measurement_window",
  "definition_id_a", "definition_id_b", "margin_table_id"
)

.CS_ROW_LEVEL_COLUMNS <- c(
  "person_id", "participant_id", "subject_id", "patient_id",
  "record_id", "row_id", "dob", "date_of_birth", "mrn", "ssn",
  "first_name", "last_name", "patient_name", "address", "email"
)

.CS_MISSINGNESS <- c("observed", "suppressed", "absent")
