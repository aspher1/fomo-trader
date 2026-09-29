# Empirical Showdown Report — Exit Config: On-Disk vs Described Strategy (+ V5 feasibility)

**Worker:** empirical showdown subagent (session 39bea9a2). **Date:** 2026-09-28 ~13:30 ET.
**Mandate:** determine by honest backtest whether the on-disk exit config or the
"described strategy" exit config is better. Entries FIXED (historical entries as
they happened); only exit logic varies across V0–V4. V5 (early-wave entry)
assessed for feasibility only. **Nothing was changed on the bot**: analysis
only; no config, code, journal, or state file was modified; the bot was not
restarted.

**Artifacts:** `analysis/exit_showdown.py` (harness, new file),
`analysis/exit_showdown_results.json` (per-trade replay rows, new file).

**Headline verdict: NO VARIANT PASSES TRACK B. Nothing ships.**
Provisional ranking on current data: V4 ≈ V0 > V1/V3, V2 ≡ V0 — but every
variant fails the walk-forward retention gate (best retention 49% < 60%
required), IS n=42 < 100 required, and OOS PF sits at 0.17–0.21 for all of
them. There is no demonstrated positive expectancy to promote.

---

## 1. Coverage audit

**Universe:** 121 stamped closes (close lines with `realized_usd != null`,
Lane-Validation's definition) at read time ~13:00 ET 2026-09-28. (Lane-Validation
read 117 at ~12:15 ET; the bot closed 4 more since — the universe grew.)

| Recorded exit-reason cohort | n | path file exists | full entry→exit cover | full % |
|---|---|---|---|---|
| dump-detector | 95 | 65 | 64 | 67.4% |
| venue-dump | 18 | 12 | 12 | 66.7% |
| trailing-stop | 7 | 6 | 6 | 85.7% |
| stale | 1 | 0 | 0 | 0% |
| **TOTAL** | **121** | **83** | **82** | **67.8%** |

"Full cover" = path's first tick ≤ entry_ts + 120s AND last tick ≥ close_ts −
120s (tolerance covers the ~2s poll offset; entry/close prints are journaled
separately). Median tick gap on covered trades is ~2–3s.

**Reconciliation note (answers Astra's count objection):** 83 trades have a
path file but only 82 are fully covered. The single path-exists-but-partial
case is `0xb38c76ba02` (2026-09-27 17:13→17:46 trade; path covers only the
last 57s — capture started late, consistent with a mid-trade bot restart).
Covered-by-date (path-exists): 43 on 9-27 + 40 on 9-28 = 83. Replay universe
(full-cover): 42 IS (closes < 2026-09-28) + 40 OOS (2026-09-28) = 82.
Uncovered: all 14 from 9-24 + 24 from 9-27.

**Selection bias (material, disclosed):** quote-path capture only began
2026-09-27, so the **entire 9-24 regime is absent** from the replay universe
(9-24 was the worst day: PF 0.151, -$29.26 on 14 closes). The covered set
skews recent. Missing-at-random does not hold; absolute P&L and possibly
rankings would shift if 9-24 were recoverable (it is not — no tapes exist).

**Replayable?** Yes for the cohorts that matter: 67–86% full coverage on
dump-detector, venue-dump, and trailing-stop. The stale cohort (n=1) has no
path — stale exits cannot be evaluated from this data (only 1 replay stale
exit fired across all variants anyway).

---

## 2. Verdict table — all variants, Track B

Walk-forward split (same as prior passes): IS = closes with ts < "2026-09-28"
(n=42), OOS = 2026-09-28 closes (n=40). Primary P&L is **gross** of the
replay.py cost model so it reconciles with Lane-Validation's realized_usd
baseline; base-cost and 3x-fee-stress columns apply that model on top.
Retention = OOS_PF / IS_PF. Gate: retention ≥ 60%, ≥100 IS / ≥30 OOS trades.

| Var | Exit config | n (IS/OOS) | Net $ | PF | WR | MaxDD $ | IS PF | OOS PF | Retention | 3x-fee PF | Red flags | Verdict |
|-----|-------------|-----------|-------|------|------|---------|-------|--------|-----------|-----------|-----------|---------|
| V0 | TP [[50,50]], trail 25%, hard 35% (on-disk) | 82 (42/40) | -66.09 | 0.393 | 31.7% | 79.73 | 0.524 | 0.203 | 39% | 0.347 | retention<60% | **FAIL** |
| V1 | TP [[100,50],[200,25]], trail 25%, hard 35% (described TP) | 82 (42/40) | -95.15 | 0.273 | 31.7% | 100.55 | 0.344 | 0.169 | 49% | 0.240 | retention<60% | **FAIL** |
| V2 | TP [[50,50]], trail 30%, hard 35% (described trail) | 82 (42/40) | -66.09 | 0.393 | 31.7% | 79.73 | 0.524 | 0.203 | 39% | 0.347 | retention<60% | **FAIL** |
| V3 | described TP + described trail 30% | 82 (42/40) | -95.15 | 0.273 | 31.7% | 100.55 | 0.344 | 0.169 | 49% | 0.240 | retention<60% | **FAIL** |
| V4 | TP [[50,50]], trail 25%, **hard 20%** (honest reachable hard stop) | 82 (42/40) | -58.81 | 0.422 | 31.7% | 72.45 | 0.583 | 0.206 | 35% | 0.371 | retention<60% | **FAIL** |

Base-cost (1x replay.py costs) nets: V0 -$71.98, V1 -$100.93, V2 -$71.98,
V3 -$100.93, V4 -$64.73. Costed PFs: 0.361 / 0.250 / 0.361 / 0.250 / 0.386.
Costs move every variant by ~$6 total — the ranking is not cost-driven
(consistent with Lane-Validation: the leak is structural, not cost-driven).

**Every variant FAILS.** Beyond retention<60%, the IS-size requirement (≥100)
is unmeetable from current data (max available: 42 covered IS closes) — a
standing data limitation for any exit-mechanic candidate, not just these five.
OOS PF is 0.17–0.21 for ALL variants: there is no demonstrated positive
out-of-sample expectancy to promote (Astra's single strongest objection).

Replay exit-reason mix per variant:
- V0: dump-detector 71, trailing-stop 7, venue-dump 2, force-close@tape-end 1, stale 1
- V1: dump-detector 71, trailing-stop 4, venue-dump 2, force-close 4, stale 1
- V2: dump-detector 71, trailing-stop 6, venue-dump 2, force-close 2, stale 1
- V3: dump-detector 71, trailing-stop 3, venue-dump 2, force-close 5, stale 1
- V4: dump-detector 66, trailing-stop 7, hard-stop 5, venue-dump 2, force-close 1, stale 1

---

## 3. Decompositions

### 3a. V2 ≡ V0 to the cent — the trail-width parameter is dead on this tape

Zero per-trade P&L differences across all 82 trades. Mechanism, verified:
4 of the 7 replay trailing exits had a TP rung fired, so trail was
min(25,12)=12% vs min(30,12)=12% — identical in both variants. The other 3
trailing exits (no rung) were one-tick gap-downs where 25% and 30% trigger on
the same tick at the same price. The 25-vs-30 debate is moot twice over:
post-TP tightening (12%) dominates whenever a rung fired, and the dump
detector (12%/60s) fires first on every violent move. (Astra's correction
adopted: "trail width had no incremental effect **in this replay**" — a
smoother future regime with slow pre-TP reversals could in principle
differentiate them; nothing in this data does.)

### 3b. V1 (described TP ladder) is worse — and exactly why

V0 − V1 = **+$29.06 for V0**, and 100% of it sits on the 20 paths that ever
reached +50%:
- 15 paths reaching +50–100%: V1 loses **$34.40** vs V0 — V0 banks 50% of the
  position at +50%; V1 holds the full ticket into the wipe.
- 5 paths reaching +100%: V1 **beats** V0 by **$5.33** — banking 50% at +100%
  beats banking at +50% when the runner actually gets there.
- The second rung [200,25] **never fires** on current data (0/82 paths reach
  +200%).

Net: the described ladder forfeits the only bank this market pays (+50%) to
chase levels only 6% of paths reach. This is base-rate exploitation, not
cleverness — and it cuts both ways (see §4).

### 3c. V4 (hard stop 20%) — the only positive full-sample signal, unvalidated

+$7.28 over V0, from **exactly 5 trades** where hard-stop 20% replaced
dump-detector exits on slow bleeds (saved $0.31–$3.95 each: 0x960f6d34,
0xd3030f79, 0x9dcf4e61, 0x6161d692, 0xe49bd0c1). **4 of the 5 are IS, 1 is
OOS** — hence the worst retention ratio (35%). This is a 5-trade hypothesis
about slow bleeds, not a validated 20% stop. The failure mode it does not
measure: trades that cross −20% and recover (sacrificed recoveries) — a
hotter regime could supply them. Winner's bias applies: V4 was selected
after inspecting results.

### 3d. Tape censoring (Astra's sharpest point — disclosed, direction assessed)

Tapes were cut at the historical close_ts; variants that would have held
longer are force-closed at the last tick (force-close@tape-end counts —
V0:1, V1:4, V2:2, V3:5, V4:1). V1/V3 hold the full position where V0 banked
half, so the censoring falls hardest on them: if those dumps kept falling
post-close (the memecoin base rate), my numbers **flatter** V1/V3 — which
strengthens the "described ladder is worse" read. If they recovered, the
read weakens. Post-close prices are unknowable from this data; the
proceed-with-caution flag stands.

---

## 4. Mootness analysis — TP levels

On the 82 covered paths (native units; journal entry/exit/peak are native
BNB/SOL prices, paths are USD — converted via the close's native/USD rate):

| Level | Paths ever reaching it |
|---|---|
| +50% (V0 rung) | 20/82 (24%) |
| +100% (V1 rung 0) | 5/82 (6%) |
| +200% (V1 rung 1) | 0/82 (0%) |

The V0-vs-V1 TP question is **answerable** (not moot): 20 paths reach +50%,
and the +50% rung earned $29.06 over 82 trades (+$0.35/trade) vs riding —
that is the measured value of banking early in this regime. The +200% rung
is moot (never fires); the +100% rung fires on 6% of paths. Honest caveat
(Astra): grouping by subsequently-achieved max gain uses hindsight — it
explains *why* +50% won here, not how often those path types recur. A hotter
regime with more +100% runners could flip the V0/V1 ranking; nothing in this
data suggests that regime is near (0/82 reached +200%).

---

## 5. Fidelity & limitations

- **Fidelity:** V0 replay vs bot's recorded realized_usd (n=82): mean abs
  diff **$0.49/trade**, bias **+$0.17/trade** (replay optimistic), Pearson
  **r=0.94**. The state machine replicates the bot well. The +$0.17 bias is
  the bot's paper-fill slippage haircut ("honest accounting: record what the
  fill actually realized, not the phantom feed gain"), which the replay does
  not model — applied ~equally across variants, so rankings are preserved
  while absolute P&L is ~$0.17/trade optimistic.
- **Unit fix (caught mid-analysis):** journal entry/exit/peak are NATIVE
  prices; quote paths are USD. First run mixed them (absurd +$329k nets);
  fixed by converting ticks to native via each close's native/USD rate.
  Gains/ratios are unit-free so a constant FX bias cancels.
- **Venue-m5 approximation:** the bot uses DexScreener's independent venue
  tape; the replay uses the path's own 5-min return, checked every 30s,
  skipped when no tick exists 270–330s back. Applied identically across
  variants, but (Astra) a common approximation does not guarantee
  cancellation — TP timing changes exposure and trail state. Replay
  venue-dump exits: 2/82 vs 12 recorded in the covered set (most recorded
  venue-dumps replay as dump-detector at the same wipe tick — P&L-identical,
  label differs).
- **Not modeled:** kill-switch protect mode (tightens trail to 10% on
  kill-switch days), cross-trade portfolio effects, entries (fixed by design).
- **Cost model (exact, vendored from analysis/replay.py as read 2026-09-28):**
  0.0025 swap fee/leg + 0.0015 slippage/leg (×3 under stress) on
  (stake + stake×R); fixed 2×0.00002 BNB/leg (BSC) or 2×2M lamports/leg
  (Solana); USD via the close's native/USD rate (115 fallback for early SOL).

---

## 6. Astra's skeptical review (unedited in substance)

*Run 2026-09-28 ~13:15 ET via `/usr/bin/codex exec --model gpt-6-astra
-s read-only`, prompt via stdin. Full text:*

> **"Nothing ships" survives. The directional recommendations need weaker wording.**
> V0 is less bad than V1 on the replayed paths; V4 loses slightly less than V0.
> Neither establishes an exit policy worth promoting.
>
> ### 1. Kill verdict per directional read
> **(a) KEEP the +50% TP rung — kill as a validated recommendation; retain as a
> sample-specific result.** The $29.06 advantage is real within this replay, but
> "20 affected paths" is not enough information to establish reliability. We need
> the paired differences, their concentration, and dependence across tokens and
> days. Twenty trades exposed to the same market episode are not twenty
> independent experiments. The decomposition explains the result; it does not
> independently validate it. Grouping paths by the maximum return they
> subsequently achieved uses hindsight. It shows *why* +50% won here, not how
> often those path types will occur next. Also, "nothing reaches +100%" is false:
> five paths did, and V1 won on that subgroup. A hotter regime could change the
> subgroup mix enough to reverse the ranking. The +200% rung is untested by these
> data. Defensible wording: **"The +50% rung outperformed the described ladder on
> this covered sample. There is insufficient evidence to change it."** Keeping the
> status quo has a lower evidentiary burden than declaring it superior.
>
> **(b) The trail parameter is dead — survives only with "on these 82 paths"
> attached.** Zero paired differences are strong evidence of observed equivalence.
> This is not a statistical-significance problem: the two settings produced
> identical outcomes. But the mechanism matters. Post-TP tightening removes the
> difference on some paths; large tick gaps conceal it on others. Neither proves
> that 25% versus 30% cannot matter on future, smoother pre-TP reversals.
> Defensible wording: **"Trail width had no incremental effect in this replay."**
> Kill any broader claim that the parameter is useless.
>
> **(c) V4 is a positive signal — kill the word "positive" unless it explicitly
> means relative loss reduction.** V4 still loses $58.81, with OOS PF 0.206. Its
> $7.28 improvement comes from five trades, only one OOS. That is a hypothesis
> about slow bleeds, not validation of a 20% stop. A different regime could supply
> the missing counterexamples: trades that cross −20%, recover, and would have
> survived the baseline logic. The evidence must measure those sacrificed
> recoveries as well as avoided losses. V4's worst retention ratio is not, by
> itself, evidence that it is worse OOS: its OOS PF is slightly higher than V0's.
> The ratio deteriorates partly because its IS result improved more. **The gate
> fails, but the ratio does not establish comparative harm.**
>
> ### 2. Threats that could overturn the ranking
> - **Coverage is materially selective.** An entirely missing day and partial
> coverage of another make missing-at-random reasoning unjustified. The worst
> day's absence could distort absolute performance and relative ranking. Its poor
> recorded PF does **not** tell us which alternative exits would win there.
> - **One OOS day supplies little regime evidence.** Forty trades do not substitute
> for independent market episodes. The 11 wipes also deserve a decomposition:
> common unavoidable losses can dominate PF while contributing little information
> about differences between configs.
> - **Multiple comparisons remain unresolved.** These are not five independent
> experiments: V0/V2 and V1/V3 are identical here. Nevertheless, selecting V4
> after inspecting the results creates winner's bias. Neither V4's gain nor V1's
> deficit can be classified as "noise" or "significant" from aggregate totals alone.
> Any earlier parameter search also belongs in the selection history.
> - **The coverage counts do not reconcile.** *(Resolved in §1 above: 83
> path-exists vs 82 full-cover; the gap is the single partial-path trade
> 0xb38c76ba02.)*
> - **Counterfactual tape length is crucial.** *(Addressed in §3d.)*
> - **Common approximation does not guarantee cancellation.** *(Addressed in §5.)*
>
> ### 3. Single strongest objection to shipping
> **There is no demonstrated positive OOS expectancy: every candidate has OOS PF
> around 0.17–0.21.** That is more fundamental than missing the retention gate.
> Selecting the smallest observed loss does not establish a viable policy. More
> trades could validate relative superiority while confirming that every option
> loses money. This supports withholding promotion; it does not preclude continued
> paper testing.
>
> ### 4. Evidence that would change its mind
> 1. An auditable replay universe: reconcile counts, report exclusions, capture
> ≥95% of eligible entries with tapes extending through every candidate exit;
> measure actual venue signals, executable fills, fees, slippage.
> 2. A frozen prospective comparison: meet ≥100 IS / ≥30 OOS, but target **≥200
> fresh OOS trades across 20+ trading days** covering rug-heavy, quiet, and
> hot/trending conditions.
> 3. Enough informative events: ≥100 paths where TP choices differ, ≥50 where stop
> choices differ, including recoveries after −20% crossings; derive final sample
> requirements from paired-effect variance and a prespecified economically
> meaningful improvement.
> 4. Uncertainty respecting dependence/selection: paired comparisons with
> day/token clustering, simultaneous intervals for prespecified contrasts,
> sensitivity to days, tokens, costs, venue-trigger errors.
> 5. Both relative AND absolute success: robust improvement over V0 **and**
> positive net OOS expectancy after costs, with uncertainty supporting
> profitability, while passing the declared gate.

---

## 7. Provisional winner: CANNOT BE DETERMINED — do not ship

No variant passes Track B; the winner must win out-of-sample and none does
(OOS PF 0.17–0.21 across the board). Ranked directional reads, in Astra's
weakened wording:

1. **The +50% rung outperformed the described ladder on this covered sample.
   There is insufficient evidence to change it.** (V0/V2 > V1/V3 by $29.06,
   fully decomposed; the +200% rung never fires.)
2. **Trail width had no incremental effect in this replay.** (V2 ≡ V0 to the
   cent; the 25-vs-30 debate needs no resolution today.)
3. **V4 lost the least** (−$58.81 vs −$66.09) via a 5-trade slow-bleed
   hypothesis that fails retention and carries winner's bias. Not validated;
   not shippable. If the 4h loop wants a follow-up, it is a *frozen
   prospective* test of hard-stop 20% with pre-registered sacrificed-recovery
   measurement — not a config change.

Config-drift note for the coordinator: the on-disk config already runs the
+50% rung / 25% trail / 35% hard stop that this showdown finds least-bad.
No drift correction is indicated by this data (the "described" values lose).

---

## 8. V5 — early-wave entry (feasibility verdict: NEEDS FRESH DATA)

### 8a. The exact V5 rule (frozen definition, from the hunter's real fields)

A scanner candidate is **V5-eligible** iff ALL of:

1. **First sighting:** `repeat is null` in candidates.jsonl — the
   ObservationTracker (`journal.py`) returns None on a pool's first
   observation and `{"first_ts", "second_price_usd", "sightings"}` on repeats,
   keyed by (chain, mint). Enter on the first print, not after N repeat
   sightings.
2. **Modest gain band:** `15m_gain_pct` in **[path threshold, 60)** —
   threshold = the hunter's own minimum for that path (regular
   `min_m15_gain_pct` = 20; early/DexScreener `min_m15_gain_pct` = 15).
   I.e., enter when the gain FIRST crosses a modest threshold rather than
   after a ≥100% print. The 60% upper cap keeps it an *early*-wave rule;
   ≥60% first-sightings stay baseline.
3. **Everything else unchanged (non-negotiable):** rug guard + honeypot
   screen, liquidity/volume/buys minimums, `veto_positive_slip=true`,
   all risk caps, kill switch, sizing. A V5-eligible candidate the rug guard
   rejects is a reject, journaled as such.

One clean definition, no tuning knobs beyond the frozen constants above.

### 8b. Why it cannot be backtested (do not interpolate)

- `candidates.jsonl` (the every-observation stream, including scanner
  sightings that never became entries) starts **2026-09-28 16:25:16 UTC
  (12:25 ET)** — 40 observations in ~25 min at read time. **All 121 stamped
  closes predate it.** There is no historical record of what the hunter saw
  and skipped.
- GeckoTerminal/DexScreener **cannot** reconstruct first-sighting times:
  first-sighting is a property of *our hunter's* observation history, not the
  venue. `poolCreatedAt` ≠ first-sighting (a pool can exist for hours before
  trending onto a scanned page; the early/DexScreener path has different
  timing). No GT quota was burned on this — the reconstruction is impossible
  in principle, not just expensive.
- Even with first-sighting times for *traded* pools, we would only have the
  selected sample (pools that became entries) — never the counterfactual
  stream of skipped candidates an entry-rule change needs. Any "backtest"
  would be selection-biased by construction.

**Verdict: V5 = NEEDS FRESH DATA.** That is a complete, honest deliverable.

### 8c. Forward-validation protocol (for the 4h loop)

1. **Freeze** the §8a rule with a date stamp. No peeking or tuning on forward
   data until the gate sample is complete.
2. **Instrumentation (additive, behavior-neutral):** the hunter already
   journals every observation to candidates.jsonl with `guardrail_verdict`
   and `repeat`. Add `v5_eligible` (bool) per observation. For V5-eligible
   observations the baseline hunter *skips* (e.g., would have entered on a
   later repeat sighting), open **shadow paper entries**: record commit price
   and stake, then score the position with the CURRENT exit state machine
   (V0) on that pool's quote path — the same replay harness as this showdown
   (`analysis/exit_showdown.py`). Baseline entries that are also V5-eligible
   give free paired data.
3. **Rug-screen accounting (per mandate):** track rejects/observations
   separately for the V5-eligible cohort vs baseline via
   `guardrail_verdict` + a new `v5_guardrail_verdict`. Historical context:
   348 `RUG-GUARD SKIP` lines in the current bot.log window vs 164 lifetime
   journaled entries — windows mismatch, so no clean historical rate exists;
   the forward stream will produce the first clean one. (For V0–V4 the rate
   is identical by construction — entries were fixed.)
4. **Gate (Track B, all forward/OOS):** ≥30 V5-eligible shadow entries, then:
   PF aspiration > 1.2, OOS retention ≥60% vs its own IS, 3x-fee stress,
   overfitting red flags, plus a **paired day-matched comparison** against
   the baseline entry cohort over the same forward window. Verdict options:
   PASS / FAIL / NOT_VERIFIABLE (still <30).
5. **Pre-registered expectations — say plainly:** entering earlier means
   weaker confirmation → expect more false positives and **higher rug
   exposure**; the wipe rate per cohort must be reported explicitly. The deep
   pass's inverse test (vetoing signal_gain ≥100% entries) FAILED at ~50.5%
   OOS retention — that failure predicts nothing about V5 either way; V5 is
   tested on its own merits.
6. **Caveats:** the ObservationTracker is in-memory per bot process — restarts
   reset first-sighting state (a pre-restart pool looks "first" after). The
   protocol should persist the tracker or accept/quantify the noise.
   Timeline: at ~30–40 entries/day, the ≥30 minimum needs 2–4 days of
   forward data; Astra's bar for *promotion* (not just gating) is far higher
   — ≥200 fresh OOS trades over 20+ days across regimes.
7. **V5 does NOT ship on user order.** Unlike the slip veto (which had a
   validated PF 0.254→0.796 behind it when ordered), V5 has no passing
   validation. It runs shadow-only until a PASS verdict.

---

## 9. Poll interval (2s vs 5s) — ops recommendation, NOT backtested

Not backtestable from trade records (per mandate — no pretense otherwise).
**Recommendation: keep on-disk 2s.**

- For 2s: the dominant exits are violent dumps where earlier detection weakly
  dominates — on a −50%/minute slide, 3s earlier detection saves ~2.5% of
  position value; TP rungs fill closer to trigger. Only 2 `BLIND` (no-price)
  warnings in the entire current bot.log: the 2s manage poll is not causing
  quote blindness at scale.
- For 5s: less quote load per position. But the 429/quote-error lines in the
  log trace to Jupiter API errors (mostly an older run's config), not to
  manage-poll overload — no evidence the 2s cadence is the load problem.
  (The AGENTS.md GeckoTerminal 30-req/min lesson concerns hunter *scans*, a
  separate path from the 2s manage polls.)
- Changing to 5s would loosen every stop by ~3s of slide with no demonstrated
  load benefit. **Revisit only if** blind-quote episodes or 429 clusters can
  be attributed to manage polling.

---

## 10. Reproducibility

- Harness: `analysis/exit_showdown.py` (run: `python3 analysis/exit_showdown.py`);
  per-trade rows: `analysis/exit_showdown_results.json`.
- State machine mirrored from `fomo_trader.py::_manage_once` as read
  2026-09-28 (TP-at-market → venue → dump 12%/60s → trail → hard → stale;
  trail→12% after any rung, from the next tick).
- IS/OOS split: close-ts string < "2026-09-28" (same as Lane-Validation §3.6).
- Bot state untouched: no config/code/journal/state/log edits, no restarts,
  no key material touched. Sibling lane files not touched (one new harness
  file + one new results file + this report only).

*End of report.*
