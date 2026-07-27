# table3_projection.R  --  Table 3: the long-run projection regression
# ===========================================================================
# Three OLS regressions in FIRST DIFFERENCES (semiannual, ~1985-2025) of the
# 5f10y rate and its components on: CBO 5y-ahead debt + foreign holdings +
# Fed holdings + 10y expected inflation. Heteroskedasticity-robust SEs.
#
# All regressors come pre-assembled from the Plante-Richter-Zubairy deposit
# (data/prz_table3.rds). Run load_colleague_data.R first.
# One time: install.packages(c("sandwich", "lmtest"))
# ===========================================================================

library(sandwich); library(lmtest)

prz <- readRDS("data/prz_table3.rds")
prz <- prz[order(prz$date), ]                 # ensure time order for differencing

D <- function(x) c(NA, diff(x))               # first difference

df <- data.frame(
  d_yield5f10 = D(prz$i5y10y_zc) * 100,        # dependent (col 1), in basis points
  d_debt      = D(prz$debt_y5),                # the regressor of interest (pp of GDP)
  d_foreign   = D(prz$foreign_gdp),
  d_fed       = D(prz$fed_gdp),
  d_pi        = D(prz$frbus_pi_y10),
  d_rstar_5f5 = D(prz$dkw_rshort_y5y5) * 100,  # DKW real short rate at 5f5 (public)
  d_rtp_5f5   = D(prz$dkw_rtp_y5y5)   * 100    # DKW real term premium at 5f5 (public)
)

robust <- function(m) coeftest(m, vcov = vcovHC(m, type = "HC1"))

# ---- Table 3, column (1): the 5f10y nominal yield  (paper: debt coef 3.95) --
cat("== Table 3 col (1): 5f10y nominal yield ==   paper debt coefficient = 3.95\n")
m1 <- lm(d_yield5f10 ~ d_debt + d_foreign + d_fed + d_pi, data = df)
print(robust(m1))
cat("N =", nobs(m1), "\n")

# ---- Pipeline check: reproduce PRZ's OWN 5f5 decomposition (public DKW) -----
# Not the paper's 5f10y, but the parent paper's tenor -- confirms our regression
# machinery reproduces the literature it builds on. Expect r* ~1, real TP ~2.
cat("\n== Pipeline check: DKW 5f5 decomposition (PRZ's tenor) ==\n")
m2 <- lm(d_rstar_5f5 ~ d_debt + d_foreign + d_fed + d_pi, data = df)
m3 <- lm(d_rtp_5f5   ~ d_debt + d_foreign + d_fed + d_pi, data = df)
cat("5f5 Exp r*   debt coef:", round(coef(m2)["d_debt"], 2), "\n")
cat("5f5 Real T.P debt coef:", round(coef(m3)["d_debt"], 2), "\n")

# ---- Table 3, cols (2)(3): our 5f10y ACM decomposition (nominal, Novelty 5) -
# Disclosed extension: the paper's real 5f10y split is walled, so we substitute
# our ACM nominal split. ACM monthly series matched to each CBO-release month.
if (file.exists("data/acm_5f10_nominal_monthly.rds")) {
  acm <- readRDS("data/acm_5f10_nominal_monthly.rds")
  ym  <- function(d) format(as.Date(d), "%Y-%m")
  prz$rst <- acm$rstar_5f10[match(ym(prz$date), ym(acm$date))]
  prz$tp  <- acm$tp_5f10   [match(ym(prz$date), ym(acm$date))]
  df$d_rst <- D(prz$rst) * 100
  df$d_tp  <- D(prz$tp)  * 100
  cat("\n== Table 3 cols (2)(3): 5f10y ACM NOMINAL decomposition (ours) ==\n")
  cat("   (paper's real split: Exp r* 1.24, Real T.P. 1.74 -- shown for shape)\n")
  m4 <- lm(d_rst ~ d_debt + d_foreign + d_fed + d_pi, data = df)
  m5 <- lm(d_tp  ~ d_debt + d_foreign + d_fed + d_pi, data = df)
  cat("5f10 nominal exp-rate   debt coef:", round(coef(m4)["d_debt"], 2), "\n")
  cat("5f10 nominal term-prem  debt coef:", round(coef(m5)["d_debt"], 2), "\n")
} else {
  cat("\n(ACM output not found -- run R/acm_nominal.R for the 5f10y decomposition)\n")
}
