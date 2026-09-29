# LANE-VALIDATION Report — Deep Research Pass 2026-09-28

**Lane:** Validation (independent gatekeeper). **Author:** subagent session c04a7b6e.
**Method:** Direct reads of `~/workspace/fomo-trader/runs/paper-1h/trades.jsonl` only (read-only).
No CLI agents, no replay-code reuse from other lanes — every number below was
recomputed with my own scripts in `/tmp/lane-validation/` (`gate.py`).
**Bot was not disturbed.** Nothing in the repo was edited; the report dir holds
only this report.

---

## 1. Headline findings (read first)

1. **Baseline aggregates CONFIRMED, trade count MISMATCHED.** The recorded
   "kickstart" aggregates (-$113.87 net, PF ≈ 0.276, max DD ≈ $119) reproduce
   from my direct read **only for the trade set through ~06:08 on 2026-09-28**
   (93 close lines: net -$113.79, PF 0.2736, DD $117.21 — within $0.08 / 0.003 /
   $1.78). But the recorded count "67 closed" matches **no** reconstruction:
   the set that reproduces the P&L has 93 closes, and no clean subset (BSC-only,
   single-day, ticket-filtered, FIFO-matched pairs, any contiguous window) has
   exactly 67. The 67 figure is unaccounted for — likely the kickstart harness
   counted differently (post-cost filtering, a narrower window, or a miscount).
   Full detail in §2.
2. **The one-tick -100% venue wipes ARE the leak — confirmed independently.**
   24 rug-gap exits (-100% one-tick wipes) lost **-$100.04** of the -$139.60
   lifetime net (71.7%). All 109 dump-ish exits together: -$137.37. The six
   trailing-stop exits actually *made* +$3.37.
3. **The leak is structural, not cost-driven.** Lifetime PF 0.239–0.254 even at
   $0/trade cost; break-even needs PF 1.0, so fees/slippage accounting cannot
   rescue the edge. Cost-sensitivity sweep: $0.10 → PF 0.214, $0.50 → PF 0.145.
4. **The baseline itself fails the Track B walk-forward gate.** IS (through
   9-27): PF 0.278 → OOS (9-28): PF 0.124, **45% retention** (<60% required).
   Any candidate must beat this bar, not the full-sample mean.
5. **On 9-28, one-tick wipes were 81.7% of the day's loss** (-$32.47 of -$39.73)
   — the "venue wipes as most of the day's losses" claim is confirmed (11 such
   exits that day).
6. **Candidate gating: PENDING.** The other lanes' reports were not on disk
   when this report was written (dir created 12:01 ET, empty at read time).
   My independent gating harness (`/tmp/lane-validation/gate.py`) is built,
   smoke-tested, and ready: entry-level no-look-ahead replay, walk-forward
   IS/OOS (60% retention, ≥100 IS / ≥30 OOS), 3x-fee stress, overfitting red
   flags. §4 defines the gates and a methodological hard limit (exit-mechanic
   changes are NOT verifiable from trades.jsonl — no intra-trade price paths).

---

## 2. Independent baseline reproduction

### 2.1 Method
- Direct parse of all 323 lines of trades.jsonl (163 close lines, 160 entry lines).
- Close-line read: every line with `type == 'close'` and `realized_usd != null`
  (117 lines). Each close line is one complete round trip — net position P&L
  including rung profits (the `rungs` field documents the rung that fired;
  verified against matched entries, §5).
- Pair replay (for candidate gating): FIFO entry→close matching by mint, 115
  usd-denominated pairs (2 close lines could not be FIFO-paired within their
  mint's entry queue due to re-entries; 46 older-schema close lines have only
  realized_sol). Used for §4 gating; aggregates differ from the close-line
  read by <2%.

### 2.2 Lifetime numbers (close-line read, authoritative)

| Metric | Value |
|---|---|
| Closed round trips (realized_usd) | **117** |
| Net P&L | **-$139.60** |
| Gross wins / gross losses | +$47.64 / -$187.24 |
| Profit factor | **0.254** |
| Win rate | **23.9%** (28/117) |
| Max drawdown (closed-trade equity) | **$143.02** |
| Avg P&L per trade | -$1.19 |
| Best single trade | +$5.31 (FM / WBNB, 2026-09-27 19:23 ET) |
| SOL-chain-only closes (52, realized_sol) | -0.4410 SOL, PF 0.489, DD 0.4976 SOL |

### 2.3 Match/mismatch vs recorded baselines

| Recorded claim | My reproduction | Verdict |
|---|---|---|
| Kickstart: 67 closed, -$113.87, PF 0.276, DD $118.99 | Direct read through **2026-09-28 06:08** (93 closes): **-$113.79 / PF 0.2736 / DD $117.21** | **Aggregates MATCH (within $0.08 / 0.003 / $1.78); count MISMATCHES.** No subset yields 67: BSC-only through 06:08 = 87; 9-27 alone = 67 closes but -$70.61/PF 0.343; any 67-length contiguous window = -$69.45; FIFO pairs through 06:08 = 91. The "67" cannot be reproduced — treat the count as unverified. |
| "18 rug-gap exits were essentially the entire net loss" | Direct read: **24 rug-gap (-100% wipe) exits, -$100.04** of -$139.60 lifetime (71.7%). At the ~06:08 snapshot the file held 16 such exits (-$77.97 of -$113.79, 68.5%). The 18th such exit occurred 2026-09-28 07:00; 18 sum -$83.06 | **PARTIAL.** They are the dominant leak (largest single bucket, >2/3 of net), but not the whole net loss, and the count 18 is a snapshot that has since grown to 24. |
| "one-tick -100% venue wipes = most of the day's losses" (9-28 session) | 9-28: net -$39.73; 11 rug-gap exits totaling **-$32.47 = 81.7%** of the day | **CONFIRMED.** |

### 2.4 P&L by exit reason (117 closes)

| Exit reason bucket | n | Net $ | Avg $ |
|---|---|---|---|
| rug-gap (-100% one-tick wipe) | 24 | -100.04 | -4.17 |
| dump-detector / venue-dump (partial wipe) | 86 | -42.34 | -0.49 |
| trailing stop | 6 | +3.37 | +0.56 |
| stale exit (thesis dead) | 1 | -0.59 | -0.59 |

Dump-ish exits combined (109): -$137.37, PF 0.222. Rug-gap wipes average
-$4.17 on ~$7 tickets — most already took a TP rung before the wipe (e.g. the
AGPUB close took rung 0 at +51% then dumped to -100% on the remainder; net
position -$1.72), so **the wipes hit the runner half, not the full ticket**.

---

## 3. Regime breakdown (independent)

### 3.1 By day
| Day | n | Net $ | PF | WR | DD $ |
|---|---|---|---|---|---|
| 2026-09-24 | 14 | -29.26 | 0.151 | 7.1% | 32.68 |
| 2026-09-27 | 67 | -70.61 | 0.343 | 25.4% | 71.31 |
| 2026-09-28 | 36 | -39.73 | 0.124 | 27.8% | 40.23 |

Every day is negative; 9-27 had the best PF (0.343) but the worst dollar loss.

### 3.2 By chain / ticket
- BSC: 111 closes, -$136.42, PF 0.237, WR 24.3% — **the entire business is BSC.**
- Solana: 6 closes, -$3.18, PF 0.621 (n too small to mean anything).
- Ticket ≈0.009 BNB: 55 closes; early 9-24 tickets 0.06 (~$9): 6 closes.

### 3.3 By entry signal gain (116/117 closes matched to an entry)
| Signal gain | n | Avg $ | Sum $ | WR |
|---|---|---|---|---|
| <100% | 35 | -1.09 | -38.07 | 34% |
| 100–200% | 44 | -1.57 | -69.15 | 23% |
| 200–400% | 33 | -1.10 | -36.42 | 12% |
| 400%+ | 4 | -0.13 | -0.52 | 25% |

Stronger signal → *worse* win rate and worse average. The 100–200% band is the
largest loss bucket. This is consistent with "signal chases tops; entries fill
into the dump."

### 3.4 By hour of day (ET close time)
Losses concentrate 20:00–22:00 (-$30.43 / -$16.82 / -$21.63) and 14:00–17:00;
18:00 (+$6.50, PF 2.94) and 16:00 (+$4.88, PF 1.59) were the only profitable
hours. Hours are exit times, not entry times — treat as descriptive, not a
tradable filter, without entry-time mapping.

### 3.5 Cost sensitivity (pair replay, n=115)
| Extra cost/trade | Net $ | PF |
|---|---|---|
| $0.00 | -137.17 | 0.239 |
| $0.10 | -148.67 | 0.214 |
| $0.20 | -160.17 | 0.192 |
| $0.50 | -194.67 | 0.145 |
| $1.00 | -252.17 | 0.094 |

Verdict: costs move the needle but the strategy is deeply negative at $0 cost.
**Cost accounting is not the fix; the edge is.**

### 3.6 Baseline walk-forward (methodology check for candidate gates)
- IS = closes before 2026-09-28 00:00 (n=79): net -$97.44, PF 0.2776, WR 21.5%
- OOS = 2026-09-28 closes (n=36, meets ≥30): net -$39.73, PF 0.1241, WR 27.8%
- **OOS retention = 45% < 60% → the status quo fails its own gate.**
  Any candidate must clear 60% retention with ≥100 IS / ≥30 OOS trades.

---

## 4. Candidate gating — STATUS: PENDING (other lanes' reports not on disk)

### 4.1 Readiness
- LANE-CURSOR report: **not present** at read time.
- LANE-CODEX-ASTRA report: **not present** at read time.
- Directory `hidden_files/research-pass-2026-09-28/` was created 12:01 ET and
  was empty. This lane did not wait: baseline + harness are done and this
  report is written. When the sibling reports land, I will gate every proposed
  candidate through `gate.py` in a follow-up pass and append the verdict table
  here.

### 4.2 Gate definitions (already implemented in `/tmp/lane-validation/gate.py`)
Each candidate is expressed as an **entry-level predicate** over FIFO-matched
(entry, close) pairs — no post-entry information, no look-ahead. Gates:
1. **Full replay** with realistic costs: net, PF, WR, DD, avg/trade.
2. **Walk-forward**: IS = closes before 2026-09-28 00:00, OOS = 2026-09-28;
   requires OOS PF ≥ 60% of IS PF, **≥100 IS trades and ≥30 OOS trades**.
3. **3x-fee stress**: per-trade cost ×3 must not collapse PF below 1.0
   (reported; a candidate already negative at 1x cost fails trivially).
4. **Overfitting red flags** (auto-fail): WR_IS > 90%; OOS PF decay > 70%;
   retention < 60%; single-regime-only (works on exactly one day/chain/hour).
5. Sample-size rule: candidates covering <30 OOS trades are NOT_VERIFIABLE,
   not PASS.

### 4.3 Hard methodological limit (flagged now, applies to all lanes)
`trades.jsonl` contains **no intra-trade price paths** — only entry, peak,
exit, rung marks, and exit reason. Therefore:
- ✅ **Verifiable by me:** pre-entry screens/filters (skip trades by entry
  data: liquidity, signal gain, m15 buys/sells/volume, mcap, slippage,
  latency, hour).
- ❌ **NOT verifiable by me from this data:** trailing-stop width changes,
  dump-detector sensitivity changes, TP-ladder changes, any exit-mechanic
  tweak — these require a no-look-ahead price-path replay tape (GeckoTerminal
  candles or the bot's own candle store). If LANE-CURSOR or LANE-CODEX-ASTRA
  propose exit-mechanic candidates, I will mark them **NOT_VERIFIABLE_FROM_TRADES_JSONL**
  unless the proposing lane ships its own validated price-path replay, which I
  will then independently re-run rather than trust.

### 4.4 Verdict table
| # | Candidate (lane) | Full replay (net / PF / WR / n) | IS PF → OOS PF (retention) | 3x-fee | Red flags | Verdict |
|---|---|---|---|---|---|---|
| — | *(no candidates proposed yet)* | — | — | — | — | PENDING |

---

## 5. Data-quality notes (for the other lanes)
- Each close line = one complete round trip; `realized_usd` is position-net
  including rung profits (verified against matched entries, e.g. 0x9e49…ee094).
- 46 early close lines (9-24, chain=null) carry only `realized_sol`; 6 have
  `chain: solana`. 117 carry `realized_usd`. Pair replay uses the 115
  FIFO-matchable usd pairs; aggregates differ from the 117-line read by <2%.
- 5 close lines have no FIFO-matchable entry (re-entries); 2 entries remain
  open. 158 total FIFO round trips, 115 with usd.
- Entry records carry (post-Round-3 enrichment): `signal_gain_pct`,
  `signal_ratio`, `liquidity_usd`, `source`, `window`, `signal_price_usd`,
  `commit_price_native/usd`, `slip_from_signal_pct`, `entry_latency_ms`,
  `m15_buys/sells/volume_usd`, `mcap_usd` (92/115 pairs), and allocator fields
  (60/115). Candidate screens using fields with <92/115 coverage should be
  gated on the covered subset only.

## 6. Open items for the coordinator
1. The "67 closed" count in the kickstart baseline is unverifiable; the
   aggregates reproduce at n=93. Recommend the other lanes cite n=93 for that
   snapshot or document the 67-count methodology.
2. Sibling reports not yet on disk — candidate gating is the explicit
   follow-up; this session is persistent and ready.
3. If any candidate is an exit-mechanic change, the lane must provide a
   no-look-ahead price-path replay tape; trades.jsonl cannot verify it.

---
*Report written 2026-09-28 ~12:15 ET. Bot untouched (paper-only, running). No
repo files modified. Harness: `/tmp/lane-validation/gate.py`.*
