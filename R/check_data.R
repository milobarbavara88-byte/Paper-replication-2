# check_data.R
# ---------------------------------------------------------------------------
# Robustness / integrity report over whatever fetch_data.R actually produced.
# Run AFTER fetch_data.R (or after dropping manually-downloaded files in place).
#
#   Rscript R/check_data.R
#
# It never errors out on a missing file: it reports every input as PASS / FAIL /
# MISSING, prints date coverage and the paper-critical values, and ends with an
# explicit list of "what failed to extract" so the gap is unambiguous.
# ---------------------------------------------------------------------------

suppressWarnings(suppressMessages({ library(dplyr) }))

status <- list()   # collects one row per input for the final summary
note   <- function(name, verdict, detail = "") {
  status[[length(status) + 1]] <<- data.frame(input = name, verdict = verdict, detail = detail)
}
hr <- function() cat(strrep("-", 72), "\n")
rd <- function(p) if (file.exists(p)) readRDS(p) else NULL

cat("\n================  DATA INTEGRITY REPORT  ================\n\n")

# ---- 1. GSW nominal --------------------------------------------------------
hr(); cat("[1] GSW nominal curve  (data/raw/gsw_nominal.rds)\n")
g <- rd("data/raw/gsw_nominal.rds")
if (is.null(g)) { cat("   MISSING\n"); note("GSW nominal", "MISSING") } else {
  d <- as.Date(g$Date)
  have <- all(c("SVENY05","SVENY15") %in% names(g))
  cat(sprintf("   rows: %d | dates: %s -> %s | SVENY05&15 present: %s\n",
              nrow(g), min(d, na.rm=TRUE), max(d, na.rm=TRUE), have))
  covers_event <- as.Date("2021-01-06") <= max(d, na.rm=TRUE)
  covers_tab3  <- as.Date("2025-01-31") <= max(d, na.rm=TRUE)
  cat(sprintf("   covers event study (>=2021-01-06): %s | covers Table 3 (>=2025-01): %s\n",
              covers_event, covers_tab3))
  note("GSW nominal", if (have && covers_event) "PASS" else "CHECK",
       sprintf("last=%s", max(d, na.rm=TRUE)))
}

# ---- 2. GSW TIPS -----------------------------------------------------------
hr(); cat("[2] GSW TIPS curve  (data/raw/gsw_tips.rds)\n")
t <- rd("data/raw/gsw_tips.rds")
if (is.null(t)) { cat("   MISSING\n"); note("GSW TIPS", "MISSING") } else {
  d <- as.Date(t$Date)
  have <- all(c("TIPSY05","TIPSY15") %in% names(t))
  cat(sprintf("   rows: %d | dates: %s -> %s | TIPSY05&15 present: %s\n",
              nrow(t), min(d, na.rm=TRUE), max(d, na.rm=TRUE), have))
  note("GSW TIPS", if (have) "PASS" else "CHECK", sprintf("last=%s", max(d, na.rm=TRUE)))
}

# ---- 3. Derived 5f10y + the event-study sanity check -----------------------
hr(); cat("[3] Derived 5f10y and the Jan 5->6, 2021 move\n")
report_5f10 <- function(path, label) {
  x <- rd(path)
  if (is.null(x)) { cat(sprintf("   %-16s MISSING\n", label)); note(label, "MISSING"); return() }
  d5 <- x$y5f10[match(as.Date("2021-01-05"), x$date)]
  d6 <- x$y5f10[match(as.Date("2021-01-06"), x$date)]
  chg <- (d6 - d5) * 100  # percentage points -> basis points
  cat(sprintf("   %-16s rows=%d  range=%s..%s  Jan5=%.3f Jan6=%.3f  1-day change=%.1f bp\n",
              label, nrow(x), min(x$date), max(x$date),
              d5 %||% NA, d6 %||% NA, chg %||% NA))
  note(label, if (!is.na(chg)) "PASS" else "CHECK", sprintf("%.1f bp on the day", chg %||% NA))
}
`%||%` <- function(a,b) if (length(a)==0 || is.na(a)) b else a
report_5f10("data/derived/nominal_5f10y.rds", "5f10y nominal")
report_5f10("data/derived/tips_5f10y.rds",    "5f10y TIPS")
cat("   (paper: 10y nominal rose ~10bp on the day; raw 10y TIPS move ~5.3bp)\n")

# ---- 4. FRED controls ------------------------------------------------------
hr(); cat("[4] Macro controls  (data/raw/controls_fred.rds)\n")
ctrl <- rd("data/raw/controls_fred.rds")
wanted <- c("gdp","fed_hold","foreign")
if (is.null(ctrl)) {
  cat("   MISSING — the whole FRED pull failed.\n")
  for (w in wanted) note(paste0("FRED:", w), "MISSING")
} else {
  for (w in wanted) {
    if (is.null(ctrl[[w]])) { cat(sprintf("   %-10s FAILED / absent\n", w)); note(paste0("FRED:", w), "FAIL") }
    else {
      df <- ctrl[[w]]; dc <- as.Date(df$date)
      cat(sprintf("   %-10s rows=%d  %s -> %s\n", w, nrow(df), min(dc,na.rm=T), max(dc,na.rm=T)))
      note(paste0("FRED:", w), "PASS")
    }
  }
}

# ---- 5. Items expected to be absent (not on a primary URL) -----------------
hr(); cat("[5] Known-manual inputs (expected absent unless you added them)\n")
for (p in c("data/raw/dkw_output", "data/raw/ptr.rds",
            "data/raw/cbo_debt5.rds", "data/raw/predictit.rds")) {
  present <- length(Sys.glob(paste0(p, "*"))) > 0
  cat(sprintf("   %-26s %s\n", basename(p), if (present) "present" else "absent (expected)"))
}

# ---- 6. Summary ------------------------------------------------------------
hr(); cat("SUMMARY\n"); hr()
S <- do.call(rbind, status)
print(S, row.names = FALSE)
failed <- S$input[S$verdict %in% c("MISSING","FAIL")]
cat("\nFAILED TO EXTRACT: ",
    if (length(failed)) paste(failed, collapse = ", ") else "(none)", "\n\n")
