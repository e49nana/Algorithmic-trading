# ASQ JournalExport v2.0 — MQL5 Code Base Description (English)

---

## Title
ASQ JournalExport

## Short Description
One-click CSV trade journal export with R:R ratio, win rate, expectancy, profit factor, max streaks, best/worst trade, avg duration, and full summary section. Free script.

---

## Full Description

**ASQ JournalExport** generates a comprehensive CSV file of your trade history with a single click. Perfect for importing into Excel, Google Sheets, or any journaling tool for detailed trade analysis.

**Exported Fields per Trade:**

• Position ticket, symbol, direction (BUY/SELL)
• Open time, close time
• Lot size, open price, close price
• Stop loss and take profit levels
• Gross P/L, swap, commission, net P/L
• R:R ratio (calculated from actual SL/TP if set)
• Trade duration in minutes
• Magic number and trade comment (all optional)

**New in v2.0 — Extended Summary Statistics:**

The CSV now includes a comprehensive summary section at the bottom:
• Total trades, wins, losses, win rate %
• Average win amount, average loss amount
• Expectancy — the mathematical edge per trade
• Profit factor — ratio of total wins to total losses
• Best single trade and worst single trade
• Maximum consecutive win streak and loss streak
• Average trade duration in minutes
• Period covered and generation timestamp

**The Alert report** after export now shows all key metrics at a glance: win rate, P/L, profit factor, expectancy, streaks, and average duration — so you get immediate feedback without opening the CSV.

**Filtering:**

• Days back: export last 7, 30, 90 days or all history
• Symbol filter: export only one instrument
• Magic filter: export only trades from a specific EA

**File Output:**

Saved to MQL5/Files/ with auto-generated filename including the date (e.g., ASQ_Journal_20260327.csv).

**How to Use:**

1. Drag ASQ JournalExport onto any chart
2. Configure days back, filters, and which fields to include
3. Click OK — the CSV is generated instantly
4. Open from MQL5/Files/ in Excel or Google Sheets

**Single-file script, no DLLs, no external dependencies.**

---

## Tags
journal, trade log, CSV export, trade history, win rate, expectancy, profit factor, trade analysis, position log, reporting, statistics

## Category
Scripts / Trading Utilities

## Author
AlgoSphere Quant (robin2.0)
