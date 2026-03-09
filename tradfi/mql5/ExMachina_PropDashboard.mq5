//+------------------------------------------------------------------+
//|                                  ExMachina_PropDashboard.mq5     |
//|                        Copyright 2026, ExMachina Trading Systems  |
//|                        https://www.mql5.com/en/users/algosphere   |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, ExMachina Trading Systems"
#property link        "https://www.mql5.com/en/users/algosphere"
#property version     "1.00"
#property description "Prop Firm Dashboard: track daily drawdown, max drawdown,"
#property description "profit target, trading days, and session P&L in real time."
#property description "Compatible with FTMO, MyFundedFX, TFT, Bulenox and more."
#property description "Precision before profit."
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//+------------------------------------------------------------------+
//| Enums                                                             |
//+------------------------------------------------------------------+
enum ENUM_PROP_PRESET
  {
   PRESET_CUSTOM      = 0,   // Custom (manual settings)
   PRESET_FTMO        = 1,   // FTMO
   PRESET_MFF         = 2,   // MyFundedFX / MyFundsedFX
   PRESET_TFT         = 3,   // The Funded Trader
   PRESET_E8          = 4,   // E8 Funding
   PRESET_BULENOX     = 5    // Bulenox (Futures)
  };

enum ENUM_DD_CALC
  {
   DD_FROM_BALANCE    = 0,   // From initial balance (static)
   DD_FROM_EQUITY_HWM = 1,   // From equity high-water mark (trailing)
   DD_FROM_EOD_BALANCE = 2   // From end-of-day balance
  };

//+------------------------------------------------------------------+
//| Inputs                                                            |
//+------------------------------------------------------------------+
input group                "══════ PROP FIRM PRESET ══════"
input ENUM_PROP_PRESET InpPreset        = PRESET_CUSTOM;   // Prop firm preset
input double    InpAccountSize           = 100000.0;        // Account starting size

input group                "══════ RULES (Custom / Override) ══════"
input double    InpDailyLossLimit        = 5.0;    // Daily loss limit (%)
input double    InpMaxDrawdown           = 10.0;   // Max total drawdown (%)
input double    InpProfitTarget          = 10.0;   // Profit target (%)
input int       InpMinTradingDays        = 0;      // Min trading days required (0=off)
input int       InpMaxTradingDays        = 0;      // Max days for challenge (0=unlimited)
input ENUM_DD_CALC InpDDCalcMethod       = DD_FROM_BALANCE; // Drawdown calculation method

input group                "══════ DAILY RESET ══════"
input int       InpDayResetHour          = 0;      // Day reset hour (server time, 0=midnight)
input int       InpDayResetMinute        = 0;      // Day reset minute

input group                "══════ DISPLAY ══════"
input int       InpPanelX                = 15;     // Panel X position
input int       InpPanelY                = 25;     // Panel Y position
input int       InpFontSize              = 10;     // Font size
input color     InpPanelBg               = C'14,17,24';    // Background
input color     InpBorderColor           = C'30,35,50';    // Border
input color     InpHeaderColor           = C'90,180,250';  // Headers
input color     InpTextColor             = C'165,170,185'; // Normal text
input color     InpSafeColor             = C'0,200,83';    // Safe / green
input color     InpWarningColor          = C'255,215,0';   // Warning / yellow
input color     InpDangerColor           = C'255,23,68';   // Danger / red
input color     InpTargetColor           = C'0,230,118';   // Target reached

input group                "══════ ALERTS ══════"
input bool      InpAlertAt80Pct          = true;   // Alert at 80% of limits
input bool      InpAlertAtBreach         = true;   // Alert when limit breached
input bool      InpAlertPush             = false;  // Send push notification
input bool      InpAlertEmail            = false;  // Send email alert

//+------------------------------------------------------------------+
//| Constants                                                         |
//+------------------------------------------------------------------+
const string OBJ_PREFIX = "EXPD_";

//+------------------------------------------------------------------+
//| Prop firm rule set                                                 |
//+------------------------------------------------------------------+
struct PropRules
  {
   double         dailyLossLimit;     // % daily max loss
   double         maxDrawdown;        // % max total drawdown
   double         profitTarget;       // % profit target
   int            minTradingDays;     // minimum trading days
   int            maxDays;            // max calendar days (0=unlimited)
   ENUM_DD_CALC   ddMethod;           // how DD is calculated
  };

//+------------------------------------------------------------------+
//| Globals                                                           |
//+------------------------------------------------------------------+
PropRules      g_rules;
double         g_startBalance       = 0;
double         g_dayStartBalance    = 0;
double         g_dayStartEquity     = 0;
double         g_equityHWM          = 0;     // equity high-water mark
double         g_eodBalance         = 0;     // end-of-day balance for trailing DD
datetime       g_currentDay         = 0;
int            g_tradingDaysCount   = 0;
datetime       g_challengeStartDate = 0;
bool           g_dailyAlert80Sent   = false;
bool           g_dailyAlertSent     = false;
bool           g_maxDDAlert80Sent   = false;
bool           g_maxDDAlertSent     = false;
int            g_panelWidth         = 310;

//+------------------------------------------------------------------+
//| Custom indicator initialization                                    |
//+------------------------------------------------------------------+
int OnInit()
  {
   LoadPreset();

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);

   //--- use actual balance or configured size
   g_startBalance    = (InpAccountSize > 0) ? InpAccountSize : balance;
   g_dayStartBalance = balance;
   g_dayStartEquity  = equity;
   g_equityHWM       = MathMax(balance, equity);
   g_eodBalance      = balance;
   g_currentDay      = GetDayStart(TimeCurrent());
   g_challengeStartDate = g_currentDay;
   g_tradingDaysCount = 0;

   //--- check if we traded today
   if(HasTradedToday())
      g_tradingDaysCount = 1;

   CreatePanel();

   IndicatorSetString(INDICATOR_SHORTNAME, "ExMachina Prop Dashboard");
   PrintFormat("ExMachina Prop Dashboard initialized. Start balance: %.2f", g_startBalance);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinitialization                                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, OBJ_PREFIX);
  }

//+------------------------------------------------------------------+
//| Main calculation                                                   |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   CheckNewDay();

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);

   //--- update HWM
   if(equity > g_equityHWM)
      g_equityHWM = equity;

   //--- calculate all metrics
   double dailyPnL       = equity - g_dayStartBalance;
   double dailyPnLPct    = (g_dayStartBalance > 0) ? (dailyPnL / g_dayStartBalance) * 100.0 : 0;

   //--- total drawdown depends on method
   double totalDD     = 0;
   double totalDDPct  = 0;
   double ddBase      = 0;

   switch(g_rules.ddMethod)
     {
      case DD_FROM_BALANCE:
         ddBase = g_startBalance;
         totalDD = g_startBalance - equity;
         break;
      case DD_FROM_EQUITY_HWM:
         ddBase = g_equityHWM;
         totalDD = g_equityHWM - equity;
         break;
      case DD_FROM_EOD_BALANCE:
         ddBase = g_eodBalance;
         totalDD = g_eodBalance - equity;
         break;
     }

   if(totalDD < 0) totalDD = 0;
   totalDDPct = (ddBase > 0) ? (totalDD / ddBase) * 100.0 : 0;

   //--- profit progress
   double totalPnL    = equity - g_startBalance;
   double totalPnLPct = (g_startBalance > 0) ? (totalPnL / g_startBalance) * 100.0 : 0;
   double targetPct   = (g_rules.profitTarget > 0) ? (totalPnLPct / g_rules.profitTarget) * 100.0 : 0;
   if(targetPct < 0) targetPct = 0;

   //--- calendar days
   int calendarDays = (int)((TimeCurrent() - g_challengeStartDate) / 86400) + 1;
   int daysRemaining = (g_rules.maxDays > 0) ? g_rules.maxDays - calendarDays : -1;

   //--- alerts
   CheckAlerts(dailyPnLPct, totalDDPct);

   //--- update panel
   UpdatePanel(balance, equity, dailyPnL, dailyPnLPct, totalDD, totalDDPct,
               totalPnL, totalPnLPct, targetPct, calendarDays, daysRemaining);

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Load preset rules                                                  |
//+------------------------------------------------------------------+
void LoadPreset()
  {
   switch(InpPreset)
     {
      case PRESET_FTMO:
         g_rules.dailyLossLimit = 5.0;
         g_rules.maxDrawdown    = 10.0;
         g_rules.profitTarget   = 10.0;
         g_rules.minTradingDays = 4;
         g_rules.maxDays        = 30;
         g_rules.ddMethod       = DD_FROM_BALANCE;
         break;

      case PRESET_MFF:
         g_rules.dailyLossLimit = 5.0;
         g_rules.maxDrawdown    = 12.0;
         g_rules.profitTarget   = 8.0;
         g_rules.minTradingDays = 5;
         g_rules.maxDays        = 30;
         g_rules.ddMethod       = DD_FROM_BALANCE;
         break;

      case PRESET_TFT:
         g_rules.dailyLossLimit = 5.0;
         g_rules.maxDrawdown    = 10.0;
         g_rules.profitTarget   = 10.0;
         g_rules.minTradingDays = 0;
         g_rules.maxDays        = 35;
         g_rules.ddMethod       = DD_FROM_BALANCE;
         break;

      case PRESET_E8:
         g_rules.dailyLossLimit = 5.0;
         g_rules.maxDrawdown    = 8.0;
         g_rules.profitTarget   = 8.0;
         g_rules.minTradingDays = 0;
         g_rules.maxDays        = 0;
         g_rules.ddMethod       = DD_FROM_EQUITY_HWM;
         break;

      case PRESET_BULENOX:
         g_rules.dailyLossLimit = 0;    // Bulenox uses trailing max DD, no daily
         g_rules.maxDrawdown    = 4.0;  // depends on account, typical ~$2500 on $50K
         g_rules.profitTarget   = 6.0;
         g_rules.minTradingDays = 0;
         g_rules.maxDays        = 0;
         g_rules.ddMethod       = DD_FROM_EQUITY_HWM;
         break;

      default: // CUSTOM
         g_rules.dailyLossLimit = InpDailyLossLimit;
         g_rules.maxDrawdown    = InpMaxDrawdown;
         g_rules.profitTarget   = InpProfitTarget;
         g_rules.minTradingDays = InpMinTradingDays;
         g_rules.maxDays        = InpMaxTradingDays;
         g_rules.ddMethod       = InpDDCalcMethod;
         break;
     }
  }

//+------------------------------------------------------------------+
//| Check for new trading day                                          |
//+------------------------------------------------------------------+
void CheckNewDay()
  {
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);

   //--- build reset time for today
   MqlDateTime resetDt;
   TimeToStruct(g_currentDay, resetDt);
   resetDt.hour = InpDayResetHour;
   resetDt.min  = InpDayResetMinute;
   resetDt.sec  = 0;

   datetime todayReset = GetDayStart(now);
   MqlDateTime todayDt;
   TimeToStruct(todayReset, todayDt);
   todayDt.hour = InpDayResetHour;
   todayDt.min  = InpDayResetMinute;
   todayDt.sec  = 0;
   datetime resetTime = StructToTime(todayDt);

   //--- check if we crossed into a new day
   datetime today = GetDayStart(now);
   if(today != g_currentDay && now >= resetTime)
     {
      //--- end of day: store balance
      g_eodBalance = AccountInfoDouble(ACCOUNT_BALANCE);

      //--- new day
      g_currentDay = today;
      double bal = AccountInfoDouble(ACCOUNT_BALANCE);
      double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
      g_dayStartBalance = bal;
      g_dayStartEquity  = eq;

      //--- reset daily alerts
      g_dailyAlert80Sent = false;
      g_dailyAlertSent   = false;

      //--- count trading day if traded yesterday
      if(HasTradedOnDate(today - 86400))
         g_tradingDaysCount++;

      PrintFormat("Prop Dashboard: New day. Balance: %.2f | Trading days: %d",
                  bal, g_tradingDaysCount);
     }
  }

//+------------------------------------------------------------------+
//| Check if any trades were made today                                |
//+------------------------------------------------------------------+
bool HasTradedToday()
  {
   return HasTradedOnDate(GetDayStart(TimeCurrent()));
  }

//+------------------------------------------------------------------+
//| Check if any trades were made on a specific date                   |
//+------------------------------------------------------------------+
bool HasTradedOnDate(datetime dayStart)
  {
   datetime dayEnd = dayStart + 86400;

   //--- check open positions
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
     {
      if(PositionGetTicket(i) == 0) continue;
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      if(openTime >= dayStart && openTime < dayEnd)
         return true;
     }

   //--- check deal history
   if(HistorySelect(dayStart, dayEnd))
     {
      if(HistoryDealsTotal() > 0)
         return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Get day start timestamp                                            |
//+------------------------------------------------------------------+
datetime GetDayStart(datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   return StructToTime(dt);
  }

//+------------------------------------------------------------------+
//| Check and send alerts                                              |
//+------------------------------------------------------------------+
void CheckAlerts(const double dailyPct, const double totalDDPct)
  {
   //--- daily loss 80% warning
   if(InpAlertAt80Pct && g_rules.dailyLossLimit > 0 && !g_dailyAlert80Sent)
     {
      if(dailyPct < 0 && MathAbs(dailyPct) >= g_rules.dailyLossLimit * 0.8)
        {
         string msg = StringFormat("Prop Dashboard WARNING: Daily loss at %.2f%% (limit: %.1f%%)",
                                   MathAbs(dailyPct), g_rules.dailyLossLimit);
         SendPropAlert(msg);
         g_dailyAlert80Sent = true;
        }
     }

   //--- daily loss breach
   if(InpAlertAtBreach && g_rules.dailyLossLimit > 0 && !g_dailyAlertSent)
     {
      if(dailyPct < 0 && MathAbs(dailyPct) >= g_rules.dailyLossLimit)
        {
         string msg = StringFormat("Prop Dashboard BREACH: Daily loss limit HIT! %.2f%% >= %.1f%%",
                                   MathAbs(dailyPct), g_rules.dailyLossLimit);
         SendPropAlert(msg);
         g_dailyAlertSent = true;
        }
     }

   //--- max DD 80% warning
   if(InpAlertAt80Pct && g_rules.maxDrawdown > 0 && !g_maxDDAlert80Sent)
     {
      if(totalDDPct >= g_rules.maxDrawdown * 0.8)
        {
         string msg = StringFormat("Prop Dashboard WARNING: Max DD at %.2f%% (limit: %.1f%%)",
                                   totalDDPct, g_rules.maxDrawdown);
         SendPropAlert(msg);
         g_maxDDAlert80Sent = true;
        }
     }

   //--- max DD breach
   if(InpAlertAtBreach && g_rules.maxDrawdown > 0 && !g_maxDDAlertSent)
     {
      if(totalDDPct >= g_rules.maxDrawdown)
        {
         string msg = StringFormat("Prop Dashboard BREACH: Max drawdown HIT! %.2f%% >= %.1f%%",
                                   totalDDPct, g_rules.maxDrawdown);
         SendPropAlert(msg);
         g_maxDDAlertSent = true;
        }
     }
  }

//+------------------------------------------------------------------+
//| Send alert via configured channels                                 |
//+------------------------------------------------------------------+
void SendPropAlert(const string message)
  {
   Print(message);
   Alert(message);
   if(InpAlertPush)  SendNotification(message);
   if(InpAlertEmail) SendMail("Prop Dashboard Alert", message);
  }

//+------------------------------------------------------------------+
//|                    PANEL CREATION                                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create the full dashboard panel                                    |
//+------------------------------------------------------------------+
void CreatePanel()
  {
   int x = InpPanelX;
   int y = InpPanelY;
   int lineH = (int)(InpFontSize * 1.8);
   int barH  = 8;
   int gap   = 4;

   //--- background
   MakeRect(OBJ_PREFIX + "BG", x - 6, y - 6, g_panelWidth + 12, 600, InpPanelBg, InpBorderColor);

   //--- title
   MakeLabel(OBJ_PREFIX + "Title", x, y, "══ PROP DASHBOARD ══", InpHeaderColor, InpFontSize + 2);
   y += lineH + 2;

   //--- preset label
   string presetName = GetPresetName();
   MakeLabel(OBJ_PREFIX + "Preset", x, y, presetName, C'100,105,120', InpFontSize - 1);
   y += lineH;
   MakeLabel(OBJ_PREFIX + "Sep0", x, y, SepLine(), InpBorderColor, InpFontSize - 2);
   y += lineH - 2;

   //--- account section
   MakeLabel(OBJ_PREFIX + "SecAcct", x, y, "ACCOUNT", InpHeaderColor, InpFontSize);
   y += lineH;
   MakeLabel(OBJ_PREFIX + "Balance", x, y, "Balance: —", InpTextColor, InpFontSize);
   y += lineH;
   MakeLabel(OBJ_PREFIX + "Equity", x, y, "Equity:  —", InpTextColor, InpFontSize);
   y += lineH;
   MakeLabel(OBJ_PREFIX + "FloatPnL", x, y, "Floating: —", InpTextColor, InpFontSize);
   y += lineH + gap;

   MakeLabel(OBJ_PREFIX + "Sep1", x, y, SepLine(), InpBorderColor, InpFontSize - 2);
   y += lineH - 2;

   //--- daily loss section
   MakeLabel(OBJ_PREFIX + "SecDaily", x, y, "DAILY LOSS", InpHeaderColor, InpFontSize);
   y += lineH;
   MakeLabel(OBJ_PREFIX + "DailyPnL", x, y, "Today: —", InpTextColor, InpFontSize);
   y += lineH;
   MakeLabel(OBJ_PREFIX + "DailyBar", x, y, "", InpTextColor, InpFontSize); // placeholder for bar
   y += 2;
   MakeRect(OBJ_PREFIX + "DailyBarBg", x, y, g_panelWidth - 10, barH, C'25,28,38', C'25,28,38');
   MakeRect(OBJ_PREFIX + "DailyBarFill", x, y, 1, barH, InpSafeColor, InpSafeColor);
   y += barH + 2;
   MakeLabel(OBJ_PREFIX + "DailyPctInfo", x, y, "", C'80,85,100', InpFontSize - 2);
   y += lineH;
   MakeLabel(OBJ_PREFIX + "DailyRemain", x, y, "Remaining: —", InpTextColor, InpFontSize);
   y += lineH + gap;

   MakeLabel(OBJ_PREFIX + "Sep2", x, y, SepLine(), InpBorderColor, InpFontSize - 2);
   y += lineH - 2;

   //--- max drawdown section
   MakeLabel(OBJ_PREFIX + "SecMaxDD", x, y, "MAX DRAWDOWN", InpHeaderColor, InpFontSize);
   y += lineH;
   MakeLabel(OBJ_PREFIX + "MaxDDVal", x, y, "Drawdown: —", InpTextColor, InpFontSize);
   y += lineH;
   MakeRect(OBJ_PREFIX + "MaxDDBarBg", x, y, g_panelWidth - 10, barH, C'25,28,38', C'25,28,38');
   MakeRect(OBJ_PREFIX + "MaxDDBarFill", x, y, 1, barH, InpSafeColor, InpSafeColor);
   y += barH + 2;
   MakeLabel(OBJ_PREFIX + "MaxDDPctInfo", x, y, "", C'80,85,100', InpFontSize - 2);
   y += lineH;
   MakeLabel(OBJ_PREFIX + "MaxDDRemain", x, y, "Remaining: —", InpTextColor, InpFontSize);
   y += lineH;
   MakeLabel(OBJ_PREFIX + "DDMethod", x, y, "", C'80,85,100', InpFontSize - 2);
   y += lineH + gap;

   MakeLabel(OBJ_PREFIX + "Sep3", x, y, SepLine(), InpBorderColor, InpFontSize - 2);
   y += lineH - 2;

   //--- profit target section
   MakeLabel(OBJ_PREFIX + "SecTarget", x, y, "PROFIT TARGET", InpHeaderColor, InpFontSize);
   y += lineH;
   MakeLabel(OBJ_PREFIX + "TargetVal", x, y, "Progress: —", InpTextColor, InpFontSize);
   y += lineH;
   MakeRect(OBJ_PREFIX + "TargetBarBg", x, y, g_panelWidth - 10, barH, C'25,28,38', C'25,28,38');
   MakeRect(OBJ_PREFIX + "TargetBarFill", x, y, 1, barH, InpHeaderColor, InpHeaderColor);
   y += barH + 2;
   MakeLabel(OBJ_PREFIX + "TargetPctInfo", x, y, "", C'80,85,100', InpFontSize - 2);
   y += lineH;
   MakeLabel(OBJ_PREFIX + "TargetRemain", x, y, "Need: —", InpTextColor, InpFontSize);
   y += lineH + gap;

   MakeLabel(OBJ_PREFIX + "Sep4", x, y, SepLine(), InpBorderColor, InpFontSize - 2);
   y += lineH - 2;

   //--- challenge status
   MakeLabel(OBJ_PREFIX + "SecStatus", x, y, "CHALLENGE STATUS", InpHeaderColor, InpFontSize);
   y += lineH;
   MakeLabel(OBJ_PREFIX + "TradeDays", x, y, "Trading days: —", InpTextColor, InpFontSize);
   y += lineH;
   MakeLabel(OBJ_PREFIX + "CalDays", x, y, "Calendar days: —", InpTextColor, InpFontSize);
   y += lineH;
   MakeLabel(OBJ_PREFIX + "Verdict", x, y, "Status: —", InpSafeColor, InpFontSize);
   y += lineH + gap;

   //--- branding
   MakeLabel(OBJ_PREFIX + "Brand", x, y, "ExMachina Trading Systems", C'50,55,70', InpFontSize - 2);
   y += lineH;

   //--- resize background
   ObjectSetInteger(0, OBJ_PREFIX + "BG", OBJPROP_YSIZE, y - InpPanelY + 10);

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Update all panel values                                            |
//+------------------------------------------------------------------+
void UpdatePanel(const double balance,
                 const double equity,
                 const double dailyPnL,
                 const double dailyPnLPct,
                 const double totalDD,
                 const double totalDDPct,
                 const double totalPnL,
                 const double totalPnLPct,
                 const double targetPct,
                 const int calendarDays,
                 const int daysRemaining)
  {
   int barMaxW = g_panelWidth - 10;
   double floating = equity - balance;

   //--- account
   SetText(OBJ_PREFIX + "Balance",
           StringFormat("Balance:  %.2f", balance), InpTextColor);
   SetText(OBJ_PREFIX + "Equity",
           StringFormat("Equity:   %.2f", equity),
           (equity < balance) ? InpWarningColor : InpTextColor);

   color floatClr = (floating >= 0) ? InpSafeColor : InpDangerColor;
   SetText(OBJ_PREFIX + "FloatPnL",
           StringFormat("Floating: %s%.2f", (floating >= 0) ? "+" : "", floating), floatClr);

   //--- daily loss
   double dailyLoss = (dailyPnL < 0) ? MathAbs(dailyPnL) : 0;
   double dailyLossPct = (dailyPnLPct < 0) ? MathAbs(dailyPnLPct) : 0;
   double dailyUsedPct = (g_rules.dailyLossLimit > 0) ? (dailyLossPct / g_rules.dailyLossLimit) * 100.0 : 0;
   if(dailyUsedPct > 100) dailyUsedPct = 100;

   color dailyClr = GetStatusColor(dailyUsedPct);
   string dailySign = (dailyPnL >= 0) ? "+" : "";
   SetText(OBJ_PREFIX + "DailyPnL",
           StringFormat("Today: %s%.2f (%s%.2f%%)", dailySign, dailyPnL, dailySign, dailyPnLPct),
           dailyClr);

   //--- daily bar
   int dailyBarW = (int)MathMax(1, MathMin(barMaxW, barMaxW * dailyUsedPct / 100.0));
   ObjectSetInteger(0, OBJ_PREFIX + "DailyBarFill", OBJPROP_XSIZE, dailyBarW);
   ObjectSetInteger(0, OBJ_PREFIX + "DailyBarFill", OBJPROP_BGCOLOR, dailyClr);
   ObjectSetInteger(0, OBJ_PREFIX + "DailyBarFill", OBJPROP_BORDER_COLOR, dailyClr);

   if(g_rules.dailyLossLimit > 0)
     {
      SetText(OBJ_PREFIX + "DailyPctInfo",
              StringFormat("%.0f%% of %.1f%% limit used", dailyUsedPct, g_rules.dailyLossLimit),
              C'80,85,100');
      double dailyRemainMoney = (g_rules.dailyLossLimit / 100.0 * g_dayStartBalance) - dailyLoss;
      if(dailyRemainMoney < 0) dailyRemainMoney = 0;
      double dailyRemainPct = g_rules.dailyLossLimit - dailyLossPct;
      if(dailyRemainPct < 0) dailyRemainPct = 0;
      SetText(OBJ_PREFIX + "DailyRemain",
              StringFormat("Remaining: $%.2f (%.2f%%)", dailyRemainMoney, dailyRemainPct),
              (dailyRemainPct < 1.0) ? InpDangerColor : InpTextColor);
     }
   else
     {
      SetText(OBJ_PREFIX + "DailyPctInfo", "No daily limit", C'80,85,100');
      SetText(OBJ_PREFIX + "DailyRemain", "", InpTextColor);
     }

   //--- max drawdown
   double ddUsedPct = (g_rules.maxDrawdown > 0) ? (totalDDPct / g_rules.maxDrawdown) * 100.0 : 0;
   if(ddUsedPct > 100) ddUsedPct = 100;

   color ddClr = GetStatusColor(ddUsedPct);
   SetText(OBJ_PREFIX + "MaxDDVal",
           StringFormat("Drawdown: %.2f%% ($%.2f)", totalDDPct, totalDD), ddClr);

   int ddBarW = (int)MathMax(1, MathMin(barMaxW, barMaxW * ddUsedPct / 100.0));
   ObjectSetInteger(0, OBJ_PREFIX + "MaxDDBarFill", OBJPROP_XSIZE, ddBarW);
   ObjectSetInteger(0, OBJ_PREFIX + "MaxDDBarFill", OBJPROP_BGCOLOR, ddClr);
   ObjectSetInteger(0, OBJ_PREFIX + "MaxDDBarFill", OBJPROP_BORDER_COLOR, ddClr);

   if(g_rules.maxDrawdown > 0)
     {
      SetText(OBJ_PREFIX + "MaxDDPctInfo",
              StringFormat("%.0f%% of %.1f%% limit used", ddUsedPct, g_rules.maxDrawdown),
              C'80,85,100');
      double ddRemain = g_rules.maxDrawdown - totalDDPct;
      if(ddRemain < 0) ddRemain = 0;
      double ddRemainMoney = ddRemain / 100.0 * g_startBalance;
      SetText(OBJ_PREFIX + "MaxDDRemain",
              StringFormat("Remaining: $%.2f (%.2f%%)", ddRemainMoney, ddRemain),
              (ddRemain < 2.0) ? InpDangerColor : InpTextColor);
     }
   else
     {
      SetText(OBJ_PREFIX + "MaxDDPctInfo", "No max DD limit", C'80,85,100');
      SetText(OBJ_PREFIX + "MaxDDRemain", "", InpTextColor);
     }

   //--- DD method label
   string ddMethodStr = "";
   switch(g_rules.ddMethod)
     {
      case DD_FROM_BALANCE:     ddMethodStr = "Method: From initial balance (static)"; break;
      case DD_FROM_EQUITY_HWM:  ddMethodStr = "Method: Equity high-water mark (trailing)"; break;
      case DD_FROM_EOD_BALANCE: ddMethodStr = "Method: End-of-day balance"; break;
     }
   SetText(OBJ_PREFIX + "DDMethod", ddMethodStr, C'80,85,100');

   //--- profit target
   double cappedTargetPct = MathMin(targetPct, 100.0);
   if(cappedTargetPct < 0) cappedTargetPct = 0;

   color targetClr = InpHeaderColor;
   if(targetPct >= 100) targetClr = InpTargetColor;
   else if(targetPct >= 70) targetClr = InpSafeColor;

   SetText(OBJ_PREFIX + "TargetVal",
           StringFormat("Progress: %s%.2f%% of %.1f%%",
                        (totalPnLPct >= 0) ? "+" : "", totalPnLPct, g_rules.profitTarget),
           targetClr);

   int targetBarW = (int)MathMax(1, MathMin(barMaxW, barMaxW * cappedTargetPct / 100.0));
   color tBarClr = (targetPct >= 100) ? InpTargetColor : InpHeaderColor;
   ObjectSetInteger(0, OBJ_PREFIX + "TargetBarFill", OBJPROP_XSIZE, targetBarW);
   ObjectSetInteger(0, OBJ_PREFIX + "TargetBarFill", OBJPROP_BGCOLOR, tBarClr);
   ObjectSetInteger(0, OBJ_PREFIX + "TargetBarFill", OBJPROP_BORDER_COLOR, tBarClr);

   if(g_rules.profitTarget > 0)
     {
      SetText(OBJ_PREFIX + "TargetPctInfo",
              StringFormat("%.0f%% complete", cappedTargetPct), C'80,85,100');
      double needMoney = (g_rules.profitTarget / 100.0 * g_startBalance) - totalPnL;
      if(needMoney < 0) needMoney = 0;
      double needPct = g_rules.profitTarget - totalPnLPct;
      if(needPct < 0) needPct = 0;

      if(targetPct >= 100)
         SetText(OBJ_PREFIX + "TargetRemain", "TARGET REACHED!", InpTargetColor);
      else
         SetText(OBJ_PREFIX + "TargetRemain",
                 StringFormat("Need: $%.2f (%.2f%%)", needMoney, needPct), InpTextColor);
     }
   else
     {
      SetText(OBJ_PREFIX + "TargetPctInfo", "No profit target", C'80,85,100');
      SetText(OBJ_PREFIX + "TargetRemain",
              StringFormat("P&L: %s$%.2f", (totalPnL >= 0) ? "+" : "", totalPnL),
              (totalPnL >= 0) ? InpSafeColor : InpDangerColor);
     }

   //--- challenge status
   int tradeDays = g_tradingDaysCount;
   if(HasTradedToday() && !IsNewDay())
      tradeDays = g_tradingDaysCount + 1;

   string tdExtra = "";
   if(g_rules.minTradingDays > 0)
     {
      int remaining = g_rules.minTradingDays - tradeDays;
      if(remaining > 0)
         tdExtra = StringFormat(" (need %d more)", remaining);
      else
         tdExtra = " ✓";
     }
   SetText(OBJ_PREFIX + "TradeDays",
           StringFormat("Trading days: %d%s", tradeDays, tdExtra), InpTextColor);

   string calExtra = "";
   if(daysRemaining >= 0)
      calExtra = StringFormat(" (%d remaining)", MathMax(0, daysRemaining));
   SetText(OBJ_PREFIX + "CalDays",
           StringFormat("Calendar days: %d%s", calendarDays, calExtra),
           (daysRemaining >= 0 && daysRemaining <= 3) ? InpWarningColor : InpTextColor);

   //--- overall verdict
   string verdict = "";
   color  verdictClr = InpSafeColor;

   bool dailyBreached = (g_rules.dailyLossLimit > 0 && dailyLossPct >= g_rules.dailyLossLimit);
   bool ddBreached    = (g_rules.maxDrawdown > 0 && totalDDPct >= g_rules.maxDrawdown);
   bool timeExpired   = (daysRemaining == 0);
   bool targetHit     = (targetPct >= 100);
   bool minDaysMet    = (g_rules.minTradingDays <= 0 || tradeDays >= g_rules.minTradingDays);

   if(dailyBreached || ddBreached)
     {
      verdict = "FAILED — LIMIT BREACHED";
      verdictClr = InpDangerColor;
     }
   else if(timeExpired && !targetHit)
     {
      verdict = "FAILED — TIME EXPIRED";
      verdictClr = InpDangerColor;
     }
   else if(targetHit && minDaysMet)
     {
      verdict = "PASSED!";
      verdictClr = InpTargetColor;
     }
   else if(targetHit && !minDaysMet)
     {
      verdict = "TARGET HIT — Need more days";
      verdictClr = InpWarningColor;
     }
   else if(ddUsedPct >= 80 || dailyUsedPct >= 80)
     {
      verdict = "AT RISK — Approaching limits";
      verdictClr = InpWarningColor;
     }
   else
     {
      verdict = "ON TRACK";
      verdictClr = InpSafeColor;
     }

   SetText(OBJ_PREFIX + "Verdict", StringFormat("Status: %s", verdict), verdictClr);
  }

//+------------------------------------------------------------------+
//| Helper: check if it's a brand new day (no trades yet)              |
//+------------------------------------------------------------------+
bool IsNewDay()
  {
   return (GetDayStart(TimeCurrent()) != g_currentDay);
  }

//+------------------------------------------------------------------+
//| Get color based on usage percentage                                |
//+------------------------------------------------------------------+
color GetStatusColor(const double usedPct)
  {
   if(usedPct >= 100)  return InpDangerColor;
   if(usedPct >= 80)   return InpDangerColor;
   if(usedPct >= 50)   return InpWarningColor;
   return InpSafeColor;
  }

//+------------------------------------------------------------------+
//| Get preset display name                                            |
//+------------------------------------------------------------------+
string GetPresetName()
  {
   switch(InpPreset)
     {
      case PRESET_FTMO:    return StringFormat("FTMO | $%.0fK", InpAccountSize / 1000);
      case PRESET_MFF:     return StringFormat("MyFundedFX | $%.0fK", InpAccountSize / 1000);
      case PRESET_TFT:     return StringFormat("The Funded Trader | $%.0fK", InpAccountSize / 1000);
      case PRESET_E8:      return StringFormat("E8 Funding | $%.0fK", InpAccountSize / 1000);
      case PRESET_BULENOX: return StringFormat("Bulenox | $%.0fK", InpAccountSize / 1000);
      default:             return StringFormat("Custom Rules | $%.0fK", InpAccountSize / 1000);
     }
  }

//+------------------------------------------------------------------+
//| Separator line string                                              |
//+------------------------------------------------------------------+
string SepLine()
  {
   return "────────────────────────────────";
  }

//+------------------------------------------------------------------+
//|                    UI PRIMITIVES                                    |
//+------------------------------------------------------------------+

void MakeLabel(const string name, int x, int y,
               const string text, color clr, int fontSize)
  {
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0,  name, OBJPROP_TEXT, text);
   ObjectSetString(0,  name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

void MakeRect(const string name, int x, int y, int w, int h,
              color bgClr, color borderClr)
  {
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgClr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, borderClr);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

void SetText(const string name, const string text, color clr)
  {
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
  }
//+------------------------------------------------------------------+
