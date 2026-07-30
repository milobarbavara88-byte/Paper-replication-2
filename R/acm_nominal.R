# acm_nominal.R  --  Adrian-Crump-Moench term-premium model on the nominal curve
# ===========================================================================
# WHY: the public DKW file stops at the 10-year horizon, so it cannot give the
# paper's headline 5-year-forward-10-year (5f10y) split into term premium and
# expected-rate. ACM can: it is a term-structure model estimated by ordinary
# regressions (PCA + a few OLS steps), so we can run it on the GSW nominal
# curve ourselves and read off the 5f10y decomposition. This IS "Novelty 5".
#
# SCOPE: nominal curve only (we have short nominal rates; a real short rate from
# TIPS is not well defined). So this decomposes the NOMINAL 5f10y -- disclose
# that. The REAL 10-year split stays with DKW (which already matches the paper).
#
# VALIDATION built in (Step 8): our 10-year term premium is compared to the NY
# Fed's official ACM series (PRZ column acm_tp_y10). If they track, trust 5f10y.
#
# This is the one genuinely advanced script. It is 8 labelled steps; run it and
# read the printed checks top to bottom.
#
# Needs only base R. Input: data/nominal.rds (from fetch_data.R -- it has the
# Svensson parameters BETA0..TAU2 and daily dates incl. 2021-01-05/06).
# ===========================================================================

nom <- readRDS("data/nominal.rds")
# need ALL six Svensson parameters present (early rows pre-~1980 are missing some,
# which would make the yield grid NA and break the PCA)
nom <- nom[complete.cases(nom[, c("BETA0","BETA1","BETA2","BETA3","TAU1","TAU2")]), ]
nom$date <- as.Date(nom$Date)

# ---- Step 1: a yield at any maturity, from the Svensson parameters ---------
# GSW publish 6 parameters per day; this formula returns the annual % zero yield
# at maturity m (in YEARS). Lets us build a clean, evenly-spaced maturity grid.
svensson <- function(m, b0, b1, b2, b3, t1, t2) {
  f1 <- (1 - exp(-m/t1)) / (m/t1)
  f2 <- f1 - exp(-m/t1)
  f3 <- (1 - exp(-m/t2)) / (m/t2) - exp(-m/t2)
  b0 + b1*f1 + b2*f2 + b3*f3
}

mats <- 1:180                              # maturities in MONTHS: 1,2,...,180 (=15y)

# build a T x 180 matrix of yields for a data frame of Svensson params
yield_grid <- function(df) {
  g <- sapply(mats, function(n)
    svensson(n/12, df$BETA0, df$BETA1, df$BETA2, df$BETA3, df$TAU1, df$TAU2))
  g / 100 / 12                             # -> per-MONTH decimal yield y^{(n)}
}

# ---- Step 2: monthly sample + principal-component factors -----------------
ym       <- format(nom$date, "%Y-%m")
last_row <- tapply(seq_len(nrow(nom)), ym, max)      # last obs each month
mon      <- nom[sort(as.integer(last_row)), ]
Y        <- yield_grid(mon)                # T x 180, per-month decimal
keep     <- apply(is.finite(Y), 1, all)    # drop any month with a non-finite yield
Y <- Y[keep, ];  mon <- mon[keep, ]
cat("Step 2: monthly obs =", nrow(Y), " maturities =", ncol(Y), "\n")

pca  <- prcomp(Y, center = TRUE, scale. = FALSE)
K    <- 5                                  # 5 factors (standard ACM)
W    <- pca$rotation[, 1:K]                # 180 x 5 loadings
ybar <- colMeans(Y)
X    <- sweep(Y, 2, ybar) %*% W            # T x 5 factors
cat("        variance explained by 5 factors =",
    round(sum(pca$sdev[1:K]^2)/sum(pca$sdev^2), 5), "\n")

# ---- Step 3: factor VAR(1)   X_{t+1} = mu + Phi X_t + v -------------------
T   <- nrow(X)
X0  <- X[1:(T-1), ];  X1 <- X[2:T, ]
vr  <- lm(X1 ~ X0)
mu  <- as.numeric(coef(vr)[1, ])
Phi <- t(coef(vr)[-1, ])                   # 5 x 5
V   <- residuals(vr)                       # (T-1) x 5 innovations
Sig <- crossprod(V) / nrow(V)              # 5 x 5 innovation covariance

# ---- Step 4: one-month excess bond returns --------------------------------
P  <- -sweep(Y, 2, mats, "*")              # log prices p^{(n)} = -n * y^{(n)}
r  <- Y[, 1]                               # 1-month short rate
rn <- seq(12, 180, 12)                     # returns for maturities 1y..15y
rx <- sapply(rn, function(n) P[2:T, n-1] - P[1:(T-1), n] - r[1:(T-1)])
cat("Step 4: excess-return matrix =", nrow(rx), "x", ncol(rx), "\n")

# ---- Step 5: the ACM return regression  rx = a + beta*v + c*X0 ------------
rr   <- lm(rx ~ V + X0)
co   <- coef(rr)
a    <- co[1, ]                            # 15
beta <- t(co[2:(1+K), ])                   # 15 x 5  (exposure to innovations)
cc   <- t(co[(2+K):(1+2*K), ])             # 15 x 5  (exposure to lagged factors)
sig2 <- mean(diag(crossprod(residuals(rr)) / nrow(rx)))

# ---- Step 6: prices of risk  (two cross-sectional OLS solves) -------------
BtB     <- solve(crossprod(beta))
lambda1 <- BtB %*% t(beta) %*% cc                                   # 5 x 5
astar   <- a + 0.5 * (diag(beta %*% Sig %*% t(beta)) + sig2)
lambda0 <- as.numeric(BtB %*% t(beta) %*% astar)                    # 5

# short rate as a function of factors:  r = d0 + d1' X
sr <- lm(r ~ X);  d0 <- coef(sr)[1];  d1 <- as.numeric(coef(sr)[-1])
cat("Step 6: short-rate fit R^2 =", round(summary(sr)$r.squared, 4), "\n")

# ---- Step 7: price bonds with, and without, prices of risk ----------------
# Recursions give loadings A_n, B_n. Do them twice: real-world (with lambda)
# and risk-neutral (lambda = 0). Term premium = actual yield - risk-neutral.
A <- 0; B <- rep(0, K); Arn <- 0; Brn <- rep(0, K)
Alist <- Blist <- Arnlist <- Brnlist <- vector("list", 180)
for (n in 1:180) {
  Bn  <- as.numeric(B  %*% (Phi - lambda1)) - d1
  An  <- A  + sum(B  * (mu - lambda0)) + 0.5 * (as.numeric(B  %*% Sig %*% B ) + sig2) - d0
  Brn2<- as.numeric(Brn %*% Phi) - d1
  Arn2<- Arn + sum(Brn * mu)          + 0.5 *  as.numeric(Brn %*% Sig %*% Brn)        - d0
  A <- An; B <- Bn; Arn <- Arn2; Brn <- Brn2
  Alist[[n]] <- A; Blist[[n]] <- B; Arnlist[[n]] <- Arn; Brnlist[[n]] <- Brn
}

# yields (annual %) at maturity n-months for a factor matrix Xf:
fit_yield <- function(Xf, n, rnl = FALSE) {
  Acoef <- if (rnl) Arnlist[[n]] else Alist[[n]]
  Bcoef <- if (rnl) Brnlist[[n]] else Blist[[n]]
  -(Acoef + as.numeric(Xf %*% Bcoef)) / n * 12 * 100
}
# term premium & expected-rate (=risk-neutral yield) at 5f10y, for any factors:
decomp_5f10 <- function(Xf) {
  tp5  <- fit_yield(Xf,  60) - fit_yield(Xf,  60, TRUE)
  tp15 <- fit_yield(Xf, 180) - fit_yield(Xf, 180, TRUE)
  rn5  <- fit_yield(Xf,  60, TRUE);  rn15 <- fit_yield(Xf, 180, TRUE)
  data.frame(tp_5f10   = (15*tp15 - 5*tp5) / 10,      # forward formula on each piece
             rstar_5f10 = (15*rn15 - 5*rn5) / 10)
}

# monthly series (for Table 3) ...
acm_m <- cbind(date = mon$date, decomp_5f10(X))
# ... and a DAILY series (for the Table 1 event study + bootstrap)
Yday  <- yield_grid(nom)
okday <- apply(is.finite(Yday), 1, all)    # same finite-row guard for the daily grid
Yday  <- Yday[okday, ];  nomd <- nom[okday, ]
Xday  <- sweep(Yday, 2, ybar) %*% W
acm_d <- cbind(date = nomd$date, decomp_5f10(Xday))
saveRDS(acm_d, "data/acm_5f10_nominal.rds")
saveRDS(acm_m, "data/acm_5f10_nominal_monthly.rds")

# ---- Step 8: VALIDATE our 10y term premium vs the NY Fed's ACM ------------
tp10_m <- fit_yield(X, 120) - fit_yield(X, 120, TRUE)
cat("\n--- VALIDATION ---\n")
cat("our ACM 10y term premium (%):  mean", round(mean(tp10_m), 2),
    " range", round(min(tp10_m), 2), "to", round(max(tp10_m), 2), "\n")
if (file.exists("data/prz_table3.rds")) {
  prz <- readRDS("data/prz_table3.rds")
  m <- merge(data.frame(date = as.Date(format(mon$date, "%Y-%m-01")), ours = tp10_m),
             data.frame(date = as.Date(format(as.Date(prz$date), "%Y-%m-01")),
                        nyfed = as.numeric(prz$acm_tp_y10)), by = "date")
  m <- m[is.finite(m$ours) & is.finite(m$nyfed), ]
  cat("correlation with NY Fed ACM 10y (PRZ acm_tp_y10):",
      round(cor(m$ours, m$nyfed), 3), "  (want > 0.9)\n")
}

# ---- the headline: nominal 5f10y decomposition on the event days ----------
e <- acm_d[acm_d$date %in% as.Date(c("2021-01-05", "2021-01-06")), ]
cat("\n--- EVENT STUDY (nominal 5f10y, ACM) ---\n")
cat("term premium change Jan5->Jan6 (bp):", round(diff(e$tp_5f10)   * 100, 2), "\n")
cat("expected-rate change Jan5->Jan6 (bp):", round(diff(e$rstar_5f10) * 100, 2), "\n")
cat("(paper's real 5f10y: term premium 2.61, exp r* 1.64, per ~2pp shock)\n")
