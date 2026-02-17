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
using NinjaTrader.Gui.Chart;
using NinjaTrader.NinjaScript;
using NinjaTrader.NinjaScript.DrawingTools;
#endregion

namespace NinjaTrader.NinjaScript.Indicators
{
    /// <summary>
    /// SMC Liquidity Map v8 — Mouna Bouhlal Strategy Module 1
    ///
    /// Uses SwingHighBar() / SwingLowBar() to enumerate ALL confirmed swings.
    /// Guarantees 1:1 match with NT8 Swing indicator dots.
    ///
    /// Every swing high = BSL. Every swing low = SSL.
    /// Equal highs/lows get visual emphasis.
    /// Lines terminate when swept.
    /// </summary>
    public class SMC_LiquidityMap : Indicator
    {
        // =================================================================
        // PARAMETERS
        // =================================================================

        [NinjaScriptProperty]
        [Range(1, 20)]
        [Display(Name = "Swing Strength",
                 Description = "NT8 Swing Strength. Higher = fewer, bigger swings.",
                 Order = 1, GroupName = "1. Detection")]
        public int SwingStrength { get; set; }

        [NinjaScriptProperty]
        [Range(1, 200)]
        [Display(Name = "Equal Level Tolerance (Ticks)",
                 Description = "Max distance in ticks for 'equal highs/lows'",
                 Order = 2, GroupName = "1. Detection")]
        public int EqualLevelToleranceTicks { get; set; }

        [NinjaScriptProperty]
        [Range(0, 2000)]
        [Display(Name = "Max Lookback Bars",
                 Description = "How far back to draw levels (0 = no limit)",
                 Order = 3, GroupName = "1. Detection")]
        public int MaxLookbackBars { get; set; }

        // --- Visuals ---

        [NinjaScriptProperty]
        [Display(Name = "Show Single Swing Levels",
                 Description = "Thin dotted lines at every swing. Off = only equal/retested.",
                 Order = 1, GroupName = "2. Visuals")]
        public bool ShowSingleSwingLevels { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Show Labels", Order = 2, GroupName = "2. Visuals")]
        public bool ShowLabels { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Show Sweep Arrows", Order = 3, GroupName = "2. Visuals")]
        public bool ShowSweepArrows { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Show Swept Levels", Order = 4, GroupName = "2. Visuals")]
        public bool ShowSweptLevels { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Show Swing Dots",
                 Description = "Render swing high/low dots (replaces NT8 Swing indicator)",
                 Order = 5, GroupName = "2. Visuals")]
        public bool ShowSwingDots { get; set; }

        // --- Colors ---

        [XmlIgnore]
        [Display(Name = "SSL Color", Order = 1, GroupName = "3. Colors")]
        public Brush SSLBrush { get; set; }
        [Browsable(false)]
        public string SSLBrushSerialize
        { get { return Serialize.BrushToString(SSLBrush); } set { SSLBrush = Serialize.StringToBrush(value); } }

        [XmlIgnore]
        [Display(Name = "BSL Color", Order = 2, GroupName = "3. Colors")]
        public Brush BSLBrush { get; set; }
        [Browsable(false)]
        public string BSLBrushSerialize
        { get { return Serialize.BrushToString(BSLBrush); } set { BSLBrush = Serialize.StringToBrush(value); } }

        [XmlIgnore]
        [Display(Name = "Swept Level Color", Order = 3, GroupName = "3. Colors")]
        public Brush SweptBrush { get; set; }
        [Browsable(false)]
        public string SweptBrushSerialize
        { get { return Serialize.BrushToString(SweptBrush); } set { SweptBrush = Serialize.StringToBrush(value); } }

        [XmlIgnore]
        [Display(Name = "Wick Sweep Color", Order = 4, GroupName = "3. Colors")]
        public Brush WickSweepBrush { get; set; }
        [Browsable(false)]
        public string WickSweepBrushSerialize
        { get { return Serialize.BrushToString(WickSweepBrush); } set { WickSweepBrush = Serialize.StringToBrush(value); } }

        [XmlIgnore]
        [Display(Name = "Swing High Dot Color", Order = 5, GroupName = "3. Colors")]
        public Brush SwingHighDotBrush { get; set; }
        [Browsable(false)]
        public string SwingHighDotBrushSerialize
        { get { return Serialize.BrushToString(SwingHighDotBrush); } set { SwingHighDotBrush = Serialize.StringToBrush(value); } }

        [XmlIgnore]
        [Display(Name = "Swing Low Dot Color", Order = 6, GroupName = "3. Colors")]
        public Brush SwingLowDotBrush { get; set; }
        [Browsable(false)]
        public string SwingLowDotBrushSerialize
        { get { return Serialize.BrushToString(SwingLowDotBrush); } set { SwingLowDotBrush = Serialize.StringToBrush(value); } }

        // =================================================================
        // INTERNAL
        // =================================================================

        private Swing               _swing;
        private List<LiqLevel>      _levels;
        private HashSet<int>        _registeredHighBars;  // Absolute bar indices already registered
        private HashSet<int>        _registeredLowBars;
        private HashSet<int>        _drawnHighDots;       // Track drawn swing dots
        private HashSet<int>        _drawnLowDots;
        private double              _equalTol;

        // =================================================================
        // LIFECYCLE
        // =================================================================

        protected override void OnStateChange()
        {
            if (State == State.SetDefaults)
            {
                Description      = "SMC Liquidity Map v8 — Mouna Bouhlal Strategy";
                Name             = "SMC_LiquidityMap";
                Calculate        = Calculate.OnBarClose;
                IsOverlay        = true;
                DisplayInDataBox = false;
                DrawOnPricePanel = true;
                IsSuspendedWhileInactive = true;

                SwingStrength           = 3;
                EqualLevelToleranceTicks = 8;
                MaxLookbackBars         = 300;

                ShowSingleSwingLevels = true;
                ShowLabels            = true;
                ShowSweepArrows       = true;
                ShowSweptLevels       = true;
                ShowSwingDots         = true;

                SSLBrush         = Brushes.Crimson;
                BSLBrush         = Brushes.DodgerBlue;
                SweptBrush       = Brushes.DimGray;
                WickSweepBrush   = Brushes.Lime;
                SwingHighDotBrush = Brushes.DarkCyan;
                SwingLowDotBrush  = Brushes.Goldenrod;
            }
            else if (State == State.DataLoaded)
            {
                _swing              = Swing(SwingStrength);
                _levels             = new List<LiqLevel>();
                _registeredHighBars = new HashSet<int>();
                _registeredLowBars  = new HashSet<int>();
                _drawnHighDots      = new HashSet<int>();
                _drawnLowDots       = new HashSet<int>();
                _equalTol           = EqualLevelToleranceTicks * TickSize;
            }
        }

        protected override void OnBarUpdate()
        {
            int minBars = 2 * SwingStrength + 1;
            if (CurrentBar < minBars) return;

            ScanSwings();
            DetectSweeps();
            DrawAll();
            Cleanup();
        }

        // =================================================================
        // SCAN ALL SWINGS from NT8 Swing indicator
        //
        // On each bar, we use SwingHighBar/SwingLowBar to enumerate
        // every swing instance within the lookback window.
        // The HashSet prevents re-registering the same swing.
        // This guarantees perfect 1:1 match with Swing dots.
        // =================================================================

        private void ScanSwings()
        {
            int lookback = MaxLookbackBars > 0 ? MaxLookbackBars : Math.Min(CurrentBar, 500);

            // --- Scan all swing highs ---
            for (int instance = 1; instance <= 50; instance++)
            {
                int barsAgo = _swing.SwingHighBar(0, instance, lookback);
                if (barsAgo < 0) break;  // No more swing highs found

                int absBar = CurrentBar - barsAgo;

                // Skip if already registered
                if (_registeredHighBars.Contains(absBar)) continue;
                _registeredHighBars.Add(absBar);

                double price = High[barsAgo];
                RegisterLevel(LiqSide.BSL, price, absBar);

                // Draw swing high dot
                if (ShowSwingDots && !_drawnHighDots.Contains(absBar))
                {
                    Draw.Dot(this, "SWH_" + absBar, false, barsAgo, price, SwingHighDotBrush);
                    _drawnHighDots.Add(absBar);
                }
            }

            // --- Scan all swing lows ---
            for (int instance = 1; instance <= 50; instance++)
            {
                int barsAgo = _swing.SwingLowBar(0, instance, lookback);
                if (barsAgo < 0) break;

                int absBar = CurrentBar - barsAgo;

                if (_registeredLowBars.Contains(absBar)) continue;
                _registeredLowBars.Add(absBar);

                double price = Low[barsAgo];
                RegisterLevel(LiqSide.SSL, price, absBar);

                // Draw swing low dot
                if (ShowSwingDots && !_drawnLowDots.Contains(absBar))
                {
                    Draw.Dot(this, "SWL_" + absBar, false, barsAgo, price, SwingLowDotBrush);
                    _drawnLowDots.Add(absBar);
                }
            }
        }

        // =================================================================
        // REGISTER LEVEL + EQUAL CHECK
        // =================================================================

        private void RegisterLevel(LiqSide side, double price, int barIndex)
        {
            var lev = new LiqLevel
            {
                Side     = side,
                Price    = price,
                BarIndex = barIndex
            };

            // Check for equal highs/lows
            foreach (var ex in _levels)
            {
                if (ex.Side != side || ex.IsSwept) continue;
                if (Math.Abs(ex.Price - price) <= _equalTol)
                {
                    ex.IsEqual = true;
                    ex.EqualCount++;
                    lev.IsEqual = true;
                    lev.EqualCount++;
                }
            }

            _levels.Add(lev);
        }

        // =================================================================
        // SWEEP DETECTION
        // =================================================================

        private void DetectSweeps()
        {
            double hi = High[0];
            double lo = Low[0];
            double cl = Close[0];

            foreach (var lev in _levels)
            {
                if (lev.IsSwept) continue;
                if (lev.BarIndex >= CurrentBar) continue;

                if (lev.Side == LiqSide.BSL && hi > lev.Price)
                {
                    lev.IsSwept    = true;
                    lev.SweptAtBar = CurrentBar;
                    lev.SweptPrice = hi;
                    lev.WickSweep  = cl < lev.Price;
                }
                else if (lev.Side == LiqSide.SSL && lo < lev.Price)
                {
                    lev.IsSwept    = true;
                    lev.SweptAtBar = CurrentBar;
                    lev.SweptPrice = lo;
                    lev.WickSweep  = cl > lev.Price;
                }
            }
        }

        // =================================================================
        // DRAWING
        // =================================================================

        private void DrawAll()
        {
            int lookback = MaxLookbackBars > 0 ? MaxLookbackBars : 500;

            foreach (var lev in _levels)
            {
                int baForm = CurrentBar - lev.BarIndex;
                if (baForm < 0 || baForm > lookback) continue;

                bool isSSL  = lev.Side == LiqSide.SSL;
                Brush color = isSSL ? SSLBrush : BSLBrush;
                string bTag = (isSSL ? "SSL_" : "BSL_") + lev.BarIndex;

                // ------- ACTIVE level -------
                if (!lev.IsSwept)
                {
                    if (!lev.IsEqual && !ShowSingleSwingLevels) continue;

                    int width;
                    DashStyleHelper dash;

                    if (lev.IsEqual && lev.EqualCount >= 2)
                    { width = 3; dash = DashStyleHelper.Solid; }
                    else if (lev.IsEqual)
                    { width = 2; dash = DashStyleHelper.Solid; }
                    else
                    { width = 1; dash = DashStyleHelper.Dot; }

                    Draw.Line(this, bTag, false,
                        baForm, lev.Price, 0, lev.Price,
                        color, dash, width);

                    if (lev.IsEqual && ShowLabels)
                    {
                        string lt  = "L_" + bTag;
                        string txt = isSSL ? "SSL (EQL)" : "BSL (EQH)";
                        if (lev.EqualCount >= 2) txt += " ★";

                        double off = isSSL ? -5 * TickSize : 5 * TickSize;
                        Draw.Text(this, lt, false, txt,
                            2, lev.Price + off, 0,
                            color, new Gui.Tools.SimpleFont("Arial", 10),
                            TextAlignment.Right, Brushes.Transparent, Brushes.Transparent, 0);
                    }
                }
                // ------- SWEPT level -------
                else
                {
                    int baSwept = CurrentBar - lev.SweptAtBar;
                    if (baSwept < 0) continue;

                    if (ShowSweptLevels)
                    {
                        if (!lev.IsEqual && !ShowSingleSwingLevels) continue;

                        Draw.Line(this, bTag, false,
                            baForm, lev.Price, baSwept, lev.Price,
                            SweptBrush, DashStyleHelper.Dot, 1);
                    }
                    else
                    {
                        RemoveDrawObject(bTag);
                    }

                    RemoveDrawObject("L_" + bTag);

                    if (ShowSweepArrows && !lev.DrawnArrow)
                    {
                        string aTag  = "SWP_" + lev.BarIndex + "_" + lev.SweptAtBar;
                        Brush aBrush = lev.WickSweep ? WickSweepBrush : color;

                        if (isSSL)
                            Draw.ArrowUp(this, aTag, false, baSwept,
                                lev.SweptPrice - 8 * TickSize, aBrush);
                        else
                            Draw.ArrowDown(this, aTag, false, baSwept,
                                lev.SweptPrice + 8 * TickSize, aBrush);

                        lev.DrawnArrow = true;
                    }
                }
            }
        }

        // =================================================================
        // CLEANUP
        // =================================================================

        private void Cleanup()
        {
            int lookback = MaxLookbackBars > 0 ? MaxLookbackBars : 500;
            if (_levels.Count > 500)
                _levels.RemoveAll(l => l.IsSwept && (CurrentBar - l.SweptAtBar) > lookback);
        }

        // =================================================================
        // DATA MODEL
        // =================================================================

        private enum LiqSide { SSL, BSL }

        private class LiqLevel
        {
            public LiqSide  Side;
            public double   Price;
            public int      BarIndex;

            public bool     IsEqual;
            public int      EqualCount;

            public bool     IsSwept;
            public int      SweptAtBar = -1;
            public double   SweptPrice;
            public bool     WickSweep;

            public bool     DrawnArrow;
        }
    }
}
