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
	public class Ichimoku : Indicator
	{
		protected override void OnStateChange()
		{
			if (State == State.SetDefaults)
			{
				Description									= @"Enter the description for your new custom Indicator here.";
				Name										= "Ichimoku";
				Calculate									= Calculate.OnBarClose;
				IsOverlay									= true;
				DisplayInDataBox							= true;
				DrawOnPricePanel							= true;
				DrawHorizontalGridLines						= true;
				DrawVerticalGridLines						= true;
				PaintPriceMarkers							= true;
				ScaleJustification							= NinjaTrader.Gui.Chart.ScaleJustification.Right;
				//Disable this property if your indicator requires custom values that cumulate with each new market data event. 
				//See Help Guide for additional information.
				IsSuspendedWhileInactive					= true;
				TenkanPeriod					= 9;
				KijunPeriod					= 26;
				SenkouBPeriod					= 52;
				ChikouPeriod					= 26;
				AddPlot(Brushes.Aqua, "Tenkan");
				AddPlot(Brushes.Pink, "Kijun");
				AddPlot(Brushes.Green, "SenkouA");
				AddPlot(Brushes.Red, "SenkouB");
				AddPlot(Brushes.Orange, "Chikou");
				AddPlot(Brushes.Transparent, "FutureSenkouA");
				AddPlot(Brushes.Transparent, "FutureSenkouB");
			}
			else if (State == State.Configure)
			{
				Plots[0].Width = 2;
				Plots[1].Width = 2;
				Plots[2].Width = 3;
				Plots[3].Width = 3;
				Plots[4].Width = 1;
			}
		}

		protected override void OnBarUpdate()
		{
			if (CurrentBar < SenkouBPeriod * 2)
				return; 
			
			/// Tenkan line => Short term balance in the market (9 period)
			Tenkan[0] = ( MAX(High,TenkanPeriod)[0] + MIN(Low,TenkanPeriod)[0] ) / 2; 
			
			/// Kijun line => Medium term balance in the market (26 period)
			Kijun[0] = ( MAX(High,KijunPeriod)[0] + MIN(Low, KijunPeriod)[0]) / 2; 
			
			/// Senkou A => average of the Tenkan and the Kijun lines (part from the cloud)
			if ((Tenkan[26] + Kijun[26]) / 2 > 0) 
				SenkouA[0] = (Tenkan[26] + Kijun[26]) / 2;
			
			/// Senkou B => Long term balance in the market from the past
			/// - In other words: what was the balance in the market 26 bars ago? 
			/// - Assumption: the past 26 bars ago relevant to now
			SenkouB[0] = ( MAX(High,SenkouBPeriod)[26] +  MIN(Low, SenkouBPeriod)[26] ) / 2; 
			
			/// Chikou => The current price relative the price 26 bars ago
			/// - In other words: How the price act now relative to the price 26 bars ago?
			Chikou[26] = Close[0]; 
			
			/// Just fill the cloud in some color...
			Draw.Region(this, "Kumo", CurrentBar, -26, SenkouB, SenkouA, null, Brushes.Silver, 10);
			
			
			/// The future values of the cloud (the current information project into the future)
			FutureSenkouA[0] = (Tenkan[0] + Kijun[0]) / 2;
			FutureSenkouB[0] = (MAX(High,SenkouBPeriod)[0] + MIN(Low, SenkouBPeriod)[0]) / 2; 
		}
		
		#region Properties
		[NinjaScriptProperty]
		[Range(1, int.MaxValue)]
		[Display(Name="TenkanPeriod", Order=1, GroupName="Parameters")]
		public int TenkanPeriod
		{ get; set; }

		[NinjaScriptProperty]
		[Range(1, int.MaxValue)]
		[Display(Name="KijunPeriod", Order=2, GroupName="Parameters")]
		public int KijunPeriod
		{ get; set; }

		[NinjaScriptProperty]
		[Range(1, int.MaxValue)]
		[Display(Name="SenkouBPeriod", Order=3, GroupName="Parameters")]
		public int SenkouBPeriod
		{ get; set; }

		[NinjaScriptProperty]
		[Range(1, int.MaxValue)]
		[Display(Name="ChikouPeriod", Order=4, GroupName="Parameters")]
		public int ChikouPeriod
		{ get; set; }

		[Browsable(false)]
		[XmlIgnore]
		public Series<double> Tenkan
		{
			get { return Values[0]; }
		}

		[Browsable(false)]
		[XmlIgnore]
		public Series<double> Kijun
		{
			get { return Values[1]; }
		}

		[Browsable(false)]
		[XmlIgnore]
		public Series<double> SenkouA
		{
			get { return Values[2]; }
		}

		[Browsable(false)]
		[XmlIgnore]
		public Series<double> SenkouB
		{
			get { return Values[3]; }
		}

		[Browsable(false)]
		[XmlIgnore]
		public Series<double> Chikou
		{
			get { return Values[4]; }
		}
		
		[Browsable(false)]
		[XmlIgnore]
		public Series<double> FutureSenkouA
		{
			get { return Values[5]; }
		}
		
		[Browsable(false)]
		[XmlIgnore]
		public Series<double> FutureSenkouB
		{
			get { return Values[6]; }
		}
		#endregion

	}
}

#region NinjaScript generated code. Neither change nor remove.

namespace NinjaTrader.NinjaScript.Indicators
{
	public partial class Indicator : NinjaTrader.Gui.NinjaScript.IndicatorRenderBase
	{
		private Ichimoku[] cacheIchimoku;
		public Ichimoku Ichimoku(int tenkanPeriod, int kijunPeriod, int senkouBPeriod, int chikouPeriod)
		{
			return Ichimoku(Input, tenkanPeriod, kijunPeriod, senkouBPeriod, chikouPeriod);
		}

		public Ichimoku Ichimoku(ISeries<double> input, int tenkanPeriod, int kijunPeriod, int senkouBPeriod, int chikouPeriod)
		{
			if (cacheIchimoku != null)
				for (int idx = 0; idx < cacheIchimoku.Length; idx++)
					if (cacheIchimoku[idx] != null && cacheIchimoku[idx].TenkanPeriod == tenkanPeriod && cacheIchimoku[idx].KijunPeriod == kijunPeriod && cacheIchimoku[idx].SenkouBPeriod == senkouBPeriod && cacheIchimoku[idx].ChikouPeriod == chikouPeriod && cacheIchimoku[idx].EqualsInput(input))
						return cacheIchimoku[idx];
			return CacheIndicator<Ichimoku>(new Ichimoku(){ TenkanPeriod = tenkanPeriod, KijunPeriod = kijunPeriod, SenkouBPeriod = senkouBPeriod, ChikouPeriod = chikouPeriod }, input, ref cacheIchimoku);
		}
	}
}

namespace NinjaTrader.NinjaScript.MarketAnalyzerColumns
{
	public partial class MarketAnalyzerColumn : MarketAnalyzerColumnBase
	{
		public Indicators.Ichimoku Ichimoku(int tenkanPeriod, int kijunPeriod, int senkouBPeriod, int chikouPeriod)
		{
			return indicator.Ichimoku(Input, tenkanPeriod, kijunPeriod, senkouBPeriod, chikouPeriod);
		}

		public Indicators.Ichimoku Ichimoku(ISeries<double> input , int tenkanPeriod, int kijunPeriod, int senkouBPeriod, int chikouPeriod)
		{
			return indicator.Ichimoku(input, tenkanPeriod, kijunPeriod, senkouBPeriod, chikouPeriod);
		}
	}
}

namespace NinjaTrader.NinjaScript.Strategies
{
	public partial class Strategy : NinjaTrader.Gui.NinjaScript.StrategyRenderBase
	{
		public Indicators.Ichimoku Ichimoku(int tenkanPeriod, int kijunPeriod, int senkouBPeriod, int chikouPeriod)
		{
			return indicator.Ichimoku(Input, tenkanPeriod, kijunPeriod, senkouBPeriod, chikouPeriod);
		}

		public Indicators.Ichimoku Ichimoku(ISeries<double> input , int tenkanPeriod, int kijunPeriod, int senkouBPeriod, int chikouPeriod)
		{
			return indicator.Ichimoku(input, tenkanPeriod, kijunPeriod, senkouBPeriod, chikouPeriod);
		}
	}
}

#endregion
