// ═══════════════════════════════════════════════════════════════════════════════
// Sola1 v1.2 — Swing Breakout Indicator
// ═══════════════════════════════════════════════════════════════════════════════
//
// Uses NinjaTrader's NATIVE Swing() indicator for swing detection.
// Reads SwingHigh/SwingLow series + SwingHighBar()/SwingLowBar() methods.
// Strategy: breakout of last SH/SL + CHoCH / Volume / Retest filters.
// Session: US only (configurable).
//
// INSTALL: Documents\NinjaTrader 8\bin\Custom\Indicators\ → Compile (F5)
// ═══════════════════════════════════════════════════════════════════════════════

#region Using declarations
using System;
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Net;
using System.Text;
using System.Windows;
using System.Windows.Media;
using System.Xml.Serialization;
using NinjaTrader.Cbi;
using NinjaTrader.Core;
using NinjaTrader.Core.FloatingPoint;
using NinjaTrader.Gui;
using NinjaTrader.Gui.Chart;
using NinjaTrader.Gui.Tools;
using NinjaTrader.Data;
using NinjaTrader.NinjaScript;
using NinjaTrader.NinjaScript.DrawingTools;
using NinjaTrader.NinjaScript.Indicators;
#endregion

namespace NinjaTrader.NinjaScript.Indicators
{
    public class Sola1 : Indicator
    {
        // ═══════════════════════════════════════════════════════════════
        // NATIVE SWING REFERENCE
        // ═══════════════════════════════════════════════════════════════

        private Swing swingIndicator;

        // ═══════════════════════════════════════════════════════════════
        // STRATEGY STATE
        // ═══════════════════════════════════════════════════════════════

        #region Strategy State
        // Active swings (the last confirmed SH and SL)
        private double activeSH = 0;
        private double activeSL = 0;
        private int    activeSHBarsAgo = -1;
        private int    activeSLBarsAgo = -1;

        // Previous swings for CHoCH
        private double prevSH = 0;
        private double prevSL = 0;

        // Breakout state
        private bool   bullBreakConfirmed = false;
        private bool   bearBreakConfirmed = false;
        private int    bullBreakBar = -1;
        private int    bearBreakBar = -1;
        private double bullBreakPrice = 0;
        private double bearBreakPrice = 0;

        // CHoCH state
        private bool bullishCHoCH = false;
        private bool bearishCHoCH = false;

        // Retest state
        private bool awaitingBullRetest = false;
        private bool awaitingBearRetest = false;
        private bool bullRetestComplete = false;
        private bool bearRetestComplete = false;

        // Signal state
        private bool bullSignalFired = false;
        private bool bearSignalFired = false;

        // Track last known swing to detect when a NEW one appears
        private double lastKnownSH = 0;
        private double lastKnownSL = 0;
        #endregion

        // ═══════════════════════════════════════════════════════════════
        // PARAMETERS
        // ═══════════════════════════════════════════════════════════════

        #region Parameters — Structure
        [NinjaScriptProperty]
        [Range(1, int.MaxValue)]
        [Display(Name = "Swing Strength", Order = 1, GroupName = "1. Structure")]
        public int Strength { get; set; }

        [NinjaScriptProperty]
        [Range(0, 20)]
        [Display(Name = "Break Threshold (ticks)", Order = 2, GroupName = "1. Structure")]
        public int BreakThresholdTicks { get; set; }

        [NinjaScriptProperty]
        [Range(0, 2)]
        [Display(Name = "Breakout Trigger (0=Close 1=Wick 2=Both)", Order = 3, GroupName = "1. Structure")]
        public int BreakoutTrigger { get; set; }
        #endregion

        #region Parameters — Filters
        [NinjaScriptProperty]
        [Display(Name = "Require CHoCH", Order = 1, GroupName = "2. Filters")]
        public bool RequireCHoCH { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Require Volume", Order = 2, GroupName = "2. Filters")]
        public bool RequireVolume { get; set; }

        [NinjaScriptProperty]
        [Range(1.0, 5.0)]
        [Display(Name = "Volume Multiplier", Order = 3, GroupName = "2. Filters")]
        public double VolumeMultiplier { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Require Retest", Order = 4, GroupName = "2. Filters")]
        public bool RequireRetest { get; set; }

        [NinjaScriptProperty]
        [Range(1, 30)]
        [Display(Name = "Max Retest Wait (bars)", Order = 5, GroupName = "2. Filters")]
        public int MaxRetestBars { get; set; }

        [NinjaScriptProperty]
        [Range(0, 10)]
        [Display(Name = "Retest Tolerance (ticks)", Order = 6, GroupName = "2. Filters")]
        public int RetestToleranceTicks { get; set; }
        #endregion

        #region Parameters — Session
        [NinjaScriptProperty]
        [Display(Name = "NY Session Start (EST)", Order = 1, GroupName = "3. Session")]
        public TimeSpan SessionStart { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "NY Session End (EST)", Order = 2, GroupName = "3. Session")]
        public TimeSpan SessionEnd { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Use Local Time", Order = 3, GroupName = "3. Session")]
        public bool UseLocalTime { get; set; }
        #endregion

        #region Parameters — Display
        [NinjaScriptProperty]
        [Display(Name = "Show Dashboard", Order = 1, GroupName = "4. Display")]
        public bool ShowDashboard { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Show Swing Lines", Order = 2, GroupName = "4. Display")]
        public bool ShowSwingLines { get; set; }

        [NinjaScriptProperty]
        [Range(5, 200)]
        [Display(Name = "Swing Line Length (bars forward)", Order = 3, GroupName = "4. Display")]
        public int SwingLineLength { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Show Swing Dots", Description = "Plot swing dots like native Swing indicator", Order = 4, GroupName = "4. Display")]
        public bool ShowSwingDots { get; set; }
        #endregion

        // ═══════════════════════════════════════════════════════════════
        // PLOTS
        // ═══════════════════════════════════════════════════════════════
        //  Values[0] = LongSignal   (price or 0)
        //  Values[1] = ShortSignal  (price or 0)

        // ═══════════════════════════════════════════════════════════════
        // STATE MANAGEMENT
        // ═══════════════════════════════════════════════════════════════

        protected override void OnStateChange()
        {
            if (State == State.SetDefaults)
            {
                Description     = "Sola1 v1.2 — Native Swing indicator + breakout with CHoCH/Volume/Retest filters.";
                Name            = "Sola1";
                Calculate       = Calculate.OnBarClose;
                IsOverlay       = true;
                DisplayInDataBox = false;
                PaintPriceMarkers = false;
                IsSuspendedWhileInactive = true;

                Strength            = 5;
                BreakThresholdTicks = 2;
                BreakoutTrigger     = 0;

                RequireCHoCH        = true;
                RequireVolume       = true;
                VolumeMultiplier    = 1.2;
                RequireRetest       = false;
                MaxRetestBars       = 10;
                RetestToleranceTicks = 3;

                SessionStart    = new TimeSpan(9, 30, 0);
                SessionEnd      = new TimeSpan(16, 0, 0);
                UseLocalTime    = false;

                ShowDashboard   = true;
                ShowSwingLines  = true;
                SwingLineLength = 30;
                ShowSwingDots   = true;

                // Signal plots (invisible — for strategy consumption)
                AddPlot(Brushes.Transparent, "LongSignal");
                AddPlot(Brushes.Transparent, "ShortSignal");
            }
            else if (State == State.DataLoaded)
            {
                // Initialize the NATIVE Swing indicator
                swingIndicator = Swing(Strength);
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // ON BAR UPDATE
        // ═══════════════════════════════════════════════════════════════

        protected override void OnBarUpdate()
        {
            if (CurrentBar < 2 * Strength + 1) return;

            // Reset signal plots
            Values[0][0] = 0;
            Values[1][0] = 0;

            // ── Step 1: Read swings from native Swing indicator ──
            ReadSwings();

            // ── Step 2: Draw swing dots (mirroring native Swing visual) ──
            if (ShowSwingDots) DrawSwingDots();

            // ── Step 3: Strategy logic (session only) ──
            bool inSession = IsInSession();
            if (inSession)
            {
                DetectBreakouts();
                ProcessRetests();
                GenerateSignals();
            }
            else
            {
                ResetBreakoutStates();
            }

            // ── Step 4: Visuals ──
            if (ShowSwingLines) DrawSwingLines();
            if (ShowDashboard && CurrentBar >= Count - 2) DrawDashboard(inSession);
        }

        // ═══════════════════════════════════════════════════════════════
        // READ SWINGS FROM NATIVE INDICATOR
        // ═══════════════════════════════════════════════════════════════

        private void ReadSwings()
        {
            // SwingHighBar returns bars ago of the most recent swing high
            // instance=1 means "the 1st (most recent) swing"
            // lookBackPeriod=100 means search within last 100 bars
            int shBarsAgo = swingIndicator.SwingHighBar(0, 1, 100);
            int slBarsAgo = swingIndicator.SwingLowBar(0, 1, 100);

            // Read swing high value
            if (shBarsAgo >= 0)
            {
                double shValue = High[shBarsAgo];

                // Detect if this is a NEW swing (different value from last known)
                if (shValue != lastKnownSH)
                {
                    // New swing high appeared
                    prevSH = activeSH;
                    activeSH = shValue;
                    activeSHBarsAgo = shBarsAgo;
                    lastKnownSH = shValue;

                    // CHoCH: lower high = bearish structure shift
                    if (prevSH > 0 && activeSH < prevSH)
                    {
                        bearishCHoCH = true;
                        bullishCHoCH = false;
                    }

                    // New SH invalidates previous bull breakout
                    bullBreakConfirmed = false;
                    bullSignalFired = false;
                    awaitingBullRetest = false;
                    bullRetestComplete = false;
                }
                else
                {
                    activeSHBarsAgo = shBarsAgo; // Update bars ago (it shifts each bar)
                }
            }

            // Read swing low value
            if (slBarsAgo >= 0)
            {
                double slValue = Low[slBarsAgo];

                if (slValue != lastKnownSL)
                {
                    // New swing low appeared
                    prevSL = activeSL;
                    activeSL = slValue;
                    activeSLBarsAgo = slBarsAgo;
                    lastKnownSL = slValue;

                    // CHoCH: higher low = bullish structure shift
                    if (prevSL > 0 && activeSL > prevSL)
                    {
                        bullishCHoCH = true;
                        bearishCHoCH = false;
                    }

                    // New SL invalidates previous bear breakout
                    bearBreakConfirmed = false;
                    bearSignalFired = false;
                    awaitingBearRetest = false;
                    bearRetestComplete = false;
                }
                else
                {
                    activeSLBarsAgo = slBarsAgo;
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // DRAW SWING DOTS — replicates native Swing visual
        // ═══════════════════════════════════════════════════════════════

        private void DrawSwingDots()
        {
            // The native Swing indicator plots dots at the swing value
            // for the Strength bars around each swing point.
            // We replicate this by reading SwingHigh/SwingLow series.

            double sh = swingIndicator.SwingHigh[0];
            double sl = swingIndicator.SwingLow[0];

            if (sh > 0)
                Draw.Dot(this, "SHd_" + CurrentBar, false, 0, sh, Brushes.DarkCyan);

            if (sl > 0)
                Draw.Dot(this, "SLd_" + CurrentBar, false, 0, sl, Brushes.Goldenrod);
        }

        // ═══════════════════════════════════════════════════════════════
        // BREAKOUT DETECTION
        // ═══════════════════════════════════════════════════════════════

        private void DetectBreakouts()
        {
            if (activeSH <= 0 || activeSL <= 0) return;

            double threshold = BreakThresholdTicks * TickSize;

            // ── Bullish breakout (above SH) ──
            if (!bullBreakConfirmed)
            {
                bool triggered = false;
                if (BreakoutTrigger == 0)      triggered = Close[0] > activeSH + threshold;
                else if (BreakoutTrigger == 1) triggered = High[0]  > activeSH + threshold;
                else                           triggered = Close[0] > activeSH + threshold || High[0] > activeSH + threshold;

                if (triggered)
                {
                    bullBreakConfirmed = true;
                    bullBreakBar = CurrentBar;
                    bullBreakPrice = activeSH;
                    bullSignalFired = false;
                    bullRetestComplete = false;
                    if (RequireRetest) awaitingBullRetest = true;

                    // Mark the breakout on chart
                    Draw.TriangleUp(this, "BkU_" + CurrentBar, false, 0, Low[0] - 2 * TickSize, Brushes.Lime);
                }
            }

            // ── Bearish breakout (below SL) ──
            if (!bearBreakConfirmed)
            {
                bool triggered = false;
                if (BreakoutTrigger == 0)      triggered = Close[0] < activeSL - threshold;
                else if (BreakoutTrigger == 1) triggered = Low[0]   < activeSL - threshold;
                else                           triggered = Close[0] < activeSL - threshold || Low[0] < activeSL - threshold;

                if (triggered)
                {
                    bearBreakConfirmed = true;
                    bearBreakBar = CurrentBar;
                    bearBreakPrice = activeSL;
                    bearSignalFired = false;
                    bearRetestComplete = false;
                    if (RequireRetest) awaitingBearRetest = true;

                    Draw.TriangleDown(this, "BkD_" + CurrentBar, false, 0, High[0] + 2 * TickSize, Brushes.Red);
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // RETEST
        // ═══════════════════════════════════════════════════════════════

        private void ProcessRetests()
        {
            double retestTol = RetestToleranceTicks * TickSize;

            if (awaitingBullRetest && bullBreakConfirmed && !bullRetestComplete)
            {
                if (CurrentBar - bullBreakBar > MaxRetestBars)
                { awaitingBullRetest = false; bullBreakConfirmed = false; return; }
                if (Low[0] <= bullBreakPrice + retestTol && Close[0] > bullBreakPrice)
                { bullRetestComplete = true; awaitingBullRetest = false; }
            }

            if (awaitingBearRetest && bearBreakConfirmed && !bearRetestComplete)
            {
                if (CurrentBar - bearBreakBar > MaxRetestBars)
                { awaitingBearRetest = false; bearBreakConfirmed = false; return; }
                if (High[0] >= bearBreakPrice - retestTol && Close[0] < bearBreakPrice)
                { bearRetestComplete = true; awaitingBearRetest = false; }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // SIGNAL GENERATION
        // ═══════════════════════════════════════════════════════════════

        private void GenerateSignals()
        {
            // ── LONG ──
            if (bullBreakConfirmed && !bullSignalFired)
            {
                bool pass = true;

                if (RequireCHoCH && !bullishCHoCH) pass = false;

                if (pass && RequireVolume && CurrentBar >= 20
                    && Volume[0] < SMA(Volume, 20)[0] * VolumeMultiplier)
                    pass = false;

                if (pass && RequireRetest && !bullRetestComplete)
                    return; // Still waiting, don't fire yet but don't block either

                if (pass)
                {
                    Values[0][0] = Close[0];
                    bullSignalFired = true;

                    if (RequireRetest)
                        Draw.Diamond(this, "LS_" + CurrentBar, true, 0, Low[0] - 5 * TickSize, Brushes.DodgerBlue);
                    else
                        Draw.ArrowUp(this, "LS_" + CurrentBar, true, 0, Low[0] - 5 * TickSize, Brushes.LimeGreen);

                    Draw.Text(this, "LT_" + CurrentBar, "▲ LONG", 0, Low[0] - 8 * TickSize, Brushes.LimeGreen);
                }
            }

            // ── SHORT ──
            if (bearBreakConfirmed && !bearSignalFired)
            {
                bool pass = true;

                if (RequireCHoCH && !bearishCHoCH) pass = false;

                if (pass && RequireVolume && CurrentBar >= 20
                    && Volume[0] < SMA(Volume, 20)[0] * VolumeMultiplier)
                    pass = false;

                if (pass && RequireRetest && !bearRetestComplete)
                    return;

                if (pass)
                {
                    Values[1][0] = Close[0];
                    bearSignalFired = true;

                    if (RequireRetest)
                        Draw.Diamond(this, "SS_" + CurrentBar, true, 0, High[0] + 5 * TickSize, Brushes.DodgerBlue);
                    else
                        Draw.ArrowDown(this, "SS_" + CurrentBar, true, 0, High[0] + 5 * TickSize, Brushes.OrangeRed);

                    Draw.Text(this, "ST_" + CurrentBar, "▼ SHORT", 0, High[0] + 8 * TickSize, Brushes.OrangeRed);
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // SESSION
        // ═══════════════════════════════════════════════════════════════

        private bool IsInSession()
        {
            try
            {
                TimeSpan t;
                if (UseLocalTime)
                    t = Time[0].TimeOfDay;
                else
                {
                    var est = TimeZoneInfo.FindSystemTimeZoneById("Eastern Standard Time");
                    t = TimeZoneInfo.ConvertTime(Time[0], est).TimeOfDay;
                }
                return t >= SessionStart && t < SessionEnd;
            }
            catch { return true; }
        }

        private void ResetBreakoutStates()
        {
            bullBreakConfirmed = false; bearBreakConfirmed = false;
            bullSignalFired = false;    bearSignalFired = false;
            awaitingBullRetest = false;  awaitingBearRetest = false;
            bullRetestComplete = false;  bearRetestComplete = false;
        }

        // ═══════════════════════════════════════════════════════════════
        // VISUALS
        // ═══════════════════════════════════════════════════════════════

        private void DrawSwingLines()
        {
            if (activeSH > 0 && activeSHBarsAgo >= 0)
            {
                Draw.Line(this, "SH_Active", false, activeSHBarsAgo, activeSH, -SwingLineLength, activeSH,
                    Brushes.DarkCyan, DashStyleHelper.Dash, 1);
                Draw.Text(this, "SH_Lbl", "SH " + activeSH.ToString("F2"),
                    -3, activeSH + 2 * TickSize, Brushes.DarkCyan);
            }

            if (activeSL > 0 && activeSLBarsAgo >= 0)
            {
                Draw.Line(this, "SL_Active", false, activeSLBarsAgo, activeSL, -SwingLineLength, activeSL,
                    Brushes.Goldenrod, DashStyleHelper.Dash, 1);
                Draw.Text(this, "SL_Lbl", "SL " + activeSL.ToString("F2"),
                    -3, activeSL - 2 * TickSize, Brushes.Goldenrod);
            }
        }

        private void DrawDashboard(bool inSession)
        {
            string state;
            if (!inSession)                                      state = "OFF SESSION";
            else if (awaitingBullRetest)                         state = "WAIT BULL RETEST";
            else if (awaitingBearRetest)                         state = "WAIT BEAR RETEST";
            else if (bullBreakConfirmed && !bullSignalFired)     state = "BULL BREAK (filters)";
            else if (bearBreakConfirmed && !bearSignalFired)     state = "BEAR BREAK (filters)";
            else                                                 state = "SCANNING";

            string fCHoCH = RequireCHoCH
                ? (bullishCHoCH ? "CHoCH↑" : bearishCHoCH ? "CHoCH↓" : "—")
                : "OFF";
            string fVol = RequireVolume ? "Vol x" + VolumeMultiplier.ToString("F1") : "OFF";
            string fRet = RequireRetest ? "Ret " + MaxRetestBars + "b" : "OFF";

            string shStr = activeSH > 0 ? activeSH.ToString("F2") : "—";
            string slStr = activeSL > 0 ? activeSL.ToString("F2") : "—";
            string trig = BreakoutTrigger == 0 ? "Close" : BreakoutTrigger == 1 ? "Wick" : "Both";

            string txt = "═══ Sola1 v1.2 ═══\n" +
                         state + "\n" +
                         "SH: " + shStr + " | SL: " + slStr + "\n" +
                         fCHoCH + " | " + fVol + " | " + fRet + "\n" +
                         "Trigger: " + trig;

            Brush bg = state.Contains("BULL") ? Brushes.DarkGreen
                     : state.Contains("BEAR") ? Brushes.DarkRed
                     : state == "OFF SESSION"  ? Brushes.DimGray
                     : Brushes.DarkSlateGray;

            Draw.TextFixed(this, "Sola1Dash", txt, TextPosition.TopLeft,
                Brushes.White, new SimpleFont("Consolas", 11), bg, Brushes.Black, 85);
        }

        // ═══════════════════════════════════════════════════════════════
        // PUBLIC PROPERTIES (for strategy access)
        // ═══════════════════════════════════════════════════════════════

        [Browsable(false)] [XmlIgnore] public Series<double> LongSignal  => Values[0];
        [Browsable(false)] [XmlIgnore] public Series<double> ShortSignal => Values[1];
        [Browsable(false)] [XmlIgnore] public double ActiveSH => activeSH;
        [Browsable(false)] [XmlIgnore] public double ActiveSL => activeSL;
        [Browsable(false)] [XmlIgnore] public bool IsBullishStructure => bullishCHoCH;
        [Browsable(false)] [XmlIgnore] public bool IsBearishStructure => bearishCHoCH;
    }
}
