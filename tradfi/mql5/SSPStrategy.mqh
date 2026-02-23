//+------------------------------------------------------------------+
//|                                                SSPStrategy.mqh   |
//|             SafeScalperPro v3.0 - Strategy Engine Module          |
//|  Indicators, Breakout Detection, Signal Generation, All Filters  |
//+------------------------------------------------------------------+
#property copyright   "AlgoSphere Quant"
#property version     "3.10"
#property strict

#ifndef SSP_STRATEGY_MQH
#define SSP_STRATEGY_MQH

#include "SSPCore.mqh"

//+------------------------------------------------------------------+
//| STRATEGY ENGINE CLASS                                            |
//+------------------------------------------------------------------+
class CSSPStrategy
  {
private:
   // Indicator handles
   int               m_hEmaFast;
   int               m_hEmaSlow;
   int               m_hRsi;
   int               m_hAtr;
   
   // Indicator buffers
   double            m_bufEmaFast[];
   double            m_bufEmaSlow[];
   double            m_bufRsi[];
   double            m_bufAtr[];
   
   // Cached indicator snapshot
   SSspIndicators    m_ind;
   
   // Config (set once from inputs)
   int               m_emaFastPeriod;
   int               m_emaSlowPeriod;
   int               m_rsiPeriod;
   int               m_atrPeriod;
   int               m_breakoutLookback;
   double            m_breakoutBuffer;
   ENUM_SSP_TREND_STRENGTH m_trendStrength;
   double            m_rsiBuyMin, m_rsiBuyMax;
   double            m_rsiSellMin, m_rsiSellMax;
   
   // Session config
   bool              m_useSession;
   int               m_sessStartH, m_sessStartM;
   int               m_sessEndH, m_sessEndM;
   bool              m_avoidFriday;
   int               m_fridayCutoff;
   
   // Spread config
   bool              m_useSpread;
   int               m_maxSpread;
   
   // News config
   bool              m_useNews;
   string            m_newsTime[3];
   int               m_newsMinsBefore;
   int               m_newsMinsAfter;
   
   bool              m_initialized;
   
public:
                     CSSPStrategy() : m_hEmaFast(INVALID_HANDLE), m_hEmaSlow(INVALID_HANDLE),
                                      m_hRsi(INVALID_HANDLE), m_hAtr(INVALID_HANDLE),
                                      m_initialized(false) { m_ind.Reset(); }
                    ~CSSPStrategy() { Deinit(); }
   
   //--- Initialization
   bool Init(string symbol, ENUM_TIMEFRAMES tf,
             int emaFast, int emaSlow, int rsiPeriod, int atrPeriod,
             int breakoutLookback, double breakoutBuffer,
             ENUM_SSP_TREND_STRENGTH trendStrength,
             double rsiBuyMin, double rsiBuyMax,
             double rsiSellMin, double rsiSellMax)
     {
      m_emaFastPeriod   = emaFast;
      m_emaSlowPeriod   = emaSlow;
      m_rsiPeriod       = rsiPeriod;
      m_atrPeriod       = atrPeriod;
      m_breakoutLookback= breakoutLookback;
      m_breakoutBuffer  = breakoutBuffer;
      m_trendStrength   = trendStrength;
      m_rsiBuyMin       = rsiBuyMin;
      m_rsiBuyMax       = rsiBuyMax;
      m_rsiSellMin      = rsiSellMin;
      m_rsiSellMax      = rsiSellMax;
      
      // Create indicators
      m_hEmaFast = iMA(symbol, tf, emaFast, 0, MODE_EMA, PRICE_CLOSE);
      m_hEmaSlow = iMA(symbol, tf, emaSlow, 0, MODE_EMA, PRICE_CLOSE);
      m_hRsi     = iRSI(symbol, tf, rsiPeriod, PRICE_CLOSE);
      m_hAtr     = iATR(symbol, tf, atrPeriod);
      
      if(m_hEmaFast == INVALID_HANDLE || m_hEmaSlow == INVALID_HANDLE ||
         m_hRsi == INVALID_HANDLE || m_hAtr == INVALID_HANDLE)
        { SSPError("Indicator creation failed"); return false; }
      
      ArraySetAsSeries(m_bufEmaFast, true);
      ArraySetAsSeries(m_bufEmaSlow, true);
      ArraySetAsSeries(m_bufRsi, true);
      ArraySetAsSeries(m_bufAtr, true);
      
      m_initialized = true;
      SSPInfo("Strategy engine initialized | EMA " + IntegerToString(emaFast) + "/" +
              IntegerToString(emaSlow) + " | RSI " + IntegerToString(rsiPeriod) +
              " | ATR " + IntegerToString(atrPeriod) +
              " | Breakout " + IntegerToString(breakoutLookback) + " bars");
      return true;
     }
   
   void Deinit()
     {
      if(m_hEmaFast != INVALID_HANDLE) { IndicatorRelease(m_hEmaFast); m_hEmaFast = INVALID_HANDLE; }
      if(m_hEmaSlow != INVALID_HANDLE) { IndicatorRelease(m_hEmaSlow); m_hEmaSlow = INVALID_HANDLE; }
      if(m_hRsi    != INVALID_HANDLE)  { IndicatorRelease(m_hRsi);     m_hRsi = INVALID_HANDLE; }
      if(m_hAtr    != INVALID_HANDLE)  { IndicatorRelease(m_hAtr);     m_hAtr = INVALID_HANDLE; }
      m_initialized = false;
     }
   
   //--- Filter configuration
   void SetSessionFilter(bool use, int startH, int startM, int endH, int endM,
                          bool avoidFriday, int fridayCutoff)
     {
      m_useSession = use; m_sessStartH = startH; m_sessStartM = startM;
      m_sessEndH = endH; m_sessEndM = endM;
      m_avoidFriday = avoidFriday; m_fridayCutoff = fridayCutoff;
     }
   
   void SetSpreadFilter(bool use, int maxSpread)
     { m_useSpread = use; m_maxSpread = maxSpread; }
   
   void SetNewsFilter(bool use, string t1, string t2, string t3, int minsBefore, int minsAfter)
     {
      m_useNews = use;
      m_newsTime[0] = t1; m_newsTime[1] = t2; m_newsTime[2] = t3;
      m_newsMinsBefore = minsBefore; m_newsMinsAfter = minsAfter;
     }
   
   //--- Indicator access
   void GetIndicators(SSspIndicators &out) { out = m_ind; }
   
   //=================================================================
   // UPDATE INDICATORS (call once per new bar)
   //=================================================================
   
   bool UpdateIndicators()
     {
      if(!m_initialized) return false;
      
      int need = MathMax(m_breakoutLookback + 5, m_emaSlowPeriod + 5);
      need = MathMax(need, 10);
      
      if(CopyBuffer(m_hEmaFast, 0, 0, need, m_bufEmaFast) < need) return false;
      if(CopyBuffer(m_hEmaSlow, 0, 0, need, m_bufEmaSlow) < need) return false;
      if(CopyBuffer(m_hRsi, 0, 0, 5, m_bufRsi) < 5)              return false;
      if(CopyBuffer(m_hAtr, 0, 0, 5, m_bufAtr) < 5)              return false;
      
      // Cache values (bar[1] = last completed bar)
      m_ind.emaFast     = m_bufEmaFast[1];
      m_ind.emaSlow     = m_bufEmaSlow[1];
      m_ind.emaFastPrev = m_bufEmaFast[2];
      m_ind.emaSlowPrev = m_bufEmaSlow[2];
      m_ind.rsi         = m_bufRsi[1];
      m_ind.atr         = m_bufAtr[1];
      m_ind.close1      = iClose(_Symbol, PERIOD_CURRENT, 1);
      m_ind.close2      = iClose(_Symbol, PERIOD_CURRENT, 2);
      
      // Breakout levels
      m_ind.highestHigh = 0;
      m_ind.lowestLow   = DBL_MAX;
      for(int i = 2; i <= m_breakoutLookback + 1; i++)
        {
         double h = iHigh(_Symbol, PERIOD_CURRENT, i);
         double l = iLow(_Symbol, PERIOD_CURRENT, i);
         if(h > m_ind.highestHigh) m_ind.highestHigh = h;
         if(l < m_ind.lowestLow)   m_ind.lowestLow = l;
        }
      
      m_ind.valid = true;
      return true;
     }
   
   //=================================================================
   // SIGNAL GENERATION
   //=================================================================
   
   ENUM_SSP_SIGNAL GetSignal()
     {
      if(!m_ind.valid || m_ind.atr <= 0)
         return SSP_SIGNAL_NONE;
      
      // --------------------------------------------------
      // STEP 1: TREND DIRECTION (EMA 50 vs EMA 200)
      // --------------------------------------------------
      bool bullTrend = (m_ind.emaFast > m_ind.emaSlow);
      bool bearTrend = (m_ind.emaFast < m_ind.emaSlow);
      
      // --------------------------------------------------
      // STEP 2: TREND STRENGTH (avoid sideways)
      //   EMAs must be separated by minimum ATR distance
      // --------------------------------------------------
      double separation = MathAbs(m_ind.emaFast - m_ind.emaSlow);
      double minSep = 0;
      switch(m_trendStrength)
        {
         case SSP_TREND_WEAK:     minSep = m_ind.atr * 0.1; break;
         case SSP_TREND_MODERATE: minSep = m_ind.atr * 0.3; break;
         case SSP_TREND_STRONG:   minSep = m_ind.atr * 0.6; break;
        }
      if(separation < minSep)
         return SSP_SIGNAL_NONE;   // Sideways -> skip
      
      // --------------------------------------------------
      // STEP 3: PRICE POSITION (above/below both EMAs)
      // --------------------------------------------------
      bool aboveBoth = (m_ind.close1 > m_ind.emaFast && m_ind.close1 > m_ind.emaSlow);
      bool belowBoth = (m_ind.close1 < m_ind.emaFast && m_ind.close1 < m_ind.emaSlow);
      
      // --------------------------------------------------
      // STEP 4: BREAKOUT DETECTION
      //   Close breaks past N-bar high/low (with buffer)
      // --------------------------------------------------
      double buf = m_ind.atr * m_breakoutBuffer;
      bool bullBreak = (m_ind.close1 > m_ind.highestHigh - buf) && (m_ind.close2 <= m_ind.highestHigh);
      bool bearBreak = (m_ind.close1 < m_ind.lowestLow + buf)   && (m_ind.close2 >= m_ind.lowestLow);
      
      // --------------------------------------------------
      // STEP 5: RSI FILTER
      //   Buy: RSI in healthy uptrend zone (not overbought)
      //   Sell: RSI in healthy downtrend zone (not oversold)
      // --------------------------------------------------
      bool rsiBuy  = (m_ind.rsi >= m_rsiBuyMin  && m_ind.rsi <= m_rsiBuyMax);
      bool rsiSell = (m_ind.rsi >= m_rsiSellMin && m_ind.rsi <= m_rsiSellMax);
      
      // --------------------------------------------------
      // STEP 6: MOMENTUM CONFIRMATION
      //   Close > previous close for buys (and vice versa)
      // --------------------------------------------------
      bool bullMom = (m_ind.close1 > m_ind.close2);
      bool bearMom = (m_ind.close1 < m_ind.close2);
      
      // --------------------------------------------------
      // COMBINE: All 6 conditions must align
      // --------------------------------------------------
      if(bullTrend && aboveBoth && bullBreak && rsiBuy && bullMom)
         return SSP_SIGNAL_BUY;
      
      if(bearTrend && belowBoth && bearBreak && rsiSell && bearMom)
         return SSP_SIGNAL_SELL;
      
      return SSP_SIGNAL_NONE;
     }
   
   //=================================================================
   // FILTERS
   //=================================================================
   
   bool PassSessionFilter()
     {
      if(!m_useSession) return true;
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int cur = dt.hour * 60 + dt.min;
      int st  = m_sessStartH * 60 + m_sessStartM;
      int en  = m_sessEndH * 60 + m_sessEndM;
      
      // Weekend
      if(dt.day_of_week == 0 || dt.day_of_week == 6) return false;
      
      // Friday cutoff
      if(m_avoidFriday && dt.day_of_week == 5 && cur >= m_fridayCutoff * 60) return false;
      
      // Session window
      if(st < en)
        { if(cur < st || cur >= en) return false; }
      else
        { if(cur < st && cur >= en) return false; }
      
      return true;
     }
   
   bool PassSpreadFilter(int currentSpread)
     {
      if(!m_useSpread) return true;
      return currentSpread <= m_maxSpread;
     }
   
   bool PassNewsFilter()
     {
      if(!m_useNews) return true;
      datetime now = TimeCurrent();
      for(int i = 0; i < 3; i++)
         if(IsNearNewsTime(m_newsTime[i], now))
            return false;
      return true;
     }
   
   // Trend direction string
   string GetTrendDirection()
     {
      if(!m_ind.valid) return "N/A";
      if(m_ind.emaFast > m_ind.emaSlow) return "BULLISH";
      if(m_ind.emaFast < m_ind.emaSlow) return "BEARISH";
      return "FLAT";
     }

private:
   bool IsNearNewsTime(string timeStr, datetime now)
     {
      if(timeStr == "" || StringLen(timeStr) < 4) return false;
      int cp = StringFind(timeStr, ":");
      if(cp < 0) return false;
      int nh = (int)StringToInteger(StringSubstr(timeStr, 0, cp));
      int nm = (int)StringToInteger(StringSubstr(timeStr, cp + 1));
      MqlDateTime dtN;
      TimeToStruct(now, dtN);
      dtN.hour = nh; dtN.min = nm; dtN.sec = 0;
      datetime nt = StructToTime(dtN);
      return (now >= nt - m_newsMinsBefore * 60 && now <= nt + m_newsMinsAfter * 60);
     }
  };

#endif // SSP_STRATEGY_MQH
