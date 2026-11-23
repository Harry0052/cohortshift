# Proof-case oracle

These figures are hand arithmetic on `inst/fixtures/proof/`. Counts are people. Gaps are study share minus target share, in percentage points. Both populations have denominator 100.

## Margins

| Stratum | Study | Target | Gap |
| --- | --- | --- | --- |
| under 65 | 70/100 | 50/100 | (70 - 50) = +20 |
| age 65+ | 30/100 | 50/100 | (30 - 50) = -20 |
| not severe | 80/100 | 60/100 | (80 - 60) = +20 |
| severe | 20/100 | 40/100 | (20 - 40) = -20 |

## Intersection bounds when the joint files are not used

For counts `a` and `b` in a population of `N`, the intersection lies between `max(0, a + b - N)` and `min(a, b)`.

Age 65+ and severe:

- Study: `max(0, 30 + 20 - 100) = 0` through `min(30, 20) = 20`.
- Target: `max(0, 50 + 40 - 100) = 0` through `min(50, 40) = 40`.
- Gap lower bound: `0/100 - 40/100 = -40`.
- Gap upper bound: `20/100 - 0/100 = +20`.

The cell is bounded. It is not an observed count, and it is not a zero.

Coverage uses eight requested subgroups: four marginal strata and four age-by-severity cells. With the joint withheld, four marginal counts are identified, so coverage is 4/8 = 1/2.

## Exact joint

`study_joint.csv` and `target_joint.csv` reproduce both margins.

Age 65+ and severe is 0 in the study and 25 in the target. The gap is `0/100 - 25/100 = -25`. The study cell is an observed zero because missingness is `observed` and the count is 0.

The other cells are study 30, 20, and 50 against target 25, 15, and 35. Each study margin is recovered: `0 + 30 = 30`, `20 + 50 = 70`, `0 + 20 = 20`, `30 + 50 = 80`. Each target margin is recovered: `25 + 25 = 50`, `15 + 35 = 50`, `25 + 15 = 40`, `25 + 35 = 60`.

With that complete joint, all eight requested subgroups are identified, so coverage is 1.

## Rejection cases

- `invalid/joint_mismatch.csv` against the study margins: severe cells are 25 and 0, which sum to 25, not the marginal severe count 20.
- `invalid/overlapping_age.csv`: `age_50_plus` is [50, Inf) and `age_65_plus` is [65, Inf). Those intervals overlap.
- `invalid/unsupported_age.csv`: `age_60_64` is not an exact supported bucket.
- An observed zero, a suppressed blank count, an absent cell, and a cell with no usable margin stay in different evidence states. `status/suppressed_joint.csv` leaves age 65+ and severe blank with missingness `suppressed`. That blank is not a zero, including when the other cells are numerically consistent with zero.
