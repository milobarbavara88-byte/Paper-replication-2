# table1_eventstudy.R  --  Table 1: the one-day Georgia-runoff event study
# ===========================================================================
# Each number is ONE subtraction: the Jan 5 -> Jan 6 2021 change in a yield (or
# a component), in basis points, divided by the fiscal shock (~2pp of GDP).
# No regression. Run fetch_data.R and load_colleague_data.R first.
# ===========================================================================

tips <- readRDS("data/tips.rds")     # GSW TIPS curve (has TIPSY10, y5f10)
dkw  <- readRDS("data/dkw.rds")      # DKW real components (10y is what we use)
gdp  <- readRDS("data/gdp.rds")      # nominal GDP (for the shock denominator)

# ---- the shock: 0.5 * $900bn / nominal GDP(2021Q1) * 100  (~2pp of GDP) ----
ngdp  <- gdp$value[gdp$date == as.Date("2021-01-01")]
shock <- 0.5 * 900 / ngdp * 100
cat("nominal GDP 2021Q1 = $", round(ngdp), "bn   ->   shock =",
    round(shock, 3), "pp of GDP\n", sep = "")

# ---- one helper: (Jan6 - Jan5) in basis points, per 1pp of shock -----------
d5 <- as.Date("2021-01-05");  d6 <- as.Date("2021-01-06")
elast <- function(x, dt) {
  (x[dt == d6] - x[dt == d5]) * 100 / shock   # x is in %, *100 = bp, /shock = per pp
}

# ---- 10-YEAR row (real): fully replicable from public data -----------------
cat("\n== 10 YEAR (real) ==   paper: TIPS 2.58, Exp r* 1.20, Real T.P. 1.71\n")
cat("TIPS 10y    :", round(elast(tips$TIPSY10,                 tips$date), 2), "\n")
cat("Exp r* 10y  :", round(elast(dkw$exp.real.short.rate.10,   dkw$date),  2), "\n")
cat("Real T.P.10y:", round(elast(dkw$real.term.prem.10,        dkw$date),  2), "\n")

# ---- 5f10y row: the real YIELD response is replicable ----------------------
cat("\n== 5f10y (real yield) ==   paper: TIPS 3.96\n")
cat("TIPS 5f10y  :", round(elast(tips$y5f10, tips$date), 2), "\n")

# ---- 5f10y decomposition: our ACM (NOMINAL) -- Novelty 5, disclosed --------
# The paper's REAL 5f10y split (Exp r* 1.64, Real T.P. 2.61) uses DKW internals
# that are not public at this horizon. Our ACM gives the NOMINAL split instead;
# report it as an extension, not as the paper's number.
if (file.exists("data/acm_5f10_nominal.rds")) {
  acm <- readRDS("data/acm_5f10_nominal.rds")
  cat("\n== 5f10y decomposition -- ACM NOMINAL (ours, not the paper's real split) ==\n")
  cat("   (paper's real split, for shape only: Exp r* 1.64, Real T.P. 2.61)\n")
  cat("nominal term premium :", round(elast(acm$tp_5f10,    acm$date), 2), "\n")
  cat("nominal expected-rate:", round(elast(acm$rstar_5f10, acm$date), 2), "\n")
} else {
  cat("\n(ACM output not found -- run R/acm_nominal.R to fill the 5f10y split)\n")
}

# ---- sensitivity to the shock size (decisions-log item 1) ------------------
cat("\nSensitivity: at shock = 2.1pp every number above scales by",
    round(shock / 2.1, 3), "\n")
