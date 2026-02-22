//+------------------------------------------------------------------+
//|                                                     SSPCore.mqh  |
//|                   SafeScalperPro v3.0 - Core Definitions          |
//|          Enums, Data Structures, Logging, Utility Functions       |
//+------------------------------------------------------------------+
#property copyright   "AlgoSphere Quant"
#property version     "3.10"
#property strict

#ifndef SSP_CORE_MQH
#define SSP_CORE_MQH

//+------------------------------------------------------------------+
//| VERSION & IDENTITY                                               |
//+------------------------------------------------------------------+
#define SSP_VERSION          "3.10"
#define SSP_BUILD            "20250213"
#define SSP_NAME             "SafeScalperPro"
#define SSP_COMMENT          "SSPv3"

//+------------------------------------------------------------------+
//| LIMITS & CONSTANTS                                               |
//+------------------------------------------------------------------+
#define SSP_MIN_BARS         250          // Minimum bars for EMA 200
#define SSP_GUI_UPDATE_MS    500          // Dashboard refresh rate
#define SSP_MAX_RETRIES      3            // Order send retries
#define SSP_RETRY_DELAY_MS   300          // Delay between retries

//+------------------------------------------------------------------+
//| GUI PREFIXES                                                     |
//+------------------------------------------------------------------+
#define SSP_PREFIX           "SSP_"       // All EA objects
#define SSP_CP_PREFIX        "SSP_CP_"    // Cockpit objects
#define SSP_AN_PREFIX        "SSP_AN_"    // Analytics panel
#define SSP_OV_PREFIX        "SSP_OV_"    // Chart overlay

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                     |
//+------------------------------------------------------------------+

enum ENUM_SSP_LOT_MODE
  {
   SSP_LOT_FIXED       = 0,   // Fixed Lot Size
   SSP_LOT_RISK_PCT    = 1    // Percent of Balance Risk
  };

enum ENUM_SSP_TREND_STRENGTH
  {
   SSP_TREND_WEAK      = 0,   // Allow Weak Trends
   SSP_TREND_MODERATE  = 1,   // Moderate Trends Only
   SSP_TREND_STRONG    = 2    // Strong Trends Only
  };

enum ENUM_SSP_LOG_LEVEL
  {
   SSP_LOG_DEBUG       = 0,   // Debug (verbose)
   SSP_LOG_INFO        = 1,   // Info (normal)
   SSP_LOG_WARNING     = 2,   // Warnings only
   SSP_LOG_ERROR       = 3    // Errors only
  };

enum ENUM_SSP_STATUS
  {
   SSP_STATUS_RUNNING  = 0,
   SSP_STATUS_PAUSED   = 1,
   SSP_STATUS_DD_PAUSE = 2,
   SSP_STATUS_OFF_HOURS= 3,
   SSP_STATUS_SPREAD   = 4,
   SSP_STATUS_NEWS     = 5,
   SSP_STATUS_ERROR    = 6
  };

enum ENUM_SSP_SIGNAL
  {
   SSP_SIGNAL_NONE     = 0,
   SSP_SIGNAL_BUY      = 1,
   SSP_SIGNAL_SELL      = -1
  };

//+------------------------------------------------------------------+
//| MARKET DATA SNAPSHOT                                             |
//+------------------------------------------------------------------+
struct SSspMarketData
  {
   string   symbol;
   double   point;
   int      digits;
   double   tickSize;
   double   tickValue;
   double   lotMin;
   double   lotMax;
   double   lotStep;
   double   bid;
   double   ask;
   int      spreadPoints;
   long     leverage;
   
   void Reset()
     {
      symbol = ""; point = 0; digits = 0;
      tickSize = 0; tickValue = 0;
      lotMin = 0.01; lotMax = 100; lotStep = 0.01;
      bid = 0; ask = 0; spreadPoints = 0; leverage = 0;
     }
  };

//+------------------------------------------------------------------+
//| INDICATOR CACHE                                                  |
//+------------------------------------------------------------------+
struct SSspIndicators
  {
   double   emaFast;        // EMA 50 current
   double   emaSlow;        // EMA 200 current
   double   emaFastPrev;    // EMA 50 previous bar
   double   emaSlowPrev;    // EMA 200 previous bar
   double   rsi;            // RSI current
   double   atr;            // ATR current
   double   close1;         // Last closed bar close
   double   close2;         // 2 bars ago close
   double   highestHigh;    // Breakout lookback high
   double   lowestLow;      // Breakout lookback low
   bool     valid;
   
   void Reset()
     {
      emaFast = 0; emaSlow = 0;
      emaFastPrev = 0; emaSlowPrev = 0;
      rsi = 50; atr = 0;
      close1 = 0; close2 = 0;
      highestHigh = 0; lowestLow = 0;
      valid = false;
     }
  };

//+------------------------------------------------------------------+
//| TRADE STATISTICS                                                 |
//+------------------------------------------------------------------+
struct SSspTradeStats
  {
   int      totalTrades;
   int      wins;
   int      losses;
   double   grossProfit;
   double   grossLoss;
   double   winRate;
   double   profitFactor;
   double   avgWin;
   double   avgLoss;
   double   expectancy;
   int      maxWinStreak;
   int      maxLossStreak;
   int      currentStreak;   // +/- for consecutive W/L
   double   todayPnL;
   double   totalPnL;
   
   void Reset()
     {
      totalTrades = 0; wins = 0; losses = 0;
      grossProfit = 0; grossLoss = 0;
      winRate = 0; profitFactor = 0;
      avgWin = 0; avgLoss = 0; expectancy = 0;
      maxWinStreak = 0; maxLossStreak = 0; currentStreak = 0;
      todayPnL = 0; totalPnL = 0;
     }
   
   void Recalculate()
     {
      winRate       = totalTrades > 0 ? (double)wins / totalTrades * 100.0 : 0;
      profitFactor  = grossLoss != 0 ? grossProfit / MathAbs(grossLoss) : 0;
      avgWin        = wins > 0 ? grossProfit / wins : 0;
      avgLoss       = losses > 0 ? grossLoss / losses : 0;
      expectancy    = totalTrades > 0 ? (grossProfit + grossLoss) / totalTrades : 0;
     }
  };

//+------------------------------------------------------------------+
//| COCKPIT DATA (engine -> GUI)                                      |
//+------------------------------------------------------------------+
struct SSspCockpitData
  {
   // Identity
   string         symbol;
   string         timeframe;
   // Market
   double         bid, ask;
   int            spreadPoints;
   // Account
   double         balance, equity, freeMargin;
   double         floatingPnL;
   double         dailyPnL;
   // Risk
   double         lotSize;
   double         riskPct;
   bool           useLotMode;
   // Status
   ENUM_SSP_STATUS status;
   string         statusText;
   bool           autoTrading;
   bool           spreadOK, sessionON, newsClear;
   // Signal
   ENUM_SSP_SIGNAL lastSignal;
   string         trendDir;
   // Indicators
   double         emaFast, emaSlow, rsi, atr;
   // Drawdown
   double         currentDD;
   double         maxDD;
   double         allowedDD;
   // Positions
   int            openPositions;
   // Stats
   SSspTradeStats stats;
   // Timing
   int            uptimeSec;
   
   void Reset()
     {
      symbol = ""; timeframe = "";
      bid = 0; ask = 0; spreadPoints = 0;
      balance = 0; equity = 0; freeMargin = 0;
      floatingPnL = 0; dailyPnL = 0;
      lotSize = 0.01; riskPct = 1.0; useLotMode = true;
      status = SSP_STATUS_RUNNING; statusText = "RUNNING";
      autoTrading = true;
      spreadOK = true; sessionON = true; newsClear = true;
      lastSignal = SSP_SIGNAL_NONE; trendDir = "FLAT";
      emaFast = 0; emaSlow = 0; rsi = 50; atr = 0;
      currentDD = 0; maxDD = 0; allowedDD = 10;
      openPositions = 0;
      stats.Reset();
      uptimeSec = 0;
     }
  };

//+------------------------------------------------------------------+
//| GUI COMMAND FLAGS (GUI -> engine)                                  |
//+------------------------------------------------------------------+
struct SSspGuiCommands
  {
   // Trade actions
   bool     cmdBuy;
   bool     cmdSell;
   bool     cmdCloseAll;
   bool     cmdToggleAuto;
   // Risk changes
   bool     cmdModeLot;
   bool     cmdModeRisk;
   bool     cmdLotUp;
   bool     cmdLotDown;
   bool     cmdLot001, cmdLot005, cmdLot010, cmdLot050;
   // Panel
   bool     cmdTogglePanel;
   // Close confirmation
   bool     confirmCloseAll;
   uint     confirmTime;
   
   void Reset()
     {
      cmdBuy = false; cmdSell = false; cmdCloseAll = false; cmdToggleAuto = false;
      cmdModeLot = false; cmdModeRisk = false;
      cmdLotUp = false; cmdLotDown = false;
      cmdLot001 = false; cmdLot005 = false; cmdLot010 = false; cmdLot050 = false;
      cmdTogglePanel = false;
      confirmCloseAll = false; confirmTime = 0;
     }
  };

//+------------------------------------------------------------------+
//| LOGGING SYSTEM                                                   |
//+------------------------------------------------------------------+
ENUM_SSP_LOG_LEVEL g_sspLogLevel = SSP_LOG_INFO;

void SSPLog(string message, ENUM_SSP_LOG_LEVEL level = SSP_LOG_INFO)
  {
   if(level < g_sspLogLevel) return;
   string prefix;
   switch(level)
     {
      case SSP_LOG_DEBUG:   prefix = "[DEBUG] "; break;
      case SSP_LOG_INFO:    prefix = "[INFO]  "; break;
      case SSP_LOG_WARNING: prefix = "[WARN]  "; break;
      case SSP_LOG_ERROR:   prefix = "[ERROR] "; break;
     }
   Print(SSP_NAME, " v", SSP_VERSION, " ", prefix, message);
  }

void SSPDebug(string msg)   { SSPLog(msg, SSP_LOG_DEBUG); }
void SSPInfo(string msg)    { SSPLog(msg, SSP_LOG_INFO); }
void SSPWarn(string msg)    { SSPLog(msg, SSP_LOG_WARNING); }
void SSPError(string msg)   { SSPLog(msg, SSP_LOG_ERROR); }

void SSPLogTrade(string action, double lot, double price, double sl, double tp)
  {
   SSPInfo(action + " " + DoubleToString(lot, 2) + " @ " +
           DoubleToString(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) +
           " SL=" + DoubleToString(sl, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) +
           " TP=" + DoubleToString(tp, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
  }

//+------------------------------------------------------------------+
//| UTILITY FUNCTIONS                                                |
//+------------------------------------------------------------------+

// Safe division (avoid divide-by-zero)
double SSPSafeDiv(double a, double b, double def = 0)
  { return b != 0 ? a / b : def; }

// Clamp value to range
double SSPClamp(double val, double lo, double hi)
  { return val < lo ? lo : val > hi ? hi : val; }

int SSPClampI(int val, int lo, int hi)
  { return val < lo ? lo : val > hi ? hi : val; }

// Format money with optional sign
string SSPFmtMoney(double v, bool sign = false)
  { return (sign && v > 0 ? "+" : "") + DoubleToString(v, 2); }

// Format percentage
string SSPFmtPct(double v, int dec = 1)
  { return DoubleToString(v, dec) + "%"; }

// Format uptime
string SSPFmtTime(int sec)
  {
   int h = sec / 3600, m = (sec % 3600) / 60, s = sec % 60;
   return StringFormat("%d:%02d:%02d", h, m, s);
  }

// Profit/loss color
color SSPPnlColor(double v, color pos, color neg, color zero)
  { return v > 0 ? pos : v < 0 ? neg : zero; }

// Get current session name based on server hour
string SSPGetSessionName()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int h = dt.hour;
   if(h >= 0 && h < 8)   return "ASIAN";
   if(h >= 8 && h < 12)  return "LONDON";
   if(h >= 12 && h < 16) return "LON-NY OVERLAP";
   if(h >= 16 && h < 21) return "NEW YORK";
   return "OFF HOURS";
  }

// Get start of today (midnight)
datetime SSPGetDayStart()
  {
   MqlDateTime dt;
   TimeCurrent(dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   return StructToTime(dt);
  }

// Check if current day is weekend
bool SSPIsWeekend()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.day_of_week == 0 || dt.day_of_week == 6);
  }

#endif // SSP_CORE_MQH
