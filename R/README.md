# R/ — data pipeline

Read [`../DATA_CHECKLIST.md`](../DATA_CHECKLIST.md) first: it lists every input
and the cleanest way to get each.

## Setup (once)
```r
install.packages(c("fredr", "readr", "dplyr", "lubridate", "dataverse"))
```
Put your FRED key in `~/.Renviron` (then restart R):
```
FRED_API_KEY=your_key_here
```

## Scripts
| Script | Does |
|---|---|
| `fetch_data.R` | **Groups 1–2**: pulls FRED (GDP, TREAST, FDHBFIN) via `fredr`, downloads the GSW nominal + TIPS curves from the **correct** Fed Board URLs, builds the `5f10y` series, saves R-native `.rds`. Failures print loudly; a summary prints at the end. |
| `check_data.R` | Integrity report: PASS/FAIL/MISSING per input, date coverage, the Jan 5→6 2021 event-study values, and an explicit "failed to extract" list. |
| `load_fred_manual.R` | Fallback only — ingest hand-downloaded FRED CSVs if `fredr` is unavailable. |

## Run
```r
Rscript R/fetch_data.R
Rscript R/check_data.R
```

## Not covered by the scripts (one manual fetch each — see checklist)
- **DKW output** (#6) — the r*/term-premium file from the "Tips from TIPS" FEDS Note.
- **PRZ deposit** (#8) — paste the Harvard Dataverse DOI and it wires into `dataverse::get_dataframe_by_name`.
- **PTR** (#9) — FRB/US package zip.

## Why the earlier all-NULL run
The GSW URL path was dead (`/econres/feds/files/…`). Corrected here to
`/data/yield-curve-tables/…`. That, plus using `fredr` for FRED instead of a
raw `read_csv(url)`, is what makes this run cleanly.
