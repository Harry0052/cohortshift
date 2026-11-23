# CohortShift

CohortShift compares aggregate age and severity counts for a study population and a target population. It reports marginal share differences and says whether an intersection is an exact count, a range implied by the margins, or unavailable.

The tables in this repository are fictional. They are not clinical records.

## Prerequisites

- R 4.3 or newer, with the base and recommended packages that ship with R.
- No extra R packages and no network access at run time.

This project was developed on R 4.3.3. On Debian or Ubuntu:

```bash
sudo apt-get install r-base
```

## Check the fixture contract

From the repository root:

```bash
Rscript tests/test-all.R
Rscript bin/cohortshift.R validate inst/fixtures/proof/study_marginals.csv
Rscript bin/cohortshift.R validate inst/fixtures/invalid/overlapping_age.csv
```

The valid study table exits 0 and prints a JSON object with `"ok":true`. The overlapping age table exits 3, prints `"ok":false`, and explains the overlap on standard error. A joint table is checked with the marginal file it maps:

```bash
Rscript bin/cohortshift.R validate inst/fixtures/proof/study_marginals.csv \
  --joints inst/fixtures/proof/study_joint.csv
Rscript bin/cohortshift.R validate inst/fixtures/proof/study_marginals.csv \
  --joints inst/fixtures/invalid/joint_mismatch.csv
```

The first command exits 0. The second exits 3 because the joint severe cells sum to 25, not the marginal count 20.

The expected numeric results for the proof tables are written out by hand in `inst/fixtures/oracle/proof-case.md`. Checksums and the synthetic-data terms are in `inst/fixtures/manifest.json`.

## Compare the proof tables

```bash
Rscript bin/cohortshift.R compare \
  inst/fixtures/proof/study_marginals.csv \
  inst/fixtures/proof/target_marginals.csv \
  --out out/proof-withheld
```

With no joint file, age 65+ and severe is bounded: the study-minus-target gap lies from -40 to +20 percentage points, and each marginal gap is -20. Adding the joint files replaces that cell with an observed gap of -25 and marks the study count of 0 as an observed zero:

```bash
Rscript bin/cohortshift.R compare \
  inst/fixtures/proof/study_marginals.csv \
  inst/fixtures/proof/target_marginals.csv \
  --joints-study inst/fixtures/proof/study_joint.csv \
  --joints-target inst/fixtures/proof/target_joint.csv \
  --out out/proof-exact
```

`result.json` is the machine-readable result. `summary.txt` is the description. The command exits 3 for an invalid table and 4 when the tables use different severity definitions or measurement windows.

## Package layout

`R CMD INSTALL .` installs the R package. The command above does not need that install; `bin/cohortshift.R` loads the package sources from the checkout.
