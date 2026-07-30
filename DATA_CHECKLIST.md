# Master data checklist — FEDS 2026-031 replication

Every input the paper needs, the **cleanest** way to get it in R, and its status.
Grouped by acquisition method so you can knock out a whole group at once.

Legend: ✅ automatable & confirmed · ⚠️ automatable, one caveat · ✋ manual/one-off · ⛔ walled

---

## STATUS after fact-checking the colleague delivery

Verified real and folded in (`R/load_colleague_data.R`):
- **DKW output** (`DKW_updates.csv`) — genuine Fed release. Reproduces Table 1's
  **10-year** columns to 2 decimals. Horizons present: **5y, 10y, 5f5**.
- **PRZ deposit** (`Data.xlsx`, sheet `final`) — the entire Table 3 right-hand
  side (`debt_y5`, `fed_gdp`, `foreign_gdp`, `frbus_pi_y10`), semiannual
  1976–2025. Removes the CBO hand-collection **and** settles the foreign-official
  caveat (`foreign_gdp` is the real official series, not FDHBFIN).
- **FRB/US package** — real; PTR + nominal GDP. Now a backup (PTR is in PRZ).

Discarded: `predictit_illustrative.csv` — honestly labelled but interpolated
(14/18 days). **Not usable for any reported estimate.** PredictIt stays a wall.

**The one gap this exposed (headline):** the DKW public file stops at 10y + 5f5,
so the paper's preferred **5-year-forward 10-year (5f10y) r\*/term-premium**
decomposition is **not** in any public file — it is the authors' walled
extension. Fix: **run ACM on the GSW 5/10/15y TIPS curve** to produce the 5f10y
real term premium and r\* (this is Novelty 5; PRZ's own workbook carries `acm_*`
columns as precedent). Until then, the 10-year decomposition is fully replicable
and the 5f10y row is the substitution.

---

## Group 1 — FRED, via `fredr` + your API key ✅

One-time: `install.packages("fredr")`; put `FRED_API_KEY=xxxx` in `~/.Renviron`.
Then `R/fetch_data.R` pulls these automatically.

| # | Series | FRED id | Used in | Note |
|---|---|---|---|---|
| 1 | Nominal GDP (denominator for every share, and the shock's ~2% of GDP) | `GDP` | Tasks A, B | quarterly, $bn |
| 2 | Fed holdings of Treasuries (H.4.1) | `TREAST` | Task A control | weekly; splice **Fries (2018)** for pre-2018Q2 |
| 3 | Foreign-held Treasuries | `FDHBFIN` | Task A control | ⚠️ this is *total* foreign, not the *official* subset the paper uses — confirm against the PRZ deposit (#8). Footnote 11: results barely move without it. |

## Group 2 — Fed Board flat files, via `download.file()` ✅

No API, no key. **Correct** URLs (the earlier NULLs were a dead path):

| # | Series | URL | Used in | Read with |
|---|---|---|---|---|
| 4 | GSW **nominal** zero-coupon curve (`SVENY05/10/15`) | `https://www.federalreserve.gov/data/yield-curve-tables/feds200628.csv` | B, C, D + A's LHS | `read_csv(skip=9, na=c("NA","-999.99"))` |
| 5 | GSW **TIPS** zero-coupon curve (`TIPSY05/10/15`) | `https://www.federalreserve.gov/data/yield-curve-tables/feds200805.csv` | B, C, E | same |

`R/fetch_data.R` does both and builds `5f10y = (15·y15 − 5·y5)/10` for each.

## Group 3 — the r*/term-premium decomposition (DKW) ✋ **the linchpin**

| # | Series | Source | Used in |
|---|---|---|---|
| 6 | DKW daily output: expected real short rate, real term premium, TIPS liquidity premium | Fed Board **"Tips from TIPS: Update and Discussion"** FEDS Note + accompanying data file | A, B, C, E |

- No R package, not on FRED, no stable flat-file URL. Download the accompanying
  data file from the FEDS Note page once and drop it at `data/raw/dkw_output.*`.
- **This is the item that gates the paper's headline** (the r*-vs-term-premium
  split). Resolve decisions-log **item 7** (asymptotic r* vs horizon-average
  "Exp. r*") against its column definitions before building anything on it.
- The **model parameters / state-space** (needed only for intraday Task D) are
  Board-internal — ⛔ walled.
- **Clean public fallback if DKW output is unusable:** Adrian–Crump–Moench (this
  *is* Novelty 5). NY Fed publishes ACM term premiums; downloadable, replicable,
  R-friendly. Nominal-only, so it decomposes the nominal (not real) 5f10y — a
  disclosed difference, not a fudge.

## Group 4 — Table 3 panel, via the `dataverse` R package ⚠️

| # | Series | Source | Used in |
|---|---|---|---|
| 7 | CBO five-year-ahead publicly-held debt projection, 1985–2025 | CBO archive (hand-collect) **or** the deposit below | Task A regressor |
| 8 | **Whole Table 3 RHS pre-assembled** (CBO debt5 + Fed + foreign + PTR) | **Plante–Richter–Zubairy (2026), ReStat → Harvard Dataverse** | Task A |

- Cleanest: `install.packages("dataverse")`, then `dataverse::get_dataframe_by_name(...)`
  against the PRZ deposit DOI. Grab the deposit DOI from the ReStat article's
  "Replication" / Dataverse link (your connection reaches `dataverse.harvard.edu`;
  this sandbox does not, so the DOI isn't hard-coded yet — paste it and I'll wire it in).
- This single deposit is the highest-value target: it removes 40 years of CBO
  hand-collection **and** gives a reference copy of the foreign-official series
  to settle the #3 caveat.

## Group 5 — PTR (inflation expectation) ✋

| # | Series | Source | Used in |
|---|---|---|---|
| 9 | 10-year inflation expectation (PTR) | **FRB/US data package** (`federalreserve.gov/econres/us-models-package.htm`) — or inherit from the PRZ deposit (#8) | Task A control |

Not on FRED. Download the FRB/US zip once, extract the `PTR` column. If the PRZ
deposit already carries PTR, use that and skip this.

## Group 6 — Task E probabilities ⚠️

| # | Series | Source | Used in |
|---|---|---|---|
| 10 | PredictIt Georgia runoff daily closes, 14 Dec 2020 – 8 Jan 2021 | PredictIt API discontinued → look in **Mian–Straub–Sufi** or **Hazell–Hobler** files; intraday (Fig 1) via Wayback Machine | Task E |

No clean R package. If MSS/H&H posted a deposit, `dataverse`/`osfr` can pull it;
otherwise Wayback the market pages (18 daily points — trivial to hand-enter if needed).

## Group 7 — genuinely walled ⛔ (use the Novelties)

| # | Series | Why walled | Route |
|---|---|---|---|
| 11 | Hazell–Hobler investment-bank deficit cross-section | proprietary sell-side notes | email authors → else **Novelty 3** (bound the shock from public objects) / **Novelty 4** |
| 12 | Intraday 5-min Treasury yields | Bloomberg/institutional | **Novelty 6** (CME futures ZN/ZB) or declare Task D non-replicable |
| 13 | DKW state-space parameters | Board-internal | **Novelty 5** (ACM) |

---

## What runs today, unattended
Groups 1 + 2 (`R/fetch_data.R`): GDP, Fed holdings, foreign holdings, both GSW
curves, and the two `5f10y` series → all saved R-native under `data/`.

## What needs one manual fetch each
DKW output (#6), the PRZ deposit DOI (#8, then automatable), PTR (#9).

## What triggers a Novelty instead of data
Hazell–Hobler (#11), intraday (#12), DKW internals (#13).
