# Position Sizing & Risk Management

## 📊 Introduction

Position sizing is the foundation of professional trading. Without proper risk management, even the best entry signals become gambling. This document covers the mathematical frameworks used in the **AnaCristina EA** and other professional trading systems.

---

## 🎯 1. Fixed Fractional Method

The simplest approach: risk a fixed percentage of your account on each trade.

### Formula

```
Position Size (lots) = (Account Balance × Risk %) / (Stop Loss in pips × Pip Value)
```

### Example

| Parameter | Value |
|-----------|-------|
| Account Balance | $10,000 |
| Risk per trade | 2% |
| Stop Loss | 50 pips |
| Pip Value (EURUSD) | $10/lot |

```
Position Size = ($10,000 × 0.02) / (50 × $10)
             = $200 / $500
             = 0.40 lots
```

### MQL5 Implementation

```mql5
double CalculateFixedFractional(double riskPercent, double stopLossPips)
{
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double pointValue = tickValue / tickSize * _Point;
    
    double riskAmount = accountBalance * (riskPercent / 100.0);
    double lotSize = riskAmount / (stopLossPips * 10 * pointValue);
    
    // Normalize to broker's lot step
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    lotSize = MathFloor(lotSize / lotStep) * lotStep;
    
    // Apply min/max constraints
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    
    return MathMax(minLot, MathMin(maxLot, lotSize));
}
```

---

## 🧮 2. Kelly Criterion

The Kelly Criterion maximizes long-term growth by calculating the optimal fraction of capital to risk.

### Formula

```
f* = (bp - q) / b

Where:
f* = Optimal fraction of capital to bet
b  = Net odds (Reward/Risk ratio)
p  = Probability of winning
q  = Probability of losing (1 - p)
```

### Example

| Parameter | Value |
|-----------|-------|
| Win Rate | 55% (p = 0.55) |
| Loss Rate | 45% (q = 0.45) |
| Risk/Reward | 1:2 (b = 2) |

```
f* = (2 × 0.55 - 0.45) / 2
   = (1.10 - 0.45) / 2
   = 0.65 / 2
   = 0.325 (32.5%)
```

### Half-Kelly (Recommended)

Full Kelly is aggressive. Most professionals use **Half-Kelly** for reduced volatility:

```
Practical Kelly = f* / 2 = 0.325 / 2 = 16.25%
```

### MQL5 Implementation

```mql5
double CalculateKellyFraction(double winRate, double rewardRiskRatio)
{
    double p = winRate;
    double q = 1.0 - winRate;
    double b = rewardRiskRatio;
    
    double kelly = (b * p - q) / b;
    
    // Return half-Kelly for conservative approach
    return MathMax(0, kelly / 2.0);
}

// Usage with historical data
double GetHistoricalKelly()
{
    // Calculate from last 100 trades
    int totalTrades = 100;
    int wins = 0;
    double totalProfit = 0;
    double totalLoss = 0;
    
    // ... loop through history ...
    
    double winRate = (double)wins / totalTrades;
    double avgWin = totalProfit / wins;
    double avgLoss = MathAbs(totalLoss / (totalTrades - wins));
    double rewardRisk = avgWin / avgLoss;
    
    return CalculateKellyFraction(winRate, rewardRisk);
}
```

---

## 📈 3. ATR-Based Position Sizing

Using Average True Range (ATR) for dynamic stop losses adapts to market volatility.

### Formula

```
Stop Loss = ATR × Multiplier
Position Size = Risk Amount / (ATR × Multiplier × Pip Value)
```

### ATR Multipliers by Strategy

| Strategy Type | ATR Multiplier |
|--------------|----------------|
| Scalping | 1.0 - 1.5 |
| Day Trading | 1.5 - 2.0 |
| Swing Trading | 2.0 - 3.0 |
| Position Trading | 3.0 - 4.0 |

### MQL5 Implementation

```mql5
int atrHandle;

int OnInit()
{
    atrHandle = iATR(_Symbol, PERIOD_H1, 14);
    return(INIT_SUCCEEDED);
}

double CalculateATRPosition(double riskPercent, double atrMultiplier)
{
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);
    CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
    
    double atr = atrBuffer[0];
    double stopLossPips = (atr * atrMultiplier) / _Point / 10;
    
    return CalculateFixedFractional(riskPercent, stopLossPips);
}
```

---

## 🛡️ 4. Maximum Drawdown Control

Never risk more than your maximum acceptable drawdown across all open positions.

### Formula

```
Max Concurrent Risk = Max Drawdown Tolerance / Average Correlation Factor

Example:
Max Drawdown Tolerance = 20%
Average Correlation = 0.5 (partially correlated pairs)
Max Concurrent Risk = 20% / 0.5 = 40% total exposure
```

### Position Limit Calculation

```
Max Positions = Max Concurrent Risk / Risk Per Trade

Example:
Max Concurrent Risk = 40%
Risk Per Trade = 2%
Max Positions = 40% / 2% = 20 positions
```

### MQL5 Implementation

```mql5
input double MaxDrawdownPercent = 20.0;  // Maximum portfolio drawdown
input double RiskPerTrade = 2.0;         // Risk per trade

bool CanOpenNewPosition()
{
    double currentRisk = CalculateOpenRisk();
    double newTradeRisk = RiskPerTrade;
    
    return (currentRisk + newTradeRisk) <= MaxDrawdownPercent;
}

double CalculateOpenRisk()
{
    double totalRisk = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            double positionRisk = CalculatePositionRisk();
            totalRisk += positionRisk;
        }
    }
    
    return totalRisk;
}
```

---

## 📋 5. Risk Management Checklist

Before every trade, verify:

- [ ] Position size calculated correctly
- [ ] Risk does not exceed 2% per trade
- [ ] Total open risk below maximum drawdown limit
- [ ] Stop loss placed at logical level (not arbitrary)
- [ ] Risk/Reward ratio minimum 1:1.5
- [ ] Correlation with existing positions considered

---

## 🔗 Related Documents

- [02-drawdown-recovery.md](./02-drawdown-recovery.md) - Drawdown recovery strategies
- [03-correlation-analysis.md](./03-correlation-analysis.md) - Multi-pair correlation
- [04-monte-carlo.md](./04-monte-carlo.md) - Monte Carlo simulation for risk

---

## 📚 References

- Van Tharp, "Trade Your Way to Financial Freedom"
- Ralph Vince, "The Mathematics of Money Management"
- Ed Seykota, "Risk Management and Trading Psychology"

---

*Part of the [Algorithmic Trading](https://github.com/e49nana/Algorithmic-trading) repository*

*Last updated: January 20, 2026*
