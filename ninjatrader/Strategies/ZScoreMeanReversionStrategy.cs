#region Using declarations
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using System.Xml.Serialization;
using NinjaTrader.Cbi;
using NinjaTrader.Gui;
using NinjaTrader.Gui.Chart;
using NinjaTrader.Gui.SuperDom;
using NinjaTrader.Gui.Tools;
using NinjaTrader.Data;
using NinjaTrader.NinjaScript;
using NinjaTrader.Core.FloatingPoint;
using NinjaTrader.NinjaScript.Indicators;
using NinjaTrader.NinjaScript.DrawingTools;
#endregion

//This namespace holds Strategies in this folder and is required. Do not change it. 
#region Using declarations
using System;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;
using System.Windows.Media;
using NinjaTrader.Cbi;
using NinjaTrader.Gui.Tools;
using NinjaTrader.NinjaScript;
using NinjaTrader.NinjaScript.Indicators;
using NinjaTrader.NinjaScript.Strategies;
#endregion

namespace NinjaTrader.NinjaScript.Strategies
{
    public class ZScoreMeanReversionStrategy : Strategy
    {
        private ZScore zscore;

        #region Parameters

        [NinjaScriptProperty, Range(1, int.MaxValue)]
        [Display(Name="Z-Score Period", GroupName="Parameters", Order=0)]
        public int Period { get; set; }

        [NinjaScriptProperty]
        [Display(Name="Entry Threshold (σ)", GroupName="Parameters", Order=1)]
        public double EntryThreshold { get; set; }

        [NinjaScriptProperty]
        [Display(Name="Exit Threshold (σ)", GroupName="Parameters", Order=2)]
        public double ExitThreshold { get; set; }

        [NinjaScriptProperty]
        [Display(Name="Stop Loss (ticks)", GroupName="Parameters", Order=3)]
        public double StopLossTicks { get; set; }

        [NinjaScriptProperty]
        [Display(Name="Profit Target (ticks)", GroupName="Parameters", Order=4)]
        public double ProfitTargetTicks { get; set; }

        [NinjaScriptProperty]
        [Display(Name="Quantity", GroupName="Parameters", Order=5)]
        public int Qty { get; set; }

        [NinjaScriptProperty]
        [Display(Name="Start Time (ET)", GroupName="Parameters", Order=6)]
        public TimeSpan StartTime { get; set; }

        [NinjaScriptProperty]
        [Display(Name="End Time (ET)", GroupName="Parameters", Order=7)]
        public TimeSpan EndTime { get; set; }

        // Performance metrics
        [NinjaScriptProperty]
        [Display(Name="Expected Trades/Day",        GroupName="Metrics", Order=100)]
        public int ExpectedTradesPerDay { get; set; }

        [NinjaScriptProperty]
        [Display(Name="Expectancy Per Trade (USD)", GroupName="Metrics", Order=101)]
        public double ExpectancyPerTrade { get; set; }

        [NinjaScriptProperty]
        [Display(Name="Starting Capital (USD)",     GroupName="Metrics", Order=102)]
        public double StartingCapital { get; set; }

        private const int DaysPerMonth = 20;

        #endregion

        protected override void OnStateChange()
        {
            if (State == State.SetDefaults)
            {
                Name                         = "ZScoreMeanReversionStrategy";
                Description                  = "Enter long when Z ≤ –EntryThreshold, short when Z ≥ +EntryThreshold; exit at ExitThreshold";
                Calculate                    = Calculate.OnBarClose;
                EntriesPerDirection          = 1;
                EntryHandling                = EntryHandling.UniqueEntries;
                IsExitOnSessionCloseStrategy = true;
                ExitOnSessionCloseSeconds    = 30;

                // Default parameter values
                Period            = 20;
                EntryThreshold    = 2.0;
                ExitThreshold     = 0.0;
                StopLossTicks     = 10;
                ProfitTargetTicks = 10;
                Qty               = 10;
                StartTime         = new TimeSpan(12, 0, 0);
                EndTime           = new TimeSpan(14, 0, 0);

                ExpectedTradesPerDay = 5;
                ExpectancyPerTrade   = 37.5;
                StartingCapital      = 50000;
            }
            else if (State == State.Configure)
            {
                // Attach stops & targets
                SetStopLoss     (CalculationMode.Ticks, StopLossTicks);
                SetProfitTarget (CalculationMode.Ticks, ProfitTargetTicks);
                BarsRequiredToTrade = Period;
            }
            else if (State == State.DataLoaded)
            {
                // Instantiate ZScore with ALL properties (match your indicator’s constructor)
                zscore = ZScore(
                    Input,
                    Period,
                    // Z-Score line style
                    Brushes.Crimson, 2, DashStyleHelper.Solid,
                    // Zero line style
                    Brushes.Gray,   1, DashStyleHelper.Solid,
                    // +2σ line style
                    Brushes.Red,    1, DashStyleHelper.Dot,
                    // –2σ line style
                    Brushes.Green,  1, DashStyleHelper.Dot
                );
                AddChartIndicator(zscore);
            }
        }

        protected override void OnBarUpdate()
        {
            // Draw monthly metrics once per primary bar
            if (BarsInProgress == 0)
            {
                int tradesMonth   = ExpectedTradesPerDay * DaysPerMonth;
                double monthlyPnL = ExpectancyPerTrade * tradesMonth;
                double monthlyRet = StartingCapital > 0
                                    ? (monthlyPnL / StartingCapital) * 100
                                    : 0;

                string txt =
                    $"Trades/day: {ExpectedTradesPerDay}\n" +
                    $"Trades/mo : {tradesMonth}\n" +
                    $"P&L/mo    : {monthlyPnL:C0}\n" +
                    $"Return/mo : {monthlyRet:0.00}%";

               // use the 4-arg TextFixed overload
                Draw.TextFixed(
                    this,
                    "MonthlyMetrics",
                    txt,
                    TextPosition.TopRight
                );
            }

            // Warm up the indicator
            if (CurrentBar < Period)
                return;

            // Time filter
            TimeSpan tod = Time[0].TimeOfDay;
            if (tod < StartTime || tod > EndTime)
                return;

            double z = zscore[0];

            // Entry
            if (Position.MarketPosition == MarketPosition.Flat)
            {
                if (z <= -EntryThreshold)
                    EnterLong (Qty,  "Long");
                else if (z >=  EntryThreshold)
                    EnterShort(Qty, "Short");
            }

            // Exit on threshold
            if (Position.MarketPosition == MarketPosition.Long  && z >= ExitThreshold)
                ExitLong ( "ExitLong",  "Long");
            if (Position.MarketPosition == MarketPosition.Short && z <= ExitThreshold)
                ExitShort("ExitShort", "Short");
        }
    }
}

