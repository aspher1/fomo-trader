# Iteration 1 — Structural diagnosis (lane-codex-astra)

**Analyst note:** Astra (gpt-6-astra) could not run this iteration — the Codex CLI
usage quota on the ChatGPT login is exhausted (both `gpt-6-sol` and `gpt-6-astra`
return "You've hit your usage limit"; quota resets 7pm ET per user confirmation).
Per the lane task's fallback, this diagnosis was performed directly by the lane
in-shell against the live journals. It follows Astra's mandate: fresh-angled
regime characterization, edge break-point location, and ranked structural
hypotheses with VM-feasible fields and kill criteria. No files, config, or bot
behavior were changed for this analysis.

**Data snapshot (2026-09-28 ~16:30 EDT / 20:30 UTC):** 343 journal lines →
164 FIFO (chain, mint) pairs; `candidates.jsonl` 455 lines / ~3.75h of
every-observation journaling (started 16:25 UTC). Slip veto
(`hunter.entry.veto_positive_slip=true`) shipped 16:24 UTC. Timestamps below
are UTC unless noted. Cost model = lane-3 convention (base 0.15%/leg slippage,
0.004 SOL / 0.00004 BNB fixed round-trip).

---

## 1. Headline verdict

The strategy class — reactive 15m-gain spike chasing on GeckoTerminal — shows
**no edge at any decomposition tried this iteration**. The binding constraint
is entry-side and two-headed: (a) 29.9% of entries are dead-on-arrival
(peak < +10%), and (b) the LP-pull wipe cohort (≈72% of lifetime losses)
persists even on non-chase entries (2 of 8 post-veto closes are wipes).
Ex-wipe expectancy is negative in every regime slice. No structural path to
edge is validated; the three live hypotheses (pool-age screen, persistence
confirmation, V5 early-entry) all require forward data plus instrumentation
that does not exist yet.

## 2. Regime characterization

### 2a. Pre/post slip-veto regime (cutoff 2026-09-28 16:24 UTC)

| Regime | Pairs | Wipe rate | Raw P&L | Positive-slip entries | Unknown-slip entries |
|---|---|---:|---:|---:|---:|
| Pre-veto | 156 | 17.3% (27) | −$136.12 | 45/95 known (47%) | 61/156 (39%) |
| Post-veto | 8 | 25.0% (2) | −$11.85 | 0/8 (veto firing) | 0/8 |

- The veto is **mechanically working**: zero positive-slip entries since
  16:24 UTC, and 12 `slip_veto` journal events confirm it is firing on
  would-be entries (with `would_be_entry_native/usd` recorded).
- **No efficacy verdict is possible**: n=8 is far below the ≥30-close bar.
  The 25% post-veto wipe rate (2/8) is statistically meaningless, but it
  establishes that **wipes do not require chase entries** — both post-veto
  wipes entered with negative/zero slip.
- The fails-open hole (unknown slip) was 39% of pre-veto entries; post-veto
  it is 0/8 so far — monitor this fraction; if it climbs back above ~40%,
  the veto is being circumvented by unenriched entries.

### 2b. Chain asymmetry

- Lifetime: SOL 49 pairs / BSC 115 pairs (chain=None inferred as SOL on
  pump mints for the oldest 46 closes). Both chains negative in every slice
  (lane-3: SOL costed −$76.10, BSC −$144.45; OOS window here is 100% BSC).
- Recent flow is entirely BSC; there is no "good chain" to retreat to.

### 2c. Time-of-day regimes (UTC hour of entry, raw USD)

No hour with ≥20 trades has positive expectancy. Hour 14 UTC (10am EDT):
n=10, +$11.21 (+$1.12/trade) — small-n noise, not a regime. Hours 09 and 17
UTC are the worst (−$2.47/−$2.44 per trade, n=13/12). **Time filter ruled out.**

### 2d. Chase-entry redefinition (retrospective, enriched subset)

- Pre-veto, 47% of slip-known entries were positive-slip (chase). The
  retrospective veto (G2, Track B): OOS PF 0.451 vs baseline 0.183
  (+0.268 gain), OOS WR 42% vs 31% — directionally supportive of the shipped
  veto, but it **fails Track B gates** (retained IS 86 < 100; 3x-fee PF 0.424
  < 1; expectancy still −$0.46/trade). Verdict: harm-reducing, not
  edge-creating. The veto was correctly shipped on user order as risk
  reduction, not as a validated edge.

## 3. Where the edge assumption breaks

The strategy assumes a 15m-gain spike signals continuation that outruns
costs. The break points, on 164 pairs:

| Peak reached | n | share |
|---|---:|---:|
| ≥ +10% | 115 | 70.1% |
| ≥ +25% | 86 | 52.4% |
| ≥ +50% | 37 | 22.6% |
| ≥ +100% | 13 | 7.9% |
| ≥ +200% | 0 | 0% |

- **Dead-on-arrival (peak < +10%): 49/164 (29.9%).** Nearly a third of
  entries never get going — pure entry-side failure.
- Loser decomposition (113 losers): immediate-reversal 44, mid-range fade
  (peak +10–50%) 54, gave-back-gains (peak ≥+50% then negative) only 15.
  **Most losses are failures to launch, not surrendered gains.**
- The strategy is lottery-like: 22 winners with peak ≥+50% (13% of trades)
  produce $69.59 of $88.58 gross wins (79%). The TP ladder's +100%/+200%
  rungs are nearly unreachable (13 and 0 hits) — confirms the showdown's
  finding that the described ladder forfeits banked gains for levels that
  don't occur.
- **Dump-detector churn verdict:** 107 detector exits; 68% had peaked
  ≥+10% before fading, 31% exited still net-positive. The detector is mostly
  exiting dead/fading momentum, not cutting winners' legs — but the winners
  it *does* touch are the lottery tickets the strategy needs. Tightening
  exits kills the tail; loosening feeds the wipes. **Exit tuning is not a
  lever — ruled out (again).**
- Entry latency (fast vs slow half): −$0.97 vs −$1.12/trade — weak gradient,
  not structural. Buy-share terciles: −$0.93 / −$1.22 / −$1.00 — no gradient;
  imbalance screens stay rejected.

## 4. Ranked structural hypotheses

### H1. Pool-age minimum screen (anti-LP-pull) — FORWARD-ONLY, not testable today
- **Mechanism:** rug factories create pools minutes before the manufactured
  pump; a minimum pool age at entry would screen the most disposable rugs.
- **VM-feasible fields:** `pool_created_at` is journaled on every
  candidates.jsonl observation — but **0/170 lifetime entries** carry it, so
  no lifetime test is possible.
- **Falsifiable prediction:** on ≥30 OOS trades, entries on pools < Xh old
  show ≥2× the wipe rate of older pools with non-overlapping CIs.
- **Kill criteria:** no wipe-rate separation on ≥30 OOS trades, or the
  screen vetoes >50% of winners.
- **Needs:** log pool age on entries (journal.py already captures it on
  candidates) + forward observation window. Earliest testable: ~1–2 weeks
  of journaled entries at current pace.

### H2. Persistence confirmation (two consecutive sightings) — BLOCKED on instrumentation
- Lane-3's hypothesis, now testable-in-principle via candidates.jsonl.
- **Blocked by:** (a) only 3.75h of journaling; (b) the ObservationTracker
  is in-memory and **resets on every bot restart — 3 restarts in the last
  3.75h** (18:40, 18:45, 19:00 UTC), corrupting first-sighting state;
  (c) no shadow-entry instrumentation exists.
- **Needs:** persist the tracker across restarts (or accept/quantify noise)
  + shadow entries for would-be confirmed entries. Earliest honest test:
  2–4 weeks of clean journaling (Astra's promotion bar: ≥200 OOS trades).

### H3. Signal-gain cap screen — TESTED THIS ITERATION: FAIL
- G1a (veto gain ≥60): IS 27/110 kept, PF 0.988 → OOS 10/54 kept, PF 0.479.
  Retention 48.5% < 60%; IS<100, OOS<30, fails 3x-fee. The IS
  near-breakeven is **non-participation, not edge** (vetoes 75% of trades).
- G1b (veto gain ≥100, control): retention 32.7%, decay 67.3% — confirms
  the prior round's rejection.
- **Killed as a ship candidate.** Descriptive fact retained: gain ≥100%
  entries run ~16% WR — a risk marker, not a rule.

### H4. Chase-slip veto — TESTED: FAIL gates, supportive direction, already shipped
- See §2d. Harm reduction validated directionally; not edge. Forward
  validation pending (needs ≥30 post-veto closes; have 8).

### H5. V5 early-entry — PROTOCOL EXISTS, readiness assessed
- Frozen rule: first-sighting (`repeat is null`) + 15m-gain [threshold, 60%),
  all guardrails unchanged.
- Current journal: **14 strict-V5-eligible in 3.75h (≈3.7/h)**; 3 became
  baseline entries → ~2.9 shadow-entry equivalents/h.
- **68/82 raw first-sighting modest-gain observations were rug-guard
  rejected** — the eligible stream is thin because the guard eats ~83% of
  early sightings. V5's prospective sample will accrue slowly.
- **Earliest gate trigger: ~8–10h of clean journaling → ~00:30–02:00 UTC
  2026-09-29 (20:30–22:00 EDT 9-28), IF** (a) the `v5_eligible` +
  shadow-entry instrumentation ships, and (b) the ObservationTracker is
  persisted across restarts. **Both are currently missing; without them the
  protocol cannot start.** The restart noise (§H2) is the binding blocker.

## 5. Slip-veto forward-validation decision rule (for future iterations)

- **Sample bar:** ≥30 post-veto closes (≈14h at current ~2.1 closes/h →
  earliest ~10:30 UTC / 06:30 EDT 2026-09-29).
- **"Veto working":** post-veto wipe rate < 10% AND expectancy/trade better
  than pre-veto baseline (−$1.38/trade costed, lane-3) on ≥30 closes.
- **"Inconclusive":** <30 closes (current state: 8).
- **"Veto circumvented":** unknown-slip entry fraction climbs back above
  ~40%, or wipe rate unchanged on ≥30 closes.
- **Watch metric:** post-veto entries are 8/8 slip-known; any drift toward
  unknown-slip entries erodes the veto's coverage.

## 6. What the new journaling makes testable, and when

| Question | Needs | Earliest |
|---|---|---|
| V5 forward gate (≥30 shadow entries) | `v5_eligible` + shadow entries + tracker persistence | ~00:30–02:00 UTC 9-29 IF instrumented now |
| Slip-veto efficacy | ≥30 post-veto closes (no code change) | ~10:30 UTC 9-29 |
| Pool-age screen | pool age on entries + forward window | 1–2 weeks |
| Persistence confirmation | tracker persistence + shadow entries | 2–4 weeks |

The journaling infrastructure (candidates.jsonl, slip_veto events with
would-be prices) is the most valuable thing shipped this iteration cycle —
it converts untestable hypotheses into forward-testable ones. The missing
pieces are all instrumentation, not ideas.
