Implemented the **experimental, unshipped** replay in [candidate_early_veto.py](/home/hatch/workspace/fomo-trader/analysis/candidate_early_veto.py), its hermetic [tests](/home/hatch/workspace/fomo-trader/tests/test_candidate_early_veto.py), and the [CHANGELOG entry](/home/hatch/workspace/fomo-trader/CHANGELOG.md). The write canary passed and was deleted. No bot behavior, run file, or paper configuration was changed.

| Gate | Result | Observed |
|---|---|---:|
| OOS edge ≥60% of IS, base / stress | **FAIL / FAIL** | 50.5% / 50.9% |
| Original IS ≥100 / OOS ≥30 | **PASS / PASS** | 106 / 54 |
| Kept OOS net positive, base / stress | **FAIL / FAIL** | −$16.29 / −$16.75 |
| Kept OOS ≥30 | **FAIL** | 20 |
| Kept OOS WR ≤90% | **PASS** | 40.0% |
| OOS edge decay ≤70% | **PASS** | 49.5% base / 49.1% stress |
| Largest 20-close block ≤70% of savings | **PASS** | 46.9% |
| Kept OOS spans both chains | **FAIL** | 20 BSC; no Solana |

The replay paired 160 trades, found 3 unmatched closes, and purged no boundary-crossing pairs. IS kept 40/106 trades (37.7%): full net was −$163.77 base / −$168.06 stress, kept net −$6.42 / −$8.22, and edge **+$1.4844 / +$1.5079 per original trade**. OOS kept 20/54 (37.0%): full net was −$56.78 / −$58.19 and edge **+$0.7498 / +$0.7674**.

Kept IS WR/PF was 42.5%/0.891 base and 42.5%/0.862 stress; max drawdown was $24.14/$25.47. Kept OOS WR/PF was 40.0%/0.413 and 40.0%/0.401; max drawdown was $18.59/$18.78. The veto removed 4 IS and 7 OOS wipes while retaining 4 IS and 3 OOS wipes. It also vetoed 7 IS winners and 9 base-costed OOS winners (8 under stress).

**Verdict: INCONCLUSIVE; do not ship.** Fewer than 30 OOS trades remain, and the edge-retention and positive-net gates also fail. The full suite passed: **669 passed, 0 failed**.

One specification conflict remains: the frozen expression `(signal_gain_pct or 0) >= 100.0` *keeps* `None`, while the requested test says `None` vetoes. The script and test follow the frozen expression. None of the paired journal entries has a missing gain.

`git status --short` before work already showed concurrent edits and untracked files. After work, the only paths I added or edited were the replay script, its test, and `CHANGELOG.md`; the other reported paths were present beforehand.
exit=0
