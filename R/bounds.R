# Fréchet–Hoeffding bounds for one cell of a binary cross-classification.
# count_a and count_b are marginal counts in the same population of size n.
.frechet_counts <- function(count_a, count_b, n) {
  c(
    low = max(0, count_a + count_b - n),
    high = min(count_a, count_b)
  )
}

.gap_bound_pp <- function(study_low, study_high, target_low, target_high, den_study, den_target) {
  c(
    low = .gap_pp(study_low, den_study, target_high, den_target),
    high = .gap_pp(study_high, den_study, target_low, den_target)
  )
}
