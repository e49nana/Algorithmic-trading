# Risk Management Framework

Short reference behind the risk logic of the EAs in this repository. Detailed notes:

1. [Position sizing](01-position-sizing.md)
2. [Drawdown recovery](02-drawdown-recovery.md)
3. [Monte Carlo validation](03-monte-carlo.md) — code in [`python/monte_carlo.py`](../../python/monte_carlo.py)

## Position Sizing Methods

### Fixed Fractional Method
Risk a fixed percentage of account equity per trade.

```
Position Size = (Account Equity × Risk %) / (Entry Price - Stop Loss)
```

**Example**: 
- Account: €10,000
- Risk per trade: 1% (€100)
- Entry: 1.1000, Stop Loss: 1.0950 (50 pips)
- Position Size = €100 / 0.0050 = 20,000 units (0.2 lots)

### Kelly Criterion (Simplified)
Optimal bet sizing based on win rate and reward-to-risk ratio.

```
Kelly % = W - [(1 - W) / R]
```
Where:
- W = Win rate (decimal)
- R = Average Win / Average Loss

**Note**: Most traders use fractional Kelly (25-50%) to reduce volatility.

## Risk Limits

| Parameter | Conservative | Moderate | Aggressive |
|-----------|-------------|----------|------------|
| Risk per trade | 0.5% | 1-2% | 3-5% |
| Daily drawdown limit | 2% | 5% | 10% |
| Max correlated positions | 2 | 3 | 5 |
| Max total exposure | 5% | 10% | 20% |

## Implementation in NinjaTrader

```csharp
private double CalculatePositionSize(double entryPrice, double stopLoss, double riskPercent)
{
    double accountSize = Account.Get(AccountItem.CashValue, Currency.UsDollar);
    double riskAmount = accountSize * (riskPercent / 100);
    double pointValue = Instrument.MasterInstrument.PointValue; // e.g. MES = 5 USD per point
    double riskPerContract = Math.Abs(entryPrice - stopLoss) * pointValue;
    
    return riskPerContract > 0 ? Math.Floor(riskAmount / riskPerContract) : 0;
}
```

## Drawdown Recovery

The math of recovery — why protecting capital matters:

| Drawdown | Required Gain to Recover |
|----------|-------------------------|
| 10% | 11.1% |
| 20% | 25% |
| 30% | 42.9% |
| 50% | 100% |
| 70% | 233% |

## Risk Checklist (Before Each Trade)

- [ ] Position size calculated based on stop loss distance
- [ ] Risk ≤ 1-2% of account
- [ ] No correlated positions already open
- [ ] Daily drawdown limit not reached
- [ ] Risk/Reward ratio ≥ 1:2

---

*Author: [Emmanuel Nana Nana](https://github.com/e49nana)*
