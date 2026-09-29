# LANE-CODEX-ASTRA report — deep research pass 2026-09-28

**Lane:** Codex (implementer) + Astra (analyst), Track B validation pipeline
**Date:** 2026-09-28, ~12:05–12:20 EDT
**Operator:** subagent lane, read-only against the live bot (PID 17262, untouched)
**Bottom line: nothing ships. One journal-testable candidate failed Track B;
  one research hypothesis is untestable from this journal. Honest ship-nothing.**

## 1. Method and integrity

- Journal snapshot: `runs/paper-1h/trades.jsonl`, 323 append lines, 160
  entries / 163 closes, SHA-256
  `ed4391fec4200661351164b99431f33be27ed35a0d6773f23f0987707a87be6b`
  — verified UNCHANGED after all lane work (same hash before/after).
- Astra analysis ran as GPT-6 Astra via Codex CLI
  (`/usr/bin/codex exec --model gpt-6-astra -s read-only`), read-only, full
  text preserved at `hidden_files/research-pass-2026-09-28/lane3_astra_structural_diagnosis.md`.
- Codex implementation ran as gpt-6-sol via stdin prompt
  (`-s workspace-write`). Write access was verified with a canary
  file + read-back before any result was trusted (per the AGENTS.md lesson).
- Codex diff: exactly `analysis/candidate_early_veto.py` (replay script),
  `tests/test_candidate_early_veto.py` (5 hermetic tests), and a CHANGELOG
  entry marked experimental/unshipped. No bot, config, or run-file change.
  No restart. Bot confirmed still running (PID 17262) with a live log after
  the session.
- Full pytest suite re-run **in the lane's own shell**: **669 passed,
  0 failed** (664 pre-existing + 5 new). Sibling-lane in-flight edits were
  present; none of their failures needed fixing (there were none).
- Hard constraints held: paper-only, `dry_run=true` intact, no key material,
  no loosened risk control, no size increase, no network/randomness in hot
  path, no sibling-lane interference.

## 2. Astra-led diagnosis (structural, beyond the wipe screens)

Astra started where Lane 2 ended (18 primary wipes = $99.38 ≈ 45% of costed
net loss) and asked whether the STRATEGY ITSELF has edge. Fresh accounting
(160 FIFO pairs, base-costed; stress = 3x slippage only):

| Family | n | Costed P&L | WR | PF | Avg win | Avg loss |
|---|---:|---:|---:|---:|---:|---:|
| Primary wipe | 18 | −$99.38 | 0% | 0 | — | $5.52 |
| Dump detector, non-wipe | 93 | −$42.51 | 29.0% | 0.52 | $1.68 | $1.33 |
| Trailing stop | 31 | −$71.59 | 29.0% | 0.28 | $3.09 | $4.52 |
| Venue dump, non-wipe | 9 | −$7.84 | 0% | 0 | — | $0.87 |
| Stale | 5 | −$3.16 | 20% | 0.03 | $0.10 | $0.82 |
| Manual rotation | 3 | +$0.91 | 100% | — | $0.30 | — |
| Terminal take profit | 1 | +$3.02 | 100% | — | $3.02 | — |
| **Overall** | **160** | **−$220.55** | **25.6%** | **0.26** | **$1.89** | **$2.50** |

Key structural findings:

1. **Expectancy fails outside wipes too.** Removing all 18 primary wipes
   still leaves −$121.17 costed (−$88.35 raw). Overall expectancy
   −$1.378/trade; non-wipe expectancy −$0.853/trade. A wipe-only fix cannot
   make the strategy profitable.
2. **The trailing stop is the worst ordinary-loss family** (−$71.59, expectancy
   −$2.309/trade). Older Solana trailing exits dominate: 25 closes, −$74.70,
   16% WR, median holding ≈3.1 min — rapid failure/reversal after entry, not
   slow attrition. BSC ordinary dumps close in ≈0.82 min median; 24 of 79
   recorded peaks below +10%. Failures happen before continuation — an entry
   / immediate-path problem, not a late-exit problem.
3. **Signal decay is real but not a clean threshold.** 100 entries with
   signal_gain ≥100%: −$197.84, 16% WR, expectancy −$1.978/trade. <100%:
   60 trades, −$22.71, 41.7% WR. Correlation of signal gain vs raw return is
   −0.449 on Solana but only −0.047 on BSC; regime changes limit inference.
4. **Every 20-trade sequence block loses** (8/8), across Solana-era and
   BSC-era blocks. Later (all-BSC) cohort: 54 closes, −$56.78; wipes are
   −$45.27 of it, but non-wipe expectancy is still −$0.262/trade.
5. **Sizing is not the leak.** Observed allocator multipliers range
   0.52–1.00 (no >1x cohort to evaluate); the upper half has better outcomes
   (33.3% vs 26.7% WR), contradicting "bigger tickets cause worse outcomes".
6. **Config drift warning:** the on-disk paper config no longer matches the
   described strategy (TP 50%@+50% not +100%, trailing 25% not 30%, poll 2s
   not 5s, hunter 20%/10/$8k, daily cap 30/$60, mint cooldown 10 min). The
   journal is a mixture of strategy versions — terminal-reason attribution
   cannot isolate one precise entry/management rule.
7. Drift association (positive signal-to-commit drift: 45 enriched BSC pairs,
   −$97.31, WR 13.3% vs negative drift: 48 pairs, −$5.66, WR 37.5%) is already
   addressed by the shipped Round 3 size cap; nothing further proposed.

**Astra's verdict: no supportable structural change.** The scanner-entry
continuation assumption is not supported by these outcomes (−$186.77 raw,
−$220.55 costed, −$121.17 ex-wipes, all 8 sequence blocks losing).

## 3. Candidate 1 — early-entry gain veto (journal-testable) → FAIL

**Frozen predicate:** veto entries with `(signal_gain_pct or 0) >= 100.0`
(keep <100% only). If shipped, an additional pre-entry filter in the
hunter→entry handoff; never loosens guards or grows tickets. Not a retune of
the rejected >200% veto — the band evidence (<100%: PF ~0.74–0.92 vs ≥100%:
PF ~0.07) motivated this exact frozen predicate, threshold fixed before
validation.

**Track B replay** (`analysis/candidate_early_veto.py`, hermetic tests in
`tests/test_candidate_early_veto.py`): 160 FIFO pairs, close-append-order
split 106 IS / 54 OOS, 0 boundary-crossing pairs purged, Lane 2 cost model,
edge = (kept_net − full_net) / original cohort size, vetoed = $0.

| Metric | IS base | IS stress | OOS base | OOS stress |
|---|---:|---:|---:|---:|
| Original / kept | 106 / 40 | 106 / 40 | 54 / 20 | 54 / 20 |
| Full net | −$163.77 | −$168.06 | −$56.78 | −$58.19 |
| Kept net | −$6.42 | −$8.22 | −$16.29 | −$16.75 |
| Edge / original trade | +$1.4844 | +$1.5079 | +$0.7498 | +$0.7674 |
| Kept WR / PF | 42.5% / 0.891 | 42.5% / 0.862 | 40.0% / 0.413 | 40.0% / 0.401 |
| Kept max drawdown | $24.14 | $25.47 | $18.59 | $18.78 |
| Wipes vetoed / kept | 4 / 4 | 4 / 4 | 7 / 3 | 7 / 3 |
| Winners vetoed | 7 | 7 | 9 | 8 |

**Gate results:**

| Gate | Required | Observed | Verdict |
|---|---|---|---|
| OOS edge ≥ 60% of IS edge (base) | ≥60% | 50.5% | **FAIL** |
| OOS edge ≥ 60% of IS edge (stress) | ≥60% | 50.9% | **FAIL** |
| IS ≥ 100 trades | ≥100 | 106 | PASS |
| OOS ≥ 30 trades | ≥30 | 54 | PASS |
| Kept OOS net positive (base/stress) | >$0 | −$16.29 / −$16.75 | **FAIL** |
| Kept OOS ≥ 30 (else inconclusive) | ≥30 | 20 | **FAIL → INCONCLUSIVE** |
| WR ≤ 90% red flag | ≤90% | 40.0% | PASS |
| OOS edge decay ≤ 70% | ≤70% | 49.5% / 49.1% | PASS |
| No single 20-close block > 70% of savings | — | max 46.9% | PASS |
| Cross-chain robustness | spans chains | OOS kept = 20 BSC, 0 Solana | **FAIL** |

**Verdict: FAIL / INCONCLUSIVE — do not ship.** The veto dramatically
improves IS (kept −$6.42 vs full −$163.77) but OOS retention is 50.5%
(<60% gate), retained OOS still loses −$16.29 at base cost, only 20 OOS
trades are retained (<30 = inconclusive regardless), and there is no later
Solana holdout. Seven of ten later primary wipes are vetoed, but the
retained cohort has no edge. This candidate is dead unless fresh
feature-complete OOS data (≥30 retained OOS, both chains) overturns it.

## 4. Candidate 2 — persistence confirmation (Astra's research hypothesis) → UNTESTABLE

**Mechanism:** a single scanner observation doesn't establish continuing
demand; require two consecutive qualifying appearances (same
chain/mint/window, each independently passing all guards) before the normal
entry path. Deterministic pending state, no slot reservation, no size change.

**Journal evidence motivating it:** gain ≥100% entries −$197.84 (16% WR);
79 BSC ordinary dump exits −$40.93 with 24 peaks below +10%; wipe removal
alone leaves −$121.17.

**Why untestable:** the journal contains committed entries only — not the
full candidate stream, not second-observation prices, not missed-winner
counterfactuals. No delayed fill, saved loss, or replacement trade can be
honestly credited. **Not implemented** (implementing without validation would
violate verdict-only). Falsifiable prediction recorded for prospective
evaluation: a replay over successive scanner observations must show reduced
non-wipe loss per original opportunity at base and stressed costs, with
positive retained OOS P&L across later sequence blocks.

## 5. Ruled out without implementation (Astra, with numbers)

- **Wipe-only explanation:** rejected — non-wipes lose $121.17.
- **Fewer/later TP rungs:** no basis — 34 trades with a recorded rung made
  +$45.67; only 14/160 peaks reached +100%; rung occurrence is an outcome,
  not an entry feature.
- **Tighter trailing stop / earlier time-stop:** not identifiable from
  terminal records; peaks+exits don't reveal executable prices at earlier
  threshold crossings; 5 stale trades explain only $3.16.
- **Bigger allocation causes worse outcomes:** rejected — upper multiplier
  half outperforms the lower half.
- **Chain/window switching:** unsupported — Solana loses $76.10, BSC
  $144.45; the 5m cohort is 14 trades; the 15m cohort still loses $175.60.
  Solana's <100% cohort (+$7.35, 26 trades) is older, small, no later
  holdout.
- **Previously rejected screens** (gain veto >200%, $30k liquidity floor,
  imbalance/buy-count floors, holder concentration, tighter venue-m5):
  not re-proposed, not retuned. Holder/LP fields still NULL on 100% of
  paired entries — holder screens remain not_runnable.
- **Drift veto / another drift cap:** not proposed — the shipped Round 3
  size cap (111.1% base edge retention) already addresses the drift
  association.

## 6. What changed in the repo (lane's footprint)

- Added: `analysis/candidate_early_veto.py`,
  `tests/test_candidate_early_veto.py`,
  `hidden_files/research-pass-2026-09-28/lane3_astra_structural_diagnosis.md`,
  `hidden_files/research-pass-2026-09-28/lane3_codex_validation_transcript.md`,
  this report.
- Modified: `CHANGELOG.md` (one prepended entry: "Track B Lane 3 —
  early-entry gain veto (verdict only, unshipped)").
- Untouched: `fomo_trader.py`, all configs, all of `runs/` (trades.jsonl
  hash verified identical), bot process (PID 17262 running, live log).
- Suite: 669 passed, 0 failed (lane's own shell).

## 7. Open questions for the coordinator

1. The journal is a mixture of strategy versions (config drift documented
   above). Any future candidate validated on the full journal inherits that
   mixture; consider version-tagging entries or a fresh feature-complete
   window before the next Track B round.
2. Persistence confirmation needs the candidate stream (scanner observations
   that did NOT become entries) plus second-observation prices — currently
   not journaled. If the coordinator wants it testable, the bot must log
   the candidate stream first; that is instrumentation, not a strategy
   change.
3. The sibling lane has extensive uncommitted work (incl. its own low-gain
   experiments, e.g. `analysis/x3_lowgain/`). No conflicts were created by
   this lane, but reconciliation should confirm the CHANGELOG ordering and
   that `candidate_early_veto.py` and the sibling's low-gain work don't
   duplicate.

## 8. Final verdict

**SHIP NOTHING.** Candidate 1 failed Track B (retention 50.5%/50.9%,
kept OOS net −$16.29/−$16.75, 20 retained OOS < 30, no cross-chain holdout).
Candidate 2 is untestable from this journal. Astra's structural diagnosis
stands: the scanner-entry continuation assumption is unsupported
(−$186.77 raw / −$220.55 costed / −$121.17 ex-wipes), but no supportable
structural change follows from this evidence. The honest outcome is
verdict-only, and it is recorded as such.
