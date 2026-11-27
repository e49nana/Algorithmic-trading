//+------------------------------------------------------------------+
//|                                              StopLossManager.mqh |
//|                                        Copyright 2026, Algosphere |
//|                                      https://algosphere-quant.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Algosphere"
#property link      "https://algosphere-quant.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Enumeration of stop loss calculation methods                     |
//+------------------------------------------------------------------+
enum ENUM_SL_METHOD
  {
   SL_METHOD_FIXED_PIPS=0,    // Fixed Pips
   SL_METHOD_ATR=1,           // ATR Based
   SL_METHOD_SWING=2,         // Swing High/Low
   SL_METHOD_PERCENT=3        // Percentage of Price
  };

//+------------------------------------------------------------------+
//| Enumeration of trailing stop methods                             |
//+------------------------------------------------------------------+
enum ENUM_TRAIL_METHOD
  {
   TRAIL_NONE=0,              // No Trailing
   TRAIL_FIXED=1,             // Fixed Distance
   TRAIL_ATR=2,               // ATR Based
   TRAIL_STEP=3,              // Step Trailing
   TRAIL_BREAKEVEN=4          // Breakeven Only
  };

//+------------------------------------------------------------------+
//| Structure for stop loss calculation result                       |
//+------------------------------------------------------------------+
struct SStopLossResult
  {
   double            price;            // Stop loss price level
   double            distance_points;  // Distance in points
   double            distance_pips;    // Distance in pips
   bool              valid;            // Calculation valid flag
   string            error;            // Error message if invalid
  };

//+------------------------------------------------------------------+
//| Class for managing stop loss calculations and trailing           |
//+------------------------------------------------------------------+
class CStopLossManager
  {
private:
   string            m_symbol;         // Trading symbol
   ENUM_TIMEFRAMES   m_timeframe;      // Calculation timeframe
   int               m_atr_handle;     // ATR indicator handle
   int               m_atr_period;     // ATR period
   double            m_point;          // Symbol point size
   double            m_pip_size;       // Pip size in points
   int               m_digits;         // Symbol digits
   int               m_stops_level;    // Broker minimum stops level
   bool              m_initialized;    // Initialization flag

   //--- Private methods
   double            GetATRValue(const int shift=0);
   double            GetSwingHigh(const int lookback);
   double            GetSwingLow(const int lookback);
   double            NormalizePrice(const double price);
   double            AdjustForStopsLevel(const double sl_price,
                                         const double entry_price,
                                         const bool is_buy);

public:
   //--- Constructor and destructor
                     CStopLossManager(void);
                    ~CStopLossManager(void);

   //--- Initialization
   bool              Init(const string symbol,
                          const ENUM_TIMEFRAMES timeframe=PERIOD_CURRENT,
                          const int atr_period=14);

   //--- Stop loss calculation methods
   SStopLossResult   CalculateStopLoss(const ENUM_SL_METHOD method,
                                       const bool is_buy,
                                       const double entry_price,
                                       const double param1=0.0,
                                       const double param2=0.0);

   SStopLossResult   CalculateFixedPipsSL(const bool is_buy,
                                          const double entry_price,
                                          const double pips);

   SStopLossResult   CalculateATRSL(const bool is_buy,
                                    const double entry_price,
                                    const double atr_multiplier=1.5);

   SStopLossResult   CalculateSwingSL(const bool is_buy,
                                      const double entry_price,
                                      const int lookback=10,
                                      const double buffer_pips=5.0);

   SStopLossResult   CalculatePercentSL(const bool is_buy,
                                        const double entry_price,
                                        const double percent=1.0);

   //--- Take profit calculation
   double            CalculateTakeProfit(const bool is_buy,
                                         const double entry_price,
                                         const double sl_price,
                                         const double rr_ratio=2.0);

   //--- Trailing stop methods
   double            CalculateTrailingStop(const ENUM_TRAIL_METHOD method,
                                           const bool is_buy,
                                           const double entry_price,
                                           const double current_sl,
                                           const double current_price,
                                           const double param1=0.0,
                                           const double param2=0.0);

   double            TrailFixed(const bool is_buy,
                                const double current_sl,
                                const double current_price,
                                const double trail_distance_pips);

   double            TrailATR(const bool is_buy,
                              const double current_sl,
                              const double current_price,
                              const double atr_multiplier=2.0);

   double            TrailStep(const bool is_buy,
                               const double entry_price,
                               const double current_sl,
                               const double current_price,
                               const double step_pips=10.0);

   double            TrailBreakeven(const bool is_buy,
                                    const double entry_price,
                                    const double current_sl,
                                    const double current_price,
                                    const double trigger_pips=20.0,
                                    const double be_offset_pips=2.0);

   //--- Utility methods
   double            PipsToPoints(const double pips);
   double            PointsToPips(const double points);
   double            PipsToPrice(const double pips);

   //--- Information methods
   double            GetCurrentATR(void)     { return(GetATRValue(0)); }
   int               GetStopsLevel(void)     { return(m_stops_level); }
   double            GetPipSize(void)        { return(m_pip_size); }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStopLossManager::CStopLossManager(void) : m_symbol(""),
                                           m_timeframe(PERIOD_CURRENT),
                                           m_atr_handle(INVALID_HANDLE),
                                           m_atr_period(14),
                                           m_point(0),
                                           m_pip_size(0),
                                           m_digits(0),
                                           m_stops_level(0),
                                           m_initialized(false)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStopLossManager::~CStopLossManager(void)
  {
//--- Release indicator handle
   if(m_atr_handle!=INVALID_HANDLE)
      IndicatorRelease(m_atr_handle);
  }

//+------------------------------------------------------------------+
//| Initialize the stop loss manager                                 |
//+------------------------------------------------------------------+
bool CStopLossManager::Init(const string symbol,
                            const ENUM_TIMEFRAMES timeframe=PERIOD_CURRENT,
                            const int atr_period=14)
  {
   m_symbol=symbol;
   m_timeframe=(timeframe==PERIOD_CURRENT) ? Period() : timeframe;
   m_atr_period=atr_period;

//--- Get symbol specifications
   m_point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   m_digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   m_stops_level=(int)SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);

//--- Calculate pip size (10 points for 5-digit, 1 point for 4-digit)
   m_pip_size=(m_digits==5 || m_digits==3) ? m_point*10 : m_point;

//--- Validate symbol data
   if(m_point==0)
     {
      Print("Error: Invalid symbol point value for ",symbol);
      return(false);
     }

//--- Create ATR indicator handle
   m_atr_handle=iATR(symbol,m_timeframe,m_atr_period);
   if(m_atr_handle==INVALID_HANDLE)
     {
      Print("Error: Failed to create ATR indicator handle");
      return(false);
     }

   m_initialized=true;
   return(true);
  }

//+------------------------------------------------------------------+
//| Get ATR indicator value                                          |
//+------------------------------------------------------------------+
double CStopLossManager::GetATRValue(const int shift=0)
  {
   if(m_atr_handle==INVALID_HANDLE)
      return(0.0);

   double atr_buffer[1];
   if(CopyBuffer(m_atr_handle,0,shift,1,atr_buffer)!=1)
      return(0.0);

   return(atr_buffer[0]);
  }

//+------------------------------------------------------------------+
//| Get swing high price                                             |
//+------------------------------------------------------------------+
double CStopLossManager::GetSwingHigh(const int lookback)
  {
   double high_buffer[];
   ArraySetAsSeries(high_buffer,true);

   if(CopyHigh(m_symbol,m_timeframe,0,lookback,high_buffer)!=lookback)
      return(0.0);

   double highest=high_buffer[0];
   for(int i=1; i<lookback; i++)
     {
      if(high_buffer[i]>highest)
         highest=high_buffer[i];
     }

   return(highest);
  }

//+------------------------------------------------------------------+
//| Get swing low price                                              |
//+------------------------------------------------------------------+
double CStopLossManager::GetSwingLow(const int lookback)
  {
   double low_buffer[];
   ArraySetAsSeries(low_buffer,true);

   if(CopyLow(m_symbol,m_timeframe,0,lookback,low_buffer)!=lookback)
      return(0.0);

   double lowest=low_buffer[0];
   for(int i=1; i<lookback; i++)
     {
      if(low_buffer[i]<lowest)
         lowest=low_buffer[i];
     }

   return(lowest);
  }

//+------------------------------------------------------------------+
//| Normalize price to symbol digits                                 |
//+------------------------------------------------------------------+
double CStopLossManager::NormalizePrice(const double price)
  {
   return(NormalizeDouble(price,m_digits));
  }

//+------------------------------------------------------------------+
//| Adjust stop loss for broker minimum stops level                  |
//+------------------------------------------------------------------+
double CStopLossManager::AdjustForStopsLevel(const double sl_price,
                                             const double entry_price,
                                             const bool is_buy)
  {
   if(m_stops_level==0)
      return(sl_price);

   double min_distance=m_stops_level*m_point;
   double current_distance=MathAbs(entry_price-sl_price);

   if(current_distance>=min_distance)
      return(sl_price);

//--- Adjust stop loss to meet minimum distance
   if(is_buy)
      return(NormalizePrice(entry_price-min_distance));
   else
      return(NormalizePrice(entry_price+min_distance));
  }

//+------------------------------------------------------------------+
//| Universal stop loss calculation method                           |
//+------------------------------------------------------------------+
SStopLossResult CStopLossManager::CalculateStopLoss(const ENUM_SL_METHOD method,
                                                    const bool is_buy,
                                                    const double entry_price,
                                                    const double param1=0.0,
                                                    const double param2=0.0)
  {
   SStopLossResult result;
   ZeroMemory(result);

   if(!m_initialized)
     {
      result.valid=false;
      result.error="Stop loss manager not initialized";
      return(result);
     }

   switch(method)
     {
      case SL_METHOD_FIXED_PIPS:
         result=CalculateFixedPipsSL(is_buy,entry_price,param1);
         break;
      case SL_METHOD_ATR:
         result=CalculateATRSL(is_buy,entry_price,param1>0 ? param1 : 1.5);
         break;
      case SL_METHOD_SWING:
         result=CalculateSwingSL(is_buy,entry_price,(int)(param1>0 ? param1 : 10),param2>0 ? param2 : 5.0);
         break;
      case SL_METHOD_PERCENT:
         result=CalculatePercentSL(is_buy,entry_price,param1>0 ? param1 : 1.0);
         break;
     }

   return(result);
  }

//+------------------------------------------------------------------+
//| Calculate fixed pips stop loss                                   |
//+------------------------------------------------------------------+
SStopLossResult CStopLossManager::CalculateFixedPipsSL(const bool is_buy,
                                                       const double entry_price,
                                                       const double pips)
  {
   SStopLossResult result;
   ZeroMemory(result);

   if(pips<=0)
     {
      result.valid=false;
      result.error="Invalid pips value";
      return(result);
     }

   double distance=pips*m_pip_size;

   if(is_buy)
      result.price=NormalizePrice(entry_price-distance);
   else
      result.price=NormalizePrice(entry_price+distance);

//--- Adjust for stops level
   result.price=AdjustForStopsLevel(result.price,entry_price,is_buy);

//--- Calculate final distances
   result.distance_points=MathAbs(entry_price-result.price)/m_point;
   result.distance_pips=result.distance_points/(m_pip_size/m_point);
   result.valid=true;

   return(result);
  }

//+------------------------------------------------------------------+
//| Calculate ATR-based stop loss                                    |
//+------------------------------------------------------------------+
SStopLossResult CStopLossManager::CalculateATRSL(const bool is_buy,
                                                 const double entry_price,
                                                 const double atr_multiplier=1.5)
  {
   SStopLossResult result;
   ZeroMemory(result);

   double atr=GetATRValue(0);
   if(atr==0)
     {
      result.valid=false;
      result.error="Failed to get ATR value";
      return(result);
     }

   double distance=atr*atr_multiplier;

   if(is_buy)
      result.price=NormalizePrice(entry_price-distance);
   else
      result.price=NormalizePrice(entry_price+distance);

//--- Adjust for stops level
   result.price=AdjustForStopsLevel(result.price,entry_price,is_buy);

//--- Calculate final distances
   result.distance_points=MathAbs(entry_price-result.price)/m_point;
   result.distance_pips=result.distance_points/(m_pip_size/m_point);
   result.valid=true;

   return(result);
  }

//+------------------------------------------------------------------+
//| Calculate swing-based stop loss                                  |
//+------------------------------------------------------------------+
SStopLossResult CStopLossManager::CalculateSwingSL(const bool is_buy,
                                                   const double entry_price,
                                                   const int lookback=10,
                                                   const double buffer_pips=5.0)
  {
   SStopLossResult result;
   ZeroMemory(result);

   double buffer=buffer_pips*m_pip_size;

   if(is_buy)
     {
      double swing_low=GetSwingLow(lookback);
      if(swing_low==0)
        {
         result.valid=false;
         result.error="Failed to find swing low";
         return(result);
        }
      result.price=NormalizePrice(swing_low-buffer);
     }
   else
     {
      double swing_high=GetSwingHigh(lookback);
      if(swing_high==0)
        {
         result.valid=false;
         result.error="Failed to find swing high";
         return(result);
        }
      result.price=NormalizePrice(swing_high+buffer);
     }

//--- Adjust for stops level
   result.price=AdjustForStopsLevel(result.price,entry_price,is_buy);

//--- Calculate final distances
   result.distance_points=MathAbs(entry_price-result.price)/m_point;
   result.distance_pips=result.distance_points/(m_pip_size/m_point);
   result.valid=true;

   return(result);
  }

//+------------------------------------------------------------------+
//| Calculate percentage-based stop loss                             |
//+------------------------------------------------------------------+
SStopLossResult CStopLossManager::CalculatePercentSL(const bool is_buy,
                                                     const double entry_price,
                                                     const double percent=1.0)
  {
   SStopLossResult result;
   ZeroMemory(result);

   if(percent<=0 || percent>100)
     {
      result.valid=false;
      result.error="Invalid percentage value";
      return(result);
     }

   double distance=entry_price*(percent/100.0);

   if(is_buy)
      result.price=NormalizePrice(entry_price-distance);
   else
      result.price=NormalizePrice(entry_price+distance);

//--- Adjust for stops level
   result.price=AdjustForStopsLevel(result.price,entry_price,is_buy);

//--- Calculate final distances
   result.distance_points=MathAbs(entry_price-result.price)/m_point;
   result.distance_pips=result.distance_points/(m_pip_size/m_point);
   result.valid=true;

   return(result);
  }

//+------------------------------------------------------------------+
//| Calculate take profit based on risk:reward ratio                 |
//+------------------------------------------------------------------+
double CStopLossManager::CalculateTakeProfit(const bool is_buy,
                                             const double entry_price,
                                             const double sl_price,
                                             const double rr_ratio=2.0)
  {
   double sl_distance=MathAbs(entry_price-sl_price);
   double tp_distance=sl_distance*rr_ratio;

   if(is_buy)
      return(NormalizePrice(entry_price+tp_distance));
   else
      return(NormalizePrice(entry_price-tp_distance));
  }

//+------------------------------------------------------------------+
//| Universal trailing stop calculation                              |
//+------------------------------------------------------------------+
double CStopLossManager::CalculateTrailingStop(const ENUM_TRAIL_METHOD method,
                                               const bool is_buy,
                                               const double entry_price,
                                               const double current_sl,
                                               const double current_price,
                                               const double param1=0.0,
                                               const double param2=0.0)
  {
   if(!m_initialized)
      return(current_sl);

   switch(method)
     {
      case TRAIL_NONE:
         return(current_sl);
      case TRAIL_FIXED:
         return(TrailFixed(is_buy,current_sl,current_price,param1>0 ? param1 : 20.0));
      case TRAIL_ATR:
         return(TrailATR(is_buy,current_sl,current_price,param1>0 ? param1 : 2.0));
      case TRAIL_STEP:
         return(TrailStep(is_buy,entry_price,current_sl,current_price,param1>0 ? param1 : 10.0));
      case TRAIL_BREAKEVEN:
         return(TrailBreakeven(is_buy,entry_price,current_sl,current_price,
                               param1>0 ? param1 : 20.0,param2>0 ? param2 : 2.0));
     }

   return(current_sl);
  }

//+------------------------------------------------------------------+
//| Fixed distance trailing stop                                     |
//+------------------------------------------------------------------+
double CStopLossManager::TrailFixed(const bool is_buy,
                                    const double current_sl,
                                    const double current_price,
                                    const double trail_distance_pips)
  {
   double distance=trail_distance_pips*m_pip_size;
   double new_sl;

   if(is_buy)
     {
      new_sl=NormalizePrice(current_price-distance);
      if(new_sl>current_sl)
         return(new_sl);
     }
   else
     {
      new_sl=NormalizePrice(current_price+distance);
      if(new_sl<current_sl || current_sl==0)
         return(new_sl);
     }

   return(current_sl);
  }

//+------------------------------------------------------------------+
//| ATR-based trailing stop                                          |
//+------------------------------------------------------------------+
double CStopLossManager::TrailATR(const bool is_buy,
                                  const double current_sl,
                                  const double current_price,
                                  const double atr_multiplier=2.0)
  {
   double atr=GetATRValue(0);
   if(atr==0)
      return(current_sl);

   double distance=atr*atr_multiplier;
   double new_sl;

   if(is_buy)
     {
      new_sl=NormalizePrice(current_price-distance);
      if(new_sl>current_sl)
         return(new_sl);
     }
   else
     {
      new_sl=NormalizePrice(current_price+distance);
      if(new_sl<current_sl || current_sl==0)
         return(new_sl);
     }

   return(current_sl);
  }

//+------------------------------------------------------------------+
//| Step trailing stop                                               |
//+------------------------------------------------------------------+
double CStopLossManager::TrailStep(const bool is_buy,
                                   const double entry_price,
                                   const double current_sl,
                                   const double current_price,
                                   const double step_pips=10.0)
  {
   double step=step_pips*m_pip_size;
   double profit_distance;
   int steps_in_profit;

   if(is_buy)
     {
      profit_distance=current_price-entry_price;
      if(profit_distance<=0)
         return(current_sl);

      steps_in_profit=(int)MathFloor(profit_distance/step);
      if(steps_in_profit>0)
        {
         double new_sl=NormalizePrice(entry_price+(steps_in_profit-1)*step);
         if(new_sl>current_sl)
            return(new_sl);
        }
     }
   else
     {
      profit_distance=entry_price-current_price;
      if(profit_distance<=0)
         return(current_sl);

      steps_in_profit=(int)MathFloor(profit_distance/step);
      if(steps_in_profit>0)
        {
         double new_sl=NormalizePrice(entry_price-(steps_in_profit-1)*step);
         if(new_sl<current_sl || current_sl==0)
            return(new_sl);
        }
     }

   return(current_sl);
  }

//+------------------------------------------------------------------+
//| Breakeven trailing stop                                          |
//+------------------------------------------------------------------+
double CStopLossManager::TrailBreakeven(const bool is_buy,
                                        const double entry_price,
                                        const double current_sl,
                                        const double current_price,
                                        const double trigger_pips=20.0,
                                        const double be_offset_pips=2.0)
  {
   double trigger=trigger_pips*m_pip_size;
   double offset=be_offset_pips*m_pip_size;

   if(is_buy)
     {
      //--- Check if price has moved enough to trigger breakeven
      if(current_price-entry_price>=trigger)
        {
         double be_level=NormalizePrice(entry_price+offset);
         if(be_level>current_sl)
            return(be_level);
        }
     }
   else
     {
      //--- Check if price has moved enough to trigger breakeven
      if(entry_price-current_price>=trigger)
        {
         double be_level=NormalizePrice(entry_price-offset);
         if(be_level<current_sl || current_sl==0)
            return(be_level);
        }
     }

   return(current_sl);
  }

//+------------------------------------------------------------------+
//| Convert pips to points                                           |
//+------------------------------------------------------------------+
double CStopLossManager::PipsToPoints(const double pips)
  {
   return(pips*(m_pip_size/m_point));
  }

//+------------------------------------------------------------------+
//| Convert points to pips                                           |
//+------------------------------------------------------------------+
double CStopLossManager::PointsToPips(const double points)
  {
   if(m_pip_size==0)
      return(0);
   return(points/(m_pip_size/m_point));
  }

//+------------------------------------------------------------------+
//| Convert pips to price distance                                   |
//+------------------------------------------------------------------+
double CStopLossManager::PipsToPrice(const double pips)
  {
   return(pips*m_pip_size);
  }
//+------------------------------------------------------------------+
