<div align="center">

<!-- HEADER -->
<img src="https://capsule-render.vercel.app/api?type=waving&color=0:0d1117,50:1a1b27,100:0f6b3a&height=180&section=header&text=Algorithmic%20Trading&fontSize=38&fontColor=58a6ff&fontAlignY=35&desc=TradFi%20%E2%80%A2%20DeFi%20%E2%80%A2%20Quantitative%20Strategies&descSize=15&descColor=8b949e&descAlignY=55&animation=fadeIn" width="100%"/>

[![MQL5](https://img.shields.io/badge/MQL5-4A76A8?style=for-the-badge&logo=metatrader5&logoColor=white)](#-tradfi--metatrader-5--ninjatrader)
[![C#](https://img.shields.io/badge/C%23-239120?style=for-the-badge&logo=csharp&logoColor=white)](#-tradfi--metatrader-5--ninjatrader)
[![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)](#-defi--crypto-trading-bot)
[![Web3.py](https://img.shields.io/badge/Web3.py-F16822?style=for-the-badge&logo=web3dotjs&logoColor=white)](#-defi--crypto-trading-bot)
[![Solidity](https://img.shields.io/badge/Solidity-363636?style=for-the-badge&logo=solidity&logoColor=white)](#-blockchain--smart-contracts-roadmap)
[![Ethereum](https://img.shields.io/badge/Ethereum-3C3C3D?style=for-the-badge&logo=ethereum&logoColor=white)](#-defi--crypto-trading-bot)
[![License: MIT](https://img.shields.io/badge/License-MIT-58a6ff?style=for-the-badge)](LICENSE)

**Open-source tools & strategies for algorithmic trading — from traditional markets to DeFi.**  
*Commercial products by [AlgoSphere Quant](https://algosphere-quant.com) are listed below but hosted on the [MQL5 Marketplace](https://www.mql5.com/).*

</div>

---

## 📖 About

This repository brings together my algorithmic trading work across **two worlds**:

| | TradFi | DeFi |
|---|---|---|
| **Platforms** | MetaTrader 5, NinjaTrader | Ethereum, Arbitrum, Polygon, Solana |
| **Languages** | MQL5, C# | Python, Solidity (learning) |
| **Focus** | Indicators, EAs, position management | CEX/DEX connectors, arbitrage, MEV |
| **Status** | Mature (14+ products) | Active development |

---

## 📂 Repository Structure

```
Algorithmic-Trading/
│
├── tradfi/
│   ├── mql5/
│   │   ├── libraries/
│   │   │   ├── SessionTimeFilter.mqh
│   │   │   └── PositionSizer.mqh
│   │   ├── indicators/
│   │   │   ├── SpreadAnalyzer.mq5
│   │   │   ├── CandlePatternDetector.mq5
│   │   │   └── MultiTimeframeDashboard.mq5
│   │   ├── experts/
│   │   │   ├── DrawdownGuard.mq5
│   │   │   └── TradeStatistics.mq5
│   │   └── scripts/
│   │       ├── RiskCalculator.mq5
│   │       └── TradeJournal.mq5
│   │
│   └── ninjatrader/
│       ├── indicators/
│       │   ├── VolumeProfile.cs
│       │   ├── OrderFlowImbalance.cs
│       │   └── SessionHighLow.cs
│       └── strategies/
│           └── snippets/
│
├── defi/
│   ├── crypto-trade-bot/
│   │   ├── connectors/
│   │   │   ├── cex/                       # CEX connectors (Binance, Bybit, OKX)
│   │   │   │   ├── base.py
│   │   │   │   ├── binance.py
│   │   │   │   ├── bybit.py
│   │   │   │   └── okx.py
│   │   │   └── dex/                       # DEX connectors
│   │   │       ├── base.py                # AbstractDEXConnector
│   │   │       └── uniswap.py             # Uniswap V3 (Web3.py)
│   │   ├── services/
│   │   │   └── exchange_rate_limiter.py   # Token bucket rate limiting
│   │   ├── config/
│   │   └── tests/                         # 294 tests, 0 failures
│   │
│   └── contracts/                         # Solidity (coming soon)
│       └── README.md
│
└── docs/
    ├── architecture.md
    └── defi-roadmap.md
```

---

## 💹 TradFi — MetaTrader 5 & NinjaTrader

### MQL5 — Open-Source Tools

| Tool | Description | Type |
|------|-------------|------|
| **SessionTimeFilter** | Filter trades by session (London, NY, Tokyo, Sydney) with overlap detection | Library |
| **PositionSizer** | Risk-based position sizing — fixed lot, percent risk, Kelly criterion | Library |
| **SpreadAnalyzer** | Real-time spread monitoring with statistics (avg, max, percentile) | Indicator |
| **CandlePatternDetector** | Automated detection of 15+ candlestick patterns with alerts | Indicator |
| **MultiTimeframeDashboard** | Multi-timeframe trend direction panel (RSI, MA, ADX) | Indicator |
| **DrawdownGuard** | Automated equity protection with daily/weekly drawdown limits | Expert |
| **TradeStatistics** | Real-time win rate, expectancy, profit factor, Sharpe ratio | Expert |
| **RiskCalculator** | One-click lot size calculator based on SL distance & risk % | Script |
| **TradeJournal** | Export complete trade history to CSV for external analysis | Script |

> All MQL5 tools are also available on the [MQL5 Code Base](https://www.mql5.com/en/code).

### NinjaTrader — C# Indicators

| Indicator | Description | Market |
|-----------|-------------|--------|
| **VolumeProfile** | Volume distribution at each price level, VAH/VAL/POC | Futures |
| **OrderFlowImbalance** | Bid/Ask imbalance detection for scalping | Futures |
| **SessionHighLow** | Automatic session (RTH/ETH) high/low/mid levels | Futures |

---

## ⛓️ DeFi — Crypto Trading Bot

> **Multi-exchange, multi-chain trading bot** with CEX and DEX support, built in Python with async architecture.

### Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                     Telegram Bot Interface                    │
├──────────────────────────────────────────────────────────────┤
│                      Strategy Engine                          │
├────────────────────┬─────────────────────────────────────────┤
│   CEX Connectors   │            DEX Connectors               │
│  ┌───────────────┐ │  ┌────────────────────────────────────┐ │
│  │   Binance     │ │  │   Uniswap V3 (Web3.py)            │ │
│  │   Bybit       │ │  │   ├─ Ethereum mainnet              │ │
│  │   OKX         │ │  │   ├─ Arbitrum                      │ │
│  └───────┬───────┘ │  │   └─ Polygon                       │ │
│          │         │  └────────────────────────────────────┘ │
│          ▼         │                                         │
│  ┌───────────────┐ │           Smart Contracts               │
│  │  Rate Limiter │ │  ┌────────────────────────────────────┐ │
│  │ Token Bucket  │ │  │   Quoter V2    (price quotes)      │ │
│  │ per-exchange  │ │  │   SwapRouter02 (execute swaps)     │ │
│  │ per-endpoint  │ │  │   ERC-20       (approve/balance)   │ │
│  └───────────────┘ │  └────────────────────────────────────┘ │
├────────────────────┴─────────────────────────────────────────┤
│              Config  │  Logging  │  294 Tests                │
└──────────────────────────────────────────────────────────────┘
```

### Key Features

- **3 CEX connectors** — Binance, Bybit, OKX via ccxt (async)
- **Uniswap V3 DEX connector** — Direct smart contract interaction via Web3.py (Quoter V2, SwapRouter02)
- **Multi-chain** — Ethereum mainnet, Arbitrum, Polygon
- **Token bucket rate limiter** — Per-exchange, per-endpoint (order/market_data/account), with 10-20% headroom below real limits
- **Async-first** — `aiogram` for Telegram, `asyncio.to_thread()` for sync ccxt calls
- **294 tests**, 0 failures

### Rate Limiter — Exchange Limits

| Exchange | Global | Orders | Market Data | Account |
|----------|:------:|:------:|:-----------:|:-------:|
| Binance | 1000/min | 400/min | 800/min | 400/min |
| Bybit | 5000/min | 500/min | 2000/min | 600/min |
| OKX | 2000/min | 500/min | 1200/min | 500/min |

---

## 🔗 Blockchain & Smart Contracts (Roadmap)

> Currently learning Solidity and smart contract development. Planned projects:

| Phase | Project | Stack | Status |
|:-----:|---------|-------|:------:|
| 1 | Solidity fundamentals + first contract deployment | Solidity, Remix, Hardhat | 📋 Planned |
| 2 | DEX mechanics — study Uniswap V2/V3 source code | Solidity, Foundry | 📋 Planned |
| 3 | Flashloan arbitrage bot | Solidity, Aave V3, Foundry | 📋 Planned |
| 4 | MEV extraction (backrunning, sandwich detection) | Solidity, Flashbots | 📋 Planned |
| 5 | Smart contract security auditing | Slither, Mythril, CTFs | 📋 Planned |

**Learning resources in progress:** CryptoZombies, Ethernaut, Damn Vulnerable DeFi

---

## 🏢 AlgoSphere Quant — Commercial Products

> *Source code is private — links point to the MQL5 Marketplace.*

### 🏆 Flagship Products

| Product | Description | Version |
|---------|-------------|:-------:|
| **Trade Manager PRO** | Position management — automated BE, trailing, partial closes, TP ladders, session filter, journal export | v7.10 |
| **SafeScalperPro** | Automated scalping EA with risk management and prop firm compliance | v3.0 |

### Product Suite (14 products)

<details>
<summary><b>📈 9 Indicators + 🛡️ 5 Utilities</b> (click to expand)</summary>

**Indicators:**
SmartMoney Concepts, Liquidity Heatmap, Volume Profile, Divergence Scanner, Order Flow, Correlation Matrix, Session Control, Account Analytics, Risk Manager

**Utilities:**
PropGuard (prop firm compliance), Risk Manager (drawdown protection), Trade Journal, Position Sizer, News Filter

All products feature the unified **ASQ Dark Theme** built on shared includes (`ASQ_Theme.mqh`, `ASQ_Common.mqh`).

</details>

---

## 🏗️ Architecture Philosophy

```
┌─────────────────────────────────────────────────────┐
│                    EA / Bot / DApp                    │
├─────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐  ┌───────────────────┐ │
│  │  Signal   │  │  Filter  │  │  Risk Management  │ │
│  │  Module   │  │  Module  │  │     Module        │ │
│  └────┬─────┘  └────┬─────┘  └────────┬──────────┘ │
│       └──────────────┼─────────────────┘            │
│                      ▼                               │
│            ┌──────────────────┐                      │
│            │ Trade Management │                      │
│            └────────┬─────────┘                      │
│                     ▼                                │
│         ┌────────────────────┐                       │
│         │   Execution Layer  │                       │
│         │  (Deterministic)   │                       │
│         └────────────────────┘                       │
├─────────────────────────────────────────────────────┤
│  TradFi: MQL5/C#  │  DeFi: Web3.py/Solidity        │
└─────────────────────────────────────────────────────┘
```

**Shared principles across TradFi & DeFi:**
- **Deterministic execution** — Timer/block-driven, no race conditions
- **Monotonic state machines** — States progress forward, never backward
- **Rate limiting** — Token bucket per exchange/endpoint
- **Modular composition** — Reusable signal, filter, risk modules

---

## 🚀 Quick Start

```bash
git clone https://github.com/e49nana/Algorithmic-trading.git
cd Algorithmic-trading

# ── TradFi ──
# MQL5: Copy to MetaTrader data folder (Indicators/, Experts/, Include/, Scripts/)
# NinjaTrader: Tools → Import → NinjaScript Add-On

# ── DeFi ──
cd defi/crypto-trade-bot
pip install -r requirements.txt
# Configure your API keys in config/
python -m pytest tests/ -q   # 294 tests
```

---

## 🛠️ Tech Stack

<div align="center">

| Domain | Languages | Frameworks & Tools |
|--------|-----------|-------------------|
| **TradFi** | MQL5, C# | MetaTrader 5, NinjaTrader |
| **DeFi** | Python, Solidity (learning) | Web3.py, ccxt, aiogram, Hardhat |
| **Blockchain** | — | Ethereum, Arbitrum, Polygon, Solana |
| **Testing** | Python | pytest (294 tests) |
| **Smart Contracts** | — | Uniswap V3 (Quoter, Router, Pool) |

</div>

---

## 📈 Roadmap

**TradFi:**
- [x] 10 open-source MQL5 Code Base publications
- [x] NinjaTrader indicator suite for futures
- [x] AlgoSphere Quant product suite (14 products)
- [x] TradeManager v7.10 with deterministic engine
- [ ] Modular EA Framework (CTradeManager, CPositionSizer, CRiskManager)

**DeFi:**
- [x] Multi-CEX async connector (Binance, Bybit, OKX)
- [x] Uniswap V3 DEX connector (Web3.py)
- [x] Token bucket rate limiter (294 tests)
- [ ] Solidity fundamentals + first testnet deployment
- [ ] Flashloan arbitrage contract (Aave V3)
- [ ] MEV extraction bot (Flashbots)
- [ ] Smart contract security auditing

---

## ⚠️ Disclaimer

Trading involves significant risk of loss. The code in this repository is provided for **educational and research purposes only**. Past performance does not guarantee future results. Always test on demo/testnet before live trading.

---

## 👤 Author

**Emmanuel Nana Nana**  
Founder, [AlgoSphere Quant](https://algosphere-quant.com)  
B.Sc. Applied Mathematics & Physics — TH Nürnberg

[![GitHub](https://img.shields.io/badge/GitHub-e49nana-181717?style=flat&logo=github)](https://github.com/e49nana)
[![MQL5](https://img.shields.io/badge/MQL5-Profile-4A76A8?style=flat&logo=metatrader5)](https://www.mql5.com/)

---

## 📄 License

Open-source code: [MIT License](LICENSE).  
AlgoSphere Quant products: proprietary — see [algosphere-quant.com](https://algosphere-quant.com).

---

<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:0d1117,50:1a1b27,100:0f6b3a&height=100&section=footer" width="100%"/>

</div>
