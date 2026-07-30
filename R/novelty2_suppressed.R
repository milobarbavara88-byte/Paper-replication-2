# novelty2_suppressed.R  --  recover the two decomposition columns the paper drops
# ===========================================================================
# The paper reports only the expected-real-short-rate (r*) and real-term-premium
# responses, and suppresses the expected-inflation and inflation-risk-premium
# columns (it defers to Hazell-Hobler on inflation). The DKW output carries all
# four, so we recover the missing two -- and get a free diagnostic: the four
# components must SUM to the nominal response. If they do, our DKW alignment and
# our choice of the r* object are correct.
#
# Needs data/dkw.rds, data/gdp.rds, data/prz_table3.rds (re-run load_colleague_data.R
# first so the 5f5 inflation columns are present).  install.packages(c("sandwich","lmtest")).
# ===========================================================================

# ---- (a) event study, 10-year (Table 1) -----------------------------------
dkw <- readRDS("data/dkw.rds")
gdp <- readRDS("data/gdp.rds")
ngdp  <- gdp$value[gdp$date == as.Date("2021-01-01")]
shock <- 0.5 * 900 / ngdp * 100
d5 <- as.Date("2021-01-05");  d6 <- as.Date("2021-01-06")
el <- function(col) (dkw[[col]][dkw$date == d6] - dkw[[col]][dkw$date == d5]) * 100 / shock

cat("== Novelty 2a: event study (10y) -- the two suppressed columns ==\n")
cat("Expected inflation  :", round(el("exp.inflation.10"),      2), "\n")
cat("Inflation risk prem :", round(el("inflation.risk.prem.10"), 2), "\n")

four <- el("exp.real.short.rate.10") + el("real.term.prem.10") +
        el("exp.inflation.10")       + el("inflation.risk.prem.10")
cat("SUM of four components:", round(four, 2),
    "  vs nominal fitted:", round(el("nominal.yield.fitted.10"), 2),
    "  gap:", round(four - el("nominal.yield.fitted.10"), 3), "(want ~0)\n")

# ---- (b) projection regression, 5f5 tenor (Table 3) -----------------------
suppressWarnings(suppressMessages({ library(sandwich); library(lmtest) }))
prz <- readRDS("data/prz_table3.rds");  prz <- prz[order(prz$date), ]
D <- function(x) c(NA, diff(x))
b <- data.frame(
  date     = as.Date(prz$date),
  d_debt   = D(prz$debt_y5), d_foreign = D(prz$foreign_gdp),
  d_fed    = D(prz$fed_gdp), d_pi = D(prz$frbus_pi_y10),
  d_rshort = D(prz$dkw_rshort_y5y5) * 100, d_rtp  = D(prz$dkw_rtp_y5y5)  * 100,
  d_epi    = D(prz$dkw_epi_y5y5)    * 100, d_pirp = D(prz$dkw_pirp_y5y5) * 100,
  d_ifit   = D(prz$dkw_ifit_y5y5)   * 100
)
b <- subset(b, date >= as.Date("1985-01-01") & date <= as.Date("2025-01-31"))
dcoef <- function(dep)
  round(coef(lm(reformulate(c("d_debt","d_foreign","d_fed","d_pi"), dep), b))["d_debt"], 2)

cat("\n== Novelty 2b: projection (5f5) -- the two suppressed columns ==\n")
cat("Expected inflation  debt coef:", dcoef("d_epi"),  "\n")
cat("Inflation risk prem debt coef:", dcoef("d_pirp"), "\n")
s4 <- dcoef("d_rshort") + dcoef("d_rtp") + dcoef("d_epi") + dcoef("d_pirp")
cat("SUM of four component coefs:", round(s4, 2),
    "  vs nominal (ifit) coef:", dcoef("d_ifit"), "(should match)\n")
