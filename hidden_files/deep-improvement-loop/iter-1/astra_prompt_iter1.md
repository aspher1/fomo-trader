# Astra structural diagnosis — FOMO Trader deep-improvement loop, iteration 1

You are the independent structural analyst for iteration 1 of the FOMO Trader deep-improvement loop.
You run with a READ-ONLY sandbox. Do not attempt to write or modify any file; report everything in your response text.

## Background you already know (from prior iterations)

- FOMO Trader is a paper-only (dry_run=true) memecoin momentum bot on SOL + BSC, scanning ~450 GeckoTerminal pools every ~30s for 100%+ 15m gain spikes, buying on FOMO signals, exiting on TP ladder / trailing stop / dump detector / hard stop. Lifetime expectancy is deeply negative.
- Iteration 0 / research pass established the binding constraint is STRUCTURAL, not parametric:
  - BSC one-tick LP-pull wipes are ~72% of lifetime losses; ex-wipe edge is still negative (PF ~0.254 at zero cost).
  - All exit-config variants failed Track B walk-forward (best OOS retention 49%, gate is 60%; no variant shows positive OOS expectancy).
  - Chase entries (positive signal-to-commit slip) have ~38% wipe rate.
  - Strategy-version drift: the on-disk config (TP 50%@+50%, trail 25%, hard 35%, poll 2s, daily cap 30) differs from the described one; trades.jsonl mixes regimes.
- Shipped on the user's explicit order ~12:24 EDT today (16:24 UTC): `hunter.entry.veto_positive_slip=true` on both chains (chase entries with slip>0 vetoed + journaled; unknown slip fails open).
- NEW: `journal.py` logs every scanner observation to `runs/paper-1h/candidates.jsonl` (strategy_version 1) — started 2026-09-28 16:25 UTC (~12:25 EDT). As of now ~3.7h of journaling, ~451 observations.
- A frozen V5 early-entry forward-validation protocol exists (details in `hidden_files/deep-improvement-loop/strategy-showdown-2026-09-28.md`) — it CANNOT be backtested (no pre-journal first-sighting data); it needs ≥30 OOS entries under the frozen rule.
- Hard constraints (never violated by any recommendation): stay paper-only, dry_run=true intact; never weaken the rug guard, increase position size, or loosen kill switch / daily-loss caps / risk caps; conservative changes only.

## Files you should read first (all under /home/hatch/workspace/fomo-trader/)

1. `hidden_files/research-pass-2026-09-28/lane3_astra_structural_diagnosis.md` — the full lifetime structural diagnosis (your own prior output lineage; 160 FIFO pairs, exit-family attribution, regime splits, rejected screens).
2. `hidden_files/research-pass-2026-09-28/lane-codex-astra-report.md` — the Codex/Astra lane report from the research pass.
3. `hidden_files/deep-improvement-loop/strategy-showdown-2026-09-28.md` — exit-variant showdown verdict (ship-nothing) + V5 frozen protocol.
4. `hidden_files/deep-improvement-loop/followup-fix-2026-09-28.md` — the 12:24 EDT fix pass (slip veto, journaling).
5. `hidden_files/deep-improvement-loop/loop-log.md` — brief loop history.

## Data (read directly; do your own analysis, do not trust prior numbers without spot-checking)

- `runs/paper-1h/trades.jsonl` — full lifetime trade journal (343 lines now; entry + close events; timestamps are UTC; bot restarted 16:24 UTC today). Pair entries/closes by (chain, mint) FIFO.
- `runs/paper-1h/candidates.jsonl` — every scanner observation since 16:25 UTC today (451 lines). Keys include: ts, ts_epoch, event, strategy_version, name, mint, pool, chain, price_usd, liquidity_usd, m15_volume_usd, m15_gain_pct, m5_gain_pct, m15_buys, m15_sells, buy_sell_ratio, mcap_usd, pool_created_at, source, window, early, guardrail_verdict, repeat.

## Your task: fresh-angled structural diagnosis

Prioritize angles NOT yet exhausted. Specifically:

### A. Market-regime characterization in the lifetime trades
1. **Pre/post slip-veto regime**: the veto shipped 16:24 UTC today. Only ~8 closes exist post-veto so far — characterize what CAN be said (entry counts, veto journal counts if visible, wipe rate direction) and what CANNOT (sample too thin for a verdict; state the trades-needed threshold explicitly).
2. **SOL vs BSC asymmetry**: BSC dominates recent flow; SOL's older cohort had its own failure mode (trailing exits, rapid failure). Is there any regime where the strategy is merely *less bad* vs structurally broken? Time-of-day regimes (UTC hour buckets) on entry: any hour with non-negative expectancy on ≥20 trades?
3. **Chase-entry redefinition**: positive slip is now vetoed. What does the remaining (negative/unknown-slip) entry cohort look like — is the wipe rate still elevated vs the vetoed cohort? What fraction of entries had positive slip pre-veto, and what would a retrospective veto have saved (accounting decomposition only, not a claim)?

### B. Where exactly the edge assumption breaks
The strategy assumes: a 15m-gain spike on GeckoTerminal signals continuation that outruns costs. Locate the precise break point with numbers:
- At what point after the signal does the price path typically fail (use `runs/paper-1h/quote_paths/` tapes where available; disclose selection bias — tapes start 9-27)?
- What fraction of entries ever reach +25% / +50% / +100% from entry? What fraction of losses are "dead on arrival" (peak < +10%)?
- Decompose the non-wipe loss into: (i) immediate reversal (dead-on-arrival), (ii) gave-back-gains (peak ≥ +50% then exited negative), (iii) slow bleed. Which dominates, and what does each imply about entry vs management?

### C. Structural hypotheses — mechanisms, not parameter tweaks
Propose and rank structural hypotheses, each with: the mechanism, the exact data field(s) on THIS VM that could implement it, a falsifiable prediction, and what evidence would kill it. Consider at minimum:
1. **Anti-LP-pull screens feasible from VM data**: `pool_created_at` (pool age), `mcap_usd`, `liquidity_usd`, `buy_sell_ratio`, `m15_buys`/`m15_sells` at entry. Is there a pool-age or liquidity-structure screen with a plausible rug-factory mechanism? Quantify the retrospective trade-off on lifetime data (how many wipes caught vs how many winners lost) — as a descriptive decomposition, clearly labeled.
2. **Chase-entry redefinition**: beyond slip, is there a "stale signal" construct (e.g. m5_gain already decelerating at entry, or entry price far above the 15m window's volume-weighted level)? What would the false-negative cost be?
3. **Dump-detector churn**: the detector (8% in 30s) exits many positions within ~1 minute, often at peaks < +10%. Is it cutting winners' legs, or is it correctly identifying dead momentum? Use the tapes: on positions the detector exited, what happened in the next 60–300s (did they recover, or keep bleeding)? If the data can't answer, say so.
4. **Hard-stop reachability**: on the wipe tapes, is there ANY executable exit between entry and the wipe tick (e.g. would a 20% hard stop have fired first)? The showdown's V4 (20% hard stop) failed retention at 35% — reconcile with the tape evidence.
5. **Persistence confirmation**: lane-3 proposed requiring two consecutive scanner appearances before entry; it was untestable from the old journal. With the new candidates.jsonl journaling EVERY observation, when (date/time estimate at current journaling rate) will there be enough data to test it, and exactly what fields would the test need?

### D. Slip-veto forward validation — what to watch
Specify the exact decision rule for a future iteration: how many post-veto closes, what wipe-rate comparison, what statistical bar would constitute "the veto is working" vs "inconclusive" vs "the veto is being circumvented" (e.g. unknown-slip fails open — what fraction of entries are unknown-slip?).

## Output format

Your full response IS the deliverable (it will be saved verbatim as the structural diagnosis). Structure it as:
1. Headline verdict (one paragraph: is there any structural path to edge, or is the strategy class dead?)
2. Regime characterization (with tables and exact numbers; always state n)
3. Edge break-point analysis (with numbers)
4. Ranked structural hypotheses (mechanism, VM-feasible fields, falsifiable prediction, kill criteria)
5. Slip-veto forward-validation decision rule for future iterations
6. What the new journaling makes testable and when (with dates at current rates)

Be skeptical of your own findings: flag small-n, selection bias, strategy-version drift, and timestamp discontinuities wherever they apply. Do not propose anything that violates the hard constraints. Do not recommend shipping anything — recommendation is the coordinator's job; your job is diagnosis and falsifiable hypotheses.
