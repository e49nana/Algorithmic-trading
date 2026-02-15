<div align="center">

<!-- HEADER -->
<img src="https://capsule-render.vercel.app/api?type=waving&color=0:0d1117,50:1a1b27,100:0f6b3a&height=180&section=header&text=Algorithmic%20Trading&fontSize=38&fontColor=58a6ff&fontAlignY=35&desc=MQL5%20%E2%80%A2%20NinjaTrader%20%E2%80%A2%20Quantitative%20Strategies&descSize=15&descColor=8b949e&descAlignY=55&animation=fadeIn" width="100%"/>

[![MQL5](https://img.shields.io/badge/MQL5-4A76A8?style=for-the-badge&logo=metatrader5&logoColor=white)](#-metatrader-5--mql5)
[![C#](https://img.shields.io/badge/C%23-239120?style=for-the-badge&logo=csharp&logoColor=white)](#-ninjatrader--c)
[![AlgoSphere Quant](https://img.shields.io/badge/AlgoSphere_Quant-0f6b3a?style=for-the-badge&logo=data:image/svg+xml;base64,&logoColor=white)](https://algosphere-quant.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-58a6ff?style=for-the-badge)](LICENSE)

**Open-source indicators, utilities & code snippets for algorithmic trading.**  
*Commercial products by [AlgoSphere Quant](https://algosphere-quant.com) are listed below but hosted on the [MQL5 Marketplace](https://www.mql5.com/).*

</div>

---

## 📖 About

This repository contains my **open-source algorithmic trading work** across two platforms:

- **MetaTrader 5 (MQL5)** — Indicators, utilities, and libraries published on the [MQL5 Code Base](https://www.mql5.com/en/code)
- **NinjaTrader (C#)** — Custom indicators and strategy snippets for futures trading

I also maintain a commercial product suite under **AlgoSphere Quant** — described [below](#-algosphere-quant--commercial-products) with links to the marketplace.

---

## 📂 Repository Structure

```
Algorithmic-Trading/
│
├── mql5/
│   ├── libraries/
│   │   ├── SessionTimeFilter.mqh          # Session filtering (London/NY/Tokyo/Sydney)
│   │   └── PositionSizer.mqh              # Risk-based lot sizing (fixed/percent/Kelly)
│   │
│   ├── indicators/
│   │   ├── SpreadAnalyzer.mq5             # Real-time spread monitoring & statistics
│   │   ├── CandlePatternDetector.mq5      # Automated candlestick pattern recognition
│   │   └── MultiTimeframeDashboard.mq5    # MTF trend overview panel
│   │
│   ├── experts/
│   │   ├── DrawdownGuard.mq5              # Equity protection EA (daily/weekly DD limits)
│   │   └── TradeStatistics.mq5            # Real-time P&L tracking & export
│   │
│   └── scripts/
│       ├── RiskCalculator.mq5             # One-click risk/reward calculator
│       └── TradeJournal.mq5               # Export trade history to CSV
│
├── ninjatrader/
│   ├── indicators/
│   │   ├── VolumeProfile.cs               # Volume-at-price distribution
│   │   ├── OrderFlowImbalance.cs          # Bid/Ask imbalance detector
│   │   └── SessionHighLow.cs              # Auto session high/low levels
│   │
│   └── strategies/
│       └── snippets/                      # Reusable strategy components
│
└── docs/
    └── architecture.md                    # Modular EA design philosophy
```

---

## 🔧 MQL5 — Open-Source Tools

### Libraries

| Tool | Description | Account |
|------|-------------|---------|
| **SessionTimeFilter** | Filter trades by session (London, NY, Tokyo, Sydney) with overlap detection | Both |
| **PositionSizer** | Risk-based position sizing — fixed lot, percent risk, Kelly criterion | Both |

### Indicators

| Tool | Description | Category |
|------|-------------|----------|
| **SpreadAnalyzer** | Real-time spread monitoring with statistics (avg, max, percentile) | Indicator |
| **CandlePatternDetector** | Automated detection of 15+ candlestick patterns with alerts | Indicator |
| **MultiTimeframeDashboard** | Multi-timeframe trend direction panel (RSI, MA, ADX) | Indicator |

### Experts & Scripts

| Tool | Description | Category |
|------|-------------|----------|
| **DrawdownGuard** | Automated equity protection with daily/weekly drawdown limits | Expert |
| **TradeStatistics** | Real-time win rate, expectancy, profit factor, Sharpe ratio | Expert |
| **RiskCalculator** | One-click lot size calculator based on SL distance & risk % | Script |
| **TradeJournal** | Export complete trade history to CSV for external analysis | Script |

> 💡 All MQL5 tools are also available on the [MQL5 Code Base](https://www.mql5.com/en/code).

---

## 📊 NinjaTrader — C# Indicators

| Indicator | Description | Market |
|-----------|-------------|--------|
| **VolumeProfile** | Volume distribution at each price level, VAH/VAL/POC detection | Futures |
| **OrderFlowImbalance** | Bid/Ask imbalance detection for scalping setups | Futures |
| **SessionHighLow** | Automatic session (RTH/ETH) high/low/mid levels | Futures |

---

## 🏢 AlgoSphere Quant — Commercial Products

> *The following products are developed and sold through [AlgoSphere Quant](https://algosphere-quant.com). Source code is private — links point to the MQL5 Marketplace.*

### 🏆 Flagship

| Product | Description | Version |
|---------|-------------|:-------:|
| **Trade Manager PRO** | Professional position management utility — automated BE, trailing, partial closes, TP ladders, session filter, journal export | v7.10 |
| **SafeScalperPro** | Fully automated scalping EA with risk management, session control, and prop firm compliance | v3.0 |

### 📈 Indicator Suite (9 products)

| Product | Category |
|---------|----------|
| SmartMoney Concepts | Market structure, BOS/CHoCH, order blocks |
| Liquidity Heatmap | Liquidity pool visualization |
| Volume Profile | Volume-at-price analysis |
| Divergence Scanner | Multi-indicator divergence detection |
| Order Flow | Bid/Ask imbalance & delta |
| Correlation Matrix | Multi-pair correlation dashboard |
| Session Control | Session visualization & filtering |
| Account Analytics | Real-time account statistics panel |
| Risk Manager | Position risk overlay |

### 🛡️ Utility Suite (5 products)

| Product | Category |
|---------|----------|
| PropGuard | Prop firm rule compliance monitor |
| Risk Manager | Drawdown protection & exposure limits |
| Trade Journal | Automated trade logging & CSV export |
| Position Sizer | Visual lot size calculator |
| News Filter | Economic calendar event filter |

> All products feature the unified **ASQ Dark Theme** and are built on a modular architecture with shared includes (`ASQ_Theme.mqh`, `ASQ_Common.mqh`).

---

## 🏗️ Architecture Philosophy

```
┌─────────────────────────────────────────────────────┐
│                    EA / Indicator                     │
├─────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐  ┌───────────────────┐ │
│  │  Signal   │  │  Filter  │  │  Risk Management  │ │
│  │  Module   │  │  Module  │  │     Module        │ │
│  └────┬─────┘  └────┬─────┘  └────────┬──────────┘ │
│       └──────────────┼─────────────────┘            │
│                      ▼                               │
│            ┌──────────────────┐                      │
│            │ Trade Management │                      │
│            │  (Position Mgmt) │                      │
│            └────────┬─────────┘                      │
│                     ▼                                │
│         ┌────────────────────┐                       │
│         │   Execution Layer  │                       │
│         │  (Deterministic)   │                       │
│         └────────────────────┘                       │
├─────────────────────────────────────────────────────┤
│  ASQ_Theme.mqh  │  ASQ_Common.mqh  │  Resources     │
└─────────────────────────────────────────────────────┘
```

**Key design principles:**
- **Deterministic execution** — Timer-driven pipeline (250ms), no tick-dependent logic
- **Monotonic state machine** — Stop states progress INITIAL → BE → TRAILING, never backward
- **Command queue** — UI decoupled from execution logic
- **Modular composition** — Signal, Filter, Risk, and Trade modules are interchangeable

---

## 🚀 Quick Start

```bash
# Clone
git clone https://github.com/e49nana/Algorithmic-trading.git

# MQL5 — Copy to your MetaTrader data folder:
# Indicators → MQL5/Indicators/
# Experts    → MQL5/Experts/
# Libraries  → MQL5/Include/
# Scripts    → MQL5/Scripts/

# NinjaTrader — Import via:
# Tools → Import → NinjaScript Add-On
```

---

## 🛠️ Tech Stack

<div align="center">

| Platform | Language | Use |
|----------|----------|-----|
| **MetaTrader 5** | MQL5 | Indicators, EAs, utilities |
| **NinjaTrader** | C# | Futures indicators & strategies |
| **Python** | Python | Backtesting, data analysis |

</div>

---

## 📈 Roadmap

- [x] 10 open-source MQL5 Code Base publications
- [x] NinjaTrader indicator suite for futures
- [x] AlgoSphere Quant product suite (14 products)
- [x] TradeManager v7.10 with deterministic engine
- [ ] Modular EA Framework — reusable CTradeManager, CPositionSizer, CRiskManager
- [ ] Backtesting engine with walk-forward optimization
- [ ] Python integration for ML-based signal generation

---

## ⚠️ Disclaimer

Trading involves significant risk of loss. The code in this repository is provided for **educational and research purposes only**. Past performance does not guarantee future results. Always test thoroughly on demo accounts before any live trading.

---

## 👤 Author

**Emmanuel Nana Nana**  
Founder, [AlgoSphere Quant](https://algosphere-quant.com)  
B.Sc. Applied Mathematics & Physics — TH Nürnberg

[![GitHub](https://img.shields.io/badge/GitHub-e49nana-181717?style=flat&logo=github)](https://github.com/e49nana)
[![MQL5](https://img.shields.io/badge/MQL5-Profile-4A76A8?style=flat&logo=metatrader5)](https://www.mql5.com/)

---

## 📄 License

Open-source code in this repository is licensed under the [MIT License](LICENSE).  
Commercial AlgoSphere Quant products are proprietary — see [algosphere-quant.com](https://algosphere-quant.com) for licensing.

---

<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:0d1117,50:1a1b27,100:0f6b3a&height=100&section=footer" width="100%"/>

</div>
