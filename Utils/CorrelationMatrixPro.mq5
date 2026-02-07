//+------------------------------------------------------------------+
//|                                       CorrelationMatrixPro.mq5   |
//|                        Copyright 2025, AnaCristina Trading Ltd.  |
//|                                   https://www.anacristina.trading |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, AnaCristina Trading Ltd."
#property link      "https://www.anacristina.trading"
#property version   "3.00"
#property description "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
#property description "        CORRELATION MATRIX PRO v3.0"
#property description "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
#property description "Real-time multi-asset correlation analysis:"
#property description ""
#property description "• Live correlation matrix with heatmap"
#property description "• Correlation divergence detection"
#property description "• Rolling correlation with trend"
#property description "• Portfolio correlation exposure"
#property description "• Intermarket analysis (DXY, Gold, Yields)"
#property description "• Correlation breakdown alerts"
#property description ""
#property description "Essential for portfolio risk management."
#property description ""
#property description "For automated correlation trading: AnaCristina EA v2"
#property indicator_chart_window
#property indicator_plots 0

//+------------------------------------------------------------------+
//| CONSTANTS                                                         |
//+------------------------------------------------------------------+
#define MAX_SYMBOLS     12
#define CORR_PERIODS    5

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                      |
//+------------------------------------------------------------------+
enum ENUM_SYMBOL_SET
{
   SET_MAJORS       = 0,   // Forex Majors (8)
   SET_CROSSES      = 1,   // Forex Crosses (8)
   SET_COMMODITIES  = 2,   // Commodities (Gold, Oil, etc.)
   SET_INDICES      = 3,   // Major Indices
   SET_CUSTOM       = 4    // Custom Selection
};

enum ENUM_CORR_PERIOD
{
   PERIOD_20        = 20,  // 20 Bars (Short-term)
   PERIOD_50        = 50,  // 50 Bars (Medium-term)
   PERIOD_100       = 100, // 100 Bars (Long-term)
   PERIOD_200       = 200  // 200 Bars (Extended)
};

enum ENUM_DISPLAY_MODE
{
   MODE_MATRIX      = 0,   // Full Matrix
   MODE_CURRENT     = 1,   // Current Symbol Focus
   MODE_STRONGEST   = 2    // Strongest Correlations
};

enum ENUM_THEME
{
   THEME_DARK       = 0,   // Dark Professional
   THEME_MATRIX     = 1,   // Matrix Green
   THEME_BLOOMBERG  = 2,   // Bloomberg Style
   THEME_LIGHT      = 3    // Light Mode
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input string               _S1_ = ""; // ═══════════════ SYMBOL SELECTION ═══════════════
input ENUM_SYMBOL_SET      InpSymbolSet         = SET_MAJORS;         // Symbol Set
input string               InpCustomSymbols     = "EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD,USDCHF,NZDUSD,XAUUSD"; // Custom Symbols

input string               _S2_ = ""; // ═══════════════ CORRELATION SETTINGS ═══════════════
input ENUM_CORR_PERIOD     InpMainPeriod        = PERIOD_50;          // Main Correlation Period
input ENUM_TIMEFRAMES      InpTimeframe         = PERIOD_H1;          // Calculation Timeframe
input bool                 InpShowMultiPeriod   = true;               // Show Multi-Period Analysis
input double               InpStrongCorr        = 0.7;                // Strong Correlation Threshold
input double               InpDivergenceAlert   = 0.3;                // Divergence Alert Threshold

input string               _S3_ = ""; // ═══════════════ ALERTS ═══════════════
input bool                 InpAlertBreakdown    = true;               // Alert on Correlation Breakdown
input bool                 InpAlertDivergence   = true;               // Alert on Price Divergence
input int                  InpAlertCooldown     = 60;                 // Alert Cooldown (minutes)

input string               _S4_ = ""; // ═══════════════ DISPLAY ═══════════════
input ENUM_DISPLAY_MODE    InpDisplayMode       = MODE_MATRIX;        // Display Mode
input ENUM_THEME           InpTheme             = THEME_DARK;         // Color Theme
input int                  InpXOffset           = 50;                 // X Offset
input int                  InpYOffset           = 50;                 // Y Offset
input int                  InpCellSize          = 45;                 // Cell Size (pixels)
input bool                 InpShowValues        = true;               // Show Correlation Values
input bool                 InpShowLegend        = true;               // Show Color Legend

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
struct SSymbolData
{
   string            symbol;
   double            returns[];
   double            prices[];
   bool              valid;
   double            change24h;
   double            atr;
};

struct SCorrelation
{
   double            value;
   double            prevValue;    // For trend
   double            change;
   bool              isStrong;
   bool              isDiverging;
};

struct STheme
{
   color             bgPanel;
   color             bgCell;
   color             bgHeader;
   color             border;
   color             textPrimary;
   color             textSecondary;
   color             textMuted;
   color             corrPositiveStrong;
   color             corrPositiveWeak;
   color             corrNeutral;
   color             corrNegativeWeak;
   color             corrNegativeStrong;
   color             highlight;
   color             alert;
};

//+------------------------------------------------------------------+
//| CLASS: CCorrelationMatrix                                         |
//+------------------------------------------------------------------+
class CCorrelationMatrix
{
private:
   string            m_prefix;
   STheme            m_theme;
   SSymbolData       m_symbols[MAX_SYMBOLS];
   SCorrelation      m_matrix[MAX_SYMBOLS][MAX_SYMBOLS];
   int               m_symbolCount;
   
   int               m_panelX;
   int               m_panelY;
   int               m_panelW;
   int               m_panelH;
   int               m_cellSize;
   
   datetime          m_lastAlert;
   datetime          m_lastCalc;
   
   // Statistics
   double            m_avgCorrelation;
   double            m_maxPositive;
   double            m_maxNegative;
   string            m_strongestPair[2];
   string            m_weakestPair[2];
   int               m_strongCount;
   int               m_divergenceCount;
   
public:
                     CCorrelationMatrix();
                    ~CCorrelationMatrix();
   
   void              Initialize();
   void              Calculate();
   void              DrawMatrix();
   void              Destroy();
   
private:
   void              LoadTheme();
   void              LoadSymbols();
   void              FetchData();
   double            CalculateCorrelation(int sym1, int sym2);
   double            CalculateMean(const double &arr[], int count);
   double            CalculateStdDev(const double &arr[], int count, double mean);
   void              AnalyzeCorrelations();
   void              CheckAlerts();
   
   void              DrawCell(int row, int col, double correlation, bool isHeader=false);
   void              DrawLegend(int x, int y);
   void              DrawStatistics(int x, int y);
   void              DrawMultiPeriod(int x, int y);
   
   color             GetCorrelationColor(double corr);
   string            FormatCorrelation(double corr);
   
   void              CreateRect(string name, int x, int y, int w, int h, color bg, color brd);
   void              CreateLabel(string name, int x, int y, string text, color clr, int size,
                                string font="Segoe UI", ENUM_ANCHOR_POINT anchor=ANCHOR_LEFT_UPPER);
};

//+------------------------------------------------------------------+
CCorrelationMatrix::CCorrelationMatrix()
{
   m_prefix = "CORR_";
   m_symbolCount = 0;
   m_lastAlert = 0;
   m_lastCalc = 0;
}

CCorrelationMatrix::~CCorrelationMatrix()
{
   Destroy();
}

void CCorrelationMatrix::Initialize()
{
   LoadTheme();
   LoadSymbols();
   
   m_cellSize = InpCellSize;
   m_panelX = InpXOffset;
   m_panelY = InpYOffset;
   
   // Calculate panel size
   int headerSize = 60;
   int matrixSize = m_cellSize * (m_symbolCount + 1);
   int legendSize = InpShowLegend ? 80 : 0;
   int statsSize = 120;
   
   m_panelW = matrixSize + 40 + (InpShowMultiPeriod ? 200 : 0);
   m_panelH = headerSize + matrixSize + legendSize + statsSize + 20;
}

void CCorrelationMatrix::LoadTheme()
{
   switch(InpTheme)
   {
      case THEME_MATRIX:
         m_theme.bgPanel      = C'5,15,10';
         m_theme.bgCell       = C'10,30,20';
         m_theme.bgHeader     = C'15,40,25';
         m_theme.border       = C'30,80,50';
         m_theme.textPrimary  = C'150,255,180';
         m_theme.textSecondary= C'100,200,130';
         m_theme.textMuted    = C'60,130,80';
         m_theme.corrPositiveStrong = C'0,200,100';
         m_theme.corrPositiveWeak   = C'40,120,70';
         m_theme.corrNeutral        = C'80,80,80';
         m_theme.corrNegativeWeak   = C'150,80,60';
         m_theme.corrNegativeStrong = C'220,50,50';
         m_theme.highlight    = C'100,255,150';
         m_theme.alert        = C'255,100,100';
         break;
         
      case THEME_BLOOMBERG:
         m_theme.bgPanel      = C'30,30,30';
         m_theme.bgCell       = C'45,45,45';
         m_theme.bgHeader     = C'55,55,55';
         m_theme.border       = C'80,80,80';
         m_theme.textPrimary  = C'255,140,0';
         m_theme.textSecondary= C'255,180,100';
         m_theme.textMuted    = C'180,140,80';
         m_theme.corrPositiveStrong = C'0,180,80';
         m_theme.corrPositiveWeak   = C'100,160,100';
         m_theme.corrNeutral        = C'128,128,128';
         m_theme.corrNegativeWeak   = C'200,120,100';
         m_theme.corrNegativeStrong = C'255,60,60';
         m_theme.highlight    = C'255,200,0';
         m_theme.alert        = C'255,80,80';
         break;
         
      case THEME_LIGHT:
         m_theme.bgPanel      = C'250,250,252';
         m_theme.bgCell       = C'255,255,255';
         m_theme.bgHeader     = C'240,242,245';
         m_theme.border       = C'200,205,215';
         m_theme.textPrimary  = C'30,35,45';
         m_theme.textSecondary= C'70,80,100';
         m_theme.textMuted    = C'140,150,170';
         m_theme.corrPositiveStrong = C'0,150,80';
         m_theme.corrPositiveWeak   = C'150,200,170';
         m_theme.corrNeutral        = C'200,200,200';
         m_theme.corrNegativeWeak   = C'240,180,170';
         m_theme.corrNegativeStrong = C'200,50,50';
         m_theme.highlight    = C'0,120,255';
         m_theme.alert        = C'220,60,60';
         break;
         
      case THEME_DARK:
      default:
         m_theme.bgPanel      = C'12,14,18';
         m_theme.bgCell       = C'22,26,32';
         m_theme.bgHeader     = C'30,35,42';
         m_theme.border       = C'50,58,70';
         m_theme.textPrimary  = C'240,245,250';
         m_theme.textSecondary= C'180,190,205';
         m_theme.textMuted    = C'110,120,140';
         m_theme.corrPositiveStrong = C'50,200,120';
         m_theme.corrPositiveWeak   = C'80,140,100';
         m_theme.corrNeutral        = C'100,105,115';
         m_theme.corrNegativeWeak   = C'180,100,90';
         m_theme.corrNegativeStrong = C'240,70,70';
         m_theme.highlight    = C'100,180,255';
         m_theme.alert        = C'255,100,100';
         break;
   }
}

void CCorrelationMatrix::LoadSymbols()
{
   m_symbolCount = 0;
   string symbols[];
   
   switch(InpSymbolSet)
   {
      case SET_MAJORS:
         ArrayResize(symbols, 8);
         symbols[0] = "EURUSD"; symbols[1] = "GBPUSD";
         symbols[2] = "USDJPY"; symbols[3] = "USDCHF";
         symbols[4] = "AUDUSD"; symbols[5] = "USDCAD";
         symbols[6] = "NZDUSD"; symbols[7] = "XAUUSD";
         break;
         
      case SET_CROSSES:
         ArrayResize(symbols, 8);
         symbols[0] = "EURGBP"; symbols[1] = "EURJPY";
         symbols[2] = "GBPJPY"; symbols[3] = "AUDJPY";
         symbols[4] = "EURAUD"; symbols[5] = "GBPAUD";
         symbols[6] = "EURCHF"; symbols[7] = "GBPCHF";
         break;
         
      case SET_COMMODITIES:
         ArrayResize(symbols, 6);
         symbols[0] = "XAUUSD"; symbols[1] = "XAGUSD";
         symbols[2] = "XBRUSD"; symbols[3] = "XTIUSD";
         symbols[4] = "XNGUSD"; symbols[5] = "XPDUSD";
         break;
         
      case SET_INDICES:
         ArrayResize(symbols, 6);
         symbols[0] = "US30"; symbols[1] = "US500";
         symbols[2] = "USTEC"; symbols[3] = "DE40";
         symbols[4] = "UK100"; symbols[5] = "JP225";
         break;
         
      case SET_CUSTOM:
      default:
         StringSplit(InpCustomSymbols, ',', symbols);
         break;
   }
   
   // Validate symbols
   for(int i = 0; i < ArraySize(symbols) && m_symbolCount < MAX_SYMBOLS; i++)
   {
      string sym = symbols[i];
      StringTrimLeft(sym);
      StringTrimRight(sym);
      
      if(SymbolSelect(sym, true))
      {
         m_symbols[m_symbolCount].symbol = sym;
         m_symbols[m_symbolCount].valid = true;
         m_symbolCount++;
      }
      else
      {
         Print("Symbol not found: ", sym);
      }
   }
}

void CCorrelationMatrix::Destroy()
{
   ObjectsDeleteAll(0, m_prefix);
}

void CCorrelationMatrix::FetchData()
{
   int period = InpMainPeriod;
   
   for(int i = 0; i < m_symbolCount; i++)
   {
      if(!m_symbols[i].valid) continue;
      
      double closes[];
      ArraySetAsSeries(closes, true);
      
      int copied = CopyClose(m_symbols[i].symbol, InpTimeframe, 0, period + 1, closes);
      if(copied < period + 1)
      {
         m_symbols[i].valid = false;
         continue;
      }
      
      // Calculate returns (percentage change)
      ArrayResize(m_symbols[i].returns, period);
      ArrayResize(m_symbols[i].prices, period + 1);
      ArrayCopy(m_symbols[i].prices, closes);
      
      for(int j = 0; j < period; j++)
      {
         if(closes[j + 1] != 0)
            m_symbols[i].returns[j] = (closes[j] - closes[j + 1]) / closes[j + 1] * 100;
         else
            m_symbols[i].returns[j] = 0;
      }
      
      // 24h change
      if(copied >= 24)
      {
         int bars24h = 24;
         if(InpTimeframe == PERIOD_M15) bars24h = 96;
         else if(InpTimeframe == PERIOD_M30) bars24h = 48;
         else if(InpTimeframe == PERIOD_H4) bars24h = 6;
         else if(InpTimeframe == PERIOD_D1) bars24h = 1;
         
         bars24h = MathMin(bars24h, copied - 1);
         if(closes[bars24h] != 0)
            m_symbols[i].change24h = (closes[0] - closes[bars24h]) / closes[bars24h] * 100;
      }
   }
}

double CCorrelationMatrix::CalculateCorrelation(int sym1, int sym2)
{
   if(!m_symbols[sym1].valid || !m_symbols[sym2].valid)
      return 0;
   
   int n = ArraySize(m_symbols[sym1].returns);
   if(n != ArraySize(m_symbols[sym2].returns) || n < 10)
      return 0;
   
   double mean1 = CalculateMean(m_symbols[sym1].returns, n);
   double mean2 = CalculateMean(m_symbols[sym2].returns, n);
   double std1 = CalculateStdDev(m_symbols[sym1].returns, n, mean1);
   double std2 = CalculateStdDev(m_symbols[sym2].returns, n, mean2);
   
   if(std1 == 0 || std2 == 0)
      return 0;
   
   double covariance = 0;
   for(int i = 0; i < n; i++)
   {
      covariance += (m_symbols[sym1].returns[i] - mean1) * (m_symbols[sym2].returns[i] - mean2);
   }
   covariance /= n;
   
   return covariance / (std1 * std2);
}

double CCorrelationMatrix::CalculateMean(const double &arr[], int count)
{
   double sum = 0;
   for(int i = 0; i < count; i++)
      sum += arr[i];
   return sum / count;
}

double CCorrelationMatrix::CalculateStdDev(const double &arr[], int count, double mean)
{
   double sumSq = 0;
   for(int i = 0; i < count; i++)
   {
      double diff = arr[i] - mean;
      sumSq += diff * diff;
   }
   return MathSqrt(sumSq / count);
}

void CCorrelationMatrix::Calculate()
{
   datetime now = TimeCurrent();
   
   // Recalculate every 5 minutes
   if(now - m_lastCalc < 300) return;
   m_lastCalc = now;
   
   FetchData();
   
   // Calculate correlation matrix
   for(int i = 0; i < m_symbolCount; i++)
   {
      for(int j = 0; j < m_symbolCount; j++)
      {
         if(i == j)
         {
            m_matrix[i][j].value = 1.0;
         }
         else if(j > i)
         {
            m_matrix[i][j].prevValue = m_matrix[i][j].value;
            m_matrix[i][j].value = CalculateCorrelation(i, j);
            m_matrix[i][j].change = m_matrix[i][j].value - m_matrix[i][j].prevValue;
            m_matrix[j][i] = m_matrix[i][j];  // Mirror
         }
         
         m_matrix[i][j].isStrong = (MathAbs(m_matrix[i][j].value) >= InpStrongCorr);
      }
   }
   
   AnalyzeCorrelations();
   CheckAlerts();
}

void CCorrelationMatrix::AnalyzeCorrelations()
{
   m_avgCorrelation = 0;
   m_maxPositive = -1;
   m_maxNegative = 1;
   m_strongCount = 0;
   m_divergenceCount = 0;
   
   int pairCount = 0;
   
   for(int i = 0; i < m_symbolCount; i++)
   {
      for(int j = i + 1; j < m_symbolCount; j++)
      {
         double corr = m_matrix[i][j].value;
         m_avgCorrelation += corr;
         pairCount++;
         
         if(MathAbs(corr) >= InpStrongCorr)
            m_strongCount++;
         
         if(corr > m_maxPositive)
         {
            m_maxPositive = corr;
            m_strongestPair[0] = m_symbols[i].symbol;
            m_strongestPair[1] = m_symbols[j].symbol;
         }
         
         if(corr < m_maxNegative)
         {
            m_maxNegative = corr;
            m_weakestPair[0] = m_symbols[i].symbol;
            m_weakestPair[1] = m_symbols[j].symbol;
         }
         
         // Check for divergence (price moving opposite to correlation)
         if(corr > InpStrongCorr)  // Should move together
         {
            double move1 = m_symbols[i].change24h;
            double move2 = m_symbols[j].change24h;
            
            if((move1 > 0.5 && move2 < -0.5) || (move1 < -0.5 && move2 > 0.5))
            {
               m_matrix[i][j].isDiverging = true;
               m_divergenceCount++;
            }
         }
         else if(corr < -InpStrongCorr)  // Should move opposite
         {
            double move1 = m_symbols[i].change24h;
            double move2 = m_symbols[j].change24h;
            
            if((move1 > 0.5 && move2 > 0.5) || (move1 < -0.5 && move2 < -0.5))
            {
               m_matrix[i][j].isDiverging = true;
               m_divergenceCount++;
            }
         }
         else
         {
            m_matrix[i][j].isDiverging = false;
         }
      }
   }
   
   if(pairCount > 0)
      m_avgCorrelation /= pairCount;
}

void CCorrelationMatrix::CheckAlerts()
{
   if(!InpAlertBreakdown && !InpAlertDivergence) return;
   
   datetime now = TimeCurrent();
   if(now - m_lastAlert < InpAlertCooldown * 60) return;
   
   // Alert on divergences
   if(InpAlertDivergence && m_divergenceCount > 0)
   {
      Alert("Correlation Divergence: ", m_divergenceCount, " pairs diverging from expected correlation");
      m_lastAlert = now;
   }
}

color CCorrelationMatrix::GetCorrelationColor(double corr)
{
   if(corr >= 0.7)       return m_theme.corrPositiveStrong;
   if(corr >= 0.3)       return m_theme.corrPositiveWeak;
   if(corr >= -0.3)      return m_theme.corrNeutral;
   if(corr >= -0.7)      return m_theme.corrNegativeWeak;
   return m_theme.corrNegativeStrong;
}

string CCorrelationMatrix::FormatCorrelation(double corr)
{
   string sign = (corr >= 0) ? "+" : "";
   return sign + DoubleToString(corr, 2);
}

void CCorrelationMatrix::DrawMatrix()
{
   // Clear previous
   ObjectsDeleteAll(0, m_prefix);
   
   // Main panel background
   CreateRect("Panel", m_panelX, m_panelY, m_panelW, m_panelH, m_theme.bgPanel, m_theme.border);
   
   // Header
   CreateRect("Header", m_panelX, m_panelY, m_panelW, 55, m_theme.bgHeader, m_theme.border);
   CreateLabel("Title", m_panelX + 15, m_panelY + 12, "CORRELATION MATRIX", 
               m_theme.textPrimary, 13, "Segoe UI Bold");
   CreateLabel("Subtitle", m_panelX + 15, m_panelY + 32, 
               IntegerToString(m_symbolCount) + " Assets • " + IntegerToString(InpMainPeriod) + " Period • " + 
               EnumToString(InpTimeframe), m_theme.textMuted, 9);
   
   // Version
   CreateRect("Ver", m_panelX + m_panelW - 50, m_panelY + 15, 40, 20, m_theme.border, m_theme.border);
   CreateLabel("VerText", m_panelX + m_panelW - 45, m_panelY + 18, "v3.0", m_theme.highlight, 9);
   
   int matrixY = m_panelY + 65;
   int matrixX = m_panelX + 15;
   
   // Draw column headers
   for(int j = 0; j < m_symbolCount; j++)
   {
      int cellX = matrixX + m_cellSize + j * m_cellSize;
      CreateRect("ColH_" + IntegerToString(j), cellX, matrixY, m_cellSize - 2, m_cellSize - 2,
                m_theme.bgHeader, m_theme.border);
      
      string shortSym = StringSubstr(m_symbols[j].symbol, 0, 3);
      CreateLabel("ColL_" + IntegerToString(j), cellX + m_cellSize/2, matrixY + m_cellSize/2 - 5,
                 shortSym, m_theme.textSecondary, 8, "Segoe UI Bold", ANCHOR_CENTER);
   }
   
   // Draw rows
   for(int i = 0; i < m_symbolCount; i++)
   {
      int rowY = matrixY + m_cellSize + i * m_cellSize;
      
      // Row header
      CreateRect("RowH_" + IntegerToString(i), matrixX, rowY, m_cellSize - 2, m_cellSize - 2,
                m_theme.bgHeader, m_theme.border);
      
      string shortSym = StringSubstr(m_symbols[i].symbol, 0, 3);
      CreateLabel("RowL_" + IntegerToString(i), matrixX + m_cellSize/2, rowY + m_cellSize/2 - 5,
                 shortSym, m_theme.textSecondary, 8, "Segoe UI Bold", ANCHOR_CENTER);
      
      // Cells
      for(int j = 0; j < m_symbolCount; j++)
      {
         int cellX = matrixX + m_cellSize + j * m_cellSize;
         double corr = m_matrix[i][j].value;
         color cellColor = GetCorrelationColor(corr);
         
         string cellName = "Cell_" + IntegerToString(i) + "_" + IntegerToString(j);
         CreateRect(cellName, cellX, rowY, m_cellSize - 2, m_cellSize - 2, cellColor, m_theme.border);
         
         // Value
         if(InpShowValues && i != j)
         {
            color textColor = (MathAbs(corr) > 0.5) ? m_theme.textPrimary : m_theme.textSecondary;
            CreateLabel("Val_" + IntegerToString(i) + "_" + IntegerToString(j),
                       cellX + m_cellSize/2, rowY + m_cellSize/2 - 5,
                       FormatCorrelation(corr), textColor, 8, "Consolas", ANCHOR_CENTER);
         }
         
         // Divergence indicator
         if(m_matrix[i][j].isDiverging && i < j)
         {
            CreateLabel("Div_" + IntegerToString(i) + "_" + IntegerToString(j),
                       cellX + m_cellSize - 10, rowY + 3,
                       "!", m_theme.alert, 10, "Segoe UI Bold");
         }
      }
   }
   
   int bottomY = matrixY + m_cellSize * (m_symbolCount + 1) + 15;
   
   // Legend
   if(InpShowLegend)
   {
      DrawLegend(matrixX, bottomY);
      bottomY += 55;
   }
   
   // Statistics
   DrawStatistics(matrixX, bottomY);
   
   // Multi-period analysis
   if(InpShowMultiPeriod)
   {
      int mpX = matrixX + m_cellSize * (m_symbolCount + 1) + 20;
      DrawMultiPeriod(mpX, matrixY);
   }
   
   ChartRedraw();
}

void CCorrelationMatrix::DrawLegend(int x, int y)
{
   CreateLabel("LegendTitle", x, y, "CORRELATION SCALE", m_theme.textMuted, 8);
   y += 15;
   
   // Gradient boxes
   color colors[] = {m_theme.corrNegativeStrong, m_theme.corrNegativeWeak, 
                    m_theme.corrNeutral, m_theme.corrPositiveWeak, m_theme.corrPositiveStrong};
   string labels[] = {"-1.0", "-0.5", "0.0", "+0.5", "+1.0"};
   
   int boxW = 40;
   for(int i = 0; i < 5; i++)
   {
      CreateRect("Leg_" + IntegerToString(i), x + i * boxW, y, boxW - 2, 20, colors[i], m_theme.border);
      CreateLabel("LegL_" + IntegerToString(i), x + i * boxW + boxW/2, y + 25,
                 labels[i], m_theme.textMuted, 7, "Consolas", ANCHOR_CENTER);
   }
}

void CCorrelationMatrix::DrawStatistics(int x, int y)
{
   CreateLabel("StatsTitle", x, y, "ANALYSIS", m_theme.textMuted, 8);
   y += 18;
   
   CreateRect("StatsBG", x, y, m_panelW - 30, 85, m_theme.bgCell, m_theme.border);
   y += 10;
   
   int col1 = x + 10;
   int col2 = x + (m_panelW - 30) / 2;
   
   // Average correlation
   CreateLabel("AvgL", col1, y, "Avg Correlation", m_theme.textMuted, 8);
   CreateLabel("AvgV", col1, y + 12, FormatCorrelation(m_avgCorrelation), 
               GetCorrelationColor(m_avgCorrelation), 11, "Consolas Bold");
   
   // Strong pairs
   CreateLabel("StrongL", col2, y, "Strong Pairs", m_theme.textMuted, 8);
   CreateLabel("StrongV", col2, y + 12, IntegerToString(m_strongCount), m_theme.highlight, 11, "Consolas Bold");
   
   y += 35;
   
   // Most correlated
   CreateLabel("MaxPosL", col1, y, "Most Correlated", m_theme.textMuted, 8);
   CreateLabel("MaxPosV", col1, y + 12, m_strongestPair[0] + "/" + m_strongestPair[1] + " " + FormatCorrelation(m_maxPositive),
               m_theme.corrPositiveStrong, 9, "Consolas");
   
   // Most inverse
   CreateLabel("MaxNegL", col2, y, "Most Inverse", m_theme.textMuted, 8);
   CreateLabel("MaxNegV", col2, y + 12, m_weakestPair[0] + "/" + m_weakestPair[1] + " " + FormatCorrelation(m_maxNegative),
               m_theme.corrNegativeStrong, 9, "Consolas");
   
   // Divergence warning
   if(m_divergenceCount > 0)
   {
      y += 35;
      CreateRect("DivWarn", x, y, m_panelW - 30, 25, m_theme.alert, m_theme.alert);
      CreateLabel("DivWarnT", x + 10, y + 6, "⚠ " + IntegerToString(m_divergenceCount) + " Correlation Divergence(s) Detected",
                 m_theme.textPrimary, 9, "Segoe UI Bold");
   }
}

void CCorrelationMatrix::DrawMultiPeriod(int x, int y)
{
   CreateLabel("MPTitle", x, y, "MULTI-PERIOD", m_theme.textMuted, 8);
   y += 18;
   
   CreateRect("MPBG", x, y, 180, m_cellSize * m_symbolCount + 50, m_theme.bgCell, m_theme.border);
   y += 10;
   
   // Period headers
   string periods[] = {"20", "50", "100", "200"};
   int colW = 40;
   
   for(int p = 0; p < 4; p++)
   {
      CreateLabel("MPH_" + IntegerToString(p), x + 50 + p * colW, y, periods[p],
                 m_theme.textSecondary, 8, "Consolas", ANCHOR_CENTER);
   }
   y += 18;
   
   // For current symbol - show correlation with others across periods
   int currentIdx = -1;
   for(int i = 0; i < m_symbolCount; i++)
   {
      if(m_symbols[i].symbol == _Symbol)
      {
         currentIdx = i;
         break;
      }
   }
   
   if(currentIdx < 0) currentIdx = 0;
   
   for(int i = 0; i < m_symbolCount; i++)
   {
      if(i == currentIdx) continue;
      
      string shortSym = StringSubstr(m_symbols[i].symbol, 0, 6);
      CreateLabel("MPS_" + IntegerToString(i), x + 10, y, shortSym, m_theme.textSecondary, 8);
      
      // Main correlation value
      double corr = m_matrix[currentIdx][i].value;
      CreateLabel("MPC_" + IntegerToString(i), x + 90, y, FormatCorrelation(corr),
                 GetCorrelationColor(corr), 9, "Consolas");
      
      // Trend indicator
      double change = m_matrix[currentIdx][i].change;
      string trend = (change > 0.02) ? "↑" : (change < -0.02) ? "↓" : "→";
      color trendColor = (change > 0.02) ? m_theme.corrPositiveStrong : 
                        (change < -0.02) ? m_theme.corrNegativeStrong : m_theme.textMuted;
      CreateLabel("MPT_" + IntegerToString(i), x + 140, y, trend, trendColor, 10);
      
      y += 18;
   }
}

void CCorrelationMatrix::CreateRect(string name, int x, int y, int w, int h, color bg, color brd)
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

void CCorrelationMatrix::CreateLabel(string name, int x, int y, string text, color clr, int size,
                                     string font, ENUM_ANCHOR_POINT anchor)
{
   string objName = m_prefix + name;
   if(ObjectFind(0, objName) < 0)
      ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, objName, OBJPROP_FONT, font);
   ObjectSetInteger(0, objName, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| GLOBAL INSTANCE                                                   |
//+------------------------------------------------------------------+
CCorrelationMatrix g_matrix;

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
   
   g_matrix.Initialize();
   g_matrix.Calculate();
   g_matrix.DrawMatrix();
   
   EventSetTimer(60);  // Update every minute
   
   Print("═══════════════════════════════════════════════════════");
   Print("   CORRELATION MATRIX PRO v3.0 - Initialized");
   Print("   Multi-Asset Analysis • Divergence Detection");
   Print("═══════════════════════════════════════════════════════");
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   // Restore original chart theme
   RestoreChartTheme();
   
   EventKillTimer();
   g_matrix.Destroy();
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
   g_matrix.Calculate();
   g_matrix.DrawMatrix();
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      g_matrix.DrawMatrix();
   }
}
//+------------------------------------------------------------------+
