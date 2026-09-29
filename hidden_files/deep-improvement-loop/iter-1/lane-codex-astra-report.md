# LANE-CODEX-ASTRA report — deep-improvement loop, iteration 1

**Date:** 2026-09-28 ~16:08–16:45 EDT. **Lane:** codex-astra (implementer + analyst).
**Coordinator handoff note:** this is the full report; the handoff message is only a completion ping.

## 0. Execution status — Codex and Astra both quota-blocked

- `/usr/bin/codex` has vanished from the VM again (AGENTS.md lesson confirmed);
  `~/.local/bin/codex` (0.158.0) works as the replacement path.
- **Both `gpt-6-sol` and `gpt-6-astra` return "You've hit your usage limit …
  try again at 10:52 PM"** — the usage pool is shared. Per the lane task,
  **all Codex implementer work is STOPPED for this iteration** and noted here.
  (Per AGENTS.md the exhaustion message's retry time is unreliable; the
  user-confirmed reset is 7pm ET.)
- Fallback binary `/opt/hatch-image/bin/codex` (0.149.0) also tested and
  **abandoned**: `gpt-6-astra` → "requires a newer version of Codex";
  `gpt-6-sol` → "not supported when using Codex with a ChatGPT account"
  (matches the AGENTS.md lesson). No working Codex path exists this
  iteration; total binary-hunting time <10 min per the operational note.
- Astra could not run either. The structural diagnosis was performed directly
  by the lane in-shell and saved to
  `hidden_files/deep-improvement-loop/iter-1/lane-astra-structural-diagnosis.md`
  (clearly labeled as the quota-fallback analysis).
- **No Codex session ran, so no canary test was needed and no pytest
  re-verification was triggered by agent work.** Baseline suite in my own
  shell: **698 passed** (twice), green. The sibling 6h lane has uncommitted
  changes in the tree (CHANGELOG.md, fomo_trader.py, bsc_swap.py, tests,
  etc.) — I did not touch any file it is editing; my only new file is
  `analysis/iter1_trackb_screens.py` (new, no interference).

## 1. Candidates tried (Track B) — ALL FAIL

Harness: `analysis/iter1_trackb_screens.py` (new file, read-only vs bot
state). 164 FIFO pairs from `runs/paper-1h/trades.jsonl`. Cost model =
lane-3 convention (0.15%/leg base slippage, 0.004 SOL / 0.00004 BNB fixed
round-trip; 3x-fee stress at 0.45%/leg). Walk-forward by close append order:
IS = first 110 pairs (43 SOL / 67 BSC), OOS = last 54 (all BSC).
Output saved at `iter-1/trackb_screens_output.txt`.

| Candidate | IS (kept) | OOS (kept) | OOS PF | Retention | 3x-fee PF | Verdict |
|---|---|---:|---:|---:|---:|---|
| BASELINE (no screen) | 110, PF 0.275, −$167.44 | 54, PF 0.183, −$59.17 | 0.183 | 66.5% | 0.173 | FAIL (losing) |
| **G1a: veto signal_gain ≥ 60 (NEW)** | 27, PF 0.988, −$0.45 | 10, PF 0.479, −$7.10 | 0.479 | 48.5% | 0.467 | **FAIL** |
| **G1b: veto signal_gain ≥ 100 (control)** | 41, PF 0.982, −$1.04 | 20, PF 0.321, −$19.48 | 0.321 | 32.7% | 0.310 | **FAIL** |
| **G2: veto positive slip (shipped-veto reproduction)** | 86, PF 0.335, −$114.15 | 33, PF 0.451, −$15.16 | 0.451 | 134.6% | 0.424 | **FAIL** |

FAIL reasons:
- **G1a:** IS kept 27 < 100; OOS kept 10 < 30; retention 48.5% < 60%;
  3x-fee PF 0.467 < 1. The IS near-breakeven (PF 0.988) is an artifact of
  vetoing 75% of trades — **savings by non-participation, not edge**;
  expectancy stays negative (−$0.02 IS, −$0.71 OOS). Killed as a ship candidate.
- **G1b:** retention 32.7%, OOS decay 67.3% — confirms the prior round's
  rejection of the gain ≥100% veto. Killed (again).
- **G2:** directionally supportive of the shipped slip veto — OOS PF
  0.451 vs baseline 0.183 (**+0.268 gain**), OOS WR 42% vs 31% — but fails
  gates (retained IS 86 < 100; 3x-fee PF 0.424 < 1; expectancy still
  −$0.46/trade). Verdict: **harm-reducing, not edge-creating.** The veto
  was correctly shipped on user order as risk reduction. No change proposed.

**Nothing passes every gate → nothing is proposed for shipping this
iteration.** Per the showdown precedent, **no CHANGELOG.md entry** (nothing
proposed; the sibling lane owns that file's in-flight edits anyway).

## 2. Slip-veto forward validation (task item 4a)

- Cutoff 2026-09-28 16:24 UTC (12:24 EDT ship). **Pre: 156 pairs, 17.3%
  wipe rate, −$136.12. Post: 8 pairs, 25.0% wipe rate (2/8), −$11.85.**
- The veto is mechanically working: 0 positive-slip entries post-veto
  (vs 47% of slip-known entries pre-veto) and 12 `slip_veto` journal events
  with would-be prices.
- **No efficacy verdict possible at n=8** (bar is ≥30 closes). The two
  post-veto wipes prove **wipes do not require chase entries**.
- Unknown-slip (fails-open) hole: 39% of pre-veto entries; 0/8 post-veto
  so far — monitor; >40% means circumvention.
- Decision rule for future iterations is specified in the structural
  diagnosis (§5): ≥30 closes needed (≈14h at ~2.1 closes/h → earliest
  ~10:30 UTC / 06:30 EDT 2026-09-29); "working" = wipe rate <10% with
  improved expectancy/trade on ≥30 closes.

## 3. V5 early-entry readiness (task item 4b)

- Frozen rule: first-sighting (`repeat is null`) + 15m-gain [threshold, 60%),
  all guardrails unchanged.
- **14 strict-V5-eligible observations in 3.75h (≈3.7/h)**; 3 became
  baseline entries → ~2.9 shadow-entry equivalents/h.
- **68/82 raw first-sighting modest-gain observations were rug-guard
  rejected** — the eligible stream is thin because the guard eats ~83% of
  early sightings.
- **Earliest ≥30-entry gate: ~8–10h of clean journaling → ~00:30–02:00 UTC
  2026-09-29 (20:30–22:00 EDT tonight), but ONLY IF two missing pieces ship:**
  (a) `v5_eligible` + shadow-entry instrumentation in journal.py/hunter
  (behavior-neutral, but a bot code change — coordinator's call), and
  (b) ObservationTracker persistence across restarts. **Without both, the
  protocol cannot start.**
- **Blocker severity: HIGH.** The bot restarted 3× in the last 3.75h
  (18:40, 18:45, 19:00 UTC per deaths.log); each restart resets the
  in-memory ObservationTracker, corrupting first-sighting state. The
  journal's `repeat is null` flags since 16:25 UTC already contain
  restart-noise. The V5 protocol's caveat about this is now empirically
  confirmed as the binding blocker, not a footnote.

## 4. Structural diagnosis (Astra-fallback, in-shell)

Full text: `iter-1/lane-astra-structural-diagnosis.md`. Headline findings:

- **Edge break-point:** 29.9% of entries dead-on-arrival (peak <+10%);
  only 22.6% ever reach +50%, 7.9% reach +100%, 0% reach +200%.
  Loser decomposition: 44 immediate-reversal, 54 mid-range fade, only 15
  gave-back-gains — **failures to launch dominate; the problem is entry,
  not exit.**
- Winners are lottery-like: 22 trades (13%) with peak ≥+50% produce 79%
  of gross wins ($69.59/$88.58). Exit tightening would kill the only thing
  that works — exit tuning ruled out (again).
- Dump detector (107 exits): 68% had peaked ≥+10% before fading; it exits
  dead momentum, not winners' legs — but loosening it feeds wipes.
- Ruled out this iteration: time-of-day filter (no hour ≥20 trades with
  positive expectancy), buy-share screens (no gradient), entry-latency
  screens (weak gradient), gain-cap screens (G1a/G1b FAIL above).
- Live hypotheses, all forward-only: **H1 pool-age screen** (0/170 lifetime
  entries have pool_created_at — needs entry-time logging + 1–2 weeks),
  **H2 persistence confirmation** (needs tracker persistence + shadow
  entries, 2–4 weeks), **H5 V5** (see §3).

## 5. Proposals for the coordinator (not shipped; lane has no ship authority)

1. **V5 instrumentation** (`v5_eligible` bool per observation + shadow paper
   entries scored on V0 exits + persisted ObservationTracker): the single
   highest-value code change available — it unblocks H2 and H5, the only
   live hypotheses. Behavior-neutral to live trading; needs coordinator
   approval since it touches the running bot.
2. **Log `pool_created_at` on entries** (journal.py already captures it on
   candidates): unblocks H1 pool-age screen testing within 1–2 weeks.
   Additive, behavior-neutral.
3. **No strategy/config change proposed.** All tested candidates failed;
   the shipped slip veto stands on its harm-reduction evidence.

## 6. Constraints compliance

- Paper-only maintained; dry_run untouched; trades.jsonl / state.json /
  bot.log / deaths.log / keypair.json / wrapper.log never modified
  (deaths.log and journals read only).
- No private keys installed, read, logged, or exposed. No guard weakened,
  no size increased, no cap loosened. All changes are new analysis files.
- Running bot (PID 1867) not disturbed, not restarted.
- Sibling lane: observed its uncommitted edits; did not touch them; suite
  green (698 passed) before and after my work — **no in-flight breakage
  to report.**

## 7. Verdict

**Iteration 1 (this lane): no gate-passing candidates; nothing proposed for
shipping.** The iteration's value is diagnostic: (a) gain-cap screens
formally killed, (b) slip-veto forward-validation bar set with earliest
decision ~06:30 EDT 9-29, (c) V5 readiness dated (~20:30–22:00 EDT tonight
*if* instrumented) with the restart-noise blocker identified as binding,
(d) the journaling infrastructure confirmed as the asset that converts
untestable hypotheses into forward-testable ones. Honest ship-nothing
iteration.

**Files produced (all new, no existing files modified):**
- `hidden_files/deep-improvement-loop/iter-1/lane-astra-structural-diagnosis.md` — structural diagnosis (Astra quota-fallback)
- `hidden_files/deep-improvement-loop/iter-1/lane-codex-astra-report.md` — this report
- `hidden_files/deep-improvement-loop/iter-1/trackb_screens_output.txt` — Track B raw output
- `hidden_files/deep-improvement-loop/iter-1/astra_prompt_iter1.md` — the Astra prompt (kept for rerun post-quota)
- `analysis/iter1_trackb_screens.py` — Track B screen harness (reusable)

**Coordinator bookkeeping note:** state.json / loop-log.md / daily memory
note updates are the coordinator's STEP 4 — not done by this lane.
