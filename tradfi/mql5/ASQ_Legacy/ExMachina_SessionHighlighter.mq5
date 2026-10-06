//+------------------------------------------------------------------+
//|                                ExMachina_SessionHighlighter.mq5   |
//|                        Copyright 2026, ExMachina Trading Systems  |
//|                        https://www.mql5.com/en/users/algosphere   |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, ExMachina Trading Systems"
#property link        "https://www.mql5.com/en/users/algosphere"
#property version     "1.00"
#property description "Highlights Asian, London, and New York trading sessions"
#property description "with colored background rectangles on the chart."
#property description "Precision before profit."
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//+------------------------------------------------------------------+
//| Inputs                                                            |
//+------------------------------------------------------------------+
input group           "=== Asian Session (Tokyo) ==="
input bool   InpShowAsia       = true;           // Show Asian session
input int    InpAsiaStartHour  = 0;              // Start hour (server time)
input int    InpAsiaStartMin   = 0;              // Start minute
input int    InpAsiaEndHour    = 9;              // End hour (server time)
input int    InpAsiaEndMin     = 0;              // End minute
input color  InpAsiaColor      = C'20,40,60';    // Background color

input group           "=== London Session ==="
input bool   InpShowLondon       = true;         // Show London session
input int    InpLondonStartHour  = 8;            // Start hour (server time)
input int    InpLondonStartMin   = 0;            // Start minute
input int    InpLondonEndHour    = 17;           // End hour (server time)
input int    InpLondonEndMin     = 0;            // End minute
input color  InpLondonColor      = C'15,50,25';  // Background color

input group           "=== New York Session ==="
input bool   InpShowNY         = true;           // Show New York session
input int    InpNYStartHour    = 13;             // Start hour (server time)
input int    InpNYStartMin     = 30;             // Start minute
input int    InpNYEndHour      = 22;             // End hour (server time)
input int    InpNYEndMin       = 0;              // End minute
input color  InpNYColor        = C'50,20,20';    // Background color

input group           "=== General Settings ==="
input int    InpMaxDays        = 30;             // Max days to draw
input bool   InpShowLabels     = true;           // Show session labels
input int    InpLabelFontSize  = 8;              // Label font size
input bool   InpFillBoxes      = true;           // Fill rectangles
input bool   InpBackground     = true;           // Draw as background

//+------------------------------------------------------------------+
//| Constants                                                         |
//+------------------------------------------------------------------+
const string OBJ_PREFIX = "EXSH_";

//+------------------------------------------------------------------+
//| Enums                                                             |
//+------------------------------------------------------------------+
enum ENUM_SESSION
  {
   SESSION_ASIA   = 0,
   SESSION_LONDON = 1,
   SESSION_NY     = 2
  };

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
  {
   IndicatorSetString(INDICATOR_SHORTNAME, "ExMachina Sessions");
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
//--- only recalculate fully on first load or when new bars appear
   if(prev_calculated > 0 && prev_calculated == rates_total)
      return(rates_total);

   ArraySetAsSeries(time, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low,  true);

//--- remove old objects and redraw
   ObjectsDeleteAll(0, OBJ_PREFIX);

//--- find unique dates in visible range
   datetime startDate = time[MathMin(rates_total - 1, rates_total - 1)];
   datetime endDate   = time[0];

   //--- limit to InpMaxDays
   datetime limitDate = endDate - (datetime)(InpMaxDays * 86400);
   if(startDate < limitDate)
      startDate = limitDate;

   MqlDateTime dtStart, dtEnd;
   TimeToStruct(startDate, dtStart);
   TimeToStruct(endDate, dtEnd);

//--- iterate through each day
   MqlDateTime dtCurrent;
   dtCurrent = dtStart;
   dtCurrent.hour = 0;
   dtCurrent.min  = 0;
   dtCurrent.sec  = 0;

   datetime currentDay = StructToTime(dtCurrent);
   datetime lastDay    = endDate + 86400;

   int sessionCount = 0;

   while(currentDay <= lastDay && sessionCount < InpMaxDays * 3)
     {
      //--- get day high/low for rectangles
      double dayHigh = 0, dayLow = 0;
      if(!GetDayRange(currentDay, time, high, low, rates_total, dayHigh, dayLow))
        {
         currentDay += 86400;
         continue;
        }

      //--- draw sessions
      if(InpShowAsia)
         DrawSession(SESSION_ASIA, currentDay, dayHigh, dayLow, sessionCount);

      if(InpShowLondon)
         DrawSession(SESSION_LONDON, currentDay, dayHigh, dayLow, sessionCount);

      if(InpShowNY)
         DrawSession(SESSION_NY, currentDay, dayHigh, dayLow, sessionCount);

      sessionCount++;
      currentDay += 86400;
     }

   ChartRedraw(0);
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Draw a single session rectangle                                   |
//+------------------------------------------------------------------+
void DrawSession(const ENUM_SESSION session,
                 const datetime dayStart,
                 const double dayHigh,
                 const double dayLow,
                 const int index)
  {
   int startH, startM, endH, endM;
   color clr;
   string tag;

   switch(session)
     {
      case SESSION_ASIA:
         startH = InpAsiaStartHour;  startM = InpAsiaStartMin;
         endH   = InpAsiaEndHour;    endM   = InpAsiaEndMin;
         clr    = InpAsiaColor;      tag    = "Asia";
         break;
      case SESSION_LONDON:
         startH = InpLondonStartHour; startM = InpLondonStartMin;
         endH   = InpLondonEndHour;   endM   = InpLondonEndMin;
         clr    = InpLondonColor;     tag    = "London";
         break;
      case SESSION_NY:
         startH = InpNYStartHour;    startM = InpNYStartMin;
         endH   = InpNYEndHour;      endM   = InpNYEndMin;
         clr    = InpNYColor;        tag    = "NY";
         break;
      default:
         return;
     }

   datetime tStart = dayStart + startH * 3600 + startM * 60;
   datetime tEnd   = dayStart + endH * 3600 + endM * 60;

   //--- handle overnight sessions
   if(tEnd <= tStart)
      tEnd += 86400;

   //--- add small margin to price range
   double margin = (dayHigh - dayLow) * 0.02;
   double priceTop    = dayHigh + margin;
   double priceBottom = dayLow  - margin;

   //--- rectangle
   string rectName = StringFormat("%sRect_%s_%d", OBJ_PREFIX, tag, index);
   ObjectCreate(0, rectName, OBJ_RECTANGLE, 0, tStart, priceTop, tEnd, priceBottom);
   ObjectSetInteger(0, rectName, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, rectName, OBJPROP_FILL,       InpFillBoxes);
   ObjectSetInteger(0, rectName, OBJPROP_BACK,       InpBackground);
   ObjectSetInteger(0, rectName, OBJPROP_SELECTABLE,  false);
   ObjectSetInteger(0, rectName, OBJPROP_HIDDEN,     true);
   ObjectSetInteger(0, rectName, OBJPROP_WIDTH,      1);

   //--- label
   if(InpShowLabels)
     {
      string lblName = StringFormat("%sLbl_%s_%d", OBJ_PREFIX, tag, index);
      ObjectCreate(0, lblName, OBJ_TEXT, 0, tStart, priceTop);
      ObjectSetString(0,  lblName, OBJPROP_TEXT,     " " + tag);
      ObjectSetString(0,  lblName, OBJPROP_FONT,     "Consolas");
      ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, InpLabelFontSize);
      ObjectSetInteger(0, lblName, OBJPROP_COLOR,    clr);
      ObjectSetInteger(0, lblName, OBJPROP_ANCHOR,   ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lblName, OBJPROP_HIDDEN,   true);
     }
  }

//+------------------------------------------------------------------+
//| Get the high/low range for a given day from available bars        |
//+------------------------------------------------------------------+
bool GetDayRange(const datetime dayStart,
                 const datetime &time[],
                 const double &high[],
                 const double &low[],
                 const int total,
                 double &outHigh,
                 double &outLow)
  {
   datetime dayEnd = dayStart + 86400;
   outHigh = -DBL_MAX;
   outLow  = DBL_MAX;
   bool found = false;

   //--- scan backwards (arrays are series)
   for(int i = 0; i < total; i++)
     {
      if(time[i] < dayStart)
         break;
      if(time[i] >= dayStart && time[i] < dayEnd)
        {
         if(high[i] > outHigh) outHigh = high[i];
         if(low[i]  < outLow)  outLow  = low[i];
         found = true;
        }
     }

   return found;
  }
//+------------------------------------------------------------------+
