# LANE-VALIDATION Report — Deep-Improvement Loop, Iteration 1

**Lane:** Validation (independent gatekeeper). **Method:** direct reads of
`~/workspace/fomo-trader/runs/paper-1h/trades.jsonl` and `candidates.jsonl` only
(read-only). No CLI agents, no code from other lanes — every number recomputed
with my own harness in `/tmp/lane-validation-iter1/` (`gate.py`, `baseline.py`).
**Bot not disturbed** (process confirmed running; no repo files modified).

**Sibling-report status at write time (2026-09-28 ~16:15 EDT / 20:15 UTC):**
LANE-CURSOR report — **not on disk**. LANE-CODEX-ASTRA report — **not on disk**
(only `astra_prompt_iter1.md` + `astra_stderr.log`, which shows
`timeout: failed to run command '/usr/bin/codex': No such file or directory` —
the known fragile Codex path; coordinator should verify that lane's implementer
is actually running). Per my task brief I therefore gated the high-priority
hypotheses independently: (a) slip-veto forward validation, (b) LP-pull
anti-screen feasibility, (c) hour-of-day / regime-conditioned entry filters.

---

## 1. Headline findings (read first)

1. **Iteration-0 baselines reproduce EXACTLY — no mismatch this time.** Cutting
   the file at `ts <= 2026-09-28 12:15` (UTC, see §6) yields n=117,
   net=-$139.60, PF=0.2544, DD=$143.02 — matching the recorded iter-0 values to
   the cent. The "rug-gap" definition is now pinned: `dump detector -100.0%` +
   `venue dump: DexScreener m5 -100.0%` + `trailing stop -100.0%` = 24 wipes /
   -$100.04 at iter-0 (71.7% of net), now **26 wipes / -$113.92 (75.4% of the
   -$151.15 lifetime net)**. The structural leak is worse in both absolute and
   relative terms than at iter-0.
2. **The slip veto (shipped 12:24 EDT on user order) does not dodge wipes — it
   delays entry into them.** Both post-regime wipes (17:18 and 17:47 UTC) were on
   mints the veto had blocked hours earlier (PHOE vetoed 4×, entered at
   slip=-0.006 → -100% wipe; 0xffbca0ed vetoed 2×, entered at slip=-0.076 →
   -100% wipe). Slip is a *correlate* of chase entries, not the *cause* of
   LP-pulls. Forward sample is n=8 closes — far below the ≥30 needed — so the
   veto remains **NOT_VERIFIABLE**, and the forward evidence weakens its causal
   story even as the historical replay looks stable.
3. **LP-pull anti-screen is NOT_FEASIBLE with current data.** `lp_burn_pct` /
   `lp_locked` keys exist on entries but are null on 100% of pairs; journal
   `pool_created_at` is null on 453/453 lines. No data source → no screen.
4. **Every entry-side filter fails.** Hour windows, signal-gain bands,
   buy/sell-ratio bands, liquidity/mcap bands, and combos: all still deeply
   negative (best PF 0.757 on a data-mined n=21 slice), all fail retention
   and/or 3x-fee stress, most fail sample-size gates. The status quo itself
   fails its own walk-forward gate (47% retention < 60%).
5. **Verdict: ship-nothing from this lane.** No candidate passes every gate.
   The honest outcome is continued forward validation of the already-shipped
   slip veto, not a new change.

---

## 2. Independent baseline reproduction

### 2.1 Closed-trade definition (explicit)
Every line with `type == 'close'` and `realized_usd != null` is one complete
round trip; `realized_usd` is the net position P&L including rung profits (the
`rungs` field documents rungs that fired; verified against matched entries in
iter-0, unchanged since). FIFO entry→close matching by mint (125 pairs) is used
only for entry-feature gating; aggregates below are the close-line read.

### 2.2 Lifetime numbers (127 closes, through 2026-09-28 17:47:55 UTC)

| Metric | Value |
|---|---|
| Closed round trips | **127** |
| Net P&L | **-$151.15** |
| Gross wins / gross losses | +$52.37 / -$203.52 |
| Profit factor | **0.257** |
| Win rate | **26.0%** (33/127) |
| Max drawdown (closed-trade equity) | **$154.57** |
| Avg P&L / trade | -$1.19 |
| Best single trade | +$5.31 (FM / WBNB, 2026-09-27) |
| Ex-wipe (101 closes) | net -$37.23, **PF 0.584** — still deeply negative without wipes |

### 2.3 Reconciliation vs iteration-0

| Recorded (iter-0) | My reproduction (file state at ts ≤ 2026-09-28 12:15 UTC) | Verdict |
|---|---|---|
| 117 closed, -$139.60, PF 0.254, DD $143.02 | 117, -$139.60, PF 0.2544, DD $143.02 | **EXACT MATCH.** No mismatch. |
| 24 rug-gap wipes, -$100.04 (71.7%) | 24 / -$100.04 with definition dd100+vd100+ts100 | **CONFIRMED.** Definition pinned. |
| — | Now: 127 closes, -$151.15, PF 0.257, DD $154.57; 26 wipes / -$113.92 (75.4%) | 10 new closes since iter-0: net -$11.55, PF 0.289 |

### 2.4 P&L by exit reason (127 closes)

| Exit reason bucket | n | Net $ | Avg $ |
|---|---|---|---|
| rug-gap (-100% one-tick wipe: dump-detector -100% / venue-dump m5 -100% / trailing-stop -100%) | 26 | -113.92 | -4.38 |
| dump-detector (partial) | 93 | -40.19 | -0.43 |
| trailing stop | 7 | +3.55 | +0.51 |
| stale exit | 1 | -0.59 | -0.59 |

### 2.5 Status-quo walk-forward (extended sample, $0 cost)
- IS = closes before 2026-09-28 00:00 UTC (n=81): PF 0.222
- OOS = 2026-09-28 closes (n=46): PF 0.104
- **Retention 47% < 60% → the status quo fails its own gate** (as at iter-0: 45%).

### 2.6 Cost sensitivity (status quo, n=127)
| Cost/trade | Net $ | PF |
|---|---|---|
| $0.00 | -151.15 | 0.257 |
| $0.25 | -182.90 | 0.197 |
| $0.75 (3x) | -246.40 | 0.124 |
Costs hurt but the strategy is deeply negative at $0 cost — **the edge, not the
accounting, is the problem** (unchanged from iter-0).

---

## 3. Candidate gating

### Gate definitions (implemented in `/tmp/lane-validation-iter1/gate.py`)
Entry-level predicates over FIFO pairs, no look-ahead. A candidate PASSes only
with: full replay at $0 and $0.25/trade; walk-forward IS/OOS with **OOS PF ≥ 60%
of IS PF, ≥100 IS trades, ≥30 OOS trades**; 3x-fee ($0.75) PF reported; and none
of the overfitting red flags (WR_IS > 90%, OOS decay > 70%, single-regime-only,
retention < 60%). <30 OOS trades → **NOT_VERIFIABLE** (not PASS, not FAIL).
Falsification: alternate splits (midpoint, ≤9-27 vs 9-28), fee multipliers
$0–$2.50, regime slices — I actively tried to break each candidate.

### 3a. Slip veto — forward validation (shipped 12:24 EDT = 16:24 UTC, user order)
Post-regime window (≥16:24 UTC): **7 entries, 8 closes, net -$11.85, PF 0.29**;
wipes 2/8 (25%) vs pre-regime 24/119 (20.2%). The journal shows 12 `slip_veto`
events (all BSC, slips 0.015–0.454). **Forward n=8 << 30 → NOT_VERIFIABLE.**
Key forward evidence (§1.2): both post-regime wipes were re-entries of
vetoed mints at slip≤0 — the veto changes *when* you enter, not *whether* the
LP gets pulled.

Historical replay of the veto rule (block slip>0, fail-open on unknown, n=80
kept / 45 blocked / -$94.42 of blocked losses incl. 17 wipes):

| Split | IS PF (n) → OOS PF (n) | Retention |
|---|---|---|
| Standard (</≥ 9-28 00:00 UTC), $0 | 0.426 (52) → 0.428 (28) | 100% |
| Standard, $0.25/trade | 0.336 (52) → 0.263 (28) | 78% |
| Midpoint (2026-09-27 20:35 UTC), $0 | 0.332 (40) → 0.599 (40) | 180% |
| ≤9-27 vs 9-28, $0 | 0.426 (52) → 0.428 (28) | 100% |

The retention survived every falsification split — the direction is genuinely
stable. But: **IS n=52 <100, OOS n=28 <30** (sample-size gate), full-sample
kept set still **-$54.30 @ $0 cost, PF 0.427** (0.317 @ $0.25), 3x-fee PF 0.19.
Fee multipliers on the kept set: $0 → PF 0.427; $0.25 → 0.317; $0.75 → 0.188;
$2.50 → 0.037. **Verdict: NOT_VERIFIABLE** at Track B sizes — loss-reducing,
not edge-creating; forward validation must continue to ≥30 OOS closes under
the regime. The veto stays (user's order); nothing about it upgrades to PASS.

### 3b. LP-pull anti-screen — feasibility
**NOT_FEASIBLE.** Entry `lp_burn_pct`/`lp_locked` keys present but null on all
125 pairs; journal `pool_created_at` null on 453/453 lines; entry
`pool_created_at` null on all pairs; `holder_top1_pct`/`holder_top5_pct` null
everywhere. There is no LP-burn/lock/age data source wired — a screen cannot be
built, let alone validated. (Unchanged from iter-0.)

### 3c. Hour-of-day / regime-conditioned entry filters
All gated at $0 cost, standard walk-forward. Every band of every feature is
negative in-sample (entry-hour table: only hours 12/14/16/18 positive, n≤9
each; signal-gain 200–400% band PF 0.030; higher buy/sell ratio → worse PF;
higher liquidity → worse PF).

| # | Candidate | Full: n / net / PF / WR / DD | IS PF(n) → OOS PF(n), retention | 3x-fee PF | Verdict |
|---|---|---|---|---|---|
| F1 | slip≤0 AND gain<100% | 21 / -$8.06 / 0.757 / — / — | — | — | **NOT_VERIFIABLE** (n=21<30; explicitly data-mined — do not ship) |
| F2 | slip≤0 AND liq≥$60k | 42 / -$28.56 / 0.359 / 36% / $28.56 | 0.416(24) → 0.239(18), 58% | 0.13 | **FAIL** |
| F3 | slip≤0 AND ratio≥3 | 32 / -$46.89 / 0.200 / 25% / $52.10 | 0.163(19) → 0.282(13), 173% | 0.10 | **FAIL** |
| F4 | gain<100% only | 38 / -$42.46 / 0.431 / 37% / $42.46 | 0.477(22) → 0.320(16), 67% | 0.24 | **FAIL** |
| F5 | entries 14:00–18:00 UTC | 35 / -$28.50 / 0.420 / 23% / $31.92 | 0.558(28) → 0.134(7), 24% | 0.22 | **FAIL** |
| B | entries 12:00–18:00 (local-hour variant) | 38 / -$26.19 / 0.469 / 26% / $29.61 | 0.558(28) → 0.289(10), 52% | 0.23 | **FAIL** |
| C | exclude gain 100–200% band | 80 / -$88.53 / 0.305 / 25% / $91.95 | 0.372(50) → 0.174(30), 47% | 0.16 | **FAIL** |
| E | slip-veto AND excl 100–200% | 53 / -$35.20 / 0.475 / 30% / $38.62 | 0.536(34) → 0.344(19), 64% | 0.23 | **FAIL** |
| — | status quo (reference) | 125 / -$148.72 / 0.239 / 19% / $182.64 | 0.222(79) → 0.104(46), 47% | 0.11 | **FAIL** (own gate) |

(Full-replay nets here are on the 125 FIFO pairs at $0 cost; close-line net is
-$151.15 — the 2 unmatched closes account for the -$2.43 difference.)

### Verdict table (consolidated)

| Candidate (origin) | Exp. PnL / n / WR / DD | OOS retention | 3x-fee | Verdict |
|---|---|---|---|---|
| Slip veto, historical (shipped, user order) | -$54.30 / 80 / 32% / $57.72 (@$0) | 78–100% across 3 splits | PF 0.19 | **NOT_VERIFIABLE** (IS 52<100, OOS 28<30; still negative) |
| Slip veto, forward (post-16:24 UTC) | -$11.85 / 8 / — / — | n/a | n/a | **NOT_VERIFIABLE** (need ≥30; 2/8 wipes were vetoed-then-re-entered mints) |
| LP-pull anti-screen | — | — | — | **NOT_FEASIBLE** (all LP/age fields null) |
| Hour / regime filters (F1–F5, B, C, E) | all negative, best PF 0.757 (n=21, mined) | 24–173%, all fail ≥1 gate | all <1.0 | **FAIL** (F1: NOT_VERIFIABLE, do not ship) |

**Nothing passes every gate. Ship-nothing from this lane.**

---

## 4. Falsification notes (what I tried to break)
- Slip-veto retention holds at 78–180% across three different IS/OOS splits —
  the *direction* is real, but the *magnitude* never reaches breakeven (kept-set
  PF 0.43 at $0 cost) and the sample is too small for Track B. Not falsified on
  stability; blocked on size and on the forward re-entry evidence.
- The two post-regime wipes falsify the strong causal claim "vetoing
  slip>0 avoids LP-pull wipes": both wiped tokens entered at slip≤0 after being
  vetoed. The veto removes ~$94 of historical chase losses but the wipe
  mechanism fires independently of entry slip.
- Hour filters collapse under alternate hour windows (F5: 24% retention) —
  classic single-regime overfitting; the "profitable hours" were n≤9 artifacts.
- Exit-mechanic changes remain **NOT_VERIFIABLE_FROM_TRADES_JSONL** (no
  intra-trade price paths) — restating the iter-0 hard limit for any sibling
  candidate of that type.

## 5. Data-quality notes
- **Timezone correction:** `trades.jsonl` and `candidates.jsonl` timestamps are
  **UTC**, not ET as prior reports labeled them (proof: last close 17:47:55
  would be in the future under EDT at read time; journal's 20:09 UTC = 16:09
  EDT ≈ now). The iter-0 "12:15" snapshot cutoff reproduces exactly when read
  as UTC. Recommend all lanes treat file `ts` as UTC going forward.
- 43 apparent "open" entries are a matching artifact: 9-24 old-schema entries
  (chain=null) whose closes carry only `realized_sol` (52 such closes,
  net -0.4410 SOL) — not truly open.
- 2 closes (2026-09-27 14:23:59 -$6.99; 16:46:23 +$4.56) could not be
  FIFO-paired within their mint's entry queue (re-entries); excluded from pair
  replay only.

## 6. Operational observations (for coordinator, not gated)
- Bot process confirmed running via `pgrep -f "fomo_trader[.]py"`; `bot.pid`
  now reads **1867** (was 23939 at the 12:24 EDT restart) — the bot has been
  restarted since the fix pass, presumably by the fix loop after one of the
  recurring kills. Fix-loop owns diagnosis; noting only.
- `iter-1/astra_stderr.log` shows the Codex-Astra lane hit
  `/usr/bin/codex: No such file or directory` — the known fragile Codex path
  across VM rebuilds. If that lane's implementer work is missing, this is why.
- Journal health: 453 lines, 16:25–20:09 UTC, 12 slip_veto events, 95 enter /
  346 guardrail_skip verdicts (skip reasons not journaled — minor gap for
  future analysis).

## 7. Open items for the coordinator
1. Sibling reports (CURSOR, CODEX-ASTRA) were not on disk at write time; if
   they land with new candidates I can gate them in a follow-up pass against
   the harness at `/tmp/lane-validation-iter1/gate.py`.
2. Slip-veto forward validation needs ≥30 OOS closes under the ≥16:24 UTC
   regime (currently 8) — the 4h loop should keep accumulating; the re-entry
   wipe evidence should temper expectations.
3. Recommend the loop treat file timestamps as UTC in all future reports.

---
*Report written 2026-09-28 ~16:15 EDT (20:15 UTC). Bot untouched. No repo files
modified. Harness: `/tmp/lane-validation-iter1/gate.py`, `baseline.py`.*
