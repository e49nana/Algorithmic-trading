//+------------------------------------------------------------------+
//|                                               PositionSizer.mqh |
//|                                        Copyright 2026, Algosphere |
//|                                      https://algosphere-quant.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Algosphere"
#property link      "https://algosphere-quant.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Enumeration of position sizing methods                           |
//+------------------------------------------------------------------+
enum ENUM_LOT_SIZE_METHOD
  {
   LOT_SIZE_FIXED=0,       // Fixed Lot Size
   LOT_SIZE_RISK_PERCENT=1,// Risk Percentage of Balance
   LOT_SIZE_RISK_MONEY=2,  // Fixed Risk Amount
   LOT_SIZE_KELLY=3        // Kelly Criterion
  };

//+------------------------------------------------------------------+
//| Structure for symbol trading specifications                      |
//+------------------------------------------------------------------+
struct SSymbolSpecs
  {
   string            symbol;           // Symbol name
   double            point;            // Point size
   int               digits;           // Price digits
   double            tick_size;        // Tick size
   double            tick_value;       // Tick value in account currency
   double            lot_min;          // Minimum lot size
   double            lot_max;          // Maximum lot size
   double            lot_step;         // Lot step
   double            contract_size;    // Contract size
   int               stops_level;      // Minimum stops level in points
  };

//+------------------------------------------------------------------+
//| Class for calculating position sizes based on risk               |
//+------------------------------------------------------------------+
class CPositionSizer
  {
private:
   SSymbolSpecs      m_specs;          // Symbol specifications
   bool              m_initialized;    // Initialization flag
   string            m_last_error;     // Last error message

   //--- Private methods
   bool              LoadSymbolSpecs(const string symbol);
   double            NormalizeLot(const double lot);

public:
   //--- Constructor and destructor
                     CPositionSizer(void);
                    ~CPositionSizer(void);

   //--- Initialization
   bool              Init(const string symbol);

   //--- Lot calculation methods
   double            CalculateLotSize(const ENUM_LOT_SIZE_METHOD method,
                                      const double risk_value,
                                      const double stop_loss_points,
                                      const double win_rate=0.0,
                                      const double reward_risk_ratio=0.0);

   double            CalculateFixedLot(const double lot);
   double            CalculateRiskPercentLot(const double risk_percent,
                                             const double stop_loss_points);
   double            CalculateRiskMoneyLot(const double risk_money,
                                           const double stop_loss_points);
   double            CalculateKellyLot(const double win_rate,
                                       const double reward_risk_ratio,
                                       const double max_risk_percent=2.0);

   //--- Risk calculation methods
   double            CalculateRiskMoney(const double lot_size,
                                        const double stop_loss_points);
   double            CalculateRiskPercent(const double lot_size,
                                          const double stop_loss_points);

   //--- Utility methods
   double            PointsToPrice(const double points);
   double            PriceToPoints(const double price_distance);
   double            GetPipValue(const double lot_size);

   //--- Information methods
   string            GetLastError(void) { return(m_last_error); }
   double            GetMinLot(void)    { return(m_specs.lot_min); }
   double            GetMaxLot(void)    { return(m_specs.lot_max); }
   double            GetLotStep(void)   { return(m_specs.lot_step); }
   int               GetStopsLevel(void){ return(m_specs.stops_level); }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPositionSizer::CPositionSizer(void) : m_initialized(false),
                                       m_last_error("")
  {
   ZeroMemory(m_specs);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPositionSizer::~CPositionSizer(void)
  {
  }

//+------------------------------------------------------------------+
//| Initialize with symbol specifications                            |
//+------------------------------------------------------------------+
bool CPositionSizer::Init(const string symbol)
  {
   m_last_error="";

//--- Load symbol specifications
   if(!LoadSymbolSpecs(symbol))
      return(false);

   m_initialized=true;
   return(true);
  }

//+------------------------------------------------------------------+
//| Load symbol trading specifications from broker                   |
//+------------------------------------------------------------------+
bool CPositionSizer::LoadSymbolSpecs(const string symbol)
  {
//--- Verify symbol exists
   if(!SymbolSelect(symbol,true))
     {
      m_last_error="Symbol not found: "+symbol;
      return(false);
     }

//--- Load specifications
   m_specs.symbol=symbol;
   m_specs.point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   m_specs.digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   m_specs.tick_size=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   m_specs.tick_value=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);
   m_specs.lot_min=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   m_specs.lot_max=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   m_specs.lot_step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
   m_specs.contract_size=SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE);
   m_specs.stops_level=(int)SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);

//--- Validate critical values
   if(m_specs.point==0 || m_specs.tick_value==0)
     {
      m_last_error="Invalid symbol specifications for: "+symbol;
      return(false);
     }

   return(true);
  }

//+------------------------------------------------------------------+
//| Normalize lot size to broker requirements                        |
//+------------------------------------------------------------------+
double CPositionSizer::NormalizeLot(const double lot)
  {
//--- Apply lot step
   double normalized=MathFloor(lot/m_specs.lot_step)*m_specs.lot_step;

//--- Apply min/max limits
   if(normalized<m_specs.lot_min)
      normalized=m_specs.lot_min;
   if(normalized>m_specs.lot_max)
      normalized=m_specs.lot_max;

//--- Round to lot step precision
   int lot_digits=(int)MathMax(-MathLog10(m_specs.lot_step),0);
   normalized=NormalizeDouble(normalized,lot_digits);

   return(normalized);
  }

//+------------------------------------------------------------------+
//| Universal lot calculation method                                 |
//+------------------------------------------------------------------+
double CPositionSizer::CalculateLotSize(const ENUM_LOT_SIZE_METHOD method,
                                        const double risk_value,
                                        const double stop_loss_points,
                                        const double win_rate=0.0,
                                        const double reward_risk_ratio=0.0)
  {
   if(!m_initialized)
     {
      m_last_error="Position sizer not initialized";
      return(0.0);
     }

   double lot=0.0;

   switch(method)
     {
      case LOT_SIZE_FIXED:
         lot=CalculateFixedLot(risk_value);
         break;
      case LOT_SIZE_RISK_PERCENT:
         lot=CalculateRiskPercentLot(risk_value,stop_loss_points);
         break;
      case LOT_SIZE_RISK_MONEY:
         lot=CalculateRiskMoneyLot(risk_value,stop_loss_points);
         break;
      case LOT_SIZE_KELLY:
         lot=CalculateKellyLot(win_rate,reward_risk_ratio,risk_value);
         break;
     }

   return(lot);
  }

//+------------------------------------------------------------------+
//| Calculate fixed lot size (with normalization)                    |
//+------------------------------------------------------------------+
double CPositionSizer::CalculateFixedLot(const double lot)
  {
   if(!m_initialized)
     {
      m_last_error="Position sizer not initialized";
      return(0.0);
     }

   return(NormalizeLot(lot));
  }

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage of account balance  |
//+------------------------------------------------------------------+
double CPositionSizer::CalculateRiskPercentLot(const double risk_percent,
                                               const double stop_loss_points)
  {
   if(!m_initialized)
     {
      m_last_error="Position sizer not initialized";
      return(0.0);
     }

//--- Validate inputs
   if(risk_percent<=0 || risk_percent>100)
     {
      m_last_error="Invalid risk percent: must be between 0 and 100";
      return(0.0);
     }

   if(stop_loss_points<=0)
     {
      m_last_error="Invalid stop loss: must be greater than 0";
      return(0.0);
     }

//--- Get account balance
   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance<=0)
     {
      m_last_error="Invalid account balance";
      return(0.0);
     }

//--- Calculate risk amount in account currency
   double risk_money=balance*(risk_percent/100.0);

//--- Calculate lot size
   return(CalculateRiskMoneyLot(risk_money,stop_loss_points));
  }

//+------------------------------------------------------------------+
//| Calculate lot size based on fixed risk amount in account currency|
//+------------------------------------------------------------------+
double CPositionSizer::CalculateRiskMoneyLot(const double risk_money,
                                             const double stop_loss_points)
  {
   if(!m_initialized)
     {
      m_last_error="Position sizer not initialized";
      return(0.0);
     }

//--- Validate inputs
   if(risk_money<=0)
     {
      m_last_error="Invalid risk amount: must be greater than 0";
      return(0.0);
     }

   if(stop_loss_points<=0)
     {
      m_last_error="Invalid stop loss: must be greater than 0";
      return(0.0);
     }

//--- Calculate value per point for 1 lot
   double point_value=m_specs.tick_value*(m_specs.point/m_specs.tick_size);

//--- Calculate lot size: risk_money / (stop_loss_points * point_value)
   double lot=risk_money/(stop_loss_points*point_value);

   return(NormalizeLot(lot));
  }

//+------------------------------------------------------------------+
//| Calculate lot size using Kelly Criterion                         |
//+------------------------------------------------------------------+
double CPositionSizer::CalculateKellyLot(const double win_rate,
                                         const double reward_risk_ratio,
                                         const double max_risk_percent=2.0)
  {
   if(!m_initialized)
     {
      m_last_error="Position sizer not initialized";
      return(0.0);
     }

//--- Validate inputs
   if(win_rate<=0 || win_rate>=1)
     {
      m_last_error="Invalid win rate: must be between 0 and 1";
      return(0.0);
     }

   if(reward_risk_ratio<=0)
     {
      m_last_error="Invalid reward/risk ratio: must be greater than 0";
      return(0.0);
     }

//--- Kelly formula: f* = (bp - q) / b
//--- Where: b = reward/risk ratio, p = win rate, q = loss rate (1-p)
   double b=reward_risk_ratio;
   double p=win_rate;
   double q=1.0-p;

   double kelly_percent=(b*p-q)/b;

//--- Apply half-Kelly for safety
   kelly_percent=kelly_percent*0.5;

//--- Cap at maximum risk percent
   if(kelly_percent>max_risk_percent/100.0)
      kelly_percent=max_risk_percent/100.0;

//--- If Kelly is negative, don't trade
   if(kelly_percent<=0)
     {
      m_last_error="Kelly criterion negative: unfavorable risk/reward";
      return(0.0);
     }

//--- Return as percentage for use with CalculateRiskPercentLot
   return(kelly_percent*100.0);
  }

//+------------------------------------------------------------------+
//| Calculate risk in account currency for given lot and stop loss   |
//+------------------------------------------------------------------+
double CPositionSizer::CalculateRiskMoney(const double lot_size,
                                          const double stop_loss_points)
  {
   if(!m_initialized)
     {
      m_last_error="Position sizer not initialized";
      return(0.0);
     }

   if(lot_size<=0 || stop_loss_points<=0)
      return(0.0);

//--- Calculate value per point for 1 lot
   double point_value=m_specs.tick_value*(m_specs.point/m_specs.tick_size);

//--- Calculate total risk
   double risk=lot_size*stop_loss_points*point_value;

   return(NormalizeDouble(risk,2));
  }

//+------------------------------------------------------------------+
//| Calculate risk as percentage of account balance                  |
//+------------------------------------------------------------------+
double CPositionSizer::CalculateRiskPercent(const double lot_size,
                                            const double stop_loss_points)
  {
   if(!m_initialized)
     {
      m_last_error="Position sizer not initialized";
      return(0.0);
     }

//--- Get risk in money
   double risk_money=CalculateRiskMoney(lot_size,stop_loss_points);
   if(risk_money<=0)
      return(0.0);

//--- Get account balance
   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance<=0)
      return(0.0);

//--- Calculate percentage
   double risk_percent=(risk_money/balance)*100.0;

   return(NormalizeDouble(risk_percent,2));
  }

//+------------------------------------------------------------------+
//| Convert points to price distance                                 |
//+------------------------------------------------------------------+
double CPositionSizer::PointsToPrice(const double points)
  {
   if(!m_initialized)
      return(0.0);

   return(points*m_specs.point);
  }

//+------------------------------------------------------------------+
//| Convert price distance to points                                 |
//+------------------------------------------------------------------+
double CPositionSizer::PriceToPoints(const double price_distance)
  {
   if(!m_initialized || m_specs.point==0)
      return(0.0);

   return(price_distance/m_specs.point);
  }

//+------------------------------------------------------------------+
//| Get pip value for given lot size                                 |
//+------------------------------------------------------------------+
double CPositionSizer::GetPipValue(const double lot_size)
  {
   if(!m_initialized)
      return(0.0);

//--- Calculate pip size (10 points for 5-digit, 1 point for 4-digit)
   double pip_points=(m_specs.digits==5 || m_specs.digits==3) ? 10.0 : 1.0;

//--- Calculate value per point for 1 lot
   double point_value=m_specs.tick_value*(m_specs.point/m_specs.tick_size);

//--- Return pip value
   return(lot_size*pip_points*point_value);
  }
//+------------------------------------------------------------------+
