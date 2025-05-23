#region Using declarations
using System;
using NinjaTrader.Data;
using NinjaTrader.NinjaScript;
using NinjaTrader.NinjaScript.Indicators;
using NinjaTrader.NinjaScript.DrawingTools;
#endregion

namespace NinjaTrader.NinjaScript.Indicators
{
    public class PremiumDiscountZones : Indicator
    {
        private Swing swing;
        private Series<double> zoneHigh, zoneLow, zoneMid;

        [Range(1, 20), NinjaScriptProperty]
        [Display(Name = "Swing Strength", Order = 0, GroupName = "Parameters")]
        public int SwingStrength { get; set; }

        [Range(0.1, 0.99), NinjaScriptProperty]
        [Display(Name = "Fib 0.50", Order = 1, GroupName = "Fibonacci")]
        public double Fib50 { get; set; }

        [Range(0.1, 0.99), NinjaScriptProperty]
        [Display(Name = "Fib 0.618", Order = 2, GroupName = "Fibonacci")]
        public double Fib618 { get; set; }

        [Range(0.1, 0.99), NinjaScriptProperty]
        [Display(Name = "Fib 0.705", Order = 3, GroupName = "Fibonacci")]
        public double Fib705 { get; set; }

        [Range(0.1, 0.99), NinjaScriptProperty]
        [Display(Name = "Fib 0.786", Order = 4, GroupName = "Fibonacci")]
        public double Fib786 { get; set; }

        protected override void OnStateChange()
        {
            if (State == State.SetDefaults)
            {
                Name = "PremiumDiscountZones";
                Description = "Detects premium and discount zones using Fibonacci levels with auto-trend detection.";
                Calculate = MarketCalculate.OnBarClose;
                IsOverlay = true;
                SwingStrength = 5;

                Fib50 = 0.5;
                Fib618 = 0.618;
                Fib705 = 0.705;
                Fib786 = 0.786;
            }
            else if (State == State.DataLoaded)
            {
                swing = Swing(SwingStrength);
                zoneHigh = new Series<double>(this);
                zoneLow = new Series<double>(this);
                zoneMid = new Series<double>(this);
            }
        }

        protected override void OnBarUpdate()
        {
            if (CurrentBar < SwingStrength + 10)
                return;

            zoneHigh[0] = zoneHigh[1];
            zoneLow[0] = zoneLow[1];
            zoneMid[0] = zoneMid[1];

            // Auto-trend detection based on swing structure
            double currentHigh = swing.SwingHigh[1];
            double currentLow = swing.SwingLow[1];
            bool isBullish = currentHigh > swing.SwingHigh[3] && currentLow > swing.SwingLow[3];
            bool isBearish = currentHigh < swing.SwingHigh[3] && currentLow < swing.SwingLow[3];

            RemoveDrawObject("ZoneTop");
            RemoveDrawObject("ZoneBot");
            RemoveDrawObject("ZoneLabel");

            if (isBullish)
            {
                double discTop = currentHigh - (currentHigh - currentLow) * Fib50;
                double discBottom = currentHigh - (currentHigh - currentLow) * Fib786;

                Draw.HorizontalLine(this, "ZoneTop", discTop, Brushes.ForestGreen);
                Draw.HorizontalLine(this, "ZoneBot", discBottom, Brushes.ForestGreen);
                Draw.Text(this, "ZoneLabel", "Discount Zone", 0, discTop + TickSize * 2, Brushes.ForestGreen);

                zoneHigh[0] = discTop;
                zoneLow[0] = discBottom;
                zoneMid[0] = (discTop + discBottom) / 2;
            }
            else if (isBearish)
            {
                double premTop = currentLow + (currentHigh - currentLow) * Fib786;
                double premBottom = currentLow + (currentHigh - currentLow) * Fib50;

                Draw.HorizontalLine(this, "ZoneTop", premTop, Brushes.IndianRed);
                Draw.HorizontalLine(this, "ZoneBot", premBottom, Brushes.IndianRed);
                Draw.Text(this, "ZoneLabel", "Premium Zone", 0, premTop + TickSize * 2, Brushes.IndianRed);

                zoneHigh[0] = premTop;
                zoneLow[0] = premBottom;
                zoneMid[0] = (premTop + premBottom) / 2;
            }
        }

        #region Public Outputs
        [Browsable(false)]
        [XmlIgnore()]
        public Series<double> ZoneHigh => zoneHigh;

        [Browsable(false)]
        [XmlIgnore()]
        public Series<double> ZoneLow => zoneLow;

        [Browsable(false)]
        [XmlIgnore()]
        public Series<double> ZoneMid => zoneMid;
        #endregion
    }
}
