# FOMO Trader CHANGELOG

Every behavior change, with the evidence that motivated it. This is the
paper-validation record: nothing here touches real money (dry_run=true).

## 2026-09-27 — Track B offline exit sweep (no exit change recommended)
- Added `analysis/exit_sweep.py`, 9 hermetic tests, and `analysis/exit_sweep_report.md`. The read-only journal snapshot had 73 closes; used first 45 by `close_ts` as IS and final 28 as OOS (round 2's 45/22 split had 67 closes).
- Swept 467 sets across one- and two-rung TP thresholds/fractions, trailing and hard stops, stale timeout and gain threshold, dump threshold and window, and post-TP trail. The strongest IS region was TP `[[30,100]]` plus 10% trail, with nearby ladders and 15–20% trails retaining IS edge; OOS trail sensitivity was absent. No set passed all gates.
- Current exit base IS: 45 / −$75.63 / 35.6% wins / PF 0.282 / $75.63 max drawdown; OOS: 28 / −$46.24 / 10.7% / PF 0.227 / $52.27. Current exit 3× slippage: −$77.75 IS and −$47.27 OOS.
- Exploratory top point base IS: 45 / −$38.83 / 48.9% / PF 0.385 / $42.14 drawdown; OOS: 28 / −$26.47 / 35.7% / PF 0.374 / $30.55. At 3× slippage: IS −$41.17, PF 0.359, drawdown $44.04; OOS −$27.62, PF 0.357, drawdown $31.60. It retained 86.4% of IS per-trade edge OOS but failed the required positive OOS stress net. Counterfactual TP fills and stop timing remain uncertain from entry/peak/exit alone.
- **Exact recommended JSON Patch for `exit`: `[]`**. No bot, paper config, journal, or risk guard was changed; no restart. Full hermetic suite: 100 passed, 0 failed (`.venv/bin/python -m pytest tests/ -q`). Paper-only `dry_run=true` remains required.

## 2026-09-27 — Track C signal quality
- Offline paper snapshot: 628 parsed FOMO/PRE-PUMP signals, 70 entries and
  73 closes (3 closes without entry evidence). Join uses normalized names,
  journal-anchored log dates, same chain, and a 30-minute signal-to-entry
  window. It assigns 17 entered winners, 53 entered losers, 0 entered without
  a close, 476 never-entered, and 82 best-effort guard-skip observations.
  Repeated signals are individual observations; the latest eligible signal
  is paired to each entry. The full method, caveats, and all selection and
  outcome buckets are in `analysis/signal_quality_report.md`.
- Strong descriptive splits: logged gain <100% had 30 entries, 43.3% wins,
  PF 1.055, +$1.88 costed net; gain >=400% had 11, 9.1%, PF 0.092,
  -$45.85. Ratio >=4 had 11 entries, zero winners, -$26.46; liquidity
  >=$50k had 23, one winner, -$62.70. These overlap and are not validated
  entry edges. UTC hours 12–17 and 18–23 had similar win rates (24.1% and
  22.5%) and both lost money (-$71.91 and -$50.12); 06–11 had one entry.
  Launcher zone switches in `deaths.log` were matched to bot-start lines
  before converting hours and entry timestamps to UTC. Chain results are
  confounded with the later BSC-heavy period.
  Weak or untestable features: ratio <2 and 2–4 had nearly identical win
  rates (29.0% and 28.6%); only 3/70 entries (4.3%) recorded each of
  m15 buy/sell counts, volume, market cap, slip, and latency; no matched
  entry came from DexScreener or a pre-pump line. The prior gain and
  liquidity caps remain rejected.
- Added a pure-stdlib, fail-open `analysis/signal_filter.py` and parameter
  file. The one-threshold offline candidate vetoes buys/sells ratio >=4;
  the ratio >=3 and >=4 family was compared on the first 47 entries only,
  ordered by UTC-normalized entry time. The >=4 threshold had the better IS per-trade
  edge (+$0.024 versus -$0.001). IS unfiltered: **47 / -$69.36 / 34.0% /
  PF 0.348 / $76.24 max drawdown**; filtered: **41 / -$59.53 / 39.0% /
  PF 0.383 / $66.75**. OOS unfiltered: **23 / -$50.46 / 4.3% /
  PF 0.092 / $50.46**; filtered: **18 / -$33.83 / 5.6% / PF 0.132 /
  $33.83**. OOS per-trade edge was +$0.314, above 60% of IS edge,
  but the retained OOS set had only one winner. Under 3x estimated
  slippage, IS unfiltered/filtered were -$71.53/-$61.45 and OOS
  unfiltered/filtered were -$51.26/-$34.49 (filtered OOS PF 0.128,
  $34.49 max drawdown). **Reject shipping:** the retained positive
  outcome is concentrated in one winner and filtered OOS is negative
  under stress. `ship_recommend=false` makes `approve()` pass through.
  Nothing is connected to the bot. The snapshot does not establish future
  returns or executable fills.
- Added hermetic join, bucket, veto, fallback, cached-load, and <50ms
  inference tests. Full suite: **100 passed, 0 failed** with
  `.venv/bin/python -m pytest tests/ -q`. The bot was not restarted;
  `fomo_trader.py` and `runs/paper-1h/` were not edited.

## 2026-09-27 — round 4 loss forensics and dump re-entry safety
- **Snapshot:** first 69 journal closes, ending with BT at the displayed
  `2026-09-27 15:06:33` (EDT). The bot continued appending later closes while
  this review ran; they are outside this fixed snapshot. FIFO mint pairing and
  the existing `analysis/replay.py` cost model were reused. Local journal
  timestamps mix EDT and UTC; `deaths.log` shows launcher TZ changes. Replay
  now uses append order for chronological IS/OOS, since lexically sorting the
  local clock strings misorders Bukangi and SF #2. For duration math, the
  18:18:22 UTC SF #2 entry is 14:18:22 EDT, and its 14:23:59 EDT close is
  about 5m37s later. Its prior SF close was 14:05:13 EDT, so re-entry came
  about 13m09s later, not four hours. ARCHIBROWN's 2026-09-24 22:08:01 UTC
  entry to 2026-09-27 14:01:35 EDT close spans about 2d19h54m.
- The nine specified closes total **-$13.11** from unrounded journal native
  returns converted at recorded USD marks; the row-rounded values sum to
  **-$13.12**. The replay's additional fee/slippage estimates make those nine
  **-$14.31**. Causes below use row-rounded *journal* USD, so the operator's
  loss taxonomy is comparable:

  | Close | Signal gain | Entry to peak | Exit versus entry | Journal USD | Cause |
  | --- | ---: | ---: | ---: | ---: | --- |
  | ARCHIBROWN / SOL | 18.9% | +41.1% | -70.9% | -$5.18 | Legacy frozen bleed; 79.4% below peak |
  | 本命年十 / BSC | 257.4% | +8.6% | -22.1% | -$0.44 | Bought near top |
  | SF🐲 #1 / BSC | 103.0% | +36.0% | +5.0% | -$0.09 | Costs ate gross winner |
  | WOJ / BSC | 183.0% | +68.0% | +9.4% | -$0.12 | Costs ate gross winner |
  | 😂SC / BSC | 220.8% | +16.8% | -13.8% | -$0.89 | Bought near top |
  | Bukangi / BSC | 25.1% | +140.0% | +108.7% | +$5.24 | Winner, +50% TP rung fired |
  | SF🐲 #2 / BSC | 199.5% | +2.5% | ~-100% | -$6.99 | Venue dump to near zero |
  | STO / BSC | 224.4% | +9.4% | -27.0% | -$1.77 | Bought near top |
  | BT / BSC | 290.6% | +2.3% | -28.9% | -$2.88 | Bought near top |

- Cause totals from those rounded rows: bought near top **-$5.98**; venue rug
  **-$6.99**; legacy bleed **-$5.18**; two gross winners consumed by costs
  **-$0.21**; Bukangi **+$5.24**. BSC's 17 closes lose **-$40.51 costed**
  (-$2.38/trade), versus SOL's 52 at **-$78.16** (-$1.50/trade).
  The supplied claim of only two wins across 69 closes does not match the
  journal: 23 raw wins, 19 after estimated costs. Nor is every coarse bucket
  negative: the `<100%` signal-gain bucket is +$1.88 over 30 closes. These
  corrections do not establish a repeatable entry edge.
- **Validation split:** first 46 closes IS, last 23 OOS in journal close
  order. Metrics are `n / costed net USD / net win rate / profit factor /
  max USD drawdown`. Baseline IS **46 / -$71.88 / 37.0% / 0.318 / $75.63**;
  OOS **23 / -$46.80 / 8.7% / 0.173 / $49.07**. With 3x all modeled
  round-trip costs (swap fee, slippage and fixed transaction allowance),
  baseline net is -$120.31 IS and -$55.69 OOS. Filter edge means
  kept-set net USD/trade minus the same split's unfiltered net USD/trade;
  missing entry evidence passes through. Entry-filter replay does not model
  freed capacity or later opportunities.
- **Fix 1, shipped safety guard:** persist `dump_cooldown[mint]` at close for
  dump-detector or venue-dump exits. Both scan guardrails and commit guard
  reject that mint for 24 hours with `DUMP-COOLDOWN SKIP <name>`. Other close
  reasons do not arm it, and the existing 10-minute entry cooldown remains.
  Historical support is exactly one repeat, SF #2: its -$6.99 journal loss
  would have been vetoed had this guard existed. This is a safety tightening,
  not a statistically validated P&L edge. Logic, expiry, non-dump behavior,
  commit check and persisted state have hermetic tests.
- **Fix 2, tighter dump detector: rejected.** The counterfactual assumes a
  monotonic fall from each recorded *lifetime* peak through an exact
  `peak*(1-threshold)` fill on the remaining bag; it cannot observe the
  60-second rolling peak, gap, quote depth, liquidity or execution price.
  Current configured trigger remains 12%/60s. At 8%: IS **46 / -$56.70 /
  41.3% / 0.415 / $72.72**, OOS **23 / +$15.29 / 52.2% / 2.231 / $5.70**;
  per-trade edges +$0.330 / +$2.700 (819% retention); 3x-cost net
  -$105.28 / +$5.76. At 10%: IS **46 / -$58.52 / 41.3% / 0.399 /
  $72.86**, OOS **23 / +$12.27 / 47.8% / 1.895 / $5.70**; edges
  +$0.290 / +$2.568 (885%); 3x-cost net -$107.08 / +$2.77. IS-only
  choice is 8%, but its estimated OOS uplift comes $51.04 of $62.09 from
  BSC, while its IS uplift comes entirely from SOL ($15.17). The edge
  switches regimes and the exact fill assumption is especially fragile for
  the venue rug. Both stressed IS nets stay negative. Neither threshold
  passed the single-regime/3x-cost acceptance discipline; no exit threshold
  was wired.
- **Fix 3, gain caps: rejected.** Caps 150/200/250% kept IS respectively
  **32 / -$4.18**, **32 / -$4.18**, **33 / -$13.80**; IS per-trade edges
  +$1.432, +$1.432, +$1.144. Their OOS kept sets were **9 / -$20.91**,
  **13 / -$36.97**, **19 / -$46.17**, with edges -$0.289, -$0.809,
  -$0.396 (negative retention). OOS 3x-cost net: -$24.10, -$41.57,
  -$52.65. IS ties favor the smaller 150% kept set; all reverse OOS and
  remain negative under stress. The +437.1% winner `dap / SOL` was a regular
  15m GeckoTerminal signal (not early), SOL, ratio 3.1, liquidity $9,087;
  its peak reached +148% and its costed net was +$4.67. It would be cut by
  every candidate cap, illustrating the nonmonotonic signal relationship.
- **Fix 4, ratio floors: rejected.** Floors 2.0/2.5 kept IS **26 / -$57.43**
  and **17 / -$27.22** with per-trade edges -$0.647 and -$0.038. OOS kept
  **12 / -$27.57** and **10 / -$19.99**, edges -$0.263 and +$0.035;
  no positive IS edge exists to retain. OOS 3x-cost net -$31.97 and
  -$24.12. The 42 recorded sub-2.5 ratio entries include 12 costed wins,
  so the premise that this band had zero wins was also false.
- Pullback entry remains at 0% in paper config. Historical entry/peak/exit
  points cannot replay a pullback order or fill path. Round 3's
  `slip_from_signal_pct` field will allow later measurement on enriched
  entries. Full hermetic suite: **90 passed, 0 failed** via
  `.venv/bin/python -m pytest tests/ -q`. Paper `dry_run=true` and its code
  default remain unchanged. The bot was not restarted.

## 2026-09-27 — round 3 entry evidence for offline review
- Paper entry records and in-memory positions now retain the signal USD price
  (`priceUsd` from DexScreener or `base_token_price_usd` from GeckoTerminal),
  native commit price (the existing entry quote), USD commit price (entry
  multiplied by the existing SOL/USD or BNB/USD journal rate), and
  `slip_from_signal_pct` as the requested fractional change
  `(commit USD / signal USD) - 1`. Missing or unusable prices remain null.
- Both chains also record nonnegative signal-to-commit latency in milliseconds,
  15m buy and sell counts, 15m USD volume, market cap, and the previously
  journaled liquidity, all copied from the signal without fetching data.
  The DexScreener fallback uses its 5m window under the existing `m15_*`
  keys and records `window=5m` as before.
- Solana holder top 1 and top 5 percentages come from the already required
  `getTokenLargestAccounts` and `getTokenSupply` rug check. The guard's
  mint/freeze, concentration and fail-closed decisions are unchanged. BSC
  holder fields remain null because its existing honeypot quote check does
  not return holder accounts; no extra RPC call was added.
- The pool payload inspection checks the explicit `lp_burn_pct` and
  `lp_locked` fields in GeckoTerminal attributes and DexScreener pair data.
  The sampled payload shapes do not contain either field, so both remain
  null unless a future payload explicitly provides them. Liquidity is not
  treated as LP lock or burn evidence. No new API or entry fetch was added.
- Replay retains old entries unchanged and adds holder buckets `<10`,
  `10-25`, `25-40`, `>40` plus LP buckets `burned`, `locked`, `unknown`.
  All 67 historical closes have missing holder evidence and unknown LP
  evidence; these buckets support future review only.
- Field assembly measured 0.002174 ms per call over 100,000 hermetic calls
  in `test_entry_evidence_assembly_timing` on this workspace. This measures
  local arithmetic and dictionary creation,
  not network or disk timing. Persisting the evidence adds one local state
  save after the existing post-commit USD-rate lookup. Rejected commits do
  not make a USD-rate request. Full hermetic suite: 73 passed, 0 failed via
  `.venv/bin/python -m pytest tests/ -q`. Paper config and code default
  remain `dry_run=true`; the bot was not restarted.

## 2026-09-27 — round 2 entry-filter validation (no filters shipped)
- Reused `analysis/replay.py` and its cost model on all 67 closes, sorted by
  `close_ts`: first 45 IS, last 22 OOS. Three unmatched closes have no entry
  fields and pass through candidate filters. Metrics below are `n / net USD /
  win rate / profit factor / max USD drawdown`. Unfiltered IS: **45 / -$75.63 /
  35.6% / 0.282 / $75.63**; unfiltered OOS: **22 / -$38.24 / 13.6% /
  0.262 / $49.39**. With 3x estimated slippage, those baselines are
  -$77.75 IS and -$39.05 OOS.
- **Fix 1, pre-entry rug avoidance: rejected as untestable with the recorded
  entry fields.** The 18 rug-gap closes lost about $114.49 (10 IS, -$75.60;
  8 OOS, -$38.89). The existing SOL path checks mint/freeze authorities,
  largest-holder concentration and a sell route; BSC checks a buy/sell quote
  round trip. GeckoTerminal supplies pool liquidity, volume, transactions
  and price-change windows; DexScreener supplies pair liquidity, transactions
  and price-change windows. No journal entry records holder percentages,
  LP lock/burn evidence, signal price, or commit-time price. The optional
  pullback reference price is disabled in paper config. Therefore no
  entry-time veto set, filtered IS/OOS metrics, edge retention, or stress
  result can be established for a dump or tighter-holder screen. The IS/OOS
  baselines above remain the only measurable results for this fix. No screen
  was wired and no LP evidence was assumed.
- **Fix 2, liquidity cap: rejected.** IS-only comparison of veto thresholds
  found $40k strongest: IS filtered **36 / -$29.60 / 41.7% / 0.493 /
  $33.86**, vetoing 8 losers and 1 winner (vetoed net -$46.03). OOS filtered
  **8 / -$7.79 / 25.0% / 0.519 / $15.61**, vetoing 13 losers and 1 winner
  (vetoed net -$30.45). Its per-trade edge was +$0.859 IS and +$0.764 OOS,
  retaining 89.0%. However, the OOS retained sample is only 8 trades, its
  2 winners are both on Solana, and its 3x-slippage OOS net remains -$8.10
  (PF 0.506, drawdown $15.76; baseline -$39.05). This is inconclusive and
  fails the stress bar. At 3x slippage, filtered IS net is -$31.39 (PF 0.471,
  drawdown $35.25). The >$50k candidate retained only 14.6% of its IS
  per-trade edge on OOS (+$0.598 vs +$0.087). The SOL-only >$50k candidate
  reversed on OOS (+$0.598 vs -$0.030); BSC-only had zero IS vetoes, so it
  could not be tuned on IS. No liquidity cap was wired.
- **Fix 3, signal-gain cap: rejected.** IS-only selection favored 350%:
  IS filtered **34 / -$17.26 / 47.1% / 0.633 / $17.94**, vetoing 11 losers
  and no winners (vetoed net -$58.37). OOS filtered **20 / -$41.10 / 10.0% /
  0.178 / $49.97**, vetoing 1 loser and 1 winner (vetoed net +$2.85).
  Per-trade edge reversed from +$1.173 IS to -$0.317 OOS (-27.0% retained).
  At 3x slippage, filtered OOS net was -$41.82 (PF 0.173, drawdown $50.57)
  versus -$39.05 unfiltered; filtered IS net was -$18.97 (PF 0.603,
  drawdown $19.06). The 400% and 300% candidates also had -$0.317
  OOS per-trade edge. No gain cap was wired.
- No entry, risk, rug-guard, or config behavior changed. The rejected filters
  are offline counterfactuals: skipping entries would also change capacity
  and later trade opportunities, which this journal cannot replay.
- Full hermetic suite: 52 passed, 0 failed via
  `.venv/bin/python -m pytest tests/ -q`. Paper config and code default
  remain `dry_run=true`; the bot was not restarted.

## 2026-09-27 — offline profitability replay and signal-model validation
- Added `analysis/replay.py`: FIFO mint pairing of 64 entries and 67 closes
  (3 closes have no entry record), parsing of 599 FOMO/PRE-PUMP log signals,
  per-trade paper P&L, cost stress, attribution, and an explicitly approximate
  counterfactual exit calculator. Recorded peak/exit cannot reveal intratrade
  path, executable rung timing, quote depth, or gap fills. No HTTP is used.
- Costs are **additional estimates** on top of paper journal returns: 0.25%
  swap fee and 0.15% slippage per leg, 0.002 SOL priority-fee cap per leg
  from paper config, or 0.00002 BNB gas per leg. Stress triples slippage.
  USD marks use recorded close prices except 24 early SOL closes with no
  quote, for which a disclosed $115/SOL approximation is used. Aggregate
  native balances are kept separate by chain; PF and drawdown use USD.
- Costed baseline: 67 closes, -0.676571 SOL and -0.045862 BNB, about
  -$113.87 total; win rate 28.36%, profit factor 0.276, max USD drawdown
  $118.99. Rug-gap exits (exit over 60% below peak): 18, about -$114.49.
  Liquidity above $50k: 19 trades, one win, about -$56.78. Signal gain above
  400%: 11 trades, one win, about -$45.85. These buckets overlap.
- Added pure-stdlib L2 logistic training/scoring and serialized
  `analysis/signal_model.json`. Features are seven recorded entry fields or
  transforms; absent 15m volume is not invented. Labels use net P&L after
  modeled costs. A time-ordered 43/21 IS/OOS split tuned threshold 0.41 on
  IS only. IS unfiltered: 43 trades, -$69.82, 34.9% wins, PF 0.317,
  max DD $75.19; filtered: 13 trades, +$11.92, 69.2% wins, PF 2.569,
  max DD $6.72. OOS unfiltered: 21 trades, -$41.99, 9.5% wins,
  PF 0.189, max DD $44.27; filtered: 15 trades, -$29.61, 6.7% wins,
  PF 0.147, max DD $29.61. The OOS per-trade improvement of $0.026 is
  below 60% of the IS $2.540 improvement, retained winners concentrate in
  one regime, and filtered OOS remains negative under 3x slippage (-$30.16).
  **The filter did not validate and was not wired into entries or config.**
  The model artifact is for offline review only; no result establishes
  future returns or executable fills.
- Added hermetic replay/model tests. Full suite: 52 passed, 0 failed via
  `.venv/bin/python -m pytest tests/ -q`. Paper config remains `dry_run=true`;
  entry guards, position caps, kill switch, and rug checks were not changed.

## 2026-09-27 — entry signal freshness re-validation at commit
- Gap: entry work can take minutes after a scanner detects a pump. The
  commit guard rechecked trade caps and the kill switch, but could still
  enter after the pool's gain or liquidity had faded.
- Fix: SOL and BSC GeckoTerminal FOMO signals, GeckoTerminal early signals,
  and DexScreener fallback signals now carry a scan timestamp. At commit,
  signals older than `hunter.entry.signal_max_age_sec` get one rate-limited
  fetch of the same pool. The entry proceeds only if gain, liquidity, and
  buy/sell ratio still meet that scanner path's bars. Missing timestamps,
  invalid pool data, and fetch failures skip with `STALE SIGNAL SKIP`.
  Fresh signals add no HTTP request. DexScreener fallback uses its 5m gain
  bar because that feed has no 15m bucket.
- Config: `hunter.entry.signal_max_age_sec: 180` in the example and paper
  config; missing or invalid values fall back to 180 seconds. Paper config
  remains `dry_run=true`.
- Tests: full suite 85 passed, 0 failed (operator re-ran: 85/0, hermetic);
  HTTP blocked throughout and zero real requests made.
- Restart: bot relaunched 2026-09-27 14:13 EDT, pid 9869 -> 12010,
  dry_run=true, config unchanged apart from the new key.

## 2026-09-27 — kill switch re-checked at entry commit (mid-flight race fix)
- Gap: `guardrails_ok()` runs at signal time, but an entry then spends
  minutes in flight (rug screens, pullback waits, decimals lookups, entry
  quotes, honeypot checks). Meanwhile another manage thread can close a
  losing position and trip the daily-loss kill switch - and the in-flight
  entry would still commit, entering a trade AFTER the guardrail fired.
- Fix: new `_entry_commit_ok()` helper, called under the lock at commit
  time in both `enter()` (SOL) and `enter_bsc()` (BSC). It re-checks the
  daily/hourly trade caps (moved verbatim out of the inline commit blocks)
  AND `_kill_switch_tripped()`; on refusal it discards the pending-entry
  slot and logs the reason. No other entry logic changed; the pre-entry
  scan-time checks are untouched.
- Tests: 3 new cases (kill switch tripped mid-flight blocks, daily and
  hourly caps still block at commit, clear path still allows). Full suite:
  74 passed, 0 failed; no HTTP requests made.
- Config: untouched (dry_run=true intact); halt.flag, trades.jsonl,
  state.json, bot.log, keypair.json untouched.

## 2026-09-27 — daily-loss protect mode for open positions
- When either configured daily USD or SOL loss cap trips, existing positions
  enter persistent PROTECT MODE and use at most a 10% trailing stop. The
  tighter trail composes with post-TP and moonbag trails; invalid settings
  fall back to 10%. Protection stays on through the next daily reset.
- This limits further drawdown on open positions after the entry kill switch
  trips. Price gaps and unavailable quotes can still produce larger losses.
- Manage-cycle tests cover USD and SOL cap parity with entry guardrails,
  normal versus protected exits, post-TP and moonbag composition, persistence,
  and invalid trail settings.
- Config: `risk.kill_switch_protect_trail_pct: 10` added to
  `runs/paper-1h/config.json` and `config.example.json`; dry_run=true
  intact. Run verification (2026-09-27 ~08:15 EDT): the Codex session hit
  its usage limit right after the code edit, so the assistant reviewed the
  diff, fixed 7 test assertions (they expected the bare "trail-10%" label,
  but sell_pct_of_balance wraps labels as "SELL <name> (trail-10%)" —
  product behavior was correct), and re-ran the full suite: 70 passed,
  0 failed. halt.flag, trades.jsonl, state.json, bot.log, keypair.json
  untouched.

## 2026-09-27 — halt responsiveness and conservative entry guards
- **Halt flag:** check immediately after SIGTERM at the start of every main
  loop and during each 0.5s poll wait. A flag appearing mid-wait now exits
  with code 42 promptly; the startup check retains its existing behavior.
- **Solana rug guard:** reject truncated mint account data, zero supply, and
  empty largest-holder results. Those responses cannot establish disabled
  authorities or holder concentration, so an entry must fail closed.
- **Daily loss limits:** enforce the SOL cap even when a USD cap is also
  configured. Previously the USD branch skipped the SOL limit entirely;
  crossing either configured limit now blocks new entries.
- **Hermetic tests:** stub BNB/USD in the BSC entry test and block HTTP for
  the whole test suite. This prevents a paper test from fetching live data.

## v2 — 2026-09-24 (polish for live-money confidence)
- **Virtual token ledger (dry_run):** paper sells now simulate real swaps.
  Entry stores the quoted token amount; each rung sell quotes mint→SOL and
  decrements the virtual bag; realized P&L = simulated proceeds − stake.
  Previously rung sells were no-ops against the real (empty) wallet and P&L
  was price-math. Old positions (opened before this) still close on the
  legacy price-math path.
- **exit.mode: "ladder" | "moonbag"** (default ladder). Moonbag banks 50% at
  +100% and lets the rest ride with a 50% trailing stop, no TP ceiling.
  One-word flip in config; ladder stays live until paper data says otherwise.
- **Manage threads can no longer die silently:** the per-position loop body
  moved to `_manage_once()` wrapped in try/except with full tracebacks.
- **Heartbeat** every 30 min (open count, realized SOL, uptime) — silence in
  the log now means death, not quiet markets.
- **Watchdog cron** every 15 min restarts the bot if the pidfile process is
  gone (2026-09-24: bot died silently ~08:04 during a proxy blip, no
  traceback; positions unmanaged for ~1h until manual restart).
- **Daily analysis cron** (~07:00 ET): scores the journal against the
  confidence bar and proposes at most one evidence-backed tweak.

## v1 — 2026-09-24 (baseline)
- Hunter: GeckoTerminal (15 pages, token bucket ≤20/min) + DexScreener
  fallback; FOMO filter 100%+/15m, buys/sells ≥10, ≥50 buys, liq ≥$15k,
  15m vol ≥$5k. Rug guard (mint/freeze authority, holder concentration,
  honeypot quote) fail-closed on every entry.
- Exits: TP ladder 50% @+100%, 25% @+200%; trailing −30% from peak;
  hard stop −40% from entry. 5s manage poll per position.
- Guardrails: max 3 positions, 10 trades/day, 2h cooldown/mint,
  0.2 SOL daily-loss kill switch, halt.flag exits 42 (never auto-restarted).
- First paper round trip 07:58: miao coin trailing stop −39.3% from peak,
  realized −0.023 SOL. MultiChain exited 08:00: +0.024 SOL (trailing stop).

## v1.1 — 2026-09-24 (rug autopsy: GP / SOL)
- **What happened:** 08:03:24 paper-bought GP / SOL on a +131.2%/15m signal
  (buy/sell 3.4, liq ~$30k; honeypot check passed at entry). The bot process
  died silently at 08:04:24 (proxy blip, no traceback) and the position sat
  **unmanaged for ~60 minutes** while the token collapsed. On manual restart
  at 09:04 the manager sold immediately at −98.9% from peak, realizing
  −0.085894 SOL. With the bot alive, the −30% trailing stop would have fired
  for roughly −0.03 SOL — the outage tripled the loss.
- **Lesson:** a rug that collapses faster than the recovery loop can respond
  is the worst case. The entry guard (honeypot quote at entry) passed — a
  token can be sellable at entry and still go to zero an hour later. No
  entry-time check can fully prevent this; survival depends on (a) the bot
  never being unmanaged and (b) exits firing the moment price data returns.
- **Fixes applied:**
  - Watchdog (15 min) + log-staleness check already in place; worst-case
    unmanaged window is now ~15 min, not 60.
  - Entry quote failures (e.g. Jupiter 400s like the Felis signals) now log
    one clean SKIP line instead of a full traceback — entry still fails
    closed, but the log stays readable.
- **Implication for live-money confidence:** this is exactly why the 30-trade
  paper bar exists. The strategy's designed worst case per trade is the
  −40% hard stop; the realized −98.9% came from an infrastructure outage,
  not the strategy. Both must be proven before real money.

## v1.2 — 2026-09-24 (stale exit / position rotation)
- User directive: don't babysit dead positions; free the slot for fresh
  signals. New `exit.stale_exit_min` (45) + `exit.stale_exit_max_gain_pct`
  (10): a position older than 45 min and up less than +10% is sold in full
  ("stale exit"), freeing one of the 3 slots. Positions in real profit are
  untouched (trailing stop still guards them). Unit-checked on 4 cases.
- Stale exit tightened 45 -> 15 min per user ("it can be quicker than that").
  One full 15m signal window with no real move = momentum's gone, free the slot.
- Stale exit set to 30 min — middle ground between 45 and 15 per user.
- 2026-09-24 ~10:24: user-requested reset of the daily-loss kill switch
  (state.realized_sol -0.354 -> 0.0, clean stop + restart, pid 9498).
  Trade journal (trades.jsonl) untouched, so analyzer history is intact.

## v1.3 — 2026-09-24 (data-driven risk tightening, 19-trade review)
Diagnosis from 19 closed trades: 7 wins (+0.212 SOL) vs 12 losses (-0.567).
Two structural findings: (1) TP rung at +100% fired only 2/19 times — 6
winners peaked +40-88% and were trailed out before banking; (2) six
gap-down/rug events (-0.065 to -0.086 each) blew straight through the
trailing stop, exiting -83% to -99% from peak — no stop setting can
execute through a liquidity vacuum. Plus a real bug: 2 non-SOL entries
(Claude/ANTHRP, USDC/USDC) leaked through GeckoTerminal, costing -0.10.
Changes:
- Strict SOL-pair enforcement in BOTH feeds (GT quote_token relationship
  + pool-name fallback; DexScreener quoteToken address). Non-SOL quotes
  are now rejected at scan time.
- First TP rung +100% -> +60% (6 of 8 winners peaked above +60%).
- Trailing stop 30% -> 25%, hard stop 40% -> 35% (gradual fades cluster
  at -31% to -42% from peak; tighter keeps more of winners too).
- Entry bar raised: min 15m gain 10% -> 20%, min liquidity $3k -> $8k
  (weakest entries never ran; thin books gap harder).
- Position size 0.087 -> 0.06 SOL: the 0.2 SOL kill switch now needs 3+
  full-stake rug losses to trip instead of ~2.5.
- All values kept inside the auto-tuner's allowlist bounds so the daily
  self-improvement loop can continue from here.
Honest limit: nothing here prevents gap-rug losses; it only makes them
smaller and less frequent. Expectancy is still unproven at 19 trades.

## v1.4 — 2026-09-24 (USD P&L reporting)
- Per user request: P&L analysis now in dollars. Bot stamps `sol_usd`
  (Jupiter price API, 120s cache, fail-soft) on every entry and close
  journal record. analyze.py shows $ next to every SOL figure, using each
  trade's own stamped price with --sol-usd as fallback for older records.
  Close log lines now include the $ amount. Daily cron fetches SOL/USD and
  passes --sol-usd so reports always carry dollars.

## 2026-09-24 11:51 EDT - TP rung marked only on real fills (manual fix)
- Bug: a take-profit rung was marked "fired" even when the sell failed or
  returned dust. CTNT / SOL's +60% rung "fired" at a +120.9% feed print while
  the Jupiter fill for the actual size was 3.3555e-05 SOL (phantom depth on a
  thin pool) - the rung was recorded as a +120% take-profit.
- sell_pct_of_balance now returns (sig, proceeds_sol); the TP loop marks a
  rung ONLY when the sell succeeds, records the realized gain on the sold
  slice (not the feed gain), stores proceeds in the rung record, and logs a
  PRICE-IMPACT WARNING when the fill is <25% of the feed-implied value.
  Failed sells are retried next cycle instead of silently skipped.
- Corrected the live CTNT rung record to its honest -99.89% realized value.

## 2026-09-24 14:15 EDT - Dump detector: instant exits on violent drops (manual fix)
- New anti-rug reflex in the manage loop: if a position falls 12% or more
  from its max price within 60 seconds, the bot sells everything immediately
  instead of waiting for the 25% trailing stop. Rationale: today's exits kept
  printing "-80% to -99% from peak" - by the time the wide trail triggered,
  the liquidity was gone. The detector reacts to drop VELOCITY, so slow
  bleeds still use the normal trail/stale exits.
- Config: exit.dump_drop_pct=12, exit.dump_window_sec=60 (tunable).
- Per-mint in-memory price history (deque, 300 samples); cleared on close.

## 2026-09-24 14:20 EDT - Silent-death forensics (manual fix)
- Root-cause investigation found the bot is NOT crashing in Python: the
  pidfile survives every death, and Trader.run's try/finally always removes
  the pidfile on any interpreter-level exit. Verdict: external SIGKILL or a
  native segfault. Some "deaths" today were deliberate agent restarts.
- Added faulthandler.enable() at main() start so a native crash dumps a
  stack trace into bot.log instead of vanishing.
- New run_bot.sh wrapper: stays alive as the bot's parent, waits on it, and
  records the exit code in runs/paper-1h/deaths.log (137=SIGKILL,
  139=segfault, 143=SIGTERM). Next death identifies itself.
- Watchdog cron now restarts through run_bot.sh; bot relaunched under it.

## 2026-09-24 14:26 EDT - Fixed NameError that disabled ALL exits (watchdog-caught)
- The dump-detector edit referenced `ex` (exit config) inside
  _manage_once(), where it was not in scope. Every manage cycle raised
  NameError, the manage thread swallowed it, and no exit (TP, trail, hard
  stop, stale, dump) could fire for ~10 minutes. Caught by the watchdog's
  log scan. Fix: `ex = self.cfg["exit"]` at the top of _manage_once().
- Lesson: any edit touching the exit path gets a manage-cycle smoke test
  before the bot is considered healthy.
