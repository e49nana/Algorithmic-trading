//+------------------------------------------------------------------+
//|                                  ExMachina_SupplyDemand.mq5      |
//|                     Copyright 2026, ExMachina Trading Systems     |
//|              https://www.mql5.com/en/users/williammukam           |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, ExMachina Trading Systems"
#property link        "https://www.mql5.com/en/users/williammukam"
#property version     "2.00"
#property description "ExMachina Supply & Demand Zones v2.0"
#property description "Impulse-based detection with ATR filter,"
#property description "strength rating, freshness + touch tracking,"
#property description "zone proximity alerts, premium dashboard."
#property description "Precision before profit."
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//+------------------------------------------------------------------+
//| Inputs                                                            |
//+------------------------------------------------------------------+
input group              "══════ DETECTION ══════"
input int       InpLookback       = 1000;      // Lookback bars
input double    InpMinImpulse     = 1.0;       // Min impulse size (ATR multiplier)
input int       InpATRPeriod      = 14;        // ATR period
input int       InpMaxZones       = 10;        // Max zones displayed
input bool      InpShowFresh      = false;     // Show only fresh zones (false=show all)
input double    InpMergeDistance   = 0.5;       // Merge zones within (ATR x multiplier)
input bool      InpUseRange       = true;      // Use candle range (high-low) instead of body
input int       InpMultiCandle    = 3;         // Multi-candle impulse window (1=single, 2-3=combo)

input group              "══════ VISUAL ══════"
input color     InpDemandColor    = C'0,150,120';     // Demand zone border
input color     InpDemandFill     = C'0,50,38';       // Demand fill
input color     InpSupplyColor    = C'180,45,65';      // Supply zone border
input color     InpSupplyFill     = C'60,18,28';       // Supply fill
input color     InpTestedColor    = C'45,48,60';       // Tested zone color
input color     InpTestedFill     = C'25,27,35';       // Tested zone fill
input bool      InpShowLabels     = true;              // Show zone labels
input bool      InpExtendRight    = true;              // Extend zones to current bar
input bool      InpShowMidline    = true;              // Show zone midline (EQ)

input group              "══════ CHART THEME ══════"
input bool      InpApplyTheme     = true;              // Apply ExMachina dark theme
input color     InpChartBg        = C'10,12,20';       // Chart background
input color     InpChartFg        = C'25,28,40';       // Chart foreground (candle area)
input color     InpChartGrid      = C'20,22,32';       // Grid color
input color     InpBullCandle     = C'0,185,140';      // Bull candle body
input color     InpBearCandle     = C'220,50,80';      // Bear candle body
input color     InpCandleWick     = C'80,85,100';      // Candle wick/border
input color     InpChartLine      = C'90,180,220';     // Ask/Bid line
input color     InpVolumeColor    = C'35,40,55';       // Volume bars

input group              "══════ ALERTS ══════"
input bool      InpAlertTouch     = true;      // Alert on zone touch
input bool      InpAlertProximity = true;      // Alert on zone approach
input int       InpProximityPts   = 50;        // Proximity distance (points)
input bool      InpAlertPopup     = true;      // Show popup alert
input bool      InpAlertSound     = true;      // Play sound
input bool      InpAlertPush      = false;     // Push notification

input group              "══════ DASHBOARD ══════"
input bool      InpShowDashboard  = true;      // Show dashboard panel
input int       InpDashX          = 20;        // Dashboard X position
input int       InpDashY          = 40;        // Dashboard Y position
input int       InpDashFontSize   = 9;         // Dashboard font size
input color     InpDashBgColor    = C'8,10,18';       // Dashboard background
input color     InpDashBorderColor= C'30,34,46';      // Dashboard border
input color     InpDashTextColor  = C'160,168,180';   // Dashboard text
input color     InpDashHeaderColor= C'90,180,220';    // Dashboard header

//+------------------------------------------------------------------+
//| Constants                                                         |
//+------------------------------------------------------------------+
const string OBJ_PREFIX   = "EXSD_";
const string INDI_NAME    = "ExMachina S&D Zones";

//+------------------------------------------------------------------+
//| Zone structure                                                    |
//+------------------------------------------------------------------+
struct SDZone
  {
   datetime       timeStart;       // zone origin bar time
   double         priceHigh;       // zone upper boundary
   double         priceLow;        // zone lower boundary
   bool           isDemand;        // true=demand, false=supply
   bool           isFresh;         // never penetrated
   int            strength;        // impulse strength score (body/ATR * 10)
   int            touchCount;      // times price touched but didn't break
   datetime       lastTouchTime;   // last touch bar time
  };

//+------------------------------------------------------------------+
//| Globals                                                           |
//+------------------------------------------------------------------+
SDZone         g_zones[];
int            g_zoneCount    = 0;
int            g_demandCount  = 0;
int            g_supplyCount  = 0;
int            g_freshCount   = 0;
double         g_avgStrength  = 0;

int            g_atrHandle    = INVALID_HANDLE;
double         g_atrBuffer[];

datetime       g_lastAlertTime     = 0;
datetime       g_lastProxAlertTime = 0;
int            g_lastCalcBars      = 0;

//+------------------------------------------------------------------+
//| Initialization                                                    |
//+------------------------------------------------------------------+
int OnInit()
  {
   IndicatorSetString(INDICATOR_SHORTNAME, INDI_NAME);

   //--- apply ExMachina chart theme
   if(InpApplyTheme)
      ApplyChartTheme();

   //--- create ATR handle ONCE (not per tick)
   g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   if(g_atrHandle == INVALID_HANDLE)
     {
      PrintFormat("%s: Failed to create ATR(%d) handle", INDI_NAME, InpATRPeriod);
      return(INIT_FAILED);
     }

   ArraySetAsSeries(g_atrBuffer, false);

   //--- build dashboard
   if(InpShowDashboard)
      CreateDashboard();

   PrintFormat("%s v2.00 initialized on %s", INDI_NAME, _Symbol);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Apply ExMachina dark chart theme                                  |
//+------------------------------------------------------------------+
void ApplyChartTheme()
  {
   long chartId = 0;

   //--- chart colors
   ChartSetInteger(chartId, CHART_COLOR_BACKGROUND,       InpChartBg);
   ChartSetInteger(chartId, CHART_COLOR_FOREGROUND,        InpChartFg);
   ChartSetInteger(chartId, CHART_COLOR_GRID,              InpChartGrid);
   ChartSetInteger(chartId, CHART_COLOR_CHART_UP,          InpBullCandle);
   ChartSetInteger(chartId, CHART_COLOR_CHART_DOWN,        InpBearCandle);
   ChartSetInteger(chartId, CHART_COLOR_CANDLE_BULL,       InpBullCandle);
   ChartSetInteger(chartId, CHART_COLOR_CANDLE_BEAR,       InpBearCandle);
   ChartSetInteger(chartId, CHART_COLOR_CHART_LINE,        InpChartLine);
   ChartSetInteger(chartId, CHART_COLOR_VOLUME,            InpVolumeColor);
   ChartSetInteger(chartId, CHART_COLOR_ASK,               InpChartLine);
   ChartSetInteger(chartId, CHART_COLOR_BID,               C'180,45,65');
   ChartSetInteger(chartId, CHART_COLOR_STOP_LEVEL,        C'220,50,80');
   ChartSetInteger(chartId, CHART_COLOR_LAST,              InpChartFg);

   //--- chart style
   ChartSetInteger(chartId, CHART_MODE, CHART_CANDLES);
   ChartSetInteger(chartId, CHART_SHOW_GRID, false);
   ChartSetInteger(chartId, CHART_SHOW_VOLUMES, CHART_VOLUME_HIDE);
   ChartSetInteger(chartId, CHART_AUTOSCROLL, true);
   ChartSetInteger(chartId, CHART_SHIFT, true);
   ChartSetInteger(chartId, CHART_SHOW_ASK_LINE, true);
   ChartSetInteger(chartId, CHART_SHOW_BID_LINE, false);

   ChartRedraw(chartId);
   PrintFormat("%s: ExMachina chart theme applied", INDI_NAME);
  }

//+------------------------------------------------------------------+
//| Deinitialization                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, OBJ_PREFIX);
   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Main calculation                                                  |
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
   if(rates_total < InpATRPeriod + 10)
      return(0);

   //--- copy ATR buffer (handle created once in OnInit)
   if(CopyBuffer(g_atrHandle, 0, 0, rates_total, g_atrBuffer) < rates_total)
      return(0);

   //--- full recalc on first run or history change
   bool fullRecalc = (prev_calculated == 0 || rates_total != g_lastCalcBars);

   if(fullRecalc)
     {
      ObjectsDeleteAll(0, OBJ_PREFIX + "ZN_");
      ObjectsDeleteAll(0, OBJ_PREFIX + "LBL_");
      ObjectsDeleteAll(0, OBJ_PREFIX + "MID_");
      DetectAllZones(rates_total, time, open, high, low, close);
     }
   else
     {
      //--- incremental: only update freshness + touches for latest bar
      UpdateZoneFreshness(rates_total, high, low, close, time);
     }

   //--- draw zones
   DrawZones(rates_total, time);

   //--- alerts
   if(rates_total > 1)
      CheckAlerts(rates_total, high, low, time);

   //--- dashboard
   if(InpShowDashboard)
      UpdateDashboard(rates_total, close, time);

   g_lastCalcBars = rates_total;
   return(rates_total);
  }

//+------------------------------------------------------------------+
//|                    ZONE DETECTION                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Detect all zones from scratch                                     |
//+------------------------------------------------------------------+
void DetectAllZones(const int rates_total,
                    const datetime &time[],
                    const double &open[],
                    const double &high[],
                    const double &low[],
                    const double &close[])
  {
   ArrayResize(g_zones, 0);
   g_zoneCount   = 0;
   g_demandCount = 0;
   g_supplyCount = 0;
   g_freshCount  = 0;
   g_avgStrength = 0;

   int start = MathMax(rates_total - InpLookback, InpATRPeriod + 2);
   int window = MathMax(1, MathMin(InpMultiCandle, 3)); // clamp 1-3

   for(int i = start + window; i < rates_total - 1; i++)
     {
      double atr = g_atrBuffer[i];
      if(atr <= 0)
         continue;

      //--- measure impulse over the multi-candle window
      //    net move = close[i] - open[i-window+1] (directional)
      //    total range = highest high - lowest low over window
      int wStart = i - window + 1;
      double netMove    = close[i] - open[wStart];
      double windowHigh = high[wStart];
      double windowLow  = low[wStart];
      for(int w = wStart + 1; w <= i; w++)
        {
         if(high[w] > windowHigh) windowHigh = high[w];
         if(low[w] < windowLow)   windowLow  = low[w];
        }
      double totalRange = windowHigh - windowLow;

      //--- choose measurement: range or body
      double impulseSize = InpUseRange ? totalRange : MathAbs(netMove);
      if(impulseSize < atr * InpMinImpulse)
         continue;

      //--- direction from net move
      bool bullish = (netMove > 0);
      bool bearish = (netMove < 0);

      //--- base candle = candle before the impulse window
      int base = wStart - 1;
      if(base < start)
         continue;

      double strength = impulseSize / atr * 10;

      SDZone zone;
      zone.touchCount    = 0;
      zone.lastTouchTime = 0;

      //--- bullish impulse → demand zone at base
      if(bullish)
        {
         zone.timeStart = time[base];
         zone.priceHigh = MathMax(open[base], close[base]);
         zone.priceLow  = low[base];
         zone.isDemand  = true;
         zone.isFresh   = true;
         zone.strength  = (int)strength;

         //--- scan forward: check freshness + count touches
         for(int j = i + 1; j < rates_total; j++)
           {
            if(close[j] < zone.priceLow)
              {
               zone.isFresh = false;
               break;
              }
            if(low[j] <= zone.priceHigh && low[j] >= zone.priceLow)
              {
               zone.touchCount++;
               zone.lastTouchTime = time[j];
              }
           }

         AddZoneWithMerge(zone);
        }

      //--- bearish impulse → supply zone at base
      if(bearish)
        {
         zone.timeStart = time[base];
         zone.priceHigh = high[base];
         zone.priceLow  = MathMin(open[base], close[base]);
         zone.isDemand  = false;
         zone.isFresh   = true;
         zone.strength  = (int)strength;

         //--- scan forward: check freshness + count touches
         for(int j = i + 1; j < rates_total; j++)
           {
            if(close[j] > zone.priceHigh)
              {
               zone.isFresh = false;
               break;
              }
            if(high[j] >= zone.priceLow && high[j] <= zone.priceHigh)
              {
               zone.touchCount++;
               zone.lastTouchTime = time[j];
              }
           }

         AddZoneWithMerge(zone);
        }
     }

   //--- compute stats
   RecalcStats();
  }

//+------------------------------------------------------------------+
//| Add zone with proximity merge check                               |
//+------------------------------------------------------------------+
void AddZoneWithMerge(SDZone &newZone)
  {
   //--- check if a nearby zone of the same type already exists
   if(InpMergeDistance > 0 && g_zoneCount > 0)
     {
      double mergeThreshold = 0;

      //--- use last ATR value for merge distance
      if(ArraySize(g_atrBuffer) > 0)
         mergeThreshold = g_atrBuffer[ArraySize(g_atrBuffer) - 1] * InpMergeDistance;

      for(int i = g_zoneCount - 1; i >= MathMax(0, g_zoneCount - 10); i--)
        {
         if(g_zones[i].isDemand != newZone.isDemand)
            continue;

         double midOld = (g_zones[i].priceHigh + g_zones[i].priceLow) / 2.0;
         double midNew = (newZone.priceHigh + newZone.priceLow) / 2.0;
         double dist   = MathAbs(midOld - midNew);

         if(dist < mergeThreshold)
           {
            //--- merge: expand boundaries, keep higher strength
            g_zones[i].priceHigh = MathMax(g_zones[i].priceHigh, newZone.priceHigh);
            g_zones[i].priceLow  = MathMin(g_zones[i].priceLow, newZone.priceLow);
            if(newZone.strength > g_zones[i].strength)
               g_zones[i].strength = newZone.strength;
            g_zones[i].touchCount += newZone.touchCount;
            if(!newZone.isFresh)
               g_zones[i].isFresh = false;
            return;
           }
        }
     }

   //--- no merge: add new zone
   g_zoneCount++;
   ArrayResize(g_zones, g_zoneCount, 50);
   g_zones[g_zoneCount - 1] = newZone;
  }

//+------------------------------------------------------------------+
//| Update zone freshness incrementally (latest bar only)             |
//+------------------------------------------------------------------+
void UpdateZoneFreshness(const int rates_total,
                         const double &high[],
                         const double &low[],
                         const double &close[],
                         const datetime &time[])
  {
   if(rates_total < 1)
      return;

   int lastBar = rates_total - 1;

   for(int i = 0; i < g_zoneCount; i++)
     {
      if(!g_zones[i].isFresh)
         continue;

      //--- check if latest bar broke the zone
      if(g_zones[i].isDemand)
        {
         if(close[lastBar] < g_zones[i].priceLow)
            g_zones[i].isFresh = false;
         else if(low[lastBar] <= g_zones[i].priceHigh
                 && low[lastBar] >= g_zones[i].priceLow)
           {
            g_zones[i].touchCount++;
            g_zones[i].lastTouchTime = time[lastBar];
           }
        }
      else
        {
         if(close[lastBar] > g_zones[i].priceHigh)
            g_zones[i].isFresh = false;
         else if(high[lastBar] >= g_zones[i].priceLow
                 && high[lastBar] <= g_zones[i].priceHigh)
           {
            g_zones[i].touchCount++;
            g_zones[i].lastTouchTime = time[lastBar];
           }
        }
     }

   RecalcStats();
  }

//+------------------------------------------------------------------+
//| Recalculate zone statistics                                       |
//+------------------------------------------------------------------+
void RecalcStats()
  {
   g_demandCount = 0;
   g_supplyCount = 0;
   g_freshCount  = 0;
   g_avgStrength = 0;
   double totalStr = 0;

   for(int i = 0; i < g_zoneCount; i++)
     {
      if(g_zones[i].isDemand)
         g_demandCount++;
      else
         g_supplyCount++;
      if(g_zones[i].isFresh)
         g_freshCount++;
      totalStr += g_zones[i].strength;
     }

   if(g_zoneCount > 0)
      g_avgStrength = totalStr / g_zoneCount;
  }

//+------------------------------------------------------------------+
//|                    DRAWING                                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Draw all visible zones                                            |
//+------------------------------------------------------------------+
void DrawZones(const int rates_total, const datetime &time[])
  {
   //--- clean previous zone objects
   ObjectsDeleteAll(0, OBJ_PREFIX + "ZN_");
   ObjectsDeleteAll(0, OBJ_PREFIX + "LBL_");
   ObjectsDeleteAll(0, OBJ_PREFIX + "MID_");

   int drawn = 0;
   datetime endTime = time[rates_total - 1] + PeriodSeconds() * 10;

   //--- draw from most recent zones first
   for(int i = g_zoneCount - 1; i >= 0 && drawn < InpMaxZones; i--)
     {
      if(InpShowFresh && !g_zones[i].isFresh)
         continue;

      //--- determine colors
      color zoneColor, fillColor;

      if(!g_zones[i].isFresh)
        {
         zoneColor = InpTestedColor;
         fillColor = InpTestedFill;
        }
      else if(g_zones[i].isDemand)
        {
         zoneColor = InpDemandColor;
         fillColor = InpDemandFill;
        }
      else
        {
         zoneColor = InpSupplyColor;
         fillColor = InpSupplyFill;
        }

      string id = IntegerToString(i);
      datetime eT = InpExtendRight ? endTime
                                   : g_zones[i].timeStart + PeriodSeconds() * 20;

      //--- zone fill rectangle
      string rectName = OBJ_PREFIX + "ZN_" + id;
      ObjectCreate(0, rectName, OBJ_RECTANGLE, 0,
                   g_zones[i].timeStart, g_zones[i].priceHigh,
                   eT, g_zones[i].priceLow);
      ObjectSetInteger(0, rectName, OBJPROP_COLOR, fillColor);
      ObjectSetInteger(0, rectName, OBJPROP_FILL, true);
      ObjectSetInteger(0, rectName, OBJPROP_BACK, true);
      ObjectSetInteger(0, rectName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, rectName, OBJPROP_HIDDEN, true);

      //--- zone border (dotted outline)
      string borderName = OBJ_PREFIX + "ZN_B_" + id;
      ObjectCreate(0, borderName, OBJ_RECTANGLE, 0,
                   g_zones[i].timeStart, g_zones[i].priceHigh,
                   eT, g_zones[i].priceLow);
      ObjectSetInteger(0, borderName, OBJPROP_COLOR, zoneColor);
      ObjectSetInteger(0, borderName, OBJPROP_FILL, false);
      ObjectSetInteger(0, borderName, OBJPROP_BACK, true);
      ObjectSetInteger(0, borderName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, borderName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, borderName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, borderName, OBJPROP_HIDDEN, true);

      //--- midline (equilibrium)
      if(InpShowMidline)
        {
         double mid = (g_zones[i].priceHigh + g_zones[i].priceLow) / 2.0;
         string midName = OBJ_PREFIX + "MID_" + id;
         ObjectCreate(0, midName, OBJ_TREND, 0,
                      g_zones[i].timeStart, mid, eT, mid);
         ObjectSetInteger(0, midName, OBJPROP_COLOR, zoneColor);
         ObjectSetInteger(0, midName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, midName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, midName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, midName, OBJPROP_BACK, true);
         ObjectSetInteger(0, midName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, midName, OBJPROP_HIDDEN, true);
        }

      //--- label with strength + touch count
      if(InpShowLabels)
        {
         string lblName = OBJ_PREFIX + "LBL_" + id;
         string typeTxt  = g_zones[i].isDemand ? "DEMAND" : "SUPPLY";
         string freshTxt = g_zones[i].isFresh ? " ●" : " [T]";
         string touchTxt = (g_zones[i].touchCount > 0)
                           ? " x" + IntegerToString(g_zones[i].touchCount)
                           : "";
         string label = typeTxt + freshTxt
                        + " S:" + IntegerToString(g_zones[i].strength)
                        + touchTxt;

         double labelPrice = g_zones[i].isDemand
                             ? g_zones[i].priceLow
                             : g_zones[i].priceHigh;

         ObjectCreate(0, lblName, OBJ_TEXT, 0,
                      g_zones[i].timeStart, labelPrice);
         ObjectSetString(0, lblName, OBJPROP_TEXT, label);
         ObjectSetInteger(0, lblName, OBJPROP_COLOR, zoneColor);
         ObjectSetString(0, lblName, OBJPROP_FONT, "Consolas");
         ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 7);
         ObjectSetInteger(0, lblName, OBJPROP_ANCHOR,
                          g_zones[i].isDemand ? ANCHOR_LEFT_UPPER
                                              : ANCHOR_LEFT_LOWER);
         ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, lblName, OBJPROP_HIDDEN, true);
        }

      drawn++;
     }

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//|                    ALERTS                                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check for zone touch and proximity alerts                         |
//+------------------------------------------------------------------+
void CheckAlerts(const int rates_total,
                 const double &high[],
                 const double &low[],
                 const datetime &time[])
  {
   int lastBar = rates_total - 1;
   double h = high[lastBar];
   double l = low[lastBar];
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   //--- zone touch alert
   if(InpAlertTouch && time[lastBar] > g_lastAlertTime)
     {
      for(int i = g_zoneCount - 1; i >= 0; i--)
        {
         if(!g_zones[i].isFresh)
            continue;
         if(l <= g_zones[i].priceHigh && h >= g_zones[i].priceLow)
           {
            string zType = g_zones[i].isDemand ? "DEMAND" : "SUPPLY";
            string msg = INDI_NAME + " | " + _Symbol
                         + " | Price entering " + zType + " zone"
                         + " (S:" + IntegerToString(g_zones[i].strength) + ")";
            FireAlert(msg);
            g_lastAlertTime = time[lastBar];
            break;
           }
        }
     }

   //--- proximity alert (approaching a zone)
   if(InpAlertProximity && time[lastBar] > g_lastProxAlertTime)
     {
      double proxDist = InpProximityPts * point;

      for(int i = g_zoneCount - 1; i >= 0; i--)
        {
         if(!g_zones[i].isFresh)
            continue;

         bool approaching = false;
         string direction = "";

         //--- demand: price approaching from above
         if(g_zones[i].isDemand && l > g_zones[i].priceHigh
            && (l - g_zones[i].priceHigh) <= proxDist)
           {
            approaching = true;
            direction = "approaching DEMAND from above";
           }

         //--- supply: price approaching from below
         if(!g_zones[i].isDemand && h < g_zones[i].priceLow
            && (g_zones[i].priceLow - h) <= proxDist)
           {
            approaching = true;
            direction = "approaching SUPPLY from below";
           }

         if(approaching)
           {
            string msg = INDI_NAME + " | " + _Symbol + " | Price " + direction
                         + " (S:" + IntegerToString(g_zones[i].strength) + ")";
            FireAlert(msg);
            g_lastProxAlertTime = time[lastBar];
            break;
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Fire alert through configured channels                            |
//+------------------------------------------------------------------+
void FireAlert(const string msg)
  {
   if(InpAlertPopup)  Alert(msg);
   if(InpAlertSound)  PlaySound("alert.wav");
   if(InpAlertPush)   SendNotification(msg);
   Print(msg);
  }

//+------------------------------------------------------------------+
//|                    DASHBOARD                                       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create dashboard panel                                            |
//+------------------------------------------------------------------+
void CreateDashboard()
  {
   int x      = InpDashX;
   int y      = InpDashY;
   int panelW = 280;
   int lineH  = 20;
   int fs     = InpDashFontSize;
   int pad    = 10;
   int valX   = x + 170;

   //--- outer glow border
   CreateRect(OBJ_PREFIX + "DASH_GLOW", x - 8, y - 8, panelW + 16, 10,
              C'15,18,28', C'40,45,65');

   //--- main background
   CreateRect(OBJ_PREFIX + "DASH_BG", x - 6, y - 6, panelW + 12, 10,
              InpDashBgColor, InpDashBorderColor);

   //--- title
   CreateLabel(OBJ_PREFIX + "DASH_Title", x + pad, y,
               "══ S&D ZONES ══", InpDashHeaderColor, fs + 2);
   y += lineH + 8;

   CreateLabel(OBJ_PREFIX + "DASH_Sep0", x + pad, y,
               "───────────────────────────────", InpDashBorderColor, fs - 2);
   y += lineH;

   //--- zone stats
   CreateLabel(OBJ_PREFIX + "DASH_TotalLbl", x + pad, y,
               "Total Zones:", C'90,95,110', fs);
   CreateLabel(OBJ_PREFIX + "DASH_TotalVal", valX, y,
               "—", InpDashTextColor, fs);
   y += lineH;

   CreateLabel(OBJ_PREFIX + "DASH_DemandLbl", x + pad, y,
               "Demand:", C'90,95,110', fs);
   CreateLabel(OBJ_PREFIX + "DASH_DemandVal", valX, y,
               "—", InpDemandColor, fs);
   y += lineH;

   CreateLabel(OBJ_PREFIX + "DASH_SupplyLbl", x + pad, y,
               "Supply:", C'90,95,110', fs);
   CreateLabel(OBJ_PREFIX + "DASH_SupplyVal", valX, y,
               "—", InpSupplyColor, fs);
   y += lineH;

   CreateLabel(OBJ_PREFIX + "DASH_FreshLbl", x + pad, y,
               "Fresh:", C'90,95,110', fs);
   CreateLabel(OBJ_PREFIX + "DASH_FreshVal", valX, y,
               "—", C'0,185,140', fs);
   y += lineH;

   CreateLabel(OBJ_PREFIX + "DASH_StrLbl", x + pad, y,
               "Avg Strength:", C'90,95,110', fs);
   CreateLabel(OBJ_PREFIX + "DASH_StrVal", valX, y,
               "—", C'200,170,50', fs);
   y += lineH + 4;

   CreateLabel(OBJ_PREFIX + "DASH_Sep1", x + pad, y,
               "───────────────────────────────", InpDashBorderColor, fs - 2);
   y += lineH;

   //--- nearest zone info
   CreateLabel(OBJ_PREFIX + "DASH_NearLbl", x + pad, y,
               "Nearest Fresh Zone:", InpDashHeaderColor, fs);
   y += lineH;

   CreateLabel(OBJ_PREFIX + "DASH_NearVal", x + pad, y,
               "—", InpDashTextColor, fs);
   y += lineH;

   CreateLabel(OBJ_PREFIX + "DASH_DistLbl", x + pad, y,
               "Distance:", C'90,95,110', fs);
   CreateLabel(OBJ_PREFIX + "DASH_DistVal", valX, y,
               "—", InpDashTextColor, fs);
   y += lineH + 4;

   CreateLabel(OBJ_PREFIX + "DASH_Sep2", x + pad, y,
               "───────────────────────────────", InpDashBorderColor, fs - 2);
   y += lineH;

   //--- branding
   CreateLabel(OBJ_PREFIX + "DASH_Brand", x + pad, y,
               "ExMachina Trading Systems", C'50,55,70', fs - 2);
   y += lineH + 2;

   //--- resize backgrounds to fit content
   int totalH = y - InpDashY + 12;
   ObjectSetInteger(0, OBJ_PREFIX + "DASH_BG", OBJPROP_YSIZE, totalH);
   ObjectSetInteger(0, OBJ_PREFIX + "DASH_GLOW", OBJPROP_YSIZE, totalH + 4);

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Update dashboard values                                           |
//+------------------------------------------------------------------+
void UpdateDashboard(const int rates_total,
                     const double &close[],
                     const datetime &time[])
  {
   //--- zone stats
   UpdateLabel(OBJ_PREFIX + "DASH_TotalVal",
               IntegerToString(g_zoneCount), InpDashTextColor);
   UpdateLabel(OBJ_PREFIX + "DASH_DemandVal",
               IntegerToString(g_demandCount), InpDemandColor);
   UpdateLabel(OBJ_PREFIX + "DASH_SupplyVal",
               IntegerToString(g_supplyCount), InpSupplyColor);
   UpdateLabel(OBJ_PREFIX + "DASH_FreshVal",
               IntegerToString(g_freshCount), C'0,185,140');
   UpdateLabel(OBJ_PREFIX + "DASH_StrVal",
               StringFormat("S:%.0f", g_avgStrength), C'200,170,50');

   //--- find nearest fresh zone to current price
   if(rates_total < 1 || g_zoneCount == 0)
     {
      UpdateLabel(OBJ_PREFIX + "DASH_NearVal", "No zones", C'90,95,110');
      UpdateLabel(OBJ_PREFIX + "DASH_DistVal", "—", InpDashTextColor);
      return;
     }

   double curPrice = close[rates_total - 1];
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0)
      point = _Point;

   int    nearestIdx  = -1;
   double nearestDist = DBL_MAX;

   for(int i = 0; i < g_zoneCount; i++)
     {
      if(!g_zones[i].isFresh)
         continue;

      double mid  = (g_zones[i].priceHigh + g_zones[i].priceLow) / 2.0;
      double dist = MathAbs(curPrice - mid);

      if(dist < nearestDist)
        {
         nearestDist = dist;
         nearestIdx  = i;
        }
     }

   if(nearestIdx >= 0)
     {
      string zType = g_zones[nearestIdx].isDemand ? "DEMAND" : "SUPPLY";
      color  zClr  = g_zones[nearestIdx].isDemand ? InpDemandColor : InpSupplyColor;
      string nearTxt = zType + " ● S:" + IntegerToString(g_zones[nearestIdx].strength)
                       + " x" + IntegerToString(g_zones[nearestIdx].touchCount);
      UpdateLabel(OBJ_PREFIX + "DASH_NearVal", nearTxt, zClr);

      int distPts = (int)(nearestDist / point);
      string distTxt = IntegerToString(distPts) + " pts";
      color  distClr = (distPts < InpProximityPts) ? C'255,215,0' : InpDashTextColor;
      UpdateLabel(OBJ_PREFIX + "DASH_DistVal", distTxt, distClr);
     }
   else
     {
      UpdateLabel(OBJ_PREFIX + "DASH_NearVal", "No fresh zones", C'90,95,110');
      UpdateLabel(OBJ_PREFIX + "DASH_DistVal", "—", InpDashTextColor);
     }
  }

//+------------------------------------------------------------------+
//|                    UI HELPERS                                      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create a label                                                    |
//+------------------------------------------------------------------+
void CreateLabel(const string name, int x, int y,
                 const string text, color clr, int fontSize)
  {
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//| Update a label                                                    |
//+------------------------------------------------------------------+
void UpdateLabel(const string name, const string text, color clr)
  {
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
  }

//+------------------------------------------------------------------+
//| Create a rectangle label (panel background)                       |
//+------------------------------------------------------------------+
void CreateRect(const string name, int x, int y, int w, int h,
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
//+------------------------------------------------------------------+
