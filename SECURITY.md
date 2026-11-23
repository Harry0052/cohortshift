# Security

CohortShift reads local CSV files and writes a report to a directory you choose. It does not authenticate to a service, and the repository must not contain credentials or clinical records.

## Reporting a vulnerability

Use GitHub private vulnerability reporting on [Harry0052/cohortshift](https://github.com/Harry0052/cohortshift). Do not open a public issue for a security report.

Include the version or commit, the command you ran, and the fixture if it is synthetic. Do not send personal data or a real extract.

## What the project checks

Input is parsed as text and rejected when it contains individual identifiers, a parent-directory segment in the output path, or a file above the size and row limits in `inst/schema/marginal-v1.json`. Those checks are not a substitute for reviewing the files you pass in.
