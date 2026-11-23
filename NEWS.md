# Changelog

## 0.1.0

First working release.

- Validate aggregate age and severity tables, including explicit missingness, mutually exclusive strata, and joint tables that must reproduce their margins.
- Compare a study table with a target table. Report marginal gaps in percentage points and label each intersection as identified, bounded, or unavailable.
- Replace bounds with an exact joint gap only when the joint reproduces both margins, and keep an observed zero distinct from a suppressed or absent cell.
- Export `result.json`, `summary.txt`, and `report.html`.
- Accept one predeclared target scenario without changing study counts or the study source reference.
- Ship fictional fixtures only. No individual records and no network access at run time.
