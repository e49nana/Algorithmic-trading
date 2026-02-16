#region Using declarations
using System;
using System.Collections.Generic;
using NinjaTrader.Cbi;
using NinjaTrader.Gui.Tools;
using NinjaTrader.NinjaScript;
using NinjaTrader.Data;
using NinjaTrader.Gui;
using NinjaTrader.NinjaScript.Indicators;
using NinjaTrader.NinjaScript.DrawingTools;
#endregion

namespace NinjaTrader.NinjaScript.Indicators
{
    public class LiquidityZonesWithTrendlines : Indicator
    {
        private Swing swing;
        private double tickTolerance;

        private List<double> trackedBSL = new List<double>();
        private List<double> trackedSSL = new List<double>();
        private List<int> swingHighBars = new List<int>();
        private List<int> swingLowBars = new List<int>();

        [Range(1, 20), NinjaScriptProperty]
        [Display(Name = "Swing Strength", Order = 1, GroupName = "Parameters")]
        public int SwingStrength { get; set; }

        [Range(1, 10), NinjaScriptProperty]
        [Display(Name = "Equal High/Low Tolerance (Ticks)", Order = 2, GroupName = "Parameters")]
        public int EqualToleranceTicks { get; set; }

        [Range(2, 10), NinjaScriptProperty]
        [Display(Name = "Minimum Points for Trendline", Order = 3, GroupName = "Parameters")]
        public int MinTrendlinePoints { get; set; }

        protected override void OnStateChange()
        {
            if (State == State.SetDefaults)
            {
                Description = "Detects Buy/Sell-side liquidity from equal highs/lows and trendlines.";
                Name = "LiquidityZonesWithTrendlines";
                Calculate = MarketCalculate.OnBarClose;
                IsOverlay = true;
                SwingStrength = 5;
                EqualToleranceTicks = 2;
                MinTrendlinePoints = 2;
            }
            else if (State == State.DataLoaded)
            {
                swing = Swing(SwingStrength);
                tickTolerance = EqualToleranceTicks * TickSize;
            }
        }

        protected override void OnBarUpdate()
        {
            if (CurrentBar < SwingStrength + 2)
                return;

            double high = High[0];
            double low = Low[0];

            // === Equal Highs (BSL) ===
            if (swing.SwingHigh[0] != double.MinValue)
            {
                for (int back = 1; back <= 10; back++)
                {
                    if (swing.SwingHigh[back] != double.MinValue &&
                        Math.Abs(swing.SwingHigh[0] - swing.SwingHigh[back]) <= tickTolerance)
                    {
                        double zone = swing.SwingHigh[0];
                        Draw.Rectangle(this, "BSL_Zone_" + CurrentBar, false,
                            back, zone + 2 * TickSize,
                            0, zone,
                            Brushes.LightBlue, Brushes.Transparent, 2);
                        Draw.Text(this, "BSL_Label_" + CurrentBar, "BSL", 0, zone + 3 * TickSize, Brushes.Blue);
                        if (!trackedBSL.Contains(zone)) trackedBSL.Add(zone);
                        break;
                    }
                }
            }

            // === Equal Lows (SSL) ===
            if (swing.SwingLow[0] != double.MinValue)
            {
                for (int back = 1; back <= 10; back++)
                {
                    if (swing.SwingLow[back] != double.MinValue &&
                        Math.Abs(swing.SwingLow[0] - swing.SwingLow[back]) <= tickTolerance)
                    {
                        double zone = swing.SwingLow[0];
                        Draw.Rectangle(this, "SSL_Zone_" + CurrentBar, false,
                            back, zone,
                            0, zone - 2 * TickSize,
                            Brushes.LightPink, Brushes.Transparent, 2);
                        Draw.Text(this, "SSL_Label_" + CurrentBar, "SSL", 0, zone - 3 * TickSize, Brushes.Red);
                        if (!trackedSSL.Contains(zone)) trackedSSL.Add(zone);
                        break;
                    }
                }
            }

            // === Detect BSL Sweep ===
            foreach (var zone in trackedBSL.ToArray())
            {
                if (high > zone + TickSize)
                {
                    Draw.Text(this, "BSL_Grab_" + CurrentBar, "BSL Grab", 0, zone + 5 * TickSize, Brushes.DarkBlue);
                    trackedBSL.Remove(zone);
                }
            }

            // === Detect SSL Sweep ===
            foreach (var zone in trackedSSL.ToArray())
            {
                if (low < zone - TickSize)
                {
                    Draw.Text(this, "SSL_Grab_" + CurrentBar, "SSL Grab", 0, zone - 5 * TickSize, Brushes.DarkRed);
                    trackedSSL.Remove(zone);
                }
            }

            // === Update Trendline Buffers ===
            if (swing.SwingHigh[0] != double.MinValue)
            {
                swingHighBars.Add(CurrentBar);
                if (swingHighBars.Count > 20) swingHighBars.RemoveAt(0);
            }

            if (swing.SwingLow[0] != double.MinValue)
            {
                swingLowBars.Add(CurrentBar);
                if (swingLowBars.Count > 20) swingLowBars.RemoveAt(0);
            }

            // === Bearish Trendline → Buy-Side Liquidity ===
            if (swingHighBars.Count >= MinTrendlinePoints)
            {
                int bar1 = swingHighBars[swingHighBars.Count - MinTrendlinePoints];
                int bar2 = swingHighBars[swingHighBars.Count - 1];
                double price1 = swing.SwingHigh[CurrentBar - bar1];
                double price2 = swing.SwingHigh[CurrentBar - bar2];

                Draw.Line(this, "BearTrend_" + CurrentBar, false,
                    CurrentBar - bar1, price1,
                    CurrentBar - bar2, price2,
                    Brushes.Red, DashStyleHelper.Dash, 2);

                Draw.Text(this, "BSL_Trend_" + CurrentBar, "BSL (Trendline)", 0, price2 + 3 * TickSize, Brushes.Red);
            }

            // === Bullish Trendline → Sell-Side Liquidity ===
            if (swingLowBars.Count >= MinTrendlinePoints)
            {
                int bar1 = swingLowBars[swingLowBars.Count - MinTrendlinePoints];
                int bar2 = swingLowBars[swingLowBars.Count - 1];
                double price1 = swing.SwingLow[CurrentBar - bar1];
                double price2 = swing.SwingLow[CurrentBar - bar2];

                Draw.Line(this, "BullTrend_" + CurrentBar, false,
                    CurrentBar - bar1, price1,
                    CurrentBar - bar2, price2,
                    Brushes.Green, DashStyleHelper.Dash, 2);

                Draw.Text(this, "SSL_Trend_" + CurrentBar, "SSL (Trendline)", 0, price2 - 3 * TickSize, Brushes.Green);
            }
        }
    }
}
