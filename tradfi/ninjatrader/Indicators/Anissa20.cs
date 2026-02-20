#region Using declarations 
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;
using System.Windows;
using System.Windows.Media;
using System.Xml.Serialization;
using NinjaTrader.Cbi;
using NinjaTrader.Gui;
using NinjaTrader.Gui.Chart;
using NinjaTrader.NinjaScript;
using NinjaTrader.NinjaScript.DrawingTools;
using System.Net;
using NinjaTrader.Data;

#endregion

namespace NinjaTrader.NinjaScript.Indicators
{
    public class Anissa20 : Indicator
    {
        #region Variables & Constants
        private int cacheSize; // Number of bars used in swing validation (2*Strength+1)
        private double currentSwingHigh;
        private double currentSwingLow;
        private List<double> highCache;
        private List<double> lowCache;
        private double lastSwingHighValue;
        private double lastSwingLowValue;
        private int saveCurrentBar;

        // Flags to prevent multiple BOS signals per swing
        private bool bullishBreakDetected;
        private bool bearishBreakDetected;

        // Series used for swing calculation
        private Series<double> swingHighSeries;
        private Series<double> swingHighSwings;
        private Series<double> swingLowSeries;
        private Series<double> swingLowSwings;

        // Daily extremes for retracements
        private double dailyHighestSwingHigh = double.MinValue;
        private double dailyLowestSwingLow = double.MaxValue;
        private DateTime currentDay = DateTime.MinValue;

        // Alert flags to prevent duplicate alerts per structure
        private bool bullishEntryAlertSent = false;
        private bool bearishEntryAlertSent = false;

        // Last session label to avoid re-drawing tags every bar
        private string lastSessionLabel = string.Empty;

        // Tolerance for swing comparisons
        private const double SwingTolerance = 0.0001;

        // --- Additional Structure Concept Variables ---
        // Track previous swing levels to detect CHoCH.
        private double previousSwingHigh = 0;
        private double previousSwingLow = 0;
        private bool bullishCHoCHDetected = false;
        private bool bearishCHoCHDetected = false;

        // --- Module Instances ---
        private OrderBlockModule orderBlockModule;
        private FairValueGapModule fvgModule;
        private LiquidityModule liquidityModule;

        // --- Fibonacci update tracking ---
        private DateTime lastFibonacciUpdate = DateTime.MinValue;
		
		private DateTime indicatorStartTime = DateTime.MinValue;
		private int secondaryTelegramAlertCount = 0;
		private const int MaxSecondaryTelegramAlerts = 3;
		
		private Dictionary<int, Anissa20Logic> marketLogics = new Dictionary<int, Anissa20Logic>();

        #endregion

        #region Indicator Parameters
        [NinjaScriptProperty]
        [Range(1, int.MaxValue)]
        [Display(Name = "Strength", Order = 1, GroupName = "Parameters")]
        public int Strength { get; set; }

        [NinjaScriptProperty]
        [Range(1, int.MaxValue)]
        [Display(Name = "BreakThresholdTicks", Order = 2, GroupName = "Parameters")]
        public int BreakThresholdTicks { get; set; }

        // Order Block parameters
        [NinjaScriptProperty]
        [Display(Name = "Plot Orderblocks", Order = 3, GroupName = "Parameters")]
        public bool PlotOrderblocks { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Orderblock Extension Bars", Order = 4, GroupName = "Parameters")]
        public int OrderblockExtensionBars { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Bullish Orderblock Color", Order = 5, GroupName = "Parameters")]
        public Brush BullishOrderblockColor { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Bearish Orderblock Color", Order = 6, GroupName = "Parameters")]
        public Brush BearishOrderblockColor { get; set; }

        // Fair Value Gap (FVG) parameters
        [NinjaScriptProperty]
        [Display(Name = "Plot Fair Value Gaps", Order = 7, GroupName = "SMC/ICT")]
        public bool PlotFairValueGaps { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "FVG Extension Bars", Order = 8, GroupName = "SMC/ICT")]
        [Range(0, int.MaxValue)]
        public int FvgExtensionBars { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "FVG Min Size (Ticks)", Order = 9, GroupName = "SMC/ICT")]
        [Range(1, int.MaxValue)]
        public int FvgMinSizeTicks { get; set; }

        // Liquidity Lines parameters
        [NinjaScriptProperty]
        [Display(Name = "Plot Liquidity Lines", Order = 10, GroupName = "SMC/ICT")]
        public bool PlotLiquidityLines { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Liquidity Tolerance (Ticks)", Order = 11, GroupName = "SMC/ICT")]
        [Range(0, int.MaxValue)]
        public int LiquidityToleranceTicks { get; set; }

        // Alert configuration parameters
        [NinjaScriptProperty]
        [Display(Name = "Send Email Alerts", Order = 12, GroupName = "Alerts")]
        public bool SendEmailAlerts { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Enable Sound Alerts", Order = 13, GroupName = "Alerts")]
        public bool EnableSoundAlerts { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Alert Sound File", Order = 14, GroupName = "Alerts")]
        public string AlertSoundFile { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Alert Message Prefix", Order = 15, GroupName = "Alerts")]
        public string AlertMessagePrefix { get; set; }

        // Session configuration parameters
        [NinjaScriptProperty]
        [Display(Name = "Use Custom Session Times", Order = 16, GroupName = "Sessions")]
        public bool UseCustomSessionTimes { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "New York Session Start", Order = 17, GroupName = "Sessions")]
        public TimeSpan NewYorkSessionStart { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "New York Session End", Order = 18, GroupName = "Sessions")]
        public TimeSpan NewYorkSessionEnd { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "London Session Start", Order = 19, GroupName = "Sessions")]
        public TimeSpan LondonSessionStart { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "London Session End", Order = 20, GroupName = "Sessions")]
        public TimeSpan LondonSessionEnd { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Asian Session Start", Order = 21, GroupName = "Sessions")]
        public TimeSpan AsianSessionStart { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Asian Session End", Order = 22, GroupName = "Sessions")]
        public TimeSpan AsianSessionEnd { get; set; }

        // Optional description text for plots
        [NinjaScriptProperty]
        [Display(Name = "Show Plot Descriptions", Order = 23, GroupName = "Descriptions")]
        public bool ShowPlotDescriptions { get; set; }
		
		[NinjaScriptProperty]
		[Display(Name = "Secondary Telegram Bot Token", Order = 300, GroupName = "Telegram Settings")]
		public string SecondaryTelegramBotToken { get; set; }
		
		[NinjaScriptProperty]
		[Display(Name = "Secondary Telegram Chat ID", Order = 301, GroupName = "Telegram Settings")]
		public string SecondaryTelegramChatID { get; set; }
		
		[NinjaScriptProperty]
		[Display(Name = "Afficher Dashboard", Order = 50, GroupName = "Affichage")]
		public bool AfficherDashboard { get; set; }

        #endregion

        #region Public Properties
        [Browsable(false)]
        [XmlIgnore]
        public Series<double> SwingHighPlot { get { return Values[0]; } }

        [Browsable(false)]
        [XmlIgnore]
        public Series<double> SwingLowPlot { get { return Values[1]; } }

        [Browsable(false)]
        [XmlIgnore]
        public Series<double> BreakUpPlot { get { return Values[2]; } }

        [Browsable(false)]
        [XmlIgnore]
        public Series<double> BreakDownPlot { get { return Values[3]; } }

        [Browsable(false)]
        [XmlIgnore]
        public Series<double> EntrySignalPlot { get { return Values[4]; } }

        // CHoCH and MSB plots (indexes 5 and 6 respectively)
        [Browsable(false)]
        [XmlIgnore]
        public Series<double> CHoCHPlot { get { return Values[5]; } }

        [Browsable(false)]
        [XmlIgnore]
        public Series<double> MSBPlot { get { return Values[6]; } }

        [Browsable(false)]
        [XmlIgnore]
        public double LastSwingHigh { get { return lastSwingHighValue; } }

        [Browsable(false)]
        [XmlIgnore]
        public double LastSwingLow { get { return lastSwingLowValue; } }
        #endregion

        #region Strategy-Level Properties
        // Expose key internal data for strategy use.
        [Browsable(false)]
        [XmlIgnore]
        public double LastBullishOBTop { get { return orderBlockModule.LastBullishOBTop; } }

        [Browsable(false)]
        [XmlIgnore]
        public double LastBullishOBBottom { get { return orderBlockModule.LastBullishOBBottom; } }

        [Browsable(false)]
        [XmlIgnore]
        public double LastBearishOBTop { get { return orderBlockModule.LastBearishOBTop; } }

        [Browsable(false)]
        [XmlIgnore]
        public double LastBearishOBBottom { get { return orderBlockModule.LastBearishOBBottom; } }

        [Browsable(false)]
        [XmlIgnore]
        public bool BullishCHoCH { get { return bullishCHoCHDetected; } }

        [Browsable(false)]
        [XmlIgnore]
        public bool BearishCHoCH { get { return bearishCHoCHDetected; } }
        #endregion

        #region State Management
        protected override void OnStateChange()
        {
            if (State == State.SetDefaults)
            {
                Description = "Swing indicator with break-of-structure, orderblock plotting, and SMC/ICT additions including CHoCH, MSB, and enhanced alert/session configurability.";
                Name = "Anissa20";
                Calculate = Calculate.OnBarClose;
                IsOverlay = true;
                DisplayInDataBox = false;
                PaintPriceMarkers = false;
                IsSuspendedWhileInactive = true;

                // Default technical parameter values
                Strength = 5;
                BreakThresholdTicks = 2;
                PlotOrderblocks = true;
                OrderblockExtensionBars = 5;
                BullishOrderblockColor = Brushes.LightGreen;
                BearishOrderblockColor = Brushes.LightPink;
                PlotFairValueGaps = false;
                FvgExtensionBars = 5;
                FvgMinSizeTicks = 2;
                PlotLiquidityLines = false;
                LiquidityToleranceTicks = 1;

                // Default alert configuration
                SendEmailAlerts = false;
                EnableSoundAlerts = false;
                AlertSoundFile = "";
                AlertMessagePrefix = "";

                // Default session configuration
                UseCustomSessionTimes = false;
                NewYorkSessionStart = new TimeSpan(9, 0, 0);
                NewYorkSessionEnd = new TimeSpan(15, 30, 0);
                LondonSessionStart = new TimeSpan(2, 30, 0);
                LondonSessionEnd = new TimeSpan(9, 0, 0);
                AsianSessionStart = new TimeSpan(17, 30, 0);
                AsianSessionEnd = new TimeSpan(1, 30, 0);

                // Default optional feature: do not show text descriptions by default.
                ShowPlotDescriptions = false;

                // Configure plots (indexes: 0=SwingHigh, 1=SwingLow, 2=BreakUp, 3=BreakDown, 4=Entry, 5=CHoCH, 6=MSB)
                AddPlot(new Stroke(Brushes.DarkCyan, 2), PlotStyle.Dot, "SwingHighPlot");
                AddPlot(new Stroke(Brushes.Goldenrod, 2), PlotStyle.Dot, "SwingLowPlot");
                AddPlot(Brushes.Green, "BreakUpPlot");
                AddPlot(Brushes.Red, "BreakDownPlot");
                AddPlot(Brushes.Blue, "EntrySignalPlot");
                AddPlot(Brushes.Purple, "CHoCHPlot");
                AddPlot(Brushes.Orange, "MSBPlot");
				
				// Paramètres Telegram secondaires (pour alertes spéciales confluence)
				SecondaryTelegramBotToken = "8148620113:AAGSysjSL2VWGo-B_AcM97deVJUTvIC1jmo";
				SecondaryTelegramChatID = "7138060180";
				
				AfficherDashboard = true;
            }
            else if (State == State.Configure)
            {
                currentSwingHigh = 0;
                currentSwingLow = 0;
                lastSwingHighValue = 0;
                lastSwingLowValue = 0;
                saveCurrentBar = -1;
                cacheSize = 2 * Strength + 1;
                bullishBreakDetected = false;
                bearishBreakDetected = false;
                Calculate = Calculate.OnBarClose;
				
				AddDataSeries("MNQ 09-25", BarsPeriodType.Minute, 15);
				AddDataSeries("MYM 09-25", BarsPeriodType.Minute, 15);
            }
            else if (State == State.DataLoaded)
			{
			    highCache = new List<double>();
			    lowCache = new List<double>();
			
			    swingHighSeries = new Series<double>(this);
			    swingHighSwings = new Series<double>(this);
			    swingLowSeries = new Series<double>(this);
			    swingLowSwings = new Series<double>(this);
			
			    // Modules
			    orderBlockModule = new OrderBlockModule(this);
			    fvgModule = new FairValueGapModule(this, FvgExtensionBars, FvgMinSizeTicks);
			    liquidityModule = new LiquidityModule(this, LiquidityToleranceTicks);
				
				indicatorStartTime = DateTime.Now;
				
				marketLogics[0] = new Anissa20Logic(this, 0, Strength, BreakThresholdTicks);
				marketLogics[1] = new Anissa20Logic(this, 1, Strength, BreakThresholdTicks);
				marketLogics[2] = new Anissa20Logic(this, 2, Strength, BreakThresholdTicks);
			
			    // ✅ Envoi message Telegram dès que l’indicateur est prêt
			    if (!string.IsNullOrWhiteSpace(SecondaryTelegramBotToken) && !string.IsNullOrWhiteSpace(SecondaryTelegramChatID))
			    {
			        string msg = $"✅ Indicateur 'Anissa20' prêt sur {Bars.Instrument.FullName} @ {DateTime.Now:HH:mm:ss}";
			        SendSecondaryTelegramStatus(msg);
			    }	

			}			
			else if (State == State.Terminated)
			{
			    if (!string.IsNullOrWhiteSpace(SecondaryTelegramBotToken) && !string.IsNullOrWhiteSpace(SecondaryTelegramChatID))
			    {
			        TimeSpan duration = DateTime.Now - indicatorStartTime;
			        string instrument = Bars?.Instrument?.FullName ?? "instrument inconnu";
			
			        string formattedDuration = $"{(int)duration.TotalHours}h {duration.Minutes}m {duration.Seconds}s";
			
			        string msg = $"⛔ Indicateur 'Anissa20' déconnecté de {instrument} @ {DateTime.Now:HH:mm:ss}\n" +
			                     $"⏱️ Durée d'utilisation : {formattedDuration}";
			
			        SendSecondaryTelegramStatus(msg);
			    }
			}
        }
        #endregion

        #region OnBarUpdate Processing
        protected override void OnBarUpdate()
        {
            if (CurrentBar < 0)
                return;

            double high0 = High[0];
            double low0 = Low[0];
            double close0 = Close[0];

            // Handle removal of the last bar scenario
            if (BarsArray[0].BarsType.IsRemoveLastBarSupported && CurrentBar < saveCurrentBar)
            {
                currentSwingHigh = SwingHighPlot.IsValidDataPoint(0) ? SwingHighPlot[0] : 0;
                currentSwingLow = SwingLowPlot.IsValidDataPoint(0) ? SwingLowPlot[0] : 0;
                lastSwingHighValue = swingHighSeries[0];
                lastSwingLowValue = swingLowSeries[0];
                swingHighSeries[Strength] = 0;
                swingLowSeries[Strength] = 0;

                highCache.Clear();
                lowCache.Clear();
                for (int i = Math.Min(CurrentBar, cacheSize) - 1; i >= 0; i--)
                {
                    highCache.Add(High[i]);
                    lowCache.Add(Low[i]);
                }
                saveCurrentBar = CurrentBar;
                return;
            }

            // Process new bar only once
            if (saveCurrentBar != CurrentBar)
            {
                ResetSeriesForCurrentBar();
                UpdateCaches(high0, low0);

                if (highCache.Count == cacheSize)
                    ProcessSwingHigh(close0, high0);
                if (lowCache.Count == cacheSize)
                    ProcessSwingLow(close0, low0);

                saveCurrentBar = CurrentBar;
            }

            if (CurrentBar < cacheSize)
                return;

            ClearBreakPlots();
            double breakThresholdValue = BreakThresholdTicks * TickSize;

            // Break-of-Structure detection
            if (lastSwingHighValue > 0 && !bullishBreakDetected && close0 > lastSwingHighValue + breakThresholdValue)
            {
                bullishBreakDetected = true;
                Values[2][0] = close0;
                Draw.ArrowUp(this, "BreakUp" + CurrentBar, true, 0, low0 - 2 * TickSize, Brushes.Green);
                if (ShowPlotDescriptions)
                    Draw.Text(this, "Desc_BreakUp" + CurrentBar, "Break Up", 0, low0 - 3 * TickSize, Brushes.Green);
            }
            if (lastSwingLowValue > 0 && !bearishBreakDetected && close0 < lastSwingLowValue - breakThresholdValue)
            {
                bearishBreakDetected = true;
                Values[3][0] = close0;
                Draw.ArrowDown(this, "BreakDown" + CurrentBar, true, 0, high0 + 2 * TickSize, Brushes.Red);
                if (ShowPlotDescriptions)
                    Draw.Text(this, "Desc_BreakDown" + CurrentBar, "Break Down", 0, high0 + 3 * TickSize, Brushes.Red);
            }

            // Entry signal detection
            if (PlotOrderblocks)
                DetectEntryPoints();

            // Session and daily analysis
            PlotSessions();
            UpdateDailySwingExtremes();
            // Update Fibonacci retracements every two hours
            if (lastFibonacciUpdate == DateTime.MinValue || Time[0] >= lastFibonacciUpdate.AddHours(2))
            {
                PlotDailyFibonacciRetracements();
                lastFibonacciUpdate = Time[0];
            }

            // Modularized FVG and Liquidity lines (only when enabled)
            if (PlotFairValueGaps && CurrentBar > 1)
                fvgModule.DetectAndPlotFVG();
            if (PlotLiquidityLines && CurrentBar > 1)
                liquidityModule.DetectLiquidityLines();
			
			if (!marketLogics.ContainsKey(BarsInProgress))
			    return;
			
			marketLogics[BarsInProgress].UpdateBar();
			
			// Lorsqu’on traite la série principale
			if (BarsInProgress == 0)
			{
			    bool mes = marketLogics[0].DetectedBullishMSB;
			    bool mnq = marketLogics[1].DetectedBullishMSB;
			    bool mym = marketLogics[2].DetectedBullishMSB;
			
			    if ((mes && mnq) || (mes && mym) || (mnq && mym))
			    {
			        string msg = $"🚀 Signal haussier multi-marché détecté @ {Time[0]:HH:mm:ss}\n" +
			                     $"→ MES: {(mes ? "✅" : "❌")}, MNQ: {(mnq ? "✅" : "❌")}, MYM: {(mym ? "✅" : "❌")}";
			        SendSecondaryTelegramStatus(msg);
			    }
				
				bool mesBear = marketLogics[0].DetectedBearishMSB;
				bool mnqBear = marketLogics[1].DetectedBearishMSB;
				bool mymBear = marketLogics[2].DetectedBearishMSB;
				
				if ((mesBear && mnqBear) || (mesBear && mymBear) || (mnqBear && mymBear))
				{
				    string msg = $"🔻 Signal baissier multi-marché détecté @ {Time[0]:HH:mm:ss}\n" +
				                 $"→ MES: {(mesBear ? "✅" : "❌")}, MNQ: {(mnqBear ? "✅" : "❌")}, MYM: {(mymBear ? "✅" : "❌")}";
				    SendSecondaryTelegramStatus(msg);
				}
			
			    foreach (var logic in marketLogics.Values)
			        logic.ResetSignals();
			}

            // Additional structure: MSB detection
            DetectMSB();
			DetectPerfectConfluence();
			
			if (AfficherDashboard)
			{
			    DrawDashboard();
			    DetectAndMarkPerfectConfluence();
				DetectAndLogPerfectConfluence();
			}
        }
        #endregion

        #region Swing Processing Methods
        private void ResetSeriesForCurrentBar()
        {
            swingHighSwings[0] = 0;
            swingLowSwings[0] = 0;
            swingHighSeries[0] = 0;
            swingLowSeries[0] = 0;
        }

        private void UpdateCaches(double high0, double low0)
        {
            highCache.Add(high0);
            if (highCache.Count > cacheSize)
                highCache.RemoveAt(0);

            lowCache.Add(low0);
            if (lowCache.Count > cacheSize)
                lowCache.RemoveAt(0);
        }

        private bool ValidateSwing(List<double> cache, int centerIndex, bool isHigh)
        {
            double candidate = cache[centerIndex];
            for (int i = 0; i < cache.Count; i++)
            {
                if (i == centerIndex)
                    continue;
                if (isHigh && cache[i] > candidate + SwingTolerance)
                    return false;
                if (!isHigh && cache[i] < candidate - SwingTolerance)
                    return false;
            }
            return true;
        }

        private void ProcessSwingHigh(double close0, double high0)
        {
            int centerIndex = Strength;
            double candidate = highCache[centerIndex];
            bool isSwingHigh = ValidateSwing(highCache, centerIndex, true);
            swingHighSwings[Strength] = isSwingHigh ? candidate : 0.0;

            if (isSwingHigh)
            {
                // Reset bullish break detection flag on new swing high
                bullishBreakDetected = false;

                // CHoCH detection for swing high
                if (previousSwingHigh != 0 && candidate < previousSwingHigh - (BreakThresholdTicks * TickSize))
                {
                    bearishCHoCHDetected = true;
                    Values[5][0] = candidate;
                    Draw.Diamond(this, "CHoCH_Bear_" + CurrentBar, true, 0, candidate, Brushes.Purple);
                    if (ShowPlotDescriptions)
                        Draw.Text(this, "Desc_CHoCH_Bear_" + CurrentBar, "CHoCH Bear", 0, candidate + 2 * TickSize, Brushes.Purple);
                }
                previousSwingHigh = candidate;
                lastSwingHighValue = candidate;
                bullishEntryAlertSent = false;
                currentSwingHigh = candidate;

                if (PlotOrderblocks)
                    orderBlockModule.DrawOrderBlock(false, Strength, OrderblockExtensionBars, BearishOrderblockColor, out double obTop, out double obBottom);

                for (int i = 0; i <= Strength; i++)
                {
                    SwingHighPlot[i] = currentSwingHigh;
                    swingHighSeries[i] = lastSwingHighValue;
                }
                if (ShowPlotDescriptions)
                    Draw.Text(this, "Desc_SwingHigh_" + CurrentBar, "Swing High", 0, candidate + 2 * TickSize, Brushes.DarkCyan);
            }
            else if (high0 > currentSwingHigh || Math.Abs(currentSwingHigh) < SwingTolerance)
            {
                currentSwingHigh = 0.0;
                SwingHighPlot[0] = close0;
            }
            else
            {
                SwingHighPlot[0] = currentSwingHigh;
            }
        }

        private void ProcessSwingLow(double close0, double low0)
        {
            int centerIndex = Strength;
            double candidate = lowCache[centerIndex];
            bool isSwingLow = ValidateSwing(lowCache, centerIndex, false);
            swingLowSwings[Strength] = isSwingLow ? candidate : 0.0;

            if (isSwingLow)
            {
                // Reset bearish break detection flag on new swing low
                bearishBreakDetected = false;

                // CHoCH detection for swing low
                if (previousSwingLow != 0 && candidate > previousSwingLow + (BreakThresholdTicks * TickSize))
                {
                    bullishCHoCHDetected = true;
                    Values[5][0] = candidate;
                    Draw.Diamond(this, "CHoCH_Bull_" + CurrentBar, true, 0, candidate, Brushes.Purple);
                    if (ShowPlotDescriptions)
                        Draw.Text(this, "Desc_CHoCH_Bull_" + CurrentBar, "CHoCH Bull", 0, candidate - 2 * TickSize, Brushes.Purple);
                }
                previousSwingLow = candidate;
                lastSwingLowValue = candidate;
                bearishEntryAlertSent = false;
                currentSwingLow = candidate;

                if (PlotOrderblocks)
                    orderBlockModule.DrawOrderBlock(true, Strength, OrderblockExtensionBars, BullishOrderblockColor, out double obTop, out double obBottom);

                for (int i = 0; i <= Strength; i++)
                {
                    SwingLowPlot[i] = currentSwingLow;
                    swingLowSeries[i] = lastSwingLowValue;
                }
                if (ShowPlotDescriptions)
                    Draw.Text(this, "Desc_SwingLow_" + CurrentBar, "Swing Low", 0, candidate - 2 * TickSize, Brushes.Goldenrod);
            }
            else if (low0 < currentSwingLow || Math.Abs(currentSwingLow) < SwingTolerance)
            {
                currentSwingLow = double.MaxValue;
                SwingLowPlot[0] = close0;
            }
            else
            {
                SwingLowPlot[0] = currentSwingLow;
            }
        }
        #endregion

        #region Break-of-Structure, Alerts & Additional Structure Concepts
        private void ClearBreakPlots()
        {
            Values[2][0] = 0;
            Values[3][0] = 0;
        }

        private void SendEmailAlert(string entryType, double price)
        {
            if (!SendEmailAlerts)
                return;

            string prefix = string.IsNullOrEmpty(AlertMessagePrefix) ? "" : AlertMessagePrefix + " ";
            string subject = prefix + entryType + " Signal";
            string message = $"{prefix}{entryType} detected at {price} on {Bars.Instrument.FullName} @ {Time[0]}";
            Print($"Email Alert: {subject} - {message}");
            Share("MyGmailAlert", subject, message);

            if (EnableSoundAlerts && !string.IsNullOrEmpty(AlertSoundFile))
                PlaySound(AlertSoundFile);
        }

        private void DetectEntryPoints()
        {
            Values[4][0] = 0;
            double barHigh = High[0];
            double barLow = Low[0];
            double entryPrice = (barHigh + barLow) / 2.0;

            // Bullish entry logic
            if (bullishBreakDetected && orderBlockModule.LastBullishOBSet &&
                (barLow <= orderBlockModule.LastBullishOBTop && barHigh >= orderBlockModule.LastBullishOBBottom) &&
                !bullishEntryAlertSent)
            {
                Values[4][0] = entryPrice;
                Draw.Diamond(this, "BullEntry_" + CurrentBar, true, 0, entryPrice, Brushes.Blue);
                if (ShowPlotDescriptions)
                    Draw.Text(this, "Desc_BullEntry_" + CurrentBar, "Bullish Entry", 0, entryPrice + 2 * TickSize, Brushes.Blue);
                SendEmailAlert("Bullish Entry", entryPrice);
                bullishEntryAlertSent = true;
            }
            // Bearish entry logic
            if (bearishBreakDetected && orderBlockModule.LastBearishOBSet &&
                (barHigh >= orderBlockModule.LastBearishOBBottom && barLow <= orderBlockModule.LastBearishOBTop) &&
                !bearishEntryAlertSent)
            {
                Values[4][0] = entryPrice;
                Draw.Diamond(this, "BearEntry_" + CurrentBar, true, 0, entryPrice, Brushes.Blue);
                if (ShowPlotDescriptions)
                    Draw.Text(this, "Desc_BearEntry_" + CurrentBar, "Bearish Entry", 0, entryPrice - 2 * TickSize, Brushes.Blue);
                SendEmailAlert("Bearish Entry", entryPrice);
                bearishEntryAlertSent = true;
            }
        }

        private void DetectMSB()
        {
            double breakThresholdValue = BreakThresholdTicks * TickSize;
            if (bearishCHoCHDetected && Close[0] < lastSwingLowValue - breakThresholdValue)
            {
                Values[6][0] = Close[0];
                Draw.Diamond(this, "MSB_Bear_" + CurrentBar, true, 0, Close[0], Brushes.Orange);
                if (ShowPlotDescriptions)
                    Draw.Text(this, "Desc_MSB_Bear_" + CurrentBar, "MSB Bear", 0, Close[0] - 2 * TickSize, Brushes.Orange);
                bearishCHoCHDetected = false;
            }
            if (bullishCHoCHDetected && Close[0] > lastSwingHighValue + breakThresholdValue)
            {
                Values[6][0] = Close[0];
                Draw.Diamond(this, "MSB_Bull_" + CurrentBar, true, 0, Close[0], Brushes.Orange);
                if (ShowPlotDescriptions)
                    Draw.Text(this, "Desc_MSB_Bull_" + CurrentBar, "MSB Bull", 0, Close[0] + 2 * TickSize, Brushes.Orange);
                bullishCHoCHDetected = false;
            }
        }
        #endregion

        #region Session & Daily Analysis
		
        private void PlotSessions()
        {
            if (CurrentBar < 1)
                return;

            string prevSession = GetSessionLabel(Time[1]);
            string currSession = GetSessionLabel(Time[0]);

            if (prevSession != currSession || currSession != lastSessionLabel)
            {
                string lineTag = "SessionLine_" + CurrentBar;
                string textTag = "SessionLabel_" + CurrentBar;
                Draw.VerticalLine(this, lineTag, 0, Brushes.Gray);
                Draw.Text(this, textTag, currSession, 0, High[0] + 2 * TickSize, Brushes.Yellow);
                lastSessionLabel = currSession;
            }
        }

        private string GetSessionLabel(DateTime time)
        {
            if (UseCustomSessionTimes)
            {
                TimeSpan t = time.TimeOfDay;
                if (t >= NewYorkSessionStart && t < NewYorkSessionEnd)
                    return "New York";
                else if (t >= LondonSessionStart && t < LondonSessionEnd)
                    return "London";
                else if (t >= AsianSessionStart || t < AsianSessionEnd)
                    return "Asian";
                else
                    return "Off Hours";
            }
            else
            {
                TimeZoneInfo estZone = TimeZoneInfo.FindSystemTimeZoneById("Eastern Standard Time");
                DateTime timeEST = TimeZoneInfo.ConvertTime(time, estZone);
                TimeSpan t = timeEST.TimeOfDay;

                TimeSpan nyStart = new TimeSpan(9, 0, 0);
                TimeSpan nyEnd = new TimeSpan(15, 30, 0);
                TimeSpan nyMorningEnd = new TimeSpan(12, 30, 0);
                TimeSpan nyAfternoonStart = new TimeSpan(13, 30, 0);
                TimeSpan londonStart = new TimeSpan(2, 30, 0);
                TimeSpan asianStart = new TimeSpan(17, 30, 0);
                TimeSpan asianEnd = new TimeSpan(1, 30, 0);

                if (t >= nyStart && t < nyEnd)
                {
                    if (t < nyMorningEnd)
                        return "New York Morning (Optimal)";
                    else if (t >= nyAfternoonStart)
                        return "New York Afternoon (Optimal)";
                    else
                        return "New York";
                }
                else if (t >= londonStart && t < nyStart)
                {
                    return "London";
                }
                else if (t >= asianStart || t < asianEnd)
                {
                    return "Asian";
                }
                else
                {
                    return "Off Hours";
                }
            }
        }

        private void UpdateDailySwingExtremes()
        {
            if (Time[0].Date != currentDay)
            {
                currentDay = Time[0].Date;
                dailyHighestSwingHigh = (lastSwingHighValue > 0) ? lastSwingHighValue : High[0];
                dailyLowestSwingLow = (lastSwingLowValue > 0 && lastSwingLowValue != double.MaxValue) ? lastSwingLowValue : Low[0];
                lastFibonacciUpdate = Time[0]; // reset fibonacci update on new day
            }
            else
            {
                if (lastSwingHighValue > dailyHighestSwingHigh)
                    dailyHighestSwingHigh = lastSwingHighValue;
                if (lastSwingLowValue < dailyLowestSwingLow && lastSwingLowValue != 0 && lastSwingLowValue != double.MaxValue)
                    dailyLowestSwingLow = lastSwingLowValue;
            }
        }

        private void PlotDailyFibonacciRetracements()
        {
            if (dailyHighestSwingHigh == double.MinValue || dailyLowestSwingLow == double.MaxValue)
                return;

            double highVal = dailyHighestSwingHigh;
            double lowVal = dailyLowestSwingLow;
            double range = highVal - lowVal;
            double[] fibPercents = new double[] { 0.0, 0.236, 0.382, 0.5, 0.618, 1.0 };

            foreach (double fib in fibPercents)
            {
                double levelPrice = highVal - (range * fib);
                string tag = "DailyFib_" + fib.ToString("0.000");
                Draw.HorizontalLine(this, tag, levelPrice, Brushes.LightBlue);
                if (ShowPlotDescriptions)
                    Draw.Text(this, tag + "_Desc", $"Fib {fib:P0}", 0, levelPrice, Brushes.LightBlue);
            }
        }
		
		private void SendSpecialTelegramAlert(string message)
		{
		    if (string.IsNullOrEmpty(SecondaryTelegramBotToken) || string.IsNullOrEmpty(SecondaryTelegramChatID))
		        return;
		
		    string url = $"https://api.telegram.org/bot{SecondaryTelegramBotToken}/sendMessage?chat_id={SecondaryTelegramChatID}&text={Uri.EscapeDataString(message)}";
		
		    try
		    {
		        HttpWebRequest request = (HttpWebRequest)WebRequest.Create(url);
		        using (HttpWebResponse response = (HttpWebResponse)request.GetResponse())
		        {
		            // Optionnel : log du succès
		        }
		    }
		    catch (Exception ex)
		    {
		        Print("Special Telegram alert error: " + ex.Message);
		    }
		}
		
		private void DetectPerfectConfluence()
		{
		    // S'assurer que les plots sont valides sur cette bougie
		    bool bullishConfluence = MSBPlot[0] > 0 && EntrySignalPlot[0] > 0 && BreakUpPlot[0] > 0;
		    bool bearishConfluence = MSBPlot[0] > 0 && EntrySignalPlot[0] > 0 && BreakDownPlot[0] > 0;
		
		    if (bullishConfluence)
		    {
		        string message = $"🔥 Perfect Bullish Confluence Detected on {Bars.Instrument.FullName} @ {Time[0]}\nMSB ✅ | Entry ✅ | BreakUp ✅";
		        SendSpecialTelegramAlert(message);
		    }
		
		    if (bearishConfluence)
		    {
		        string message = $"🔥 Perfect Bearish Confluence Detected on {Bars.Instrument.FullName} @ {Time[0]}\nMSB ✅ | Entry ✅ | BreakDown ✅";
		        SendSpecialTelegramAlert(message);
		    }
		}
		
		private void DetectAndMarkPerfectConfluence()
		{
		    bool bullishConfluence = MSBPlot[0] > 0 && EntrySignalPlot[0] > 0 && BreakUpPlot[0] > 0;
		    bool bearishConfluence = MSBPlot[0] > 0 && EntrySignalPlot[0] > 0 && BreakDownPlot[0] > 0;
		
		    if (!bullishConfluence && !bearishConfluence)
		        return;
		
		    // Analyse du marché
		    double vol = Volume[0];
		    double body = Math.Abs(Close[0] - Open[0]);
		    double range = High[0] - Low[0];
		    double bodyRatio = body / (range + TickSize);
		
		    double avgVol = SMA(Volume, 20)[0];
		    double volRatio = vol / (avgVol + 1);
		
		    bool strongBullCandle = Close[0] > Open[0] && bodyRatio > 0.6;
		    bool strongBearCandle = Close[0] < Open[0] && bodyRatio > 0.6;
		
		    bool aboveSwing = Close[0] > lastSwingHighValue + 2 * TickSize;
		    bool belowSwing = Close[0] < lastSwingLowValue - 2 * TickSize;
		
		    string bias = "Neutral";
		    if (strongBullCandle && volRatio > 1.2 && aboveSwing)
		        bias = "Bullish";
		    else if (strongBearCandle && volRatio > 1.2 && belowSwing)
		        bias = "Bearish";
		
		    // Affichage
		    string tag = "PerfectConfluence_" + CurrentBar;
		    double y = bullishConfluence ? Low[0] - 4 * TickSize : High[0] + 4 * TickSize;
		    Brush color = bullishConfluence ? Brushes.LimeGreen : Brushes.Red;
		    Brush biasColor = bias == "Bullish" ? Brushes.LightGreen :
		                      bias == "Bearish" ? Brushes.OrangeRed : Brushes.Gray;
		
		    string dir = bullishConfluence ? "Bullish" : "Bearish";
		
		    Draw.Text(this, tag, "★", 0, y, color);
		    Draw.Text(this, tag + "_info", $"Signal: {dir}\nBias: {bias}", 0, y + (bullishConfluence ? -2 : 2) * TickSize, biasColor);
		}
		
		private void SendSecondaryTelegramStatus(string message)
		{
		    if (State != State.Realtime)
		        return;
		
		    if (secondaryTelegramAlertCount >= MaxSecondaryTelegramAlerts)
		        return;
		
		    if (string.IsNullOrWhiteSpace(SecondaryTelegramBotToken) || string.IsNullOrWhiteSpace(SecondaryTelegramChatID))
		        return;
		
		    string url = $"https://api.telegram.org/bot{SecondaryTelegramBotToken}/sendMessage?chat_id={SecondaryTelegramChatID}&text={Uri.EscapeDataString(message)}";
		
		    try
		    {
		        HttpWebRequest request = (HttpWebRequest)WebRequest.Create(url);
		        using (HttpWebResponse response = (HttpWebResponse)request.GetResponse())
		        {
		            secondaryTelegramAlertCount++;
		        }
		    }
		    catch (Exception ex)
		    {
		        Print("Erreur Telegram secondaire : " + ex.Message);
		    }
		}
		
		// 1. Détection du biais directionnel (basé sur CHoCH + MSB)
		private string GetDirectionalBias()
		{
		    if (CHoCHPlot[0] > 0 && CHoCHPlot[0] < MSBPlot[0])
		        return "Bullish";
		    else if (CHoCHPlot[0] > 0 && CHoCHPlot[0] > MSBPlot[0])
		        return "Bearish";
		    return "Neutral";
		}
		
		// 2. Score de confluence entre marchés (MES, MNQ, MYM)
		private int GetConfluenceScore()
		{
		    int score = 0;
		
		    if (!marketLogics.ContainsKey(0) || !marketLogics.ContainsKey(1) || !marketLogics.ContainsKey(2))
		        return score;
		
		    if (marketLogics[0].DetectedBullishMSB || marketLogics[0].DetectedBearishMSB) score++;
		    if (marketLogics[1].DetectedBullishMSB || marketLogics[1].DetectedBearishMSB) score++;
		    if (marketLogics[2].DetectedBullishMSB || marketLogics[2].DetectedBearishMSB) score++;
		
		    return score;
		}
		
		// 3. Dashboard graphique dans le coin supérieur gauche
		private void DrawDashboard()
		{
		    string bias = GetDirectionalBias();
		    int score = GetConfluenceScore();
		    string session = GetSessionLabel(Time[0]);
		    string timestamp = Time[0].ToString("HH:mm:ss");
		
		    string dashboardText =
		        $"📊 Anissa20 Dashboard\n" +
		        $"→ Time: {timestamp}\n" +
		        $"→ Bias: {bias}\n" +
		        $"→ Score: {score}/3\n" +
		        $"→ Session: {session}";
		
		    // Nettoyage (facultatif)
		    RemoveDrawObject("DashboardBox");
		    RemoveDrawObject("DashboardText");
		
		    double y = High[0] + 10 * TickSize;
		    Brush color = bias == "Bullish" ? Brushes.LightGreen : bias == "Bearish" ? Brushes.LightCoral : Brushes.White;
		
		    Draw.Rectangle(this, "DashboardBox", false, 0, y + 3 * TickSize, 0, y - 6 * TickSize, Brushes.Black, Brushes.DimGray, 40);
		    Draw.Text(this, "DashboardText", dashboardText, 0, y, color);
		}
		
		// 4. Marqueur graphique sur la bougie en cas de confluence parfaite
		private void MarkPerfectConfluence()
		{
		    bool bullish = MSBPlot[0] > 0 && EntrySignalPlot[0] > 0 && BreakUpPlot[0] > 0;
		    bool bearish = MSBPlot[0] > 0 && EntrySignalPlot[0] > 0 && BreakDownPlot[0] > 0;
		
		    if (!bullish && !bearish)
		        return;
		
		    string tag = "PerfectConfluence_" + CurrentBar;
		    double y = bullish ? Low[0] - 4 * TickSize : High[0] + 4 * TickSize;
		    Brush color = bullish ? Brushes.LimeGreen : Brushes.Red;
		
		    Draw.Text(this, tag, "★", 0, y, color);
		    Draw.Text(this, tag + "_label", "Perfect Confluence", 0, y + (bullish ? -2 : 2) * TickSize, color);
		}
		
		private void DetectAndLogPerfectConfluence()
		{
		    bool bullishConfluence = MSBPlot[0] > 0 && EntrySignalPlot[0] > 0 && BreakUpPlot[0] > 0;
		    bool bearishConfluence = MSBPlot[0] > 0 && EntrySignalPlot[0] > 0 && BreakDownPlot[0] > 0;
		
		    if (!bullishConfluence && !bearishConfluence)
		        return;
		
		    // Analyse de contexte pondérée
		    int bullScore = 0;
		    int bearScore = 0;
		
		    double emaFast = EMA(Close, 21)[0];
		    double emaSlow = EMA(Close, 50)[0];
		    if (emaFast > emaSlow) bullScore += 20;
		    else if (emaFast < emaSlow) bearScore += 20;
		
		    double range = dailyHighestSwingHigh - dailyLowestSwingLow;
		    double posInDay = (Close[0] - dailyLowestSwingLow) / (range + TickSize);
		    if (posInDay > 0.7) bullScore += 15;
		    else if (posInDay < 0.3) bearScore += 15;
		
		    double vol = Volume[0];
		    double avgVol = SMA(Volume, 20)[0];
		    double volRatio = vol / (avgVol + 1);
		    if (volRatio > 1.3) { bullScore += 10; bearScore += 10; }
		
		    double body = Math.Abs(Close[0] - Open[0]);
		    double totalRange = High[0] - Low[0];
		    double bodyRatio = body / (totalRange + TickSize);
		    if (Close[0] > Open[0] && bodyRatio > 0.6) bullScore += 20;
		    else if (Close[0] < Open[0] && bodyRatio > 0.6) bearScore += 20;
		
		    string session = GetSessionLabel(Time[0]);
		    if (session.Contains("New York")) { bullScore += 10; bearScore += 10; }
		
		    double trend = EMA(Close, 8)[0] - EMA(Close, 21)[0];
		    if (trend > 0) bullScore += 15;
		    else if (trend < 0) bearScore += 15;
		
		    string predictedDir;
		    int score;
		    if (bullScore > bearScore) { predictedDir = "Bullish"; score = bullScore; }
		    else if (bearScore > bullScore) { predictedDir = "Bearish"; score = bearScore; }
		    else { predictedDir = "Indécis"; score = bullScore; }
		
		    // Affichage graphique avec flèches et texte
		    string tag = "PerfectSignal_" + CurrentBar;
		    double y = bullishConfluence ? Low[0] - 4 * TickSize : High[0] + 4 * TickSize;
		    Brush color = predictedDir == "Bullish" ? Brushes.LimeGreen :
		                  predictedDir == "Bearish" ? Brushes.OrangeRed :
		                  Brushes.Gray;
		
		    Draw.Text(this, tag + "_Star", "★", 0, y, color);
		    Draw.Text(this, tag + "_Info", $"→ {predictedDir} ({score}/100)", 0, y + (bullishConfluence ? -2 : 2) * TickSize, color);
		
		    if (predictedDir == "Bullish")
		        Draw.ArrowUp(this, tag + "_Arrow", true, 0, Low[0] - 2 * TickSize, Brushes.LimeGreen);
		    else if (predictedDir == "Bearish")
		        Draw.ArrowDown(this, tag + "_Arrow", true, 0, High[0] + 2 * TickSize, Brushes.OrangeRed);
		
		    // Log .csv de la prédiction
		    LogPrediction(predictedDir, score, Close[0]);
		}
		
		private void LogPrediction(string predictedDir, int score, double entryPrice)
		{
		    int validationBars = 5;
		    if (CurrentBar < validationBars)
		        return;
		
		    double futurePrice = Close[validationBars];
		    double actualMove = futurePrice - entryPrice;
		    double ticksMove = actualMove / TickSize;
		
		    string actualDir = ticksMove > 2 ? "Bullish" :
		                       ticksMove < -2 ? "Bearish" : "Flat";
		
		    string path = NinjaTrader.Core.Globals.UserDataDir + "Anissa20_Predictions.csv";
		    string logLine = $"{Time[0]:yyyy-MM-dd HH:mm:ss};{Bars.Instrument.FullName};{predictedDir};{score};{actualDir};{ticksMove:F1}";
		
		    try
		    {
		        if (!System.IO.File.Exists(path))
		            System.IO.File.WriteAllText(path, "Time;Instrument;Prediction;Score;ActualDirection;TicksMove\n");
		
		        System.IO.File.AppendAllText(path, logLine + Environment.NewLine);
		    }
		    catch (Exception ex)
		    {
		        Print("Erreur écriture log prédiction : " + ex.Message);
		    }
		}

        #endregion

        #region Module Classes
        internal class OrderBlockModule
        {
            private readonly Indicator owner;
            public double LastBullishOBTop { get; private set; }
            public double LastBullishOBBottom { get; private set; }
            public double LastBearishOBTop { get; private set; }
            public double LastBearishOBBottom { get; private set; }
            public bool LastBullishOBSet { get; private set; }
            public bool LastBearishOBSet { get; private set; }

            public OrderBlockModule(Indicator owner)
            {
                this.owner = owner;
            }

            public void DrawOrderBlock(bool isBullish, int startBarsAgo, int extensionBars, Brush color, out double obTop, out double obBottom)
            {
                obTop = owner.High[startBarsAgo];
                obBottom = owner.Low[startBarsAgo];
                string tag = (isBullish ? "BullishOB_" : "BearishOB_") + owner.CurrentBar;
                Draw.Rectangle(owner, tag, false, startBarsAgo, obTop, -extensionBars, obBottom, color, Brushes.Transparent, 30);

                if (((Anissa20)owner).ShowPlotDescriptions)
                {
                    double midPrice = (obTop + obBottom) / 2;
                    Draw.Text(owner, tag + "_Desc", isBullish ? "Bullish OB" : "Bearish OB", 0, midPrice, color);
                }

                if (isBullish)
                {
                    LastBullishOBTop = obTop;
                    LastBullishOBBottom = obBottom;
                    LastBullishOBSet = true;
                }
                else
                {
                    LastBearishOBTop = obTop;
                    LastBearishOBBottom = obBottom;
                    LastBearishOBSet = true;
                }
            }
        }

        internal class FairValueGapModule
        {
            private readonly Indicator owner;
            private readonly int fvgExtensionBars;
            private readonly int fvgMinSizeTicks;

            public FairValueGapModule(Indicator owner, int extensionBars, int minSizeTicks)
            {
                this.owner = owner;
                fvgExtensionBars = extensionBars;
                fvgMinSizeTicks = minSizeTicks;
            }

            public void DetectAndPlotFVG()
            {
                if (owner.CurrentBar < 2)
                    return;

                double priorHigh = owner.High[1];
                double priorLow = owner.Low[1];
                double gapSize = 0;
                double tickSize = owner.TickSize;

                if (owner.Low[0] > priorHigh)
                {
                    gapSize = owner.Low[0] - priorHigh;
                    if (gapSize >= fvgMinSizeTicks * tickSize)
                    {
                        string bullTag = "BullFVG_" + owner.CurrentBar;
                        int startBarsAgo = 1;
                        int endBarsAgo = -fvgExtensionBars;
                        double top = owner.Low[0];
                        double bottom = priorHigh;
                        Draw.Rectangle(owner, bullTag, false, startBarsAgo, top, endBarsAgo, bottom, Brushes.LightBlue, Brushes.Transparent, 20);
                        if (((Anissa20)owner).ShowPlotDescriptions)
                        {
                            Draw.Text(owner, "Desc_" + bullTag, "Bull FVG", 1, top, Brushes.LightBlue);
                        }
                    }
                }
                if (owner.High[0] < priorLow)
                {
                    gapSize = priorLow - owner.High[0];
                    if (gapSize >= fvgMinSizeTicks * tickSize)
                    {
                        string bearTag = "BearFVG_" + owner.CurrentBar;
                        int startBarsAgo = 1;
                        int endBarsAgo = -fvgExtensionBars;
                        double top = priorLow;
                        double bottom = owner.High[0];
                        Draw.Rectangle(owner, bearTag, false, startBarsAgo, top, endBarsAgo, bottom, Brushes.LightCoral, Brushes.Transparent, 20);
                        if (((Anissa20)owner).ShowPlotDescriptions)
                        {
                            Draw.Text(owner, "Desc_" + bearTag, "Bear FVG", 1, top, Brushes.LightCoral);
                        }
                    }
                }
            }
        }

        internal class LiquidityModule
        {
            private readonly Indicator owner;
            private readonly int liquidityToleranceTicks;

            public LiquidityModule(Indicator owner, int toleranceTicks)
            {
                this.owner = owner;
                liquidityToleranceTicks = toleranceTicks;
            }

            public void DetectLiquidityLines()
            {
                if (owner.CurrentBar < 2)
                    return;

                double tolerance = liquidityToleranceTicks * owner.TickSize;
                if (Math.Abs(owner.High[0] - owner.High[1]) <= tolerance)
                {
                    double eqHigh = Math.Max(owner.High[0], owner.High[1]);
                    string tag = "EqHigh_" + owner.CurrentBar;
                    Draw.HorizontalLine(owner, tag, eqHigh, Brushes.MediumVioletRed);
                    if (((Anissa20)owner).ShowPlotDescriptions)
                        Draw.Text(owner, tag + "_Desc", "Eq High", 0, eqHigh + 2 * owner.TickSize, Brushes.MediumVioletRed);
                }
                if (Math.Abs(owner.Low[0] - owner.Low[1]) <= tolerance)
                {
                    double eqLow = Math.Min(owner.Low[0], owner.Low[1]);
                    string tag = "EqLow_" + owner.CurrentBar;
                    Draw.HorizontalLine(owner, tag, eqLow, Brushes.MediumVioletRed);
                    if (((Anissa20)owner).ShowPlotDescriptions)
                        Draw.Text(owner, tag + "_Desc", "Eq Low", 0, eqLow - 2 * owner.TickSize, Brushes.MediumVioletRed);
                }
            }
        }
		
		private class Anissa20Logic
		{
		    private readonly Indicator owner;
		    private readonly int barsIndex;
		    private readonly int strength;
		    private readonly double tickSize;
		    private readonly int breakThresholdTicks;
		    private readonly int cacheSize;
		    private const double SwingTolerance = 0.0001;
		
		    private List<double> highCache = new List<double>();
		    private List<double> lowCache = new List<double>();
		
		    public double LastSwingHigh { get; private set; } = 0;
		    public double LastSwingLow { get; private set; } = double.MaxValue;
		
		    public bool DetectedBullishMSB { get; private set; } = false;
		    public bool DetectedBearishMSB { get; private set; } = false;
		
		    private bool bullishBreak = false;
		    private bool bearishBreak = false;
		    private double previousHigh = 0;
		    private double previousLow = 0;
		    private bool bullishCHoCH = false;
		    private bool bearishCHoCH = false;
		
		    public Anissa20Logic(Indicator owner, int barsIndex, int strength, int breakThresholdTicks)
		    {
		        this.owner = owner;
		        this.barsIndex = barsIndex;
		        this.strength = strength;
		        this.breakThresholdTicks = breakThresholdTicks;
		        this.tickSize = owner.TickSize;
		        this.cacheSize = 2 * strength + 1;
		    }
		
		    public void UpdateBar()
		    {
		        if (owner.BarsArray.Length <= barsIndex || owner.CurrentBars[barsIndex] < cacheSize)
		            return;
		
		        double high = owner.Highs[barsIndex][0];
		        double low = owner.Lows[barsIndex][0];
		        double close = owner.Closes[barsIndex][0];
		
		        UpdateCaches(high, low);
		
		        int center = strength;
		        if (highCache.Count == cacheSize)
		        {
		            double candidate = highCache[center];
		            bool isSwingHigh = ValidateSwing(highCache, center, true);
		
		            if (isSwingHigh)
		            {
		                if (previousHigh != 0 && candidate < previousHigh - breakThresholdTicks * tickSize)
		                    bearishCHoCH = true;
		
		                previousHigh = candidate;
		                LastSwingHigh = candidate;
		                bullishBreak = false;
		            }
		
		            if (LastSwingHigh > 0 && !bullishBreak && close > LastSwingHigh + breakThresholdTicks * tickSize)
		            {
		                bullishBreak = true;
		                if (bearishCHoCH)
		                {
		                    DetectedBearishMSB = true;
		                    bearishCHoCH = false;
		                }
		            }
		        }
		
		        if (lowCache.Count == cacheSize)
		        {
		            double candidate = lowCache[center];
		            bool isSwingLow = ValidateSwing(lowCache, center, false);
		
		            if (isSwingLow)
		            {
		                if (previousLow != 0 && candidate > previousLow + breakThresholdTicks * tickSize)
		                    bullishCHoCH = true;
		
		                previousLow = candidate;
		                LastSwingLow = candidate;
		                bearishBreak = false;
		            }
		
		            if (LastSwingLow < double.MaxValue && !bearishBreak && close < LastSwingLow - breakThresholdTicks * tickSize)
		            {
		                bearishBreak = true;
		                if (bullishCHoCH)
		                {
		                    DetectedBullishMSB = true;
		                    bullishCHoCH = false;
		                }
		            }
		        }
		    }
		
		    private void UpdateCaches(double high, double low)
		    {
		        highCache.Add(high);
		        if (highCache.Count > cacheSize)
		            highCache.RemoveAt(0);
		
		        lowCache.Add(low);
		        if (lowCache.Count > cacheSize)
		            lowCache.RemoveAt(0);
		    }
		
		    private bool ValidateSwing(List<double> cache, int centerIndex, bool isHigh)
		    {
		        double candidate = cache[centerIndex];
		        for (int i = 0; i < cache.Count; i++)
		        {
		            if (i == centerIndex)
		                continue;
		
		            if (isHigh && cache[i] > candidate + SwingTolerance)
		                return false;
		            if (!isHigh && cache[i] < candidate - SwingTolerance)
		                return false;
		        }
		        return true;
		    }
		
		    public void ResetSignals()
		    {
		        DetectedBullishMSB = false;
		        DetectedBearishMSB = false;
		    }
		}

        #endregion
    }
}


#region NinjaScript generated code. Neither change nor remove.

namespace NinjaTrader.NinjaScript.Indicators
{
	public partial class Indicator : NinjaTrader.Gui.NinjaScript.IndicatorRenderBase
	{
		private Anissa20[] cacheAnissa20;
		public Anissa20 Anissa20(int strength, int breakThresholdTicks, bool plotOrderblocks, int orderblockExtensionBars, Brush bullishOrderblockColor, Brush bearishOrderblockColor, bool plotFairValueGaps, int fvgExtensionBars, int fvgMinSizeTicks, bool plotLiquidityLines, int liquidityToleranceTicks, bool sendEmailAlerts, bool enableSoundAlerts, string alertSoundFile, string alertMessagePrefix, bool useCustomSessionTimes, TimeSpan newYorkSessionStart, TimeSpan newYorkSessionEnd, TimeSpan londonSessionStart, TimeSpan londonSessionEnd, TimeSpan asianSessionStart, TimeSpan asianSessionEnd, bool showPlotDescriptions, string secondaryTelegramBotToken, string secondaryTelegramChatID, bool afficherDashboard)
		{
			return Anissa20(Input, strength, breakThresholdTicks, plotOrderblocks, orderblockExtensionBars, bullishOrderblockColor, bearishOrderblockColor, plotFairValueGaps, fvgExtensionBars, fvgMinSizeTicks, plotLiquidityLines, liquidityToleranceTicks, sendEmailAlerts, enableSoundAlerts, alertSoundFile, alertMessagePrefix, useCustomSessionTimes, newYorkSessionStart, newYorkSessionEnd, londonSessionStart, londonSessionEnd, asianSessionStart, asianSessionEnd, showPlotDescriptions, secondaryTelegramBotToken, secondaryTelegramChatID, afficherDashboard);
		}

		public Anissa20 Anissa20(ISeries<double> input, int strength, int breakThresholdTicks, bool plotOrderblocks, int orderblockExtensionBars, Brush bullishOrderblockColor, Brush bearishOrderblockColor, bool plotFairValueGaps, int fvgExtensionBars, int fvgMinSizeTicks, bool plotLiquidityLines, int liquidityToleranceTicks, bool sendEmailAlerts, bool enableSoundAlerts, string alertSoundFile, string alertMessagePrefix, bool useCustomSessionTimes, TimeSpan newYorkSessionStart, TimeSpan newYorkSessionEnd, TimeSpan londonSessionStart, TimeSpan londonSessionEnd, TimeSpan asianSessionStart, TimeSpan asianSessionEnd, bool showPlotDescriptions, string secondaryTelegramBotToken, string secondaryTelegramChatID, bool afficherDashboard)
		{
			if (cacheAnissa20 != null)
				for (int idx = 0; idx < cacheAnissa20.Length; idx++)
					if (cacheAnissa20[idx] != null && cacheAnissa20[idx].Strength == strength && cacheAnissa20[idx].BreakThresholdTicks == breakThresholdTicks && cacheAnissa20[idx].PlotOrderblocks == plotOrderblocks && cacheAnissa20[idx].OrderblockExtensionBars == orderblockExtensionBars && cacheAnissa20[idx].BullishOrderblockColor == bullishOrderblockColor && cacheAnissa20[idx].BearishOrderblockColor == bearishOrderblockColor && cacheAnissa20[idx].PlotFairValueGaps == plotFairValueGaps && cacheAnissa20[idx].FvgExtensionBars == fvgExtensionBars && cacheAnissa20[idx].FvgMinSizeTicks == fvgMinSizeTicks && cacheAnissa20[idx].PlotLiquidityLines == plotLiquidityLines && cacheAnissa20[idx].LiquidityToleranceTicks == liquidityToleranceTicks && cacheAnissa20[idx].SendEmailAlerts == sendEmailAlerts && cacheAnissa20[idx].EnableSoundAlerts == enableSoundAlerts && cacheAnissa20[idx].AlertSoundFile == alertSoundFile && cacheAnissa20[idx].AlertMessagePrefix == alertMessagePrefix && cacheAnissa20[idx].UseCustomSessionTimes == useCustomSessionTimes && cacheAnissa20[idx].NewYorkSessionStart == newYorkSessionStart && cacheAnissa20[idx].NewYorkSessionEnd == newYorkSessionEnd && cacheAnissa20[idx].LondonSessionStart == londonSessionStart && cacheAnissa20[idx].LondonSessionEnd == londonSessionEnd && cacheAnissa20[idx].AsianSessionStart == asianSessionStart && cacheAnissa20[idx].AsianSessionEnd == asianSessionEnd && cacheAnissa20[idx].ShowPlotDescriptions == showPlotDescriptions && cacheAnissa20[idx].SecondaryTelegramBotToken == secondaryTelegramBotToken && cacheAnissa20[idx].SecondaryTelegramChatID == secondaryTelegramChatID && cacheAnissa20[idx].AfficherDashboard == afficherDashboard && cacheAnissa20[idx].EqualsInput(input))
						return cacheAnissa20[idx];
			return CacheIndicator<Anissa20>(new Anissa20(){ Strength = strength, BreakThresholdTicks = breakThresholdTicks, PlotOrderblocks = plotOrderblocks, OrderblockExtensionBars = orderblockExtensionBars, BullishOrderblockColor = bullishOrderblockColor, BearishOrderblockColor = bearishOrderblockColor, PlotFairValueGaps = plotFairValueGaps, FvgExtensionBars = fvgExtensionBars, FvgMinSizeTicks = fvgMinSizeTicks, PlotLiquidityLines = plotLiquidityLines, LiquidityToleranceTicks = liquidityToleranceTicks, SendEmailAlerts = sendEmailAlerts, EnableSoundAlerts = enableSoundAlerts, AlertSoundFile = alertSoundFile, AlertMessagePrefix = alertMessagePrefix, UseCustomSessionTimes = useCustomSessionTimes, NewYorkSessionStart = newYorkSessionStart, NewYorkSessionEnd = newYorkSessionEnd, LondonSessionStart = londonSessionStart, LondonSessionEnd = londonSessionEnd, AsianSessionStart = asianSessionStart, AsianSessionEnd = asianSessionEnd, ShowPlotDescriptions = showPlotDescriptions, SecondaryTelegramBotToken = secondaryTelegramBotToken, SecondaryTelegramChatID = secondaryTelegramChatID, AfficherDashboard = afficherDashboard }, input, ref cacheAnissa20);
		}
	}
}

namespace NinjaTrader.NinjaScript.MarketAnalyzerColumns
{
	public partial class MarketAnalyzerColumn : MarketAnalyzerColumnBase
	{
		public Indicators.Anissa20 Anissa20(int strength, int breakThresholdTicks, bool plotOrderblocks, int orderblockExtensionBars, Brush bullishOrderblockColor, Brush bearishOrderblockColor, bool plotFairValueGaps, int fvgExtensionBars, int fvgMinSizeTicks, bool plotLiquidityLines, int liquidityToleranceTicks, bool sendEmailAlerts, bool enableSoundAlerts, string alertSoundFile, string alertMessagePrefix, bool useCustomSessionTimes, TimeSpan newYorkSessionStart, TimeSpan newYorkSessionEnd, TimeSpan londonSessionStart, TimeSpan londonSessionEnd, TimeSpan asianSessionStart, TimeSpan asianSessionEnd, bool showPlotDescriptions, string secondaryTelegramBotToken, string secondaryTelegramChatID, bool afficherDashboard)
		{
			return indicator.Anissa20(Input, strength, breakThresholdTicks, plotOrderblocks, orderblockExtensionBars, bullishOrderblockColor, bearishOrderblockColor, plotFairValueGaps, fvgExtensionBars, fvgMinSizeTicks, plotLiquidityLines, liquidityToleranceTicks, sendEmailAlerts, enableSoundAlerts, alertSoundFile, alertMessagePrefix, useCustomSessionTimes, newYorkSessionStart, newYorkSessionEnd, londonSessionStart, londonSessionEnd, asianSessionStart, asianSessionEnd, showPlotDescriptions, secondaryTelegramBotToken, secondaryTelegramChatID, afficherDashboard);
		}

		public Indicators.Anissa20 Anissa20(ISeries<double> input , int strength, int breakThresholdTicks, bool plotOrderblocks, int orderblockExtensionBars, Brush bullishOrderblockColor, Brush bearishOrderblockColor, bool plotFairValueGaps, int fvgExtensionBars, int fvgMinSizeTicks, bool plotLiquidityLines, int liquidityToleranceTicks, bool sendEmailAlerts, bool enableSoundAlerts, string alertSoundFile, string alertMessagePrefix, bool useCustomSessionTimes, TimeSpan newYorkSessionStart, TimeSpan newYorkSessionEnd, TimeSpan londonSessionStart, TimeSpan londonSessionEnd, TimeSpan asianSessionStart, TimeSpan asianSessionEnd, bool showPlotDescriptions, string secondaryTelegramBotToken, string secondaryTelegramChatID, bool afficherDashboard)
		{
			return indicator.Anissa20(input, strength, breakThresholdTicks, plotOrderblocks, orderblockExtensionBars, bullishOrderblockColor, bearishOrderblockColor, plotFairValueGaps, fvgExtensionBars, fvgMinSizeTicks, plotLiquidityLines, liquidityToleranceTicks, sendEmailAlerts, enableSoundAlerts, alertSoundFile, alertMessagePrefix, useCustomSessionTimes, newYorkSessionStart, newYorkSessionEnd, londonSessionStart, londonSessionEnd, asianSessionStart, asianSessionEnd, showPlotDescriptions, secondaryTelegramBotToken, secondaryTelegramChatID, afficherDashboard);
		}
	}
}

namespace NinjaTrader.NinjaScript.Strategies
{
	public partial class Strategy : NinjaTrader.Gui.NinjaScript.StrategyRenderBase
	{
		public Indicators.Anissa20 Anissa20(int strength, int breakThresholdTicks, bool plotOrderblocks, int orderblockExtensionBars, Brush bullishOrderblockColor, Brush bearishOrderblockColor, bool plotFairValueGaps, int fvgExtensionBars, int fvgMinSizeTicks, bool plotLiquidityLines, int liquidityToleranceTicks, bool sendEmailAlerts, bool enableSoundAlerts, string alertSoundFile, string alertMessagePrefix, bool useCustomSessionTimes, TimeSpan newYorkSessionStart, TimeSpan newYorkSessionEnd, TimeSpan londonSessionStart, TimeSpan londonSessionEnd, TimeSpan asianSessionStart, TimeSpan asianSessionEnd, bool showPlotDescriptions, string secondaryTelegramBotToken, string secondaryTelegramChatID, bool afficherDashboard)
		{
			return indicator.Anissa20(Input, strength, breakThresholdTicks, plotOrderblocks, orderblockExtensionBars, bullishOrderblockColor, bearishOrderblockColor, plotFairValueGaps, fvgExtensionBars, fvgMinSizeTicks, plotLiquidityLines, liquidityToleranceTicks, sendEmailAlerts, enableSoundAlerts, alertSoundFile, alertMessagePrefix, useCustomSessionTimes, newYorkSessionStart, newYorkSessionEnd, londonSessionStart, londonSessionEnd, asianSessionStart, asianSessionEnd, showPlotDescriptions, secondaryTelegramBotToken, secondaryTelegramChatID, afficherDashboard);
		}

		public Indicators.Anissa20 Anissa20(ISeries<double> input , int strength, int breakThresholdTicks, bool plotOrderblocks, int orderblockExtensionBars, Brush bullishOrderblockColor, Brush bearishOrderblockColor, bool plotFairValueGaps, int fvgExtensionBars, int fvgMinSizeTicks, bool plotLiquidityLines, int liquidityToleranceTicks, bool sendEmailAlerts, bool enableSoundAlerts, string alertSoundFile, string alertMessagePrefix, bool useCustomSessionTimes, TimeSpan newYorkSessionStart, TimeSpan newYorkSessionEnd, TimeSpan londonSessionStart, TimeSpan londonSessionEnd, TimeSpan asianSessionStart, TimeSpan asianSessionEnd, bool showPlotDescriptions, string secondaryTelegramBotToken, string secondaryTelegramChatID, bool afficherDashboard)
		{
			return indicator.Anissa20(input, strength, breakThresholdTicks, plotOrderblocks, orderblockExtensionBars, bullishOrderblockColor, bearishOrderblockColor, plotFairValueGaps, fvgExtensionBars, fvgMinSizeTicks, plotLiquidityLines, liquidityToleranceTicks, sendEmailAlerts, enableSoundAlerts, alertSoundFile, alertMessagePrefix, useCustomSessionTimes, newYorkSessionStart, newYorkSessionEnd, londonSessionStart, londonSessionEnd, asianSessionStart, asianSessionEnd, showPlotDescriptions, secondaryTelegramBotToken, secondaryTelegramChatID, afficherDashboard);
		}
	}
}

#endregion
