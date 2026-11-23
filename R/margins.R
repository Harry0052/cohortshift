# Study share minus target share, in percentage points.
# The products stay exact for the integer denominators this release accepts
# when both denominators are at most 1e6. Larger products are still computed
# in double precision and checked against the oracle on the demo fixture.
.gap_pp <- function(count_study, den_study, count_target, den_target) {
  ((count_study * den_target) - (count_target * den_study)) * 100 /
    (den_study * den_target)
}

.share <- function(count, denominator) {
  count / denominator
}
