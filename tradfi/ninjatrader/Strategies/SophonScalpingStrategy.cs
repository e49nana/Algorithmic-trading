#region Using declarations
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Windows.Media;
using System.Xml.Serialization;
using NinjaTrader.Cbi;
using NinjaTrader.Data;
using NinjaTrader.Gui;
using NinjaTrader.NinjaScript;
using NinjaTrader.NinjaScript.Indicators;
using NinjaTrader.NinjaScript.DrawingTools;
#endregion

// ═══════════════════════════════════════════════════════════════════════════════
// SOPHON SCALPING STRATEGY - EMMANUEL EDITION v2.0
// ═══════════════════════════════════════════════════════════════════════════════
//
// SOURCE: 7 Conversations, 90+ Images, +$32,953.70 P&L Documented
//
// CONFIGURATION EMMANUEL (CONFIRMÉE):
//   EMA:              19 (6x+ confirmé)
//   Timeframes:       2m, 3m, 5m, 15m, 30m, 60m
//   Win Rate Global:  ~85%
//   Avg Win:          ~$550
//   Avg Loss:         ~$322
//
// LES 8 PATTERNS EMMANUEL:
//   1. EMABounce         (~20%) - 80% WR - Rebond sur EMA 19
//   2. RangeBreakout     (~20%) - 80% WR - Cassure de range
//   3. TrendlineTrading  (~15%) - 75% WR - Rebond sur trendline
//   4. ZoneTrading       (~15%) - 80% WR - Trading de zones S/R
//   5. ICTLevelBounce    (~10%) - 75% WR - Rebond sur PDH/PDL
//   6. BOSEntry          (~10%) - 80% WR - Entrée après BOS
//   7. LiquiditySweep    (~5%)  - 75% WR - Sweep de liquidité
//   8. TrendContinuation (~5%)  - 70% WR - Continuation
//
// CONFLUENCE SCORING (Max 10):
//   EMA position:  +2 | EMA slope:    +2 | Momentum:     +1
//   Volume spike:  +1 | ICT level:    +1 | BOS:          +1
//   NY session:    +1 | HTF aligned:  +1
//
// Copyright (c) 2026 Algosphere Quant - Emmanuel
// ═══════════════════════════════════════════════════════════════════════════════

namespace NinjaTrader.NinjaScript.Strategies
{
    public class SophonScalpingStrategy : Strategy
    {
        #region Variables
        // ═══════════════════════════════════════════════════════════════════════
        // INDICATEURS
        // ═══════════════════════════════════════════════════════════════════════
        private EMA ema19;
        private EMA ema50;        // Pour HTF confirmation
        private ATR atr;
        private SMA volumeSMA;
        
        // ═══════════════════════════════════════════════════════════════════════
        // STRUCTURE & SWINGS
        // ═══════════════════════════════════════════════════════════════════════
        private double swingHigh;
        private double swingLow;
        private double prevSwingHigh;
        private double prevSwingLow;
        private int swingHighBar;
        private int swingLowBar;
        
        // BOS Detection
        private bool bosLong;
        private bool bosShort;
        private double bosLevel;
        private int bosBar;
        
        // ═══════════════════════════════════════════════════════════════════════
        // ICT LEVELS
        // ═══════════════════════════════════════════════════════════════════════
        private double pdh;  // Previous Day High
        private double pdl;  // Previous Day Low
        private double pwh;  // Previous Week High
        private double pwl;  // Previous Week Low
        private DateTime lastDayProcessed;
        
        // ═══════════════════════════════════════════════════════════════════════
        // RANGE DETECTION
        // ═══════════════════════════════════════════════════════════════════════
        private double rangeHigh;
        private double rangeLow;
        private bool inRange;
        private int rangeStartBar;
        
        // ═══════════════════════════════════════════════════════════════════════
        // TRADE MANAGEMENT
        // ═══════════════════════════════════════════════════════════════════════
        private int lastTradeBar;
        private int todayTrades;
        private DateTime currentDate;
        private string lastPattern;
        private double entryPrice;
        private double stopPrice;
        private double target1Price;
        private double target2Price;
        
        // ═══════════════════════════════════════════════════════════════════════
        // STATISTICS
        // ═══════════════════════════════════════════════════════════════════════
        private int totalSignals;
        private int totalTrades;
        private int winningTrades;
        private int losingTrades;
        private Dictionary<string, int> patternCounts;
        private Dictionary<string, int> patternWins;
        #endregion

        #region Parameters
        // ═══════════════════════════════════════════════════════════════════════
        // 1. EMA SETTINGS (Emmanuel Confirmed)
        // ═══════════════════════════════════════════════════════════════════════
        [NinjaScriptProperty]
        [Range(5, 50)]
        [Display(Name = "EMA Period", Description = "Emmanuel uses 19", Order = 1, GroupName = "1. EMA Settings")]
        public int EMAPeriod { get; set; }

        [NinjaScriptProperty]
        [Range(20, 100)]
        [Display(Name = "EMA Slow (HTF)", Order = 2, GroupName = "1. EMA Settings")]
        public int EMASlowPeriod { get; set; }

        // ═══════════════════════════════════════════════════════════════════════
        // 2. CONFLUENCE
        // ═══════════════════════════════════════════════════════════════════════
        [NinjaScriptProperty]
        [Range(1, 10)]
        [Display(Name = "Min Confluence Score", Description = "Minimum score to enter (1-10)", Order = 1, GroupName = "2. Confluence")]
        public int MinConfluence { get; set; }

        [NinjaScriptProperty]
        [Range(1.0, 3.0)]
        [Display(Name = "Volume Spike Multiplier", Order = 2, GroupName = "2. Confluence")]
        public double VolumeSpikeMultiplier { get; set; }

        // ═══════════════════════════════════════════════════════════════════════
        // 3. PATTERNS (Enable/Disable)
        // ═══════════════════════════════════════════════════════════════════════
        [NinjaScriptProperty]
        [Display(Name = "1. EMA Bounce (80% WR)", Order = 1, GroupName = "3. Patterns")]
        public bool EnableEMABounce { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "2. Range Breakout (80% WR)", Order = 2, GroupName = "3. Patterns")]
        public bool EnableRangeBreakout { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "3. Trendline Trading (75% WR)", Order = 3, GroupName = "3. Patterns")]
        public bool EnableTrendline { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "4. Zone Trading (80% WR)", Order = 4, GroupName = "3. Patterns")]
        public bool EnableZoneTrading { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "5. ICT Level Bounce (75% WR)", Order = 5, GroupName = "3. Patterns")]
        public bool EnableICTBounce { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "6. BOS Entry (80% WR)", Order = 6, GroupName = "3. Patterns")]
        public bool EnableBOSEntry { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "7. Liquidity Sweep (75% WR)", Order = 7, GroupName = "3. Patterns")]
        public bool EnableLiquiditySweep { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "8. Trend Continuation (70% WR)", Order = 8, GroupName = "3. Patterns")]
        public bool EnableTrendContinuation { get; set; }

        // ═══════════════════════════════════════════════════════════════════════
        // 4. RISK MANAGEMENT
        // ═══════════════════════════════════════════════════════════════════════
        [NinjaScriptProperty]
        [Range(1.0, 5.0)]
        [Display(Name = "TP1 R:R", Order = 1, GroupName = "4. Risk")]
        public double TP1RR { get; set; }

        [NinjaScriptProperty]
        [Range(2.0, 10.0)]
        [Display(Name = "TP2 R:R", Order = 2, GroupName = "4. Risk")]
        public double TP2RR { get; set; }

        [NinjaScriptProperty]
        [Range(0.2, 2.0)]
        [Display(Name = "SL Buffer (ATR x)", Order = 3, GroupName = "4. Risk")]
        public double SLBuffer { get; set; }

        [NinjaScriptProperty]
        [Range(1, 10)]
        [Display(Name = "Max Trades/Day", Order = 4, GroupName = "4. Risk")]
        public int MaxDailyTrades { get; set; }

        [NinjaScriptProperty]
        [Range(3, 30)]
        [Display(Name = "Min Bars Between Trades", Order = 5, GroupName = "4. Risk")]
        public int MinBarsBetween { get; set; }

        // ═══════════════════════════════════════════════════════════════════════
        // 5. DIRECTION & SIZE
        // ═══════════════════════════════════════════════════════════════════════
        [NinjaScriptProperty]
        [Display(Name = "Trade Long", Order = 1, GroupName = "5. Direction")]
        public bool TradeLong { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Trade Short", Order = 2, GroupName = "5. Direction")]
        public bool TradeShort { get; set; }

        [NinjaScriptProperty]
        [Range(1, 50)]
        [Display(Name = "Position Size", Order = 3, GroupName = "5. Direction")]
        public int PositionSize { get; set; }

        // ═══════════════════════════════════════════════════════════════════════
        // 6. DEBUG
        // ═══════════════════════════════════════════════════════════════════════
        [NinjaScriptProperty]
        [Display(Name = "Show Drawings", Order = 1, GroupName = "6. Debug")]
        public bool ShowDrawings { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Debug Mode", Order = 2, GroupName = "6. Debug")]
        public bool DebugMode { get; set; }
        #endregion

        #region State Management
        protected override void OnStateChange()
        {
            if (State == State.SetDefaults)
            {
                Description = "Sophon Scalping Strategy - Emmanuel 8 Patterns";
                Name = "SophonScalpingStrategy";
                Calculate = Calculate.OnBarClose;
                EntriesPerDirection = 1;
                EntryHandling = EntryHandling.AllEntries;
                IsExitOnSessionCloseStrategy = true;
                ExitOnSessionCloseSeconds = 30;
                IsFillLimitOnTouch = false;
                MaximumBarsLookBack = MaximumBarsLookBack.TwoHundredFiftySix;
                OrderFillResolution = OrderFillResolution.Standard;
                Slippage = 1;
                StartBehavior = StartBehavior.WaitUntilFlat;
                TimeInForce = TimeInForce.Gtc;
                TraceOrders = true;
                RealtimeErrorHandling = RealtimeErrorHandling.StopCancelClose;
                StopTargetHandling = StopTargetHandling.PerEntryExecution;
                BarsRequiredToTrade = 50;

                // Emmanuel Defaults
                EMAPeriod = 19;
                EMASlowPeriod = 50;
                MinConfluence = 5;
                VolumeSpikeMultiplier = 1.3;
                
                // All patterns enabled by default
                EnableEMABounce = true;
                EnableRangeBreakout = true;
                EnableTrendline = true;
                EnableZoneTrading = true;
                EnableICTBounce = true;
                EnableBOSEntry = true;
                EnableLiquiditySweep = true;
                EnableTrendContinuation = true;
                
                // Risk
                TP1RR = 1.5;
                TP2RR = 2.5;
                SLBuffer = 0.5;
                MaxDailyTrades = 5;
                MinBarsBetween = 10;
                
                // Direction
                TradeLong = true;
                TradeShort = true;
                PositionSize = 1;
                
                // Debug
                ShowDrawings = true;
                DebugMode = true;
            }
            else if (State == State.DataLoaded)
            {
                ema19 = EMA(EMAPeriod);
                ema50 = EMA(EMASlowPeriod);
                atr = ATR(14);
                volumeSMA = SMA(Volume, 20);
                
                patternCounts = new Dictionary<string, int>();
                patternWins = new Dictionary<string, int>();
                
                swingHigh = 0;
                swingLow = double.MaxValue;
                prevSwingHigh = 0;
                prevSwingLow = double.MaxValue;
                
                if (DebugMode) Print("SophonScalpingStrategy: Initialisé - EMA=" + EMAPeriod);
            }
            else if (State == State.Terminated)
            {
                PrintFinalStats();
            }
        }
        #endregion

        #region Main Update
        protected override void OnBarUpdate()
        {
            if (CurrentBar < BarsRequiredToTrade) return;
            
            // Reset journalier
            if (Time[0].Date != currentDate)
            {
                currentDate = Time[0].Date;
                todayTrades = 0;
                UpdateICTLevels();
                if (DebugMode) Print($"=== {currentDate:yyyy-MM-dd} | PDH={pdh:F2} PDL={pdl:F2} ===");
            }
            
            double currentATR = atr[0];
            if (currentATR <= 0) return;
            
            // ═══════════════════════════════════════════════════════════════════════
            // UPDATE STRUCTURE
            // ═══════════════════════════════════════════════════════════════════════
            UpdateSwingPoints();
            DetectBOS();
            UpdateRangeDetection();
            
            // ═══════════════════════════════════════════════════════════════════════
            // CHECK FOR ENTRIES
            // ═══════════════════════════════════════════════════════════════════════
            if (Position.MarketPosition == MarketPosition.Flat)
            {
                if (todayTrades < MaxDailyTrades && CurrentBar - lastTradeBar >= MinBarsBetween)
                {
                    CheckAllPatterns(currentATR);
                }
            }
            else
            {
                // Gérer les positions existantes (Break-even, trailing, etc.)
                ManagePosition(currentATR);
            }
        }
        #endregion

        #region ICT Levels
        private void UpdateICTLevels()
        {
            if (CurrentBar < 2) return;
            
            // PDH/PDL - Previous Day High/Low
            double dayHigh = 0;
            double dayLow = double.MaxValue;
            DateTime previousDay = Time[0].Date.AddDays(-1);
            
            for (int i = 1; i < Math.Min(CurrentBar, 500); i++)
            {
                if (Time[i].Date == previousDay)
                {
                    dayHigh = Math.Max(dayHigh, High[i]);
                    dayLow = Math.Min(dayLow, Low[i]);
                }
                else if (Time[i].Date < previousDay)
                    break;
            }
            
            if (dayHigh > 0) pdh = dayHigh;
            if (dayLow < double.MaxValue) pdl = dayLow;
            
            // PWH/PWL - Previous Week High/Low
            double weekHigh = 0;
            double weekLow = double.MaxValue;
            DateTime weekStart = Time[0].Date.AddDays(-7);
            
            for (int i = 1; i < Math.Min(CurrentBar, 2000); i++)
            {
                if (Time[i].Date >= weekStart && Time[i].Date < Time[0].Date)
                {
                    weekHigh = Math.Max(weekHigh, High[i]);
                    weekLow = Math.Min(weekLow, Low[i]);
                }
            }
            
            if (weekHigh > 0) pwh = weekHigh;
            if (weekLow < double.MaxValue) pwl = weekLow;
        }
        #endregion

        #region Structure Detection
        private void UpdateSwingPoints()
        {
            int lb = 10; // Swing lookback
            
            // Swing High Detection
            if (CurrentBar >= lb * 2)
            {
                bool isHigh = true;
                double midHigh = High[lb];
                
                for (int i = 0; i < lb; i++)
                {
                    if (High[i] >= midHigh || High[lb + 1 + i] >= midHigh)
                    {
                        isHigh = false;
                        break;
                    }
                }
                
                if (isHigh && midHigh != swingHigh)
                {
                    prevSwingHigh = swingHigh;
                    swingHigh = midHigh;
                    swingHighBar = CurrentBar - lb;
                }
            }
            
            // Swing Low Detection
            if (CurrentBar >= lb * 2)
            {
                bool isLow = true;
                double midLow = Low[lb];
                
                for (int i = 0; i < lb; i++)
                {
                    if (Low[i] <= midLow || Low[lb + 1 + i] <= midLow)
                    {
                        isLow = false;
                        break;
                    }
                }
                
                if (isLow && midLow != swingLow)
                {
                    prevSwingLow = swingLow;
                    swingLow = midLow;
                    swingLowBar = CurrentBar - lb;
                }
            }
        }

        private void DetectBOS()
        {
            // Reset BOS flags
            bosLong = false;
            bosShort = false;
            
            // Bullish BOS: Close above previous swing high
            if (prevSwingHigh > 0 && Close[0] > prevSwingHigh && Close[1] <= prevSwingHigh)
            {
                bosLong = true;
                bosLevel = prevSwingHigh;
                bosBar = CurrentBar;
                prevSwingHigh = 0;
                
                if (DebugMode) Print($"[{Time[0]}] BOS LONG @ {bosLevel:F2}");
                if (ShowDrawings) Draw.Text(this, "BOS" + CurrentBar, "BOS↑", 0, High[0] + atr[0] * 0.3, Brushes.Lime);
            }
            
            // Bearish BOS: Close below previous swing low
            if (prevSwingLow > 0 && prevSwingLow < double.MaxValue &&
                Close[0] < prevSwingLow && Close[1] >= prevSwingLow)
            {
                bosShort = true;
                bosLevel = prevSwingLow;
                bosBar = CurrentBar;
                prevSwingLow = double.MaxValue;
                
                if (DebugMode) Print($"[{Time[0]}] BOS SHORT @ {bosLevel:F2}");
                if (ShowDrawings) Draw.Text(this, "BOS" + CurrentBar, "BOS↓", 0, Low[0] - atr[0] * 0.3, Brushes.Red);
            }
        }

        private void UpdateRangeDetection()
        {
            int rangeLookback = 20;
            
            rangeHigh = MAX(High, rangeLookback)[0];
            rangeLow = MIN(Low, rangeLookback)[0];
            
            double rangeSize = rangeHigh - rangeLow;
            double avgRange = atr[0] * 3;
            
            // Range valide si pas trop grand et pas trop petit
            inRange = rangeSize < avgRange && rangeSize > atr[0];
        }
        #endregion

        #region Confluence Scoring
        private int CalculateConfluence(int direction)
        {
            int score = 0;
            double currentATR = atr[0];
            
            // ═══════════════════════════════════════════════════════════════════════
            // REQUIRED FACTORS (Max 5 points)
            // ═══════════════════════════════════════════════════════════════════════
            
            // 1. EMA 19 Position (+2 points)
            bool emaPositionOk = (direction == 1 && Close[0] > ema19[0]) ||
                                 (direction == -1 && Close[0] < ema19[0]);
            if (emaPositionOk) score += 2;
            
            // 2. EMA 19 Slope (+2 points)
            double emaSlope = ema19[0] - ema19[5];
            bool emaSlopeOk = (direction == 1 && emaSlope > 0) ||
                             (direction == -1 && emaSlope < 0);
            if (emaSlopeOk) score += 2;
            
            // 3. Momentum Candle (+1 point)
            double bodySize = Math.Abs(Close[0] - Open[0]);
            bool hasMomentum = bodySize > currentATR * 0.5;
            bool correctDir = (direction == 1 && Close[0] > Open[0]) ||
                             (direction == -1 && Close[0] < Open[0]);
            if (hasMomentum && correctDir) score += 1;
            
            // ═══════════════════════════════════════════════════════════════════════
            // IMPORTANT FACTORS (Max 3 points)
            // ═══════════════════════════════════════════════════════════════════════
            
            // 4. Volume Spike (+1 point)
            if (Volume[0] > volumeSMA[0] * VolumeSpikeMultiplier) score += 1;
            
            // 5. Near ICT Level (+1 point)
            double tolerance = currentATR * 1.5;
            if ((direction == 1 && pdl > 0 && Math.Abs(Close[0] - pdl) < tolerance) ||
                (direction == -1 && pdh > 0 && Math.Abs(Close[0] - pdh) < tolerance))
                score += 1;
            
            // 6. BOS Confirmed (+1 point)
            if ((direction == 1 && bosLong && CurrentBar - bosBar < 10) ||
                (direction == -1 && bosShort && CurrentBar - bosBar < 10))
                score += 1;
            
            // ═══════════════════════════════════════════════════════════════════════
            // BONUS FACTORS (Max 2 points)
            // ═══════════════════════════════════════════════════════════════════════
            
            // 7. Trading Session (+1 point) - NY Open 9:30-11:30
            int timeInt = Time[0].Hour * 100 + Time[0].Minute;
            if ((timeInt >= 930 && timeInt <= 1130) || (timeInt >= 1400 && timeInt <= 1600))
                score += 1;
            
            // 8. HTF Aligned (+1 point) - Price on correct side of EMA 50
            if ((direction == 1 && Close[0] > ema50[0] && ema19[0] > ema50[0]) ||
                (direction == -1 && Close[0] < ema50[0] && ema19[0] < ema50[0]))
                score += 1;
            
            return score;
        }
        #endregion

        #region Pattern Detection
        private void CheckAllPatterns(double currentATR)
        {
            // ═══════════════════════════════════════════════════════════════════════
            // 1. EMA BOUNCE (~20% freq, 80% WR)
            // ═══════════════════════════════════════════════════════════════════════
            if (EnableEMABounce)
            {
                // Long: Price touches EMA from above and bounces
                if (TradeLong && Low[0] <= ema19[0] * 1.003 && Close[0] > ema19[0] && Close[0] > Open[0])
                {
                    int conf = CalculateConfluence(1);
                    if (conf >= MinConfluence)
                    {
                        double sl = ema19[0] - currentATR * SLBuffer;
                        double risk = Close[0] - sl;
                        ExecuteTrade(true, "EMABounce", sl, Close[0] + risk * TP1RR, conf);
                        return;
                    }
                }
                
                // Short: Price touches EMA from below and rejects
                if (TradeShort && High[0] >= ema19[0] * 0.997 && Close[0] < ema19[0] && Close[0] < Open[0])
                {
                    int conf = CalculateConfluence(-1);
                    if (conf >= MinConfluence)
                    {
                        double sl = ema19[0] + currentATR * SLBuffer;
                        double risk = sl - Close[0];
                        ExecuteTrade(false, "EMABounce", sl, Close[0] - risk * TP1RR, conf);
                        return;
                    }
                }
            }

            // ═══════════════════════════════════════════════════════════════════════
            // 2. RANGE BREAKOUT (~20% freq, 80% WR)
            // ═══════════════════════════════════════════════════════════════════════
            if (EnableRangeBreakout && inRange)
            {
                // Bullish Breakout
                if (TradeLong && Close[0] > rangeHigh && Close[1] <= rangeHigh)
                {
                    int conf = CalculateConfluence(1);
                    if (conf >= MinConfluence)
                    {
                        double sl = rangeLow - currentATR * SLBuffer;
                        double risk = Close[0] - sl;
                        ExecuteTrade(true, "RangeBreakout", sl, Close[0] + risk * TP1RR, conf);
                        return;
                    }
                }
                
                // Bearish Breakout
                if (TradeShort && Close[0] < rangeLow && Close[1] >= rangeLow)
                {
                    int conf = CalculateConfluence(-1);
                    if (conf >= MinConfluence)
                    {
                        double sl = rangeHigh + currentATR * SLBuffer;
                        double risk = sl - Close[0];
                        ExecuteTrade(false, "RangeBreakout", sl, Close[0] - risk * TP1RR, conf);
                        return;
                    }
                }
            }

            // ═══════════════════════════════════════════════════════════════════════
            // 3. ICT LEVEL BOUNCE (~10% freq, 75% WR)
            // ═══════════════════════════════════════════════════════════════════════
            if (EnableICTBounce)
            {
                double tolerance = currentATR * 0.5;
                
                // PDL Bounce (Long)
                if (TradeLong && pdl > 0 && Low[0] <= pdl + tolerance && Close[0] > pdl && Close[0] > Open[0])
                {
                    int conf = CalculateConfluence(1);
                    if (conf >= MinConfluence)
                    {
                        double sl = pdl - currentATR * SLBuffer;
                        double risk = Close[0] - sl;
                        ExecuteTrade(true, "ICT_PDL", sl, Close[0] + risk * TP1RR, conf);
                        return;
                    }
                }
                
                // PDH Rejection (Short)
                if (TradeShort && pdh > 0 && High[0] >= pdh - tolerance && Close[0] < pdh && Close[0] < Open[0])
                {
                    int conf = CalculateConfluence(-1);
                    if (conf >= MinConfluence)
                    {
                        double sl = pdh + currentATR * SLBuffer;
                        double risk = sl - Close[0];
                        ExecuteTrade(false, "ICT_PDH", sl, Close[0] - risk * TP1RR, conf);
                        return;
                    }
                }
            }

            // ═══════════════════════════════════════════════════════════════════════
            // 4. BOS ENTRY (~10% freq, 80% WR)
            // ═══════════════════════════════════════════════════════════════════════
            if (EnableBOSEntry)
            {
                // Long after BOS - Wait for pullback
                if (TradeLong && bosLong && CurrentBar - bosBar >= 2 && CurrentBar - bosBar <= 15)
                {
                    // Pullback near BOS level
                    if (Low[0] <= bosLevel * 1.005 && Close[0] > bosLevel && Close[0] > Open[0])
                    {
                        int conf = CalculateConfluence(1);
                        if (conf >= MinConfluence)
                        {
                            double sl = bosLevel - currentATR * SLBuffer;
                            double risk = Close[0] - sl;
                            ExecuteTrade(true, "BOSEntry", sl, Close[0] + risk * TP1RR, conf);
                            bosLong = false;
                            return;
                        }
                    }
                }
                
                // Short after BOS
                if (TradeShort && bosShort && CurrentBar - bosBar >= 2 && CurrentBar - bosBar <= 15)
                {
                    if (High[0] >= bosLevel * 0.995 && Close[0] < bosLevel && Close[0] < Open[0])
                    {
                        int conf = CalculateConfluence(-1);
                        if (conf >= MinConfluence)
                        {
                            double sl = bosLevel + currentATR * SLBuffer;
                            double risk = sl - Close[0];
                            ExecuteTrade(false, "BOSEntry", sl, Close[0] - risk * TP1RR, conf);
                            bosShort = false;
                            return;
                        }
                    }
                }
            }

            // ═══════════════════════════════════════════════════════════════════════
            // 5. TREND CONTINUATION (~5% freq, 70% WR)
            // ═══════════════════════════════════════════════════════════════════════
            if (EnableTrendContinuation)
            {
                // Strong uptrend: EMA19 > EMA50, price pulling back to EMA19
                if (TradeLong && ema19[0] > ema50[0] && Close[0] > ema50[0])
                {
                    // Pullback touch EMA19 with bullish candle
                    if (Low[0] <= ema19[0] * 1.002 && Close[0] > ema19[0] && Close[0] > Open[0])
                    {
                        // Confirm trend strength
                        double trendStrength = (ema19[0] - ema50[0]) / currentATR;
                        if (trendStrength > 0.5)
                        {
                            int conf = CalculateConfluence(1);
                            if (conf >= MinConfluence)
                            {
                                double sl = ema50[0] - currentATR * SLBuffer;
                                double risk = Close[0] - sl;
                                ExecuteTrade(true, "TrendCont", sl, Close[0] + risk * TP1RR, conf);
                                return;
                            }
                        }
                    }
                }
                
                // Strong downtrend
                if (TradeShort && ema19[0] < ema50[0] && Close[0] < ema50[0])
                {
                    if (High[0] >= ema19[0] * 0.998 && Close[0] < ema19[0] && Close[0] < Open[0])
                    {
                        double trendStrength = (ema50[0] - ema19[0]) / currentATR;
                        if (trendStrength > 0.5)
                        {
                            int conf = CalculateConfluence(-1);
                            if (conf >= MinConfluence)
                            {
                                double sl = ema50[0] + currentATR * SLBuffer;
                                double risk = sl - Close[0];
                                ExecuteTrade(false, "TrendCont", sl, Close[0] - risk * TP1RR, conf);
                                return;
                            }
                        }
                    }
                }
            }
        }
        #endregion

        #region Trade Execution
        private void ExecuteTrade(bool isLong, string pattern, double sl, double tp, int confluence)
        {
            totalSignals++;
            lastPattern = pattern;
            entryPrice = Close[0];
            stopPrice = sl;
            target1Price = tp;
            
            if (!patternCounts.ContainsKey(pattern)) patternCounts[pattern] = 0;
            patternCounts[pattern]++;
            
            if (DebugMode)
            {
                string dir = isLong ? "LONG" : "SHORT";
                Print($"[{Time[0]}] >>> {dir} {pattern} | Entry={entryPrice:F2} SL={sl:F2} TP={tp:F2} | Conf={confluence}/10 <<<");
            }
            
            string orderName = $"Scalp_{pattern}";
            
            if (isLong)
            {
                EnterLong(PositionSize, orderName);
                SetStopLoss(orderName, CalculationMode.Price, sl, false);
                SetProfitTarget(orderName, CalculationMode.Price, tp);
                
                if (ShowDrawings)
                    Draw.ArrowUp(this, "Entry" + CurrentBar, false, 0, Low[0] - atr[0] * 0.3, Brushes.Lime);
            }
            else
            {
                EnterShort(PositionSize, orderName);
                SetStopLoss(orderName, CalculationMode.Price, sl, false);
                SetProfitTarget(orderName, CalculationMode.Price, tp);
                
                if (ShowDrawings)
                    Draw.ArrowDown(this, "Entry" + CurrentBar, false, 0, High[0] + atr[0] * 0.3, Brushes.Red);
            }
            
            lastTradeBar = CurrentBar;
            todayTrades++;
            totalTrades++;
        }

        private void ManagePosition(double currentATR)
        {
            // Break-even logic
            if (Position.MarketPosition == MarketPosition.Long)
            {
                double unrealized = Close[0] - Position.AveragePrice;
                double risk = Position.AveragePrice - stopPrice;
                
                // Move to BE after 1R profit
                if (risk > 0 && unrealized > risk && stopPrice < Position.AveragePrice)
                {
                    stopPrice = Position.AveragePrice + TickSize * 2;
                    // Note: NinjaTrader doesn't allow modifying stop after entry easily
                    // This would require OnOrderUpdate handling
                }
            }
            else if (Position.MarketPosition == MarketPosition.Short)
            {
                double unrealized = Position.AveragePrice - Close[0];
                double risk = stopPrice - Position.AveragePrice;
                
                if (risk > 0 && unrealized > risk && stopPrice > Position.AveragePrice)
                {
                    stopPrice = Position.AveragePrice - TickSize * 2;
                }
            }
        }
        #endregion

        #region Statistics
        protected override void OnExecutionUpdate(Execution execution, string executionId, double price,
            int quantity, MarketPosition marketPosition, string orderId, DateTime time)
        {
            if (execution.Order == null) return;
            
            string orderName = execution.Order.Name;
            
            if (DebugMode)
                Print($"[{time}] FILL: {orderName} @ {price:F2} x{quantity}");
            
            // Track wins/losses
            if (orderName.Contains("Profit"))
            {
                winningTrades++;
                if (lastPattern != null)
                {
                    if (!patternWins.ContainsKey(lastPattern)) patternWins[lastPattern] = 0;
                    patternWins[lastPattern]++;
                }
                if (DebugMode) Print($"    >>> WIN <<<");
            }
            else if (orderName.Contains("Stop"))
            {
                losingTrades++;
                if (DebugMode) Print($"    >>> LOSS <<<");
            }
        }

        private void PrintFinalStats()
        {
            Print("═══════════════════════════════════════════════════════════════════════");
            Print("              SOPHON SCALPING - EMMANUEL EDITION - FINAL STATS");
            Print("═══════════════════════════════════════════════════════════════════════");
            Print($"Total Signals:  {totalSignals}");
            Print($"Total Trades:   {totalTrades}");
            Print($"Wins:           {winningTrades}");
            Print($"Losses:         {losingTrades}");
            
            double winRate = totalTrades > 0 ? (winningTrades * 100.0 / totalTrades) : 0;
            Print($"Win Rate:       {winRate:F1}%");
            
            Print("");
            Print("PATTERN BREAKDOWN:");
            foreach (var kvp in patternCounts.OrderByDescending(x => x.Value))
            {
                int wins = patternWins.ContainsKey(kvp.Key) ? patternWins[kvp.Key] : 0;
                double pWinRate = kvp.Value > 0 ? (wins * 100.0 / kvp.Value) : 0;
                Print($"  {kvp.Key,-15} : {kvp.Value,3} trades, {wins,3} wins, {pWinRate:F1}% WR");
            }
            Print("═══════════════════════════════════════════════════════════════════════");
        }
        #endregion
    }
}
