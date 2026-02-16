# Monte Carlo Simulation for Trading Systems

## 🎲 Introduction

Backtesting shows you ONE possible outcome. Monte Carlo simulation shows you THOUSANDS. It answers the critical question: "How bad could it realistically get?" This document covers Monte Carlo methods for validating trading systems and setting realistic expectations.

---

## 🔢 1. Monte Carlo Fundamentals

### What Monte Carlo Does

```
1. Take your historical trades
2. Randomly reorder them (shuffle)
3. Calculate equity curve, drawdown, returns
4. Repeat 1000-10000 times
5. Analyze the distribution of outcomes
```

### Why Order Matters

Same trades, different order = different drawdown:

| Trade Sequence | Running P/L | Max Drawdown |
|----------------|-------------|--------------|
| +100, +50, -80, -60, +90 | +100 | -140 (from +150 to +10) |
| -80, -60, +100, +50, +90 | +100 | -140 (from 0 to -140) |
| +100, -80, +50, -60, +90 | +100 | -80 |
| -60, +90, -80, +100, +50 | +100 | -60 |

Same total profit, but max drawdown ranges from -60 to -140!

---

## 🧮 2. Basic Monte Carlo Implementation

### Trade Shuffling Method

```mql5
class CMonteCarlo
{
private:
    double m_trades[];
    int m_tradeCount;
    int m_simulations;
    
    // Results
    double m_maxDrawdowns[];
    double m_finalEquities[];
    double m_maxRunups[];
    
public:
    CMonteCarlo(double &trades[], int simulations = 10000)
    {
        m_tradeCount = ArraySize(trades);
        ArrayResize(m_trades, m_tradeCount);
        ArrayCopy(m_trades, trades);
        
        m_simulations = simulations;
        ArrayResize(m_maxDrawdowns, simulations);
        ArrayResize(m_finalEquities, simulations);
        ArrayResize(m_maxRunups, simulations);
    }
    
    void Run(double startingCapital = 10000)
    {
        for(int sim = 0; sim < m_simulations; sim++)
        {
            double shuffled[];
            ShuffleTrades(shuffled);
            
            SimulationResult result = SimulateEquityCurve(shuffled, startingCapital);
            
            m_maxDrawdowns[sim] = result.maxDrawdownPercent;
            m_finalEquities[sim] = result.finalEquity;
            m_maxRunups[sim] = result.maxRunup;
        }
        
        // Sort for percentile calculations
        ArraySort(m_maxDrawdowns);
        ArraySort(m_finalEquities);
    }
    
private:
    void ShuffleTrades(double &output[])
    {
        ArrayResize(output, m_tradeCount);
        ArrayCopy(output, m_trades);
        
        // Fisher-Yates shuffle
        for(int i = m_tradeCount - 1; i > 0; i--)
        {
            int j = MathRand() % (i + 1);
            double temp = output[i];
            output[i] = output[j];
            output[j] = temp;
        }
    }
    
    struct SimulationResult
    {
        double maxDrawdownPercent;
        double finalEquity;
        double maxRunup;
    };
    
    SimulationResult SimulateEquityCurve(double &trades[], double startingCapital)
    {
        SimulationResult result;
        
        double equity = startingCapital;
        double peak = startingCapital;
        double maxDrawdown = 0;
        double maxRunup = 0;
        
        for(int i = 0; i < ArraySize(trades); i++)
        {
            equity += trades[i];
            
            if(equity > peak)
            {
                peak = equity;
            }
            
            double drawdown = (peak - equity) / peak * 100;
            if(drawdown > maxDrawdown)
                maxDrawdown = drawdown;
            
            double runup = (equity - startingCapital) / startingCapital * 100;
            if(runup > maxRunup)
                maxRunup = runup;
        }
        
        result.maxDrawdownPercent = maxDrawdown;
        result.finalEquity = equity;
        result.maxRunup = maxRunup;
        
        return result;
    }
};
```

### Getting Results

```mql5
// Continuation of CMonteCarlo class

public:
    double GetDrawdownPercentile(double percentile)
    {
        int index = (int)(m_simulations * percentile / 100.0);
        index = MathMin(index, m_simulations - 1);
        return m_maxDrawdowns[index];
    }
    
    double GetEquityPercentile(double percentile)
    {
        int index = (int)(m_simulations * percentile / 100.0);
        index = MathMin(index, m_simulations - 1);
        return m_finalEquities[index];
    }
    
    double GetAverageDrawdown()
    {
        double sum = 0;
        for(int i = 0; i < m_simulations; i++)
            sum += m_maxDrawdowns[i];
        return sum / m_simulations;
    }
    
    double GetWorstDrawdown()
    {
        return m_maxDrawdowns[m_simulations - 1];  // Array is sorted
    }
    
    double GetBestDrawdown()
    {
        return m_maxDrawdowns[0];
    }
    
    void PrintReport()
    {
        Print("=== MONTE CARLO REPORT ===");
        Print("Simulations: ", m_simulations);
        Print("Trades per simulation: ", m_tradeCount);
        Print("");
        Print("--- DRAWDOWN ANALYSIS ---");
        Print("Best case: ", DoubleToString(GetBestDrawdown(), 2), "%");
        Print("5th percentile: ", DoubleToString(GetDrawdownPercentile(5), 2), "%");
        Print("25th percentile: ", DoubleToString(GetDrawdownPercentile(25), 2), "%");
        Print("Median (50th): ", DoubleToString(GetDrawdownPercentile(50), 2), "%");
        Print("75th percentile: ", DoubleToString(GetDrawdownPercentile(75), 2), "%");
        Print("95th percentile: ", DoubleToString(GetDrawdownPercentile(95), 2), "%");
        Print("99th percentile: ", DoubleToString(GetDrawdownPercentile(99), 2), "%");
        Print("Worst case: ", DoubleToString(GetWorstDrawdown(), 2), "%");
        Print("");
        Print("--- RECOMMENDATION ---");
        Print("Expect drawdown up to: ", DoubleToString(GetDrawdownPercentile(95), 2), "%");
        Print("Prepare for drawdown of: ", DoubleToString(GetDrawdownPercentile(99), 2), "%");
    }
};
```

---

## 📊 3. Advanced: Parameter Perturbation

Test system robustness by varying parameters.

### Concept

```
Original system: SL=50, TP=100, MA=20
Perturbed: SL=45-55, TP=90-110, MA=18-22

If small changes destroy profitability → System is overfit
If results remain stable → System is robust
```

### Implementation

```mql5
struct SystemParameters
{
    int stopLoss;
    int takeProfit;
    int maPeriod;
    double riskPercent;
};

class CParameterMonteCarlo
{
private:
    SystemParameters m_baseParams;
    double m_perturbRange;  // e.g., 0.1 = ±10%
    int m_simulations;
    
public:
    CParameterMonteCarlo(SystemParameters &base, double perturbRange, int sims)
    {
        m_baseParams = base;
        m_perturbRange = perturbRange;
        m_simulations = sims;
    }
    
    void Run()
    {
        double profits[];
        ArrayResize(profits, m_simulations);
        
        for(int sim = 0; sim < m_simulations; sim++)
        {
            SystemParameters perturbed = PerturbParameters();
            profits[sim] = BacktestWithParams(perturbed);
        }
        
        AnalyzeRobustness(profits);
    }
    
private:
    SystemParameters PerturbParameters()
    {
        SystemParameters p;
        
        p.stopLoss = PerturbInt(m_baseParams.stopLoss);
        p.takeProfit = PerturbInt(m_baseParams.takeProfit);
        p.maPeriod = PerturbInt(m_baseParams.maPeriod);
        p.riskPercent = PerturbDouble(m_baseParams.riskPercent);
        
        return p;
    }
    
    int PerturbInt(int value)
    {
        double range = value * m_perturbRange;
        double perturbation = (MathRand() / 32767.0 - 0.5) * 2 * range;
        return (int)MathRound(value + perturbation);
    }
    
    double PerturbDouble(double value)
    {
        double range = value * m_perturbRange;
        double perturbation = (MathRand() / 32767.0 - 0.5) * 2 * range;
        return value + perturbation;
    }
    
    double BacktestWithParams(SystemParameters &params)
    {
        // Run backtest with perturbed parameters
        // Return net profit
        return 0; // Placeholder
    }
    
    void AnalyzeRobustness(double &profits[])
    {
        int profitable = 0;
        double sum = 0;
        
        for(int i = 0; i < m_simulations; i++)
        {
            sum += profits[i];
            if(profits[i] > 0) profitable++;
        }
        
        double profitablePercent = (double)profitable / m_simulations * 100;
        double avgProfit = sum / m_simulations;
        
        Print("=== ROBUSTNESS ANALYSIS ===");
        Print("Profitable variations: ", DoubleToString(profitablePercent, 1), "%");
        Print("Average profit: ", DoubleToString(avgProfit, 2));
        
        if(profitablePercent < 70)
            Print("WARNING: System may be overfit!");
        else if(profitablePercent > 90)
            Print("System appears robust.");
    }
};
```

---

## 🎯 4. Confidence Intervals

### Calculating System Confidence

```mql5
struct ConfidenceInterval
{
    double lower;
    double upper;
    double confidence;  // e.g., 95%
};

ConfidenceInterval CalculateReturnCI(double &trades[], double confidence = 95)
{
    CMonteCarlo mc(trades, 10000);
    mc.Run(10000);
    
    double lowerPercentile = (100 - confidence) / 2;      // 2.5 for 95%
    double upperPercentile = 100 - lowerPercentile;       // 97.5 for 95%
    
    ConfidenceInterval ci;
    ci.lower = mc.GetEquityPercentile(lowerPercentile);
    ci.upper = mc.GetEquityPercentile(upperPercentile);
    ci.confidence = confidence;
    
    return ci;
}

void PrintConfidenceReport(ConfidenceInterval &ci, double startingCapital)
{
    double lowerReturn = (ci.lower - startingCapital) / startingCapital * 100;
    double upperReturn = (ci.upper - startingCapital) / startingCapital * 100;
    
    Print("=== ", DoubleToString(ci.confidence, 0), "% CONFIDENCE INTERVAL ===");
    Print("Return range: ", DoubleToString(lowerReturn, 2), "% to ", 
          DoubleToString(upperReturn, 2), "%");
    Print("Equity range: $", DoubleToString(ci.lower, 2), " to $", 
          DoubleToString(ci.upper, 2));
}
```

---

## 📉 5. Risk of Ruin Analysis

### Probability of Account Destruction

```mql5
double CalculateRiskOfRuin(double &trades[], double ruinThreshold = 50, 
                           int simulations = 10000)
{
    int ruinCount = 0;
    double startingCapital = 10000;
    double ruinLevel = startingCapital * (1 - ruinThreshold / 100);
    
    for(int sim = 0; sim < simulations; sim++)
    {
        double shuffled[];
        ShuffleTrades(trades, shuffled);
        
        double equity = startingCapital;
        bool ruined = false;
        
        for(int i = 0; i < ArraySize(shuffled) && !ruined; i++)
        {
            equity += shuffled[i];
            if(equity <= ruinLevel)
                ruined = true;
        }
        
        if(ruined) ruinCount++;
    }
    
    return (double)ruinCount / simulations * 100;
}

void ShuffleTrades(double &input[], double &output[])
{
    int n = ArraySize(input);
    ArrayResize(output, n);
    ArrayCopy(output, input);
    
    for(int i = n - 1; i > 0; i--)
    {
        int j = MathRand() % (i + 1);
        double temp = output[i];
        output[i] = output[j];
        output[j] = temp;
    }
}
```

### Risk of Ruin Table

```mql5
void PrintRiskOfRuinTable(double &trades[])
{
    Print("=== RISK OF RUIN ANALYSIS ===");
    Print("Ruin Level | Probability");
    Print("------------------------");
    
    double thresholds[] = {20, 30, 40, 50, 60, 70, 80};
    
    for(int i = 0; i < ArraySize(thresholds); i++)
    {
        double ror = CalculateRiskOfRuin(trades, thresholds[i], 5000);
        Print(DoubleToString(thresholds[i], 0), "% loss  | ", 
              DoubleToString(ror, 2), "%");
    }
}
```

### Example Output

```
=== RISK OF RUIN ANALYSIS ===
Ruin Level | Probability
------------------------
20% loss   | 45.32%
30% loss   | 23.18%
40% loss   | 8.54%
50% loss   | 2.12%
60% loss   | 0.34%
70% loss   | 0.02%
80% loss   | 0.00%
```

---

## 🔄 6. Sequential Dependency Test

Check if your system has patterns (streaks) that matter.

### Runs Test

```mql5
struct RunsTestResult
{
    int totalRuns;
    double expectedRuns;
    double zScore;
    bool isRandom;
};

RunsTestResult PerformRunsTest(double &trades[])
{
    RunsTestResult result;
    
    int n = ArraySize(trades);
    int wins = 0, losses = 0;
    int runs = 1;
    
    // Count wins/losses
    for(int i = 0; i < n; i++)
    {
        if(trades[i] > 0) wins++;
        else losses++;
    }
    
    // Count runs (sequences of same sign)
    for(int i = 1; i < n; i++)
    {
        bool currentWin = trades[i] > 0;
        bool previousWin = trades[i-1] > 0;
        
        if(currentWin != previousWin)
            runs++;
    }
    
    // Calculate expected runs
    double n1 = wins;
    double n2 = losses;
    double expectedRuns = (2 * n1 * n2) / (n1 + n2) + 1;
    
    // Standard deviation of runs
    double variance = (2 * n1 * n2 * (2 * n1 * n2 - n1 - n2)) / 
                      ((n1 + n2) * (n1 + n2) * (n1 + n2 - 1));
    double stdDev = MathSqrt(variance);
    
    // Z-score
    double zScore = (runs - expectedRuns) / stdDev;
    
    result.totalRuns = runs;
    result.expectedRuns = expectedRuns;
    result.zScore = zScore;
    result.isRandom = MathAbs(zScore) < 1.96;  // 95% confidence
    
    return result;
}

void PrintRunsTestReport(RunsTestResult &result)
{
    Print("=== RUNS TEST (Sequential Dependency) ===");
    Print("Total runs: ", result.totalRuns);
    Print("Expected runs: ", DoubleToString(result.expectedRuns, 2));
    Print("Z-score: ", DoubleToString(result.zScore, 2));
    Print("");
    
    if(result.isRandom)
    {
        Print("Result: Trade sequence appears RANDOM");
        Print("Monte Carlo shuffling is appropriate.");
    }
    else if(result.zScore > 1.96)
    {
        Print("Result: More runs than expected (ALTERNATING pattern)");
        Print("Consider: Mean reversion may be present.");
    }
    else
    {
        Print("Result: Fewer runs than expected (STREAKY pattern)");
        Print("Consider: Momentum/trending in results.");
        Print("WARNING: Standard Monte Carlo may underestimate risk!");
    }
}
```

---

## 📋 7. Complete Monte Carlo Workflow

```mql5
void RunCompleteMonteCarlo(double &trades[], double startingCapital = 10000)
{
    Print("========================================");
    Print("   COMPLETE MONTE CARLO ANALYSIS");
    Print("========================================");
    Print("");
    
    // Step 1: Runs test
    RunsTestResult runsTest = PerformRunsTest(trades);
    PrintRunsTestReport(runsTest);
    Print("");
    
    // Step 2: Basic Monte Carlo
    CMonteCarlo mc(trades, 10000);
    mc.Run(startingCapital);
    mc.PrintReport();
    Print("");
    
    // Step 3: Confidence intervals
    ConfidenceInterval ci95 = CalculateReturnCI(trades, 95);
    ConfidenceInterval ci99 = CalculateReturnCI(trades, 99);
    PrintConfidenceReport(ci95, startingCapital);
    PrintConfidenceReport(ci99, startingCapital);
    Print("");
    
    // Step 4: Risk of ruin
    PrintRiskOfRuinTable(trades);
    Print("");
    
    // Step 5: Summary recommendations
    Print("=== RECOMMENDATIONS ===");
    Print("1. Set max drawdown stop at: ", 
          DoubleToString(mc.GetDrawdownPercentile(95) * 1.2, 1), "%");
    Print("2. Expected typical drawdown: ", 
          DoubleToString(mc.GetDrawdownPercentile(50), 1), "%");
    Print("3. If drawdown exceeds ", 
          DoubleToString(mc.GetDrawdownPercentile(99), 1), 
          "%, system may be broken");
    
    if(!runsTest.isRandom)
    {
        Print("4. WARNING: Results show non-random patterns.");
        Print("   Consider block-bootstrap instead of simple shuffle.");
    }
}
```

---

## 📊 8. Interpreting Results

### Decision Matrix

| 95th Percentile DD | Risk of 50% Ruin | Action |
|--------------------|------------------|--------|
| < 15% | < 1% | Trade with confidence |
| 15-25% | 1-5% | Trade with reduced size |
| 25-35% | 5-15% | Review system parameters |
| > 35% | > 15% | Do not trade live |

### Red Flags

- 95th percentile DD is 2x+ median DD → Fat tail risk
- Risk of ruin > 10% at any level → Reduce position size
- Runs test shows streaks → Results may be correlated
- Parameter perturbation kills profitability → Overfit

---

## 📋 9. Monte Carlo Checklist

Before going live:

- [ ] Run 10,000+ simulations minimum
- [ ] Check runs test for sequential dependency
- [ ] 95th percentile drawdown is acceptable
- [ ] Risk of 50% ruin is < 5%
- [ ] Parameter perturbation shows > 70% profitable
- [ ] Confidence intervals are realistic for your goals
- [ ] Set hard stop at 99th percentile drawdown

---

## 🔗 Related Documents

- [01-position-sizing.md](./01-position-sizing.md) - Position sizing fundamentals
- [02-drawdown-recovery.md](./02-drawdown-recovery.md) - Drawdown recovery strategies
- [03-correlation-analysis.md](./03-correlation-analysis.md) - Multi-pair correlation

---

## 📚 References

- David Aronson, "Evidence-Based Technical Analysis"
- Robert Pardo, "The Evaluation and Optimization of Trading Strategies"
- Ernest Chan, "Quantitative Trading"

---

*Part of the [Algorithmic Trading](https://github.com/e49nana/Algorithmic-trading) repository*

*Last updated: January 23, 2026*
