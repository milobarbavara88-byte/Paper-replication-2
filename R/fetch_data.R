# fetch_data.R  — corrected pipeline
# ---------------------------------------------------------------------------
# Replication data for Bhatt, Diercks, Eyal & Skaperdas (2026), FEDS 2026-031.
#
# Groups 1 & 2 of DATA_CHECKLIST.md run here unattended:
#   FRED (via fredr + API key) : GDP, Fed holdings, foreign holdings
#   Fed Board flat files       : GSW nominal + TIPS curves, then 5f10y
#
# WHY THE EARLIER RUN RETURNED ALL-NULL:
#   the GSW URL path was dead (/econres/feds/files/...). The live path is
#   /data/yield-curve-tables/... (confirmed across ~20 public repos). Fixed
#   below. Failures now print LOUDLY and a summary prints at the end — no more
#   silent NULLs.
#
# SETUP (once):
#   install.packages(c("fredr","readr","dplyr","lubridate"))
#   # put this line in ~/.Renviron  (then restart R):
#   #   FRED_API_KEY=your_key_here
#
# RUN:
#   Rscript R/fetch_data.R      (or source it in RStudio)
# ---------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  library(readr); library(dplyr); library(lubridate)
}))

dir.create("data/raw",     recursive = TRUE, showWarnings = FALSE)
dir.create("data/derived", recursive = TRUE, showWarnings = FALSE)

results <- character(0)
ok   <- function(x) { results[[length(results)+1]] <<- paste0("OK    ", x); message("  [OK]   ", x) }
bad  <- function(x, e) { results[[length(results)+1]] <<- paste0("FAIL  ", x, "  <- ", conditionMessage(e)); message("  [FAIL] ", x, ": ", conditionMessage(e)) }
try2 <- function(label, expr) tryCatch({ v <- force(expr); ok(label); v }, error = function(e) { bad(label, e); NULL })

# ===========================================================================
# GROUP 1 — FRED via fredr + API key
# ===========================================================================
message("[1] FRED (fredr) ...")
fred_ok <- requireNamespace("fredr", quietly = TRUE)
if (!fred_ok) message("  [FAIL] package 'fredr' not installed: install.packages('fredr')")
key <- Sys.getenv("FRED_API_KEY")
if (fred_ok && nzchar(key)) fredr::fredr_set_key(key)
if (fred_ok && !nzchar(key)) message("  [FAIL] FRED_API_KEY not set in ~/.Renviron")

get_fred <- function(id) {
  stopifnot(fred_ok, nzchar(key))
  df <- fredr::fredr(series_id = id)          # tibble: date, series_id, value, ...
  tibble(date = as.Date(df$date), value = as.numeric(df$value)) |> filter(!is.na(value))
}

controls <- list(
  gdp      = try2("FRED GDP (nominal GDP)",            get_fred("GDP")),
  fed_hold = try2("FRED TREAST (Fed Treasury holds)",  get_fred("TREAST")),
  foreign  = try2("FRED FDHBFIN (foreign-held debt)",  get_fred("FDHBFIN"))
)
controls <- controls[!vapply(controls, is.null, logical(1))]
if (length(controls)) saveRDS(controls, "data/raw/controls_fred.rds")

# ===========================================================================
# GROUP 2 — GSW nominal & TIPS curves (Fed Board flat files)
# ===========================================================================
message("[2] GSW curves (Fed Board) ...")

# Fed Board CSVs have a ~9-line descriptive preamble; the real header starts
# "Date,". Detect it (robust to the preamble differing between the two files)
# and treat both "NA" and the GSW sentinel -999.99 as missing.
read_gsw <- function(url) {
  tmp <- tempfile(fileext = ".csv")
  utils::download.file(url, tmp, quiet = TRUE)         # download.file's UA is accepted by the Board
  lines <- readr::read_lines(tmp)
  hdr   <- which(grepl("^Date,", lines))[1]
  if (is.na(hdr)) stop("no 'Date,' header row (URL may have moved)")
  readr::read_csv(paste(lines[hdr:length(lines)], collapse = "\n"),
                  na = c("", "NA", "-999.99"), show_col_types = FALSE, guess_max = 200000)
}

url_nom  <- "https://www.federalreserve.gov/data/yield-curve-tables/feds200628.csv"
url_tips <- "https://www.federalreserve.gov/data/yield-curve-tables/feds200805.csv"

gsw_nom  <- try2("GSW nominal (feds200628)", read_gsw(url_nom))
gsw_tips <- try2("GSW TIPS (feds200805)",    read_gsw(url_tips))
if (!is.null(gsw_nom))  saveRDS(gsw_nom,  "data/raw/gsw_nominal.rds")
if (!is.null(gsw_tips)) saveRDS(gsw_tips, "data/raw/gsw_tips.rds")

# 5f10y = (15*y15 - 5*y5)/10  (exact for continuously-compounded zeros).
make_5f10 <- function(df, y5, y15) {
  stopifnot(all(c("Date", y5, y15) %in% names(df)))
  d <- tibble(date = as.Date(df$Date),
              y5   = as.numeric(df[[y5]]),
              y15  = as.numeric(df[[y15]]))
  d$y5[d$y5 <= -999]  <- NA          # guard any residual sentinel
  d$y15[d$y15 <= -999] <- NA
  d$y5f10 <- (15 * d$y15 - 5 * d$y5) / 10
  d[!is.na(d$y5f10), c("date", "y5f10")]
}

if (!is.null(gsw_nom)) {
  x <- try2("5f10y nominal", make_5f10(gsw_nom, "SVENY05", "SVENY15"))
  if (!is.null(x)) saveRDS(x, "data/derived/nominal_5f10y.rds")
}
if (!is.null(gsw_tips)) {
  x <- try2("5f10y TIPS", make_5f10(gsw_tips, "TIPSY05", "TIPSY15"))
  if (!is.null(x)) saveRDS(x, "data/derived/tips_5f10y.rds")
}

# ===========================================================================
# GROUPS 3-7 — not automatable from here (see DATA_CHECKLIST.md):
#   #6  DKW output       -> FEDS Note "Tips from TIPS" data file -> data/raw/dkw_output.*
#   #8  PRZ Table 3 panel-> dataverse::get_dataframe_by_name(<PRZ DOI>) [paste the DOI]
#   #9  PTR              -> FRB/US package zip, extract PTR column
#   #10 PredictIt        -> MSS/H&H files or Wayback
#   #11-13 walled        -> Novelties 3/4/5/6
# ===========================================================================

message("\n================  FETCH SUMMARY  ================")
for (r in results) message(r)
message("Saved under data/. Now run:  Rscript R/check_data.R")
