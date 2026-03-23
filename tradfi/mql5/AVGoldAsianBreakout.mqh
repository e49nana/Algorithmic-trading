//+------------------------------------------------------------------+
//|                                        AVGoldAsianBreakout.mqh    |
//|                        Copyright 2026, Algosphere Quant           |
//|              AnaValencia Gold - Asian Range Breakout Strategy      |
//+------------------------------------------------------------------+
//| ╔═══════════════════════════════════════════════════════════════╗  |
//| ║  STRATEGY 1: ASIAN RANGE BREAKOUT                            ║  |
//| ║                                                               ║  |
//| ║  Gold consolidates during Asian session (00:00-06:00 UTC),   ║  |
//| ║  creating a "liquidity box". At London open, price sweeps    ║  |
//| ║  the high or low of this range, then reverses. The EA:       ║  |
//| ║  1. Records Asian session High/Low (the "box")               ║  |
//| ║  2. Waits for London/NY session                              ║  |
//| ║  3. Detects liquidity sweep beyond box (false breakout)      ║  |
//| ║  4. Confirms reversal with structure break (candle close)    ║  |
//| ║  5. Enters counter-sweep direction                           ║  |
//| ║  6. TP at opposing side of box / SL beyond sweep wick        ║  |
//| ║                                                               ║  |
//| ║  Also supports CLEAN breakout mode (no sweep required)       ║  |
//| ╚═══════════════════════════════════════════════════════════════╝  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Algosphere Quant"
#property version   "1.00"
#property strict

#ifndef AVGOLDASIANBREAKOUT_MQH
#define AVGOLDASIANBREAKOUT_MQH

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                      |
//+------------------------------------------------------------------+
enum ENUM_ASIAN_MODE
{
   ASIAN_SWEEP_REVERSAL  = 0,   // Sweep + Reversal (high probability)
   ASIAN_CLEAN_BREAKOUT  = 1,   // Clean Breakout (more signals)
   ASIAN_BOTH            = 2    // Both modes (most signals)
};

//+------------------------------------------------------------------+
//| ASIAN RANGE SIGNAL STRUCTURE                                      |
//+------------------------------------------------------------------+
struct SAsianSignal
{
   bool              valid;
   int               direction;      // +1 = BUY, -1 = SELL
   double            strength;       // 0.0 - 1.0
   string            reason;         // Signal description
   double            entryPrice;     // Suggested entry
   double            tpPrice;        // Suggested TP
   double            slPrice;        // Suggested SL
   double            rrRatio;        // Risk:Reward ratio
   bool              isSweep;        // Was there a liquidity sweep?
   double            sweepPips;      // How far the sweep went beyond box
   datetime          signalTime;     // When signal was generated
   
   void Reset()
   {
      valid = false;
      direction = 0;
      strength = 0;
      reason = "";
      entryPrice = 0;
      tpPrice = 0;
      slPrice = 0;
      rrRatio = 0;
      isSweep = false;
      sweepPips = 0;
      signalTime = 0;
   }
};

//+------------------------------------------------------------------+
//| ASIAN RANGE DATA                                                  |
//+------------------------------------------------------------------+
struct SAVAsianRange
{
   double            high;           // Asian session high
   double            low;            // Asian session low
   double            rangePips;      // Range size in pips
   double            midpoint;       // Midpoint of range
   datetime          highTime;       // Time of high
   datetime          lowTime;        // Time of low
   datetime          sessionStart;   // Start of Asian session
   datetime          sessionEnd;     // End of Asian session
   bool              valid;          // Is current day's range valid?
   bool              swept_high;     // Was high swept?
   bool              swept_low;      // Was low swept?
   double            sweep_high_max; // Max price during high sweep
   double            sweep_low_min;  // Min price during low sweep
   bool              traded_today;   // Already traded this setup today?
   int               trade_count;    // Trades taken from this range
   
   void Reset()
   {
      high = 0;
      low = DBL_MAX;
      rangePips = 0;
      midpoint = 0;
      highTime = 0;
      lowTime = 0;
      sessionStart = 0;
      sessionEnd = 0;
      valid = false;
      swept_high = false;
      swept_low = false;
      sweep_high_max = 0;
      sweep_low_min = DBL_MAX;
      traded_today = false;
      trade_count = 0;
   }
};

//+------------------------------------------------------------------+
//| CLASS: CAVGoldAsianBreakout                                       |
//+------------------------------------------------------------------+
class CAVGoldAsianBreakout
{
private:
   //--- Configuration
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;
   double            m_pipValue;
   int               m_digits;
   ENUM_ASIAN_MODE   m_mode;
   
   //--- Asian Session Time (UTC/GMT hours)
   int               m_asianStartHour;    // Default: 0 (midnight UTC)
   int               m_asianEndHour;      // Default: 6 (06:00 UTC)
   int               m_londonStartHour;   // Default: 7 (07:00 UTC)
   int               m_tradeWindowEnd;    // Default: 16 (16:00 UTC) - stop looking for signals
   
   //--- Broker GMT offset
   int               m_brokerGMTOffset;   // Hours to add to broker time to get GMT
   
   //--- Range filters
   double            m_minRangePips;      // Minimum Asian range to trade (default: 30 pips for Gold)
   double            m_maxRangePips;      // Maximum Asian range (too wide = no trade, default: 200)
   double            m_sweepMinPips;      // Minimum sweep beyond box (default: 5 pips)
   double            m_sweepMaxPips;      // Maximum sweep (if too far, it's a real breakout, default: 80)
   int               m_maxTradesPerRange; // Max trades per Asian range (default: 2)
   
   //--- TP/SL configuration
   double            m_tpMultiplier;      // TP as multiple of range (default: 0.5 = opposing 50% of box)
   double            m_slBufferPips;      // SL buffer beyond sweep high/low (default: 15 pips)
   double            m_minRRRatio;        // Minimum R:R to take trade (default: 1.5)
   
   //--- EMA filter
   bool              m_useEMAFilter;      // Use EMA 200 for directional bias
   int               m_emaPeriod;         // EMA period (default: 200)
   int               m_emaHandle;         // iMA handle
   
   //--- State
   SAVAsianRange       m_currentRange;      // Today's Asian range
   SAsianSignal      m_signal;            // Current signal
   datetime          m_lastRangeDate;     // Date of last calculated range
   bool              m_initialized;
   bool              m_rangeComplete;     // Asian session ended, range is locked
   
   //--- Internal methods
   int               GetGMTHour();
   void              BuildAsianRange();
   bool              IsInAsianSession();
   bool              IsInTradeWindow();
   bool              DetectSweepReversal();
   bool              DetectCleanBreakout();
   double            GetEMAValue();
   bool              EMAFilterPassed(int direction);
   
public:
                     CAVGoldAsianBreakout();
                    ~CAVGoldAsianBreakout();
   
   //--- Initialization
   bool              Initialize(string symbol, ENUM_TIMEFRAMES tf, double pipValue, int digits);
   void              SetMode(ENUM_ASIAN_MODE mode)        { m_mode = mode; }
   void              SetSessionTimes(int startH, int endH, int londonH, int tradeEndH);
   void              SetBrokerGMTOffset(int offset)       { m_brokerGMTOffset = offset; }
   void              SetRangeFilters(double minPips, double maxPips);
   void              SetSweepFilters(double minPips, double maxPips);
   void              SetMaxTrades(int maxTrades)           { m_maxTradesPerRange = maxTrades; }
   void              SetTPSL(double tpMult, double slBuffer, double minRR);
   void              SetEMAFilter(bool use, int period);
   
   //--- Core
   void              Update();           // Call on each tick or new bar
   void              OnNewDay();         // Reset for new day
   bool              HasSignal()         { return m_signal.valid; }
   SAsianSignal      GetSignal()         { return m_signal; }
   int               GetSignalDirection(){ return m_signal.direction; }
   double            GetSignalStrength() { return m_signal.strength; }
   void              ClearSignal()       { m_signal.Reset(); }
   void              OnTradeExecuted()   { m_currentRange.trade_count++; }
   
   //--- Info
   SAVAsianRange       GetCurrentRange()   { return m_currentRange; }
   bool              IsRangeValid()      { return m_currentRange.valid && m_rangeComplete; }
   double            GetRangeHighPrice() { return m_currentRange.high; }
   double            GetRangeLowPrice()  { return m_currentRange.low; }
   double            GetRangePips()      { return m_currentRange.rangePips; }
   string            GetStatusText();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CAVGoldAsianBreakout::CAVGoldAsianBreakout()
{
   m_symbol = "";
   m_tf = PERIOD_M5;
   m_pipValue = 0.01;  // Gold: 1 pip = 0.01
   m_digits = 2;
   m_mode = ASIAN_SWEEP_REVERSAL;
   
   // Default Asian session: 00:00 - 06:00 GMT
   m_asianStartHour = 0;
   m_asianEndHour = 6;
   m_londonStartHour = 7;
   m_tradeWindowEnd = 16;
   m_brokerGMTOffset = 0;
   
   // Gold-specific range filters
   m_minRangePips = 30;       // Gold typically moves 50-150 pips in Asian
   m_maxRangePips = 200;      // If range > 200 pips, too wide
   m_sweepMinPips = 5;        // At least 5 pips beyond box = sweep
   m_sweepMaxPips = 80;       // More than 80 pips = real breakout, not sweep
   m_maxTradesPerRange = 2;
   
   // TP/SL
   m_tpMultiplier = 0.5;      // Target: 50% of range (opposing side)
   m_slBufferPips = 15;       // SL 15 pips beyond sweep extreme
   m_minRRRatio = 1.5;
   
   // EMA filter
   m_useEMAFilter = true;
   m_emaPeriod = 200;
   m_emaHandle = INVALID_HANDLE;
   
   // State
   m_currentRange.Reset();
   m_signal.Reset();
   m_lastRangeDate = 0;
   m_initialized = false;
   m_rangeComplete = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CAVGoldAsianBreakout::~CAVGoldAsianBreakout()
{
   if(m_emaHandle != INVALID_HANDLE)
      IndicatorRelease(m_emaHandle);
}

//+------------------------------------------------------------------+
//| Initialize                                                        |
//+------------------------------------------------------------------+
bool CAVGoldAsianBreakout::Initialize(string symbol, ENUM_TIMEFRAMES tf, double pipValue, int digits)
{
   m_symbol = symbol;
   m_tf = tf;
   m_pipValue = pipValue;
   m_digits = digits;
   
   // Create EMA indicator
   if(m_useEMAFilter)
   {
      m_emaHandle = iMA(m_symbol, PERIOD_H1, m_emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(m_emaHandle == INVALID_HANDLE)
      {
         LogWarning("[AsianBreakout] Failed to create EMA(" + IntegerToString(m_emaPeriod) + ") - continuing without EMA filter");
         m_useEMAFilter = false;
      }
   }
   
   m_initialized = true;
   LogInfo("[AsianBreakout] Initialized | Mode: " + EnumToString(m_mode) + 
           " | Range: " + DoubleToString(m_minRangePips, 0) + "-" + DoubleToString(m_maxRangePips, 0) + " pips" +
           " | Sweep: " + DoubleToString(m_sweepMinPips, 0) + "-" + DoubleToString(m_sweepMaxPips, 0) + " pips" +
           " | EMA: " + (m_useEMAFilter ? IntegerToString(m_emaPeriod) : "OFF"));
   
   return true;
}

//+------------------------------------------------------------------+
//| Configuration setters                                             |
//+------------------------------------------------------------------+
void CAVGoldAsianBreakout::SetSessionTimes(int startH, int endH, int londonH, int tradeEndH)
{
   m_asianStartHour = startH;
   m_asianEndHour = endH;
   m_londonStartHour = londonH;
   m_tradeWindowEnd = tradeEndH;
}

void CAVGoldAsianBreakout::SetRangeFilters(double minPips, double maxPips)
{
   m_minRangePips = minPips;
   m_maxRangePips = maxPips;
}

void CAVGoldAsianBreakout::SetSweepFilters(double minPips, double maxPips)
{
   m_sweepMinPips = minPips;
   m_sweepMaxPips = maxPips;
}

void CAVGoldAsianBreakout::SetTPSL(double tpMult, double slBuffer, double minRR)
{
   m_tpMultiplier = tpMult;
   m_slBufferPips = slBuffer;
   m_minRRRatio = minRR;
}

void CAVGoldAsianBreakout::SetEMAFilter(bool use, int period)
{
   m_useEMAFilter = use;
   m_emaPeriod = period;
   
   // Recreate handle if needed
   if(m_useEMAFilter && m_emaHandle == INVALID_HANDLE)
   {
      m_emaHandle = iMA(m_symbol, PERIOD_H1, m_emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   }
}

//+------------------------------------------------------------------+
//| Get current GMT hour (adjusted from broker time)                  |
//+------------------------------------------------------------------+
int CAVGoldAsianBreakout::GetGMTHour()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int gmtHour = (dt.hour - m_brokerGMTOffset) % 24;
   if(gmtHour < 0) gmtHour += 24;
   return gmtHour;
}

//+------------------------------------------------------------------+
//| Check if we're in Asian session                                   |
//+------------------------------------------------------------------+
bool CAVGoldAsianBreakout::IsInAsianSession()
{
   int gmtHour = GetGMTHour();
   return (gmtHour >= m_asianStartHour && gmtHour < m_asianEndHour);
}

//+------------------------------------------------------------------+
//| Check if we're in the trade window (post-Asian, pre-close)        |
//+------------------------------------------------------------------+
bool CAVGoldAsianBreakout::IsInTradeWindow()
{
   int gmtHour = GetGMTHour();
   return (gmtHour >= m_asianEndHour && gmtHour < m_tradeWindowEnd);
}

//+------------------------------------------------------------------+
//| Build Asian Range from historical bars                            |
//+------------------------------------------------------------------+
void CAVGoldAsianBreakout::BuildAsianRange()
{
   // Calculate how many bars cover the Asian session
   // We look back from the end of Asian session to find all bars within it
   
   datetime now = TimeCurrent();
   MqlDateTime dtNow;
   TimeToStruct(now, dtNow);
   
   // Check if we need to build a new range (new day)
   datetime today = StringToTime(IntegerToString(dtNow.year) + "." + 
                                  IntegerToString(dtNow.mon) + "." + 
                                  IntegerToString(dtNow.day));
   
   // If same day and range already complete, don't rebuild
   if(today == m_lastRangeDate && m_rangeComplete)
      return;
   
   // During Asian session, continuously update range
   if(IsInAsianSession())
   {
      if(today != m_lastRangeDate)
      {
         // New day - reset everything
         m_currentRange.Reset();
         m_lastRangeDate = today;
         m_rangeComplete = false;
      }
      
      // Build range from Asian session bars
      // Calculate session start time for today (in broker time)
      int brokerAsianStart = (m_asianStartHour + m_brokerGMTOffset) % 24;
      if(brokerAsianStart < 0) brokerAsianStart += 24;
      
      datetime sessionStartTime = today + brokerAsianStart * 3600;
      
      // If broker offset causes start to be previous day, adjust
      if(brokerAsianStart > dtNow.hour)
         sessionStartTime -= 86400;  // Previous day
      
      m_currentRange.sessionStart = sessionStartTime;
      
      // Scan bars from session start to now
      int bars = iBars(m_symbol, m_tf);
      for(int i = 0; i < bars && i < 500; i++)
      {
         datetime barTime = iTime(m_symbol, m_tf, i);
         if(barTime < sessionStartTime)
            break;
         if(barTime > now)
            continue;
            
         double high = iHigh(m_symbol, m_tf, i);
         double low  = iLow(m_symbol, m_tf, i);
         
         if(high > m_currentRange.high)
         {
            m_currentRange.high = high;
            m_currentRange.highTime = barTime;
         }
         if(low < m_currentRange.low)
         {
            m_currentRange.low = low;
            m_currentRange.lowTime = barTime;
         }
      }
      
      // Calculate range metrics
      if(m_currentRange.high > 0 && m_currentRange.low < DBL_MAX && m_currentRange.high > m_currentRange.low)
      {
         m_currentRange.rangePips = (m_currentRange.high - m_currentRange.low) / m_pipValue;
         m_currentRange.midpoint = (m_currentRange.high + m_currentRange.low) / 2.0;
         m_currentRange.valid = true;
      }
      
      return;  // Still building range
   }
   
   // Post-Asian session: lock the range
   if(!m_rangeComplete && m_currentRange.valid)
   {
      // Validate range size
      if(m_currentRange.rangePips >= m_minRangePips && m_currentRange.rangePips <= m_maxRangePips)
      {
         int brokerAsianEnd = (m_asianEndHour + m_brokerGMTOffset) % 24;
         if(brokerAsianEnd < 0) brokerAsianEnd += 24;
         m_currentRange.sessionEnd = today + brokerAsianEnd * 3600;
         
         m_rangeComplete = true;
         LogInfo("[AsianBreakout] Range LOCKED | High: " + DoubleToString(m_currentRange.high, m_digits) +
                 " | Low: " + DoubleToString(m_currentRange.low, m_digits) +
                 " | Range: " + DoubleToString(m_currentRange.rangePips, 1) + " pips");
      }
      else
      {
         // Range too small or too large - invalidate
         m_currentRange.valid = false;
         m_rangeComplete = true;
         LogInfo("[AsianBreakout] Range INVALID | " + DoubleToString(m_currentRange.rangePips, 1) + 
                 " pips (need " + DoubleToString(m_minRangePips, 0) + "-" + DoubleToString(m_maxRangePips, 0) + ")");
      }
   }
   
   // If it's a new day and we missed the Asian session, try to build from history
   if(today != m_lastRangeDate && !IsInAsianSession())
   {
      m_lastRangeDate = today;
      m_currentRange.Reset();
      
      // Scan historical bars for today's Asian session
      int brokerAsianStart = (m_asianStartHour + m_brokerGMTOffset) % 24;
      int brokerAsianEnd = (m_asianEndHour + m_brokerGMTOffset) % 24;
      if(brokerAsianStart < 0) brokerAsianStart += 24;
      if(brokerAsianEnd < 0) brokerAsianEnd += 24;
      
      datetime sessionStartTime = today + brokerAsianStart * 3600;
      datetime sessionEndTime = today + brokerAsianEnd * 3600;
      
      // Handle overnight session
      if(brokerAsianStart > brokerAsianEnd)
         sessionStartTime -= 86400;
      
      m_currentRange.sessionStart = sessionStartTime;
      m_currentRange.sessionEnd = sessionEndTime;
      
      int bars = iBars(m_symbol, m_tf);
      bool foundBars = false;
      
      for(int i = 0; i < bars && i < 1000; i++)
      {
         datetime barTime = iTime(m_symbol, m_tf, i);
         if(barTime < sessionStartTime)
            break;
         if(barTime >= sessionEndTime)
            continue;
         
         foundBars = true;
         double high = iHigh(m_symbol, m_tf, i);
         double low  = iLow(m_symbol, m_tf, i);
         
         if(high > m_currentRange.high)
         {
            m_currentRange.high = high;
            m_currentRange.highTime = barTime;
         }
         if(low < m_currentRange.low)
         {
            m_currentRange.low = low;
            m_currentRange.lowTime = barTime;
         }
      }
      
      if(foundBars && m_currentRange.high > 0 && m_currentRange.low < DBL_MAX)
      {
         m_currentRange.rangePips = (m_currentRange.high - m_currentRange.low) / m_pipValue;
         m_currentRange.midpoint = (m_currentRange.high + m_currentRange.low) / 2.0;
         m_currentRange.valid = (m_currentRange.rangePips >= m_minRangePips && m_currentRange.rangePips <= m_maxRangePips);
         m_rangeComplete = true;
         
         if(m_currentRange.valid)
         {
            LogInfo("[AsianBreakout] Range BUILT from history | High: " + DoubleToString(m_currentRange.high, m_digits) +
                    " | Low: " + DoubleToString(m_currentRange.low, m_digits) +
                    " | Range: " + DoubleToString(m_currentRange.rangePips, 1) + " pips");
         }
      }
      else
      {
         m_rangeComplete = true;
         m_currentRange.valid = false;
      }
   }
}

//+------------------------------------------------------------------+
//| Get EMA value on H1                                               |
//+------------------------------------------------------------------+
double CAVGoldAsianBreakout::GetEMAValue()
{
   if(m_emaHandle == INVALID_HANDLE) return 0;
   
   double ema[];
   ArraySetAsSeries(ema, true);
   if(CopyBuffer(m_emaHandle, 0, 0, 1, ema) < 1)
      return 0;
   
   return ema[0];
}

//+------------------------------------------------------------------+
//| EMA directional filter                                            |
//+------------------------------------------------------------------+
bool CAVGoldAsianBreakout::EMAFilterPassed(int direction)
{
   if(!m_useEMAFilter) return true;
   
   double ema = GetEMAValue();
   if(ema <= 0) return true;  // If EMA unavailable, allow trade
   
   double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   
   // BUY: price should be above EMA (bullish bias)
   // SELL: price should be below EMA (bearish bias)
   if(direction > 0 && price < ema)
   {
      LogDebug("[AsianBreakout] EMA filter: Price below EMA200 - rejecting BUY");
      return false;
   }
   if(direction < 0 && price > ema)
   {
      LogDebug("[AsianBreakout] EMA filter: Price above EMA200 - rejecting SELL");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Detect Sweep + Reversal pattern                                   |
//+------------------------------------------------------------------+
bool CAVGoldAsianBreakout::DetectSweepReversal()
{
   if(!m_currentRange.valid || !m_rangeComplete)
      return false;
   
   double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   
   // Check for high sweep (price went above Asian high, then reversed)
   if(!m_currentRange.swept_high && bid > m_currentRange.high)
   {
      double sweepPips = (bid - m_currentRange.high) / m_pipValue;
      if(sweepPips >= m_sweepMinPips)
      {
         m_currentRange.swept_high = true;
         m_currentRange.sweep_high_max = bid;
         LogInfo("[AsianBreakout] HIGH SWEPT by " + DoubleToString(sweepPips, 1) + " pips");
      }
   }
   
   // Update sweep max
   if(m_currentRange.swept_high && bid > m_currentRange.sweep_high_max)
      m_currentRange.sweep_high_max = bid;
   
   // Check for low sweep (price went below Asian low, then reversed)
   if(!m_currentRange.swept_low && bid < m_currentRange.low)
   {
      double sweepPips = (m_currentRange.low - bid) / m_pipValue;
      if(sweepPips >= m_sweepMinPips)
      {
         m_currentRange.swept_low = true;
         m_currentRange.sweep_low_min = bid;
         LogInfo("[AsianBreakout] LOW SWEPT by " + DoubleToString(sweepPips, 1) + " pips");
      }
   }
   
   // Update sweep min
   if(m_currentRange.swept_low && bid < m_currentRange.sweep_low_min)
      m_currentRange.sweep_low_min = bid;
   
   //=== CHECK FOR REVERSAL AFTER SWEEP ===
   
   // HIGH sweep → price came back inside box → SELL signal
   if(m_currentRange.swept_high && !m_currentRange.swept_low)
   {
      // Confirm reversal: price must close back below the Asian high
      double close1 = iClose(m_symbol, m_tf, 1);  // Last completed bar
      double close0 = iClose(m_symbol, m_tf, 0);  // Current bar
      
      if(close1 < m_currentRange.high && close0 < m_currentRange.high && bid < m_currentRange.high)
      {
         double sweepDist = (m_currentRange.sweep_high_max - m_currentRange.high) / m_pipValue;
         
         // Verify sweep wasn't too large (real breakout)
         if(sweepDist <= m_sweepMaxPips)
         {
            // SELL signal: Sweep high + reversal
            double sl = m_currentRange.sweep_high_max + m_slBufferPips * m_pipValue;
            double tp = m_currentRange.low + (m_currentRange.high - m_currentRange.low) * (1.0 - m_tpMultiplier);
            // Alternative TP: opposing side of box
            tp = m_currentRange.low;
            
            double slPips = (sl - bid) / m_pipValue;
            double tpPips = (bid - tp) / m_pipValue;
            double rr = (slPips > 0) ? tpPips / slPips : 0;
            
            if(rr >= m_minRRRatio && EMAFilterPassed(-1))
            {
               m_signal.Reset();
               m_signal.valid = true;
               m_signal.direction = -1;
               m_signal.entryPrice = bid;
               m_signal.tpPrice = tp;
               m_signal.slPrice = sl;
               m_signal.rrRatio = rr;
               m_signal.isSweep = true;
               m_signal.sweepPips = sweepDist;
               m_signal.signalTime = TimeCurrent();
               
               // Strength based on sweep distance and R:R
               m_signal.strength = MathMin(1.0, 0.5 + (sweepDist / 30.0) * 0.2 + (rr / 3.0) * 0.3);
               m_signal.reason = "AsianSweepHigh(" + DoubleToString(sweepDist, 0) + "p) R:R=" + DoubleToString(rr, 1);
               
               LogInfo("[AsianBreakout] === SELL SIGNAL === | Sweep High " + DoubleToString(sweepDist, 1) + 
                       "p | R:R=" + DoubleToString(rr, 1) + " | Strength=" + DoubleToString(m_signal.strength * 100, 0) + "%");
               return true;
            }
         }
      }
   }
   
   // LOW sweep → price came back inside box → BUY signal
   if(m_currentRange.swept_low && !m_currentRange.swept_high)
   {
      double close1 = iClose(m_symbol, m_tf, 1);
      double close0 = iClose(m_symbol, m_tf, 0);
      
      if(close1 > m_currentRange.low && close0 > m_currentRange.low && bid > m_currentRange.low)
      {
         double sweepDist = (m_currentRange.low - m_currentRange.sweep_low_min) / m_pipValue;
         
         if(sweepDist <= m_sweepMaxPips)
         {
            // BUY signal: Sweep low + reversal
            double sl = m_currentRange.sweep_low_min - m_slBufferPips * m_pipValue;
            double tp = m_currentRange.high;
            
            double slPips = (ask - sl) / m_pipValue;
            double tpPips = (tp - ask) / m_pipValue;
            double rr = (slPips > 0) ? tpPips / slPips : 0;
            
            if(rr >= m_minRRRatio && EMAFilterPassed(1))
            {
               m_signal.Reset();
               m_signal.valid = true;
               m_signal.direction = 1;
               m_signal.entryPrice = ask;
               m_signal.tpPrice = tp;
               m_signal.slPrice = sl;
               m_signal.rrRatio = rr;
               m_signal.isSweep = true;
               m_signal.sweepPips = sweepDist;
               m_signal.signalTime = TimeCurrent();
               
               m_signal.strength = MathMin(1.0, 0.5 + (sweepDist / 30.0) * 0.2 + (rr / 3.0) * 0.3);
               m_signal.reason = "AsianSweepLow(" + DoubleToString(sweepDist, 0) + "p) R:R=" + DoubleToString(rr, 1);
               
               LogInfo("[AsianBreakout] === BUY SIGNAL === | Sweep Low " + DoubleToString(sweepDist, 1) + 
                       "p | R:R=" + DoubleToString(rr, 1) + " | Strength=" + DoubleToString(m_signal.strength * 100, 0) + "%");
               return true;
            }
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Detect Clean Breakout (no sweep required)                         |
//+------------------------------------------------------------------+
bool CAVGoldAsianBreakout::DetectCleanBreakout()
{
   if(!m_currentRange.valid || !m_rangeComplete)
      return false;
   
   double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   
   // Need a confirmed candle close beyond the range
   double close1 = iClose(m_symbol, m_tf, 1);  // Last completed bar
   double open1  = iOpen(m_symbol, m_tf, 1);
   double high1  = iHigh(m_symbol, m_tf, 1);
   double low1   = iLow(m_symbol, m_tf, 1);
   
   // Bullish breakout: candle closed above Asian high with momentum
   if(close1 > m_currentRange.high && open1 < m_currentRange.high)
   {
      double breakPips = (close1 - m_currentRange.high) / m_pipValue;
      
      // Must be a strong candle (body > 50% of total range)
      double bodySize = MathAbs(close1 - open1);
      double candleRange = high1 - low1;
      double bodyRatio = (candleRange > 0) ? bodySize / candleRange : 0;
      
      if(breakPips >= 3.0 && bodyRatio >= 0.5 && EMAFilterPassed(1))
      {
         // BUY: Breakout above Asian high
         double sl = m_currentRange.midpoint;  // SL at midpoint of range
         double tp = ask + m_currentRange.rangePips * m_tpMultiplier * m_pipValue;
         
         double slPips = (ask - sl) / m_pipValue;
         double tpPips = (tp - ask) / m_pipValue;
         double rr = (slPips > 0) ? tpPips / slPips : 0;
         
         if(rr >= m_minRRRatio)
         {
            m_signal.Reset();
            m_signal.valid = true;
            m_signal.direction = 1;
            m_signal.entryPrice = ask;
            m_signal.tpPrice = tp;
            m_signal.slPrice = sl;
            m_signal.rrRatio = rr;
            m_signal.isSweep = false;
            m_signal.sweepPips = 0;
            m_signal.signalTime = TimeCurrent();
            m_signal.strength = MathMin(1.0, 0.4 + bodyRatio * 0.3 + (rr / 3.0) * 0.3);
            m_signal.reason = "AsianBreakoutHigh(" + DoubleToString(breakPips, 0) + "p) R:R=" + DoubleToString(rr, 1);
            
            LogInfo("[AsianBreakout] === BUY BREAKOUT === | Break " + DoubleToString(breakPips, 1) + 
                    "p above range | R:R=" + DoubleToString(rr, 1));
            return true;
         }
      }
   }
   
   // Bearish breakout: candle closed below Asian low with momentum
   if(close1 < m_currentRange.low && open1 > m_currentRange.low)
   {
      double breakPips = (m_currentRange.low - close1) / m_pipValue;
      
      double bodySize = MathAbs(close1 - open1);
      double candleRange = high1 - low1;
      double bodyRatio = (candleRange > 0) ? bodySize / candleRange : 0;
      
      if(breakPips >= 3.0 && bodyRatio >= 0.5 && EMAFilterPassed(-1))
      {
         // SELL: Breakout below Asian low
         double sl = m_currentRange.midpoint;
         double tp = bid - m_currentRange.rangePips * m_tpMultiplier * m_pipValue;
         
         double slPips = (sl - bid) / m_pipValue;
         double tpPips = (bid - tp) / m_pipValue;
         double rr = (slPips > 0) ? tpPips / slPips : 0;
         
         if(rr >= m_minRRRatio)
         {
            m_signal.Reset();
            m_signal.valid = true;
            m_signal.direction = -1;
            m_signal.entryPrice = bid;
            m_signal.tpPrice = tp;
            m_signal.slPrice = sl;
            m_signal.rrRatio = rr;
            m_signal.isSweep = false;
            m_signal.sweepPips = 0;
            m_signal.signalTime = TimeCurrent();
            m_signal.strength = MathMin(1.0, 0.4 + bodyRatio * 0.3 + (rr / 3.0) * 0.3);
            m_signal.reason = "AsianBreakoutLow(" + DoubleToString(breakPips, 0) + "p) R:R=" + DoubleToString(rr, 1);
            
            LogInfo("[AsianBreakout] === SELL BREAKOUT === | Break " + DoubleToString(breakPips, 1) + 
                    "p below range | R:R=" + DoubleToString(rr, 1));
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Main Update - call on each tick or new bar                        |
//+------------------------------------------------------------------+
void CAVGoldAsianBreakout::Update()
{
   if(!m_initialized) return;
   
   //=== Step 1: Build/Update Asian Range ===
   BuildAsianRange();
   
   //=== Step 2: Don't generate signals during Asian session ===
   if(IsInAsianSession())
      return;
   
   //=== Step 3: Don't generate signals outside trade window ===
   if(!IsInTradeWindow())
      return;
   
   //=== Step 4: Check if range is valid and we haven't maxed out trades ===
   if(!m_currentRange.valid || !m_rangeComplete)
      return;
   
   if(m_currentRange.trade_count >= m_maxTradesPerRange)
      return;
   
   //=== Step 5: Don't generate new signal if one is active ===
   if(m_signal.valid)
   {
      // Check signal expiry (30 seconds for scalp signals)
      if(TimeCurrent() - m_signal.signalTime > 30)
      {
         LogDebug("[AsianBreakout] Signal expired");
         m_signal.Reset();
      }
      else
         return;
   }
   
   //=== Step 6: Detect signals based on mode ===
   switch(m_mode)
   {
      case ASIAN_SWEEP_REVERSAL:
         DetectSweepReversal();
         break;
         
      case ASIAN_CLEAN_BREAKOUT:
         DetectCleanBreakout();
         break;
         
      case ASIAN_BOTH:
         // Try sweep first (higher probability), then breakout
         if(!DetectSweepReversal())
            DetectCleanBreakout();
         break;
   }
}

//+------------------------------------------------------------------+
//| Reset for new day                                                 |
//+------------------------------------------------------------------+
void CAVGoldAsianBreakout::OnNewDay()
{
   m_currentRange.Reset();
   m_signal.Reset();
   m_rangeComplete = false;
   LogDebug("[AsianBreakout] New day - range reset");
}

//+------------------------------------------------------------------+
//| Status text for display                                           |
//+------------------------------------------------------------------+
string CAVGoldAsianBreakout::GetStatusText()
{
   if(!m_initialized)
      return "Not initialized";
   
   if(IsInAsianSession())
   {
      if(m_currentRange.valid)
         return "Building range: " + DoubleToString(m_currentRange.rangePips, 0) + "p";
      else
         return "Waiting for Asian range...";
   }
   
   if(!m_currentRange.valid)
      return "No valid range today";
   
   if(!IsInTradeWindow())
      return "Outside trade window";
   
   if(m_currentRange.trade_count >= m_maxTradesPerRange)
      return "Max trades reached (" + IntegerToString(m_maxTradesPerRange) + ")";
   
   string status = "Range: " + DoubleToString(m_currentRange.rangePips, 0) + "p";
   
   if(m_currentRange.swept_high)
      status += " | HIGH SWEPT";
   if(m_currentRange.swept_low)
      status += " | LOW SWEPT";
   
   if(m_signal.valid)
      status += " | SIGNAL: " + (m_signal.direction > 0 ? "BUY" : "SELL");
   else
      status += " | Scanning...";
   
   return status;
}

#endif // AVGOLDASIANBREAKOUT_MQH
