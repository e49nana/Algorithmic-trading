# 💹 Algorithmic Trading

[![C#](https://img.shields.io/badge/C%23-239120?style=flat&logo=c-sharp&logoColor=white)](https://docs.microsoft.com/en-us/dotnet/csharp/)
[![NinjaTrader](https://img.shields.io/badge/NinjaTrader%208-FF6600?style=flat)](https://ninjatrader.com/)
[![MQL5](https://img.shields.io/badge/MQL5-4A76A8?style=flat)](https://www.mql5.com/)
[![Stars](https://img.shields.io/github/stars/e49nana/Algorithmic-trading?style=flat)](https://github.com/e49nana/Algorithmic-trading/stargazers)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> 📊 Custom indicators, strategies, and trading utilities for **NinjaTrader 8** and **MetaTrader 5**.

---

## 🎯 Overview

This repository contains algorithmic trading tools developed with a focus on:

- **Market Structure Analysis** — Swing points, BOS, CHoCH detection
- **Risk Management** — Position sizing, drawdown control
- **ICT/SMC Concepts** — Order blocks, fair value gaps, liquidity pools
- **Quantitative Analysis** — Statistical edge validation

---

## 📂 Repository Structure

```
Algorithmic-trading/
│
├── indicators/
│   ├── NinjaTrader/           # NT8 indicators (.cs)
│   │   ├── SwingHighLow.cs
│   │   ├── MarketStructure.cs
│   │   └── ...
│   └── MetaTrader/            # MT5 indicators (.mq5)
│       └── ...
│
├── strategies/
│   ├── NinjaTrader/           # NT8 strategies
│   └── MetaTrader/            # MT5 EAs
│
├── utils/
│   └── RiskManagement.cs      # Position sizing utilities
│
└── docs/
    ├── RISK_MANAGEMENT.md     # Risk framework documentation
    └── INSTALLATION.md        # Setup guide
```

---

## 📊 Available Indicators

### Market Structure
| Indicator | Platform | Description |
|-----------|----------|-------------|
| `SwingHighLow` | NT8 | Automatic swing point detection |
| `MarketStructureShift` | NT8 | BOS & CHoCH pattern recognition |
| `FairValueGap` | NT8 / MT5 | Imbalance detection with fill tracking |

### Order Flow & Volume
| Indicator | Platform | Description |
|-----------|----------|-------------|
| `VolumeProfile` | NT8 | Session-based POC, VAH, VAL |
| `DeltaDivergence` | NT8 | Cumulative delta with divergence alerts |

### ICT/SMC Concepts
| Indicator | Platform | Description |
|-----------|----------|-------------|
| `LiquidityPools` | NT8 | Equal highs/lows as liquidity targets |
| `OrderBlocks` | NT8 / MT5 | OB detection with mitigation tracking |
| `KillZones` | NT8 / MT5 | Session highlights (London, NY, Asia) |

---

## 🛡️ Risk Management Framework

### Position Sizing Formula
```
Position Size = (Account × Risk%) / |Entry - Stop Loss|
```

### Risk Limits
| Parameter | Conservative | Moderate | Aggressive |
|-----------|-------------|----------|------------|
| Risk per trade | 0.5% | 1-2% | 3-5% |
| Daily drawdown | 2% | 5% | 10% |
| Max exposure | 5% | 10% | 20% |

📖 Full documentation: [`docs/RISK_MANAGEMENT.md`](docs/RISK_MANAGEMENT.md)

---

## 🚀 Installation

### NinjaTrader 8
```
1. Copy .cs files to: Documents/NinjaTrader 8/bin/Custom/Indicators/
2. Open NinjaTrader → Tools → Compile
3. Add indicator to chart from Indicators menu
```

### MetaTrader 5
```
1. Copy .mq5 files to: MQL5/Indicators/
2. Compile in MetaEditor (F7)
3. Drag indicator onto chart
```

---

## 💻 Code Example

```csharp
// Position sizing in NinjaTrader
private double CalculatePositionSize(double entry, double stopLoss, double riskPercent)
{
    double accountSize = Account.Get(AccountItem.CashValue, Currency.UsDollar);
    double riskAmount = accountSize * (riskPercent / 100);
    double pipRisk = Math.Abs(entry - stopLoss);
    
    return Math.Floor(riskAmount / pipRisk);
}

// Usage in strategy
protected override void OnBarUpdate()
{
    double posSize = CalculatePositionSize(Close[0], Close[0] - 10 * TickSize, 1.0);
    EnterLong((int)posSize, "Long Entry");
}
```

---

## 📈 Backtesting Results

> ⚠️ **Disclaimer:** Past performance does not guarantee future results.

| Strategy | Win Rate | Avg R:R | Profit Factor | Max DD |
|----------|----------|---------|---------------|--------|
| ICT Breaker | 52% | 1:2.1 | 1.45 | 12% |
| FVG Fill | 48% | 1:2.5 | 1.38 | 15% |
| Swing Failure | 55% | 1:1.8 | 1.42 | 10% |

*Tested on ES futures, 2023-2025 data*

---

## 🧮 The Math Behind Trading

This project applies concepts from:

- **Probability Theory** — Win rate, expected value, Kelly criterion
- **Statistics** — Distribution analysis, significance testing
- **Numerical Methods** — Optimization, curve fitting
- **Risk Theory** — Value at Risk, risk of ruin

📚 Related repo: [AMP-Studies](https://github.com/e49nana/AMP-Studies)

---

## 🗺️ Roadmap

- [x] Core market structure indicators
- [x] Risk management framework
- [ ] Machine learning signal filter
- [ ] Walk-forward optimization tool
- [ ] Performance analytics dashboard
- [ ] Full EA release (AnaCristina EA)

---

## ⚠️ Disclaimer

This software is for **educational purposes only**. Trading involves substantial risk of loss. The author is not responsible for any financial losses incurred using these tools.

**Not financial advice. Trade at your own risk.**

---

## 👤 Author

**Emmanuel Nana Nana**  
Applied Mathematics & Physics @ TH Nürnberg  
Algorithmic Trading Developer

[![GitHub](https://img.shields.io/badge/GitHub-e49nana-181717?style=flat&logo=github)](https://github.com/e49nana)
[![MQL5](https://img.shields.io/badge/MQL5-Market-4A76A8?style=flat)](https://www.mql5.com/en/users/emmanuelnana)

---

## 📄 License

MIT License — Free for educational use. Commercial use requires permission.

---

*"The goal is not to predict the market, but to have an edge and manage risk."*
