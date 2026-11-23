# Grokbot progress

## P01 — Research overlap and confirm the MVP

- **Phase and status:** P01 PASS
- **Files changed:** `docs/overlap.md`, `docs/project-contract.md`, `docs/grokbot-progress.md`
- **Commands and results:**
  - Inspected the checkout. `README.md` contained the title only. `LICENSE` is MIT. Remote is `Harry0052/cohortshift`. No R packages were present. After `apt-get install r-base`, `Rscript --version` reported R 4.3.3 (2024-02-29). `matlab` and `octave` were absent. Python 3.12.3 was present.
  - Equiflow 0.1.10 observed run, 2026-11-23. Aggregate rows were counted as four people. Two margin-compatible joints (0 and 20) produced the same marginal characteristic table. Study-versus-target drifts were `age 0.42` and `severity 0.45`, not the required percentage-point gaps. No bound method exists.
  - ClinicalTrialEquity `Equity_metrics.R` at commit `137f496` observed run under R 4.3.3. Log disparity on the shared marginals was `-0.8472979` and `-0.9808293`. A true zero and a missing cell filled as zero were both `-Inf` and both labeled `Absent`.
  - GIST 2.0 commit `51f099f` was documentation only. Execution is unresolved because Matlab is not installed and the repository has no license. The documented input is a 250 by 69 individual file, which the shared fixture is not.
  - generalize commit `53f1dc4` was documentation only. License metadata is `NOASSERTION`, and `assess()` requires stacked individual records.
- **Artifact paths:** `docs/overlap.md`, `docs/project-contract.md`
- **Open issues:** GIST was not executed. generalize was not executed. Neither gap changes the proceed decision, because both documented inputs fall outside the aggregate acceptance case.
- **Next phase:** P02 — Create the repository and data contracts.

Decision recorded in `docs/overlap.md`: proceed. The acceptance case and the base-R provenance path are in `docs/project-contract.md`.

## P02 — Create the repository and data contracts

- **Phase and status:** P02 PASS
- **Files changed:** `DESCRIPTION`, `NAMESPACE`, `.Rbuildignore`, `.gitignore`, `README.md`, `R/limits.R`, `R/errors.R`, `R/json.R`, `R/bins.R`, `R/schema.R`, `R/cli.R`, `bin/cohortshift.R`, `inst/schema/marginal-v1.json`, `inst/schema/joint-v1.json`, `inst/schema/comparison-v1.json`, `inst/fixtures/manifest.json`, `inst/fixtures/oracle/proof-case.md`, `inst/fixtures/oracle/proof-case.json`, `inst/fixtures/proof/*.csv`, `inst/fixtures/invalid/*.csv`, `inst/fixtures/status/suppressed_joint.csv`, `tests/test-all.R`, `docs/grokbot-progress.md`
- **Commands and results:**
  - `Rscript tests/test-all.R` — `Passed 30 checks`, exit 0. R 4.3.3.
  - `Rscript bin/cohortshift.R validate inst/fixtures/proof/study_marginals.csv` — exit 0. Stdout: `{"ok":true,"schema_version":1,"kind":"marginal","path":"inst/fixtures/proof/study_marginals.csv","rows":4,"population":"study","table_id":"study-margins-v1","digest":"df75a9df47c54b7a4773c0eed00935ff"}`.
  - `Rscript bin/cohortshift.R validate inst/fixtures/invalid/overlapping_age.csv` — exit 3. Stderr names the overlap of `age_50_plus [50, Inf)` and `age_65_plus [65, Inf)` and says interpolation is not performed. Stdout is `{"ok":false,...}` with category `partition`.
  - `Rscript bin/cohortshift.R validate inst/fixtures/proof/study_marginals.csv --joints inst/fixtures/invalid/joint_mismatch.csv` — exit 3. Joint severe cells sum to 25 against marginal count 20.
  - `R CMD INSTALL --library=/tmp/cs-lib .` — `DONE (cohortshift)`.
- **Artifact paths:** `inst/fixtures/oracle/proof-case.md`, `inst/fixtures/manifest.json`, `inst/schema/marginal-v1.json`, `inst/schema/joint-v1.json`, `inst/schema/comparison-v1.json`
- **Open issues:** The compare command, gap arithmetic, HTML report, and scenario substitution are not in this phase.
- **Next phase:** P03 — Build the working core.

## P03 — Build the working core

- **Phase and status:** P03 PASS
- **Files changed:** `R/margins.R`, `R/bounds.R`, `R/compare.R`, `R/report.R`, `R/cli.R`, `bin/cohortshift.R`, `NAMESPACE`, `tests/test-all.R`, `README.md`, `inst/fixtures/invalid/target_other_severity.csv`, `inst/fixtures/invalid/target_other_window.csv`, `inst/fixtures/manifest.json`, `docs/grokbot-progress.md`
- **Commands and results:**
  - `Rscript tests/test-all.R` — `Passed 67 checks`, exit 0, R 4.3.3.
  - `Rscript bin/cohortshift.R compare inst/fixtures/proof/study_marginals.csv inst/fixtures/proof/target_marginals.csv --out out/proof-withheld` — exit 0. Age 65+ and severe is `bounded`, study count 0 to 20, target count 0 to 40, gap -40 to +20 percentage points. Marginal gaps are -20 and -20. Coverage is 4 of 8 (share 0.5).
  - The same command with `--joints-study inst/fixtures/proof/study_joint.csv --joints-target inst/fixtures/proof/target_joint.csv --out out/proof-exact` — exit 0. That cell is `identified`, study count 0 (`observed_zero`), target count 25, gap -25. Coverage share is 1.
  - A joint that sums the severe cells to 25 against a marginal of 20 is rejected. Different severity definitions and different measurement windows exit 4 and do not emit gaps.
  - `R CMD INSTALL --library=/tmp/cs-lib .` — `DONE (cohortshift)`.
- **Artifact paths:** `out/proof-withheld/result.json`, `out/proof-withheld/summary.txt`, `out/proof-exact/result.json`, `out/proof-exact/summary.txt`, `inst/fixtures/oracle/proof-case.json`
- **Open issues:** The local HTML report, the alternate target scenario, and the release workflow are not in this phase. `out/` is generated and is not committed.
- **Next phase:** P04 — Ship the user workflow and reports.
