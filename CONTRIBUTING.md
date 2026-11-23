# Contributing

CohortShift accepts bug reports and small changes that keep the aggregate-only boundary. Individual records, imputed outcomes, causal adjustment, and treatment recommendations stay out of scope.

1. Install R 4.3 or newer. No extra packages are required.
2. From a checkout, run `Rscript tests/test-all.R`.
3. Run the demo in the README and compare `out/cohortshift/result.json` with `inst/fixtures/oracle/proof-case.md`.
4. Keep new fixtures fictional. Record them in `inst/fixtures/manifest.json` with checksums.
5. Do not commit generated `out/` directories, credentials, or clinical records.

Open a pull request against `main`. The GitHub Actions workflow runs the tests and the fixture demo without secrets.
