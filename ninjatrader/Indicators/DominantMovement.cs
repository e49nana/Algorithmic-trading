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
using NinjaTrader.NinjaScript.DrawingTools;
#endregion

//This namespace holds Indicators in this folder and is required. Do not change it. 
namespace NinjaTrader.NinjaScript.Indicators
{
	public class DominantMovement : Indicator
	{
		protected override void OnStateChange()
		{
			if (State == State.SetDefaults)
			{
				Description									= @"Enter the description for your new custom Indicator here.";
				Name										= "DominantMovement";
				Calculate									= Calculate.OnBarClose;
				IsOverlay									= false;
				DisplayInDataBox							= true;
				DrawOnPricePanel							= true;
				DrawHorizontalGridLines						= true;
				DrawVerticalGridLines						= true;
				PaintPriceMarkers							= true;
				ScaleJustification							= NinjaTrader.Gui.Chart.ScaleJustification.Right;
				//Disable this property if your indicator requires custom values that cumulate with each new market data event. 
				//See Help Guide for additional information.
				IsSuspendedWhileInactive					= true;
				Period 										= 14;
				SmoothPeriod 								= 14;
			}
			else if (State == State.Configure)
			{
				AddPlot(Brushes.CadetBlue,"DominantMovement Power");
				AddPlot(Brushes.ForestGreen,"Smooth DominantMovement Power");
				
				AddLine(new Stroke(Brushes.Coral),80,"Upper Limit");
				AddLine(new Stroke(Brushes.Coral),20,"Lower Limit");
			}
		}

		protected override void OnBarUpdate()
		{
			if (CurrentBar < Period) return;
			
			double bearish = 0;
			double bullish = 0;
			
			for (int i = 0; i < Period; i++)
			{
				
				bool is_green_candle = Close[i] > Open[i];
				
				double candle_range = Math.Abs(Close[i] - Open[i]);
				
				if (is_green_candle)
					bullish += candle_range;
				else
					bearish += candle_range;
			}
			
			if (bearish == 0)
				Line[0] = 100;
			else if (bullish == 0)
				Line[0] = 0;
			else
				Line[0] = ( bullish / (bullish + bearish) ) * 100;
			
			Smooth[0] = EMA(Line,SmoothPeriod)[0];
			
			
		}
		
		#region Properties
		[Range(1, int.MaxValue), NinjaScriptProperty]
		[Display(ResourceType = typeof(Custom.Resource), Name = "Period", GroupName = "NinjaScriptParameters", Order = 0)]
		public int Period
		{ get; set; }
		
		[Range(1, int.MaxValue), NinjaScriptProperty]
		[Display(ResourceType = typeof(Custom.Resource), Name = "SmoothPeriod", GroupName = "NinjaScriptParameters", Order = 0)]
		public int SmoothPeriod
		{ get; set; }
		
		[Browsable(false)]
		[XmlIgnore()]
		public Series<double> Line
		{
			get { return Values[0]; }
		}
		
		[Browsable(false)]
		[XmlIgnore()]
		public Series<double> Smooth
		{
			get { return Values[1]; }
		}
		#endregion
	}
}

#region NinjaScript generated code. Neither change nor remove.

namespace NinjaTrader.NinjaScript.Indicators
{
	public partial class Indicator : NinjaTrader.Gui.NinjaScript.IndicatorRenderBase
	{
		private DominantMovement[] cacheDominantMovement;
		public DominantMovement DominantMovement(int period, int smoothPeriod)
		{
			return DominantMovement(Input, period, smoothPeriod);
		}

		public DominantMovement DominantMovement(ISeries<double> input, int period, int smoothPeriod)
		{
			if (cacheDominantMovement != null)
				for (int idx = 0; idx < cacheDominantMovement.Length; idx++)
					if (cacheDominantMovement[idx] != null && cacheDominantMovement[idx].Period == period && cacheDominantMovement[idx].SmoothPeriod == smoothPeriod && cacheDominantMovement[idx].EqualsInput(input))
						return cacheDominantMovement[idx];
			return CacheIndicator<DominantMovement>(new DominantMovement(){ Period = period, SmoothPeriod = smoothPeriod }, input, ref cacheDominantMovement);
		}
	}
}

namespace NinjaTrader.NinjaScript.MarketAnalyzerColumns
{
	public partial class MarketAnalyzerColumn : MarketAnalyzerColumnBase
	{
		public Indicators.DominantMovement DominantMovement(int period, int smoothPeriod)
		{
			return indicator.DominantMovement(Input, period, smoothPeriod);
		}

		public Indicators.DominantMovement DominantMovement(ISeries<double> input , int period, int smoothPeriod)
		{
			return indicator.DominantMovement(input, period, smoothPeriod);
		}
	}
}

namespace NinjaTrader.NinjaScript.Strategies
{
	public partial class Strategy : NinjaTrader.Gui.NinjaScript.StrategyRenderBase
	{
		public Indicators.DominantMovement DominantMovement(int period, int smoothPeriod)
		{
			return indicator.DominantMovement(Input, period, smoothPeriod);
		}

		public Indicators.DominantMovement DominantMovement(ISeries<double> input , int period, int smoothPeriod)
		{
			return indicator.DominantMovement(input, period, smoothPeriod);
		}
	}
}

#endregion
