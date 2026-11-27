# ASQ PropGuard v2.0 — MQL5 Code Base Description (English)

---

## Title
ASQ PropGuard

## Short Description
Real-time prop firm challenge monitor with 7 firm presets (FTMO, Bulenox, MFF, E8, TFT, Topstep), phase tracking, daily DD & max DD with progress bars, profit target, trading days, deadline calculator, auto-close protection. Free.

---

## Full Description

**ASQ PropGuard** monitors your prop firm challenge rules in real time and protects your account by automatically closing positions when drawdown limits are about to be breached.

**7 Built-in Firm Presets:**

• FTMO — 5% daily, 10% max, 10% target, 4 min days, 30 day period
• Bulenox — 4% daily, 7.5% max (trailing), 6% target, no time limit
• MyFundedFX — 5% daily, 10% max, 8% target, 5 min days, 30 days
• E8 Funding — 5% daily, 8% max, 8% target, no time limit
• The Funded Trader — 5% daily, 10% max, 10% target, 35 days
• Topstep — 2% daily, 4% max (trailing), 6% target
• Custom — set your own rules for any firm

**New in v2.0:**

• Challenge Phase selector (Phase 1 / Phase 2 / Funded) — displayed in dashboard header, so you always know which stage you're tracking
• Deadline calculator — shows the exact calendar date your challenge expires
• High Water Mark display — see the peak balance used for trailing DD calculation
• Proper day detection — uses TimeToStruct instead of modular arithmetic, correctly handles broker timezone offsets
• CTrade-based protection — uses the standard MQL5 trade library instead of raw OrderSend, with configurable slippage
• Fully reformatted, readable code — no more compressed one-liners

**Dashboard Panel:**

A comprehensive panel showing: firm name with phase indicator, balance, equity, floating P/L, high water mark, daily drawdown with progress bar and percentage, max drawdown with progress bar, profit target with progress bar, trading days vs minimum, days passed, days left, deadline date, status indicator, and protection armed status. All with color-coded thresholds.

**Three Drawdown Calculation Types:**

• Balance-based (trailing) — drawdown measured from the highest balance reached
• Equity-based (trailing) — drawdown measured from the highest equity
• Static — drawdown measured from the initial account size

**Auto-Close Protection:**

When a drawdown limit is breached, the indicator can: alert only, close all positions, or close losing positions only. Configurable warning threshold (default 80% of limit) fires alerts before the breach.

**How to Use:**

1. Attach to any chart
2. Select your prop firm preset or configure custom rules
3. Set your challenge phase
4. Enable auto-close if you want protection
5. Monitor your progress in real time

**Single-file indicator with CTrade include. No DLLs, no external dependencies.**

---

## Tags
prop firm, FTMO, Bulenox, MyFundedFX, E8, Topstep, drawdown, daily loss, profit target, trading days, challenge, funded account, risk management, auto close, dashboard

## Category
Indicators / Trading Utilities

## Author
AlgoSphere Quant (robin2.0)
