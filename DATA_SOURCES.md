# Data manifest — replication of Bhatt, Diercks, Eyal & Skaperdas (2026)

*"The Causal Effect of Debt on Interest Rates," FEDS 2026-031.*

This file is the output of the data-scouting phase. It records, for every input
the paper uses, the **exact** primary source, the frequency and format, and the
verified access status. It also records what was and was not retrievable from
this working environment.

---

## 0. Environment access constraint (read this first)

Data acquisition for this replication was attempted from an execution
environment whose outbound network is governed by an organization egress policy.
**That policy allows only GitHub and language-package registries. Every
primary economic-data host is blocked at the proxy (HTTP 403 on CONNECT).**

Verified blocked (org policy, not a TLS/tooling problem):

| Host | Needed for |
|---|---|
| `federalreserve.gov` | GSW nominal & TIPS curves; DKW output; H.4.1 |
| `fred.stlouisfed.org` | GDP, Fed holdings, foreign holdings |
| `apps.bea.gov` / `www.bea.gov` | Nominal GDP (primary) |
| `www.cbo.gov` | CBO 5-year-ahead debt projections |
| `dataverse.harvard.edu` | Plante–Richter–Zubairy replication package |
| `www.openicpsr.org`, `zenodo.org`, `osf.io` | other replication packages |

Reachable: `github.com`, `raw.githubusercontent.com`, `api.github.com`, plus
pip/npm/CRAN-mirror registries.

**Consequence.** None of the primary sources below can be pulled from *this*
environment, and the cited-paper replication packages (Dataverse/openICPSR) are
likewise unreachable. The GitHub-only fallback was scouted (see §3) and yields
only partial, monthly, or stale third-party mirrors — none adequate for the
daily/intraday event study. The retrieval harness in `R/fetch_data.R` targets
the exact official URLs and will run correctly the moment it is executed either
(a) locally, or (b) in an environment whose egress policy allows the hosts in
the table above.

To unblock full automated retrieval here, the environment's network policy would
need those six hosts added to its allowlist.

---

## 1. Primary public sources (the intended route)

All series below are genuinely public and free; the constraint is purely the
egress policy above, plus hand-collection where noted.

### 1.1 Yields — daily, drive Tasks B, C, D and the LHS of Task A

| Series | Source | Exact file / URL | Freq | Format |
|---|---|---|---|---|
| Nominal zero-coupon Treasury curve (`SVENY05/10/15`, plus `BETA*`, `TAU*`) | Gürkaynak–Sack–Wright (2007) | `https://www.federalreserve.gov/econres/feds/files/feds200628.csv` | Daily, 1961– | CSV w/ ~9-line preamble |
| TIPS zero-coupon curve (`TIPSY05/10/15`) | Gürkaynak–Sack–Wright (2010) | `https://www.federalreserve.gov/econres/feds/files/feds200805.csv` | Daily, 1999– | CSV w/ preamble |

Landing pages (if the file URLs move):
`https://www.federalreserve.gov/data/nominal-yield-curve.htm` and
`https://www.federalreserve.gov/data/tips-yield-curve-and-inflation-compensation.htm`.

### 1.2 DKW decomposition output — daily, drives the r*/term-premium columns

| Series | Source | Access | Notes |
|---|---|---|---|
| Expected real short rate, real term premium, inflation exp., inflation risk premium, TIPS liquidity premium | D'Amico, Kim & Wei (2018); Fed Board "Tips from TIPS: Update and Discussion" FEDS Note + data release | **PUBLIC (output only)** | The *model output* is released as an accompanying data file on the FEDS Notes page. The model **parameters / state-space** (needed for the intraday Task D filter) are Board-internal — **WALLED**. |

Resolve decisions-log **item 7** (asymptotic r* vs. horizon-average "Exp. r*")
directly against the column definitions in this release before building anything
downstream.

### 1.3 Task A (Table 3) controls — semiannual/quarterly

| Series | Source | Candidate FRED id | Status |
|---|---|---|---|
| Nominal GDP (denominator for all shares) | BEA | `GDP` | PUBLIC |
| Federal Reserve Treasury holdings | H.4.1; pre-2018Q2 from **Fries (2018)** | `TREAST` (weekly, 2002–) | PUBLIC; **splice Fries (2018) for pre-2018Q2** |
| Foreign official Treasury holdings | Financial Accounts Z.1 | `FDHBFIN` (candidate — **confirm this is the "official" subset**) | PUBLIC; id needs confirmation |
| 10-year inflation expectation (PTR) | FRB/US model database | ships in the FRB/US data package (zip), not a clean FRED series | PUBLIC (package download) |
| CBO five-year-ahead publicly-held debt projection, 1985–2025 | CBO Budget & Economic Outlook + summer Updates (archived) | — | PUBLIC but **hand-collection** (this is the N≈84 panel; the Plante–Richter–Zubairy deposit is the shortcut) |

### 1.4 Task E (Table 2) — daily probabilities

| Series | Source | Status |
|---|---|---|
| PredictIt Georgia runoff daily closes, 14 Dec 2020 – 8 Jan 2021 | PredictIt (public API discontinued) | **UNRELIABLE.** Daily closes circulate in Mian–Straub–Sufi and Hazell–Hobler files; intraday (Figure 1) via Wayback Machine on the PredictIt market pages. |

---

## 2. Cited-paper replication packages (the fallback route)

Journal-mandated deposits are the efficient way to inherit pre-assembled panels.
All are on hosts blocked by this environment's egress policy; retrieve them where
network access permits.

| Package | Venue / deposit | Gives you | Deposit mandated? |
|---|---|---|---|
| **Plante, Richter & Zubairy (2026)** | Review of Economics & Statistics → **Harvard Dataverse** | The Table 3 (Task A) RHS panel: CBO 5y-ahead debt, Fed & foreign holdings, PTR. **Highest-value target.** | Yes |
| Ehrlich, Kay & Thapar (2026) | AER: Insights → deposit; also Dallas Fed WP 2539 | International comparison only — **not** a source for the US core tasks | Yes |
| Mian, Straub & Sufi (2022) | NBER WP "A Goldilocks theory of fiscal deficits" | Georgia-window comparison; possibly PredictIt closes | **No** — cited as NBER WP, not a journal deposit. Verify publication status before relying. |
| Hazell & Hobler (2025) | LSE working paper | The investment-bank deficit cross-section — the **Task C bootstrap input** | **No** — working paper. Only realistic public route; else email authors / use Novelty 3/4. |

---

## 3. GitHub-only fallback — what was actually found here

Because GitHub was the only reachable host, it was scouted directly. Findings:

- **No replication repo** exists on GitHub for Plante–Richter–Zubairy, Hazell–Hobler,
  Mian–Straub–Sufi, or a Georgia-runoff / PredictIt dataset (searched by author,
  title, and topic — zero hits).
- **No DKW decomposition output** on GitHub (searched by component-series names).
- GSW curves appear only as **partial third-party mirrors**, unusable for this paper:
  - `invertedv/fwdrates` → `data/fedTest.csv`: a **57-line test fragment**, not the series.
  - `linroger/Fixed-Income-Asset-Pricing-Repo`: GSW nominal & TIPS but **monthly, from 2004** — cannot support a one-day (Jan 5→6 2021) or intraday event study.
  - `serhiykozak/EquityTS`, `AlexanderSchulz14/Master-Thesis`, `fernando-duarte/ERP`: monthly/annual GSW subsets, same limitation.

None of these are provenance-clean substitutes for the official daily files, so
none were adopted. Using them would silently degrade the event study.

---

## 4. Bottom line

The daily/intraday event study (Tasks B, C, D) **cannot** be assembled from
GitHub. It requires the official Fed Board daily GSW curves and DKW output.
Task A is inheritable from the Plante–Richter–Zubairy Dataverse deposit. Both
routes are blocked *only* by this environment's egress policy, not by the data
being non-public. Open the six hosts in §0 (or run `R/fetch_data.R` locally) and
the primary route is fully automatable.
