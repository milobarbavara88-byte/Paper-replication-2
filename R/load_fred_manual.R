# load_fred_manual.R
# ---------------------------------------------------------------------------
# Ingest MANUALLY-downloaded FRED CSVs (because the automated fredgraph pull
# failed) and fold them into data/raw/controls_fred.rds, R-native.
#
# HOW TO USE
#   1. Download each series below from FRED as CSV (the blue "Download" button
#      on the series page -> CSV). Keep the default file name or rename freely.
#   2. Put the CSVs in   data/raw/fred/   (create the folder).
#   3. Rscript R/load_fred_manual.R
#
# WHICH SERIES (Table 3 / equation 2 controls, paper footnote 9):
#   GDP       Nominal GDP (denominator for all shares, quarterly, $bn, SAAR)
#             page:     https://fred.stlouisfed.org/series/GDP
#             csv:      https://fred.stlouisfed.org/graph/fredgraph.csv?id=GDP
#   TREAST    Fed holdings of U.S. Treasury securities (H.4.1, weekly, $mn)
#             page:     https://fred.stlouisfed.org/series/TREAST
#             csv:      https://fred.stlouisfed.org/graph/fredgraph.csv?id=TREAST
#             NOTE: splice Fries (2018) for the pre-2018Q2 stretch the paper uses.
#   FDHBFIN   Federal Debt Held by Foreign & International Investors (Z.1-related,
#             quarterly, $bn) -- pragmatic stand-in for "foreign OFFICIAL"
#             holdings. Confirm the official-vs-total distinction against the
#             Plante-Richter-Zubairy panel before finalising.
#             page:     https://fred.stlouisfed.org/series/FDHBFIN
#             csv:      https://fred.stlouisfed.org/graph/fredgraph.csv?id=FDHBFIN
#
# NOT ON FRED (do not look for these there):
#   PTR   -> FRB/US data package (federalreserve.gov/econres/us-models-package.htm)
#   CBO 5y-ahead debt projections -> CBO archive or Plante-Richter-Zubairy deposit
# ---------------------------------------------------------------------------

suppressWarnings(suppressMessages({ library(readr) }))

fred_dir <- "data/raw/fred"
if (!dir.exists(fred_dir)) stop("Put the downloaded FRED CSVs in ", fred_dir, "/ first.")

# Map series id -> the list slot name used elsewhere in the pipeline.
id_to_slot <- c(GDP = "gdp", TREAST = "fed_hold", FDHBFIN = "foreign")

read_one <- function(path) {
  df <- suppressMessages(read_csv(path, show_col_types = FALSE))
  # FRED CSVs are 2 columns: a date column (DATE/observation_date) + the series.
  names(df)[1] <- "date"
  df$date <- as.Date(df$date)
  df[[2]]  <- suppressWarnings(as.numeric(df[[2]]))
  df
}

files <- list.files(fred_dir, pattern = "\\.csv$", full.names = TRUE, ignore.case = TRUE)
if (!length(files)) stop("No .csv files found in ", fred_dir)

controls <- if (file.exists("data/raw/controls_fred.rds")) readRDS("data/raw/controls_fred.rds") else list()

for (f in files) {
  df  <- read_one(f)
  sid <- names(df)[2]                                   # the FRED column name = series id
  slot <- id_to_slot[[toupper(sid)]] %||% tolower(sid)  # fall back to the id itself
  controls[[slot]] <- df
  message(sprintf("  loaded %-10s (%s) -> slot '%s', %d rows, %s..%s",
                  sid, basename(f), slot, nrow(df), min(df$date, na.rm=TRUE), max(df$date, na.rm=TRUE)))
}
`%||%` <- function(a,b) if (is.null(a)) b else a

dir.create("data/raw", showWarnings = FALSE, recursive = TRUE)
saveRDS(controls, "data/raw/controls_fred.rds")
message("\nSaved data/raw/controls_fred.rds with slots: ", paste(names(controls), collapse = ", "))
message("Re-run R/check_data.R to verify.")
