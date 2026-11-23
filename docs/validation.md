# Validation

Checked on 2026-11-23 with R 4.3.3 (2024-02-29) on Linux 6.12.113+ x86_64. Every numeric check below is on the synthetic fixtures in `inst/fixtures/`. There is no external dataset in this release.

Tolerance: counts and percentage points on these fixtures are exact integers. Tests use `all.equal(..., tolerance = 0)`. The method is not an approximation. Shares are displayed from those integers. The 5 second budget below is a wall-clock ceiling, not a numeric tolerance.

## Acceptance evidence

| Check | Command or test | Observed |
| --- | --- | --- |
| Marginal gaps on the proof fixture | `compare_files` on `proof/study_marginals.csv` and `proof/target_marginals.csv` | Age 65+ and severe are each -20 percentage points. Under 65 and not severe are each +20. |
| Joint bounds when the joint is withheld | Same comparison, cell age 65+ × severe | Evidence `bounded`. Study count 0 to 20. Target count 0 to 40. Gap -40 to +20. Coverage 4/8 = 0.5. |
| Exact joint | Both `proof/*_joint.csv` files | Evidence `identified`. Study count 0 with status `observed_zero`. Target count 25. Gap -25. Coverage 8/8 = 1. |
| Joint that misses a margin | `invalid/joint_mismatch.csv` | Rejected, category `joint`. Severe cells sum to 25 against marginal count 20. |
| Overlapping age bands | `invalid/overlapping_age.csv` | Rejected, category `partition`. `age_50_plus` [50, Inf) overlaps `age_65_plus` [65, Inf). |
| Unsupported age band | `invalid/unsupported_age.csv` | Rejected. `age_60_64` is not interpolated. |
| Different severity definitions | `invalid/target_other_severity.csv` | Exit 4, category `definition`. No gap is emitted. |
| Different measurement windows | `invalid/target_other_window.csv` | Exit 4, category `definition`. |
| Observed zero versus suppressed | `status/suppressed_joint.csv` | The blank suppressed cell stays `suppressed` with a null count. The complete joint's zero stays `observed_zero`. |
| Scenario substitution | `scenarios/alternate_target.csv` | Study count 30 and source `synthetic:study-margins-v1` stay put. Age gap changes from -20 to -40. Severe gap stays -20. Baseline target source is retained. |
| Matched margins, different joint | `proof/hidden_*` | Both marginal gaps are 0. The age-65-plus and severe gap is -50, and the report says this is not a treatment effect. |

`Rscript tests/test-all.R` reported `Passed 93 checks`.

A fresh process, `Rscript bin/cohortshift.R compare inst/fixtures/proof/study_marginals.csv inst/fixtures/proof/target_marginals.csv --out /tmp/fresh-proof`, wrote a result whose withheld age-65-plus and severe gap was -40 to 20 and whose coverage share was 0.5. The summary includes the sentence that the figures are not a treatment effect.

## Performance

The supported demo is the proof fixture: 18 CSV files under `inst/fixtures/`, 12911 bytes in total. The compare function on the two proof marginal tables took 0.23 seconds inside an already running R process. The CLI, including R startup, took 0.44 seconds. The budget is 5 seconds for that compare. It is set above the observed time so a slower laptop still passes, and it is still tight enough to catch an accidental hang. The test fails if the in-process compare takes 5 seconds or more. Inputs above 10000 rows or 5 MiB are rejected before the calculation.

## Trust boundaries

- CSV fields are read as text and checked against the version 1 schema. They are not evaluated as code.
- The only `system2` call is in `tests/test-all.R`, and it launches this repository's CLI with an argument vector.
- Package code does not open network connections, start a child process, or read a path supplied as an output directory when that path contains `..`.
- Writes for a successful compare are `result.json`, `summary.txt`, and `report.html` inside the requested directory.
- Columns such as `person_id` are rejected as individual-level input.
- A count above its denominator, a negative count, and an oversized file are rejected.
- No CRAN packages are imported. There is no third-party lockfile to scan. The interpreter is the base R 4.3.3 package from Ubuntu. The project license is MIT. Running it on GPL R does not copy R's source into the repository.
- Fixtures are hand-specified integers. `inst/fixtures/manifest.json` stores their checksums. No clinical table is redistributed.

## Domain safeguard

Equal marginals are not treated as an equal intersection. The hidden-gap fixture has a 0 percentage point gap for age 65+ and for severe, and a -50 percentage point gap for their intersection. The study cell is an observed zero. The summary and the HTML keep the methodology beside the result: the numbers describe composition, not treatment-effect heterogeneity and not generalizability.

A comparison is refused, with no gap table, when the measurement window or the variable definition differs.

## Residual limitations

- The Fréchet bounds assume the two margins describe the same people. The schema enforces one denominator and one window inside a table. It cannot detect a mislabeled population that happens to use the same codes.
- A suppressed cell is not filled from the other cells, even when those cells leave only one integer that would fit.
- Age support is the three declared buckets. Other published age cuts are rejected rather than mapped.
- The HTML report is a static document. Tab order follows the skip link and the headings. It does not submit data anywhere.
