//+------------------------------------------------------------------+
//|                                                SpreadMonitor.mqh |
//|                                        Copyright 2026, Algosphere |
//|                                      https://algosphere-quant.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Algosphere"
#property link      "https://algosphere-quant.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Enumeration of spread conditions                                 |
//+------------------------------------------------------------------+
enum ENUM_SPREAD_CONDITION
  {
   SPREAD_LOW=0,         // Low Spread (Green)
   SPREAD_NORMAL=1,      // Normal Spread (Yellow)
   SPREAD_HIGH=2,        // High Spread (Orange)
   SPREAD_EXTREME=3      // Extreme Spread (Red)
  };

//+------------------------------------------------------------------+
//| Structure for spread statistics                                  |
//+------------------------------------------------------------------+
struct SSpreadStats
  {
   double            current;          // Current spread in pips
   double            average;          // Average spread in pips
   double            minimum;          // Minimum spread recorded
   double            maximum;          // Maximum spread recorded
   double            std_deviation;    // Standard deviation
   int               sample_count;     // Number of samples
   ENUM_SPREAD_CONDITION condition;    // Current spread condition
  };

//+------------------------------------------------------------------+
//| Class for monitoring and analyzing spread                        |
//+------------------------------------------------------------------+
class CSpreadMonitor
  {
private:
   string            m_symbol;              // Trading symbol
   double            m_spread_history[];    // Spread history array
   int               m_history_size;        // Maximum history size
   int               m_current_index;       // Current index in history
   int               m_sample_count;        // Total samples collected
   double            m_pip_size;            // Pip size for the symbol
   int               m_digits;              // Symbol digits
   
   //--- Threshold settings
   double            m_threshold_low;       // Low spread threshold
   double            m_threshold_normal;    // Normal spread threshold
   double            m_threshold_high;      // High spread threshold
   
   //--- Statistics cache
   double            m_sum;                 // Running sum for average
   double            m_sum_squared;         // Running sum of squares
   double            m_min_spread;          // Minimum spread
   double            m_max_spread;          // Maximum spread
   
   bool              m_initialized;         // Initialization flag

   //--- Private methods
   void              UpdateStatistics(const double spread);
   double            GetCurrentSpreadPips(void);

public:
   //--- Constructor and destructor
                     CSpreadMonitor(void);
                    ~CSpreadMonitor(void);

   //--- Initialization
   bool              Init(const string symbol,
                          const int history_size=1000,
                          const double low_threshold=1.0,
                          const double normal_threshold=2.0,
                          const double high_threshold=5.0);

   //--- Update and recording
   void              Update(void);
   void              RecordSpread(void);

   //--- Spread information methods
   double            GetCurrentSpread(void);
   double            GetAverageSpread(void);
   double            GetMinSpread(void);
   double            GetMaxSpread(void);
   double            GetStdDeviation(void);
   
   //--- Condition methods
   ENUM_SPREAD_CONDITION GetSpreadCondition(void);
   ENUM_SPREAD_CONDITION GetConditionForSpread(const double spread_pips);
   string            GetConditionName(const ENUM_SPREAD_CONDITION condition);
   color             GetConditionColor(const ENUM_SPREAD_CONDITION condition);
   
   //--- Filter methods
   bool              IsSpreadAcceptable(const double max_spread_pips);
   bool              IsSpreadBelowAverage(const double multiplier=1.0);
   bool              IsSpreadStable(const int periods=10,const double tolerance=0.5);
   
   //--- Statistics
   SSpreadStats      GetStatistics(void);
   void              ResetStatistics(void);
   
   //--- Threshold management
   void              SetThresholds(const double low,const double normal,const double high);
   
   //--- Information
   int               GetSampleCount(void)  { return(m_sample_count); }
   double            GetPipSize(void)      { return(m_pip_size); }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSpreadMonitor::CSpreadMonitor(void) : m_symbol(""),
                                       m_history_size(1000),
                                       m_current_index(0),
                                       m_sample_count(0),
                                       m_pip_size(0.0001),
                                       m_digits(5),
                                       m_threshold_low(1.0),
                                       m_threshold_normal(2.0),
                                       m_threshold_high(5.0),
                                       m_sum(0),
                                       m_sum_squared(0),
                                       m_min_spread(DBL_MAX),
                                       m_max_spread(0),
                                       m_initialized(false)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSpreadMonitor::~CSpreadMonitor(void)
  {
   ArrayFree(m_spread_history);
  }

//+------------------------------------------------------------------+
//| Initialize the spread monitor                                    |
//+------------------------------------------------------------------+
bool CSpreadMonitor::Init(const string symbol,
                          const int history_size=1000,
                          const double low_threshold=1.0,
                          const double normal_threshold=2.0,
                          const double high_threshold=5.0)
  {
   m_symbol=symbol;
   m_history_size=history_size;
   
//--- Set thresholds
   m_threshold_low=low_threshold;
   m_threshold_normal=normal_threshold;
   m_threshold_high=high_threshold;
   
//--- Get symbol specifications
   m_digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   
//--- Calculate pip size
   m_pip_size=(m_digits==5 || m_digits==3) ? point*10 : point;
   
   if(m_pip_size==0)
     {
      Print("Error: Invalid pip size for symbol ",symbol);
      return(false);
     }

//--- Initialize history array
   ArrayResize(m_spread_history,m_history_size);
   ArrayInitialize(m_spread_history,0);
   
//--- Reset statistics
   ResetStatistics();
   
   m_initialized=true;
   return(true);
  }

//+------------------------------------------------------------------+
//| Update spread (call on each tick or timer)                       |
//+------------------------------------------------------------------+
void CSpreadMonitor::Update(void)
  {
   if(!m_initialized)
      return;
      
   RecordSpread();
  }

//+------------------------------------------------------------------+
//| Record current spread to history                                 |
//+------------------------------------------------------------------+
void CSpreadMonitor::RecordSpread(void)
  {
   if(!m_initialized)
      return;

   double spread=GetCurrentSpreadPips();
   
//--- Store in circular buffer
   m_spread_history[m_current_index]=spread;
   m_current_index=(m_current_index+1)%m_history_size;
   
//--- Update statistics
   UpdateStatistics(spread);
  }

//+------------------------------------------------------------------+
//| Get current spread in pips (internal)                            |
//+------------------------------------------------------------------+
double CSpreadMonitor::GetCurrentSpreadPips(void)
  {
   double ask=SymbolInfoDouble(m_symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(m_symbol,SYMBOL_BID);
   
   if(ask==0 || bid==0 || m_pip_size==0)
      return(0);
      
   return((ask-bid)/m_pip_size);
  }

//+------------------------------------------------------------------+
//| Update running statistics                                        |
//+------------------------------------------------------------------+
void CSpreadMonitor::UpdateStatistics(const double spread)
  {
   m_sample_count++;
   m_sum+=spread;
   m_sum_squared+=spread*spread;
   
   if(spread<m_min_spread)
      m_min_spread=spread;
   if(spread>m_max_spread)
      m_max_spread=spread;
  }

//+------------------------------------------------------------------+
//| Get current spread in pips                                       |
//+------------------------------------------------------------------+
double CSpreadMonitor::GetCurrentSpread(void)
  {
   return(GetCurrentSpreadPips());
  }

//+------------------------------------------------------------------+
//| Get average spread in pips                                       |
//+------------------------------------------------------------------+
double CSpreadMonitor::GetAverageSpread(void)
  {
   if(m_sample_count==0)
      return(0);
      
   return(m_sum/m_sample_count);
  }

//+------------------------------------------------------------------+
//| Get minimum recorded spread                                      |
//+------------------------------------------------------------------+
double CSpreadMonitor::GetMinSpread(void)
  {
   if(m_min_spread==DBL_MAX)
      return(0);
      
   return(m_min_spread);
  }

//+------------------------------------------------------------------+
//| Get maximum recorded spread                                      |
//+------------------------------------------------------------------+
double CSpreadMonitor::GetMaxSpread(void)
  {
   return(m_max_spread);
  }

//+------------------------------------------------------------------+
//| Get standard deviation of spread                                 |
//+------------------------------------------------------------------+
double CSpreadMonitor::GetStdDeviation(void)
  {
   if(m_sample_count<2)
      return(0);
      
//--- Calculate variance: E[X^2] - E[X]^2
   double mean=m_sum/m_sample_count;
   double variance=(m_sum_squared/m_sample_count)-(mean*mean);
   
   if(variance<0)
      variance=0;
      
   return(MathSqrt(variance));
  }

//+------------------------------------------------------------------+
//| Get current spread condition                                     |
//+------------------------------------------------------------------+
ENUM_SPREAD_CONDITION CSpreadMonitor::GetSpreadCondition(void)
  {
   return(GetConditionForSpread(GetCurrentSpreadPips()));
  }

//+------------------------------------------------------------------+
//| Get condition for specific spread value                          |
//+------------------------------------------------------------------+
ENUM_SPREAD_CONDITION CSpreadMonitor::GetConditionForSpread(const double spread_pips)
  {
   if(spread_pips<=m_threshold_low)
      return(SPREAD_LOW);
   if(spread_pips<=m_threshold_normal)
      return(SPREAD_NORMAL);
   if(spread_pips<=m_threshold_high)
      return(SPREAD_HIGH);
      
   return(SPREAD_EXTREME);
  }

//+------------------------------------------------------------------+
//| Get condition name string                                        |
//+------------------------------------------------------------------+
string CSpreadMonitor::GetConditionName(const ENUM_SPREAD_CONDITION condition)
  {
   switch(condition)
     {
      case SPREAD_LOW:      return("LOW");
      case SPREAD_NORMAL:   return("NORMAL");
      case SPREAD_HIGH:     return("HIGH");
      case SPREAD_EXTREME:  return("EXTREME");
     }
   return("UNKNOWN");
  }

//+------------------------------------------------------------------+
//| Get condition color for display                                  |
//+------------------------------------------------------------------+
color CSpreadMonitor::GetConditionColor(const ENUM_SPREAD_CONDITION condition)
  {
   switch(condition)
     {
      case SPREAD_LOW:      return(clrLime);
      case SPREAD_NORMAL:   return(clrYellow);
      case SPREAD_HIGH:     return(clrOrange);
      case SPREAD_EXTREME:  return(clrRed);
     }
   return(clrWhite);
  }

//+------------------------------------------------------------------+
//| Check if spread is below maximum acceptable                      |
//+------------------------------------------------------------------+
bool CSpreadMonitor::IsSpreadAcceptable(const double max_spread_pips)
  {
   return(GetCurrentSpreadPips()<=max_spread_pips);
  }

//+------------------------------------------------------------------+
//| Check if spread is below average (with multiplier)               |
//+------------------------------------------------------------------+
bool CSpreadMonitor::IsSpreadBelowAverage(const double multiplier=1.0)
  {
   double avg=GetAverageSpread();
   if(avg==0)
      return(true);
      
   return(GetCurrentSpreadPips()<=(avg*multiplier));
  }

//+------------------------------------------------------------------+
//| Check if spread is stable (low variation)                        |
//+------------------------------------------------------------------+
bool CSpreadMonitor::IsSpreadStable(const int periods=10,const double tolerance=0.5)
  {
   if(m_sample_count<periods)
      return(false);

//--- Calculate recent average
   double sum=0;
   int count=0;
   int idx=m_current_index;
   
   for(int i=0; i<periods && i<m_history_size; i++)
     {
      idx=(idx-1+m_history_size)%m_history_size;
      if(m_spread_history[idx]>0)
        {
         sum+=m_spread_history[idx];
         count++;
        }
     }
   
   if(count==0)
      return(false);
      
   double recent_avg=sum/count;
   
//--- Check if current spread is within tolerance of recent average
   double current=GetCurrentSpreadPips();
   double deviation=MathAbs(current-recent_avg);
   
   return(deviation<=tolerance);
  }

//+------------------------------------------------------------------+
//| Get complete statistics structure                                |
//+------------------------------------------------------------------+
SSpreadStats CSpreadMonitor::GetStatistics(void)
  {
   SSpreadStats stats;
   
   stats.current=GetCurrentSpread();
   stats.average=GetAverageSpread();
   stats.minimum=GetMinSpread();
   stats.maximum=GetMaxSpread();
   stats.std_deviation=GetStdDeviation();
   stats.sample_count=m_sample_count;
   stats.condition=GetSpreadCondition();
   
   return(stats);
  }

//+------------------------------------------------------------------+
//| Reset all statistics                                             |
//+------------------------------------------------------------------+
void CSpreadMonitor::ResetStatistics(void)
  {
   m_current_index=0;
   m_sample_count=0;
   m_sum=0;
   m_sum_squared=0;
   m_min_spread=DBL_MAX;
   m_max_spread=0;
   
   ArrayInitialize(m_spread_history,0);
  }

//+------------------------------------------------------------------+
//| Set spread thresholds                                            |
//+------------------------------------------------------------------+
void CSpreadMonitor::SetThresholds(const double low,const double normal,const double high)
  {
   m_threshold_low=low;
   m_threshold_normal=normal;
   m_threshold_high=high;
  }
//+------------------------------------------------------------------+
