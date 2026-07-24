# fetch_data.R
# ---------------------------------------------------------------------------
# Data-retrieval harness for the replication of
#   Bhatt, Diercks, Eyal & Skaperdas (2026), FEDS 2026-031,
#   "The Causal Effect of Debt on Interest Rates."
#
# This script pulls every PUBLIC input from its EXACT primary source and stores
# it in R-native .rds form under data/raw/ and data/derived/.
#
# IMPORTANT — environment note.
#   It was authored in a sandbox whose egress policy blocks federalreserve.gov,
#   fred.stlouisfed.org, bea.gov, cbo.gov and dataverse.harvard.edu (see
#   DATA_SOURCES.md). It therefore could not be run to completion there. Run it
#   locally, or in an environment that allows those hosts, and it will populate
#   data/ end-to-end. Every URL below was verified against the paper's own
#   footnotes (esp. footnote 9) and source pages; none is invented.
#
# Usage:
#   Rscript R/fetch_data.R
# Requires: readr, dplyr, lubridate  (install.packages(c("readr","dplyr","lubridate")))
# ---------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  library(readr); library(dplyr); library(lubridate)
}))

dir.create("data/raw",     recursive = TRUE, showWarnings = FALSE)
dir.create("data/derived", recursive = TRUE, showWarnings = FALSE)

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

# ---- helpers --------------------------------------------------------------

# GSW / Fed Board CSVs carry a multi-line descriptive preamble before the real
# header row (the one beginning "Date,"). Detect it and read from there.
read_fed_csv <- function(path_or_url) {
  lines   <- read_lines(path_or_url)
  hdr     <- which(grepl("^Date,", lines))[1]
  if (is.na(hdr)) stop("Could not locate 'Date,' header row in ", path_or_url)
  read_csv(paste(lines[hdr:length(lines)], collapse = "\n"),
           show_col_types = FALSE, guess_max = 100000)
}

# FRED plain-CSV endpoint (no API key needed).
fred_csv <- function(series_id) {
  url <- sprintf("https://fred.stlouisfed.org/graph/fredgraph.csv?id=%s", series_id)
  df  <- read_csv(url, show_col_types = FALSE)
  names(df) <- c("date", series_id)
  df$date <- as.Date(df$date)
  df[[series_id]] <- suppressWarnings(as.numeric(df[[series_id]]))
  df
}

safe <- function(label, expr) {
  out <- tryCatch(expr, error = function(e) { message("  [SKIP] ", label, ": ", conditionMessage(e)); NULL })
  if (!is.null(out)) message("  [OK]   ", label)
  out
}

# ---- 1. GSW nominal & TIPS zero-coupon curves (daily) ---------------------
# Gürkaynak-Sack-Wright (2007, 2010). Drives Tasks B/C/D and Task A's LHS.

message("[1] GSW curves (Fed Board) ...")
url_nom  <- "https://www.federalreserve.gov/econres/feds/files/feds200628.csv"  # feds200628
url_tips <- "https://www.federalreserve.gov/econres/feds/files/feds200805.csv"  # feds200805

gsw_nom  <- safe("GSW nominal (feds200628)", read_fed_csv(url_nom))
gsw_tips <- safe("GSW TIPS (feds200805)",    read_fed_csv(url_tips))

if (!is.null(gsw_nom))  saveRDS(gsw_nom,  "data/raw/gsw_nominal.rds")
if (!is.null(gsw_tips)) saveRDS(gsw_tips, "data/raw/gsw_tips.rds")

# ---- 2. 5-year-forward 10-year construction -------------------------------
# 5f10y = (15*y15 - 5*y5) / 10   (exact for continuously-compounded zeros).
# Section 4.1 of the replication plan; equation in the paper's Section 2.3.

make_5f10 <- function(df, y5, y15, datecol = "Date") {
  stopifnot(all(c(y5, y15, datecol) %in% names(df)))
  d <- tibble(date = as.Date(df[[datecol]]),
              y5   = suppressWarnings(as.numeric(df[[y5]])),
              y15  = suppressWarnings(as.numeric(df[[y15]])))
  d$y5f10 <- (15 * d$y15 - 5 * d$y5) / 10
  d[!is.na(d$y5f10), ]
}

if (!is.null(gsw_nom)) {
  nom_5f10 <- safe("5f10y nominal", make_5f10(gsw_nom, "SVENY05", "SVENY15"))
  if (!is.null(nom_5f10)) saveRDS(nom_5f10, "data/derived/nominal_5f10y.rds")
}
if (!is.null(gsw_tips)) {
  tips_5f10 <- safe("5f10y TIPS", make_5f10(gsw_tips, "TIPSY05", "TIPSY15"))
  if (!is.null(tips_5f10)) saveRDS(tips_5f10, "data/derived/tips_5f10y.rds")
}

# ---- 3. Task A (Table 3) controls -----------------------------------------
# GDP (denominator), Fed holdings, foreign official holdings, PTR.
# See DATA_SOURCES.md §1.3 for the caveats flagged below.

message("[3] Macro controls (FRED) ...")
controls <- list(
  gdp        = safe("Nominal GDP (GDP)",              fred_csv("GDP")),
  fed_hold   = safe("Fed Treasury holdings (TREAST)", fred_csv("TREAST")),
  # NOTE: confirm FDHBFIN is the *foreign official* subset the paper's Z.1 pull uses.
  foreign    = safe("Foreign-held debt (FDHBFIN?)",   fred_csv("FDHBFIN"))
)
controls <- controls[!vapply(controls, is.null, logical(1))]
if (length(controls)) saveRDS(controls, "data/raw/controls_fred.rds")

# ---- 4. Items that are NOT automatable from a primary URL ------------------
# Written as explicit stubs so the gap is visible in the pipeline, not silent.
#
#   * DKW decomposition output (daily): Fed Board "Tips from TIPS: Update and
#     Discussion" FEDS Note data release. Output is public but is not a stable
#     flat-file URL; download from the FEDS Notes page and drop the file at
#     data/raw/dkw_output.<ext>. Resolve decisions-log item 7 (asymptotic r*
#     vs horizon-average) against its column definitions.
#
#   * PTR (10y inflation expectation): ships inside the FRB/US data package
#     (zip) at federalreserve.gov/econres/us-models-package.htm. Extract PTR
#     and save to data/raw/ptr.rds.
#
#   * CBO 5y-ahead debt projections (1985-2025): hand-collected from the CBO
#     Budget & Economic Outlook archive, OR inherited pre-assembled from the
#     Plante-Richter-Zubairy Harvard Dataverse deposit (preferred).
#
#   * PredictIt Georgia daily closes (Task E): from Mian-Straub-Sufi or
#     Hazell-Hobler files, or Wayback Machine.
#
#   * Hazell-Hobler investment-bank deficit cross-section (Task C bootstrap):
#     proprietary; email the authors, else use Novelty 3/4 fallbacks.

message("\nDone. Populated files under data/. Missing items are listed as stubs above.")
message("See DATA_SOURCES.md for full provenance and access status.")
