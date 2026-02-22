//+------------------------------------------------------------------+
//|                                          SafeScalperPro_v3.mq5   |
//|                Professional Breakout Scalping EA v3.0             |
//|                                                                  |
//|  =============================================================  |
//|  STRATEGY:                                                       |
//|    EMA 50/200 Trend Direction + Trend Strength (ATR-based)       |
//|    + Breakout Detection + RSI Filter + Momentum Confirmation     |
//|    All 6 conditions must align for entry.                        |
//|                                                                  |
//|  PAIRS:      XAUUSD, XAGUSD, Forex majors                       |
//|  TIMEFRAME:  M5, M15                                             |
//|  RISK:       Conservative. No martingale. No grid. No hedging.   |
//|              Fixed SL/TP. One trade at a time.                   |
//|                                                                  |
//|  ARCHITECTURE (4 modules):                                       |
//|    SSPCore.mqh      - Enums, structs, logging, utilities         |
//|    SSPTrading.mqh   - Order execution, risk, breakeven, stats    |
//|    SSPStrategy.mqh  - Indicators, signal gen, all filters        |
//|    SSPDashboard.mqh - Premium dark GUI (cockpit + analytics)     |
//|  =============================================================  |
//+------------------------------------------------------------------+
#property copyright   "AlgoSphere Quant"
#property link        "https://www.mql5.com/en/users/algosphere-quant"
#property version     "3.10"
#property description "SafeScalperPro v3.1 - Professional Breakout Scalping System"
#property description "EMA 50/200 Trend + RSI + Breakout + Premium Dashboard"
#property description "Conservative risk | No martingale/grid/hedging"
#property strict

//+------------------------------------------------------------------+
//| INCLUDES                                                         |
//+------------------------------------------------------------------+
#include <SafeScalperPro\SSPCore.mqh>
#include <SafeScalperPro\SSPTrading.mqh>
#include <SafeScalperPro\SSPStrategy.mqh>
#include <SafeScalperPro\SSPDashboard.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+

input string _I0_ = "=========================================="; // ====== GENERAL ======
input int               InpMagicNumber      = 202503;            // Magic Number
input string            InpTradeComment     = "SSPv3";           // Trade Comment
input int               InpMaxSlippage      = 10;                // Max Slippage (points)
input ENUM_SSP_LOG_LEVEL InpLogLevel        = SSP_LOG_INFO;      // Log Level

input string _I1_ = "=========================================="; // ====== RISK MANAGEMENT ======
input ENUM_SSP_LOT_MODE InpLotMode          = SSP_LOT_FIXED;    // Lot Sizing Mode
input double            InpFixedLots        = 0.01;              // Fixed Lot Size
input double            InpRiskPercent      = 1.0;               // Risk % per Trade (if % mode)
input double            InpMaxDrawdownPct   = 10.0;              // Max Drawdown % (pause EA)

input string _I2_ = "=========================================="; // ====== STOP LOSS & TAKE PROFIT ======
input int               InpStopLoss         = 150;               // Stop Loss (points)
input int               InpTakeProfit       = 200;               // Take Profit (points)
input bool              InpUseBreakeven     = true;              // Use Breakeven
input int               InpBreakevenStart   = 100;               // BE Trigger (points in profit)
input int               InpBreakevenOffset  = 10;                // BE Offset (points above entry)

input string _I3_ = "=========================================="; // ====== EMA TREND FILTER ======
input int               InpEmaFast          = 50;                // Fast EMA Period
input int               InpEmaSlow          = 200;               // Slow EMA Period
input ENUM_SSP_TREND_STRENGTH InpTrendStrength = SSP_TREND_MODERATE; // Trend Strength Filter

input string _I4_ = "=========================================="; // ====== RSI FILTER ======
input int               InpRsiPeriod        = 14;                // RSI Period
input double            InpRsiBuyMin        = 40.0;              // RSI Buy Min (above this)
input double            InpRsiBuyMax        = 65.0;              // RSI Buy Max (below this)
input double            InpRsiSellMin       = 35.0;              // RSI Sell Min (above this)
input double            InpRsiSellMax       = 60.0;              // RSI Sell Max (below this)

input string _I5_ = "=========================================="; // ====== BREAKOUT DETECTION ======
input int               InpBreakoutLookback = 20;                // Lookback Bars
input double            InpBreakoutBuffer   = 0.5;               // Buffer (x ATR)
input int               InpAtrPeriod        = 14;                // ATR Period

input string _I6_ = "=========================================="; // ====== SESSION FILTER ======
input bool              InpUseSessionFilter = true;              // Enable Session Filter
input int               InpSessionStartHour = 8;                 // Start Hour (server time)
input int               InpSessionStartMin  = 0;                 // Start Minute
input int               InpSessionEndHour   = 20;                // End Hour
input int               InpSessionEndMin    = 0;                 // End Minute
input bool              InpAvoidFriday      = true;              // Avoid Friday Afternoon
input int               InpFridayCutoffHour = 16;                // Friday Cutoff Hour

input string _I7_ = "=========================================="; // ====== SPREAD FILTER ======
input bool              InpUseSpreadFilter  = true;              // Enable Spread Filter
input int               InpMaxSpread        = 30;                // Max Spread (points)

input string _I8_ = "=========================================="; // ====== NEWS FILTER ======
input bool              InpUseNewsFilter    = true;              // Enable News Filter
input string            InpNewsTime1        = "";                // News Time 1 (HH:MM)
input string            InpNewsTime2        = "";                // News Time 2
input string            InpNewsTime3        = "";                // News Time 3
input int               InpNewsMinsBefore   = 30;                // Minutes Before News
input int               InpNewsMinsAfter    = 15;                // Minutes After News

input string _I9_ = "=========================================="; // ====== DISPLAY ======
input bool              InpShowDashboard    = true;              // Show Dashboard
input bool              InpSyncChartTheme   = true;              // Apply Dark Theme
input bool              InpShowAnalytics    = true;              // Show Analytics Panel

//+------------------------------------------------------------------+
//| GLOBAL MODULE INSTANCES                                          |
//+------------------------------------------------------------------+
CSSPTrading    g_engine;        // Trading engine (orders, risk, stats)
CSSPStrategy   g_strategy;      // Strategy engine (indicators, signals, filters)
CSSPDashboard  g_dashboard;     // Dashboard GUI

// EA state
datetime       g_lastBarTime   = 0;
datetime       g_startTime     = 0;
bool           g_autoTrading   = true;
double         g_lotSize       = 0.01;
double         g_riskPct       = 1.0;
bool           g_useLotMode    = true;
bool           g_ddPaused      = false;
ENUM_SSP_SIGNAL g_lastSignal   = SSP_SIGNAL_NONE;

//+------------------------------------------------------------------+
//| EXPERT INITIALIZATION                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Set log level
   g_sspLogLevel = InpLogLevel;
   
   // -- Validate inputs --
   if(InpStopLoss <= 0 || InpTakeProfit <= 0)
     { SSPError("SL and TP must be > 0"); return INIT_PARAMETERS_INCORRECT; }
   if(InpEmaFast >= InpEmaSlow)
     { SSPError("Fast EMA must be < Slow EMA"); return INIT_PARAMETERS_INCORRECT; }
   if(InpFixedLots <= 0 && InpLotMode == SSP_LOT_FIXED)
     { SSPError("Fixed lot size must be > 0"); return INIT_PARAMETERS_INCORRECT; }
   
   // -- Init trading engine --
   if(!g_engine.Init(_Symbol, InpMagicNumber, InpMaxSlippage, InpTradeComment))
     { SSPError("Trading engine init failed"); return INIT_FAILED; }
   
   // -- Init strategy engine --
   if(!g_strategy.Init(_Symbol, (ENUM_TIMEFRAMES)Period(),
                       InpEmaFast, InpEmaSlow, InpRsiPeriod, InpAtrPeriod,
                       InpBreakoutLookback, InpBreakoutBuffer, InpTrendStrength,
                       InpRsiBuyMin, InpRsiBuyMax, InpRsiSellMin, InpRsiSellMax))
     { SSPError("Strategy engine init failed"); return INIT_FAILED; }
   
   // Configure filters
   g_strategy.SetSessionFilter(InpUseSessionFilter, InpSessionStartHour, InpSessionStartMin,
                                InpSessionEndHour, InpSessionEndMin, InpAvoidFriday, InpFridayCutoffHour);
   g_strategy.SetSpreadFilter(InpUseSpreadFilter, InpMaxSpread);
   g_strategy.SetNewsFilter(InpUseNewsFilter, InpNewsTime1, InpNewsTime2, InpNewsTime3,
                             InpNewsMinsBefore, InpNewsMinsAfter);
   
   // -- Init state --
   g_startTime   = TimeCurrent();
   g_lotSize     = InpFixedLots;
   g_riskPct     = InpRiskPercent;
   g_useLotMode  = (InpLotMode == SSP_LOT_FIXED);
   g_autoTrading = true;
   g_ddPaused    = false;
   g_lastSignal  = SSP_SIGNAL_NONE;
   
   // -- Init dashboard --
   if(InpShowDashboard)
     {
      if(g_dashboard.Init(ChartID(), InpSyncChartTheme))
        {
         g_dashboard.SetPanelVisible(InpShowAnalytics);
         EventSetMillisecondTimer(SSP_GUI_UPDATE_MS);
        }
     }
   
   // -- Startup banner --
   SSPInfo("=========================================================");
   SSPInfo("  " + SSP_NAME + " v" + SSP_VERSION + " | Build " + SSP_BUILD);
   SSPInfo("  " + _Symbol + " | " + EnumToString((ENUM_TIMEFRAMES)Period()));
   SSPInfo("  SL=" + IntegerToString(InpStopLoss) + " TP=" + IntegerToString(InpTakeProfit) +
           " | Magic=" + IntegerToString(InpMagicNumber));
   SSPInfo("  Lot Mode=" + (g_useLotMode ? "FIXED " + DoubleToString(g_lotSize, 2) :
           "RISK% " + DoubleToString(g_riskPct, 1) + "%"));
   SSPInfo("=========================================================");
   
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| EXPERT DEINITIALIZATION                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_dashboard.Deinit();
   g_strategy.Deinit();
   SSPInfo("EA removed. Reason=" + IntegerToString(reason));
  }

//+------------------------------------------------------------------+
//| TICK EVENT - Main trading logic                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   // -- Refresh market data --
   g_engine.RefreshMarket();
   
   // -- Breakeven management (every tick) --
   if(InpUseBreakeven)
      g_engine.ManageBreakeven(InpBreakevenStart, InpBreakevenOffset);
   
   // -- New bar gate --
   datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(barTime == g_lastBarTime) return;
   g_lastBarTime = barTime;
   
   // -- Drawdown check --
   g_ddPaused = !g_engine.CheckDrawdown(InpMaxDrawdownPct);
   if(g_ddPaused) { g_lastSignal = SSP_SIGNAL_NONE; return; }
   
   // -- Auto trading check --
   if(!g_autoTrading) { g_lastSignal = SSP_SIGNAL_NONE; return; }
   
   // -- One trade at a time --
   if(g_engine.HasOpenPosition()) return;
   
   // -- Update indicators --
   if(!g_strategy.UpdateIndicators()) return;
   
   // -- Filters --
   if(!g_strategy.PassSessionFilter())
     { g_lastSignal = SSP_SIGNAL_NONE; return; }
   if(!g_strategy.PassSpreadFilter(g_engine.GetSpread()))
     { g_lastSignal = SSP_SIGNAL_NONE; return; }
   if(!g_strategy.PassNewsFilter())
     { g_lastSignal = SSP_SIGNAL_NONE; return; }
   
   // -- Signal generation --
   ENUM_SSP_SIGNAL signal = g_strategy.GetSignal();
   g_lastSignal = signal;
   
   if(signal == SSP_SIGNAL_NONE) return;
   
   // -- Calculate lot --
   double lot = g_engine.CalculateLot(g_useLotMode, g_lotSize, g_riskPct, InpStopLoss);
   
   // -- Execute --
   if(signal == SSP_SIGNAL_BUY)
      g_engine.OpenBuy(lot, InpStopLoss, InpTakeProfit);
   else if(signal == SSP_SIGNAL_SELL)
      g_engine.OpenSell(lot, InpStopLoss, InpTakeProfit);
  }

//+------------------------------------------------------------------+
//| TRADE EVENT - Update statistics                                  |
//+------------------------------------------------------------------+
void OnTrade()
  {
   g_engine.LoadHistory();
  }

//+------------------------------------------------------------------+
//| TIMER - Dashboard updates                                        |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(!InpShowDashboard) return;
   
   g_engine.RefreshMarket();
   
   // Build cockpit data
   SSspCockpitData data;
   data.symbol        = _Symbol;
   data.timeframe     = EnumToString((ENUM_TIMEFRAMES)Period());
   
   SSspMarketData mkt;
   g_engine.GetMarket(mkt);
   data.bid           = mkt.bid;
   data.ask           = mkt.ask;
   data.spreadPoints  = mkt.spreadPoints;
   data.balance       = g_engine.GetBalance();
   data.equity        = g_engine.GetEquity();
   data.freeMargin    = g_engine.GetFreeMargin();
   data.floatingPnL   = g_engine.GetFloatingPnL();
   data.dailyPnL      = g_engine.GetDailyPnL();
   data.lotSize       = g_lotSize;
   data.riskPct       = g_riskPct;
   data.useLotMode    = g_useLotMode;
   data.autoTrading   = g_autoTrading;
   data.spreadOK      = g_strategy.PassSpreadFilter(mkt.spreadPoints);
   data.sessionON     = g_strategy.PassSessionFilter();
   data.newsClear     = g_strategy.PassNewsFilter();
   data.lastSignal    = g_lastSignal;
   data.trendDir      = g_strategy.GetTrendDirection();
   data.openPositions = g_engine.CountPositions();
   data.currentDD     = g_engine.GetDrawdownPct();
   data.allowedDD     = InpMaxDrawdownPct;
   data.uptimeSec     = (int)(TimeCurrent() - g_startTime);
   
   // Indicator values
   SSspIndicators ind;
   g_strategy.GetIndicators(ind);
   data.emaFast = ind.emaFast;
   data.emaSlow = ind.emaSlow;
   data.rsi     = ind.rsi;
   data.atr     = ind.atr;
   
   // Status
   if(g_ddPaused)          data.status = SSP_STATUS_DD_PAUSE;
   else if(!g_autoTrading) data.status = SSP_STATUS_PAUSED;
   else                    data.status = SSP_STATUS_RUNNING;
   
   // Stats
   g_engine.GetStats(data.stats);
   
   // Confirmation timeout
   SSspGuiCommands cmd;
   g_dashboard.GetCommands(cmd);
   if(cmd.confirmCloseAll && GetTickCount() - cmd.confirmTime > 3000)
     { cmd.confirmCloseAll = false; cmd.confirmTime = 0; }
   
   // Draw
   g_dashboard.Draw(data);
  }

//+------------------------------------------------------------------+
//| CHART EVENT - Route to dashboard                                 |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(!InpShowDashboard) return;
   
   if(g_dashboard.OnEvent(id, lparam, dparam, sparam))
     {
      ProcessGuiCommands();
      return;
     }
   
   if(id == CHARTEVENT_CHART_CHANGE)
      g_dashboard.OnResize();
  }

//+------------------------------------------------------------------+
//| PROCESS GUI COMMANDS                                             |
//+------------------------------------------------------------------+
void ProcessGuiCommands()
  {
   SSspGuiCommands cmd;
   g_dashboard.GetCommands(cmd);
   
   // Manual BUY
   if(cmd.cmdBuy)
     {
      double lot = g_engine.CalculateLot(g_useLotMode, g_lotSize, g_riskPct, InpStopLoss);
      g_engine.OpenBuy(lot, InpStopLoss, InpTakeProfit);
     }
   
   // Manual SELL
   if(cmd.cmdSell)
     {
      double lot = g_engine.CalculateLot(g_useLotMode, g_lotSize, g_riskPct, InpStopLoss);
      g_engine.OpenSell(lot, InpStopLoss, InpTakeProfit);
     }
   
   // Close All
   if(cmd.cmdCloseAll)
      g_engine.CloseAllPositions();
   
   // Toggle auto
   if(cmd.cmdToggleAuto)
     {
      g_autoTrading = !g_autoTrading;
      SSPInfo("Auto trading " + (g_autoTrading ? "ENABLED" : "DISABLED"));
     }
   
   // Lot mode
   if(cmd.cmdModeLot)  g_useLotMode = true;
   if(cmd.cmdModeRisk) g_useLotMode = false;
   
   // Lot +/-
   if(cmd.cmdLotUp)
     {
      if(g_useLotMode) g_lotSize = MathMin(10.0, NormalizeDouble(g_lotSize + 0.01, 2));
      else             g_riskPct = MathMin(5.0, NormalizeDouble(g_riskPct + 0.1, 1));
     }
   if(cmd.cmdLotDown)
     {
      if(g_useLotMode) g_lotSize = MathMax(0.01, NormalizeDouble(g_lotSize - 0.01, 2));
      else             g_riskPct = MathMax(0.1, NormalizeDouble(g_riskPct - 0.1, 1));
     }
   
   // Lot presets
   if(cmd.cmdLot001) { g_lotSize = 0.01; g_useLotMode = true; }
   if(cmd.cmdLot005) { g_lotSize = 0.05; g_useLotMode = true; }
   if(cmd.cmdLot010) { g_lotSize = 0.10; g_useLotMode = true; }
   if(cmd.cmdLot050) { g_lotSize = 0.50; g_useLotMode = true; }
   
   // Panel toggle
   if(cmd.cmdTogglePanel)
      g_dashboard.SetPanelVisible(!InpShowAnalytics); // Toggle state handled internally
   
   g_dashboard.ClearCommands();
  }

//+------------------------------------------------------------------+
//| TESTER - Custom optimization criterion                           |
//+------------------------------------------------------------------+
double OnTester()
  {
   double profit  = TesterStatistics(STAT_PROFIT);
   double trades  = TesterStatistics(STAT_TRADES);
   double maxDD   = TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
   double pf      = TesterStatistics(STAT_PROFIT_FACTOR);
   double sharpe  = TesterStatistics(STAT_SHARPE_RATIO);
   double recovery= TesterStatistics(STAT_RECOVERY_FACTOR);
   double winRate = trades > 0 ? TesterStatistics(STAT_PROFIT_TRADES) / trades * 100 : 0;
   
   // Minimum requirements
   if(trades < 30)                    return 0;
   if(profit <= 0)                    return 0;
   if(maxDD > InpMaxDrawdownPct)      return 0;
   if(winRate < 40)                   return 0;
   if(pf < 1.2)                      return 0;
   
   // Composite fitness score
   double fitness = SSPSafeDiv(profit, MathMax(maxDD, 0.1), 0);
   if(winRate > 50) fitness *= (1.0 + (winRate - 50) / 100.0);
   if(pf > 1.5)    fitness *= (1.0 + (pf - 1.5) / 10.0);
   if(sharpe > 0)   fitness *= (1.0 + sharpe / 10.0);
   if(recovery > 1)  fitness *= (1.0 + SSPClamp(recovery, 0, 5) / 10.0);
   
   SSPInfo("[OnTester] Fitness=" + DoubleToString(fitness, 2) +
           " | PF=" + DoubleToString(pf, 2) +
           " | WR=" + DoubleToString(winRate, 1) + "%" +
           " | DD=" + DoubleToString(maxDD, 2) + "%" +
           " | Trades=" + IntegerToString((int)trades));
   
   return fitness;
  }

//+------------------------------------------------------------------+
//| END OF EA                                                        |
//+------------------------------------------------------------------+
