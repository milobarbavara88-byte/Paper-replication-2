# R/ — data pipeline

One script: `fetch_data.R`. Run it top to bottom.

## Setup (once)
```r
install.packages(c("fredr", "readr"))
```
Get a free FRED API key at https://fred.stlouisfed.org/docs/api/api_key.html
and paste it into the `fredr_set_key("...")` line at the top of the script.
(Don't commit your key — leave the placeholder in the committed copy.)

## Run
```r
Rscript R/fetch_data.R
```
It saves everything under `data/` as `.rds`:
`gdp`, `treast`, `foreign`, `nominal`, `tips` — the last two include the
5-year-forward 10-year rate (`y5f10`). The script prints row counts and the
Jan 5 vs Jan 6 2021 values at the end so you can see it worked.

See [`../DATA_CHECKLIST.md`](../DATA_CHECKLIST.md) for the full list of inputs
and how to get the ones this script doesn't cover (DKW, the PRZ deposit, PTR).
