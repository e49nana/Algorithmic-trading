# ASQ Safe Scalping v1.11
### AlgoSphere Quant | https://www.mql5.com/en/users/robin2.0

---

## Files

| Path in this repository | Role |
|---|---|
| `mql5/Experts/AlgoSphere/ASQ_SafeScalping.mq5` | Main EA (inputs, event handlers) |
| `mql5/Include/ASQSafeScalping/ASQCore.mqh` | Enums, structs, logging, utilities |
| `mql5/Include/ASQSafeScalping/ASQTrading.mqh` | Execution, risk, break-even, trailing, partial close, peak DD |
| `mql5/Include/ASQSafeScalping/ASQStrategy.mqh` | 7-condition signal engine (EMA + RSI + breakout + MTF) |
| `mql5/Include/ASQSafeScalping/ASQDashboard.mqh` | Scarlet Forge GUI (cockpit + analytics panel) |
| `mql5/Presets/ASQ_SafeScalping/*.set` | Production preset and the four optimisation phases |

## Installation

1. Copy the repository's `mql5/` folder into your terminal's data folder (MetaTrader 5 → File → Open Data Folder → `MQL5`).
2. Compile `Experts/AlgoSphere/ASQ_SafeScalping.mq5` in MetaEditor.
3. Attach to an XAUUSD M5 chart.
4. Inputs tab → Load → `Presets/ASQ_SafeScalping/ASQ_SafeScalping_XAUUSD_M5_v2.set`.

## Preset Files

| File | Purpose |
|------|---------|
| `ASQ_SafeScalping_XAUUSD_M5_v2.set` | Production preset (grid-optimized, Sharpe 1.27) |
| `Phase1_Structure_FIXED.set` | Baseline test — all params fixed, no optimization |
| `Phase2_SL_TP_Risk.set` | Optimize SL/TP/Risk (3 params, 210 combos) |
| `Phase3_Exit_Management.set` | Optimize trailing/TP1/BE (4 params, genetic) |
| `Phase4_Session_DayCap.set` | Optimize session/daycap (4 params, 240 combos) |

## Optimization Workflow

1. Phase 1 → single backtest → establish baseline
2. Phase 2 → optimize SL/TP/Risk → paste winners into Phase 3
3. Phase 3 → optimize trailing/TP1/BE → paste winners into Phase 4
4. Phase 4 → optimize session/daycap → final set
5. Validate on out-of-sample data (40% holdout)

## Strategy (7 conditions)

1. EMA 50/200 trend direction
2. Trend strength (ATR-based separation)
3. Price position (above/below both EMAs)
4. N-bar breakout detection
5. RSI filter (healthy momentum zone)
6. Close-to-close momentum confirmation
7. [Optional] H1 EMA 20/50 MTF agreement

## v1.11 (2026-11-27)

- Risk mode no longer raises the lot to the broker minimum: if the risk-based lot is below the minimum, the trade is skipped and logged, so the real risk never exceeds the configured percentage.
- Risk-based lot is rounded down to the volume step instead of rounded to 2 decimals.

## v1.10 Features

- Trailing stop (configurable start/step)
- Multi-timeframe confirmation (7th condition)
- Max trades per day limiter
- Peak drawdown tracker (persisted via GlobalVariable)
- Partial close at TP1 (50% at first target)
- Scarlet Forge dashboard theme

## Default Parameters (XAUUSD M5)

- SL: 300 pts | TP: 450 pts | R:R 1:1.5
- Risk: 0.5% per trade | Max DD: 8%
- Trailing: start 200pts, step 100pts
- Partial close: 50% at TP1 (200pts)
- Session: 08:00-17:00 | Max 4 trades/day
- MTF: H1 EMA 20/50 confirmation enabled

## Monte Carlo Results (500 runs)

Full report: [`docs/reports/ASQ_SafeScalping_MonteCarlo_XAUUSD_M5.html`](../reports/ASQ_SafeScalping_MonteCarlo_XAUUSD_M5.html). Past results do not guarantee future results.


- Median return: +2.6%
- Median max DD: 2.7%
- Sharpe ratio: 1.27
- Win rate: 74.1%
- Profit factor: 1.20
- Profitable runs: 78.9%
- Risk of ruin: 0%

---
*AlgoSphere Quant — Precision before profit*
