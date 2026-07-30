# novelty1_break.R  --  extend Table 3 and test whether the debt coefficient is stable
# ===========================================================================
# Section 2.5 concedes the time-series evidence reflects the recent fiscal regime.
# We already saw the debt coefficient move with the sample (paper-window 4.13 vs
# full 3.48). Here we test it formally: is there a structural break, and how does
# the coefficient drift over time?
#
# install.packages(c("strucchange", "sandwich", "lmtest"))
# Needs data/prz_table3.rds (run load_colleague_data.R first).
# ===========================================================================

suppressWarnings(suppressMessages({ library(strucchange) }))

prz <- readRDS("data/prz_table3.rds");  prz <- prz[order(prz$date), ]
D <- function(x) c(NA, diff(x))
df <- data.frame(
  date    = as.Date(prz$date),
  y       = D(prz$i5y10y_zc) * 100,
  debt    = D(prz$debt_y5),
  foreign = D(prz$foreign_gdp),
  fed     = D(prz$fed_gdp),
  pi      = D(prz$frbus_pi_y10)
)
df   <- df[complete.cases(df), ]
form <- y ~ debt + foreign + fed + pi

# ---- 1) is there ANY break? (unknown break point, supF test) --------------
fs <- Fstats(form, data = df)
cat("== Unknown-break test (supF) ==\n")
cat("p-value:", round(sctest(fs)$p.value, 3),
    " | estimated break near:", format(df$date[fs$breakpoint]), "\n")

# ---- 2) Chow tests at named candidate breaks ------------------------------
cat("\n== Chow tests at candidate breaks ==\n")
for (bk in as.Date(c("1985-01-01", "2008-07-01", "2020-01-01"))) {
  k <- max(which(df$date <= bk))
  p <- sctest(form, data = df, type = "Chow", point = k)$p.value
  cat(sprintf("break at %s (obs %d):  p = %.3f\n", format(bk), k, p))
}

# ---- 3) debt coefficient over time ----------------------------------------
cat("\n== Debt coefficient: split-sample and rolling ==\n")
h  <- floor(nrow(df) / 2)
c1 <- coef(lm(form, df[1:h, ]))["debt"]
c2 <- coef(lm(form, df[(h+1):nrow(df), ]))["debt"]
cat("first half:", round(c1, 2), " | second half:", round(c2, 2), "\n")

w    <- 30                                              # rolling window (obs)
roll <- sapply(1:(nrow(df) - w + 1),
               function(i) coef(lm(form, df[i:(i+w-1), ]))["debt"])
cat("rolling debt coef (", w, "-obs window): min", round(min(roll), 2),
    " max", round(max(roll), 2), " latest", round(tail(roll, 1), 2), "\n")
cat("\n(If the coefficient has risen in recent windows, that is a publishable",
    "\nobservation on the current fiscal regime; if flat, that is equally informative.)\n")
