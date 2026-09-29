# LANE-CURSOR report — full-system audit + lifetime attribution
Deep research pass, 2026-09-28. Lane: read-only audit (no code edits, no restarts).
Auditor ran the Cursor agent CLI twice (first attempt stalled on an internal
confirmation gate; retry with `--mode=plan` was still running at report time —
its output, if any, is supplemental; every number below was independently
derived in my own shell from `runs/paper-1h/trades.jsonl`, `bot.log`,
`quote_paths/`, and the code).

## 0. TL;DR diagnosis

The leak is **instant post-entry LP-pull rugs on BSC**, not bad prints and not
fees. 29 of 163 closes (≈18%) are full -100% wipe exits; they account for
≈$100 of ≈$140 stamped losses (72%; obs_dashboard's broader rug-gap
classifier: $196 of $279 gross = 70%, criterion 6 TRIPPED). Tick-level
`quote_paths/` captures on 20 of 29 wipes show the same signature: price flat
for minutes, then a single ~0 tick. `bot.log` shows the on-chain PancakeSwap
router quoting dust at the sell (e.g. MUMU: 1.16e12 token raw → 145,637 wei;
SF🐲: 1.36e25 raw → 1.43e10 wei ≈ $0.00000001) — the pool was genuinely empty,
so this is **not a feed glitch**. Exit-side speed cannot save these (a faster
dump detector just sells the same dust sooner).

Structural causes (code locations in §5):
1. **BSC has no LP-burn/lock check and no holder-concentration check.**
   `enter_bsc` (fomo_trader.py ~1988) screens only via
   `bsc_swap.honeypot_check` (buy+sell round-trip ≥ 50%), which passes on any
   fresh pool with LP present — exactly the setup a dev uses before pulling LP.
   The `lp_burn_pct`/`lp_locked` fields are **dead**: `lp_evidence()` reads
   `p.get("lp_burn_pct")` from DexScreener/GeckoTerminal payloads, a field
   neither API provides → always None on all 160 entries. Solana's `rug_check`
   (mint/freeze authority + holder concentration via Solana RPC) cannot run on BSC.
2. **The bot systematically buys the top of vertical moves.** Pullback wait is
   disabled (`entry.pullback_pct=0`). On the 92 enriched entries,
   `slip_from_signal_pct` (fill vs signal price) splits the book: slip>0
   (chasing, median +7.9% on wipes) → 45 trades, **-$94.42, 38% wipe rate**;
   slip<0 → 47 trades, -$6.46, 6% wipe rate. Positive-slip entries are 68% of
   stamped dollar losses.
3. **The dump detector (12%/60s) is a hair-trigger that adds churn**:
   75 partial dump exits on BSC lost -$29.60 (avg -$0.39) — each exit frees a
   slot for a fresh entry into the same rug population.
4. **The hard stop is mathematically unreachable** in ladder mode
   (trail 25% < hard 35%, peak ≥ entry ⟹ dd_peak ≥ trail always fires first).
   Dead safety net; the trailing stop is the only real backstop.

## 1. Lifetime numbers (all 163 closes, 2026-09-24 → 2026-09-28)

| Metric | Value | Notes |
|---|---|---|
| Closes / entries | 163 / 160 | 3 orphan closes (positions predate journal logging); no trades 9/25–9/26 |
| Net P&L | **≈ -$187** | obs_dashboard canonical (-$187.26); my build: -$139.60 stamped + ≈-$51 SOL-era |
| Win rate | 30.1% (49W/114L) | stamped BSC subset: 23.9% |
| Profit factor | 0.436 | stamped BSC subset: 0.254; last-100 window: 0.29 |
| Avg win / avg loss (stamped) | +$1.70 / -$2.10 | expectancy ≈ -$1.19/trade |
| Max drawdown (stamped equity) | -$143.02 | kill criteria 1, 4, 6 TRIPPED (obs_dashboard: program_killed=True) |
| SOL chain | 52 closes, -0.441 SOL (≈ -$51 @ ~$115) | Sep-24 era |
| BSC chain | 111 closes, -0.176 BNB, stamped -$139.60 | Sep-27/28 era |
| Median round-trip cost | -1.09% of ticket | costs are NOT the leak (criterion 2 ok) |

### 1a. P&L by exit reason (USD-stamped BSC closes, n=117)

| Exit group | n | USD |
|---|---|---|
| dump detector -100% | 13 | -53.63 |
| venue dump m5 -100% | 10 | -41.40 |
| dump detector (partial, -12%…-97%) | 75 | -29.60 |
| venue dump (partial) | 7 | -15.33 |
| trailing stop (normal) | 5 | +8.55 |
| trail-stop wipe-like (≥90%) | 1 | -5.01 |
| **Wipe-like subtotal** | **29 incl. SOL** | **≈ -100.6 (72% of stamped losses)** |
| stale exit (30m/<10%) | 6 | +3.40 |
| take-profit rotate | 1 (SOL era) | small + |

SOL-era (unstamped, native): 5 trail-stop wipe-likes ≈ -0.34 SOL; 27 normal
trailing stops ≈ -0.20 SOL; 14 partial dump exits +0.011 SOL; 6 stale +0.003.

### 1b. Attribution by entry setup

| Slice | n | USD | Wipe rate |
|---|---|---|---|
| slip_from_signal > 0 (chase) | 45 | **-94.42** | 38% (17/45) |
| slip_from_signal < 0 | 47 | -6.46 | 6% (3/47) |
| window 5m (early/pre-pump) | 14 | -43.69 | 50% (7/14) |
| window 15m (regular) | 102 | -100.47 | 17% (17/102) |
| signal gain 100–200% | 49 | -69.15 | 20% |
| signal gain ≥200% | 51 | -36.94 | 8% (buys the top, loses via partial exits) |
| entry hour 20:00–22:00 ET | 32 | ≈ -65 | volume-concentrated |
| hold < 5 min | 84 | -67.61 | — |
| hold < 15 min | 94 | -104.69 | — |

All 116 stamped closes with a known source are GeckoTerminal; the DexScreener
fallback never produced a stamped close. 84 of 117 stamped closes die within
5 minutes of entry.

## 2. Dollar attribution to dominant leaks

1. **Instant LP-pull rugs (full -100% wipes): ≈ -$100 (72% of stamped losses).**
   29 exits. Median hold ~12 min; 8 wiped within 5 min of entry. Representative:
   MUMU (entry 08:30:57, flat 4 min, one 9.61e-15 tick at 08:34:50 → dump
   detector → on-chain sell 145,637 wei → -$3.67). 6 of the 29 had banked a
   +50% TP rung first, cutting the loss to ≈ -23% — the TP ladder is the only
   mechanism that has ever mitigated a wipe.
2. **Partial dump/venue exits: ≈ -$45.** 82 exits, avg ≈ -$0.55. The 12%/60s
   dump detector fires on normal memecoin chop; each exit churns the slot.
3. **Trailing-stop bleed (SOL era): ≈ -$0.54 native.** Normal operation.
4. **Costs: negligible** (-1.09% median round-trip; paper quotes).

## 3. Pipeline map (signal → entry → manage → exit)

**Scan (Hunter, fomo_trader.py 884–1116):** GeckoTerminal trending+new pools
(4+3 pages/chain, sequential through 20/min token bucket), filters:
m15 ≥ +20%, buy/sell ≥ 2.0, liq $8k–$500k, m15 buys ≥ 10, sells ≥ 5,
vol ≥ $5k, strict native-pair enforcement (SOL/WBNB quote only). Pre-pump
("early") lane: m5 +10–150% and accelerating (p15 > p5×1.2), m15 ≥ 15%,
liq ≥ $8k. Failover to DexScreener boosts only when GT yields 0 pages.
`lp_evidence()` reads non-existent `lp_burn_pct`/`lp_locked` fields → always None.

**Entry (`enter` 1829 / `enter_bsc` 1988):** pending_entries slot guard →
SOL: `rug_check` (mint/freeze authority must be disabled, top1 ≤ 40%,
top5 ≤ 75%, fail-closed) ; BSC: `honeypot_check` round-trip ≥ 50% only →
pullback wait (disabled, 0/0) → Jupiter/PancakeSwap entry quote → dust-quote
reject (<10,000 tokens) → commit-time recheck under lock
(`_entry_commit_ok`: caps, kill switch, signal age ≤ 180s or re-validate) →
`_allocate` (allocator, now **live** with uncalibrated priors; take≈100%) →
BSC-only `wipe_drift_cap_native` (halves ticket when fill > signal price;
deployed with the 11:53 EDT 9/28 restart, **never yet observed firing**) →
virtual ledger write (`tokens_raw`, `sold_sol=0`) → manage thread spawned.
Paper fills ARE the quotes (dry_run: `send_quote` returns `outAmount`).

**Manage (`_manage_once` 2241):** 2s poll. Price: SOL = Jupiter⨉DS race
(`_race_price`, rejects 0/None/NaN/inf but **accepts tiny positives like
1e-17**); BSC = DexScreener `priceUsd` best pair (same source as the venue
tripwire — **not independent on BSC**). No price → no exits (blind counter).
Peak ratchets up only. Exit precedence per cycle: venue m5 ≤ -30% (30s
cadence) → dump detector (-12%/60s on own tick hist) → trailing stop
(25%; 12% after any TP rung; 10% in kill-switch protect mode) → **hard stop
35% (unreachable, see §4)** → stale exit (30m & <+10%) → else hold.
TP ladder [[50, 50]]: at +50% gain sell 50% (honest fill accounting; rung
recorded with realized gain). Full exits: `sell_pct_of_balance` re-quotes at
sell time (BSC: on-chain router; raises on dust → sell fails → position held,
retry next cycle), then `close_trade` journals exact ledger
`sold + dust − buy`.

**Guards:** kill switch $60/day USD or 0.2 SOL/day (adaptive: min(fixed,
6%×day-start bankroll)); drawdown brake at 15% (resume <10%); max 3 open,
30/day (40 after +$10), 6/hour rolling; 10-min/mint cooldown; 24h
dump-cooldown per mint after dump exits; halt.flag exits 42 (no auto-restart).

## 4. Holes and edge cases found

- **H-A (leak): BSC has no LP/holder screen.** Only the honeypot round-trip;
  passes on fresh pools pre-rug. `lp_burn_pct`/`lp_locked` dead fields (both
  chains). *Fix needs new data + validation.*
- **H-B (leak): chase entries.** Pullback disabled; slip>0 = 68% of losses,
  38% wipe rate. `wipe_drift_cap_native` exists but BSC-only, only halves the
  ticket (doesn't veto), and has never fired in the journal. *Strongest
  validation-ready candidate: veto slip>0 (or >threshold).*
- **H-C (churn): dump detector 12%/60s.** 75 partial exits, -$29.60, feeds
  re-entry churn. Shadow 8%/30s candidate exists but replay says stay shadow.
- **H-D (dead code): hard stop unreachable** in ladder mode (trail 25 < hard
  35 ∧ peak ≥ entry ⟹ trailing always wins). Either gate hard stop on entry
  independently or document/remove. Not a leak — the trailing stop is the real
  backstop — but the "hard stop" safety story is false.
- **H-E (investigated, reject): second-source confirm on venue -100%.**
  Sampled wipes show the on-chain router agreed (dust), so confirmation would
  not have saved them. The -100% prints are genuine LP pulls, not feed glitches
  (20/20 captured wipes: flat-then-one-zero-tick; 0 showed decay).
- **H-F (ops): allocator flipped to `live`** in runs/paper-1h/config.json with
  uncalibrated priors after an explicit "stays in shadow" verdict (2026-09-28
  changelog). Behaviorally near-identical today (takes ~100% at 0.95–1.15x),
  but the process breach should be reverted or re-verdict.
- **H-G:** `_race_price` accepts arbitrarily small positive prices (the
  1e-17 wipe tick passed validation). A one-tick >99.9% down-move hold/verify
  rule is conceivable but would not have changed outcomes (router confirmed).
- **H-H:** `peak` ratchets on phantom spikes (no high-print sanity check);
  not observed as a loss driver in this journal.
- **H-I:** `_px_hist` is in-memory; a restart blinds the dump detector for 60s.
- **H-J:** 163 closes vs 160 entries — 3 orphan closes predate journal
  logging; harmless.
- Working tree is dirty (915 uncommitted lines in fomo_trader.py + tests +
  CHANGELOG from the research pass; sibling lane active). Read-only lane:
  noted, not touched. Bot PID 17262 running the 15:34 UTC build, restarted
  11:53 EDT 9/28.

## 5. Ranked candidate fixes (hypothesis each targets)

1. **Veto positive-slip entries** (`slip_from_signal_pct > 0`, tune threshold
   0–10%). Targets H-B: 45 chase entries → -$94.42 (68% of stamped losses),
   wipe rate 38% vs 6%. Mechanism: market-buying 5–45% above the signal print
   buys the dev's exit liquidity minutes before the LP pull. Veto-only,
   conservative. → validation lane: IS/OOS gates, ≥30 OOS, retention ≥60%.
2. **BSC LP-burn/lock pre-entry verification** (new data source required —
   BscScan LP-holder query or equivalent). Targets H-A: the structural hole;
   only defense that fires *before* the money is gone, since no exit can save
   a -100% LP pull (proven by replay + router evidence). Currently not_runnable;
   needs plumbing, then Track B validation.
3. **Pool-age minimum** (DexScreener `pairCreatedAt` is available in the same
   payload the Hunter already fetches). Targets H-A from a different angle:
   the wipe population is minutes-old pools; require age ≥ N min. Cheap to
   implement from existing data; needs validation for N and false positives.
4. **Sweep `dump_drop_pct`** (12%/60s → looser) in shadow first. Targets H-C:
   -$29.60 churn over 75 exits plus re-entry exposure. Must keep an anti-rug
   reflex; validate against the shadow_dump harness, not live.
5. **Enable pullback wait** (`entry.pullback_pct` > 0). Targets H-B via a
   different mechanism (wait for the dip instead of vetoing). Risk: just
   reduces fill rate; needs validation.
6. **Earlier first TP rung** (e.g. bank 50% at +30–40% instead of +50%).
   Targets wipe severity: the only observed mitigant (6 wipes cut to ≈-23%).
   Changes upside profile; validation lane must weigh expectancy, not just
   wipe losses.
7. **Fix or remove the dead hard stop** (H-D). Housekeeping; no P&L claim.
   If kept, evaluate it against entry independently of the trailing stop.
8. **Revert allocator to shadow** until a pass verdict (H-F). Process hygiene;
   no P&L claim (behavior ≈ identical today).

Explicitly NOT recommended: tightening the dump detector / venue tripwire
(replay showed a one-tick -100% LP pull cannot be saved by a faster threshold;
tighter = more churn), second-source confirmation on venue -100% (investigated:
router agreed, would not have saved the observed wipes), any sizing increase
or guardrail loosening (forbidden).

## 6. Method notes

- All numbers derived from `runs/paper-1h/trades.jsonl` (323 lines:
  160 entries, 163 closes), cross-checked against `bot.log` sell quotes and
  79 `quote_paths/*.jsonl` tick captures (20 of 29 wipe-like exits had
  captures; all 20 show flat-then-one-zero-tick, 0 show decay).
- USD conversion: journal `realized_usd` where stamped (117 closes, all BSC
  era); SOL era via `sol_usd` stamp (≈$115 on 9/24); obs_dashboard's -$187.26
  canonical total adopted for the lifetime figure.
- Slip/wipe correlations are descriptive (92 enriched entries), not validated —
  handed to the validation lane for gating. No profitability claimed for any
  candidate.
- Constraints honored: read-only; bot untouched (running PID 17262);
  trades.jsonl/state.json/bot.log/deaths.log/keypair.json unmodified; no key
  material accessed; no sizing/guardrail-loosening suggestions.
