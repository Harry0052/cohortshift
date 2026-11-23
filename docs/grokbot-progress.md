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
