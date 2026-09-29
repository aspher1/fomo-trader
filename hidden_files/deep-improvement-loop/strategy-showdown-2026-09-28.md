# Strategy showdown — coordinator verdict (2026-09-28 ~12:48–12:55 EDT)

User question: which is "the best strategy" — the on-disk exit config or the described one?
Empirical answer: **neither proves itself. Nothing ships; on-disk config stays.**

## Verdict table (82 taped trades; walk-forward IS n=42 through 9-27 / OOS n=40 on 9-28)

| Variant | All net / PF | IS PF | OOS net / PF | Retention | 3x-fee PF | Verdict |
|---|---|---|---|---|---|---|
| V0 on-disk (TP 50%@+50%, trail 25%, hard 35%) | -66.09 / 0.393 | 0.524 | -35.31 / 0.203 | 39% | 0.347 | FAIL |
| V1 described TP (50%@+100%, 25%@+200%) | -95.15 / 0.273 | 0.344 | -43.96 / 0.169 | 49% | 0.240 | FAIL |
| V2 described trail 30% | ≡ V0 to the cent | ≡ V0 | ≡ V0 | 39% | 0.347 | FAIL |
| V3 described TP + trail 30% | ≡ V1 to the cent | ≡ V1 | ≡ V1 | 49% | 0.240 | FAIL |
| V4 reachable hard stop 20% | -58.81 / 0.422 | 0.583 | -34.57 / 0.206 | 35% | 0.371 | FAIL |

Gate: OOS retention ≥60%. Best retention is 49% (V1/V3). **No variant shows positive OOS expectancy (OOS PF 0.17–0.21 across the board).**

## Why each variant fails — the honest decompositions

- **V2 ≡ V0 exactly (zero per-trade diffs): the 25-vs-30 trail width is a dead parameter.** Post-TP tightening (12%) or one-tick gaps dominate every trailing exit, so the width never matters. The "described 30%" is moot, not better or worse.
- **V1 loses $29.06 to V0**, all concentrated on the 20 paths that reached +50%: the described ladder forfeits the banked +50% gain to chase +100%/+200% levels that only 6%/0% of paths ever reach (20/82 ≥ +50%, 5/82 ≥ +100%, 0/82 ≥ +200%). On current data the described TP ladder is strictly worse — it gives up realized money for levels that don't occur.
- **V4's $7.28 edge over V0 = exactly 5 slow-bleed trades** (4 IS, 1 OOS). Unvalidated hypothesis, winner's bias on a tiny subset, and it still fails retention at 35%.
- Replay fidelity: V0 replay vs recorded P&L r=0.94, bias +$0.17/trade (the bot's paper slippage haircut — disclosed, favors no variant).

## Data-availability verdict on price paths

Answerable, with a disclosed bias: 121 stamped closes, 82 (67.8%) have full entry→exit tapes from `runs/paper-1h/quote_paths/`. **Selection bias: the entire 9-24 regime (worst day, PF 0.151) has no tapes** — capture only began 9-27. So results describe the 9-27/9-28 regime, not the full lifetime. The worker adopted two corrections from Astra's review: count reconciliation (83 path-files exist vs 82 full-cover — one partial-path trade) and tape-censoring disclosure (force-closes flatter V1/V3: V1:4, V3:5).

## V5 (early-wave entry): NEEDS FRESH DATA — honest verdict, not a failure

Frozen rule defined: first-sighting priority (`repeat is null` from ObservationTracker) + 15m-gain entry band [threshold, 60%), all guardrails unchanged (rug guard, honeypot, veto_positive_slip, caps). Historical backtest is impossible in principle: `candidates.jsonl` starts 2026-09-28 12:25 ET (40 obs at showdown time); all 121 closes predate it; GeckoTerminal cannot reconstruct our hunter's first-sighting times. Full forward-validation protocol is specified in the worker report for the 4h loop: frozen rule, shadow entries scored on V0 exits, ≥30 OOS entries under the rule, rug-reject-rate tracked per cohort, pre-registered expectation that earlier entries = more rug exposure. V5 does NOT ship on user order — no validation behind it, and the user was told exactly that.

## Poll interval: keep 2s

Ops judgment, not a backtest (not backtestable from trade records): only 2 BLIND warnings in bot.log total — no evidence 2s polling causes load problems; 5s would loosen every stop ~3s for no demonstrated benefit.

## Astra's skeptical review (gpt-6-astra, full text in worker report)

"Nothing ships" survives. Strongest objection: no variant shows positive OOS expectancy. Directional reads were softened per its critique; it forced the count-reconciliation and tape-censoring corrections above.

## What shipped

**Nothing.** No variant passed every gate → no config change, no restart, no CHANGELOG entry for strategy. Bot untouched (PID 23939), config verified unchanged (TP [[50,50]], trail 25, hard 35, poll 2s, veto_positive_slip=true, allocator shadow, dry_run=true). Full worker report: `hidden_files/deep-improvement-loop/showdown-empirical-report.md`; harness `analysis/exit_showdown.py`; rows `analysis/exit_showdown_results.json`.

## What would change this verdict

- V4 (or any exit variant): a fresh ≥30-trade OOS window where retention clears 60% with positive OOS expectancy. The 4h loop can re-gate.
- V5: the forward-validation protocol completing with ≥30 OOS entries under the frozen rule.
- The structural leak (LP-pull wipes = 72% of lifetime losses; negative edge ex-wipes) remains the binding constraint — exit tuning cannot fix it, which is exactly what this showdown confirmed.
