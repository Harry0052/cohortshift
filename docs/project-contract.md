# Project contract

Status: active after the P01 proceed decision in `docs/overlap.md`.

## User task

A clinical research analyst loads aggregate age-band counts and severity counts for a synthetic study and a synthetic target population. The analyst sees each marginal count beside its denominator, the study share minus the target share in percentage points, the source reference, and an evidence state. For the age-by-severity intersection, the result says whether the cell is an exact joint count, a Fréchet range implied by the margins, or unavailable. The analyst can substitute one predeclared target mix and export the assumptions, the evidence states, and the unchanged study provenance.

## Minimum dependencies

- R >= 4.3, base packages only. Development and the local probe used R 4.3.3.
- No CRAN packages, no network call at run time, and no paid service.
- Input and output are local CSV, JSON, and HTML.

## Boundaries

In scope: fictional aggregate tables; schema checks; exact age buckets and severity definitions; marginal share differences; Fréchet–Hoeffding intersection bounds; exact joints only when they reproduce both margins; evidence labels that keep an observed zero apart from suppressed, absent, and unevaluable cells; a target-scenario substitution; a local HTML report and a JSON export.

Out of scope: individual records, imputed subgroup outcomes, causal adjustment, clinical recommendations, disease prediction, and any claim that a treatment effect generalizes.

## Measurable acceptance case

Fixture populations of 100. Study age 65+ count 30 and severe count 20. Target age 65+ count 50 and severe count 40. Complements are under 65 and not severe, and each variable's strata sum to its denominator.

Hand-derived results the implementation must match exactly:

- Marginal gaps, study share minus target share: -20 percentage points for age 65+, -20 percentage points for severe, +20 percentage points for under 65, and +20 percentage points for not severe.
- With no joint table, the age-65-plus and severe intersection is bounded. Study count lies in 0 to 20. Target count lies in 0 to 40. The study-minus-target gap lies in -40 to +20 percentage points.
- With a complete joint that reproduces both margins, study intersection 0 and target intersection 25, the observed gap is -25 percentage points. The study cell is an observed zero.
- Requested subgroups on this fixture are the four marginal strata plus the four age-by-severity cells. Coverage, the share of those eight with identified counts, is 1/2 when the joint is withheld and 1 when the complete compatible joint is used.

The same build must also reject a joint that does not reproduce a declared marginal, reject overlapping age intervals and mismatched severity definitions, and keep suppressed, absent, and unevaluable cells out of the observed-zero label. Changing only the target scenario may change target-derived fields and must leave study counts and study source references unchanged.

Arithmetic for the headline cell: study lower bound `max(0, 30 + 20 - 100) = 0`, upper bound `min(30, 20) = 20`. Target lower bound `max(0, 50 + 40 - 100) = 0`, upper bound `min(50, 40) = 40`. Gap lower bound `0/100 - 40/100 = -40` percentage points. Gap upper bound `20/100 - 0/100 = +20` percentage points. Exact gap `0/100 - 25/100 = -25` percentage points.

## Fixture provenance

Counts are hand-specified integers committed under `inst/fixtures/`. They are not sampled, so there is no generator seed. `inst/fixtures/manifest.json` records checksums, the synthetic-data terms, and the source label `synthetic`. No external table is redistributed.
