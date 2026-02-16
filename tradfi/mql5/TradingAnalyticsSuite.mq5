//+------------------------------------------------------------------+
//|                                        TradingAnalyticsSuite.mq5 |
//|                        Copyright 2025, AnaCristina Trading Ltd.  |
//|                                   https://www.anacristina.trading |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, AnaCristina Trading Ltd."
#property link      "https://www.anacristina.trading"
#property version   "2.00"
#property description "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
#property description "      TRADING ANALYTICS SUITE v2.0"
#property description "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
#property description "Comprehensive trading performance analytics with"
#property description "risk metrics, position sizing, equity analysis,"
#property description "and professional-grade statistical measures."
#property description " "
#property description "For automated risk management: AnaCristina EA"
#property indicator_chart_window
#property indicator_plots 0

//+------------------------------------------------------------------+
//| CONSTANTS                                                         |
//+------------------------------------------------------------------+
#define MAX_TRADES       1000
#define RISK_FREE_RATE   0.02   // 2% annual

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                      |
//+------------------------------------------------------------------+
enum ENUM_ANALYSIS_PERIOD
{
   PERIOD_ALL          = 0,    // All History
   PERIOD_THIS_YEAR    = 1,    // This Year
   PERIOD_LAST_6M      = 2,    // Last 6 Months
   PERIOD_LAST_3M      = 3,    // Last 3 Months
   PERIOD_LAST_MONTH   = 4,    // Last Month
   PERIOD_THIS_WEEK    = 5     // This Week
};

enum ENUM_PANEL_STYLE
{
   STYLE_DARK          = 0,    // Dark Theme
   STYLE_LIGHT         = 1,    // Light Theme
   STYLE_MIDNIGHT      = 2,    // Midnight Blue
   STYLE_FOREST        = 3     // Forest Green
};

enum ENUM_METRICS_VIEW
{
   VIEW_OVERVIEW       = 0,    // Overview
   VIEW_RISK           = 1,    // Risk Metrics
   VIEW_PERFORMANCE    = 2,    // Performance
   VIEW_SIZING         = 3     // Position Sizing
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input string               _H1_ = ""; // ━━━━━━━━━━━━ ANALYSIS SETTINGS ━━━━━━━━━━━━
input ENUM_ANALYSIS_PERIOD InpPeriod            = PERIOD_ALL;         // Analysis Period
input ulong                InpMagicNumber       = 0;                  // Magic Number (0=all)
input string               InpSymbolFilter      = "";                 // Symbol Filter (empty=current)
input bool                 InpIncludeCommission = true;               // Include Commission/Swap

input string               _H2_ = ""; // ━━━━━━━━━━━━ DISPLAY SETTINGS ━━━━━━━━━━━━
input ENUM_PANEL_STYLE     InpStyle             = STYLE_DARK;         // Panel Theme
input ENUM_BASE_CORNER     InpCorner            = CORNER_RIGHT_UPPER; // Panel Corner
input int                  InpXOffset           = 20;                 // X Offset
input int                  InpYOffset           = 50;                 // Y Offset
input bool                 InpShowEquityCurve   = true;               // Show Mini Equity Curve
input bool                 InpShowDistribution  = true;               // Show Win/Loss Distribution

input string               _H3_ = ""; // ━━━━━━━━━━━━ POSITION SIZING ━━━━━━━━━━━━
input double               InpRiskPercent       = 1.0;                // Default Risk %
input double               InpDefaultStopPips   = 20.0;               // Default Stop Loss (pips)

input string               _THEME_ = ""; // ══════════════ CHART THEME ══════════════
input bool                 InpApplyChartTheme   = true;                // Apply Chart Theme
input color                InpBackgroundColor   = C'15,15,25';         // Background Color
input color                InpForegroundColor   = C'120,120,140';      // Foreground (Text) Color
input color                InpGridColor         = C'30,30,45';         // Grid Color
input color                InpBullCandleColor   = C'0,200,120';        // Bullish Candle Color
input color                InpBearCandleColor   = C'220,60,80';        // Bearish Candle Color
input color                InpBullWickColor     = C'0,180,100';        // Bullish Wick Color  
input color                InpBearWickColor     = C'200,50,70';        // Bearish Wick Color
input color                InpChartLineColor    = C'80,180,220';       // Chart Line Color (for line charts)
input color                InpVolumeUpColor     = C'0,180,120';        // Volume Up Color
input color                InpVolumeDownColor   = C'200,60,80';        // Volume Down Color
input color                InpBidLineColor      = C'80,120,200';       // Bid Price Line
input color                InpAskLineColor      = C'200,100,80';       // Ask Price Line


//+------------------------------------------------------------------+
//| STRUCTURES                                                        |
//+------------------------------------------------------------------+
struct STrade
{
   ulong             ticket;
   datetime          openTime;
   datetime          closeTime;
   string            symbol;
   double            lots;
   double            profit;
   double            commission;
   double            swap;
   double            netProfit;
   bool              isWin;
   double            pips;
};

struct SMetrics
{
   // Basic
   int               totalTrades;
   int               wins;
   int               losses;
   double            winRate;
   
   // Profit/Loss
   double            grossProfit;
   double            grossLoss;
   double            netProfit;
   double            profitFactor;
   double            avgWin;
   double            avgLoss;
   double            largestWin;
   double            largestLoss;
   
   // Expectancy
   double            expectancy;
   double            expectancyPct;
   double            payoffRatio;
   
   // Risk Metrics
   double            maxDrawdown;
   double            maxDrawdownPct;
   double            avgDrawdown;
   double            recoveryFactor;
   double            ulcerIndex;
   
   // Risk-Adjusted
   double            sharpeRatio;
   double            sortinoRatio;
   double            calmarRatio;
   double            sqn;
   
   // Position Sizing
   double            kellyPercent;
   double            optimalF;
   double            safeF;
   
   // Streaks
   int               maxWinStreak;
   int               maxLossStreak;
   int               currentStreak;
   bool              onWinStreak;
   
   // Time Analysis
   double            avgTradeDuration;
   double            avgWinDuration;
   double            avgLossDuration;
   double            profitPerDay;
   int               tradingDays;
   
   // Distribution
   int               profitDistribution[10];  // -50+, -40-50, ... 40-50, 50+
};

struct SStyle
{
   color             bgPrimary;
   color             bgSecondary;
   color             bgTertiary;
   color             border;
   color             textPrimary;
   color             textSecondary;
   color             textMuted;
   color             success;
   color             successLight;
   color             warning;
   color             danger;
   color             dangerLight;
   color             info;
   color             accent;
};

//+------------------------------------------------------------------+
//| CLASS: CTradingAnalytics                                          |
//+------------------------------------------------------------------+
class CTradingAnalytics
{
private:
   string            m_prefix;
   SStyle            m_style;
   SMetrics          m_metrics;
   STrade            m_trades[];
   
   int               m_panelX;
   int               m_panelY;
   int               m_panelWidth;
   int               m_panelHeight;
   
   double            m_equityHistory[];
   datetime          m_lastUpdate;
   
public:
                     CTradingAnalytics();
                    ~CTradingAnalytics();
   
   void              Initialize();
   void              Update();
   void              Destroy();
   
private:
   void              LoadStyle();
   void              LoadTradeHistory();
   void              CalculateMetrics();
   void              CalculateRiskMetrics();
   void              CalculatePositionSizing();
   void              BuildEquityHistory();
   void              DrawPanel();
   void              DrawMetricsSection(int &y);
   void              DrawRiskSection(int &y);
   void              DrawSizingSection(int &y);
   void              DrawMiniEquityCurve(int x, int y, int width, int height);
   void              DrawDistributionBars(int x, int y, int width, int height);
   
   string            FormatNumber(double value, int decimals=2);
   string            FormatPercent(double value, int decimals=1);
   string            FormatCurrency(double value);
   string            GetSQNRating(double sqn);
   color             GetSQNColor(double sqn);
   color             GetValueColor(double value, double neutral=0);
   datetime          GetPeriodStart();
   
   void              CreateRect(string name, int x, int y, int w, int h, color bg, color brd);
   void              CreateLabel(string name, int x, int y, string text, color clr, int size, bool bold=false);
   void              CreateProgressBar(string name, int x, int y, int w, int h, double pct, color barClr, color bgClr);
};

//+------------------------------------------------------------------+
CTradingAnalytics::CTradingAnalytics()
{
   m_prefix = "TAS_";
   m_panelWidth = 340;
   m_panelHeight = InpShowEquityCurve ? 520 : 440;
   m_lastUpdate = 0;
}

CTradingAnalytics::~CTradingAnalytics()
{
   Destroy();
}

void CTradingAnalytics::Initialize()
{
   LoadStyle();
   
   m_panelX = InpXOffset;
   m_panelY = InpYOffset;
   
   // Adjust for corner
   if(InpCorner == CORNER_RIGHT_UPPER || InpCorner == CORNER_RIGHT_LOWER)
   {
      int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      m_panelX = chartWidth - m_panelWidth - InpXOffset;
   }
   
   LoadTradeHistory();
   CalculateMetrics();
   DrawPanel();
}

void CTradingAnalytics::Destroy()
{
   ObjectsDeleteAll(0, m_prefix);
}

void CTradingAnalytics::LoadStyle()
{
   switch(InpStyle)
   {
      case STYLE_LIGHT:
         m_style.bgPrimary    = C'252,252,254';
         m_style.bgSecondary  = C'242,242,247';
         m_style.bgTertiary   = C'232,232,240';
         m_style.border       = C'210,210,220';
         m_style.textPrimary  = C'28,28,30';
         m_style.textSecondary= C'60,60,67';
         m_style.textMuted    = C'142,142,147';
         m_style.success      = C'52,199,89';
         m_style.successLight = C'200,240,210';
         m_style.warning      = C'255,149,0';
         m_style.danger       = C'255,59,48';
         m_style.dangerLight  = C'255,220,220';
         m_style.info         = C'0,122,255';
         m_style.accent       = C'88,86,214';
         break;
         
      case STYLE_MIDNIGHT:
         m_style.bgPrimary    = C'10,25,47';
         m_style.bgSecondary  = C'20,40,70';
         m_style.bgTertiary   = C'30,55,95';
         m_style.border       = C'50,80,130';
         m_style.textPrimary  = C'230,235,245';
         m_style.textSecondary= C'180,195,220';
         m_style.textMuted    = C'120,140,175';
         m_style.success      = C'80,220,140';
         m_style.successLight = C'30,80,60';
         m_style.warning      = C'255,200,60';
         m_style.danger       = C'255,100,100';
         m_style.dangerLight  = C'80,40,40';
         m_style.info         = C'100,180,255';
         m_style.accent       = C'140,120,255';
         break;
         
      case STYLE_FOREST:
         m_style.bgPrimary    = C'15,30,20';
         m_style.bgSecondary  = C'25,50,35';
         m_style.bgTertiary   = C'35,70,50';
         m_style.border       = C'60,100,75';
         m_style.textPrimary  = C'230,245,235';
         m_style.textSecondary= C'180,210,190';
         m_style.textMuted    = C'120,155,135';
         m_style.success      = C'100,230,130';
         m_style.successLight = C'40,80,55';
         m_style.warning      = C'255,210,80';
         m_style.danger       = C'255,110,90';
         m_style.dangerLight  = C'80,50,45';
         m_style.info         = C'100,200,180';
         m_style.accent       = C'150,220,180';
         break;
         
      case STYLE_DARK:
      default:
         m_style.bgPrimary    = C'17,17,22';
         m_style.bgSecondary  = C'26,26,34';
         m_style.bgTertiary   = C'36,36,46';
         m_style.border       = C'55,55,70';
         m_style.textPrimary  = C'245,245,250';
         m_style.textSecondary= C'185,185,200';
         m_style.textMuted    = C'115,115,135';
         m_style.success      = C'52,211,153';
         m_style.successLight = C'30,70,55';
         m_style.warning      = C'251,191,36';
         m_style.danger       = C'248,113,113';
         m_style.dangerLight  = C'70,40,40';
         m_style.info         = C'96,165,250';
         m_style.accent       = C'167,139,250';
         break;
   }
}

datetime CTradingAnalytics::GetPeriodStart()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   
   switch(InpPeriod)
   {
      case PERIOD_THIS_YEAR:
         dt.mon = 1;
         dt.day = 1;
         dt.hour = 0;
         dt.min = 0;
         dt.sec = 0;
         return StructToTime(dt);
         
      case PERIOD_LAST_6M:
         return now - 180 * 24 * 3600;
         
      case PERIOD_LAST_3M:
         return now - 90 * 24 * 3600;
         
      case PERIOD_LAST_MONTH:
         return now - 30 * 24 * 3600;
         
      case PERIOD_THIS_WEEK:
         return now - dt.day_of_week * 24 * 3600;
         
      case PERIOD_ALL:
      default:
         return 0;
   }
}

void CTradingAnalytics::LoadTradeHistory()
{
   ArrayResize(m_trades, 0);
   
   datetime startDate = GetPeriodStart();
   if(!HistorySelect(startDate, TimeCurrent()))
   {
      Print("Failed to load trade history");
      return;
   }
   
   string symbolFilter = (InpSymbolFilter == "") ? _Symbol : InpSymbolFilter;
   if(InpSymbolFilter == "ALL") symbolFilter = "";
   
   int total = HistoryDealsTotal();
   
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      
      ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
      if(dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL) continue;
      
      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) continue;
      
      if(InpMagicNumber > 0)
      {
         ulong magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
         if(magic != InpMagicNumber) continue;
      }
      
      if(symbolFilter != "")
      {
         string dealSymbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
         if(dealSymbol != symbolFilter) continue;
      }
      
      STrade trade;
      trade.ticket = ticket;
      trade.closeTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      trade.symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
      trade.lots = HistoryDealGetDouble(ticket, DEAL_VOLUME);
      trade.profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      trade.commission = InpIncludeCommission ? HistoryDealGetDouble(ticket, DEAL_COMMISSION) : 0;
      trade.swap = InpIncludeCommission ? HistoryDealGetDouble(ticket, DEAL_SWAP) : 0;
      trade.netProfit = trade.profit + trade.commission + trade.swap;
      trade.isWin = (trade.netProfit > 0);
      
      int size = ArraySize(m_trades);
      if(size >= MAX_TRADES) break;
      
      ArrayResize(m_trades, size + 1);
      m_trades[size] = trade;
   }
}

void CTradingAnalytics::CalculateMetrics()
{
   ZeroMemory(m_metrics);
   ArrayInitialize(m_metrics.profitDistribution, 0);
   
   int tradeCount = ArraySize(m_trades);
   if(tradeCount == 0) return;
   
   m_metrics.totalTrades = tradeCount;
   m_metrics.largestWin = 0;
   m_metrics.largestLoss = 0;
   
   // Build equity curve and calculate basic metrics
   ArrayResize(m_equityHistory, tradeCount + 1);
   double equity = 10000;  // Base for calculations
   m_equityHistory[0] = equity;
   
   double peak = equity;
   double maxDD = 0;
   double totalDD = 0;
   int ddCount = 0;
   double sumSquaredDD = 0;
   
   int winStreak = 0, lossStreak = 0;
   int maxWin = 0, maxLoss = 0;
   
   datetime firstTrade = m_trades[0].closeTime;
   datetime lastTrade = m_trades[tradeCount-1].closeTime;
   
   for(int i = 0; i < tradeCount; i++)
   {
      double profit = m_trades[i].netProfit;
      m_metrics.netProfit += profit;
      
      if(profit > 0)
      {
         m_metrics.wins++;
         m_metrics.grossProfit += profit;
         if(profit > m_metrics.largestWin) m_metrics.largestWin = profit;
         
         winStreak++;
         lossStreak = 0;
         if(winStreak > maxWin) maxWin = winStreak;
      }
      else if(profit < 0)
      {
         m_metrics.losses++;
         m_metrics.grossLoss += MathAbs(profit);
         if(profit < m_metrics.largestLoss) m_metrics.largestLoss = profit;
         
         lossStreak++;
         winStreak = 0;
         if(lossStreak > maxLoss) maxLoss = lossStreak;
      }
      
      // Update equity curve
      equity += profit;
      m_equityHistory[i + 1] = equity;
      
      // Track drawdown
      if(equity > peak) peak = equity;
      double dd = (peak - equity) / peak * 100;
      if(dd > maxDD) maxDD = dd;
      if(dd > 0)
      {
         totalDD += dd;
         sumSquaredDD += dd * dd;
         ddCount++;
      }
      
      // Distribution buckets
      double pctChange = profit / 10000 * 100;  // Relative to base
      int bucket = 4 + (int)(pctChange / 10);
      bucket = MathMax(0, MathMin(9, bucket));
      m_metrics.profitDistribution[bucket]++;
   }
   
   // Basic ratios
   m_metrics.winRate = (tradeCount > 0) ? (double)m_metrics.wins / tradeCount * 100 : 0;
   m_metrics.profitFactor = (m_metrics.grossLoss > 0) ? m_metrics.grossProfit / m_metrics.grossLoss : 0;
   m_metrics.avgWin = (m_metrics.wins > 0) ? m_metrics.grossProfit / m_metrics.wins : 0;
   m_metrics.avgLoss = (m_metrics.losses > 0) ? m_metrics.grossLoss / m_metrics.losses : 0;
   
   // Expectancy
   double pWin = m_metrics.winRate / 100;
   double pLoss = 1 - pWin;
   m_metrics.expectancy = (pWin * m_metrics.avgWin) - (pLoss * m_metrics.avgLoss);
   m_metrics.expectancyPct = m_metrics.expectancy / 10000 * 100;  // As % of base
   m_metrics.payoffRatio = (m_metrics.avgLoss > 0) ? m_metrics.avgWin / m_metrics.avgLoss : 0;
   
   // Drawdown metrics
   m_metrics.maxDrawdown = maxDD;
   m_metrics.maxDrawdownPct = maxDD;
   m_metrics.avgDrawdown = (ddCount > 0) ? totalDD / ddCount : 0;
   m_metrics.ulcerIndex = (ddCount > 0) ? MathSqrt(sumSquaredDD / ddCount) : 0;
   m_metrics.recoveryFactor = (maxDD > 0) ? (m_metrics.netProfit / 10000 * 100) / maxDD : 0;
   
   // Streaks
   m_metrics.maxWinStreak = maxWin;
   m_metrics.maxLossStreak = maxLoss;
   m_metrics.currentStreak = (winStreak > 0) ? winStreak : -lossStreak;
   m_metrics.onWinStreak = (winStreak > 0);
   
   // Trading days
   m_metrics.tradingDays = (int)((lastTrade - firstTrade) / (24 * 3600)) + 1;
   m_metrics.profitPerDay = (m_metrics.tradingDays > 0) ? m_metrics.netProfit / m_metrics.tradingDays : 0;
   
   CalculateRiskMetrics();
   CalculatePositionSizing();
}

void CTradingAnalytics::CalculateRiskMetrics()
{
   int tradeCount = ArraySize(m_trades);
   if(tradeCount < 2) return;
   
   // Calculate returns
   double returns[];
   ArrayResize(returns, tradeCount);
   
   double sumReturn = 0;
   double sumNegReturn = 0;
   int negCount = 0;
   
   for(int i = 0; i < tradeCount; i++)
   {
      returns[i] = m_trades[i].netProfit / 10000 * 100;  // % return
      sumReturn += returns[i];
      
      if(returns[i] < 0)
      {
         sumNegReturn += returns[i] * returns[i];
         negCount++;
      }
   }
   
   double avgReturn = sumReturn / tradeCount;
   
   // Standard deviation
   double sumSqDiff = 0;
   for(int i = 0; i < tradeCount; i++)
   {
      double diff = returns[i] - avgReturn;
      sumSqDiff += diff * diff;
   }
   double stdDev = MathSqrt(sumSqDiff / tradeCount);
   
   // Downside deviation
   double downsideDev = (negCount > 0) ? MathSqrt(sumNegReturn / negCount) : 0;
   
   // Risk-adjusted ratios
   double riskFreeDaily = RISK_FREE_RATE / 252;
   
   m_metrics.sharpeRatio = (stdDev > 0) ? (avgReturn - riskFreeDaily) / stdDev : 0;
   m_metrics.sortinoRatio = (downsideDev > 0) ? (avgReturn - riskFreeDaily) / downsideDev : 0;
   
   // Annualized Calmar
   double annualizedReturn = avgReturn * 252;
   m_metrics.calmarRatio = (m_metrics.maxDrawdownPct > 0) ? annualizedReturn / m_metrics.maxDrawdownPct : 0;
   
   // SQN
   if(stdDev > 0)
      m_metrics.sqn = MathSqrt((double)tradeCount) * (avgReturn / stdDev);
}

void CTradingAnalytics::CalculatePositionSizing()
{
   // Kelly Criterion
   double pWin = m_metrics.winRate / 100;
   double pLoss = 1 - pWin;
   
   if(m_metrics.payoffRatio > 0 && pLoss > 0)
   {
      m_metrics.kellyPercent = (pWin - (pLoss / m_metrics.payoffRatio)) * 100;
      m_metrics.kellyPercent = MathMax(0, m_metrics.kellyPercent);
   }
   
   // Optimal f (simplified)
   if(m_metrics.largestLoss < 0)
   {
      m_metrics.optimalF = m_metrics.expectancy / MathAbs(m_metrics.largestLoss) * 100;
      m_metrics.optimalF = MathMax(0, MathMin(100, m_metrics.optimalF));
   }
   
   // Safe f (half Kelly)
   m_metrics.safeF = m_metrics.kellyPercent / 2;
}

void CTradingAnalytics::Update()
{
   datetime now = TimeCurrent();
   
   // Refresh data every 30 seconds
   if(now - m_lastUpdate >= 30)
   {
      LoadTradeHistory();
      CalculateMetrics();
      m_lastUpdate = now;
   }
   
   DrawPanel();
   ChartRedraw();
}

void CTradingAnalytics::DrawPanel()
{
   // Main panel
   CreateRect("Main", m_panelX, m_panelY, m_panelWidth, m_panelHeight, m_style.bgPrimary, m_style.border);
   
   // Header
   CreateRect("Header", m_panelX, m_panelY, m_panelWidth, 48, m_style.bgSecondary, m_style.border);
   CreateLabel("Title", m_panelX+16, m_panelY+10, "TRADING ANALYTICS", m_style.textPrimary, 12, true);
   
   // Trade count badge
   string countText = IntegerToString(m_metrics.totalTrades) + " trades";
   CreateLabel("TradeCount", m_panelX+16, m_panelY+28, countText, m_style.textMuted, 9, false);
   
   // SQN badge
   string sqnText = "SQN: " + DoubleToString(m_metrics.sqn, 2);
   CreateRect("SQN_Badge", m_panelX+m_panelWidth-90, m_panelY+12, 75, 24, m_style.bgTertiary, m_style.border);
   CreateLabel("SQN", m_panelX+m_panelWidth-80, m_panelY+17, sqnText, GetSQNColor(m_metrics.sqn), 9, true);
   
   int y = m_panelY + 58;
   
   // Check for no data
   if(m_metrics.totalTrades == 0)
   {
      CreateLabel("NoData", m_panelX+m_panelWidth/2-60, m_panelY+m_panelHeight/2-20, 
                  "No trades found", m_style.textMuted, 11, false);
      CreateLabel("NoData2", m_panelX+m_panelWidth/2-80, m_panelY+m_panelHeight/2+5, 
                  "Adjust filters or trade more", m_style.textMuted, 9, false);
      return;
   }
   
   // Sections
   DrawMetricsSection(y);
   DrawRiskSection(y);
   DrawSizingSection(y);
   
   // Mini equity curve
   if(InpShowEquityCurve)
   {
      y += 10;
      CreateLabel("EC_Title", m_panelX+16, y, "EQUITY CURVE", m_style.textMuted, 8, false);
      y += 16;
      DrawMiniEquityCurve(m_panelX+16, y, m_panelWidth-32, 60);
      y += 70;
   }
   
   // Distribution
   if(InpShowDistribution)
   {
      CreateLabel("Dist_Title", m_panelX+16, y, "P/L DISTRIBUTION", m_style.textMuted, 8, false);
      y += 16;
      DrawDistributionBars(m_panelX+16, y, m_panelWidth-32, 30);
   }
}

void CTradingAnalytics::DrawMetricsSection(int &y)
{
   CreateLabel("M_Title", m_panelX+16, y, "PERFORMANCE", m_style.textMuted, 8, false);
   y += 16;
   
   CreateRect("M_BG", m_panelX+10, y, m_panelWidth-20, 85, m_style.bgSecondary, m_style.border);
   y += 10;
   
   int col1 = m_panelX + 20;
   int col2 = m_panelX + m_panelWidth/2 + 10;
   int rowH = 18;
   
   // Win Rate
   CreateLabel("M_WR_L", col1, y, "Win Rate", m_style.textMuted, 8, false);
   string wrText = FormatPercent(m_metrics.winRate);
   color wrColor = (m_metrics.winRate >= 50) ? m_style.success : m_style.danger;
   CreateLabel("M_WR_V", col1, y+12, wrText, wrColor, 10, true);
   
   // Profit Factor
   CreateLabel("M_PF_L", col2, y, "Profit Factor", m_style.textMuted, 8, false);
   color pfColor = (m_metrics.profitFactor >= 1.5) ? m_style.success : 
                   (m_metrics.profitFactor >= 1.0) ? m_style.warning : m_style.danger;
   CreateLabel("M_PF_V", col2, y+12, FormatNumber(m_metrics.profitFactor), pfColor, 10, true);
   
   y += rowH + 16;
   
   // Net Profit
   CreateLabel("M_NP_L", col1, y, "Net Profit", m_style.textMuted, 8, false);
   CreateLabel("M_NP_V", col1, y+12, FormatCurrency(m_metrics.netProfit), GetValueColor(m_metrics.netProfit), 10, true);
   
   // Expectancy
   CreateLabel("M_EX_L", col2, y, "Expectancy", m_style.textMuted, 8, false);
   string exText = FormatCurrency(m_metrics.expectancy) + "/trade";
   CreateLabel("M_EX_V", col2, y+12, exText, GetValueColor(m_metrics.expectancy), 10, true);
   
   y += rowH + 20;
   
   // Payoff ratio bar
   CreateLabel("M_PR_L", m_panelX+20, y, "Payoff Ratio: " + FormatNumber(m_metrics.payoffRatio) + 
               " (Avg Win: " + FormatCurrency(m_metrics.avgWin) + " / Avg Loss: " + FormatCurrency(m_metrics.avgLoss) + ")", 
               m_style.textMuted, 8, false);
   
   y += 25;
}

void CTradingAnalytics::DrawRiskSection(int &y)
{
   CreateLabel("R_Title", m_panelX+16, y, "RISK METRICS", m_style.textMuted, 8, false);
   y += 16;
   
   CreateRect("R_BG", m_panelX+10, y, m_panelWidth-20, 85, m_style.bgSecondary, m_style.border);
   y += 10;
   
   int col1 = m_panelX + 20;
   int col2 = m_panelX + m_panelWidth/2 + 10;
   int rowH = 18;
   
   // Max Drawdown
   CreateLabel("R_DD_L", col1, y, "Max Drawdown", m_style.textMuted, 8, false);
   color ddColor = (m_metrics.maxDrawdownPct < 10) ? m_style.success :
                   (m_metrics.maxDrawdownPct < 20) ? m_style.warning : m_style.danger;
   CreateLabel("R_DD_V", col1, y+12, FormatPercent(m_metrics.maxDrawdownPct), ddColor, 10, true);
   
   // Recovery Factor
   CreateLabel("R_RF_L", col2, y, "Recovery Factor", m_style.textMuted, 8, false);
   color rfColor = (m_metrics.recoveryFactor >= 2) ? m_style.success :
                   (m_metrics.recoveryFactor >= 1) ? m_style.warning : m_style.danger;
   CreateLabel("R_RF_V", col2, y+12, FormatNumber(m_metrics.recoveryFactor), rfColor, 10, true);
   
   y += rowH + 16;
   
   // Sharpe Ratio
   CreateLabel("R_SR_L", col1, y, "Sharpe Ratio", m_style.textMuted, 8, false);
   color srColor = (m_metrics.sharpeRatio >= 1) ? m_style.success :
                   (m_metrics.sharpeRatio >= 0) ? m_style.warning : m_style.danger;
   CreateLabel("R_SR_V", col1, y+12, FormatNumber(m_metrics.sharpeRatio), srColor, 10, true);
   
   // Sortino Ratio
   CreateLabel("R_SO_L", col2, y, "Sortino Ratio", m_style.textMuted, 8, false);
   color soColor = (m_metrics.sortinoRatio >= 1.5) ? m_style.success :
                   (m_metrics.sortinoRatio >= 0) ? m_style.warning : m_style.danger;
   CreateLabel("R_SO_V", col2, y+12, FormatNumber(m_metrics.sortinoRatio), soColor, 10, true);
   
   y += rowH + 16;
   
   // Streaks
   string streakText = "Streaks - Max Win: " + IntegerToString(m_metrics.maxWinStreak) + 
                       " | Max Loss: " + IntegerToString(m_metrics.maxLossStreak);
   CreateLabel("R_Streak", m_panelX+20, y, streakText, m_style.textMuted, 8, false);
   
   y += 25;
}

void CTradingAnalytics::DrawSizingSection(int &y)
{
   CreateLabel("S_Title", m_panelX+16, y, "POSITION SIZING", m_style.textMuted, 8, false);
   y += 16;
   
   CreateRect("S_BG", m_panelX+10, y, m_panelWidth-20, 55, m_style.bgSecondary, m_style.border);
   y += 10;
   
   int col1 = m_panelX + 20;
   int col2 = m_panelX + m_panelWidth/3 + 10;
   int col3 = m_panelX + 2*m_panelWidth/3;
   
   // Kelly %
   CreateLabel("S_K_L", col1, y, "Kelly %", m_style.textMuted, 8, false);
   string kellyText = FormatPercent(m_metrics.kellyPercent);
   if(m_metrics.kellyPercent > 25) kellyText += "*";
   color kellyColor = (m_metrics.kellyPercent > 0) ? m_style.success : m_style.danger;
   CreateLabel("S_K_V", col1, y+12, kellyText, kellyColor, 10, true);
   
   // Safe F (Half Kelly)
   CreateLabel("S_SF_L", col2, y, "Safe F (½K)", m_style.textMuted, 8, false);
   CreateLabel("S_SF_V", col2, y+12, FormatPercent(m_metrics.safeF), m_style.info, 10, true);
   
   // SQN Rating
   CreateLabel("S_SQN_L", col3, y, "System Quality", m_style.textMuted, 8, false);
   CreateLabel("S_SQN_V", col3, y+12, GetSQNRating(m_metrics.sqn), GetSQNColor(m_metrics.sqn), 10, true);
   
   y += 50;
   
   // Note about Kelly
   if(m_metrics.kellyPercent > 25)
   {
      CreateLabel("S_Note", m_panelX+20, y, "* Kelly > 25% - consider using half Kelly", m_style.warning, 8, false);
      y += 15;
   }
}

void CTradingAnalytics::DrawMiniEquityCurve(int x, int y, int width, int height)
{
   CreateRect("EC_BG", x, y, width, height, m_style.bgSecondary, m_style.border);
   
   int count = ArraySize(m_equityHistory);
   if(count < 2) return;
   
   // Find min/max
   double minVal = m_equityHistory[0];
   double maxVal = m_equityHistory[0];
   
   for(int i = 1; i < count; i++)
   {
      if(m_equityHistory[i] < minVal) minVal = m_equityHistory[i];
      if(m_equityHistory[i] > maxVal) maxVal = m_equityHistory[i];
   }
   
   if(maxVal == minVal) return;
   
   // Draw baseline
   double baseline = 10000;
   int baseY = y + height - 4 - (int)((baseline - minVal) / (maxVal - minVal) * (height - 8));
   baseY = MathMax(y+2, MathMin(y+height-3, baseY));
   
   CreateRect("EC_Base", x+2, baseY, width-4, 1, m_style.textMuted, m_style.textMuted);
   
   // Draw equity points
   double stepX = (double)(width - 4) / (count - 1);
   
   for(int i = 0; i < count; i++)
   {
      int px = x + 2 + (int)(i * stepX);
      int py = y + height - 4 - (int)((m_equityHistory[i] - minVal) / (maxVal - minVal) * (height - 8));
      py = MathMax(y+2, MathMin(y+height-3, py));
      
      color ptColor = (m_equityHistory[i] >= baseline) ? m_style.success : m_style.danger;
      
      string ptName = m_prefix + "EC_P" + IntegerToString(i);
      if(ObjectFind(0, ptName) < 0)
         ObjectCreate(0, ptName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      
      ObjectSetInteger(0, ptName, OBJPROP_XDISTANCE, px);
      ObjectSetInteger(0, ptName, OBJPROP_YDISTANCE, py);
      ObjectSetInteger(0, ptName, OBJPROP_XSIZE, 2);
      ObjectSetInteger(0, ptName, OBJPROP_YSIZE, 2);
      ObjectSetInteger(0, ptName, OBJPROP_BGCOLOR, ptColor);
      ObjectSetInteger(0, ptName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, ptName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   }
}

void CTradingAnalytics::DrawDistributionBars(int x, int y, int width, int height)
{
   CreateRect("Dist_BG", x, y, width, height, m_style.bgSecondary, m_style.border);
   
   // Find max for scaling
   int maxCount = 1;
   for(int i = 0; i < 10; i++)
   {
      if(m_metrics.profitDistribution[i] > maxCount)
         maxCount = m_metrics.profitDistribution[i];
   }
   
   int barWidth = (width - 24) / 10;
   int barY = y + 4;
   int barMaxH = height - 8;
   
   for(int i = 0; i < 10; i++)
   {
      int barX = x + 4 + i * barWidth + 2;
      int barH = (int)((double)m_metrics.profitDistribution[i] / maxCount * barMaxH);
      if(barH < 2 && m_metrics.profitDistribution[i] > 0) barH = 2;
      
      color barColor = (i < 5) ? m_style.danger : m_style.success;
      if(i == 4 || i == 5) barColor = m_style.warning;
      
      CreateRect("Dist_B" + IntegerToString(i), barX, barY + barMaxH - barH, barWidth - 4, barH, barColor, barColor);
   }
}

// Helper functions
string CTradingAnalytics::FormatNumber(double value, int decimals)
{
   return DoubleToString(value, decimals);
}

string CTradingAnalytics::FormatPercent(double value, int decimals)
{
   return DoubleToString(value, decimals) + "%";
}

string CTradingAnalytics::FormatCurrency(double value)
{
   string sign = (value >= 0) ? "+" : "";
   return sign + "$" + DoubleToString(MathAbs(value), 0);
}

string CTradingAnalytics::GetSQNRating(double sqn)
{
   if(sqn >= 5.0) return "Holy Grail";
   if(sqn >= 3.0) return "Excellent";
   if(sqn >= 2.5) return "Very Good";
   if(sqn >= 2.0) return "Good";
   if(sqn >= 1.6) return "Average";
   if(sqn >= 0) return "Poor";
   return "Losing";
}

color CTradingAnalytics::GetSQNColor(double sqn)
{
   if(sqn >= 2.5) return m_style.success;
   if(sqn >= 1.6) return m_style.warning;
   return m_style.danger;
}

color CTradingAnalytics::GetValueColor(double value, double neutral)
{
   if(value > neutral) return m_style.success;
   if(value < neutral) return m_style.danger;
   return m_style.textSecondary;
}

void CTradingAnalytics::CreateRect(string name, int x, int y, int w, int h, color bg, color brd)
{
   string objName = m_prefix + name;
   if(ObjectFind(0, objName) < 0)
      ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, brd);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

void CTradingAnalytics::CreateLabel(string name, int x, int y, string text, color clr, int size, bool bold)
{
   string objName = m_prefix + name;
   if(ObjectFind(0, objName) < 0)
      ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, objName, OBJPROP_FONT, bold ? "Segoe UI Semibold" : "Segoe UI");
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| GLOBAL INSTANCE                                                   |
//+------------------------------------------------------------------+
CTradingAnalytics g_analytics;

//+------------------------------------------------------------------+
//| Initialization                                                    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| CHART THEME - Original Colors Storage                             |
//+------------------------------------------------------------------+
color g_origBackground;
color g_origForeground;
color g_origGrid;
color g_origBullCandle;
color g_origBearCandle;
color g_origBullWick;
color g_origBearWick;
color g_origChartLine;
color g_origVolumeUp;
color g_origVolumeDown;
color g_origBidLine;
color g_origAskLine;
bool  g_themeApplied = false;



//+------------------------------------------------------------------+
//| Apply Chart Theme                                                  |
//+------------------------------------------------------------------+
void ApplyChartTheme()
{
   if(!InpApplyChartTheme) return;
   
   // Save original colors
   g_origBackground  = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   g_origForeground  = (color)ChartGetInteger(0, CHART_COLOR_FOREGROUND);
   g_origGrid        = (color)ChartGetInteger(0, CHART_COLOR_GRID);
   g_origBullCandle  = (color)ChartGetInteger(0, CHART_COLOR_CANDLE_BULL);
   g_origBearCandle  = (color)ChartGetInteger(0, CHART_COLOR_CANDLE_BEAR);
   g_origBullWick    = (color)ChartGetInteger(0, CHART_COLOR_CHART_UP);
   g_origBearWick    = (color)ChartGetInteger(0, CHART_COLOR_CHART_DOWN);
   g_origChartLine   = (color)ChartGetInteger(0, CHART_COLOR_CHART_LINE);
   g_origVolumeUp    = (color)ChartGetInteger(0, CHART_COLOR_VOLUME);
   g_origVolumeDown  = (color)ChartGetInteger(0, CHART_COLOR_VOLUME);
   g_origBidLine     = (color)ChartGetInteger(0, CHART_COLOR_BID);
   g_origAskLine     = (color)ChartGetInteger(0, CHART_COLOR_ASK);
   
   // Apply new theme colors
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, InpBackgroundColor);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, InpForegroundColor);
   ChartSetInteger(0, CHART_COLOR_GRID, InpGridColor);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, InpBullCandleColor);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, InpBearCandleColor);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, InpBullWickColor);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, InpBearWickColor);
   ChartSetInteger(0, CHART_COLOR_CHART_LINE, InpChartLineColor);
   ChartSetInteger(0, CHART_COLOR_VOLUME, InpVolumeUpColor);
   ChartSetInteger(0, CHART_COLOR_BID, InpBidLineColor);
   ChartSetInteger(0, CHART_COLOR_ASK, InpAskLineColor);
   
   // Additional chart settings for professional look
   ChartSetInteger(0, CHART_SHOW_GRID, true);
   ChartSetInteger(0, CHART_COLOR_STOP_LEVEL, clrRed);
   
   g_themeApplied = true;
   ChartRedraw(0);
   
   Print("📊 Chart theme applied - AnaCristina Premium Suite");
}

//+------------------------------------------------------------------+
//| Restore Original Chart Colors                                      |
//+------------------------------------------------------------------+
void RestoreChartTheme()
{
   if(!g_themeApplied || !InpApplyChartTheme) return;
   
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, g_origBackground);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, g_origForeground);
   ChartSetInteger(0, CHART_COLOR_GRID, g_origGrid);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, g_origBullCandle);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, g_origBearCandle);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, g_origBullWick);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, g_origBearWick);
   ChartSetInteger(0, CHART_COLOR_CHART_LINE, g_origChartLine);
   ChartSetInteger(0, CHART_COLOR_VOLUME, g_origVolumeUp);
   ChartSetInteger(0, CHART_COLOR_BID, g_origBidLine);
   ChartSetInteger(0, CHART_COLOR_ASK, g_origAskLine);
   
   g_themeApplied = false;
   ChartRedraw(0);
   
   Print("📊 Original chart theme restored");
}


int OnInit()
{
   // Apply chart theme
   ApplyChartTheme();
   
   g_analytics.Initialize();
   EventSetTimer(5);
   
   Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   Print("  Trading Analytics Suite v2.0 Initialized");
   Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   // Restore original chart theme
   RestoreChartTheme();
   
   EventKillTimer();
   g_analytics.Destroy();
}

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
   return(rates_total);
}

void OnTimer()
{
   g_analytics.Update();
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
      g_analytics.Update();
}
//+------------------------------------------------------------------+
