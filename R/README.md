# R/ — data pipeline

## Files
- `fetch_data.R` — pulls every public input from its exact primary source and
  stores it R-natively under `data/raw/` and `data/derived/`. Also builds the
  5-year-forward 10-year (`5f10y`) series for the nominal and TIPS curves.

## Run
```r
install.packages(c("readr", "dplyr", "lubridate"))
Rscript R/fetch_data.R
```

## Why the data isn't already in this repo
This repo was assembled in a sandbox whose network policy blocks every economic-
data host (federalreserve.gov, fred.stlouisfed.org, bea.gov, cbo.gov,
dataverse.harvard.edu) — only GitHub and package registries were reachable. The
script therefore could not be executed there. Run it locally, or in an
environment that allows those hosts, and `data/` populates end-to-end. Full
provenance, access status, and the walled items are documented in
[`../DATA_SOURCES.md`](../DATA_SOURCES.md).

## Output layout
```
data/
  raw/       gsw_nominal.rds, gsw_tips.rds, controls_fred.rds
  derived/   nominal_5f10y.rds, tips_5f10y.rds
```
Items requiring hand-collection or author correspondence (DKW output, PTR, CBO
vintages, PredictIt, Hazell–Hobler cross-section) are flagged as explicit stubs
inside `fetch_data.R` rather than silently omitted.
