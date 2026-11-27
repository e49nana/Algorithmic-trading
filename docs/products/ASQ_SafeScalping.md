# ASQ Safe Scalping v1.10
### AlgoSphere Quant | https://www.mql5.com/en/users/robin2.0

---

## Architecture

```
Experts/
  ASQ_SafeScalping.mq5          → Main EA (Market version, Scarlet Forge dashboard)

Include/ASQSafeScalping/
  ASQCore.mqh                   → Enums, structs, logging, utilities
  ASQTrading.mqh                → Execution, risk, breakeven, trailing, partial close, peak DD
  ASQStrategy.mqh               → 7-condition signal engine (EMA+RSI+Breakout+MTF)
  ASQDashboard.mqh              → Scarlet Forge GUI (cockpit + analytics panel)

ASQ_SafeScalping_CodeBase.mq5   → Single-file version (Code Base, free, open-source)
```

## Installation (Market version)

1. Copy `ASQ_SafeScalping.mq5` → `MQL5/Experts/`
2. Copy `Include/ASQSafeScalping/` folder → `MQL5/Include/ASQSafeScalping/`
3. Compile in MetaEditor
4. Attach to XAUUSD M5 chart
5. Load `ASQ_SafeScalping_XAUUSD_M5_v2.set` in Inputs tab

## Installation (Code Base version)

1. Copy `ASQ_SafeScalping_CodeBase.mq5` → `MQL5/Experts/`
2. Compile (only requires standard Trade.mqh)
3. Attach to XAUUSD M5 chart, load .set file

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

- Median return: +2.6%
- Median max DD: 2.7%
- Sharpe ratio: 1.27
- Win rate: 74.1%
- Profit factor: 1.20
- Profitable runs: 78.9%
- Risk of ruin: 0%

---
*AlgoSphere Quant — Precision before profit*
