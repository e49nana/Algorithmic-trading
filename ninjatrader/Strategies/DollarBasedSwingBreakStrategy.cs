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
using System.Collections.Generic;
using NinjaTrader.Cbi;
using NinjaTrader.Gui.NinjaScript;
using NinjaTrader.NinjaScript.Strategies;
#endregion

namespace NinjaTrader.NinjaScript.Strategies
{
    public class DollarBasedSwingBreakStrategy : Strategy
    {
        #region Variables
        // Swing detection variables (used to trigger entries)
        private int constant;
        private double currentSwingHigh;
        private double currentSwingLow;
        private List<double> lastHighCache;
        private List<double> lastLowCache;
        private double lastSwingHighValue;
        private double lastSwingLowValue;
        private int saveCurrentBar;
        private bool bullishBreakDetected;
        private bool bearishBreakDetected;

        private Series<double> swingHighSeries;
        private Series<double> swingHighSwings;
        private Series<double> swingLowSeries;
        private Series<double> swingLowSwings;

        // Order management objects
        private Order longStopOrder;
        private Order longProfitTargetOrder;
        private Order shortStopOrder;
        private Order shortProfitTargetOrder;
        #endregion

        #region Properties (Parameters)
        [NinjaScriptProperty]
        [Range(1, int.MaxValue)]
        [Display(Name = "Strength", Order = 1, GroupName = "Parameters")]
        public int Strength { get; set; }

        [NinjaScriptProperty]
        [Range(1, int.MaxValue)]
        [Display(Name = "BreakThresholdTicks", Order = 2, GroupName = "Parameters")]
        public int BreakThresholdTicks { get; set; }

        // Fixed risk parameters (in dollars)
        [NinjaScriptProperty]
        [Display(Name = "StopLossDollars", Order = 3, GroupName = "Parameters")]
        public double StopLossDollars { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "ProfitTargetDollars", Order = 4, GroupName = "Parameters")]
        public double ProfitTargetDollars { get; set; }

        // Trailing stop increment threshold (in dollars)
        [NinjaScriptProperty]
        [Display(Name = "TrailingIncrement", Order = 5, GroupName = "Parameters")]
        public double TrailingIncrement { get; set; }
        #endregion

        protected override void OnStateChange()
        {
            if (State == State.SetDefaults)
            {
                Description = "Strategy that enters trades on swing break signals (with arrow plotting) and uses fixed dollar risk: a $500 stop loss and a $1000 profit target. " +
                              "A trailing stop moves in steps (e.g. to break even at $200 profit, then to entry + $200 at $400, etc.). " +
                              "This strategy is designed to trade only MNQ futures.";
                Name = "DollarBasedSwingBreakStrategy";
                Calculate = Calculate.OnBarClose;
                EntriesPerDirection = 1;
                EntryHandling = EntryHandling.AllEntries;
                IsInstantiatedOnEachOptimizationIteration = false;

                // Default parameter values
                Strength = 5;
                BreakThresholdTicks = 2;
                StopLossDollars = 500;
                ProfitTargetDollars = 1000;
                TrailingIncrement = 200;
            }
            else if (State == State.Configure)
            {
                // Ensure this strategy runs only on MNQ futures
                if (Instrument.MasterInstrument.Name != "MNQ")
                    throw new Exception("This strategy is designed to trade only MNQ futures.");

                // Number of bars required for swing detection: (2 * Strength + 1)
                constant = 2 * Strength + 1;
                currentSwingHigh = 0;
                currentSwingLow = 0;
                lastSwingHighValue = 0;
                lastSwingLowValue = 0;
                saveCurrentBar = -1;
                bullishBreakDetected = false;
                bearishBreakDetected = false;
            }
            else if (State == State.DataLoaded)
            {
                lastHighCache = new List<double>();
                lastLowCache = new List<double>();

                swingHighSeries = new Series<double>(this);
                swingHighSwings = new Series<double>(this);
                swingLowSeries = new Series<double>(this);
                swingLowSwings = new Series<double>(this);
            }
        }

        protected override void OnBarUpdate()
        {
            // Ensure we have enough bars
            if (CurrentBar < constant)
                return;

            double high0 = High[0];
            double low0 = Low[0];
            double close0 = Close[0];

            // --- Update Swing Detection Caches and Logic ---
            if (saveCurrentBar != CurrentBar)
            {
                // Update caches
                lastHighCache.Add(high0);
                if (lastHighCache.Count > constant)
                    lastHighCache.RemoveAt(0);

                lastLowCache.Add(low0);
                if (lastLowCache.Count > constant)
                    lastLowCache.RemoveAt(0);

                // Detect Swing High
                if (lastHighCache.Count == constant)
                {
                    bool isSwingHigh = true;
                    double candidate = lastHighCache[Strength];
                    for (int i = 0; i < Strength; i++)
                        if (lastHighCache[i] >= candidate)
                            isSwingHigh = false;
                    for (int i = Strength + 1; i < lastHighCache.Count; i++)
                        if (lastHighCache[i] > candidate)
                            isSwingHigh = false;

                    swingHighSwings[Strength] = isSwingHigh ? candidate : 0.0;
                    if (isSwingHigh)
                    {
                        lastSwingHighValue = candidate;
                        bullishBreakDetected = false;
                        currentSwingHigh = candidate;
                    }
                    else if (high0 > currentSwingHigh || currentSwingHigh == 0)
                    {
                        currentSwingHigh = 0.0;
                    }
                    swingHighSeries[0] = lastSwingHighValue;
                }

                // Detect Swing Low
                if (lastLowCache.Count == constant)
                {
                    bool isSwingLow = true;
                    double candidate = lastLowCache[Strength];
                    for (int i = 0; i < Strength; i++)
                        if (lastLowCache[i] <= candidate)
                            isSwingLow = false;
                    for (int i = Strength + 1; i < lastLowCache.Count; i++)
                        if (lastLowCache[i] < candidate)
                            isSwingLow = false;

                    swingLowSwings[Strength] = isSwingLow ? candidate : 0.0;
                    if (isSwingLow)
                    {
                        lastSwingLowValue = candidate;
                        bearishBreakDetected = false;
                        currentSwingLow = candidate;
                    }
                    else if (low0 < currentSwingLow || currentSwingLow == 0)
                    {
                        currentSwingLow = double.MaxValue;
                    }
                    swingLowSeries[0] = lastSwingLowValue;
                }

                saveCurrentBar = CurrentBar;
            }

            // --- Break-of-Structure Detection & Trade Entry ---
            double breakThreshold = BreakThresholdTicks * Instrument.MasterInstrument.TickSize;
            // Long entry if close exceeds last swing high by the threshold
            if (lastSwingHighValue > 0 && close0 > lastSwingHighValue + breakThreshold && !bullishBreakDetected && Position.MarketPosition == MarketPosition.Flat)
            {
                bullishBreakDetected = true;
                EnterLong(0, "LongEntry");
                Draw.ArrowUp(this, "LongArrow" + CurrentBar, false, 0, low0 - (2 * Instrument.MasterInstrument.TickSize), Brushes.Green);
            }
            // Short entry if close is below last swing low by the threshold
            if (lastSwingLowValue > 0 && close0 < lastSwingLowValue - breakThreshold && !bearishBreakDetected && Position.MarketPosition == MarketPosition.Flat)
            {
                bearishBreakDetected = true;
                EnterShort(0, "ShortEntry");
                Draw.ArrowDown(this, "ShortArrow" + CurrentBar, false, 0, high0 + (2 * Instrument.MasterInstrument.TickSize), Brushes.Red);
            }

            // --- Trade Management: Fixed Dollar Stop/Target with Trailing Stops ---
            // For Long Positions
            if (Position.MarketPosition == MarketPosition.Long)
            {
                double entryPrice = Position.AveragePrice;
                double currentProfit = Close[0] - entryPrice;
                double fixedStop = entryPrice - StopLossDollars;
                double fixedTarget = entryPrice + ProfitTargetDollars;
                double newStop = fixedStop;

                if (currentProfit >= TrailingIncrement)
                {
                    int increments = (int)(currentProfit / TrailingIncrement);
                    newStop = entryPrice + (increments - 1) * TrailingIncrement;
                    if (newStop < entryPrice)
                        newStop = entryPrice;
                    if (newStop < fixedStop)
                        newStop = fixedStop;
                }
                else
                {
                    newStop = fixedStop;
                }

                if (longStopOrder == null || longStopOrder.OrderState == OrderState.Filled || longStopOrder.OrderState == OrderState.Cancelled)
                {
                    longStopOrder = ExitLongStopMarket(0, true, Position.Quantity, newStop, "LongStop", "LongEntry");
                }
                else if (Math.Abs(longStopOrder.StopPrice - newStop) > Instrument.MasterInstrument.TickSize)
                {
                    ChangeOrder(longStopOrder, longStopOrder.Quantity, newStop, longStopOrder.LimitPrice);
                }
                if (longProfitTargetOrder == null || longProfitTargetOrder.OrderState == OrderState.Filled || longProfitTargetOrder.OrderState == OrderState.Cancelled)
                {
                    longProfitTargetOrder = ExitLongLimit(0, true, Position.Quantity, fixedTarget, "LongTarget", "LongEntry");
                }
            }

            // For Short Positions
            if (Position.MarketPosition == MarketPosition.Short)
            {
                double entryPrice = Position.AveragePrice;
                double currentProfit = entryPrice - Close[0];
                double fixedStop = entryPrice + StopLossDollars;
                double fixedTarget = entryPrice - ProfitTargetDollars;
                double newStop = fixedStop;

                if (currentProfit >= TrailingIncrement)
                {
                    int increments = (int)(currentProfit / TrailingIncrement);
                    newStop = entryPrice - (increments - 1) * TrailingIncrement;
                    if (newStop > entryPrice)
                        newStop = entryPrice;
                    if (newStop > fixedStop)
                        newStop = fixedStop;
                }
                else
                {
                    newStop = fixedStop;
                }

                if (shortStopOrder == null || shortStopOrder.OrderState == OrderState.Filled || shortStopOrder.OrderState == OrderState.Cancelled)
                {
                    shortStopOrder = ExitShortStopMarket(0, true, Position.Quantity, newStop, "ShortStop", "ShortEntry");
                }
                else if (Math.Abs(shortStopOrder.StopPrice - newStop) > Instrument.MasterInstrument.TickSize)
                {
                    ChangeOrder(shortStopOrder, shortStopOrder.Quantity, newStop, shortStopOrder.LimitPrice);
                }
                if (shortProfitTargetOrder == null || shortProfitTargetOrder.OrderState == OrderState.Filled || shortProfitTargetOrder.OrderState == OrderState.Cancelled)
                {
                    shortProfitTargetOrder = ExitShortLimit(0, true, Position.Quantity, fixedTarget, "ShortTarget", "ShortEntry");
                }
            }
        }

        protected override void OnExecutionUpdate(Execution execution, string executionId, double price, int quantity,
            MarketPosition marketPosition, string orderId, DateTime time)
        {
            // Optional: add logging or additional order management if needed.
        }
    }
}


