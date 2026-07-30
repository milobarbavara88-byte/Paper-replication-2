# ===========================================================================
# The Causal Effect of Debt on Interest Rates -- a replication in R
# Bhatt, Diercks, Eyal & Skaperdas (2026), FEDS 2026-031
# ---------------------------------------------------------------------------
# Reproduces the paper's three public exercises and extends them:
#   Table 1  one-day Georgia-runoff event study (10y exact; 5f10y yield exact)
#   Task C   placebo-bootstrap p-values for Table 1
#   Table 3  long-run projection regression (paper window + full-sample extension)
#   ACM      an independent term-structure model for the 5f10y decomposition
#   +        the two decomposition columns the paper suppresses, and a
#            structural-break test of the debt coefficient
#
# Data: FRED (via the API key below) and the Gurkaynak-Sack-Wright curves are
# downloaded at run time; the DKW decomposition and the Plante-Richter-Zubairy
# panel travel with this repository under data/.
#
# Packages: fredr, readxl, sandwich, lmtest, strucchange
# ===========================================================================

library(fredr); library(readxl); library(sandwich); library(lmtest); library(strucchange)

fredr_set_key("2dc39adca864462a604d64d7ea499289")
dir.create("data", showWarnings = FALSE)
set.seed(20210106)

# ===========================================================================
# 1. DATA
# ===========================================================================

# --- FRED: nominal GDP, Federal Reserve and foreign Treasury holdings --------
gdp     <- fredr(series_id = "GDP")
treast  <- fredr(series_id = "TREAST")
foreign <- fredr(series_id = "FDHBFIN")

# --- Gurkaynak-Sack-Wright nominal curve (9 header lines; -999.99 = missing) -
download.file("https://www.federalreserve.gov/data/yield-curve-tables/feds200628.csv",
              "data/feds200628.csv")
nominal <- read.csv("data/feds200628.csv", skip = 9, na.strings = c("NA", "-999.99"))
nominal$date  <- as.Date(nominal$Date)
nominal$y5f10 <- (15 * nominal$SVENY15 - 5 * nominal$SVENY05) / 10

# --- Gurkaynak-Sack-Wright TIPS (real) curve (18 header lines) ---------------
download.file("https://www.federalreserve.gov/data/yield-curve-tables/feds200805.csv",
              "data/feds200805.csv")
tips <- read.csv("data/feds200805.csv", skip = 18, na.strings = c("NA", "-999.99"))
tips$date  <- as.Date(tips$Date)
tips$y5f10 <- (15 * tips$TIPSY15 - 5 * tips$TIPSY05) / 10

# --- DKW decomposition (r*, real term premium, inflation components) ---------
dkw_lines <- readLines("data/DKW_updates.csv")
dkw <- read.csv("data/DKW_updates.csv",
                skip = grep('^"?date"?,', dkw_lines)[1] - 1, na.strings = "NA")
dkw$date <- as.Date(dkw$date)

# --- Plante-Richter-Zubairy panel: the Table 3 right-hand side ---------------
prz <- read_excel("data/Data.xlsx", sheet = "final", na = c("", "#N/A", "NA"))
prz <- prz[order(prz$date), ]

# --- the fiscal shock: 0.5 * $900bn / nominal GDP(2021Q1), in points of GDP --
ngdp  <- gdp$value[gdp$date == as.Date("2021-01-01")]
shock <- 0.5 * 900 / ngdp * 100

# ===========================================================================
# 2. ACM TERM-STRUCTURE MODEL (nominal curve)
# ---------------------------------------------------------------------------
# The public DKW file stops at the 10-year horizon, so the paper's 5-year-forward
# 10-year decomposition is estimated here with the Adrian-Crump-Moench model
# (principal components + OLS). Nominal curve only: it decomposes the nominal,
# not the real, 5f10y. Validated below against the New York Fed's ACM 10y series.
# ===========================================================================

nom <- nominal[complete.cases(nominal[, c("BETA0","BETA1","BETA2","BETA3","TAU1","TAU2")]), ]

svensson <- function(m, b0, b1, b2, b3, t1, t2) {
  f1 <- (1 - exp(-m/t1)) / (m/t1)
  f2 <- f1 - exp(-m/t1)
  f3 <- (1 - exp(-m/t2)) / (m/t2) - exp(-m/t2)
  b0 + b1*f1 + b2*f2 + b3*f3
}
mats <- 1:180                                        # maturities in months
yield_grid <- function(df) {
  g <- sapply(mats, function(n)
    svensson(n/12, df$BETA0, df$BETA1, df$BETA2, df$BETA3, df$TAU1, df$TAU2))
  g / 100 / 12                                       # per-month decimal yields
}

# monthly sample and principal-component factors
ym       <- format(nom$date, "%Y-%m")
mon      <- nom[sort(as.integer(tapply(seq_len(nrow(nom)), ym, max))), ]
Y        <- yield_grid(mon)
keep     <- apply(is.finite(Y), 1, all)
Y <- Y[keep, ];  mon <- mon[keep, ]
pca  <- prcomp(Y, center = TRUE, scale. = FALSE)
K    <- 5
W    <- pca$rotation[, 1:K]
ybar <- colMeans(Y)
X    <- sweep(Y, 2, ybar) %*% W

# factor VAR(1)
T   <- nrow(X)
X0  <- X[1:(T-1), ];  X1 <- X[2:T, ]
vr  <- lm(X1 ~ X0)
mu  <- as.numeric(coef(vr)[1, ]);  Phi <- t(coef(vr)[-1, ])
V   <- residuals(vr);  Sig <- crossprod(V) / nrow(V)

# one-month excess bond returns
P  <- -sweep(Y, 2, mats, "*")
r  <- Y[, 1]
rn <- seq(12, 180, 12)
rx <- sapply(rn, function(n) P[2:T, n-1] - P[1:(T-1), n] - r[1:(T-1)])

# ACM return regression and prices of risk
rr   <- lm(rx ~ V + X0);  co <- coef(rr)
a    <- co[1, ];  beta <- t(co[2:(1+K), ]);  cc <- t(co[(2+K):(1+2*K), ])
sig2 <- mean(diag(crossprod(residuals(rr)) / nrow(rx)))
BtB     <- solve(crossprod(beta))
lambda1 <- BtB %*% t(beta) %*% cc
lambda0 <- as.numeric(BtB %*% t(beta) %*% (a + 0.5 * (diag(beta %*% Sig %*% t(beta)) + sig2)))
sr <- lm(r ~ X);  d0 <- coef(sr)[1];  d1 <- as.numeric(coef(sr)[-1])

# pricing recursions, with and without prices of risk; term premium = difference
A <- 0; B <- rep(0, K); Arn <- 0; Brn <- rep(0, K)
Alist <- Blist <- Arnlist <- Brnlist <- vector("list", 180)
for (n in 1:180) {
  Bn   <- as.numeric(B  %*% (Phi - lambda1)) - d1
  An   <- A  + sum(B  * (mu - lambda0)) + 0.5 * (as.numeric(B  %*% Sig %*% B ) + sig2) - d0
  Brn2 <- as.numeric(Brn %*% Phi) - d1
  Arn2 <- Arn + sum(Brn * mu) + 0.5 * as.numeric(Brn %*% Sig %*% Brn) - d0
  A <- An; B <- Bn; Arn <- Arn2; Brn <- Brn2
  Alist[[n]] <- A; Blist[[n]] <- B; Arnlist[[n]] <- Arn; Brnlist[[n]] <- Brn
}
fit_yield <- function(Xf, n, rnl = FALSE) {
  Ac <- if (rnl) Arnlist[[n]] else Alist[[n]]
  Bc <- if (rnl) Brnlist[[n]] else Blist[[n]]
  -(Ac + as.numeric(Xf %*% Bc)) / n * 12 * 100
}
decomp_5f10 <- function(Xf) {
  tp5  <- fit_yield(Xf, 60)  - fit_yield(Xf, 60,  TRUE)
  tp15 <- fit_yield(Xf, 180) - fit_yield(Xf, 180, TRUE)
  data.frame(tp_5f10    = (15*tp15 - 5*tp5) / 10,
             rstar_5f10 = (15*fit_yield(Xf,180,TRUE) - 5*fit_yield(Xf,60,TRUE)) / 10)
}
acm_monthly <- cbind(date = mon$date, decomp_5f10(X))
Yday  <- yield_grid(nom);  okday <- apply(is.finite(Yday), 1, all)
acm   <- cbind(date = nom$date[okday], decomp_5f10(sweep(Yday[okday, ], 2, ybar) %*% W))

# validation: our ACM 10y term premium vs the NY Fed's (PRZ column acm_tp_y10)
tp10 <- fit_yield(X, 120) - fit_yield(X, 120, TRUE)
v <- merge(data.frame(date = as.Date(format(mon$date, "%Y-%m-01")), ours = tp10),
           data.frame(date = as.Date(format(as.Date(prz$date), "%Y-%m-01")),
                      nyfed = as.numeric(prz$acm_tp_y10)), by = "date")
acm_corr <- cor(v$ours, v$nyfed, use = "complete.obs")

# ===========================================================================
# 3. TABLE 1 -- one-day event study (elasticities per 1pp of debt/GDP)
# ===========================================================================
d5 <- as.Date("2021-01-05");  d6 <- as.Date("2021-01-06")
elast <- function(x, dt) (x[dt == d6] - x[dt == d5]) * 100 / shock

t1_tips10  <- elast(tips$TIPSY10, tips$date)                 # paper 2.58
t1_r10     <- elast(dkw$exp.real.short.rate.10, dkw$date)    # paper 1.20
t1_tp10    <- elast(dkw$real.term.prem.10, dkw$date)         # paper 1.71
t1_tips5f  <- elast(tips$y5f10, tips$date)                   # paper 3.96
t1_tp5f    <- elast(acm$tp_5f10, acm$date)                   # nominal (ACM)
t1_r5f     <- elast(acm$rstar_5f10, acm$date)                # nominal (ACM)

cat("\n===== TABLE 1: event-study elasticities (bp per 1pp debt/GDP) =====\n")
cat(sprintf("shock = %.3f pp of GDP\n", shock))
cat(sprintf("10y   TIPS %.2f (2.58) | Exp r* %.2f (1.20) | Real T.P. %.2f (1.71)\n",
            t1_tips10, t1_r10, t1_tp10))
cat(sprintf("5f10y TIPS %.2f (3.96) | nominal split (ACM): term prem %.2f, exp-rate %.2f\n",
            t1_tips5f, t1_tp5f, t1_r5f))

# ===========================================================================
# 4. TASK C -- placebo bootstrap p-values for Table 1
# ---------------------------------------------------------------------------
# One event has no sampling variance, so we ask how often a one-day move this
# large occurs on an ordinary day in 2016-2021. Shock fixed at the $900bn median
# (it cancels), date randomised. Also reported with the COVID window removed.
# ===========================================================================
changes <- function(d, x) { o <- order(d); data.frame(date = d[o][-1], chg = diff(x[o])) }
boot_p <- function(d, x) {
  ch     <- changes(d, x)
  actual <- ch$chg[ch$date == d6]
  inwin  <- ch$date >= as.Date("2016-01-01") & ch$date <= as.Date("2021-01-04")
  covid  <- ch$date >= as.Date("2020-02-15") & ch$date <= as.Date("2020-06-30")
  draw <- function(keep) {
    pool <- ch$chg[keep]; pool <- pool[is.finite(pool)]
    s <- sample(pool, 10000, replace = TRUE)
    c(one = mean(s >= actual), two = mean(abs(s) >= abs(actual)))
  }
  full <- draw(inwin); noC <- draw(inwin & !covid)
  c(full["two"], covidX = noC["two"])
}
cat("\n===== TASK C: placebo p-values (two-sided; COVID-excluded) =====\n")
pc <- function(lbl, d, x, paper) {
  r <- boot_p(d, x)
  cat(sprintf("%-14s: %.3f  (%.3f)   [paper %s]\n", lbl, r[1], r[2], paper))
}
pc("10y Real T.P.", dkw$date,  dkw$real.term.prem.10,      ".02")
pc("10y Exp r*",    dkw$date,  dkw$exp.real.short.rate.10, ".06")
pc("10y TIPS",      tips$date, tips$TIPSY10,               ".11")
pc("5f10 TIPS",     tips$date, tips$y5f10,                 ".05")

# ===========================================================================
# 5. TABLE 3 -- projection regression (first differences, HC1 robust SEs)
# ===========================================================================
D <- function(x) c(NA, diff(x))
df <- data.frame(
  date        = as.Date(prz$date),
  d_yield5f10 = D(prz$i5y10y_zc) * 100,
  d_debt      = D(prz$debt_y5),
  d_foreign   = D(prz$foreign_gdp),
  d_fed       = D(prz$fed_gdp),
  d_pi        = D(prz$frbus_pi_y10),
  d_rstar_5f5 = D(prz$dkw_rshort_y5y5) * 100,
  d_rtp_5f5   = D(prz$dkw_rtp_y5y5)   * 100,
  d_epi_5f5   = D(prz$dkw_epi_y5y5)   * 100,
  d_pirp_5f5  = D(prz$dkw_pirp_y5y5)  * 100,
  d_ifit_5f5  = D(prz$dkw_ifit_y5y5)  * 100
)
ym2 <- function(d) format(as.Date(d), "%Y-%m")
df$d_rst_5f10 <- D(acm_monthly$rstar_5f10[match(ym2(prz$date), ym2(acm_monthly$date))]) * 100
df$d_tp_5f10  <- D(acm_monthly$tp_5f10  [match(ym2(prz$date), ym2(acm_monthly$date))]) * 100

base <- subset(df, date >= as.Date("1985-01-01") & date <= as.Date("2025-01-31"))
robust  <- function(m) coeftest(m, vcov = vcovHC(m, type = "HC1"))
dcoef   <- function(dep, data)
  round(coef(lm(reformulate(c("d_debt","d_foreign","d_fed","d_pi"), dep), data))["d_debt"], 2)

cat("\n===== TABLE 3: 5f10y yield on debt projection + controls =====\n")
m1 <- lm(d_yield5f10 ~ d_debt + d_foreign + d_fed + d_pi, data = base)
cat("BASELINE (paper window):  debt coef",
    round(coef(m1)["d_debt"], 2), "(paper 3.95), N =", nobs(m1), "\n")
print(robust(m1))
cat("5f5 DKW decomposition (public): Exp r*", dcoef("d_rstar_5f5", base),
    "| Real T.P.", dcoef("d_rtp_5f5", base), "\n")
cat("5f10y ACM decomposition (nominal): exp-rate", dcoef("d_rst_5f10", base),
    "| term prem", dcoef("d_tp_5f10", base), "\n")
cat("EXTENSION (full sample):  debt coef",
    round(coef(lm(d_yield5f10 ~ d_debt + d_foreign + d_fed + d_pi, df))["d_debt"], 2),
    ", N =", nobs(lm(d_yield5f10 ~ d_debt + d_foreign + d_fed + d_pi, df)), "\n")

# ===========================================================================
# 6. Recovered decomposition columns and the four-component sum identity
# ===========================================================================
cat("\n===== Suppressed columns (event study, 10y) =====\n")
e_epi  <- elast(dkw$exp.inflation.10, dkw$date)
e_pirp <- elast(dkw$inflation.risk.prem.10, dkw$date)
e_sum  <- t1_r10 + t1_tp10 + e_epi + e_pirp
cat(sprintf("Expected inflation %.2f | Inflation risk premium %.2f\n", e_epi, e_pirp))
cat(sprintf("four components sum to %.2f vs nominal fitted %.2f\n",
            e_sum, elast(dkw$nominal.yield.fitted.10, dkw$date)))

# ===========================================================================
# 7. Structural-break test of the debt coefficient (Table 3 extension)
# ===========================================================================
bd <- base[complete.cases(base[, c("d_yield5f10","d_debt","d_foreign","d_fed","d_pi")]), ]
form <- d_yield5f10 ~ d_debt + d_foreign + d_fed + d_pi
cat("\n===== Structural-break test =====\n")
cat("supF unknown-break p-value:", round(sctest(Fstats(form, data = bd))$p.value, 3), "\n")
for (bk in as.Date(c("2008-07-01", "2020-01-01"))) {
  k <- max(which(bd$date <= bk))
  cat(sprintf("Chow at %s: p = %.3f\n", format(bk), sctest(form, data = bd, type = "Chow", point = k)$p.value))
}
h <- floor(nrow(bd)/2)
cat("debt coef first half", round(coef(lm(form, bd[1:h,]))["d_debt"], 2),
    "| second half", round(coef(lm(form, bd[(h+1):nrow(bd),]))["d_debt"], 2), "\n")

# ===========================================================================
# 8. SUMMARY
# ===========================================================================
cat("\n===========================================================\n")
cat("SUMMARY -- replicated vs paper\n")
cat("-----------------------------------------------------------\n")
cat(sprintf("Table 1 10y     : TIPS %.2f/2.58  r* %.2f/1.20  T.P. %.2f/1.71\n",
            t1_tips10, t1_r10, t1_tp10))
cat(sprintf("Table 1 5f10y   : TIPS %.2f/3.96  (decomposition via ACM, nominal)\n", t1_tips5f))
cat(sprintf("Table 3 debt    : %.2f / 3.95 (paper window)\n", coef(m1)["d_debt"]))
cat(sprintf("ACM validation  : corr with NY Fed 10y term premium = %.3f\n", acm_corr))
cat("Walls (data access, not replicable): Table 2 (PredictIt), intraday window\n")
cat("===========================================================\n")

# ===========================================================================
# 9. FIGURES (written to figures/ for the write-up)
# ---------------------------------------------------------------------------
# To resize: change width/height/res here, and out.width in the .Rmd chunk.
# ===========================================================================
dir.create("figures", showWarnings = FALSE)

# our ACM 10-year term premium against the New York Fed's published series
vv <- v[order(v$date), ]
png("figures/acm_validation.png", width = 1800, height = 1050, res = 220)
plot(vv$date, vv$nyfed, type = "l", lwd = 2, col = "grey45",
     xlab = "", ylab = "10-year term premium (%)",
     main = sprintf("Our ACM estimate vs. New York Fed  (correlation %.3f)", acm_corr))
lines(vv$date, vv$ours, lwd = 2, col = "firebrick")
legend("topright", c("New York Fed ACM", "Our ACM"),
       col = c("grey45", "firebrick"), lwd = 2, bty = "n")
dev.off()

# the placebo null: ordinary-day moves in the 10-year real term premium, with
# the January 6 2021 move marked
chp  <- changes(dkw$date, dkw$real.term.prem.10)
pool <- chp$chg[chp$date >= as.Date("2016-01-01") & chp$date <= as.Date("2021-01-04")]
pool <- pool[is.finite(pool)]
png("figures/placebo_null.png", width = 1800, height = 1050, res = 220)
hist(pool * 100, breaks = 60, col = "grey85", border = "grey65",
     xlab = "one-day change in the 10-year real term premium (bp)",
     ylab = "placebo days, 2016-2021", main = "")
abline(v = chp$chg[chp$date == d6] * 100, lwd = 2, col = "firebrick")
text(chp$chg[chp$date == d6] * 100, par("usr")[4] * 0.92,
     "January 6, 2021", col = "firebrick", pos = 4)
dev.off()
