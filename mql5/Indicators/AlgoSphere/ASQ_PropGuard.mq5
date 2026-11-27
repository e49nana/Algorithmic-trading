//+------------------------------------------------------------------+
//|                                             ASQ_PropGuard.mq5    |
//|                              Copyright 2026, AlgoSphere Quant    |
//|                        https://www.mql5.com/en/users/robin2.0    |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, AlgoSphere Quant"
#property link        "https://www.mql5.com/en/users/robin2.0"
#property version     "2.00"
#property description "ASQ PropGuard v2 — Prop firm challenge monitor"
#property description "Daily DD, Max DD, Profit Target, Trading Days tracker."
#property description "Phase tracking, win rate, auto-close, 7 firm presets."
#property description "AlgoSphere Quant — Precision before profit."
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0
#property strict

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| Enums                                                             |
//+------------------------------------------------------------------+
enum ENUM_FIRM_PRESET
  {
   PRESET_CUSTOM   = 0,  // Custom
   PRESET_FTMO     = 1,  // FTMO
   PRESET_BULENOX  = 2,  // Bulenox
   PRESET_MFF      = 3,  // MyFundedFX
   PRESET_E8       = 4,  // E8 Funding
   PRESET_TFT      = 5,  // The Funded Trader
   PRESET_TOPSTEP  = 6   // Topstep
  };

enum ENUM_DD_TYPE
  {
   DD_BALANCE_BASED = 0,  // Balance-based (trailing)
   DD_EQUITY_BASED  = 1,  // Equity-based (trailing)
   DD_STATIC        = 2   // Static (from initial)
  };

enum ENUM_GUARD_ACTION
  {
   ACTION_ALERT_ONLY  = 0,  // Alert only
   ACTION_CLOSE_ALL   = 1,  // Close all positions
   ACTION_CLOSE_LOSING= 2   // Close losing only
  };

enum ENUM_CHALLENGE_PHASE
  {
   PHASE_1  = 0,  // Phase 1 (Challenge)
   PHASE_2  = 1,  // Phase 2 (Verification)
   FUNDED   = 2   // Funded Account
  };

//+------------------------------------------------------------------+
//| Inputs                                                            |
//+------------------------------------------------------------------+
input group                "═══════ FIRM PRESET ═══════"
input ENUM_FIRM_PRESET     InpPreset          = PRESET_CUSTOM;
input double               InpAccountSize     = 100000.0;  // Account Size
input ENUM_CHALLENGE_PHASE InpPhase           = PHASE_1;   // Challenge Phase

input group                "═══════ CUSTOM RULES ═══════"
input double               InpDailyDDPercent  = 5.0;       // Daily DD Limit %
input double               InpMaxDDPercent    = 10.0;      // Max DD Limit %
input double               InpProfitTarget    = 10.0;      // Profit Target %
input int                  InpMinTradingDays  = 4;         // Min Trading Days
input int                  InpMaxTradingDays  = 30;        // Max Calendar Days (0=unlimited)
input ENUM_DD_TYPE         InpDDType          = DD_BALANCE_BASED; // DD Calculation Type

input group                "═══════ PROTECTION ═══════"
input ENUM_GUARD_ACTION    InpAction          = ACTION_CLOSE_ALL;
input double               InpWarningPercent  = 80.0;      // Warning at % of limit
input bool                 InpAutoClose       = true;      // Auto-close on breach
input int                  InpSlippage        = 20;        // Close slippage (points)

input group                "═══════ ALERTS ═══════"
input bool                 InpAlertPopup      = true;
input bool                 InpAlertSound      = true;
input string               InpSoundFile       = "alert.wav";
input bool                 InpAlertEmail      = false;
input bool                 InpAlertPush       = false;

input group                "═══════ DASHBOARD ═══════"
input bool                 InpShowDash        = true;      // Show Dashboard
input int                  InpDashX           = 20;
input int                  InpDashY           = 30;
input int                  InpFontSize        = 9;
input color                InpAccentColor     = C'0,150,255';
input color                InpSafeColor       = C'0,200,120';
input color                InpWarningColor    = C'255,180,0';
input color                InpDangerColor     = C'240,50,70';
input color                InpProfitColor     = C'0,220,160';
input color                InpTextColor       = C'175,180,192';
input color                InpDimColor        = C'70,75,90';
input color                InpBgColor         = C'12,14,22';
input color                InpBorderColor     = C'28,32,48';

//+------------------------------------------------------------------+
//| Constants & Globals                                                |
//+------------------------------------------------------------------+
const string P       = "ASQ_PG_";
const string IND_TAG = "ASQ PropGuard";
const string IND_VER = "2.0";

CTrade g_trade;

string g_firmName       = "CUSTOM";
double g_dailyDDPct     = 5;
double g_maxDDPct       = 10;
double g_profitTarget   = 10;
int    g_minDays        = 4;
int    g_maxDays        = 30;
ENUM_DD_TYPE g_ddType   = DD_BALANCE_BASED;

double   g_initialBalance  = 0;
double   g_dayStartBalance = 0;
double   g_highWaterMark   = 0;
datetime g_dayStart        = 0;
datetime g_challengeStart  = 0;
int      g_tradingDays     = 0;
int      g_wins            = 0;
int      g_losses          = 0;

bool g_dailyBreached  = false;
bool g_maxBreached    = false;
bool g_targetReached  = false;
bool g_warningDaily   = false;
bool g_warningMax     = false;

//+------------------------------------------------------------------+
//| Init                                                              |
//+------------------------------------------------------------------+
int OnInit()
  {
   LoadPreset();

   g_initialBalance  = (InpAccountSize > 0) ? InpAccountSize : AccountInfoDouble(ACCOUNT_BALANCE);
   g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_highWaterMark   = g_initialBalance;
   g_dayStart        = GetDayStart(TimeCurrent());
   g_challengeStart  = TimeCurrent();
   g_tradingDays     = 0;
   g_wins            = 0;
   g_losses          = 0;

   g_trade.SetDeviationInPoints(InpSlippage);

   string phaseStr = (InpPhase == PHASE_1) ? "P1" : (InpPhase == PHASE_2) ? "P2" : "Funded";
   IndicatorSetString(INDICATOR_SHORTNAME,
      StringFormat("ASQ PropGuard (%s %s)", g_firmName, phaseStr));

   if(InpShowDash) CreateDashboard();

   PrintFormat("%s v%s | %s %s | Size: %.0f | DD: %.1f%% / %.1f%% | Target: %.1f%%",
               IND_TAG, IND_VER, g_firmName, phaseStr, g_initialBalance,
               g_dailyDDPct, g_maxDDPct, g_profitTarget);

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason) { ObjectsDeleteAll(0, P); ChartRedraw(0); }

//+------------------------------------------------------------------+
//| Load firm preset rules                                             |
//+------------------------------------------------------------------+
void LoadPreset()
  {
   switch(InpPreset)
     {
      case PRESET_FTMO:
         g_firmName="FTMO"; g_dailyDDPct=5; g_maxDDPct=10; g_profitTarget=10;
         g_minDays=4; g_maxDays=30; g_ddType=DD_BALANCE_BASED; break;
      case PRESET_BULENOX:
         g_firmName="BULENOX"; g_dailyDDPct=4; g_maxDDPct=7.5; g_profitTarget=6;
         g_minDays=1; g_maxDays=0; g_ddType=DD_EQUITY_BASED; break;
      case PRESET_MFF:
         g_firmName="MyFundedFX"; g_dailyDDPct=5; g_maxDDPct=10; g_profitTarget=8;
         g_minDays=5; g_maxDays=30; g_ddType=DD_BALANCE_BASED; break;
      case PRESET_E8:
         g_firmName="E8 Funding"; g_dailyDDPct=5; g_maxDDPct=8; g_profitTarget=8;
         g_minDays=0; g_maxDays=0; g_ddType=DD_BALANCE_BASED; break;
      case PRESET_TFT:
         g_firmName="The Funded Trader"; g_dailyDDPct=5; g_maxDDPct=10; g_profitTarget=10;
         g_minDays=0; g_maxDays=35; g_ddType=DD_BALANCE_BASED; break;
      case PRESET_TOPSTEP:
         g_firmName="Topstep"; g_dailyDDPct=2; g_maxDDPct=4; g_profitTarget=6;
         g_minDays=0; g_maxDays=0; g_ddType=DD_EQUITY_BASED; break;
      default:
         g_firmName="CUSTOM"; g_dailyDDPct=InpDailyDDPercent; g_maxDDPct=InpMaxDDPercent;
         g_profitTarget=InpProfitTarget; g_minDays=InpMinTradingDays;
         g_maxDays=InpMaxTradingDays; g_ddType=InpDDType; break;
     }
  }

//+------------------------------------------------------------------+
//| Main calculation                                                   |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[],
                const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
  {
   if(rates_total < 1) return(0);

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double floatPL = equity - balance;

//--- new day detection (fixed: uses TimeToStruct, not %86400)
   datetime todayStart = GetDayStart(TimeCurrent());
   if(todayStart > g_dayStart)
     {
      g_dayStart        = todayStart;
      g_dayStartBalance = balance;
      g_dailyBreached   = false;
      g_warningDaily    = false;
      if(PositionsTotal() > 0)
         g_tradingDays++;
     }

   if(balance > g_highWaterMark)
      g_highWaterMark = balance;

//--- daily DD
   double dailyDD      = g_dayStartBalance - equity;
   double dailyDDLimit  = g_dayStartBalance * g_dailyDDPct / 100.0;
   double dailyDDUsed   = (dailyDDLimit > 0) ? (dailyDD / dailyDDLimit) * 100.0 : 0;

//--- max DD
   double maxDD = 0, maxDDLimit = 0;
   switch(g_ddType)
     {
      case DD_BALANCE_BASED:
      case DD_EQUITY_BASED:
         maxDDLimit = g_highWaterMark * g_maxDDPct / 100.0;
         maxDD      = g_highWaterMark - equity;
         break;
      case DD_STATIC:
         maxDDLimit = g_initialBalance * g_maxDDPct / 100.0;
         maxDD      = g_initialBalance - equity;
         break;
     }
   double maxDDUsed = (maxDDLimit > 0) ? (maxDD / maxDDLimit) * 100.0 : 0;

//--- profit target
   double totalPL      = balance - g_initialBalance + floatPL;
   double targetAmount = g_initialBalance * g_profitTarget / 100.0;
   double targetPct    = (targetAmount > 0) ? (totalPL / targetAmount) * 100.0 : 0;

//--- days
   int daysPassed = (int)((TimeCurrent() - g_challengeStart) / 86400) + 1;
   int daysLeft   = (g_maxDays > 0) ? g_maxDays - daysPassed : -1;

//--- warnings
   if(dailyDDUsed >= InpWarningPercent && !g_warningDaily && !g_dailyBreached)
     {
      g_warningDaily = true;
      FireAlert("DAILY DD WARNING", StringFormat("%.1f%% of limit", dailyDDUsed), equity);
     }
   if(maxDDUsed >= InpWarningPercent && !g_warningMax && !g_maxBreached)
     {
      g_warningMax = true;
      FireAlert("MAX DD WARNING", StringFormat("%.1f%% of limit", maxDDUsed), equity);
     }

//--- breaches
   if(dailyDD >= dailyDDLimit && !g_dailyBreached && dailyDDLimit > 0)
     {
      g_dailyBreached = true;
      FireAlert("DAILY DD BREACHED", StringFormat("DD: %.2f", dailyDD), equity);
      if(InpAutoClose) ExecuteProtection();
     }
   if(maxDD >= maxDDLimit && !g_maxBreached && maxDDLimit > 0)
     {
      g_maxBreached = true;
      FireAlert("MAX DD BREACHED", StringFormat("DD: %.2f", maxDD), equity);
      if(InpAutoClose) ExecuteProtection();
     }
   if(totalPL >= targetAmount && !g_targetReached && targetAmount > 0)
     {
      g_targetReached = true;
      FireAlert("PROFIT TARGET REACHED", StringFormat("P/L: %.2f", totalPL), equity);
     }

//--- dashboard
   if(InpShowDash)
      UpdateDashboard(equity, balance, floatPL,
                      dailyDD, dailyDDLimit, dailyDDUsed,
                      maxDD, maxDDLimit, maxDDUsed,
                      totalPL, targetAmount, targetPct,
                      daysPassed, daysLeft);

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Execute auto-close protection via CTrade                           |
//+------------------------------------------------------------------+
void ExecuteProtection()
  {
   if(!InpAutoClose) return;
   PrintFormat("%s: EXECUTING PROTECTION...", IND_TAG);

   int closed = 0, failed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(InpAction == ACTION_CLOSE_LOSING && profit >= 0) continue;
      if(InpAction == ACTION_ALERT_ONLY) continue;

      if(g_trade.PositionClose(ticket, InpSlippage))
        { closed++; PrintFormat("  Closed #%I64u", ticket); }
      else
        { failed++; PrintFormat("  FAILED #%I64u Err: %d", ticket, GetLastError()); }
     }
   PrintFormat("%s: Closed: %d | Failed: %d", IND_TAG, closed, failed);
  }

//+------------------------------------------------------------------+
//| Helpers                                                            |
//+------------------------------------------------------------------+
datetime GetDayStart(datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   return StructToTime(dt);
  }

string PhaseStr()
  {
   switch(InpPhase)
     {
      case PHASE_1: return "PHASE 1";
      case PHASE_2: return "PHASE 2";
      case FUNDED:  return "FUNDED";
     }
   return "---";
  }

string DeadlineStr()
  {
   if(g_maxDays <= 0) return "No deadline";
   datetime deadline = g_challengeStart + g_maxDays * 86400;
   return TimeToString(deadline, TIME_DATE);
  }

string BuildBar(double pct, int width)
  {
   if(pct < 0) pct = 0;
   if(pct > 100) pct = 100;
   int filled = (int)MathRound(pct / 100.0 * width);
   string bar = "";
   for(int i = 0; i < width; i++)
      bar += (i < filled) ? CharToString(0xDB) : CharToString(0xB0);
   return bar;
  }

color LimitColor(double pct)
  {
   if(pct >= 100) return InpDangerColor;
   if(pct >= 80)  return InpDangerColor;
   if(pct >= 50)  return InpWarningColor;
   return InpSafeColor;
  }

color ProfitColor(double pct)
  {
   if(pct >= 100) return InpProfitColor;
   if(pct >= 50)  return InpSafeColor;
   return InpTextColor;
  }

//+------------------------------------------------------------------+
//| Fire alert                                                         |
//+------------------------------------------------------------------+
void FireAlert(string title, string message, double equity)
  {
   string msg = IND_TAG + " | " + g_firmName + " | " + title +
                " | " + message + " | Eq: " + DoubleToString(equity, 2);
   Print(msg);
   if(InpAlertPopup) Alert(msg);
   if(InpAlertSound) PlaySound(InpSoundFile);
   if(InpAlertEmail) SendMail(IND_TAG + " — " + title, msg);
   if(InpAlertPush)  SendNotification(msg);
  }

//+------------------------------------------------------------------+
//| Create dashboard background                                        |
//+------------------------------------------------------------------+
void CreateDashboard()
  {
   string bg = P + "BG";
   ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, InpDashX);
   ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, InpDashY);
   ObjectSetInteger(0, bg, OBJPROP_XSIZE, 330);
   ObjectSetInteger(0, bg, OBJPROP_YSIZE, 500);
   ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, InpBgColor);
   ObjectSetInteger(0, bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bg, OBJPROP_BORDER_COLOR, InpBorderColor);
   ObjectSetInteger(0, bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bg, OBJPROP_BACK, false);
   ObjectSetInteger(0, bg, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bg, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//| Update dashboard                                                   |
//+------------------------------------------------------------------+
void UpdateDashboard(double equity, double balance, double floatPL,
                     double dailyDD, double dailyDDLimit, double dailyDDUsed,
                     double maxDD, double maxDDLimit, double maxDDUsed,
                     double totalPL, double targetAmount, double targetPct,
                     int daysPassed, int daysLeft)
  {
   string cur = AccountInfoString(ACCOUNT_CURRENCY);
   int x  = InpDashX + 10;
   int xv = InpDashX + 160;
   int y  = InpDashY + 8;
   int lh = (int)(InpFontSize * 1.7);

   //--- HEADER
   DL("Title", x, y, "ASQ PROPGUARD", InpAccentColor, InpFontSize + 2);
   DL("Ver", InpDashX + 245, y + 2, "v" + IND_VER, InpDimColor, InpFontSize - 2);
   y += lh + 2;

   //--- Firm + Phase
   color phClr = (InpPhase == FUNDED) ? InpProfitColor : InpWarningColor;
   DL("Firm", x, y, g_firmName, InpWarningColor, InpFontSize);
   DL("Phase", InpDashX + 170, y, PhaseStr(), phClr, InpFontSize);
   y += lh;
   DL("Sep0", x, y, "-----------------------------------", InpBorderColor, InpFontSize - 3);
   y += lh - 4;

   //--- ACCOUNT
   DL("BalL", x, y, "Balance", InpDimColor, InpFontSize - 1);
   DL("BalV", xv, y, StringFormat("%.2f %s", balance, cur), InpTextColor, InpFontSize);
   y += lh;
   DL("EqL", x, y, "Equity", InpDimColor, InpFontSize - 1);
   DL("EqV", xv, y, StringFormat("%.2f %s", equity, cur), InpTextColor, InpFontSize);
   y += lh;
   DL("FlL", x, y, "Float P/L", InpDimColor, InpFontSize - 1);
   DL("FlV", xv, y, StringFormat("%.2f %s", floatPL, cur),
      floatPL >= 0 ? InpSafeColor : InpDangerColor, InpFontSize);
   y += lh;
   DL("HwL", x, y, "High Water Mark", InpDimColor, InpFontSize - 1);
   DL("HwV", xv, y, StringFormat("%.2f", g_highWaterMark), InpAccentColor, InpFontSize);
   y += lh;
   DL("Sep1", x, y, "-----------------------------------", InpBorderColor, InpFontSize - 3);
   y += lh - 4;

   //--- DAILY DD
   DL("DdL", x, y, "Daily DD", InpDimColor, InpFontSize - 1);
   DL("DdV", xv, y, StringFormat("%.2f / %.2f", MathMax(dailyDD,0), dailyDDLimit),
      LimitColor(dailyDDUsed), InpFontSize);
   y += lh;
   DL("DdBar", x, y, BuildBar(dailyDDUsed, 24), LimitColor(dailyDDUsed), InpFontSize - 1);
   DL("DdPct", InpDashX + 235, y, StringFormat("%.0f%%", MathMin(MathMax(dailyDDUsed,0),999)),
      LimitColor(dailyDDUsed), InpFontSize - 1);
   y += lh;

   //--- MAX DD
   DL("MdL", x, y, "Max DD", InpDimColor, InpFontSize - 1);
   DL("MdV", xv, y, StringFormat("%.2f / %.2f", MathMax(maxDD,0), maxDDLimit),
      LimitColor(maxDDUsed), InpFontSize);
   y += lh;
   DL("MdBar", x, y, BuildBar(maxDDUsed, 24), LimitColor(maxDDUsed), InpFontSize - 1);
   DL("MdPct", InpDashX + 235, y, StringFormat("%.0f%%", MathMin(MathMax(maxDDUsed,0),999)),
      LimitColor(maxDDUsed), InpFontSize - 1);
   y += lh;
   DL("Sep2", x, y, "-----------------------------------", InpBorderColor, InpFontSize - 3);
   y += lh - 4;

   //--- PROFIT TARGET
   DL("TgL", x, y, "Profit Target", InpDimColor, InpFontSize - 1);
   DL("TgV", xv, y, StringFormat("%.2f / %.2f", totalPL, targetAmount),
      ProfitColor(targetPct), InpFontSize);
   y += lh;
   DL("TgBar", x, y, BuildBar(MathMax(targetPct,0), 24), ProfitColor(targetPct), InpFontSize - 1);
   DL("TgPct", InpDashX + 235, y, StringFormat("%.0f%%", MathMax(targetPct,0)),
      ProfitColor(targetPct), InpFontSize - 1);
   y += lh;
   DL("Sep3", x, y, "-----------------------------------", InpBorderColor, InpFontSize - 3);
   y += lh - 4;

   //--- TIME
   DL("TdL", x, y, "Trading Days", InpDimColor, InpFontSize - 1);
   string minStr = (g_minDays > 0) ? IntegerToString(g_minDays) : "--";
   DL("TdV", xv, y, StringFormat("%d / %s", g_tradingDays, minStr),
      (g_minDays > 0 && g_tradingDays >= g_minDays) ? InpSafeColor : InpTextColor, InpFontSize);
   y += lh;

   DL("DpL", x, y, "Days Passed", InpDimColor, InpFontSize - 1);
   DL("DpV", xv, y, IntegerToString(daysPassed), InpTextColor, InpFontSize);
   y += lh;

   DL("DlL", x, y, "Days Left", InpDimColor, InpFontSize - 1);
   if(daysLeft >= 0)
     {
      DL("DlV", xv, y, IntegerToString(daysLeft),
         (daysLeft <= 5) ? InpWarningColor : InpTextColor, InpFontSize);
     }
   else
      DL("DlV", xv, y, "Unlimited", InpDimColor, InpFontSize);
   y += lh;

   DL("DeL", x, y, "Deadline", InpDimColor, InpFontSize - 1);
   DL("DeV", xv, y, DeadlineStr(), InpDimColor, InpFontSize - 1);
   y += lh;
   DL("Sep4", x, y, "-----------------------------------", InpBorderColor, InpFontSize - 3);
   y += lh - 4;

   //--- STATUS
   string statusText = "";
   color  statusClr  = InpSafeColor;
   if(g_dailyBreached || g_maxBreached) { statusText = "LIMIT BREACHED"; statusClr = InpDangerColor; }
   else if(g_targetReached)             { statusText = "TARGET REACHED"; statusClr = InpProfitColor; }
   else if(g_warningDaily || g_warningMax) { statusText = "WARNING"; statusClr = InpWarningColor; }
   else                                 { statusText = "MONITORING"; statusClr = InpSafeColor; }

   DL("StL", x, y, "Status", InpDimColor, InpFontSize - 1);
   DL("StV", xv, y, statusText, statusClr, InpFontSize + 1);
   y += lh;

   DL("PrL", x, y, "Protection", InpDimColor, InpFontSize - 1);
   DL("PrV", xv, y, InpAutoClose ? "ARMED" : "OFF",
      InpAutoClose ? InpSafeColor : InpDangerColor, InpFontSize);
   y += lh + 4;

   //--- FOOTER
   DL("Brand", x, y, "AlgoSphere Quant", InpDimColor, InpFontSize - 2);
   DL("Tag", InpDashX + 175, y, "Precision before profit", C'35,38,52', InpFontSize - 3);
   y += lh;

   ObjectSetInteger(0, P + "BG", OBJPROP_YSIZE, y - InpDashY + 5);
  }

//+------------------------------------------------------------------+
//| Dashboard label helper                                             |
//+------------------------------------------------------------------+
void DL(const string id, const int x, const int y,
        const string text, const color clr, const int fontSize)
  {
   string name = P + "D_" + id;
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
     }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
  }
//+------------------------------------------------------------------+
