//+------------------------------------------------------------------+
//|                                    ExMachina_SpreadMonitor.mq5    |
//|                        Copyright 2026, ExMachina Trading Systems  |
//|                        https://www.mql5.com/en/users/algosphere   |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, ExMachina Trading Systems"
#property link        "https://www.mql5.com/en/users/algosphere"
#property version     "1.00"
#property description "Real-time spread monitor with color-coded histogram and on-chart display."
#property description "Green = low spread, Yellow = medium, Red = high spread."
#property description "Precision before profit."
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   1

//--- plot Spread Histogram
#property indicator_label1  "Spread"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrLimeGreen,clrGold,clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//+------------------------------------------------------------------+
//| Inputs                                                            |
//+------------------------------------------------------------------+
input int    InpLowThreshold    = 15;    // Low spread threshold (points)
input int    InpHighThreshold   = 40;    // High spread threshold (points)
input bool   InpShowLabel       = true;  // Show spread label on chart
input int    InpFontSize        = 12;    // Label font size
input color  InpLabelColor      = C'180,185,195'; // Label color
input int    InpMaxBars         = 5000;  // Max bars to calculate

//+------------------------------------------------------------------+
//| Buffers                                                           |
//+------------------------------------------------------------------+
double g_spreadBuffer[];
double g_colorBuffer[];
double g_highBuffer[];
double g_lowBuffer[];

//--- object names
const string OBJ_PREFIX = "EXSM_";
const string LBL_SPREAD = OBJ_PREFIX + "SpreadLabel";
const string LBL_AVG    = OBJ_PREFIX + "AvgLabel";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0, g_spreadBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, g_colorBuffer,  INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, g_highBuffer,   INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, g_lowBuffer,    INDICATOR_CALCULATIONS);

   ArraySetAsSeries(g_spreadBuffer, true);
   ArraySetAsSeries(g_colorBuffer,  true);
   ArraySetAsSeries(g_highBuffer,   true);
   ArraySetAsSeries(g_lowBuffer,    true);

//--- indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "ExMachina Spread Monitor");
   IndicatorSetInteger(INDICATOR_DIGITS, 0);

//--- levels
   IndicatorSetInteger(INDICATOR_LEVELS, 2);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, (double)InpLowThreshold);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, (double)InpHighThreshold);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, clrLimeGreen);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 1, clrCrimson);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, 0, STYLE_DOT);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, 1, STYLE_DOT);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, OBJ_PREFIX);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                               |
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

   int limit = rates_total - prev_calculated;
   if(prev_calculated == 0)
     {
      limit = MathMin(rates_total, InpMaxBars) - 1;
      ArrayInitialize(g_spreadBuffer, 0);
      ArrayInitialize(g_colorBuffer,  0);
     }

//--- main calculation loop
   for(int i = limit; i >= 0; i--)
     {
      int sp = spread[i];
      g_spreadBuffer[i] = (double)sp;

      //--- color coding
      if(sp <= InpLowThreshold)
         g_colorBuffer[i] = 0; // green
      else if(sp >= InpHighThreshold)
         g_colorBuffer[i] = 2; // red
      else
         g_colorBuffer[i] = 1; // yellow
     }

//--- current spread label on main chart
   if(InpShowLabel)
     {
      int currentSpread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      double avgSpread  = CalcAverageSpread(MathMin(rates_total, 100));

      //--- spread label
      string spreadText = StringFormat("Spread: %d pts", currentSpread);
      color  spreadClr  = (currentSpread <= InpLowThreshold) ? clrLimeGreen :
                          (currentSpread >= InpHighThreshold) ? clrCrimson : clrGold;

      CreateLabel(LBL_SPREAD, spreadText, spreadClr, 10, 30);

      //--- average label
      string avgText = StringFormat("Avg(100): %.1f pts", avgSpread);
      CreateLabel(LBL_AVG, avgText, InpLabelColor, 10, 50);
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Calculate average spread over N bars                              |
//+------------------------------------------------------------------+
double CalcAverageSpread(const int bars)
  {
   if(bars <= 0)
      return 0;

   double sum = 0;
   for(int i = 0; i < bars; i++)
      sum += g_spreadBuffer[i];

   return sum / (double)bars;
  }

//+------------------------------------------------------------------+
//| Create or update a label object on the chart                      |
//+------------------------------------------------------------------+
void CreateLabel(const string name,
                 const string text,
                 const color  clr,
                 const int    xDist,
                 const int    yDist)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR,    ANCHOR_LEFT_UPPER);
      ObjectSetString(0,  name, OBJPROP_FONT,      "Consolas");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  InpFontSize);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN,    true);
     }

   ObjectSetString(0,  name, OBJPROP_TEXT,  text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xDist);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, yDist);
  }
//+------------------------------------------------------------------+
