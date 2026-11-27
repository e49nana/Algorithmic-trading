#region Using declarations
using System;
using NinjaTrader.Data;
using NinjaTrader.Gui.Tools;
using NinjaTrader.NinjaScript;
using NinjaTrader.NinjaScript.Indicators;
using NinjaTrader.NinjaScript.DrawingTools;
#endregion

namespace NinjaTrader.NinjaScript.Indicators
{
    public class FairValueGapDetector : Indicator
    {
        private const int ExtensionBars = 10;

        private Series<double> bullishFVGHigh;
        private Series<double> bullishFVGLow;
        private Series<double> bullishFVGMid;

        private Series<double> bearishFVGHigh;
        private Series<double> bearishFVGLow;
        private Series<double> bearishFVGMid;

        [Range(1, 100), NinjaScriptProperty]
        [Display(Name = "Minimum Gap Size (in Ticks)", GroupName = "Parameters", Order = 1)]
        public int MinGapTicks { get; set; }

        protected override void OnStateChange()
        {
            if (State == State.SetDefaults)
            {
                Name = "FairValueGapDetector";
                Description = "Detects and plots Bullish and Bearish Fair Value Gaps.";
                Calculate = MarketCalculate.OnBarClose;
                IsOverlay = true;
                MinGapTicks = 1;
            }
            else if (State == State.DataLoaded)
            {
                bullishFVGHigh = new Series<double>(this);
                bullishFVGLow = new Series<double>(this);
                bullishFVGMid = new Series<double>(this);

                bearishFVGHigh = new Series<double>(this);
                bearishFVGLow = new Series<double>(this);
                bearishFVGMid = new Series<double>(this);
            }
        }

        protected override void OnBarUpdate()
        {
            if (CurrentBar < 2)
                return;

            // Candle indices
            int prev = 2;
            int mid = 1;
            int next = 0;

            double prevLow = Low[prev];
            double prevHigh = High[prev];
            double nextLow = Low[next];
            double nextHigh = High[next];

            double bodyHigh = Math.Max(Open[mid], Close[mid]);
            double bodyLow = Math.Min(Open[mid], Close[mid]);
            double bodySize = bodyHigh - bodyLow;

            double minGapSize = MinGapTicks * TickSize;

            // === Bullish FVG ===
            if (Close[mid] > Open[mid] // Green candle
                && prevLow < bodyLow
                && nextLow < bodyLow
                && bodySize >= minGapSize)
            {
                Draw.Rectangle(this, "BullFVG_" + CurrentBar, false,
                    ExtensionBars, bodyHigh,
                    0, bodyLow,
                    Brushes.LimeGreen, Brushes.Transparent, 2);

                Draw.Text(this, "BullFVG_Label_" + CurrentBar,
                    "Bullish FVG", 0, bodyHigh + 2 * TickSize, Brushes.Green);

                bullishFVGHigh[0] = bodyHigh;
                bullishFVGLow[0] = bodyLow;
                bullishFVGMid[0] = (bodyHigh + bodyLow) / 2;
            }

            // === Bearish FVG ===
            if (Close[mid] < Open[mid] // Red candle
                && prevHigh > bodyHigh
                && nextHigh > bodyHigh
                && bodySize >= minGapSize)
            {
                Draw.Rectangle(this, "BearFVG_" + CurrentBar, false,
                    ExtensionBars, bodyHigh,
                    0, bodyLow,
                    Brushes.IndianRed, Brushes.Transparent, 2);

                Draw.Text(this, "BearFVG_Label_" + CurrentBar,
                    "Bearish FVG", 0, bodyLow - 2 * TickSize, Brushes.Maroon);

                bearishFVGHigh[0] = bodyHigh;
                bearishFVGLow[0] = bodyLow;
                bearishFVGMid[0] = (bodyHigh + bodyLow) / 2;
            }

            // Preserve previous FVG levels if none found this bar
            bullishFVGHigh[0] = bullishFVGHigh[1];
            bullishFVGLow[0] = bullishFVGLow[1];
            bullishFVGMid[0] = bullishFVGMid[1];

            bearishFVGHigh[0] = bearishFVGHigh[1];
            bearishFVGLow[0] = bearishFVGLow[1];
            bearishFVGMid[0] = bearishFVGMid[1];
        }

        #region Public FVG Series
        [Browsable(false)]
        [XmlIgnore()]
        public Series<double> BullishFVGHigh => bullishFVGHigh;

        [Browsable(false)]
        [XmlIgnore()]
        public Series<double> BullishFVGLow => bullishFVGLow;

        [Browsable(false)]
        [XmlIgnore()]
        public Series<double> BullishFVGMid => bullishFVGMid;

        [Browsable(false)]
        [XmlIgnore()]
        public Series<double> BearishFVGHigh => bearishFVGHigh;

        [Browsable(false)]
        [XmlIgnore()]
        public Series<double> BearishFVGLow => bearishFVGLow;

        [Browsable(false)]
        [XmlIgnore()]
        public Series<double> BearishFVGMid => bearishFVGMid;
        #endregion
    }
}
