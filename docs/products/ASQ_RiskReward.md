# ASQ RiskReward v2.0 — MQL5 Code Base Description (English)

---

## Title
ASQ RiskReward

## Short Description
Visual trade planning indicator with draggable Entry/SL/TP lines. Real-time R:R ratio with quality rating, auto lot sizing, risk/reward in $, multi-TP levels with partial close breakdown, zone shading. Click to snap entry to price. Free.

---

## Full Description

**ASQ RiskReward** lets you plan trades visually by dragging Entry, Stop Loss, and Take Profit lines directly on the chart. Every metric updates in real time as you move any line — R:R ratio, lot size, risk and reward in your account currency, distances in pips, and trade direction.

**Core Features:**

• Three draggable horizontal lines: Entry (blue), SL (red), TP (green) — all update in real time
• R:R ratio prominently displayed with quality rating: POOR (<1:1), FAIR (1:1–2:1), GOOD (2:1–3:1), EXCELLENT (3:1+)
• Auto lot sizing based on risk % of balance or fixed lots
• Risk and reward displayed in account currency with actual risk % shown
• SL and TP distances in pips
• Auto-detect trade direction (BUY/SELL) from line positions
• Color-coded risk/reward zone shading on chart
• Click entry line to snap to current bid price
• Works on all symbols — proper pip calculation for 3/4/5-digit brokers

**New in v2.0 — Multi-TP System:**

• Up to 3 take profit levels (TP1, TP2, TP3) with independent draggable lines
• Configurable partial close percentages (default: 50% / 30% / 20%)
• Each TP level shows its own zone shading with distinct color
• Dashboard shows the partial close breakdown: lot allocation and dollar reward for each TP
• Blended R:R calculation — the true weighted R:R across all partial closes, giving you a realistic expected reward ratio

**Dashboard Panel:**

A clean panel with sections for:
— Direction (BUY/SELL) with color indicator
— All price levels (Entry, SL, TP1, TP2, TP3)
— R:R ratio with POOR/FAIR/GOOD/EXCELLENT quality label
— Distances in pips for every level
— Lot size, risk in $ with % of balance, reward in $
— Multi-TP breakdown with per-level lots and dollar amounts
— Blended R:R for realistic multi-TP expectation

All dashboard colors are fully customizable: accent, text, dim, background, border.

**How to Use:**

1. Attach ASQ RiskReward to any chart.
2. Drag the Entry, SL, and TP lines to plan your trade.
3. Enable TP2/TP3 in inputs for multi-target setups.
4. Read the dashboard for instant R:R, lot size, and risk/reward.
5. Click the Entry line to snap it to the current price.

**Single-file indicator, no DLLs, no external dependencies. Works on all instruments and timeframes.**

---

## Tags
risk reward, R:R ratio, trade planner, position sizing, lot calculator, multi TP, partial close, visual trading, SL TP, risk management, zone shading, pip calculator

## Category
Indicators / Trading Utilities

## MQL5 Version
MT5 only

## Author
AlgoSphere Quant (robin2.0)
