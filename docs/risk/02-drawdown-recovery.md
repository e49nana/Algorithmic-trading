# Drawdown Recovery Strategies

## 📉 Introduction

Drawdown is inevitable in trading. What separates professionals from amateurs is how they manage recovery. This document covers mathematical frameworks for understanding and recovering from drawdowns.

---

## 🔢 1. The Mathematics of Drawdown

### Recovery Formula

The percentage gain needed to recover from a loss is always greater than the loss itself:

```
Recovery % = (1 / (1 - Loss%)) - 1

Or simplified:
Recovery % = Loss% / (1 - Loss%)
```

### Recovery Table

| Drawdown | Required Recovery | Difficulty |
|----------|-------------------|------------|
| 5% | 5.26% | Easy |
| 10% | 11.11% | Manageable |
| 20% | 25.00% | Challenging |
| 30% | 42.86% | Difficult |
| 40% | 66.67% | Very Hard |
| 50% | 100.00% | Extreme |
| 60% | 150.00% | Nearly Impossible |
| 70% | 233.33% | Account Reset |

### Key Insight

> **Never let drawdown exceed 20-25%.** Beyond this point, recovery becomes exponentially harder.

### MQL5 Implementation

```mql5
double CalculateRequiredRecovery(double drawdownPercent)
{
    if(drawdownPercent >= 100) return -1; // Account blown
    return (drawdownPercent / (100.0 - drawdownPercent)) * 100.0;
}

double GetCurrentDrawdown()
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double peak = MathMax(balance, equity); // Simplified - use stored peak in production
    
    return ((peak - equity) / peak) * 100.0;
}
```

---

## 🎚️ 2. Dynamic Position Sizing During Drawdown

### Anti-Martingale Approach

**Reduce** position size during losing streaks, **increase** during winning streaks.

```
Adjusted Risk = Base Risk × (1 - Drawdown Factor)

Where:
Drawdown Factor = Current Drawdown / Max Allowed Drawdown
```

### Example

| Parameter | Value |
|-----------|-------|
| Base Risk | 2% |
| Current Drawdown | 10% |
| Max Allowed Drawdown | 20% |

```
Drawdown Factor = 10% / 20% = 0.5
Adjusted Risk = 2% × (1 - 0.5) = 1%
```

### MQL5 Implementation

```mql5
input double BaseRiskPercent = 2.0;      // Normal risk per trade
input double MaxDrawdownPercent = 20.0;  // Maximum acceptable drawdown
input double MinRiskPercent = 0.5;       // Minimum risk floor

double peakBalance = 0;

int OnInit()
{
    peakBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    return(INIT_SUCCEEDED);
}

void OnTick()
{
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    if(currentBalance > peakBalance)
        peakBalance = currentBalance;
}

double GetAdjustedRisk()
{
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double drawdown = ((peakBalance - currentBalance) / peakBalance) * 100.0;
    
    if(drawdown <= 0) 
        return BaseRiskPercent;
    
    double drawdownFactor = drawdown / MaxDrawdownPercent;
    drawdownFactor = MathMin(drawdownFactor, 0.9); // Cap at 90% reduction
    
    double adjustedRisk = BaseRiskPercent * (1.0 - drawdownFactor);
    
    return MathMax(MinRiskPercent, adjustedRisk);
}
```

---

## 📊 3. Equity Curve Trading

Trade your own equity curve - reduce exposure when your system underperforms.

### Moving Average Filter

```
If Equity > MA(Equity, N): Trade normally
If Equity < MA(Equity, N): Reduce size or pause
```

### Implementation Strategy

```mql5
input int EquityMAPeriod = 20;           // Trades for MA calculation
input double ReducedRiskMultiplier = 0.5; // Risk multiplier when below MA

double equityHistory[];
int equityIndex = 0;

void UpdateEquityHistory()
{
    if(ArraySize(equityHistory) < EquityMAPeriod)
        ArrayResize(equityHistory, EquityMAPeriod);
    
    equityHistory[equityIndex % EquityMAPeriod] = AccountInfoDouble(ACCOUNT_EQUITY);
    equityIndex++;
}

double GetEquityMA()
{
    int count = MathMin(equityIndex, EquityMAPeriod);
    if(count == 0) return AccountInfoDouble(ACCOUNT_EQUITY);
    
    double sum = 0;
    for(int i = 0; i < count; i++)
        sum += equityHistory[i];
    
    return sum / count;
}

double GetEquityCurveAdjustedRisk(double baseRisk)
{
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double equityMA = GetEquityMA();
    
    if(currentEquity >= equityMA)
        return baseRisk;
    else
        return baseRisk * ReducedRiskMultiplier;
}
```

---

## 🔄 4. Recovery Modes

### Mode 1: Conservative Recovery

Reduce risk and wait for equity to stabilize.

```
Trigger: Drawdown > 10%
Action: Reduce risk to 50% of normal
Exit: 5 consecutive winning trades OR drawdown < 5%
```

### Mode 2: Selective Trading

Only take A+ setups during drawdown.

```
Trigger: Drawdown > 15%
Action: 
  - Increase minimum R:R to 1:2.5
  - Require confluence of 3+ signals
  - Trade only during optimal sessions
Exit: Drawdown < 10%
```

### Mode 3: Trading Pause

Stop trading to break losing psychology.

```
Trigger: Drawdown > 20% OR 5 consecutive losses
Action: 
  - Close all positions
  - No new trades for 24-48 hours
  - Review and journal all losing trades
Exit: Mental reset confirmed + market analysis updated
```

### MQL5 State Machine

```mql5
enum RECOVERY_MODE
{
    MODE_NORMAL,
    MODE_CONSERVATIVE,
    MODE_SELECTIVE,
    MODE_PAUSE
};

RECOVERY_MODE currentMode = MODE_NORMAL;
int consecutiveLosses = 0;

RECOVERY_MODE EvaluateRecoveryMode()
{
    double drawdown = GetCurrentDrawdown();
    
    // Check pause conditions first
    if(drawdown > 20.0 || consecutiveLosses >= 5)
        return MODE_PAUSE;
    
    // Check selective mode
    if(drawdown > 15.0)
        return MODE_SELECTIVE;
    
    // Check conservative mode
    if(drawdown > 10.0)
        return MODE_CONSERVATIVE;
    
    // Check exit conditions for recovery modes
    if(currentMode == MODE_CONSERVATIVE && drawdown < 5.0)
        return MODE_NORMAL;
    
    if(currentMode == MODE_SELECTIVE && drawdown < 10.0)
        return MODE_CONSERVATIVE;
    
    return currentMode;
}

bool CanTrade()
{
    currentMode = EvaluateRecoveryMode();
    
    switch(currentMode)
    {
        case MODE_PAUSE:
            return false;
        case MODE_SELECTIVE:
            return IsHighQualitySetup(); // Custom function
        default:
            return true;
    }
}

double GetModeAdjustedRisk(double baseRisk)
{
    switch(currentMode)
    {
        case MODE_CONSERVATIVE:
            return baseRisk * 0.5;
        case MODE_SELECTIVE:
            return baseRisk * 0.75;
        default:
            return baseRisk;
    }
}
```

---

## 📈 5. Recovery Time Estimation

### Formula

```
Estimated Trades = ln(1 + Recovery%) / ln(1 + Avg_Win% × Win_Rate - Avg_Loss% × Loss_Rate)
```

### Simplified Expectancy Method

```
Expectancy = (Win% × Avg_Win) - (Loss% × Avg_Loss)
Recovery Trades ≈ Drawdown Amount / (Account × Expectancy × Avg_Risk)
```

### MQL5 Implementation

```mql5
struct TradingStats
{
    double winRate;
    double avgWinPercent;
    double avgLossPercent;
    double expectancy;
};

TradingStats CalculateStats()
{
    TradingStats stats;
    
    int wins = 0, losses = 0;
    double totalWinPercent = 0, totalLossPercent = 0;
    
    HistorySelect(0, TimeCurrent());
    int deals = HistoryDealsTotal();
    
    for(int i = 0; i < deals; i++)
    {
        ulong ticket = HistoryDealGetTicket(i);
        double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
        double balance = AccountInfoDouble(ACCOUNT_BALANCE); // Simplified
        
        if(profit > 0)
        {
            wins++;
            totalWinPercent += (profit / balance) * 100;
        }
        else if(profit < 0)
        {
            losses++;
            totalLossPercent += MathAbs(profit / balance) * 100;
        }
    }
    
    int total = wins + losses;
    if(total == 0) return stats;
    
    stats.winRate = (double)wins / total;
    stats.avgWinPercent = wins > 0 ? totalWinPercent / wins : 0;
    stats.avgLossPercent = losses > 0 ? totalLossPercent / losses : 0;
    stats.expectancy = (stats.winRate * stats.avgWinPercent) - 
                       ((1 - stats.winRate) * stats.avgLossPercent);
    
    return stats;
}

int EstimateRecoveryTrades(double drawdownPercent)
{
    TradingStats stats = CalculateStats();
    
    if(stats.expectancy <= 0)
        return -1; // System has negative expectancy
    
    return (int)MathCeil(drawdownPercent / stats.expectancy);
}
```

---

## 📋 6. Recovery Protocol Checklist

When entering drawdown:

- [ ] Calculate exact drawdown percentage
- [ ] Determine recovery mode (Conservative/Selective/Pause)
- [ ] Adjust position sizing accordingly
- [ ] Review last 10 trades for pattern recognition
- [ ] Check if market conditions have changed
- [ ] Update trading journal with observations
- [ ] Set realistic recovery timeline

When exiting drawdown:

- [ ] Gradually increase position size (don't jump back to full risk)
- [ ] Confirm 3+ winning trades before normalizing
- [ ] Document what worked during recovery
- [ ] Update system parameters if needed

---

## ⚠️ 7. Common Recovery Mistakes

| Mistake | Why It Fails | Solution |
|---------|--------------|----------|
| Revenge trading | Emotional, oversized positions | Implement MODE_PAUSE |
| Martingale | Exponential risk increase | Use Anti-Martingale |
| Ignoring the drawdown | Deeper losses | Strict mode triggers |
| Changing systems | No consistency for analysis | Stick to plan, adjust size |
| Over-optimization | Curve fitting to recent data | Use out-of-sample testing |

---

## 🔗 Related Documents

- [01-position-sizing.md](./01-position-sizing.md) - Position sizing fundamentals
- [03-correlation-analysis.md](./03-correlation-analysis.md) - Multi-pair correlation
- [04-monte-carlo.md](./04-monte-carlo.md) - Monte Carlo simulation

---

## 📚 References

- Mark Douglas, "Trading in the Zone"
- Brett Steenbarger, "The Psychology of Trading"
- Van Tharp, "Trade Your Way to Financial Freedom"

---

*Part of the [Algorithmic Trading](https://github.com/e49nana/Algorithmic-trading) repository*

*Last updated: January 21, 2026*
