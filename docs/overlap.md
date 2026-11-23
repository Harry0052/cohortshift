# Overlap review

Access date for every external check: 2026-11-23.

Decision: **proceed**. CohortShift stays a separate repository. No reviewed tool already answers the acceptance case from two aggregate marginal tables.

## Question held constant

Target user: a clinical research analyst comparing published study demographics with a defined target population.

Shared input: fictional aggregate counts only. Study denominator 100, age 65+ count 30, severe count 20. Target denominator 100, age 65+ count 50, severe count 40. No individual rows. The joint age-65-plus and severe cell is withheld in the primary case and, in a second case, supplied as an exact compatible table (study 0, target 25).

Expected artifact:

- Marginal study-minus-target gaps of -20 percentage points for age 65+ and for severe.
- With the joint withheld, a joint gap range of -40 to +20 percentage points, labeled as bounded rather than observed.
- With the compatible joint, an observed joint gap of -25 percentage points, and the study cell of 0 labeled as an observed zero rather than as a missing cell.
- Coverage equal to the share of requested subgroups whose counts are identified. On this fixture that share is 1/2 when the four intersection cells are withheld and 1 when the complete joint is accepted.

Acceptance metric: exact agreement with those hand-derived values, including a separate status for known, bounded, and unavailable cells. Individual records, imputed outcomes, causal adjustment, and a single representativeness score are outside the case.

## Capability matrix

| Tool | Input it actually accepts | Trial-versus-target marginal gap in percentage points | Unidentified intersection kept distinct from zero | Fréchet gap bounds from two margins | Exact joint only when it reproduces margins | Coverage as identified-count share | Meets the acceptance case |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Equiflow 0.1.10 | One row per person, then exclusion steps | No. Reports marginal N (%) and Cohen-style drift between steps | No joint status | No | No | No | No |
| ClinicalTrialEquity commit 137f496 | Grouped subgroup counts, and the shipped app reads participant files plus NHANES extracts | No. Log disparity is a log-odds score | No. A missing count filled as 0 receives the same `-Inf` / Absent label as a true zero | No | No | No | No |
| GIST 2.0 commit 51f099f | Individual target-population rows (demo file is 250 by 69) plus eligibility limits | No. Emits sGIST and one mGIST | Not applicable; dependence is estimated from individual rows | No | No | No | No |
| generalize commit 53f1dc4 | Stacked individual trial and target data frame | No. Covariate means, ASMD, and a Tipton index | No | No | No | No | No |

## Probes

### Equiflow

- Primary URL: https://github.com/MoreiraP12/equiflow-v2
- Distribution: https://pypi.org/project/equiflow/ version 0.1.10
- Commit: `d68498d794b6a15ad525de8e78627ac8bc37e5ef` (2026-02-12)
- License: MIT (GitHub license metadata and PyPI classifier)
- Dataset terms: the package does not ship a required clinical dataset. The PLOS Digital Health paper's eICU case study is behind a PhysioNet data-use agreement and was not used. Paper: https://journals.plos.org/digitalhealth/article?id=10.1371/journal.pdig.0001342 (CC BY).
- Evidence: observed run. Python 3.12.3, `equiflow==0.1.10` installed into a temporary directory. The upstream fork parent is https://github.com/joamats/equiflow (MIT).

Observed results:

- Passing the four aggregate count rows as the data frame produced a cohort of n = 4. Equiflow treated each summary row as a person. `view_table_characteristics` then reported stratum shares of the four rows, not 30/100 or 50/100.
- The public methods are `add_exclusion`, `view_table_flows`, `view_table_characteristics`, `view_table_drifts`, `view_table_pvalues`, and `plot_flows`. None compute a bound.
- Two different individual-level joints that both match the study margins (intersection 0 and intersection 20) produced the same Equiflow marginal table: age 65+ 30 (30.0), severe 20 (20.0). The tool cannot show that those joints are different or unidentified.
- Feeding a study joint of 0 and a target joint of 25 as two sequential cohorts reported marginal shares 30 percent versus 50 percent and 20 percent versus 40 percent, and drifts `age 0.42`, `severity 0.45`. It did not report -20 percentage points, the interval [-40, +20], or the observed gap -25. Sequential cohorts are also the wrong comparison: Equiflow models exclusion steps inside one cohort, not a study table against an external target table.

Features that already match: categorical counts and percents, an explicit missingness category, and a visual composition table. Those features do not cover incomplete two-table evidence.

### ClinicalTrialEquity

- Primary URL: https://github.com/TheRensselaerIDEA/ClinicalTrialEquity
- Commit: `137f496c9b587a8a1340eeaddfd2529c31c5cd1f` (2021-09-07)
- License: Apache-2.0
- Dataset terms: the README and the medRxiv/PMC paper state that ACCORD, ALLHAT, and SPRINT participant files came through BioLINCC under restrictions. NHANES is a public CDC survey. Those files were not downloaded. Paper: https://pmc.ncbi.nlm.nih.gov/articles/PMC8460438/
- Evidence: observed run of `Visualization Codes/modules/Equity_metrics.R` at that commit, under R 4.3.3. The sunburst builder was not executed. It imports tidyverse-style grouping and the app loads the restricted example files. The absent-versus-zero behavior below is the metric those functions apply after `generate_sunburst_df` replaces missing merged counts with 0 (`replace_na(0)` in `sunburst_process.R`).

Observed results on the shared rates:

- `Log_Disparate_Impact(0.50, 0.30)` for age 65+ returned `-0.8472979`, not -20.
- `Log_Disparate_Impact(0.40, 0.20)` for severe returned `-0.9808293`, not -20.
- `Log_Disparate_Impact(0.25, 0)` for a true study joint of 0 against a target joint of 25 returned `-Inf`, and `whether_biased_label` returned `Absent`.
- The same call, which is what a missing study cell becomes after fill-zero, also returned `-Inf`. `identical()` was `TRUE`. A true zero and an unidentified cell are not distinguished.
- `Log_Disparate_Impact(0, 0)` returned the sentinel `-9999999`, labeled `No Info`. That sentinel is not a Fréchet interval.

The paper's metrics are defined on subgroup rates and can be computed from summaries when the subgroup is already identified. The shipped two-variable sunburst still needs those joint counts. It has labels for absent, no info, and no base data, and it has no bounded or unidentified state. A single log-disparity score is the opposite of showing the width of the unresolved gap.

Features that already match: study-versus-target subgroup rates, a visual that can mark a subgroup absent, and a preference for summary counts over raw identifiers. The missing-data rule and the score do not meet the acceptance metric.

### GIST 2.0

- Primary URL: https://github.com/ChunhuaWeng/GIST-2.0-for-Population-Representativeness-Measurement
- Commit: `51f099f61332455b0eb342c945f13aacbe490225` (2017-05-08)
- License: no license file. GitHub license metadata is empty. The code was not copied and was not executed.
- Dataset terms: `readme.txt` says the bundled patient file is fictitious demonstration data and should be replaced by the user. The paper is https://pmc.ncbi.nlm.nih.gov/articles/PMC5077682/ (Journal of Biomedical Informatics, 2016).
- Evidence: documentation, plus an unresolved execution check. `matlab` and `octave` are absent on this machine. `mgist_main.m` reads `dummy_target_pop.txt` with `dlmread` and scores eligibility with a per-patient weight. The readme describes that file as 250 rows by 69 traits. The output is `results_table.csv` with per-trait sGIST values and one mGIST. A trait that is not an eligibility trait is written as 100.

Two marginal count tables do not supply the individual multi-trait rows or the dependence the metric uses. Running it would have required fabricating those rows, which would no longer be the shared input. GIST 2.0 therefore cannot be scored against the hand-derived gap interval.

### Closest discovery result: generalize

- Primary URL: https://github.com/benjamin-ackerman/generalize
- Commit: `53f1dc46eb576872e2685a26728854df96f87d14` (2025-10-30)
- Version named in the README: 0.1.3
- License: GitHub reports `NOASSERTION`. The fetched LICENSE file names a copyright holder and does not contain an OSI grant. The code was not executed.
- Dataset terms: not applicable to this probe. The package operates on a user-supplied stacked data frame.
- Evidence: documentation. `assess()` takes a stacked individual-level frame, selection covariates, and optionally survey weights. It returns covariate means, absolute standardized mean differences, participation probabilities, a Tipton generalizability index, and a trimmed-population count. `generalize()` estimates a target average treatment effect. Both steps need individual records and cross the MVP boundary against causal adjustment and generalizability claims.

Searches that surfaced it, Equiflow, ClinicalTrialEquity, and GIST:

- `GitHub clinical trial representativeness aggregate subgroup trial versus target bounds`
- `clinical trial generalizability aggregate marginal intersection Frechet bounds`
- `GitHub cohort composition comparison incomplete joint distributions oncology or mobility trial`

Related work that was reviewed and set aside as a different task: ROOT (underrepresentation defined with individual covariates and treatment-effect variance; https://github.com/CI-NYC/ROOT), TrialTwin (a single representation score from simulated enrollment; https://github.com/math12345678/trialtwin), and CTGATE's GIST tutorial (the same mGIST calculation on individual weighted records; https://ctgate.cci.fsu.edu/tutorials/tutorial-gist-2-0/). None accept two aggregate margins and return the hand-derived interval.

TrialStress, named in the playbook as a neighboring project, estimates study-design operating characteristics. CohortShift does not do that.

## What already matches, and what does not

Matching pieces are marginal count displays (Equiflow, ClinicalTrialEquity) and the idea of a study-versus-target subgroup rate (ClinicalTrialEquity, generalize, GIST). None of them, on the shared aggregate input, return -20, [-40, +20], and -25 with distinct known, bounded, and unavailable states.

Contributing the acceptance case upstream is a poor fit. Equiflow's object is an exclusion sequence of row-level frames. ClinicalTrialEquity's display deliberately fills a missing cross-classification with zero and then emits a parity score. GIST 2.0 and generalize require individual-level dependence or treatment outcomes that this MVP refuses. A new small R command keeps the aggregate-only contract enforceable.

## Provenance path

The fixture will be hand-specified integers committed in the repository, not a draw from clinical records. A manifest will record checksums. The generator seed is not applicable because the counts are specified, not sampled. Runtime analysis will read only local files.

Toolchain: R, base packages only. This environment has R 4.3.3 from the Ubuntu package `r-base` (2024-02-29). R is GPL software available without a paid service, including on GitHub Actions through `r-lib/actions/setup-r`. No CRAN package is required for the acceptance case. No remote dataset is required at run time.

## Remaining uncertainties

- GIST 2.0 was not executed. Matlab is not installed, and the repository has no license. The input description is specific enough to reject it for this acceptance case. A later license-compatible Matlab run would not change the input mismatch.
- generalize was not executed because its license grant is unclear and its documented input is individual-level.
- ClinicalTrialEquity's full Shiny sunburst was not started. The metric functions and the `replace_na(0)` merge were inspected at the cited commit. That is the behavior the two-variable display applies to a missing intersection.
- Equiflow's drift of 0.42 and 0.45 was observed, not re-derived. The failure is that those numbers are not the required percentage-point gaps.

## Decision

Proceed with the MVP in this repository. Do not narrow the acceptance case to a single representativeness score, and do not hold for an upstream contribution. The first release compares aggregate age and severity margins, labels intersection evidence as identified, bounded, or unavailable, and exports the assumptions with the source references.
