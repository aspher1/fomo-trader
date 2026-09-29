# Follow-up fix — 2026-09-28 (coordinator pass)

User orders executed in this pass: (1) the original follow-up mandate
(safe instrumentation + allocator back to shadow, no strategy-behavior
changes), plus (2) a later direct user order to **fix the buying on top** by
shipping the positive-slip veto, explicitly overriding the deep pass's
"inconclusive, don't ship yet" verdict for that candidate ONLY. Everything
else keeps the verdict-only rule.

Paper-only throughout. `dry_run=true` intact. Protected files untouched
(trades.jsonl, state.json, bot.log, deaths.log, keypair.json, wrapper.log).
No private keys installed/read/logged. No rug-guard, sizing, kill-switch,
risk-cap, TP/trailing/hard-stop, or polling-interval changes.

## Shipped

### Task A — research instrumentation (additive, zero behavior change)
- NEW `journal.py`: `STRATEGY_VERSION = "1"` (bump only on strategy-behavior
  changes, never for instrumentation). Never raises, never mutates inputs,
  no network.
- NEW `runs/paper-1h/candidates.jsonl`: every scanner observation journaled,
  including guardrail rejects (verdict `enter` / `guardrail_skip`). Fields:
  symbol/mint/pool, chain, timestamp, price/liquidity/volume, buys/sells,
  gain, mcap, `pairCreatedAt`/pool-age (DexScreener ms normalized to seconds;
  missing -> null), source/window, strategy version, and repeat/second-
  observation info via in-memory `ObservationTracker` (`first_ts`,
  `second_price_usd`, `sightings`; bounded, evicts oldest). Single-backup
  rotation past 50 MB. Verified live: the restarted bot is already writing
  candidate rows.
- Every entry journal record now carries `strategy_version`,
  `pool_created_at`, and gap-filled signed slip / liquidity / signal gain
  (`finalize_entry_record`; never clobbers existing values).
- Hooks are minimal: one import, one tracker in `__init__`, one
  `_journal_candidate()` call per scan loop branch, `pool_created_at` in the
  three signal builders, one `finalize_entry_record()` wrap at each of the
  two entry journal sites.

### Task B — allocator back to shadow
- `runs/paper-1h/config.json`: `allocator.mode` `live` -> `shadow` (with a
  comment noting it went live with uncalibrated priors against the standing
  shadow verdict; it goes live again only on a pass verdict in
  `analysis/allocator_proposal.json`). Shadow scores every commit and
  journals `allocator_score/take/multiplier/would_be_native` but never skips
  and never changes ticket size (1.0x). No allocator logic edits were needed.

### Task C — positive-slip (chase) veto (BEHAVIOR CHANGE, user-ordered)
- At the commit point on both chains, if measured slip > 0 (fill above the
  signal print), the entry is vetoed: no position, journaled as a `slip_veto`
  event in `candidates.jsonl` with full would-be details for retrospective
  validation. Config `hunter.entry.veto_positive_slip`, default true
  (user-togglable). Strict > 0, no tolerance band.
- Fail-OPEN on missing data: unknown slip logs `SLIP-VETO GAP` and proceeds.
  With the veto on, the pre-existing wipe-drift 0.5x cap never fires (veto
  runs first); it still applies with the veto toggled off.
- HONEST CAVEAT: validated walk-forward was PF 0.254 -> 0.796 at 91% OOS
  retention on a SMALL sample (n_IS=29 / n_OOS=18). The 4h loop keeps
  validating with fresh data.

## Tests
- 29 new tests in `tests/test_fixup_2026_09_28.py` (journal fields,
  null-degradation, tracker bounds, veto record, entry finalizer, veto
  behavior x5, allocator shadow/live, no-mutation parity).
- Full suite in the coordinator's own shell (venv pytest): **698 passed,
  0 failed.**
- The 39 initial failures were all in the sibling lane's untracked test files
  (`tests/test_z3_obs.py`, `tests/test_z4_capture.py`, `tests/test_allocator.py`),
  broken by MY deliberate changes: golden entry bytes (new instrumentation
  fields) and the allocator mode expectation (`live` -> `shadow`). I updated
  only those mechanical expectations (golden strings + comment, mode param,
  one last-key assertion -> membership check preserving intent). Per
  AGENTS.md I did not touch any of the sibling lane's own in-flight
  breakage; these files remain untracked and theirs.

## Restart
- Old bot PID 17262 (wrapper 17257) SIGTERM'd (clean exit, code 0);
  relaunched via `run_bot.sh` -> **new bot PID 23939** (bot.pid matches pgrep).
- Verified live: dry_run=true, allocator=shadow, veto_positive_slip=true;
  new bot scanning and heartbeating; candidates.jsonl receiving rows.

## Config drift (verified on disk 2026-09-28, NOT changed — needs user approval)
- TP ladder: **50% @ +50%** (described strategy: 50% @ +100%).
- Trailing stop: **25%** (described: 30%). Hard stop 35%.
- Manage poll (`exit.sell_poll_sec`): **2s** (described: 5s). Hunter poll 30s.
- Daily cap: **max_trades_per_day 30**, profit-boost 40 trades at +$10 locked
  (prior stated ceilings differed).
- take_profits `[[50, 50]]`, `trailing_stop_pct` 25, `sell_poll_sec` 2 read
  from `runs/paper-1h/config.json`.

## Follow-ups for the loop
- Re-validate the slip veto once >= 30 retained OOS trades exist (small-sample
  caveat above).
- `candidates.jsonl` now feeds pool-age / persistence-confirmation candidates
  that were previously untestable (missing observations).
- Veto journaling + tracker give the loop the `slip_veto` cohort to study
  retrospectively.
- Watch: `candidates.jsonl` growth (50 MB rotation guard in place); the
  veto's interaction with the wipe-drift cap when toggled off.
