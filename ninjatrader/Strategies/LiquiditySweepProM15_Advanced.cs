#region Using declarations
using System;
using NinjaTrader.Cbi;
using NinjaTrader.Gui.Tools;
using NinjaTrader.NinjaScript;
using NinjaTrader.Data;
using NinjaTrader.NinjaScript.Strategies;
using NinjaTrader.NinjaScript.DrawingTools;
#endregion

namespace NinjaTrader.NinjaScript.Strategies
{
    public class LiquiditySweepProM15_Advanced : Strategy
    {
        private double preHigh = double.MinValue;
        private double preLow = double.MaxValue;
        private bool rangeSet = false;
        private bool tradeTaken = false;
        private double[] last5Ranges = new double[5];
        private int rangeIndex = 0;

        private TimeSpan preStart = new TimeSpan(6, 0, 0);
        private TimeSpan preEnd = new TimeSpan(9, 15, 0);
        private TimeSpan killStart = new TimeSpan(9, 30, 0);
        private TimeSpan killEnd = new TimeSpan(10, 30, 0);

        [NinjaScriptProperty]
        [Range(1, 20)]
        [Display(Name = "BufferTicks", Order = 1)]
        public int BufferTicks { get; set; }

        [NinjaScriptProperty]
        [Range(1.0, 5.0)]
        [Display(Name = "RiskRewardRatio", Order = 2)]
        public double RiskRewardRatio { get; set; }

        [NinjaScriptProperty]
        [Range(0.1, 1.0)]
        [Display(Name = "VolatilityThreshold", Order = 3)]
        public double VolatilityThreshold { get; set; }

        [NinjaScriptProperty]
        [Range(0.1, 1.0)]
        [Display(Name = "MinBodyRatio", Order = 4)]
        public double MinBodyRatio { get; set; }

        [NinjaScriptProperty]
        [Range(1, 20)]
        [Display(Name = "BreakEvenTicks", Order = 5)]
        public int BreakEvenTicks { get; set; }

        [NinjaScriptProperty]
        [Range(1, 30)]
        [Display(Name = "TrailingStartTicks", Order = 6)]
        public int TrailingStartTicks { get; set; }

        [NinjaScriptProperty]
        [Range(1, 10)]
        [Display(Name = "TrailingOffsetTicks", Order = 7)]
        public int TrailingOffsetTicks { get; set; }

        [NinjaScriptProperty]
        [Range(0.1, 1.0)]
        [Display(Name = "AsiaRangeMaxRatio", Order = 8)]
        public double AsiaRangeMaxRatio { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "VisualOnly", Order = 9)]
        public bool VisualOnly { get; set; }

        protected override void OnStateChange()
        {
            if (State == State.SetDefaults)
            {
                Name = "LiquiditySweepProM15_Advanced";
                Calculate = MarketCalculate.OnBarClose;
                EntriesPerDirection = 1;
                EntryHandling = EntryHandling.AllEntries;
                IncludeCommission = true;

                BufferTicks = 2;
                RiskRewardRatio = 2.0;
                VolatilityThreshold = 0.7;
                MinBodyRatio = 0.3;
                BreakEvenTicks = 8;
                TrailingStartTicks = 10;
                TrailingOffsetTicks = 2;
                AsiaRangeMaxRatio = 0.4;
                VisualOnly = true;
            }
        }

        protected override void OnBarUpdate()
        {
            if (BarsInProgress != 0 || CurrentBar < 30)
                return;

            TimeSpan now = Times[0][0].TimeOfDay;
            double buffer = TickSize * BufferTicks;

            if (Bars.IsFirstBarOfSession)
            {
                preHigh = double.MinValue;
                preLow = double.MaxValue;
                rangeSet = false;
                tradeTaken = false;

                if (CurrentBar > 20)
                {
                    double range = Highs[0][1] - Lows[0][1];
                    last5Ranges[rangeIndex % 5] = range;
                    rangeIndex++;
                }
            }

            if (now >= preStart && now <= preEnd)
            {
                preHigh = Math.Max(preHigh, High[0]);
                preLow = Math.Min(preLow, Low[0]);
                rangeSet = true;
            }

            if (!rangeSet || tradeTaken || now < killStart || now > killEnd)
                return;

            double todayRange = High[0] - Low[0];
            double avgRange = 0;
            foreach (double r in last5Ranges) avgRange += r;
            avgRange /= 5;

            if (todayRange < VolatilityThreshold * avgRange)
                return;

            double asiaHigh = double.MinValue;
            double asiaLow = double.MaxValue;
            for (int i = 1; i <= 24; i++)
            {
                DateTime barTime = Times[0][i];
                if (barTime.TimeOfDay >= new TimeSpan(0, 0, 0) && barTime.TimeOfDay <= new TimeSpan(6, 0, 0))
                {
                    asiaHigh = Math.Max(asiaHigh, Highs[0][i]);
                    asiaLow = Math.Min(asiaLow, Lows[0][i]);
                }
            }
            double asiaRange = asiaHigh - asiaLow;
            if (asiaRange > AsiaRangeMaxRatio * avgRange)
                return;

            bool bullishIntraday = Highs[0][1] > Highs[0][2] && Lows[0][1] > Lows[0][2];
            bool bearishIntraday = Highs[0][1] < Highs[0][2] && Lows[0][1] < Lows[0][2];
            bool bullishMultiDay = Lows[0][1] > Lows[0][2] && Lows[0][2] > Lows[0][3];
            bool bearishMultiDay = Highs[0][1] < Highs[0][2] && Highs[0][2] < Highs[0][3];

            double body = Math.Abs(Close[0] - Open[0]);
            double totalRange = High[0] - Low[0];
            if (totalRange == 0 || body / totalRange < MinBodyRatio)
                return;

            if (High[0] > preHigh + buffer && Close[0] < preHigh && bearishIntraday && bearishMultiDay)
            {
                Draw.Rectangle(this, "ShortZone_" + CurrentBar, false, 0, preHigh + buffer, 0, High[0], Brushes.Transparent, Brushes.Red, 2);
                Draw.Text(this, "ShortText_" + CurrentBar, "SHORT SWEEP", 0, High[0] + 2 * TickSize, Brushes.Red);

                if (!VisualOnly)
                {
                    double entry = Close[0];
                    double stop = High[0] + buffer;
                    double target = entry - RiskRewardRatio * (stop - entry);
                    EnterShortLimit(0, true, 1, entry, "ShortSweep");
                    SetStopLoss("ShortSweep", CalculationMode.Price, stop, false);
                    SetProfitTarget("ShortSweep", CalculationMode.Price, target);
                }
                tradeTaken = true;
            }
            else if (Low[0] < preLow - buffer && Close[0] > preLow && bullishIntraday && bullishMultiDay)
            {
                Draw.Rectangle(this, "LongZone_" + CurrentBar, false, 0, Low[0], 0, preLow - buffer, Brushes.Transparent, Brushes.Green, 2);
                Draw.Text(this, "LongText_" + CurrentBar, "LONG SWEEP", 0, Low[0] - 2 * TickSize, Brushes.Green);

                if (!VisualOnly)
                {
                    double entry = Close[0];
                    double stop = Low[0] - buffer;
                    double target = entry + RiskRewardRatio * (entry - stop);
                    EnterLongLimit(0, true, 1, entry, "LongSweep");
                    SetStopLoss("LongSweep", CalculationMode.Price, stop, false);
                    SetProfitTarget("LongSweep", CalculationMode.Price, target);
                }
                tradeTaken = true;
            }

            // === TRADE MANAGEMENT ===
            if (Position.MarketPosition == MarketPosition.Long)
            {
                double beTrigger = Position.AveragePrice + TickSize * BreakEvenTicks;
                double trailStart = Position.AveragePrice + TickSize * TrailingStartTicks;
                double trailStop = Low[0] - TickSize * TrailingOffsetTicks;

                if (Close[0] >= beTrigger)
                    SetStopLoss(CalculationMode.Price, Position.AveragePrice);

                if (Close[0] >= trailStart)
                    SetStopLoss(CalculationMode.Price, Math.Max(Position.AveragePrice, trailStop));
            }

            if (Position.MarketPosition == MarketPosition.Short)
            {
                double beTrigger = Position.AveragePrice - TickSize * BreakEvenTicks;
                double trailStart = Position.AveragePrice - TickSize * TrailingStartTicks;
                double trailStop = High[0] + TickSize * TrailingOffsetTicks;

                if (Close[0] <= beTrigger)
                    SetStopLoss(CalculationMode.Price, Position.AveragePrice);

                if (Close[0] <= trailStart)
                    SetStopLoss(CalculationMode.Price, Math.Min(Position.AveragePrice, trailStop));
            }
        }
    }
}
