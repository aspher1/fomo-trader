# LANE-CURSOR report — iteration 1 full-system audit + lifetime attribution
2026-09-28 ~16:10–16:50 EDT. Lane: read-only audit (no code edits, no restarts, bot untouched).

## 0. Method note

- The Cursor agent CLI was used as instructed: first attempt died in 3.5s with
  transient `socket hang up` (`Error: [aborted] socket hang up`, exit 1); the one
  permitted retry ran ~11 min and **completed** with a full audit, received after
  the initial report was written. Its independently-derived numbers (stamped net
  -$151.15, PF 0.257, WR 26.0%, BSC -$147.97) match this report's to the cent;
  its novel findings were verified in my own shell and appended as §8.
  Every number in §§1–7 was derived in my own shell from
  `runs/paper-1h/trades.jsonl`, `runs/paper-1h/candidates.jsonl`,
  `runs/paper-1h/failed_quotes.jsonl`, the live `runs/paper-1h/config.json`,
  and the code — nothing is quoted from iteration 0.
- Ops flag (not mine to fix): the bot PID changed mid-audit — `bot.pid` holds
  `1867` but `pgrep -f "fomo_trader[.]py"` returned `7149` at ~16:40 EDT (it was
  1867 at 16:08). The journal kept flowing (candidates.jsonl through 16:10 EDT),
  so trading continued; the pidfile looks stale after a restart. Coordinator /
  fix-loop should reconcile.

## 1. Lifetime numbers (all 173 closes / 170 entries, 2026-09-24 → 2026-09-28)

| Metric | Value |
|---|---|
| Entries / closes | 170 / 173 (3 orphan closes predate journaling) |
| USD-stamped closes (BSC+SOL era) | **n=127, net -$151.15, PF 0.257, WR 26.0% (33/127)** |
| Avg win / avg loss (USD) | +$1.59 / -$2.16; expectancy **-$1.190/trade** |
| Max drawdown (USD equity) | -$154.57 |
| SOL-native closes (Sep-24 era) | n=46, net -0.42 SOL, PF 0.476, WR 45.7% |
| Trades/day | 9/24: 58E/60C; 9/27: 66E/67C; 9/28: 46E/46C; none 9/25–9/26 |

### Chain asymmetry (USD-stamped only)

| Chain | n | Net | PF | WR | Wipes (≤-$3.50) |
|---|---|---|---|---|---|
| BSC | 121 | **-$147.97** | 0.242 | 26.4% | 22 |
| Solana | 6 | -$3.18 | 0.621 | 16.7% | 1 |

The entire book is BSC now. All structural losses live on BSC.

### P&L by exit group (USD, n=127)

| Exit group | n | USD |
|---|---|---|
| Wipe-like, loss ≤ -$3.50 (dump-detector -100% + venue-dump -94.5/-100% + trail -79/-100%) | 23 | **-126.01 (83.4% of USD losses)** |
| Dump-detector partials (not wipe-like) | 88 | -26.51 (avg -$0.30) |
| Venue-dump partials | 9 | -6.77 |
| Trailing-stop winners | 6 | +8.73 |
| Stale exit | 1 | -0.59 |
| Closes with a TP rung banked first | 29 | (mitigated subset of the above) |

### Hour of day (ET, USD closes)

Worst: 16:00 (n=12, -$30.43), 13:00 (n=11, -$27.52), 18:00 (n=11, -$21.63),
17:00 (n=10, -$16.82). Only positive hours: 12:00 (+$7.90) and 14:00 (+$6.50).
Wipes (23) cluster 13:00–19:00 ET (16 of 23).

### Hold duration (USD): <5m n=91, -$67.29 | <15m n=11, -$44.02 | <60m n=18, -$38.84 | ≥60m n=6, -$5.56. Fast death dominates.
### Window: 15m n=111, -$114.03 (exp -$1.03) | **5m n=15, -$41.68 (exp -$2.78)** — the "early" 5m window is ~2.7× worse per trade.

## 2. Reconciliation with iteration-0 baselines (12:16 EDT)

- Iter-0: 163 closes / 160 entries; stamped net -$139.60; wipes ≈$100 (71.7%).
- Now: 173 closes / 170 entries; stamped net -$151.15; wipes $126.01 (**83.4%**).
- Pre-slip-veto-cutoff (12:24 EDT) subset in my build: n=119, -$139.30 — matches
  iter-0's -$139.60 within $0.30 (two closes landed 12:16→12:24). Reconciled.
- The wipe share **grew** from 72% → 83%: the structural leak is accelerating
  relative to everything else, and the slip veto did not bend it (see §3).

## 3. Slip-veto regime: before vs after 12:24 EDT today (USD closes)

| Regime | n | Net | PF | WR | Expectancy | Wipes |
|---|---|---|---|---|---|---|
| Before 12:24 EDT | 119 | -$139.30 | 0.257 | 24.4% | -$1.171 | 21 |
| After 12:24 EDT | 8 | -$11.85 | 0.260 | 50.0% | -$1.481 | 2 |

- The veto works **mechanically**: 12 `slip_veto` journal events (median vetoed
  slip **+6.8%**, max **+45.4%**, median signal gain 88%, median liq $77.8k); all
  12 match `SLIP-VETO` lines in bot.log 1:1; **zero** positive-slip entries
  since (7 post entries, median slip -16.4%).
- But the binding constraint **survives the veto**: two post-veto closes are
  full -100% wipes on non-chase entries —
  - **PHOE** (17:18:52 UTC): slip **-0.6%**, signal +277%, liq $84k, 331 buys, mcap $486k → -$6.94 via `dump detector -100.0% in 60s`. A high-conviction, deep-liquidity signal still got LP-pulled.
  - **SMHB** (17:47:55 UTC): slip **-7.6%**, signal +63%, liq $52.5k, 26 buys → -$6.94 via `venue dump: DexScreener m5 -100.0%`.
- Conclusion: the veto removed the chase-driven *subset* of wipes, but non-chase
  entries are still exposed to instant LP pulls. Slip>0 was a correlate, not the
  cause. n=8 post is small — the 4h loop keeps validating — but the two wipes
  already falsify "veto fixes the binding constraint."

## 4. Pipeline map (signal → entry → manage → exit), with exact code locations

**Scan** — `Hunter.scan`, fomo_trader.py:915. GeckoTerminal trending+new pools
(30s poll), DexScreener fallback (m5 window, 60 req/min). Thresholds live
`runs/paper-1h/config.json`: min m15 gain 20%, buys ≥10, sells ≥5, buy/sell ≥2.0,
liq ≥$8k, 15m vol ≥$5k. Every surfaced signal is journaled
(`_journal_candidate`, fomo_trader.py:2533 → journal.py:129): verdict
`enter` (passed guardrails) or `guardrail_skip`.

**Entry** — threaded `enter()` fomo_trader.py:1856 → `enter_bsc()` fomo_trader.py:2022.
Order on BSC: position-cap check (2034) → `bsc.honeypot_check` (2051,
implemented bsc_swap.py:142: buy+sell round-trip quote ≥50% — **passes on any
fresh pool with LP present, i.e. exactly the pre-pull setup**) → pullback wait
**disabled** (`hunter.entry.pullback_pct=0`, 2060–2085) → decimals (2087) →
entry quote (2094) → dust-quote reject <10k units (2101) → `_entry_commit_ok`
(2117: rechecks caps + kill switch under lock) → `_allocate` (2128, shadow mode:
journals only, `_allocate` fomo_trader.py:1526, `mode_of` allocator.py:186) →
`wipe_drift_cap_native` (2135, fomo_trader.py:159: shrink positive-slip ticket to
0.5x — **dead while the veto is on**, the code comments say so at 2137–2139) →
`_slip_veto` (2141, fomo_trader.py:2556: vetoes slip>0, journals `slip_veto`
events via journal.py:171, fail-open on unknown slip) → virtual-ledger commit
(2144–2169). Solana path differs only in the screen: `rug_check` (1888,
implemented 1637: mint/freeze authority + holder concentration via Solana RPC,
fail-closed) + `honeypot_check` (1693, Jupiter route existence).

**Manage** — `_manage_once` fomo_trader.py:2283, called per position (2275) with
TP [[50,50]], trail 25%, hard 35% (live config). Exit priority is hard-coded
in order: venue-dump (2443) → dump detector 12%/60s (2369–2384) → **trailing
stop (2487)** → **hard stop (2494, unreachable — trail 25% < hard 35% and
dd_peak ≥ dd_entry whenever peak ≥ entry, so the trail always fires first;
dead safety net)** → stale 30m/<10% (2516). TP rung fired → trail tightens to
12% (`trail_after_tp_pct`, 2340).

**Guards** — `guardrails_ok` fomo_trader.py:1602: kill switch (USD adaptive cap
$60/day, `_kill_switch_tripped` 1472, `money.effective_daily_loss_cap_usd`
money.py), drawdown brake (money.py), dump cooldown per mint (1580), max 3
positions, 30 trades/day (40 with profit boost ≥$10 locked), 6/hour rolling,
10-min per-mint cooldown, protect-mode trail 10% after kill-switch trip (2344).

**Costs** — Paper mode: **the quote IS the fill** (comment at 2173). No explicit
fee deduction in dry_run: slippage allowance 500 bps only sets
`amount_out_min` on live paths (bsc_swap.py:171,208) and Jupiter quote params
(814–816); PancakeSwap V2 0.25% LP fee is embedded in `getAmountsOut` quotes;
priority-fee cap 2M lamports (1462) is live-only. Measured median round-trip
cost ≈ -1.09% (iter-0) — costs are not the leak. Per-trade tickets: 0.009 BNB /
0.06 SOL (risk section, live config).

**Aux modules** — allocator.py (signal scoring, shadow mode: journals
`allocator_*` fields on entries, no sizing effect); money.py (bankroll, drawdown
brake, adaptive USD kill cap); prepump_watch.py (phone alerts only);
diag_nearmiss.py (DexScreener fallback diagnostics); shadow_dump.py (pure
observation-only dump signal, feeds `shadow_dump_first` on closes);
journal.py (candidates.jsonl instrumentation, STRATEGY_VERSION="1");
bsc_wallet.py / keystore.py (live-swap key plumbing, dormant in dry_run).

## 5. Dollar attribution to dominant leaks (exact code locations)

1. **Instant post-entry LP-pull rugs: -$126.01, 83.4% of USD losses** (23 exits
   ≤ -$3.50). The gap: `enter_bsc` (fomo_trader.py:2022) has **no LP-burn/lock
   screen and no holder-concentration screen** — its only screen is
   `bsc.honeypot_check` (2051 → bsc_swap.py:142), which passes on any fresh pool
   with working LP. The fields that would carry LP evidence are dead:
   `lp_evidence()` (fomo_trader.py:115–118) reads `lp_burn_pct`/`lp_locked` from
   DexScreener/GT payloads, which neither API provides; verified 0/170 entries
   have non-null `lp_burn_pct`, `lp_locked`, `holder_top1_pct`,
   `holder_top5_pct`, or `pool_created_at`. Solana's `rug_check` (1637) cannot
   run on EVM. The bot buys the quote; the dev pulls LP seconds later; the dump
   detector then sells dust.
2. **Dump-detector churn: -$26.51 over 88 partial exits** (avg -$0.30), plus
   -$6.77 over 9 venue-dump partials. The 12%/60s trigger
   (fomo_trader.py:2369–2370, live config `dump_drop_pct: 12`) fires on normal
   memecoin chop and sells the whole position; each exit frees a slot that
   refills from the same rug population. It is also the only mechanism that
   ever exits wipes quickly — desensitizing it is not free.
3. **Structural entry-side reach: 5m window, -$41.68 on 15 trades** (exp -$2.78
   vs -$1.03 for 15m). The "early" window concentrates the worst expectancy.
4. **Dead safety net**: hard stop unreachable (2487–2501 ordering) — cosmetic;
   the trail already exits first. Not a P&L lever.
5. **Costs**: negligible (quote-is-fill paper; ~1.09% round-trip measured).

## 6. Fresh angles beyond iteration 0

- **Veto falsification (§3)**: the two post-veto wipes (PHOE, SMHB) prove
  positive slip was a correlate, not the cause. PHOE is the sharpest
  counterexample: +277% signal, $84k liq, 331 buys, slip -0.6% — still rugged.
  Liquidity-size screening alone does not discriminate either.
- **Entry funnel (journal integrity)**: since 12:24, 455 candidate rows: 95
  `enter` verdicts, 348 `guardrail_skip`, 12 `slip_veto`. Only **7 became
  entries**. The funnel deaths (honeypot skips, dust quotes, commit-cap races)
  are captured in `failed_quotes.jsonl` (94 lifetime: 64 bsc_honeypot — mostly
  "quote unreachable" transport reverts, not real honeypots — 16 dust_quote,
  14 commit_cap), **not** in candidates.jsonl. Journal integrity verdict:
  scan-level coverage is complete (0 rows missing mint/ts_epoch, all
  strategy_version=1, veto events match bot.log 1:1), but the journal alone
  cannot reconstruct the full enter-funnel — the coordinator must join
  candidates.jsonl + failed_quotes.jsonl + bot.log by mint.
- **`pool_created_at` still null** on all 170 entries despite the journal fix
  pass (DexScreener `pairCreatedAt` not resolving) — the pool-age gate (V5
  protocol) cannot use that field; it must use the bot's own first-sighting
  timestamps (`ObservationTracker.repeat` info is journaled).
- **Regime**: wipes cluster 13:00–19:00 ET; 12:00/14:00 ET are the only positive
  hours. Worth a Track-B time-of-day filter test, but n is small per hour.
- **Config drift** (verified on disk, unchanged): TP [[50,50]], trail 25%,
  hard 35%, sell poll 2s, daily cap 30 (40 boosted), kill $60/day, pullback 0,
  allocator shadow, veto on. Matches the loop-log; no silent changes.
- **Sibling lane**: no in-flight test breakage observed in this audit (did not
  run the suite — read-only lane).

## 7. Ranked candidate FIXES (structural, entry-side; no exit-parameter tuning)

**F1 — Direct LP-lock/burn verification on BSC (new pre-entry screen in
`enter_bsc`, before the quote at ~2094).**
Hypothesis: LP-pull rugs have unlocked/unburned LP at entry time; reading the
pair's LP-token contract (totalSupply vs burn-address balance, plus known
locker contracts — Unicrypt/PinkLock/Team Finance) via BSC RPC directly measures
the binding constraint, replacing the dead `lp_evidence()` fields (115–118).
Expected magnitude: wipes = -$126.01; if the screen catches 60% of wipes at a
10% false-positive rate on the 104 non-wipe closes (forfeiting ~+$4 of their
+$52 gross), net ≈ **+$70 lifetime**, expectancy -$1.19 → ≈ -$0.65/trade.
Confirm: backfill LP-lock status for the 23 wiped vs 104 survived mints via
BscScan/BSC RPC — wiped skew unlocked, survivors skew locked/burned. Refute:
survivors are equally unlocked (then lock status doesn't discriminate; kill it).

**F2 — Pool-age / first-sighting persistence gate.**
Hypothesis: LP-pull devs strike within minutes of pool creation + first buy
pressure; requiring first-sighting age ≥ N min (from the journal's own
`ObservationTracker`, since `pool_created_at` is null) with price inside a band
dodges the kill window. Wipe signature supports it: flat price for minutes,
then one tick — a 10–20 min seasoning delay would have skipped the entry, not
just improved the exit. Expected magnitude: if it filters 50% of wipes at 20%
fewer entries, ≈ **+$55–60 lifetime**. Confirm: join candidates.jsonl
first-sighting ts → wipe entry ts; wiped pools skew young vs survived.
Refute: age distributions overlap (then it's just a volume throttle; kill it).

**F3 — Reserve-watch instant exit (first 120s after entry).**
Hypothesis: LP removals hit pair reserves before/with the price-feed tick; the
dump detector (2369) exits on the price tick, which *is* the wipe — selling
dust. Polling `getReserves` and exiting on reserve contraction >X% converts
-100% wipes into -20–40% partials. Expected magnitude: even if only 1/3 of the
23 wipes get a 50%-loss exit instead of -100% (avg wipe -$5.48), ≈ **+$20
lifetime** — smaller than F1/F2 but complementary (it helps when F1/F2 miss).
Confirm: `quote_paths/` tick captures on the 23 wipes show reserve lead time
before the price tick. Refute: reserves vanish in the same tick as price (no
lead time; kill it).

**F4 — Desensitize the dump detector's partial exits on BSC (12%/60s → 25%/60s
or require venue confirmation).**
Hypothesis: the -$26.51 churn over 88 partial exits (avg -$0.30) is normal
memecoin chop, not information. Expected magnitude: saving half the churn ≈
**+$13 lifetime** — but the detector is also the wipe catcher, so Track B must
prove faster wipe exits aren't delayed; net could be negative. Ranked below the
entry-side fixes; gate strictly.

**F5 — Gate the 5m window harder on BSC (or disable it).**
Hypothesis: the 5m "early" window (exp -$2.78/trade, n=15) buys *into* the
kill window rather than ahead of it — early entry is adverse selection here,
not edge. Expected magnitude: removing 15 trades at -$2.78 ≈ **+$41.68
lifetime** if the 15m window doesn't just absorb the same coins later (it
partially would — true saving is smaller). Confirm/refute: walk-forward on the
window split with the V5 frozen protocol; if 15m-window entries of the same
mints also wipe, the window isn't the lever.

Deliberately NOT proposed: any exit-parameter tuning (ladder/TP/trail/hard-stop
variants — showdown verdict stands: nothing passes), rug-guard weakening,
position-size increases, kill-switch/cap loosening (all violate hard
constraints).

## Appendix — files & numbers for the coordinator

- Trades universe: `runs/paper-1h/trades.jsonl` — 343 rows (170 entries, 173 closes).
- Journal: `runs/paper-1h/candidates.jsonl` — 455 rows since 12:24 EDT, all `strategy_version=1`.
- Funnel failures: `runs/paper-1h/failed_quotes.jsonl` — 94 rows.
- Live config: `runs/paper-1h/config.json` (`dry_run=true` verified; note
  `config.json` at repo root is the template — the bot runs with
  `runs/paper-1h/config.json` per run_bot.sh:37).
- Key exact locations: slip veto 2556 (calls 1975 SOL / 2141 BSC); dead drift
  cap 159–173; `enter_bsc` 2022; honeypot screen 2051 → bsc_swap.py:142; dead
  `lp_evidence` 115–118; rug_check 1637; guardrails 1602; kill switch 1472;
  exit ordering 2443/2369/2487/2494/2516; quote-is-fill 2173; allocator shadow
  1526 + allocator.py:186.
- Reconciliation: pre-12:24 subset -$139.30 vs iter-0 -$139.60 (Δ $0.30, two
  closes) — baselines reconcile; wipe share worsened 71.7% → 83.4%.
- Headline for the loop: **the slip veto works mechanically but does not fix
  the binding constraint** — post-veto non-chase wipes (PHOE, SMHB) falsify it
  as a complete fix. The three structural entry-side candidates above (LP-lock
  verify, pool-age gate, reserve-watch) are the falsifiable shots at the
  -$126.01 wipe leak.

## 8. Supplement — completed Cursor agent CLI audit (received ~17:05 EDT)

The retry completed. Its headline numbers reconcile exactly with §§1–3
(stamped -$151.15, PF 0.257, BSC -$147.97; wipe count differs only by
definition: 21 wipes at ≥90%-of-stake = -$117.32 vs my 23 at ≤-$3.50 =
-$126.01 — same leak). Its novel findings, each verified in my own shell:

**S1. The slip veto has a re-admission hole — this is the mechanism behind the
post-veto wipes.** `_slip_veto` (2556) is evaluated **per attempt, not per
token**, against the current scan's GeckoTerminal cached price. Verified from
candidates.jsonl:
- PHOE (0xcf3ece90): vetoed 4× (+24.1%, +6.4%, +2.9%, +2.3%), then **entered**
  17:08:40 UTC at slip -0.58% → wiped -$6.94.
- SMHB (0xffbca0ed): vetoed 2× (+8.1%, +12.8%), then **entered** 17:19:49 UTC
  at slip -7.65% → wiped -$6.94.
- 0xe6ee9fd8: vetoed 1× (+17.5%), entered 17:20:49 UTC (MA, +$0.77).
3 of 6 vetoed tokens were re-admitted; 2 of the 3 re-admissions are the two
post-veto wipes. A **sticky per-token veto** (veto once → block the mint for
the day, same pattern as `dump_cooldown` at 1580/2633) would have turned the
post-veto sample from -$11.85 into +$2.03. This becomes candidate fix **F2b**,
ranked just below F1/F2: hypothesis = once a chase, always a chase; the
negative slip on re-scan is reference-price movement, not a new setup.
Confirm/refute with no code change: join `slip_veto` rows to trades over the
next ≥20 re-admissions (currently 2/3 wipe vs 0/4 never-vetoed).

**S2. The bot is locked out of entries — forward validation is starved.**
Verified from `runs/paper-1h/state.json` + money.py: bankroll $847.76 vs
$1,000 peak = **15.22% drawdown ≥ 15% max** (money.py:25), so the drawdown
brake engaged (~13:48 EDT, after the SMHB wipe). Hysteresis releases only below
10% ($900 bankroll); with **0 open positions** the bankroll is static and the
brake can never release on its own. `guardrails_ok` (1609) now rejects every
signal — the scanner still journals (all `guardrail_skip`), but the post-veto
entry sample is **frozen at n=7**. Separately, the kill switch is $2.66 from
tripping: realized -$51.28 vs cap min($60, 6% × $899.04 day-start) = $53.94.
**Coordinator decision needed:** the loop's fresh-data pipeline (slip-veto
re-validation, V5 early-wave forward protocol) is dead until the brake is
addressed — that is the user's call; loosening it would violate hard
constraints, so I propose nothing here, only the flag.

**S3. Root cause of null `pool_created_at` found.** `journal.pool_created_at()`
(journal.py:48–68) only parses *numeric* fields (`pairCreatedAt` ms etc.);
GeckoTerminal returns an ISO-8601 string, which `_num()` rejects → None on
100% of rows. The docstring even blesses this ("callers journal null").
Fixable instrumentation bug (parse ISO strings), no constraint violated —
required before any pool-age gate (F2) can use that field.

**S4. Possibly inverted PRE-PUMP filter.** fomo_trader.py:1096:
`if p15 < e_min_m15 or p15 <= p5 * e_accel: continue  # not accelerating` —
moves concentrated in the last 5 minutes are rejected as "stalling," which is
backwards for an early-move filter. Intent needs adjudication (may be deliberate
don't-buy-vertical logic); flagged for the Codex-Astra lane.

**S5. Slip ≤ -10% band is wipe-free.** Their cut: 40 trades, +$1.14, **0 wipes**;
the (-10%, 0] band: 18 trades, 4 wipes, -$14.59. Caveats: cutoff chosen
post-hoc, and most of the separation is the same PHOE/SMHB trades F2b catches;
pre-veto the ≤-10% band was only -$0.71 over 16 trades. Candidate fix F3b
(widen veto to slip ≤ -10%), strictly Track-B gated on ≥30 fresh trades/band.

**S6. Journal integrity additions.** (a) `trades.jsonl` mixes EDT and UTC
timestamps across processes (their finding — my UTC-assumed parsing still
matched 126/127 holds with 1 orphan, but the validation lane should normalize
via `deaths.log` timezone labels). (b) `ObservationTracker` repeat/first-sighting
state is in-memory (journal.py:79–126) and resets on every restart — 11
restarts post-veto — so first-sighting ages only cover the current process.
(c) No candidate→outcome join key: "enter" verdict ≠ entered (7 of 95).
(d) SOL entries are **structurally blocked**: 356 "holder concentration
unverifiable" RUG-GUARD SKIP lines in bot.log (of 357) — public-RPC
`getTokenLargestAccounts` fails and `rug_check` (1663–1690) fails closed; 0
SOL entries since 09-24. Infrastructure, not strategy; restoring it needs a
working RPC, not weaker checks.

**S7. Paper understates live costs.** Their cost table (verified against code):
BSC transfer taxes not modeled (`getAmountsOut` ignores them; the honeypot
screen can't see them either); SOL priority fees (cap 2M lamports ≈ 6.7%
round-trip on a 0.06 SOL ticket), ATA rent, and BSC gas are live-only and
absent from paper P&L. Relevant to live-readiness only — paper P&L stands as
measured. Note their flags: 36 closes had a TP rung fire (+$25.63), but 6
"+50%" rungs filled at a loss (trigger reads the DexScreener price, fill uses
the router quote); 16 of 34 trailing exits gapped past 35% below peak —
further confirmation the hard stop is unreachable (§5.4).

**S8. Uncommitted-work note.** `fomo_trader.py` carries a 1,025-line
uncommitted diff; `journal.py`, `money.py`, `allocator.py`, `shadow_dump.py`
are untracked; an uncommitted Track-B study `analysis/candidate_early_veto.py`
("100% scanner-gain veto") exists — its direction agrees with this report's
gain-based slicing (BSC signals ≥100% gain: 84 trades, -$115.84 vs <100%:
37 trades, -$32.13, per their cut). No test breakage observed (they ran 698
green); nothing was fixed or touched by this lane.
