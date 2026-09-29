# Lane 3 — Structural diagnosis of FOMO Trader

**Verdict: no supportable structural change to ship from this journal.** The observed scanner-entry strategy loses before estimated costs, after costs, and after excluding the primary wipe cohort. There is one structural research hypothesis worth testing: require persistence across existing scanner observations before committing. The present journal cannot validate it.

No files, configuration, or bot behavior were changed.

## 1. Fresh accounting

Snapshot: **323 lines, 160 entries, 163 closes**.

SHA-256: `ed4391fec4200661351164b99431f33be27ed35a0d6773f23f0987707a87be6b`

FIFO pairing by `(chain, mint)`, inferring missing chain from mint format, yields **160 pairs, three unmatched closes, and no open entries**. There are two backward timestamp transitions. All sequence analysis below uses **close append order**, never timestamp sorting.

### Accounting conventions

Raw P&L uses recorded realized native P&L converted at the close’s recorded USD rate, then entry rate, with the established $115/SOL fallback for early Solana. BSC stake sometimes uses the field name `buy_sol`.

Following Lane 2’s replay convention:

`costed P&L = raw P&L − rate × [stake × (1 + exit/entry) × (0.0025 + slippage) + fixed]`

- Base slippage: 0.15% per leg; stress: 0.45%.
- Fixed round-trip cost: 0.004 SOL or 0.00004 BNB.
- These are paper cost estimates. Terminal-price-based costs do not reconstruct actual partial-exit cash flows.

The **primary wipe proxy** remains realized native loss ≥85% of stake **and** a dump-detector or venue-dump reason. It identifies catastrophic recorded outcomes, not independently verified LP removals.

| Cohort | Count | Raw P&L | Base costed | Stress costed |
|---|---:|---:|---:|---:|
| All closes | 163 | −$187.20 | −$222.61 | −$228.48 |
| FIFO pairs | 160 | −$186.77 | −$220.55 | −$226.25 |
| Unmatched closes | 3 | −$0.44 | −$2.06 | −$2.23 |
| Paired Solana | 49 | −$50.39 | −$76.10 | −$78.32 |
| Paired BSC | 111 | −$136.38 | −$144.45 | −$147.92 |
| Primary wipes | 18 | −$98.42 | −$99.38 | −$99.68 |
| Paired non-wipes | 142 | −$88.35 | −$121.17 | −$126.57 |

The 18 wipes comprise **nine dump-detector and nine venue-dump closes**, all BSC. They account for:

- **45.06%** of paired costed net loss.
- **44.64%** of all-close costed net loss.
- **68.80%** of paired BSC costed net loss.

The broader terminal-quote proxy, `exit/entry ≤1%`, identifies **25 paired closes losing $103.12**. Only 16 overlap the primary wipe definition. Partial exits make terminal quote collapse and realized near-total loss different events.

### Exit-family attribution

Families are mutually exclusive: primary wipes are removed from ordinary dump and venue rows. WR, PF, average win and average loss use base-costed dollars. Average loss is shown as a positive magnitude; PF is gross wins divided by gross losses.

| Family | n | Raw P&L | Costed P&L | WR | PF | Avg win | Avg loss | Expectancy/trade |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Primary wipe | 18 | −$98.42 | −$99.38 | 0% | 0 | — | $5.521 | −$5.521 |
| Dump detector, non-wipe | 93 | −$29.04 | −$42.51 | 29.03% | 0.517 | $1.684 | $1.333 | −$0.457 |
| Trailing stop | 31 | −$58.13 | −$71.59 | 29.03% | 0.280 | $3.086 | $4.517 | −$2.309 |
| Venue dump, non-wipe | 9 | −$6.77 | −$7.84 | 0% | 0 | — | $0.871 | −$0.871 |
| Stale | 5 | −$0.49 | −$3.16 | 20% | 0.031 | $0.101 | $0.815 | −$0.632 |
| Manual rotation | 3 | +$2.52 | +$0.91 | 100% | — | $0.302 | — | +$0.302 |
| Terminal take profit | 1 | +$3.56 | +$3.02 | 100% | — | $3.022 | — | +$3.022 |
| **Overall** | **160** | **−$186.77** | **−$220.55** | **25.63%** | **0.259** | **$1.885** | **$2.503** | **−$1.378** |

There are no separately labelled hard-stop closes. A terminal exit reason does not identify whether partial TP occurred earlier.

### Critical strategy-version limitation

The supplied strategy description is not the current on-disk paper configuration. Read-only inspection found:

| Setting | Supplied description | Current paper config |
|---|---|---|
| TP ladder | 50% at +100%; 25% at +200% | 50% at +50% |
| Trailing / hard stop | 30% / 40% | 25% / 35% |
| Management poll | 5 seconds | 2 seconds |
| Hunter gain / buys / liquidity | 100% / uncertain / $15k | 20% / 10 / $8k |
| Daily trade cap / loss cap | 10 / $23 | 30 / $60 |
| Mint cooldown | 2 hours | 10 minutes |

The current file does not prove which settings governed every historical trade. The journal also contains changing rung outcomes and entry thresholds.

**This is evidence about the observed historical strategy mixture, not a controlled evaluation of the described +100%/+200% ladder.** No configuration changes are proposed here.

## 2. Regime diagnosis

### Expectancy fails outside wipes too

For each regime:

`E = win probability × average win − loss probability × average loss`

The following calculations use rounded displayed inputs.

| Regime | n | WR | PF | Expectancy calculation |
|---|---:|---:|---:|---|
| Overall | 160 | 25.63% | 0.259 | `0.2563×1.885 − 0.7437×2.503 ≈ −$1.378` |
| Solana | 49 | 32.65% | 0.327 | `0.3265×2.314 − 0.6735×3.428 ≈ −$1.553` |
| BSC | 111 | 22.52% | 0.218 | `0.2252×1.611 − 0.7748×2.148 ≈ −$1.301` |
| All non-wipes | 142 | 28.87% | 0.389 | `0.2887×1.885 − 0.7113×1.965 ≈ −$0.853` |
| BSC non-wipes | 93 | 26.88% | 0.472 | `0.2688×1.611 − 0.7312×1.255 ≈ −$0.485` |
| Wipes | 18 | 0% | 0 | `0 − 1×5.521 = −$5.521` |

BSC ordinary losses are smaller than ordinary wins, but winners occur too infrequently. Solana combines an inadequate win rate with larger average losses than wins.

**Even perfect retrospective removal of the primary wipes leaves a $121.17 costed loss.** That is an accounting decomposition, not an achievable pre-entry filter.

### Append-order split

First 106 closes form the earlier cohort; the boundary is journal line 215. The remaining 54 form the later cohort. No pair crosses this boundary.

These are descriptive IS/OOS labels, **not a fresh untouched holdout** after prior exploration.

| Regime | n | Chain composition | Costed P&L | Stress | WR | Avg win/loss | Expectancy |
|---|---:|---|---:|---:|---:|---:|---:|
| Earlier | 106 | 49 SOL / 57 BSC | −$163.77 | −$168.06 | 22.64% | $2.491 / $2.726 | −$1.545 |
| Later | 54 | All BSC | −$56.78 | −$58.19 | 31.48% | $1.030 / $2.008 | −$1.052 |
| Earlier non-wipe | 98 | Mixed | −$109.66 | −$113.79 | 24.49% | $2.491 / $2.290 | −$1.119 |
| Later non-wipe | 44 | All BSC | −$11.51 | −$12.78 | 38.64% | $1.030 / $1.075 | −$0.262 |

Later non-wipe expectancy improves, but remains negative:

`0.3864×$1.030 − 0.6136×$1.075 ≈ −$0.262/trade`.

Ten later wipes contribute **−$45.27** of the later cohort’s **−$56.78**. Wipes dominate the recent losses; they do not fully explain them.

### Where ordinary losses arise

**Older Solana trailing exits dominate the non-wipe dollar leak.**

- 25 Solana trailing closes lose **$74.70**.
- WR: **16%**; average win/loss: **$4.903/$4.491**.
- Expectancy: `0.16×4.903 − 0.84×4.491 ≈ −$2.988`.
- Only seven recorded a peak at least 50% above entry.
- Their median recorded holding interval is approximately **3.12 minutes**.

This does not look primarily like slow stale-position attrition. It is rapid failure or reversal after entry. The journal cannot price a tighter-trail counterfactual.

**BSC non-wipe dump exits are the main recent ordinary-loss mechanism.**

- 79 closes lose **$40.93**.
- WR **25.32%**, PF **0.440**.
- Expectancy: `0.2532×1.605 − 0.7468×1.238 ≈ −$0.518`.
- Only 17 recorded peaks ≥50%; 24 recorded peaks below +10%.
- Recorded median holding interval is approximately **0.82 minutes**, but one interval is negative because of timestamp discontinuity.

Many failures occur before substantial continuation. This implicates entry quality or immediate execution/price-path conditions more directly than a late stale exit.

**Stale exits are secondary:** five older Solana trades lose **$3.16**, versus $71.59 from trailing exits. Their recorded peaks range from 0% to approximately +30%.

Six BSC trailing exits instead make **$3.10**, but that small, selected terminal-reason cohort is not evidence for a trailing-stop entry rule.

### Sequence clustering

Twenty-pair blocks show a transition in failure mode. Dump counts below exclude primary wipes.

| Pair sequence | Chain composition | Costed P&L | Wipes | Non-wipe dump exits |
|---|---|---:|---:|---:|
| 1–20 | SOL | −$56.30 | 0 | 0 |
| 21–40 | SOL | −$15.44 | 0 | 9 |
| 41–60 | 9 SOL / 11 BSC | −$36.97 | 3 | 13 |
| 61–80 | BSC | −$15.24 | 1 | 16 |
| 81–100 | BSC | −$23.69 | 2 | 16 |
| 101–120 | BSC | −$24.72 | 5 | 12 |
| 121–140 | BSC | −$24.36 | 2 | 16 |
| 141–160 | BSC | −$23.83 | 5 | 11 |

Every block loses. Wipes concentrate in some blocks, including five each in blocks 101–120 and 141–160. Ordinary dump exits remain frequent throughout the BSC sequence.

This supports regime dependence, but does not establish that a particular cooldown following a wipe would avoid the next loss.

### Source and window

All paired entries are `geckoterminal`; **source superiority cannot be tested**.

| Window | n | Costed P&L | WR | PF | Wipes |
|---|---:|---:|---:|---:|---:|
| 15m | 146 | −$175.60 | 27.40% | 0.302 | 12 |
| 5m | 14 | −$44.95 | 7.14% | 0.026 | 6 |

The 5m cohort loses in both periods: **−$22.72 across six earlier trades**, and **−$22.23 across eight later trades**. It is concerning, but too small to establish a robust window-specific change. Removing it would still leave the 15m strategy losing substantially.

### Signal decay: consistent with exhaustion, not proof of buying the final leg

| Signal gain | n | Costed P&L | WR | PF | Mean raw stake return |
|---|---:|---:|---:|---:|---:|
| <100% | 60 | −$22.71 | 41.67% | 0.738 | −4.76% |
| 100–200% | 49 | −$89.03 | 22.45% | 0.071 | −28.00% |
| >200–500% | 41 | −$58.72 | 12.20% | 0.101 | −18.10% |
| >500% | 10 | −$50.09 | 0% | 0 | −56.31% |

Across windows, the **100 entries with gain ≥100% lose $197.84**, with **16% WR**, average win **$0.838**, and average loss **$2.515**:

`0.16×0.838 − 0.84×2.515 ≈ −$1.978/trade`.

The relationship is not a clean monotonic threshold effect. Pearson correlation between signal gain and raw stake return is **−0.449 for Solana**, but only **−0.047 for BSC**. Extreme values and regime changes limit interpretation.

Enriched signal-to-commit drift is available on **93 pairs, all BSC**:

| Drift sign | n | Share of covered entries | Costed P&L | WR |
|---|---:|---:|---:|---:|
| Negative | 48 | 51.61% | −$5.66 | 37.50% |
| Positive | 45 | 48.39% | −$97.31 | 13.33% |
| Zero | 0 | 0% | — | — |

The drift field is a fraction: `0.10` means +10%. This association is already addressed by the shipped size cap; neither drift veto nor another drift cap is proposed.

**Volume trajectory is unavailable.** The 93 covered entries contain one `m15_volume_usd` snapshot each, not successive observations. Median volume is $16,310.50 for 14 enriched wipes and $28,969 for 79 enriched non-wipes. Those levels cannot establish acceleration, exhaustion, or wash activity.

### Sizing: no observed 1–3× cohort

Allocator multiplier and score are recorded on **60 pairs**. Multipliers range from **0.522172 to 0.997954**. There are **no recorded multipliers above 1×**, so the purported 1–3× amplification cannot be evaluated.

A descriptive median split—not a proposed threshold—gives:

| Multiplier half | n | Mean ticket | Costed P&L | WR | Mean raw return | Wipes |
|---|---:|---:|---:|---:|---:|---:|
| Lower | 30 | $4.25 | −$37.95 | 26.67% | −29.48% | 8 |
| Upper | 30 | $5.97 | −$29.17 | 33.33% | −16.27% | 3 |

Multiplier/raw-return correlation is **+0.285**. Larger observed multipliers have better outcomes descriptively, although both halves lose. This contradicts a simple claim that larger tickets identify worse trades.

Allocation, balance changes, sequence and market conditions are confounded. These observations justify neither increasing size nor declaring the allocator causally effective.

## 3. Ranked structural hypothesis

### 1. Persistence confirmation before scanner entry — research only

**Mechanism:** a rolling percentage-gain threshold identifies movement that already happened. A single qualifying observation does not establish continuing demand. Requiring persistence across existing scans could reject transient scanner appearances and rapidly failing momentum.

**Journal evidence:**

- Gain ≥100% entries: **100 trades, −$197.84, 16% WR**.
- BSC ordinary dump exits: **79 trades, −$40.93**.
- Twenty-four of those dump exits record peaks below +10%.
- Wipe removal alone leaves **−$121.17**.

These observations motivate the mechanism; they do not validate the proposed intervention.

**Concrete implementable candidate:** in the hunter-to-entry handoff, maintain deterministic pending state keyed by `(chain, mint, window)`. Require two consecutive appearances satisfying the existing entry screens before allowing the normal entry path. Use only existing scan results and local state. The second observation must independently pass all current guards, freshness checks, caps and allocation rules. Do not reserve a slot or enlarge a ticket.

Freeze the two-observation rule before evaluation; do not search confirmation counts or add a gain threshold.

**Falsifiable prediction:** an append-order replay containing successive scanner observations must show that confirmation reduces **non-wipe** loss per original opportunity under base and stressed costs, after accounting for the later entry price and missed winners. Improvement must persist across later sequence blocks, and retained OOS P&L must be positive.

Fail the hypothesis if:

- Savings come only from reduced participation while retained expectancy stays negative.
- Later entry erases the benefit.
- Improvement depends on one wipe cluster.
- Replay lacks observed confirmation-time prices.

**Status: untestable from this journal.** It contains committed entries, not the full candidate stream or second-observation entry prices. No delayed fill, saved loss, or replacement trade is credited.

## 4. What is ruled out

### A wipe-only explanation

Rejected as a complete diagnosis. Primary non-wipes lose **$121.17** overall and **$11.51** in the later cohort. Wipe mitigation is useful risk reduction, but does not establish momentum edge.

### Fewer or later TP rungs

Unsupported and potentially increases exposure to reversals.

- **34 trades with one recorded rung:** +$45.67 costed.
- **126 without a rung:** −$266.22.
- No trade records two fired rungs.
- Only **14/160** recorded peaks reach +100%; those trades contribute +$42.28.

Rung occurrence is an outcome, not an entry feature. These cohorts cannot establish causality, but they provide no basis for postponing profit realization.

Recorded rung gains also include negative values, including −99.89%; a fired rung is not proof of a fill at its configured trigger.

### A tighter trailing stop or earlier time-stop as a demonstrated fix

Not identifiable from terminal records. Peak and exit do not reveal the executable price at an earlier threshold crossing.

The largest trailing loss cohort exits in roughly three minutes; BSC ordinary dumps often close within a minute. Five stale trades explain only **$3.16** of loss. A broad time-stop could sacrifice winners without reaching the dominant failures first.

No synthetic fills at stop thresholds are assumed.

### A validated “bigger allocation causes worse outcomes” claim

Rejected. The upper observed multiplier half has **33.33% WR versus 26.67%**, and a less negative mean raw return. Both halves lose; none of the covered trades tests >1× sizing.

### Switching chains or windows as a proven solution

Unsupported:

- Solana loses **$76.10**; BSC loses **$144.45**.
- Later evaluation is entirely BSC.
- The 5m cohort has only 14 trades.
- The 15m cohort still loses **$175.60**.

Solana’s <100% gain cohort makes **$7.35 across 26 trades**, but it is older, small and has no later Solana holdout. It does not justify lowering entry thresholds.

### Previously rejected screens and shipped drift work

Not retested or re-proposed:

- Signal-gain veto >200%.
- $30k liquidity floor: prior base edge retention **25.8%**.
- Imbalance/buy-count floors: prior retained OOS **five trades**, still losing.
- Holder concentration: **zero non-null holder/LP coverage** in this fresh paired sample.
- Tighter venue-m5 tripwire: no earlier executable crossing prices.
- Drift veto: previously rejected.
- Drift size cap: already shipped; CHANGELOG records **111.1% base edge retention**.

The fresh snapshot has **zero entries carrying `wipe_drift_cap`**, so it is not a prospective evaluation of the shipped cap.

## 5. Final verdict

**No supportable structural change.**

The observed historical scanner strategy has negative expectancy:

- **−$186.77 before estimated costs.**
- **−$220.55 after base costs.**
- **−$121.17 after excluding primary wipes.**
- **All eight consecutive 20-trade blocks lose.**

The core continuation assumption is not supported by these outcomes. However, strategy-version changes, older Solana data, missing candidate histories and absent executable price paths prevent attributing that failure to one precise entry or management rule.

Persistence confirmation is a falsifiable research direction. It is **not a validated recommendation to ship**.
