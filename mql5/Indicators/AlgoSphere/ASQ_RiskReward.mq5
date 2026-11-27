//+------------------------------------------------------------------+
//|                                             ASQ_RiskReward.mq5   |
//|                              Copyright 2026, AlgoSphere Quant    |
//|                        https://www.mql5.com/en/users/robin2.0    |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, AlgoSphere Quant"
#property link        "https://www.mql5.com/en/users/robin2.0"
#property version     "2.00"
#property description "ASQ RiskReward v2 — Visual trade planning indicator"
#property description "Drag Entry/SL/TP lines, real-time R:R ratio, lot size,"
#property description "multi-TP levels, risk/reward in $, zone shading."
#property description "AlgoSphere Quant — Precision before profit."
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0
#property strict

//+------------------------------------------------------------------+
//| Inputs                                                            |
//+------------------------------------------------------------------+
input group              "═══════ RISK SETTINGS ═══════"
input double             InpRiskPercent     = 1.0;             // Risk % of Balance
input double             InpFixedLots       = 0.0;             // Fixed Lots (0 = use risk %)

input group              "═══════ MULTI-TP ═══════"
input bool               InpEnableTP2       = false;           // Enable TP2 line
input bool               InpEnableTP3       = false;           // Enable TP3 line
input double             InpTP1Pct          = 50.0;            // TP1 close % (if multi-TP)
input double             InpTP2Pct          = 30.0;            // TP2 close %
input double             InpTP3Pct          = 20.0;            // TP3 close %

input group              "═══════ VISUAL SETTINGS ═══════"
input color              InpEntryColor      = C'0,150,255';    // Entry Line Color
input color              InpSLColor         = C'240,50,70';    // SL Line Color
input color              InpTP1Color        = C'0,200,120';    // TP1 Line Color
input color              InpTP2Color        = C'0,180,200';    // TP2 Line Color
input color              InpTP3Color        = C'120,80,255';   // TP3 Line Color
input int                InpLineWidth       = 2;               // Line Width
input bool               InpShowZoneFill    = true;            // Show Risk/Reward Zone Shading
input ENUM_LINE_STYLE    InpTPStyle         = STYLE_SOLID;     // TP Line Style

input group              "═══════ DASHBOARD ═══════"
input bool               InpShowDashboard   = true;            // Show Dashboard
input int                InpDashX           = 20;              // X Position
input int                InpDashY           = 30;              // Y Position
input int                InpFontSize        = 9;               // Font Size
input color              InpBgColor         = C'12,14,22';     // Background
input color              InpBorderColor     = C'28,32,48';     // Border Color
input color              InpTextColor       = C'175,180,192';  // Text Color
input color              InpDimColor        = C'70,75,90';     // Dim Text Color
input color              InpAccentColor     = C'0,150,255';    // Accent Color

//+------------------------------------------------------------------+
//| Constants                                                         |
//+------------------------------------------------------------------+
const string P            = "ASQ_RR_";          // Object prefix
const string IND_NAME     = "ASQ RiskReward";
const string IND_VERSION  = "2.0";

//+------------------------------------------------------------------+
//| Globals                                                           |
//+------------------------------------------------------------------+
double g_entry = 0, g_sl = 0, g_tp1 = 0, g_tp2 = 0, g_tp3 = 0;
bool   g_ready = false;
int    g_digits = 5;
double g_pipSize = 0.0001;
double g_pipValue = 0;

//+------------------------------------------------------------------+
//| Init                                                              |
//+------------------------------------------------------------------+
int OnInit()
  {
   IndicatorSetString(INDICATOR_SHORTNAME, IND_NAME + " v" + IND_VERSION);

   g_digits  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_pipSize = (g_digits == 3 || g_digits == 5) ? _Point * 10 : _Point;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_entry = NormalizeDouble(bid, g_digits);
   g_sl    = NormalizeDouble(bid - 20 * g_pipSize, g_digits);
   g_tp1   = NormalizeDouble(bid + 40 * g_pipSize, g_digits);
   g_tp2   = NormalizeDouble(bid + 70 * g_pipSize, g_digits);
   g_tp3   = NormalizeDouble(bid + 100 * g_pipSize, g_digits);

   CreateLine("Entry", g_entry, InpEntryColor, "ENTRY", STYLE_SOLID);
   CreateLine("SL",    g_sl,    InpSLColor,    "STOP LOSS", STYLE_SOLID);
   CreateLine("TP1",   g_tp1,   InpTP1Color,   "TP1", InpTPStyle);
   if(InpEnableTP2) CreateLine("TP2", g_tp2, InpTP2Color, "TP2", InpTPStyle);
   if(InpEnableTP3) CreateLine("TP3", g_tp3, InpTP3Color, "TP3", InpTPStyle);

   if(InpShowDashboard) CreateDashboard();

   g_ready = true;
   ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason) { ObjectsDeleteAll(0, P); ChartRedraw(0); }

//+------------------------------------------------------------------+
//| OnCalculate — update on each tick                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[],
                const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
  {
   if(!g_ready) return(rates_total);
   ReadPrices();
   CalcPipValue();
   UpdateZones();
   if(InpShowDashboard) UpdateDashboard();
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Chart events — drag detection + double-click snap                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_DRAG)
     {
      if(StringFind(sparam, P + "L_") >= 0)
        {
         ReadPrices();
         CalcPipValue();
         UpdateZones();
         if(InpShowDashboard) UpdateDashboard();
        }
     }

//--- double-click on entry line → snap to current bid
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam == P + "L_Entry")
        {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         ObjectSetDouble(0, P + "L_Entry", OBJPROP_PRICE, 0, NormalizeDouble(bid, g_digits));
         ReadPrices();
         CalcPipValue();
         UpdateZones();
         if(InpShowDashboard) UpdateDashboard();
         ChartRedraw(0);
        }
     }
  }

//+------------------------------------------------------------------+
//| Create a draggable horizontal line                                 |
//+------------------------------------------------------------------+
void CreateLine(string id, double price, color clr, string label, ENUM_LINE_STYLE style)
  {
   string name = P + "L_" + id;
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, InpLineWidth);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetString(0, name, OBJPROP_TEXT, label);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, label + " — drag to adjust");
  }

//+------------------------------------------------------------------+
//| Read all line prices                                               |
//+------------------------------------------------------------------+
void ReadPrices()
  {
   g_entry = ObjectGetDouble(0, P + "L_Entry", OBJPROP_PRICE, 0);
   g_sl    = ObjectGetDouble(0, P + "L_SL",    OBJPROP_PRICE, 0);
   g_tp1   = ObjectGetDouble(0, P + "L_TP1",   OBJPROP_PRICE, 0);
   if(InpEnableTP2) g_tp2 = ObjectGetDouble(0, P + "L_TP2", OBJPROP_PRICE, 0);
   if(InpEnableTP3) g_tp3 = ObjectGetDouble(0, P + "L_TP3", OBJPROP_PRICE, 0);
  }

//+------------------------------------------------------------------+
//| Calculate pip value for current symbol                             |
//+------------------------------------------------------------------+
void CalcPipValue()
  {
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double pointVal  = (tickSize > 0) ? tickValue / (tickSize / _Point) : 0;
   g_pipValue = (g_digits == 3 || g_digits == 5) ? pointVal * 10 : pointVal;
  }

//+------------------------------------------------------------------+
//| Update risk/reward zone rectangles                                 |
//+------------------------------------------------------------------+
void UpdateZones()
  {
   if(!InpShowZoneFill) return;

   datetime t1 = TimeCurrent() - PeriodSeconds() * 30;
   datetime t2 = TimeCurrent() + PeriodSeconds() * 15;

   //--- Risk zone (entry → SL)
   UpdateRect("Z_Risk", MathMax(g_entry, g_sl), MathMin(g_entry, g_sl), t1, t2, InpSLColor);

   //--- Reward zone (entry → TP1)
   UpdateRect("Z_Rwd1", MathMax(g_entry, g_tp1), MathMin(g_entry, g_tp1), t1, t2, InpTP1Color);

   //--- Extended TP zones
   if(InpEnableTP2)
      UpdateRect("Z_Rwd2", MathMax(g_tp1, g_tp2), MathMin(g_tp1, g_tp2), t1, t2, InpTP2Color);
   if(InpEnableTP3)
      UpdateRect("Z_Rwd3", MathMax(g_tp2, g_tp3), MathMin(g_tp2, g_tp3), t1, t2, InpTP3Color);
  }

//+------------------------------------------------------------------+
//| Create or update a filled rectangle                                |
//+------------------------------------------------------------------+
void UpdateRect(string id, double priceH, double priceL, datetime t1, datetime t2, color clr)
  {
   string name = P + id;
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, priceH, t2, priceL);
   else
     {
      ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 0, priceH);
      ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 1, priceL);
     }
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
  }

//+------------------------------------------------------------------+
//| Create dashboard background                                        |
//+------------------------------------------------------------------+
void CreateDashboard()
  {
   string bg = P + "D_BG";
   ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, InpDashX);
   ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, InpDashY);
   ObjectSetInteger(0, bg, OBJPROP_XSIZE, 295);
   ObjectSetInteger(0, bg, OBJPROP_YSIZE, 420);
   ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, InpBgColor);
   ObjectSetInteger(0, bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bg, OBJPROP_BORDER_COLOR, InpBorderColor);
   ObjectSetInteger(0, bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bg, OBJPROP_BACK, false);
   ObjectSetInteger(0, bg, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bg, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//| Update full dashboard                                              |
//+------------------------------------------------------------------+
void UpdateDashboard()
  {
   string cur = AccountInfoString(ACCOUNT_CURRENCY);
   int x  = InpDashX + 10;
   int xv = InpDashX + 140;
   int y  = InpDashY + 8;
   int lh = (int)(InpFontSize * 1.7);

   //--- HEADER
   DL("Title", x, y, "ASQ RISKREWARD", InpAccentColor, InpFontSize + 2);
   DL("Ver", InpDashX + 225, y + 2, "v" + IND_VERSION, InpDimColor, InpFontSize - 2);
   y += lh + 2;
   DL("Sep0", x, y, "-------------------------------", InpBorderColor, InpFontSize - 3);
   y += lh - 4;

   //--- PRICES
   bool isBuy = (g_tp1 > g_entry);
   string dirStr = isBuy ? "BUY (Long)" : "SELL (Short)";
   color  dirClr = isBuy ? InpTP1Color : InpSLColor;

   DL("DirL", x, y, "Direction", InpDimColor, InpFontSize - 1);
   DL("DirV", xv, y, dirStr, dirClr, InpFontSize);
   y += lh;

   DL("EnL", x, y, "Entry", InpDimColor, InpFontSize - 1);
   DL("EnV", xv, y, DoubleToString(g_entry, g_digits), InpEntryColor, InpFontSize);
   y += lh;

   DL("SlL", x, y, "Stop Loss", InpDimColor, InpFontSize - 1);
   DL("SlV", xv, y, DoubleToString(g_sl, g_digits), InpSLColor, InpFontSize);
   y += lh;

   DL("T1L", x, y, "Take Profit", InpDimColor, InpFontSize - 1);
   DL("T1V", xv, y, DoubleToString(g_tp1, g_digits), InpTP1Color, InpFontSize);
   y += lh;

   if(InpEnableTP2)
     {
      DL("T2L", x, y, "TP2", InpDimColor, InpFontSize - 1);
      DL("T2V", xv, y, DoubleToString(g_tp2, g_digits), InpTP2Color, InpFontSize);
      y += lh;
     }
   if(InpEnableTP3)
     {
      DL("T3L", x, y, "TP3", InpDimColor, InpFontSize - 1);
      DL("T3V", xv, y, DoubleToString(g_tp3, g_digits), InpTP3Color, InpFontSize);
      y += lh;
     }

   DL("Sep1", x, y, "-------------------------------", InpBorderColor, InpFontSize - 3);
   y += lh - 4;

   //--- R:R RATIO (prominent)
   double slDist = MathAbs(g_entry - g_sl) / g_pipSize;
   double tpDist = MathAbs(g_tp1 - g_entry) / g_pipSize;
   double rr = (slDist > 0) ? tpDist / slDist : 0;

   color rrClr = InpSLColor;
   string rrGrade = "POOR";
   if(rr >= 3.0)      { rrClr = InpTP1Color;  rrGrade = "EXCELLENT"; }
   else if(rr >= 2.0) { rrClr = InpTP1Color;  rrGrade = "GOOD"; }
   else if(rr >= 1.0) { rrClr = C'255,180,0'; rrGrade = "FAIR"; }

   DL("RRL", x, y, "R : R", InpDimColor, InpFontSize - 1);
   DL("RRV", xv, y, "1 : " + DoubleToString(rr, 1), rrClr, InpFontSize + 3);
   y += lh + 2;
   DL("RRG", xv, y, rrGrade, rrClr, InpFontSize);
   y += lh;

   DL("Sep2", x, y, "-------------------------------", InpBorderColor, InpFontSize - 3);
   y += lh - 4;

   //--- DISTANCES
   DL("SdL", x, y, "SL Distance", InpDimColor, InpFontSize - 1);
   DL("SdV", xv, y, DoubleToString(slDist, 1) + " pips", InpSLColor, InpFontSize);
   y += lh;

   DL("TdL", x, y, "TP Distance", InpDimColor, InpFontSize - 1);
   DL("TdV", xv, y, DoubleToString(tpDist, 1) + " pips", InpTP1Color, InpFontSize);
   y += lh;

   if(InpEnableTP2)
     {
      double tp2Dist = MathAbs(g_tp2 - g_entry) / g_pipSize;
      DL("Td2L", x, y, "TP2 Distance", InpDimColor, InpFontSize - 1);
      DL("Td2V", xv, y, DoubleToString(tp2Dist, 1) + " pips", InpTP2Color, InpFontSize);
      y += lh;
     }
   if(InpEnableTP3)
     {
      double tp3Dist = MathAbs(g_tp3 - g_entry) / g_pipSize;
      DL("Td3L", x, y, "TP3 Distance", InpDimColor, InpFontSize - 1);
      DL("Td3V", xv, y, DoubleToString(tp3Dist, 1) + " pips", InpTP3Color, InpFontSize);
      y += lh;
     }

   DL("Sep3", x, y, "-------------------------------", InpBorderColor, InpFontSize - 3);
   y += lh - 4;

   //--- LOT SIZING & MONEY
   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * InpRiskPercent / 100.0;
   double lotSize    = 0;

   if(InpFixedLots > 0)
      lotSize = InpFixedLots;
   else if(g_pipValue > 0 && slDist > 0)
      lotSize = riskAmount / (slDist * g_pipValue);

   //--- normalize lot
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lotStep <= 0) lotStep = 0.01;
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(lotSize, minLot);
   lotSize = MathMin(lotSize, maxLot);

   double riskDollar = lotSize * slDist * g_pipValue;
   double rwdDollar  = lotSize * tpDist * g_pipValue;
   double riskPctActual = (balance > 0) ? riskDollar / balance * 100.0 : 0;

   DL("LtL", x, y, "Lot Size", InpDimColor, InpFontSize - 1);
   DL("LtV", xv, y, DoubleToString(lotSize, 2), InpAccentColor, InpFontSize);
   y += lh;

   DL("RkL", x, y, "Risk", InpDimColor, InpFontSize - 1);
   DL("RkV", xv, y, StringFormat("%.2f %s (%.1f%%)", riskDollar, cur, riskPctActual),
      InpSLColor, InpFontSize);
   y += lh;

   DL("RwL", x, y, "Reward", InpDimColor, InpFontSize - 1);
   DL("RwV", xv, y, StringFormat("%.2f %s", rwdDollar, cur), InpTP1Color, InpFontSize);
   y += lh;

   //--- Multi-TP breakdown
   if(InpEnableTP2 || InpEnableTP3)
     {
      DL("Sep4", x, y, "-------------------------------", InpBorderColor, InpFontSize - 3);
      y += lh - 4;

      double tp1Lots = lotSize * InpTP1Pct / 100.0;
      double tp2Lots = InpEnableTP2 ? lotSize * InpTP2Pct / 100.0 : 0;
      double tp3Lots = InpEnableTP3 ? lotSize * InpTP3Pct / 100.0 : 0;

      DL("MtL", x, y, "PARTIAL CLOSE", InpDimColor, InpFontSize - 1);
      y += lh;

      double tp1Rwd = tp1Lots * tpDist * g_pipValue;
      DL("Mt1", x, y, StringFormat("TP1: %.0f%% (%.2f lots)", InpTP1Pct, tp1Lots), InpTP1Color, InpFontSize - 1);
      DL("Mt1V", xv + 50, y, StringFormat("+%.2f", tp1Rwd), InpTP1Color, InpFontSize - 1);
      y += lh;

      if(InpEnableTP2)
        {
         double tp2D = MathAbs(g_tp2 - g_entry) / g_pipSize;
         double tp2Rwd = tp2Lots * tp2D * g_pipValue;
         DL("Mt2", x, y, StringFormat("TP2: %.0f%% (%.2f lots)", InpTP2Pct, tp2Lots), InpTP2Color, InpFontSize - 1);
         DL("Mt2V", xv + 50, y, StringFormat("+%.2f", tp2Rwd), InpTP2Color, InpFontSize - 1);
         y += lh;
        }

      if(InpEnableTP3)
        {
         double tp3D = MathAbs(g_tp3 - g_entry) / g_pipSize;
         double tp3Rwd = tp3Lots * tp3D * g_pipValue;
         DL("Mt3", x, y, StringFormat("TP3: %.0f%% (%.2f lots)", InpTP3Pct, tp3Lots), InpTP3Color, InpFontSize - 1);
         DL("Mt3V", xv + 50, y, StringFormat("+%.2f", tp3Rwd), InpTP3Color, InpFontSize - 1);
         y += lh;
        }

      double totalRwd = 0;
      totalRwd += tp1Lots * tpDist * g_pipValue;
      if(InpEnableTP2) totalRwd += tp2Lots * MathAbs(g_tp2 - g_entry) / g_pipSize * g_pipValue;
      if(InpEnableTP3) totalRwd += tp3Lots * MathAbs(g_tp3 - g_entry) / g_pipSize * g_pipValue;
      double blendedRR = (riskDollar > 0) ? totalRwd / riskDollar : 0;

      DL("BlL", x, y, "Blended R:R", InpDimColor, InpFontSize - 1);
      DL("BlV", xv, y, "1 : " + DoubleToString(blendedRR, 1), InpAccentColor, InpFontSize);
      y += lh;
     }

   //--- FOOTER
   DL("Sep5", x, y, "-------------------------------", InpBorderColor, InpFontSize - 3);
   y += lh - 4;
   DL("Brand", x, y, "AlgoSphere Quant", InpDimColor, InpFontSize - 2);
   DL("Tag", InpDashX + 160, y, "Precision before profit", C'35,38,52', InpFontSize - 3);
   y += lh;

   //--- Resize background
   ObjectSetInteger(0, P + "D_BG", OBJPROP_YSIZE, y - InpDashY + 5);
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
