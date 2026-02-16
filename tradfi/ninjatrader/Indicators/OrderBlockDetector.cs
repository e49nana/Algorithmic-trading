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
    public class OrderBlockDetector : Indicator
    {
        private Swing swing;

        private Series<double> bullishOBLow;
        private Series<double> bullishOBHigh;
        private Series<double> bullishOBMid;

        private Series<double> bearishOBLow;
        private Series<double> bearishOBHigh;
        private Series<double> bearishOBMid;

        [Range(1, 20), NinjaScriptProperty]
        public int SwingStrength { get; set; }

        protected override void OnStateChange()
        {
            if (State == State.SetDefaults)
            {
                Name = "OrderBlockDetector";
                Description = "Detects bullish and bearish order blocks after BOS and exposes OB levels for strategy use.";
                Calculate = MarketCalculate.OnBarClose;
                IsOverlay = true;
                SwingStrength = 5;
            }
            else if (State == State.DataLoaded)
            {
                swing = Swing(SwingStrength);

                bullishOBLow = new Series<double>(this);
                bullishOBHigh = new Series<double>(this);
                bullishOBMid = new Series<double>(this);

                bearishOBLow = new Series<double>(this);
                bearishOBHigh = new Series<double>(this);
                bearishOBMid = new Series<double>(this);
            }
        }

        protected override void OnBarUpdate()
        {
            if (CurrentBar < SwingStrength + 5)
                return;

            // Reset series to hold latest only
            bullishOBLow[0] = bullishOBLow[1];
            bullishOBHigh[0] = bullishOBHigh[1];
            bullishOBMid[0] = bullishOBMid[1];

            bearishOBLow[0] = bearishOBLow[1];
            bearishOBHigh[0] = bearishOBHigh[1];
            bearishOBMid[0] = bearishOBMid[1];

            // === Bullish BoS Detection ===
            if (swing.SwingHigh[1] != double.MinValue && High[0] > swing.SwingHigh[1])
            {
                Draw.Text(this, "BoS_Up_" + CurrentBar, "BoS ↑", 0, High[0] + 3 * TickSize, Brushes.LimeGreen);
                MarkOrderBlock(isBullish: true);
            }

            // === Bearish BoS Detection ===
            if (swing.SwingLow[1] != double.MinValue && Low[0] < swing.SwingLow[1])
            {
                Draw.Text(this, "BoS_Down_" + CurrentBar, "BoS ↓", 0, Low[0] - 3 * TickSize, Brushes.Red);
                MarkOrderBlock(isBullish: false);
            }
        }

        private void MarkOrderBlock(bool isBullish)
        {
            int lookbackLimit = 20;
            for (int i = 1; i <= lookbackLimit; i++)
            {
                int barIndex = CurrentBar - i;
                if (barIndex < 0) break;

                bool found = false;

                if (isBullish && Close[barIndex] < Open[barIndex]) found = true;
                if (!isBullish && Close[barIndex] > Open[barIndex]) found = true;

                if (found)
                {
                    double high = Highs[0][i];
                    double low = Lows[0][i];
                    double mid = (high + low) / 2;

                    string tag = "OB_" + CurrentBar + (isBullish ? "_Bull" : "_Bear");

                    Draw.Rectangle(this, tag, false,
                        i + 3, high, i, low,
                        isBullish ? Brushes.LimeGreen : Brushes.IndianRed,
                        Brushes.Transparent, 2);

                    Draw.Text(this, tag + "_Label",
                        isBullish ? "Bullish OB" : "Bearish OB",
                        i, isBullish ? high + 2 * TickSize : low - 2 * TickSize,
                        isBullish ? Brushes.Green : Brushes.Maroon);

                    if (isBullish)
                    {
                        bullishOBLow[0] = low;
                        bullishOBHigh[0] = high;
                        bullishOBMid[0] = mid;
                    }
                    else
                    {
                        bearishOBLow[0] = low;
                        bearishOBHigh[0] = high;
                        bearishOBMid[0] = mid;
                    }

                    break;
                }
            }
        }

        #region Public Series Properties
        [Browsable(false)]
        [XmlIgnore()]
        public Series<double> BullishOBLow => bullishOBLow;

        [Browsable(false)]
        [XmlIgnore()]
        public Series<double> BullishOBHigh => bullishOBHigh;

        [Browsable(false)]
        [XmlIgnore()]
        public Series<double> BullishOBMid => bullishOBMid;

        [Browsable(false)]
        [XmlIgnore()]
        public Series<double> BearishOBLow => bearishOBLow;

        [Browsable(false)]
        [XmlIgnore()]
        public Series<double> BearishOBHigh => bearishOBHigh;

        [Browsable(false)]
        [XmlIgnore()]
        public Series<double> BearishOBMid => bearishOBMid;
        #endregion
    }
}
