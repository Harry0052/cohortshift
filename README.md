# CohortShift

CohortShift compares aggregate age and severity counts for a study population and a target population. It reports each marginal count beside its denominator, the study share minus the target share in percentage points, and whether an intersection is an exact count, a Fréchet range, or unavailable.

The tables shipped here are fictional aggregate counts. They are not clinical records. CohortShift does not estimate a treatment effect and does not claim that a result generalizes.

## Supported platform

Tested on Linux x86_64 with R 4.3.3 and the base and recommended packages that ship with R. No extra R packages are required, and the analysis does not use the network. GitHub Actions runs the same checks on `ubuntu-latest` with R 4.3.3.

On Debian or Ubuntu:

```bash
sudo apt-get install r-base
```

There is no separate real-data, model, or hardware demo.

## Clean install and the demo

From a fresh checkout:

```bash
git clone https://github.com/Harry0052/cohortshift.git
cd cohortshift
Rscript tests/test-all.R
Rscript bin/cohortshift.R compare \
  inst/fixtures/proof/study_marginals.csv \
  inst/fixtures/proof/target_marginals.csv
```

The demo writes:

- `out/cohortshift/report.html` — the report to open
- `out/cohortshift/result.json` — the machine-readable result
- `out/cohortshift/summary.txt` — the same findings as plain text

Expected result for age 65+ and severe, with no joint file: marginal gaps of -20 percentage points for age 65+ and for severe, and an intersection gap from -40 to +20 percentage points labeled "Bounded, not observed". Coverage is 4 of 8 requested subgroups. The hand arithmetic is in `inst/fixtures/oracle/proof-case.md`.

`R CMD INSTALL .` installs the R package. The demo command does not need that install. `bin/cohortshift.R` loads the sources in the checkout.

## Walk through the sample

1. Check the study table. This exits 0:

```bash
Rscript bin/cohortshift.R validate inst/fixtures/proof/study_marginals.csv
```

2. Run the demo command above and open `out/cohortshift/report.html`. The study source on the age 65+ row is `synthetic:study-margins-v1`, the `source_ref` value in `inst/fixtures/proof/study_marginals.csv`.

3. Substitute the predeclared target mix. The severe gap stays -20. The study source stays `synthetic:study-margins-v1`.

```bash
Rscript bin/cohortshift.R compare \
  inst/fixtures/proof/study_marginals.csv \
  inst/fixtures/proof/target_marginals.csv \
  --scenario inst/fixtures/scenarios/alternate_target.csv \
  --out out/scenario
```

4. Add the joint tables. Age 65+ and severe becomes an observed gap of -25 percentage points, and the study count of 0 is an observed zero:

```bash
Rscript bin/cohortshift.R compare \
  inst/fixtures/proof/study_marginals.csv \
  inst/fixtures/proof/target_marginals.csv \
  --joints-study inst/fixtures/proof/study_joint.csv \
  --joints-target inst/fixtures/proof/target_joint.csv \
  --out out/proof-exact
```

5. An invalid table exits 3 and explains how to fix it. A different severity definition or measurement window exits 4 and does not print a gap. Diagnostics go to standard error. JSON results go to standard output or to `result.json`.

```bash
Rscript bin/cohortshift.R compare \
  inst/fixtures/proof/study_marginals.csv \
  inst/fixtures/invalid/overlapping_age.csv
```

`Rscript bin/cohortshift.R help` lists the commands and exit codes.

## Fixture terms

Counts are hand-specified integers created for this repository. They are not sampled, so there is no generator seed. Checksums, the synthetic-data statement, and the source label are in `inst/fixtures/manifest.json`. No external table is copied. Age buckets and severity definitions are the ones named in `inst/schema/marginal-v1.json`.

## License and changes

This project is released under the MIT license. See `LICENSE`. Version 0.1.0 notes are in `NEWS.md`. Contribution steps are in `CONTRIBUTING.md`. Vulnerability reports are described in `SECURITY.md`.
