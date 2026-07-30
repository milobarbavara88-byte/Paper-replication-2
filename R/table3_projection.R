# table3_projection.R  --  Table 3: the long-run projection regression
# ===========================================================================
# Three OLS regressions in FIRST DIFFERENCES (semiannual) of the 5f10y rate and
# its components on: CBO 5y-ahead debt + foreign holdings + Fed holdings + 10y
# expected inflation. Heteroskedasticity-robust (HC1) SEs. Regressors come
# pre-assembled from the Plante-Richter-Zubairy deposit (data/prz_table3.rds).
#
# Reported two ways:
#   BASELINE  = the paper's window (Feb 1985 - Jan 2025)  -> validates 3.95
#   EXTENSION = the full PRZ sample (~1976 on)            -> Novelty 1 direction
#
# One time: install.packages(c("sandwich", "lmtest")).  Run load_colleague_data.R
# and (for the decomposition rows) acm_nominal.R first.
# ===========================================================================

library(sandwich); library(lmtest)

prz <- readRDS("data/prz_table3.rds")
prz <- prz[order(prz$date), ]                 # time order for differencing

D <- function(x) c(NA, diff(x))               # first difference

df <- data.frame(
  date        = as.Date(prz$date),
  d_yield5f10 = D(prz$i5y10y_zc) * 100,        # dependent (col 1), basis points
  d_debt      = D(prz$debt_y5),                # regressor of interest (pp of GDP)
  d_foreign   = D(prz$foreign_gdp),
  d_fed       = D(prz$fed_gdp),
  d_pi        = D(prz$frbus_pi_y10),
  d_rstar_5f5 = D(prz$dkw_rshort_y5y5) * 100,  # DKW real short rate at 5f5 (public)
  d_rtp_5f5   = D(prz$dkw_rtp_y5y5)   * 100    # DKW real term premium at 5f5 (public)
)

# attach our ACM 5f10y nominal decomposition (matched by year-month), if present
if (file.exists("data/acm_5f10_nominal_monthly.rds")) {
  acm <- readRDS("data/acm_5f10_nominal_monthly.rds")
  ym  <- function(d) format(as.Date(d), "%Y-%m")
  prz$rst  <- acm$rstar_5f10[match(ym(prz$date), ym(acm$date))]
  prz$tp   <- acm$tp_5f10   [match(ym(prz$date), ym(acm$date))]
  df$d_rst <- D(prz$rst) * 100
  df$d_tp  <- D(prz$tp)  * 100
}

robust  <- function(m) coeftest(m, vcov = vcovHC(m, type = "HC1"))
debtcof <- function(dep, data)                # quick "debt coefficient" print
  round(coef(lm(reformulate(c("d_debt","d_foreign","d_fed","d_pi"), dep), data))["d_debt"], 2)

# ===== BASELINE: the paper's sample =========================================
base <- subset(df, date >= as.Date("1985-01-01") & date <= as.Date("2025-01-31"))

cat("===== BASELINE  (paper window ~Feb 1985 - Jan 2025) =====\n")
cat("== col (1): 5f10y nominal yield ==   paper: debt 3.95, N = 84\n")
m1 <- lm(d_yield5f10 ~ d_debt + d_foreign + d_fed + d_pi, data = base)
print(robust(m1));  cat("N =", nobs(m1), "\n")

cat("\n== 5f5 DKW decomposition (pipeline check; public) ==\n")
cat("Exp r*   debt coef:", debtcof("d_rstar_5f5", base), "\n")
cat("Real T.P debt coef:", debtcof("d_rtp_5f5",   base), "\n")

if ("d_tp" %in% names(df)) {
  cat("\n== 5f10y ACM NOMINAL decomposition (ours) ==",
      "\n   paper's real split for shape: Exp r* 1.24, Real T.P. 1.74\n")
  cat("nominal exp-rate   debt coef:", debtcof("d_rst", base), "\n")
  cat("nominal term-prem  debt coef:", debtcof("d_tp",  base), "\n")
}

# ===== EXTENSION: full sample (does the debt-rate link look different?) ======
cat("\n===== EXTENSION  (full PRZ sample, ~1976 on) =====\n")
m1f <- lm(d_yield5f10 ~ d_debt + d_foreign + d_fed + d_pi, data = df)
cat("col (1) debt coef:", round(coef(m1f)["d_debt"], 2), "  N =", nobs(m1f), "\n")
cat("(baseline was", round(coef(m1)["d_debt"], 2),
    "-- if these differ, the sample window matters: Novelty 1)\n")
