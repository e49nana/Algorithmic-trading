//+------------------------------------------------------------------+
//|                                          ASQ_SafeScalping.mq5    |
//|                ASQ Safe Scalping System v1.10                    |
//|                                                                  |
//|  v1.10 IMPROVEMENTS:                                             |
//|    - Trailing stop with configurable start/step                  |
//|    - Multi-timeframe (HTF) EMA confirmation (7th condition)      |
//|    - Max trades per day limiter                                  |
//|    - Peak drawdown tracker (persisted via GlobalVariable)        |
//|    - Partial close at TP1 (close % at first target)              |
//+------------------------------------------------------------------+
#property copyright   "AlgoSphere Quant"
#property link        "https://www.mql5.com/en/users/robin2.0"
#property version     "1.10"
#property description "ASQ Safe Scalping - Professional Breakout System"
#property description "EMA Trend + RSI + Breakout + MTF + Premium Dashboard"
#property description "Conservative risk | No martingale/grid/hedging"
#property strict

#include <ASQSafeScalping\ASQCore.mqh>
#include <ASQSafeScalping\ASQTrading.mqh>
#include <ASQSafeScalping\ASQStrategy.mqh>
#include <ASQSafeScalping\ASQDashboard.mqh>

//+------------------------------------------------------------------+
//| INPUTS                                                           |
//+------------------------------------------------------------------+
input group "====== GENERAL ======"
input int               InpMagicNumber      = 202503;            // Magic Number
input string            InpTradeComment     = "ASQv1";           // Trade Comment
input int               InpMaxSlippage      = 10;                // Max Slippage (points)
input ENUM_ASQ_LOG_LEVEL InpLogLevel        = ASQ_LOG_INFO;      // Log Level

input group "====== RISK MANAGEMENT ======"
input ENUM_ASQ_LOT_MODE InpLotMode          = ASQ_LOT_FIXED;    // Lot Sizing Mode
input double            InpFixedLots        = 0.01;              // Fixed Lot Size
input double            InpRiskPercent      = 1.0;               // Risk % per Trade
input double            InpMaxDrawdownPct   = 10.0;              // Max Drawdown % (pause EA)
input int               InpMaxDayTrades     = 10;                // Max Trades per Day (0=unlimited)

input group "====== STOP LOSS & TAKE PROFIT ======"
input int               InpStopLoss         = 225;               // Stop Loss (points)
input int               InpTakeProfit       = 250;               // Take Profit (points)
input bool              InpUseBreakeven     = true;              // Use Breakeven
input int               InpBreakevenStart   = 100;               // BE Trigger (points in profit)
input int               InpBreakevenOffset  = 10;                // BE Offset (points above entry)

input group "====== TRAILING STOP ======"
input bool              InpUseTrailing      = false;             // Use Trailing Stop
input int               InpTrailStart       = 150;               // Trailing Start (points in profit)
input int               InpTrailStep        = 50;                // Trailing Step (distance behind price)

input group "====== PARTIAL CLOSE ======"
input bool              InpUsePartialClose  = false;             // Use Partial Close at TP1
input int               InpTP1Points        = 150;               // TP1 Distance (points)
input double            InpTP1ClosePercent  = 50.0;              // % of Position to Close at TP1

input group "====== EMA TREND FILTER ======"
input int               InpEmaFast          = 150;               // Fast EMA Period
input int               InpEmaSlow          = 510;               // Slow EMA Period
input ENUM_ASQ_TREND_STRENGTH InpTrendStrength = ASQ_TREND_MODERATE; // Trend Strength Filter

input group "====== MTF CONFIRMATION ======"
input bool              InpUseMTF           = false;             // Use Higher-TF Confirmation
input ENUM_TIMEFRAMES   InpMTFTimeframe     = PERIOD_H1;         // Higher Timeframe
input int               InpMTFEmaFast       = 50;                // HTF Fast EMA
input int               InpMTFEmaSlow       = 200;               // HTF Slow EMA

input group "====== RSI FILTER ======"
input int               InpRsiPeriod        = 10;                // RSI Period
input double            InpRsiBuyMin        = 40.0;              // RSI Buy Min
input double            InpRsiBuyMax        = 65.0;              // RSI Buy Max
input double            InpRsiSellMin       = 35.0;              // RSI Sell Min
input double            InpRsiSellMax       = 60.0;              // RSI Sell Max

input group "====== BREAKOUT DETECTION ======"
input int               InpBreakoutLookback = 20;                // Lookback Bars
input double            InpBreakoutBuffer   = 0.5;               // Buffer (x ATR)
input int               InpAtrPeriod        = 125;               // ATR Period

input group "====== SESSION FILTER ======"
input bool              InpUseSessionFilter = true;              // Enable Session Filter
input int               InpSessionStartHour = 8;                 // Start Hour
input int               InpSessionStartMin  = 0;                 // Start Minute
input int               InpSessionEndHour   = 20;                // End Hour
input int               InpSessionEndMin    = 0;                 // End Minute
input bool              InpAvoidFriday      = true;              // Avoid Friday Afternoon
input int               InpFridayCutoffHour = 16;                // Friday Cutoff Hour

input group "====== SPREAD FILTER ======"
input bool              InpUseSpreadFilter  = true;              // Enable Spread Filter
input int               InpMaxSpread        = 30;                // Max Spread (points)

input group "====== NEWS FILTER ======"
input bool              InpUseNewsFilter    = true;              // Enable News Filter
input string            InpNewsTime1        = "";                // News Time 1 (HH:MM)
input string            InpNewsTime2        = "";                // News Time 2
input string            InpNewsTime3        = "";                // News Time 3
input int               InpNewsMinsBefore   = 30;                // Minutes Before News
input int               InpNewsMinsAfter    = 15;                // Minutes After News

input group "====== DISPLAY ======"
input bool              InpShowDashboard    = true;              // Show Dashboard
input bool              InpSyncChartTheme   = true;              // Apply Dark Theme
input bool              InpShowAnalytics    = true;              // Show Analytics Panel

//+------------------------------------------------------------------+
//| GLOBALS                                                          |
//+------------------------------------------------------------------+
CASQTrading    g_engine;
CASQStrategy   g_strategy;
CASQDashboard  g_dashboard;

datetime       g_lastBarTime   = 0;
datetime       g_startTime     = 0;
bool           g_autoTrading   = true;
double         g_lotSize       = 0.01;
double         g_riskPct       = 1.0;
bool           g_useLotMode    = true;
bool           g_ddPaused      = false;
bool           g_daycapPaused  = false;
ENUM_ASQ_SIGNAL g_lastSignal   = ASQ_SIGNAL_NONE;

//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_asqLogLevel = InpLogLevel;
   if(InpStopLoss<=0||InpTakeProfit<=0) { ASQError("SL/TP must be > 0"); return INIT_PARAMETERS_INCORRECT; }
   if(InpEmaFast>=InpEmaSlow) { ASQError("Fast EMA must be < Slow EMA"); return INIT_PARAMETERS_INCORRECT; }
   if(InpFixedLots<=0&&InpLotMode==ASQ_LOT_FIXED) { ASQError("Fixed lot must be > 0"); return INIT_PARAMETERS_INCORRECT; }
   if(InpUsePartialClose&&InpTP1Points>=InpTakeProfit) ASQWarn("TP1 >= TP — partial close may never trigger properly");

   if(!g_engine.Init(_Symbol,InpMagicNumber,InpMaxSlippage,InpTradeComment)) return INIT_FAILED;
   if(!g_strategy.Init(_Symbol,(ENUM_TIMEFRAMES)Period(),
      InpEmaFast,InpEmaSlow,InpRsiPeriod,InpAtrPeriod,
      InpBreakoutLookback,InpBreakoutBuffer,InpTrendStrength,
      InpRsiBuyMin,InpRsiBuyMax,InpRsiSellMin,InpRsiSellMax)) return INIT_FAILED;

   g_strategy.SetMTFFilter(InpUseMTF,InpMTFTimeframe,_Symbol,InpMTFEmaFast,InpMTFEmaSlow);
   g_strategy.SetSessionFilter(InpUseSessionFilter,InpSessionStartHour,InpSessionStartMin,
     InpSessionEndHour,InpSessionEndMin,InpAvoidFriday,InpFridayCutoffHour);
   g_strategy.SetSpreadFilter(InpUseSpreadFilter,InpMaxSpread);
   g_strategy.SetNewsFilter(InpUseNewsFilter,InpNewsTime1,InpNewsTime2,InpNewsTime3,
     InpNewsMinsBefore,InpNewsMinsAfter);

   g_startTime=TimeCurrent(); g_lotSize=InpFixedLots; g_riskPct=InpRiskPercent;
   g_useLotMode=(InpLotMode==ASQ_LOT_FIXED); g_autoTrading=true; g_ddPaused=false; g_daycapPaused=false;

   if(InpShowDashboard&&!MQLInfoInteger(MQL_TESTER))
     { if(g_dashboard.Init(ChartID(),InpSyncChartTheme))
         { g_dashboard.SetPanelVisible(InpShowAnalytics); EventSetMillisecondTimer(ASQ_GUI_UPDATE_MS); } }

   ASQInfo("=========================================================");
   ASQInfo("  "+ASQ_NAME+" v"+ASQ_VERSION+" | Build "+ASQ_BUILD);
   ASQInfo("  "+_Symbol+" | "+EnumToString((ENUM_TIMEFRAMES)Period()));
   ASQInfo("  SL="+IntegerToString(InpStopLoss)+" TP="+IntegerToString(InpTakeProfit)+
           " | Magic="+IntegerToString(InpMagicNumber));
   if(InpUseTrailing) ASQInfo("  Trailing: start="+IntegerToString(InpTrailStart)+" step="+IntegerToString(InpTrailStep));
   if(InpUsePartialClose) ASQInfo("  PartialClose: TP1="+IntegerToString(InpTP1Points)+" close="+DoubleToString(InpTP1ClosePercent,0)+"%");
   if(InpUseMTF) ASQInfo("  MTF: "+EnumToString(InpMTFTimeframe)+" EMA "+IntegerToString(InpMTFEmaFast)+"/"+IntegerToString(InpMTFEmaSlow));
   if(InpMaxDayTrades>0) ASQInfo("  DayCap: "+IntegerToString(InpMaxDayTrades)+" trades/day");
   ASQInfo("=========================================================");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  { EventKillTimer(); g_dashboard.Deinit(); g_strategy.Deinit();
    ASQInfo("EA removed. Reason="+IntegerToString(reason)); }

//+------------------------------------------------------------------+
//| TICK                                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   g_engine.RefreshMarket();

   // Every tick: breakeven + trailing + partial close
   if(InpUseBreakeven) g_engine.ManageBreakeven(InpBreakevenStart,InpBreakevenOffset);
   if(InpUseTrailing) g_engine.ManageTrailing(InpTrailStart,InpTrailStep);
   if(InpUsePartialClose) g_engine.ManagePartialClose(InpTP1Points,InpTP1ClosePercent);

   // New bar gate
   datetime barTime=iTime(_Symbol,PERIOD_CURRENT,0);
   if(barTime==g_lastBarTime) return;
   g_lastBarTime=barTime;

   // Drawdown check
   g_ddPaused=!g_engine.CheckDrawdown(InpMaxDrawdownPct);
   if(g_ddPaused) { g_lastSignal=ASQ_SIGNAL_NONE; return; }

   // Day cap check
   g_daycapPaused=false;
   if(InpMaxDayTrades>0&&g_engine.GetTodayTrades()>=InpMaxDayTrades)
     { g_daycapPaused=true; g_lastSignal=ASQ_SIGNAL_NONE; return; }

   if(!g_autoTrading) { g_lastSignal=ASQ_SIGNAL_NONE; return; }
   if(g_engine.HasOpenPosition()) return;
   if(!g_strategy.UpdateIndicators()) return;

   // Filters
   if(!g_strategy.PassSessionFilter()) { g_lastSignal=ASQ_SIGNAL_NONE; return; }
   if(!g_strategy.PassSpreadFilter(g_engine.GetSpread())) { g_lastSignal=ASQ_SIGNAL_NONE; return; }
   if(!g_strategy.PassNewsFilter()) { g_lastSignal=ASQ_SIGNAL_NONE; return; }

   // Signal (includes MTF check if enabled)
   ENUM_ASQ_SIGNAL signal=g_strategy.GetSignal();
   g_lastSignal=signal;
   if(signal==ASQ_SIGNAL_NONE) return;

   double lot=g_engine.CalculateLot(g_useLotMode,g_lotSize,g_riskPct,InpStopLoss);
   if(signal==ASQ_SIGNAL_BUY) g_engine.OpenBuy(lot,InpStopLoss,InpTakeProfit);
   else if(signal==ASQ_SIGNAL_SELL) g_engine.OpenSell(lot,InpStopLoss,InpTakeProfit);
  }

void OnTrade() { g_engine.LoadHistory(); }

//+------------------------------------------------------------------+
//| TIMER                                                            |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(!InpShowDashboard||MQLInfoInteger(MQL_TESTER)) return;
   g_engine.RefreshMarket();

   SAsqCockpitData data;
   data.symbol=_Symbol;
   data.timeframe=StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()),7);
   SAsqMarketData mkt; g_engine.GetMarket(mkt);
   data.bid=mkt.bid; data.ask=mkt.ask; data.spreadPoints=mkt.spreadPoints;
   data.balance=g_engine.GetBalance(); data.equity=g_engine.GetEquity();
   data.freeMargin=g_engine.GetFreeMargin();
   data.floatingPnL=g_engine.GetFloatingPnL(); data.dailyPnL=g_engine.GetDailyPnL();
   data.lotSize=g_lotSize; data.riskPct=g_riskPct; data.useLotMode=g_useLotMode;
   data.autoTrading=g_autoTrading;
   data.spreadOK=g_strategy.PassSpreadFilter(mkt.spreadPoints);
   data.sessionON=g_strategy.PassSessionFilter();
   data.newsClear=g_strategy.PassNewsFilter();
   data.mtfOK=g_strategy.PassMTFFilter();
   data.daycapOK=(InpMaxDayTrades<=0||g_engine.GetTodayTrades()<InpMaxDayTrades);
   data.lastSignal=g_lastSignal;
   data.trendDir=g_strategy.GetTrendDirection();
   data.htfTrendDir=g_strategy.GetHTFTrendDirection();
   data.openPositions=g_engine.CountPositions();
   data.currentDD=g_engine.GetDrawdownPct();
   data.peakDD=g_engine.GetPeakDD();
   data.allowedDD=InpMaxDrawdownPct;
   data.todayTrades=g_engine.GetTodayTrades();
   data.maxDayTrades=InpMaxDayTrades;
   data.uptimeSec=(int)(TimeCurrent()-g_startTime);

   SAsqIndicators ind; g_strategy.GetIndicators(ind);
   data.emaFast=ind.emaFast; data.emaSlow=ind.emaSlow;
   data.rsi=ind.rsi; data.atr=ind.atr;

   if(g_ddPaused)           data.status=ASQ_STATUS_DD_PAUSE;
   else if(g_daycapPaused)  data.status=ASQ_STATUS_DAYCAP;
   else if(!g_autoTrading)  data.status=ASQ_STATUS_PAUSED;
   else                     data.status=ASQ_STATUS_RUNNING;

   g_engine.GetStats(data.stats);
   g_dashboard.Draw(data);
  }

//+------------------------------------------------------------------+
//| CHART EVENT                                                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,const long &lp,const double &dp,const string &sp)
  { if(!InpShowDashboard||MQLInfoInteger(MQL_TESTER)) return;
    if(g_dashboard.OnEvent(id,lp,dp,sp)){ProcessGuiCommands();return;}
    if(id==CHARTEVENT_CHART_CHANGE) g_dashboard.OnResize(); }

void ProcessGuiCommands()
  { SAsqGuiCommands cmd; g_dashboard.GetCommands(cmd);
    if(cmd.cmdBuy) { double lot=g_engine.CalculateLot(g_useLotMode,g_lotSize,g_riskPct,InpStopLoss);
      g_engine.OpenBuy(lot,InpStopLoss,InpTakeProfit); }
    if(cmd.cmdSell) { double lot=g_engine.CalculateLot(g_useLotMode,g_lotSize,g_riskPct,InpStopLoss);
      g_engine.OpenSell(lot,InpStopLoss,InpTakeProfit); }
    if(cmd.cmdCloseAll) g_engine.CloseAllPositions();
    if(cmd.cmdToggleAuto) { g_autoTrading=!g_autoTrading; ASQInfo("Auto "+(g_autoTrading?"ON":"OFF")); }
    if(cmd.cmdModeLot) g_useLotMode=true; if(cmd.cmdModeRisk) g_useLotMode=false;
    if(cmd.cmdLotUp) { if(g_useLotMode) g_lotSize=MathMin(10.0,NormalizeDouble(g_lotSize+0.01,2));
      else g_riskPct=MathMin(5.0,NormalizeDouble(g_riskPct+0.1,1)); }
    if(cmd.cmdLotDown) { if(g_useLotMode) g_lotSize=MathMax(0.01,NormalizeDouble(g_lotSize-0.01,2));
      else g_riskPct=MathMax(0.1,NormalizeDouble(g_riskPct-0.1,1)); }
    if(cmd.cmdLot001){g_lotSize=0.01;g_useLotMode=true;}
    if(cmd.cmdLot005){g_lotSize=0.05;g_useLotMode=true;}
    if(cmd.cmdLot010){g_lotSize=0.10;g_useLotMode=true;}
    if(cmd.cmdLot050){g_lotSize=0.50;g_useLotMode=true;}
    g_dashboard.ClearCommands(); }

//+------------------------------------------------------------------+
//| TESTER                                                           |
//+------------------------------------------------------------------+
double OnTester()
  { double profit=TesterStatistics(STAT_PROFIT),trades=TesterStatistics(STAT_TRADES);
    double maxDD=TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
    double pf=TesterStatistics(STAT_PROFIT_FACTOR),sharpe=TesterStatistics(STAT_SHARPE_RATIO);
    double recovery=TesterStatistics(STAT_RECOVERY_FACTOR);
    double wr=trades>0?TesterStatistics(STAT_PROFIT_TRADES)/trades*100:0;
    if(trades<30||profit<=0||maxDD>InpMaxDrawdownPct||wr<40||pf<1.2) return 0;
    double fit=ASQSafeDiv(profit,MathMax(maxDD,0.1),0);
    if(wr>50) fit*=(1.0+(wr-50)/100.0);
    if(pf>1.5) fit*=(1.0+(pf-1.5)/10.0);
    if(sharpe>0) fit*=(1.0+sharpe/10.0);
    if(recovery>1) fit*=(1.0+ASQClamp(recovery,0,5)/10.0);
    return fit; }
//+------------------------------------------------------------------+
