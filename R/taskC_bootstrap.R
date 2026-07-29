# taskC_bootstrap.R  --  Table 1 p-values via a placebo/randomisation test
# ===========================================================================
# We have ONE event, so there is no sampling variance. Instead we ask: if we ran
# the same one-day calculation on an ordinary day between 2016 and the eve of the
# runoff, how often would we see a move at least this big by chance? That share
# is the p-value.
#
# The paper also randomises the shock size by drawing from the Hazell-Hobler
# investment-bank forecast distribution -- which is proprietary and unobtainable.
# So (per the plan's fallback + Novelty 4) we FIX the shock at the $900bn median.
# With a fixed shock the denominator cancels between the actual and placebo
# moves, so the test reduces to: is the Jan-6 one-day change extreme relative to
# the 2016-2021 distribution of one-day changes in the same series? Exactly what
# the plan says the test "really" is.
#
# Novelty 4: we also report the null with the COVID volatility window excluded
# (Feb-Jun 2020), which otherwise fattens the null and makes rejection harder.
#
# No new data. Needs data/dkw.rds, data/tips.rds, data/acm_5f10_nominal.rds.
# ===========================================================================

set.seed(20210106)

dkw  <- readRDS("data/dkw.rds")
tips <- readRDS("data/tips.rds")
acm  <- readRDS("data/acm_5f10_nominal.rds")

# one-day changes of a series, tagged by the day they land on
changes <- function(d, x) {
  o <- order(d);  d <- d[o];  x <- x[o]
  data.frame(date = d[-1], chg = diff(x))
}

# placebo p-values for one series
boot_p <- function(d, x) {
  ch     <- changes(d, x)
  actual <- ch$chg[ch$date == as.Date("2021-01-06")]           # the event move
  inwin  <- ch$date >= as.Date("2016-01-01") & ch$date <= as.Date("2021-01-04")
  covid  <- ch$date >= as.Date("2020-02-15") & ch$date <= as.Date("2020-06-30")

  draw <- function(keep) {
    pool <- ch$chg[keep];  pool <- pool[is.finite(pool)]
    s <- sample(pool, 10000, replace = TRUE)
    c(one = mean(s >= actual), two = mean(abs(s) >= abs(actual)))   # actual is +ve
  }
  full  <- draw(inwin)
  noCov <- draw(inwin & !covid)
  c(actual = unname(actual),
    p_one = unname(full["one"]),  p_two = unname(full["two"]),
    pX_one = unname(noCov["one"]), pX_two = unname(noCov["two"]))
}

# series to test (with the paper's reported p-value where it's a direct match)
series <- list(
  "10y TIPS      (paper .11)" = list(tips$date, tips$TIPSY10),
  "10y Exp r*    (paper .06)" = list(dkw$date,  dkw$exp.real.short.rate.10),
  "10y Real T.P. (paper .02)" = list(dkw$date,  dkw$real.term.prem.10),
  "5f10 TIPS     (paper .05)" = list(tips$date, tips$y5f10),
  "5f10 nom T.P. (ACM, ours)" = list(acm$date,  acm$tp_5f10),
  "5f10 nom r*   (ACM, ours)" = list(acm$date,  acm$rstar_5f10)
)

cat("placebo window 2016-01-01 .. 2021-01-04 ; shock fixed at $900bn median\n")
cat(sprintf("%-26s %8s  %6s %6s | %9s %9s\n",
            "series", "move(bp)", "p_1sd", "p_2sd", "COVIDx_1", "COVIDx_2"))
for (nm in names(series)) {
  s <- series[[nm]];  r <- boot_p(s[[1]], s[[2]])
  cat(sprintf("%-26s %8.2f  %6.3f %6.3f | %9.3f %9.3f\n",
              nm, r["actual"] * 100, r["p_one.one"], r["p_two.two"],
              r["pX_one.one"], r["pX_two.two"]))
}

cat("\nNotes: p_1sd/p_2sd = one- and two-sided (the paper's asterisks fit either;",
    "\nreport both). COVIDx = same test with Feb-Jun 2020 removed (Novelty 4).",
    "\n10y and 5f10-TIPS are direct comparisons; the two ACM rows are our nominal",
    "\nextension, not the paper's real-component p-values.\n")
