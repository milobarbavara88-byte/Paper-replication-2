# load_colleague_data.R  —  fold in the two verified files from the colleague
# ---------------------------------------------------------------------------
# Put these two files in  data/colleague/  first:
#   DKW_updates.csv   (the real Fed DKW output; source below)
#   Data.xlsx         (the Plante-Richter-Zubairy Dataverse deposit workbook)
#
# One time: install.packages("readxl")
# ---------------------------------------------------------------------------

library(readxl)

# ---- DKW decomposition (r*, real term premium, liquidity premium, ...) ----
# Public source: federalreserve.gov/econres/notes/feds-notes/DKW_updates.csv
# The file has ~15 description lines before the "date" header, so find it.

dkw_lines <- readLines("data/colleague/DKW_updates.csv")
dkw_skip  <- grep('^"?date"?,', dkw_lines)[1] - 1          # number of intro lines
dkw <- read.csv("data/colleague/DKW_updates.csv", skip = dkw_skip, na.strings = "NA")
dkw$date <- as.Date(dkw$date)

saveRDS(dkw, "data/dkw.rds")

# Columns you'll actually use (horizons available: 5, 10, 5f5 -- NOT 5f10):
#   exp.real.short.rate.10   real.term.prem.10   tips.liq.prem.10   (Table 1 "10 Year")
#   ...and the .5 / .5f5 versions. The 5f10y decomposition is NOT here (see checklist).


# ---- Plante-Richter-Zubairy panel: the whole Table 3 right-hand side ------
# Sheet "final", semiannual 1976-2025. "#N/A" is their missing code.

prz <- read_excel("data/colleague/Data.xlsx", sheet = "final", na = c("", "#N/A", "NA"))

# keep the columns Table 3 needs (RHS controls + the 5f10y nominal yield PRZ computed)
prz_table3 <- prz[, c("date",
                      "i5y10y_zc",     # 5-year-forward 10-year nominal yield
                      "debt_y5",       # CBO 5-year-ahead debt projection (% GDP)
                      "fed_gdp",       # Federal Reserve Treasury holdings (% GDP)
                      "foreign_gdp",   # foreign OFFICIAL holdings (% GDP)
                      "frbus_pi_y10",  # 10-year expected inflation (PTR)
                      "acm_tp_y10")]   # NY Fed ACM 10y term premium (validates our ACM)

saveRDS(prz_table3, "data/prz_table3.rds")


# ---- quick look -----------------------------------------------------------
cat("dkw  rows:", nrow(dkw), " dates:", format(min(dkw$date)), "->", format(max(dkw$date)), "\n")
cat("prz  rows:", nrow(prz_table3), "\n")
cat("prz  columns:", paste(names(prz_table3), collapse = ", "), "\n")

# Sanity: DKW 10-year components on the event days (should reproduce Table 1's
# "10 Year" columns after dividing by the ~2pp shock: exp r* ~1.20, real TP ~1.71)
e <- dkw[dkw$date %in% as.Date(c("2021-01-05","2021-01-06")), ]
cat("10y exp r* change (bp):", diff(e$exp.real.short.rate.10) * 100, "\n")
cat("10y real TP change (bp):", diff(e$real.term.prem.10) * 100, "\n")
