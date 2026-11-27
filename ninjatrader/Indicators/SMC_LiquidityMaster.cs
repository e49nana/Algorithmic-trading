#region Using declarations
using System;
using System.Collections.Generic;
using NinjaTrader.NinjaScript;
using NinjaTrader.Data;
using NinjaTrader.NinjaScript.Indicators;
using NinjaTrader.NinjaScript.DrawingTools;
#endregion

namespace NinjaTrader.NinjaScript.Indicators
{
    public class SMC_LiquidityMaster : Indicator
    {
        private Swing swingM15;
        private Swing swingH4;
        private double tickTolerance;

        private List<double> trackedBSL = new List<double>();
        private List<double> trackedSSL = new List<double>();
        private Dictionary<double, int> breakoutTrapCandidates = new Dictionary<double, int>();

        private List<int> swingHighBars = new List<int>();
        private List<int> swingLowBars = new List<int>();

        [Range(1, 20), NinjaScriptProperty]
        public int SwingStrength { get; set; }

        [Range(1, 10), NinjaScriptProperty]
        public int EqualToleranceTicks { get; set; }

        [Range(2, 10), NinjaScriptProperty]
        public int TrapRetestBars { get; set; }

        [Range(2, 10), NinjaScriptProperty]
        public int MinTrendlinePoints { get; set; }

        protected override void OnStateChange()
        {
            if (State == State.SetDefaults)
            {
                Description = "Unified SMC Liquidity Indicator: SSL/BSL, grabs, traps, POIs, trendlines, and multi-timeframe (M15 + H4)";
                Name = "SMC_LiquidityMaster";
                Calculate = MarketCalculate.OnBarClose;
                IsOverlay = true;
                SwingStrength = 5;
                EqualToleranceTicks = 2;
                TrapRetestBars = 3;
                MinTrendlinePoints = 2;
            }
            else if (State == State.Configure)
            {
                AddDataSeries(Data.BarsPeriodType.Minute, 240); // H4
            }
            else if (State == State.DataLoaded)
            {
                swingM15 = Swing(BarsArray[0], SwingStrength);
                swingH4 = Swing(BarsArray[1], SwingStrength);
                tickTolerance = EqualToleranceTicks * TickSize;
            }
        }

        protected override void OnBarUpdate()
        {
            if (BarsInProgress == 1)
            {
                DrawLiquidityZones(swingH4, "HTF", Brushes.DodgerBlue, Brushes.IndianRed, DashStyleHelper.Dash);
                return;
            }

            if (CurrentBar < SwingStrength + 3)
                return;

            double high = High[0];
            double low = Low[0];

            // === Equal Highs / Lows from M15 ===
            DrawLiquidityZones(swingM15, "M15", Brushes.LightBlue, Brushes.LightPink, DashStyleHelper.Solid);

            // === Liquidity Sweeps ===
            foreach (var zone in trackedBSL.ToArray())
            {
                if (high > zone + TickSize)
                {
                    Draw.Text(this, "BSL_Grab_" + CurrentBar, "BSL Grab", 0, zone + 5 * TickSize, Brushes.DarkBlue);
                    if (!breakoutTrapCandidates.ContainsKey(zone))
                        breakoutTrapCandidates[zone] = CurrentBar;
                    trackedBSL.Remove(zone);
                }
            }
            foreach (var zone in trackedSSL.ToArray())
            {
                if (low < zone - TickSize)
                {
                    Draw.Text(this, "SSL_Grab_" + CurrentBar, "SSL Grab", 0, zone - 5 * TickSize, Brushes.DarkRed);
                    if (!breakoutTrapCandidates.ContainsKey(zone))
                        breakoutTrapCandidates[zone] = CurrentBar;
                    trackedSSL.Remove(zone);
                }
            }

            // === Breakout Trap Detection ===
            foreach (var kvp in breakoutTrapCandidates)
            {
                double zone = kvp.Key;
                int breakoutBar = kvp.Value;

                if (CurrentBar - breakoutBar <= TrapRetestBars)
                {
                    if (Math.Abs(Close[0] - zone) <= tickTolerance)
                    {
                        if (Close[0] < Open[0])
                            Draw.Text(this, "Trap_SSL_" + CurrentBar, "Trap (SSL)", 0, zone - 7 * TickSize, Brushes.Purple);
                        else if (Close[0] > Open[0])
                            Draw.Text(this, "Trap_BSL_" + CurrentBar, "Trap (BSL)", 0, zone + 7 * TickSize, Brushes.Purple);
                    }
                }
            }

            // === POI (Rejection Wicks) ===
            foreach (double zone in breakoutTrapCandidates.Keys)
            {
                if (High[0] > zone && Close[0] < Open[0])
                    Draw.Dot(this, "POI_WickHigh_" + CurrentBar, true, 0, High[0], Brushes.Gold);
                if (Low[0] < zone && Close[0] > Open[0])
                    Draw.Dot(this, "POI_WickLow_" + CurrentBar, true, 0, Low[0], Brushes.Gold);
            }

            // === Trendline Detection ===
            if (swingM15.SwingHigh[0] != double.MinValue)
            {
                swingHighBars.Add(CurrentBar);
                if (swingHighBars.Count > 20) swingHighBars.RemoveAt(0);
            }
            if (swingM15.SwingLow[0] != double.MinValue)
            {
                swingLowBars.Add(CurrentBar);
                if (swingLowBars.Count > 20) swingLowBars.RemoveAt(0);
            }

            if (swingHighBars.Count >= MinTrendlinePoints)
            {
                int bar1 = swingHighBars[swingHighBars.Count - MinTrendlinePoints];
                int bar2 = swingHighBars[swingHighBars.Count - 1];
                double price1 = swingM15.SwingHigh[CurrentBar - bar1];
                double price2 = swingM15.SwingHigh[CurrentBar - bar2];
                Draw.Line(this, "BearTrend_" + CurrentBar, false, CurrentBar - bar1, price1, CurrentBar - bar2, price2, Brushes.Red, DashStyleHelper.Dash, 2);
                Draw.Text(this, "TrendBSL_" + CurrentBar, "BSL (Trendline)", 0, price2 + 3 * TickSize, Brushes.Red);
            }

            if (swingLowBars.Count >= MinTrendlinePoints)
            {
                int bar1 = swingLowBars[swingLowBars.Count - MinTrendlinePoints];
                int bar2 = swingLowBars[swingLowBars.Count - 1];
                double price1 = swingM15.SwingLow[CurrentBar - bar1];
                double price2 = swingM15.SwingLow[CurrentBar - bar2];
                Draw.Line(this, "BullTrend_" + CurrentBar, false, CurrentBar - bar1, price1, CurrentBar - bar2, price2, Brushes.Green, DashStyleHelper.Dash, 2);
                Draw.Text(this, "TrendSSL_" + CurrentBar, "SSL (Trendline)", 0, price2 - 3 * TickSize, Brushes.Green);
            }
        }

        private void DrawLiquidityZones(Swing swingRef, string tagPrefix, Brush bslColor, Brush sslColor, DashStyleHelper dash)
        {
            if (CurrentBar < SwingStrength + 3)
                return;

            double tickTol = tickTolerance;

            if (swingRef.SwingHigh[0] != double.MinValue)
            {
                for (int back = 1; back <= 10; back++)
                {
                    if (swingRef.SwingHigh[back] != double.MinValue &&
                        Math.Abs(swingRef.SwingHigh[0] - swingRef.SwingHigh[back]) <= tickTol)
                    {
                        double zone = swingRef.SwingHigh[0];
                        string tag = tagPrefix + "_BSL_" + CurrentBar;
                        Draw.Rectangle(this, tag, false, back, zone + 2 * TickSize, 0, zone, bslColor, Brushes.Transparent, 2);
                        Draw.Text(this, tag + "_Label", tagPrefix + " BSL", 0, zone + 3 * TickSize, bslColor);
                        if (tagPrefix == "M15" && !trackedBSL.Contains(zone)) trackedBSL.Add(zone);
                        break;
                    }
                }
            }

            if (swingRef.SwingLow[0] != double.MinValue)
            {
                for (int back = 1; back <= 10; back++)
                {
                    if (swingRef.SwingLow[back] != double.MinValue &&
                        Math.Abs(swingRef.SwingLow[0] - swingRef.SwingLow[back]) <= tickTol)
                    {
                        double zone = swingRef.SwingLow[0];
                        string tag = tagPrefix + "_SSL_" + CurrentBar;
                        Draw.Rectangle(this, tag, false, back, zone, 0, zone - 2 * TickSize, sslColor, Brushes.Transparent, 2);
                        Draw.Text(this, tag + "_Label", tagPrefix + " SSL", 0, zone - 3 * TickSize, sslColor);
                        if (tagPrefix == "M15" && !trackedSSL.Contains(zone)) trackedSSL.Add(zone);
                        break;
                    }
                }
            }
        }
    }
}
