//+------------------------------------------------------------------+
//|                                           ASQ_SpreadLogger.mq5   |
//|                              Copyright 2026, AlgoSphere Quant    |
//|                      https://www.mql5.com/en/users/robin2.0      |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, AlgoSphere Quant"
#property link        "https://www.mql5.com/en/users/robin2.0"
#property version     "1.00"
#property description "ASQ Spread Logger — Real-time spread monitoring, statistics & CSV logging."
#property description "Tracks live spread with color-coded histogram, on-chart stats panel,"
#property description "configurable threshold alerts, and per-tick CSV export."
#property description ""
#property description "Free & open-source. AlgoSphere Quant — Precision before profit."
#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   1
#property strict

//--- Plot: Spread histogram
#property indicator_label1  "Spread"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrLimeGreen,clrGold,clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//+------------------------------------------------------------------+
//| ENUMS                                                             |
//+------------------------------------------------------------------+
enum ENUM_LOG_FREQUENCY
  {
   LOG_EVERY_TICK   = 0, // Every tick
   LOG_EVERY_SECOND = 1, // Every second
   LOG_EVERY_BAR    = 2  // Every new bar
  };

enum ENUM_PANEL_CORNER
  {
   PANEL_TOP_LEFT     = CORNER_LEFT_UPPER,  // Top-Left
   PANEL_TOP_RIGHT    = CORNER_RIGHT_UPPER, // Top-Right
   PANEL_BOTTOM_LEFT  = CORNER_LEFT_LOWER,  // Bottom-Left
   PANEL_BOTTOM_RIGHT = CORNER_RIGHT_LOWER  // Bottom-Right
  };

//+------------------------------------------------------------------+
//| INPUTS                                                            |
//+------------------------------------------------------------------+
input group "══════ Spread Thresholds ══════"
input int               InpLowThreshold     = 15;           // Low threshold (points)
input int               InpHighThreshold    = 40;           // High threshold (points)

input group "══════ CSV Logging ══════"
input bool              InpEnableCSV        = true;         // Enable CSV logging
input ENUM_LOG_FREQUENCY InpLogFrequency    = LOG_EVERY_BAR;// Log frequency
input string            InpCSVFilename      = "";           // CSV filename (blank=auto)

input group "══════ Statistics ══════"
input int               InpStatsWindow      = 500;          // Rolling stats window (ticks/bars)

input group "══════ Alerts ══════"
input bool              InpAlertOnHigh      = true;         // Alert when spread exceeds high threshold
input bool              InpAlertPush        = false;        // Send push notification
input bool              InpAlertEmail       = false;        // Send email notification
input int               InpAlertCooldown    = 60;           // Alert cooldown (seconds)

input group "══════ Display ══════"
input bool              InpShowPanel        = true;         // Show on-chart stats panel
input ENUM_PANEL_CORNER InpPanelCorner      = PANEL_TOP_LEFT; // Panel corner
input int               InpPanelXOffset     = 20;           // Panel X offset (px)
input int               InpPanelYOffset     = 30;           // Panel Y offset (px)
input int               InpFontSize         = 10;           // Font size
input color             InpPanelBG          = C'22,22,30';  // Panel background
input color             InpTextColor        = C'180,185,195';// Text color
input color             InpHeaderColor      = C'255,200,40';// Header color
input color             InpGoodColor        = clrLimeGreen; // Good spread color
input color             InpWarnColor        = clrGold;      // Medium spread color
input color             InpBadColor         = clrCrimson;   // High spread color
input bool              InpShowThresholds   = true;         // Show threshold lines on histogram
input int               InpMaxBars          = 5000;         // Max bars to calculate

//+------------------------------------------------------------------+
//| CONSTANTS & GLOBALS                                               |
//+------------------------------------------------------------------+
const string OBJ_PREFIX = "ASQSL_";

//--- Buffers
double g_spreadBuf[];
double g_colorBuf[];
double g_avgBuf[];

//--- Statistics
double g_statsArray[];
int    g_statsCount   = 0;
int    g_statsHead    = 0;
double g_statsSum     = 0.0;
double g_statsMin     = DBL_MAX;
double g_statsMax     = 0.0;

//--- CSV
int    g_csvHandle    = INVALID_HANDLE;
string g_csvFilename  = "";

//--- Alert
datetime g_lastAlertTime = 0;

//--- Logging
datetime g_lastLogTime   = 0;
datetime g_lastBarTime   = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Validate inputs
   if(InpLowThreshold <= 0 || InpHighThreshold <= 0)
     {
      Print("[ASQ SpreadLogger] ERROR: Thresholds must be > 0");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpLowThreshold >= InpHighThreshold)
     {
      Print("[ASQ SpreadLogger] ERROR: Low threshold must be < High threshold");
      return(INIT_PARAMETERS_INCORRECT);
     }

//--- Buffers
   SetIndexBuffer(0, g_spreadBuf, INDICATOR_DATA);
   SetIndexBuffer(1, g_colorBuf,  INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, g_avgBuf,    INDICATOR_DATA);

   ArraySetAsSeries(g_spreadBuf, true);
   ArraySetAsSeries(g_colorBuf,  true);
   ArraySetAsSeries(g_avgBuf,    true);

//--- Indicator settings
   IndicatorSetString(INDICATOR_SHORTNAME, "ASQ SpreadLogger (" +
                      IntegerToString(InpLowThreshold) + "/" +
                      IntegerToString(InpHighThreshold) + ")");
   IndicatorSetInteger(INDICATOR_DIGITS, 1);

//--- Threshold lines
   if(InpShowThresholds)
     {
      CreateHLine(OBJ_PREFIX + "LowLine",  (double)InpLowThreshold,  InpGoodColor, STYLE_DOT, 1);
      CreateHLine(OBJ_PREFIX + "HighLine", (double)InpHighThreshold, InpBadColor,  STYLE_DOT, 1);
     }

//--- Stats array (circular buffer)
   int windowSize = MathMax(10, InpStatsWindow);
   ArrayResize(g_statsArray, windowSize);
   ArrayInitialize(g_statsArray, 0.0);
   g_statsCount = 0;
   g_statsHead  = 0;
   g_statsSum   = 0.0;
   g_statsMin   = DBL_MAX;
   g_statsMax   = 0.0;

//--- CSV setup
   if(InpEnableCSV)
     {
      if(InpCSVFilename == "")
         g_csvFilename = "ASQ_SpreadLog_" + _Symbol + ".csv";
      else
         g_csvFilename = InpCSVFilename;

      g_csvHandle = FileOpen(g_csvFilename, FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ',');
      if(g_csvHandle == INVALID_HANDLE)
        {
         Print("[ASQ SpreadLogger] WARNING: Cannot open CSV file: ", g_csvFilename,
               " Error=", GetLastError());
        }
      else
        {
         //--- Write header
         FileWrite(g_csvHandle, "DateTime", "Symbol", "Spread_Points", "Spread_Pips",
                   "Bid", "Ask", "Avg_Spread", "Min_Spread", "Max_Spread", "Status");
         FileFlush(g_csvHandle);
         Print("[ASQ SpreadLogger] CSV logging started → MQL5/Files/", g_csvFilename);
        }
     }

//--- Panel
   if(InpShowPanel)
      CreatePanel();

   Print("[ASQ SpreadLogger] v1.00 initialized on ", _Symbol,
         " | Thresholds: ", InpLowThreshold, "/", InpHighThreshold,
         " | CSV: ", (InpEnableCSV ? "ON" : "OFF"),
         " | Alerts: ", (InpAlertOnHigh ? "ON" : "OFF"));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Close CSV
   if(g_csvHandle != INVALID_HANDLE)
     {
      FileClose(g_csvHandle);
      g_csvHandle = INVALID_HANDLE;
      Print("[ASQ SpreadLogger] CSV file closed: ", g_csvFilename,
            " | Total samples: ", g_statsCount);
     }

//--- Clean objects
   ObjectsDeleteAll(0, OBJ_PREFIX);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration                                        |
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
   ArraySetAsSeries(spread, true);
   ArraySetAsSeries(time,   true);

//--- Determine calc range
   int limit;
   if(prev_calculated == 0)
      limit = MathMin(rates_total - 1, InpMaxBars);
   else
      limit = rates_total - prev_calculated + 1;

//--- Fill histogram from history
   for(int i = limit; i >= 1; i--)
     {
      double sp = (double)spread[i];
      g_spreadBuf[i] = sp;
      g_avgBuf[i]    = 0.0;

      if(sp <= InpLowThreshold)
         g_colorBuf[i] = 0.0; // Green
      else if(sp <= InpHighThreshold)
         g_colorBuf[i] = 1.0; // Gold
      else
         g_colorBuf[i] = 2.0; // Red
     }

//--- Current bar (bar 0) — use live spread
   double currentSpread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   g_spreadBuf[0] = currentSpread;

   if(currentSpread <= InpLowThreshold)
      g_colorBuf[0] = 0.0;
   else if(currentSpread <= InpHighThreshold)
      g_colorBuf[0] = 1.0;
   else
      g_colorBuf[0] = 2.0;

//--- Update statistics (circular buffer)
   UpdateStats(currentSpread);

//--- Avg line on bar 0
   g_avgBuf[0] = (g_statsCount > 0) ? g_statsSum / g_statsCount : currentSpread;

//--- CSV logging
   if(InpEnableCSV && g_csvHandle != INVALID_HANDLE)
      TryLogCSV(currentSpread);

//--- Alert
   if(InpAlertOnHigh && currentSpread > InpHighThreshold)
      TryAlert(currentSpread);

//--- Update panel
   if(InpShowPanel)
      UpdatePanel(currentSpread);

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| STATISTICS — Circular buffer                                      |
//+------------------------------------------------------------------+
void UpdateStats(double spread)
  {
   int windowSize = ArraySize(g_statsArray);

   if(g_statsCount < windowSize)
     {
      //--- Buffer not full yet
      g_statsArray[g_statsCount] = spread;
      g_statsCount++;
      g_statsSum += spread;
     }
   else
     {
      //--- Overwrite oldest value
      g_statsSum -= g_statsArray[g_statsHead];
      g_statsArray[g_statsHead] = spread;
      g_statsSum += spread;
      g_statsHead = (g_statsHead + 1) % windowSize;
     }

//--- Min / Max (recalculate from buffer for accuracy)
   g_statsMin = DBL_MAX;
   g_statsMax = 0.0;
   int count  = MathMin(g_statsCount, windowSize);
   for(int i = 0; i < count; i++)
     {
      if(g_statsArray[i] < g_statsMin) g_statsMin = g_statsArray[i];
      if(g_statsArray[i] > g_statsMax) g_statsMax = g_statsArray[i];
     }
  }

//+------------------------------------------------------------------+
//| CSV — Conditional logging based on frequency                      |
//+------------------------------------------------------------------+
void TryLogCSV(double spread)
  {
   datetime now = TimeCurrent();
   bool doLog = false;

   switch(InpLogFrequency)
     {
      case LOG_EVERY_TICK:
         doLog = true;
         break;

      case LOG_EVERY_SECOND:
         if(now != g_lastLogTime)
           {
            doLog = true;
            g_lastLogTime = now;
           }
         break;

      case LOG_EVERY_BAR:
        {
         datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
         if(barTime != g_lastBarTime)
           {
            doLog = true;
            g_lastBarTime = barTime;
           }
        }
      break;
     }

   if(!doLog)
      return;

//--- Write row
   double bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double avgS = (g_statsCount > 0) ? g_statsSum / g_statsCount : spread;
   double pipDiv = (_Digits == 3 || _Digits == 5) ? 10.0 : 1.0;

   string status;
   if(spread <= InpLowThreshold)
      status = "LOW";
   else if(spread <= InpHighThreshold)
      status = "MEDIUM";
   else
      status = "HIGH";

   FileWrite(g_csvHandle,
             TimeToString(now, TIME_DATE | TIME_SECONDS),
             _Symbol,
             DoubleToString(spread, 0),
             DoubleToString(spread / pipDiv, 1),
             DoubleToString(bid, _Digits),
             DoubleToString(ask, _Digits),
             DoubleToString(avgS, 1),
             DoubleToString(g_statsMin, 0),
             DoubleToString(g_statsMax, 0),
             status);
   FileFlush(g_csvHandle);
  }

//+------------------------------------------------------------------+
//| ALERTS — with cooldown                                            |
//+------------------------------------------------------------------+
void TryAlert(double spread)
  {
   datetime now = TimeCurrent();
   if(now - g_lastAlertTime < InpAlertCooldown)
      return;

   g_lastAlertTime = now;

   string msg = StringFormat("[ASQ SpreadLogger] %s spread = %.0f pts (threshold: %d) at %s",
                             _Symbol, spread, InpHighThreshold,
                             TimeToString(now, TIME_SECONDS));

   Alert(msg);

   if(InpAlertPush)
      SendNotification(msg);

   if(InpAlertEmail)
      SendMail("ASQ Spread Alert: " + _Symbol, msg);
  }

//+------------------------------------------------------------------+
//| PANEL — Create objects                                            |
//+------------------------------------------------------------------+
void CreatePanel()
  {
   int corner = (int)InpPanelCorner;
   int x      = InpPanelXOffset;
   int y      = InpPanelYOffset;
   int lineH  = InpFontSize + 6;

//--- Background rectangle
   CreatePanelBG(OBJ_PREFIX + "BG", x - 6, y - 6, 200, lineH * 8 + 16, InpPanelBG);

//--- Header
   CreateLabel(OBJ_PREFIX + "Header", "ASQ Spread Logger", x, y,
               InpHeaderColor, InpFontSize + 1, "Consolas", corner, true);
   y += lineH + 4;

//--- Separator
   CreateLabel(OBJ_PREFIX + "Sep1", "─────────────────", x, y,
               C'60,60,80', InpFontSize - 2, "Consolas", corner, false);
   y += lineH - 2;

//--- Data rows
   CreateLabel(OBJ_PREFIX + "RowCur",  "Spread:  ---", x, y,
               InpTextColor, InpFontSize, "Consolas", corner, false);
   y += lineH;

   CreateLabel(OBJ_PREFIX + "RowAvg",  "Avg:     ---", x, y,
               InpTextColor, InpFontSize, "Consolas", corner, false);
   y += lineH;

   CreateLabel(OBJ_PREFIX + "RowMin",  "Min:     ---", x, y,
               InpTextColor, InpFontSize, "Consolas", corner, false);
   y += lineH;

   CreateLabel(OBJ_PREFIX + "RowMax",  "Max:     ---", x, y,
               InpTextColor, InpFontSize, "Consolas", corner, false);
   y += lineH;

   CreateLabel(OBJ_PREFIX + "RowStat", "Status:  ---", x, y,
               InpTextColor, InpFontSize, "Consolas", corner, false);
   y += lineH;

//--- Footer
   CreateLabel(OBJ_PREFIX + "RowCSV",  "CSV: " + (InpEnableCSV ? "ON" : "OFF"), x, y,
               C'100,100,120', InpFontSize - 1, "Consolas", corner, false);
  }

//+------------------------------------------------------------------+
//| PANEL — Update values                                             |
//+------------------------------------------------------------------+
void UpdatePanel(double spread)
  {
   double avgS  = (g_statsCount > 0) ? g_statsSum / g_statsCount : spread;
   double pipDiv = (_Digits == 3 || _Digits == 5) ? 10.0 : 1.0;

//--- Color based on spread level
   color  clrSpread;
   string status;
   if(spread <= InpLowThreshold)
     { clrSpread = InpGoodColor; status = "LOW";    }
   else if(spread <= InpHighThreshold)
     { clrSpread = InpWarnColor; status = "MEDIUM"; }
   else
     { clrSpread = InpBadColor;  status = "HIGH";   }

//--- Update labels
   ObjectSetString(0, OBJ_PREFIX + "RowCur", OBJPROP_TEXT,
                   StringFormat("Spread:  %.0f pts (%.1f pip)", spread, spread / pipDiv));
   ObjectSetInteger(0, OBJ_PREFIX + "RowCur", OBJPROP_COLOR, clrSpread);

   ObjectSetString(0, OBJ_PREFIX + "RowAvg", OBJPROP_TEXT,
                   StringFormat("Avg:     %.1f pts", avgS));

   ObjectSetString(0, OBJ_PREFIX + "RowMin", OBJPROP_TEXT,
                   StringFormat("Min:     %.0f pts", (g_statsMin == DBL_MAX ? 0.0 : g_statsMin)));
   ObjectSetInteger(0, OBJ_PREFIX + "RowMin", OBJPROP_COLOR, InpGoodColor);

   ObjectSetString(0, OBJ_PREFIX + "RowMax", OBJPROP_TEXT,
                   StringFormat("Max:     %.0f pts", g_statsMax));
   ObjectSetInteger(0, OBJ_PREFIX + "RowMax", OBJPROP_COLOR, InpBadColor);

   ObjectSetString(0, OBJ_PREFIX + "RowStat", OBJPROP_TEXT,
                   "Status:  " + status);
   ObjectSetInteger(0, OBJ_PREFIX + "RowStat", OBJPROP_COLOR, clrSpread);

//--- CSV row count footer
   if(InpEnableCSV)
      ObjectSetString(0, OBJ_PREFIX + "RowCSV", OBJPROP_TEXT,
                      StringFormat("CSV: ON | %d samples", g_statsCount));

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| HELPERS — Object creation                                         |
//+------------------------------------------------------------------+
void CreateHLine(const string name, double price, color clr, ENUM_LINE_STYLE style, int width)
  {
   if(ObjectFind(ChartWindowFind(), name) >= 0)
      ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_HLINE, ChartWindowFind(), 0, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_BACK,  true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
  }

//+------------------------------------------------------------------+
void CreateLabel(const string name, const string text,
                 int x, int y, color clr, int fontSize,
                 const string font, int corner, bool bold)
  {
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0,  name, OBJPROP_TEXT,     text);
   ObjectSetString(0,  name, OBJPROP_FONT,     font);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, name, OBJPROP_CORNER,    corner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR,    ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
  }

//+------------------------------------------------------------------+
void CreatePanelBG(const string name, int x, int y, int w, int h, color clr)
  {
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER,      (int)InpPanelCorner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,   x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,   y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,        w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,        h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE,  BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'50,50,65');
   ObjectSetInteger(0, name, OBJPROP_WIDTH,        1);
   ObjectSetInteger(0, name, OBJPROP_BACK,         false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,   false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,       true);
  }
//+------------------------------------------------------------------+
