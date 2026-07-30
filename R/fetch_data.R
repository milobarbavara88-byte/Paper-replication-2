# fetch_data.R  —  get the data. Run top to bottom.
# ---------------------------------------------------------------------------
# One time, install the two packages (delete the # and run once):
# install.packages(c("fredr", "readr"))
# ---------------------------------------------------------------------------

library(fredr)

# Paste your FRED API key between the quotes:
fredr_set_key("PASTE_YOUR_FRED_KEY_HERE")

# Make a folder for the data
dir.create("data", showWarnings = FALSE)


# ---- FRED series (one line each) ------------------------------------------

gdp     <- fredr(series_id = "GDP")        # nominal GDP, quarterly
treast  <- fredr(series_id = "TREAST")     # Fed holdings of Treasuries
foreign <- fredr(series_id = "FDHBFIN")    # foreign-held federal debt

saveRDS(gdp,     "data/gdp.rds")
saveRDS(treast,  "data/treast.rds")
saveRDS(foreign, "data/foreign.rds")


# ---- GSW nominal Treasury curve -------------------------------------------
# Download the file, then read it. The first 9 lines are description, so skip them.
# "-999.99" is the file's code for "missing", so treat it as NA.

download.file("https://www.federalreserve.gov/data/yield-curve-tables/feds200628.csv",
              "data/feds200628.csv")

nominal <- read.csv("data/feds200628.csv", skip = 9, na.strings = c("NA", "-999.99"))

nominal$date  <- as.Date(nominal$Date)
nominal$y5f10 <- (15 * nominal$SVENY15 - 5 * nominal$SVENY05) / 10   # 5-yr-fwd 10-yr

saveRDS(nominal, "data/nominal.rds")


# ---- GSW TIPS (real) curve ------------------------------------------------

download.file("https://www.federalreserve.gov/data/yield-curve-tables/feds200805.csv",
              "data/feds200805.csv")

# NOTE: the TIPS file has 18 description lines before the table (the nominal one had 9).
tips <- read.csv("data/feds200805.csv", skip = 18, na.strings = c("NA", "-999.99"))

tips$date  <- as.Date(tips$Date)
tips$y5f10 <- (15 * tips$TIPSY15 - 5 * tips$TIPSY05) / 10

saveRDS(tips, "data/tips.rds")


# ---- quick look so you can see it worked ----------------------------------

cat("gdp     rows:", nrow(gdp),     "\n")
cat("treast  rows:", nrow(treast),  "\n")
cat("foreign rows:", nrow(foreign), "\n")
cat("nominal rows:", nrow(nominal), " last date:", format(max(nominal$date, na.rm = TRUE)), "\n")
cat("tips    rows:", nrow(tips),    " last date:", format(max(tips$date,    na.rm = TRUE)), "\n")

# The one-day event: 5f10y nominal on Jan 5 vs Jan 6, 2021 (should jump a few bp)
cat("nominal 5f10y  2021-01-05:", nominal$y5f10[nominal$date == as.Date("2021-01-05")], "\n")
cat("nominal 5f10y  2021-01-06:", nominal$y5f10[nominal$date == as.Date("2021-01-06")], "\n")
