#region Using declarations
using System;
using NinjaTrader.Data;
using NinjaTrader.NinjaScript;
using NinjaTrader.NinjaScript.Indicators;
using NinjaTrader.NinjaScript.DrawingTools;
#endregion

namespace NinjaTrader.NinjaScript.Indicators
{
    public class ChangeOfCharacterDetector : Indicator
    {
        private Swing swing;

        private Series<double> chochLevel;
        private Series<int> chochDirection; // 1 = Bullish, -1 = Bearish, 0 = none

        [Range(1, 20), NinjaScriptProperty]
        public int SwingStrength { get; set; }

        protected override void OnStateChange()
        {
            if (State == State.SetDefaults)
            {
                Name = "ChangeOfCharacterDetector";
                Description = "Detects and highlights Change of Character (CHoCH) with proper structure break.";
                Calculate = MarketCalculate.OnBarClose;
                IsOverlay = true;
                SwingStrength = 5;
            }
            else if (State == State.DataLoaded)
            {
                swing = Swing(SwingStrength);
                chochLevel = new Series<double>(this);
                chochDirection = new Series<int>(this);
            }
        }

        protected override void OnBarUpdate()
        {
            if (CurrentBar < SwingStrength + 5)
                return;

            // Maintain previous values
            chochLevel[0] = chochLevel[1];
            chochDirection[0] = chochDirection[1];

            // === Bullish CHoCH: Close > last swing high ===
            if (swing.SwingHigh[1] != double.MinValue && Close[0] > swing.SwingHigh[1])
            {
                int swingBarOffset = swing.SwingHighBar(1, 1, 20);
                if (swingBarOffset > 0)
                {
                    int swingBar = CurrentBar - swingBarOffset;
                    double swingHigh = swing.SwingHigh[swingBarOffset];

                    if (Close[0] > swingHigh) // Confirm breakout by close
                    {
                        Draw.Rectangle(this, "CHoCH_Bull_" + CurrentBar, false,
                            swingBarOffset, swingHigh + 2 * TickSize,
                            0, Low[0] - 2 * TickSize,
                            Brushes.LimeGreen, Brushes.Transparent, 2);

                        Draw.Text(this, "CHoCH_Label_Bull_" + CurrentBar,
                            "CHoCH ↑", 0, High[0] + 3 * TickSize, Brushes.Green);

                        chochLevel[0] = swingHigh;
                        chochDirection[0] = 1;
                    }
                }
            }

            // === Bearish CHoCH: Close < last swing low ===
            if (swing.SwingLow[1] != double.MinValue && Close[0] < swing.SwingLow[1])
            {
                int swingBarOffset = swing.SwingLowBar(1, 1, 20);
                if (swingBarOffset > 0)
                {
                    int swingBar = CurrentBar - swingBarOffset;
                    double swingLow = swing.SwingLow[swingBarOffset];

                    if (Close[0] < swingLow) // Confirm breakout by close
                    {
                        Draw.Rectangle(this, "CHoCH_Bear_" + CurrentBar, false,
                            swingBarOffset, High[0] + 2 * TickSize,
                            0, swingLow - 2 * TickSize,
                            Brushes.IndianRed, Brushes.Transparent, 2);

                        Draw.Text(this, "CHoCH_Label_Bear_" + CurrentBar,
                            "CHoCH ↓", 0, Low[0] - 3 * TickSize, Brushes.Maroon);

                        chochLevel[0] = swingLow;
                        chochDirection[0] = -1;
                    }
                }
            }
        }

        #region Public Outputs
        [Browsable(false)]
        [XmlIgnore()]
        public Series<double> CHoCHLevel => chochLevel;

        [Browsable(false)]
        [XmlIgnore()]
        public Series<int> CHoCHDirection => chochDirection; // 1 = Bullish, -1 = Bearish
        #endregion
    }
}
