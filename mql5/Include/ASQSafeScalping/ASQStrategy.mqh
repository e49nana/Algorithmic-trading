//+------------------------------------------------------------------+
//|                                                ASQStrategy.mqh   |
//|            ASQ Safe Scalping v1.10 - Strategy Engine Module      |
//|  Indicators, Breakout, Signal, Filters, MTF Confirmation         |
//+------------------------------------------------------------------+
#property copyright   "AlgoSphere Quant"
#property link        "https://www.mql5.com/en/users/robin2.0"
#property version     "1.10"
#property strict

#ifndef ASQ_STRATEGY_MQH
#define ASQ_STRATEGY_MQH

#include "ASQCore.mqh"

class CASQStrategy
  {
private:
   int               m_hEmaFast,m_hEmaSlow,m_hRsi,m_hAtr;
   int               m_hHTFEmaFast,m_hHTFEmaSlow;  // v1.10: higher-TF handles
   double            m_bufEmaFast[],m_bufEmaSlow[],m_bufRsi[],m_bufAtr[];
   double            m_bufHTFEmaFast[],m_bufHTFEmaSlow[];
   SAsqIndicators    m_ind;
   int               m_emaFastPeriod,m_emaSlowPeriod,m_rsiPeriod,m_atrPeriod;
   int               m_breakoutLookback;
   double            m_breakoutBuffer;
   ENUM_ASQ_TREND_STRENGTH m_trendStrength;
   double            m_rsiBuyMin,m_rsiBuyMax,m_rsiSellMin,m_rsiSellMax;
   bool              m_useSession; int m_sessStartH,m_sessStartM,m_sessEndH,m_sessEndM;
   bool              m_avoidFriday; int m_fridayCutoff;
   bool              m_useSpread; int m_maxSpread;
   bool              m_useNews; string m_newsTime[3]; int m_newsMinsBefore,m_newsMinsAfter;
   bool              m_useMTF;          // v1.10
   ENUM_TIMEFRAMES   m_htfTimeframe;    // v1.10
   bool              m_initialized;

public:
   CASQStrategy() : m_hEmaFast(INVALID_HANDLE),m_hEmaSlow(INVALID_HANDLE),
                    m_hRsi(INVALID_HANDLE),m_hAtr(INVALID_HANDLE),
                    m_hHTFEmaFast(INVALID_HANDLE),m_hHTFEmaSlow(INVALID_HANDLE),
                    m_useMTF(false),m_initialized(false) { m_ind.Reset(); }
  ~CASQStrategy() { Deinit(); }

   bool Init(string symbol,ENUM_TIMEFRAMES tf,
             int emaFast,int emaSlow,int rsiPeriod,int atrPeriod,
             int breakoutLookback,double breakoutBuffer,
             ENUM_ASQ_TREND_STRENGTH trendStrength,
             double rsiBuyMin,double rsiBuyMax,double rsiSellMin,double rsiSellMax)
     {
      m_emaFastPeriod=emaFast; m_emaSlowPeriod=emaSlow;
      m_rsiPeriod=rsiPeriod; m_atrPeriod=atrPeriod;
      m_breakoutLookback=breakoutLookback; m_breakoutBuffer=breakoutBuffer;
      m_trendStrength=trendStrength;
      m_rsiBuyMin=rsiBuyMin; m_rsiBuyMax=rsiBuyMax;
      m_rsiSellMin=rsiSellMin; m_rsiSellMax=rsiSellMax;
      m_hEmaFast=iMA(symbol,tf,emaFast,0,MODE_EMA,PRICE_CLOSE);
      m_hEmaSlow=iMA(symbol,tf,emaSlow,0,MODE_EMA,PRICE_CLOSE);
      m_hRsi=iRSI(symbol,tf,rsiPeriod,PRICE_CLOSE);
      m_hAtr=iATR(symbol,tf,atrPeriod);
      if(m_hEmaFast==INVALID_HANDLE||m_hEmaSlow==INVALID_HANDLE||
         m_hRsi==INVALID_HANDLE||m_hAtr==INVALID_HANDLE)
        { ASQError("Indicator creation failed"); return false; }
      ArraySetAsSeries(m_bufEmaFast,true); ArraySetAsSeries(m_bufEmaSlow,true);
      ArraySetAsSeries(m_bufRsi,true); ArraySetAsSeries(m_bufAtr,true);
      m_initialized=true;
      ASQInfo("Strategy initialized | EMA "+IntegerToString(emaFast)+"/"+IntegerToString(emaSlow)+
              " | RSI "+IntegerToString(rsiPeriod)+" | ATR "+IntegerToString(atrPeriod));
      return true;
     }

   // v1.10: Initialize MTF confirmation
   void SetMTFFilter(bool use,ENUM_TIMEFRAMES htfTF,string symbol,int emaFast,int emaSlow)
     {
      m_useMTF=use; m_htfTimeframe=htfTF;
      if(!use) return;
      m_hHTFEmaFast=iMA(symbol,htfTF,emaFast,0,MODE_EMA,PRICE_CLOSE);
      m_hHTFEmaSlow=iMA(symbol,htfTF,emaSlow,0,MODE_EMA,PRICE_CLOSE);
      if(m_hHTFEmaFast==INVALID_HANDLE||m_hHTFEmaSlow==INVALID_HANDLE)
        { ASQWarn("MTF indicators failed - disabling MTF filter"); m_useMTF=false; return; }
      ArraySetAsSeries(m_bufHTFEmaFast,true); ArraySetAsSeries(m_bufHTFEmaSlow,true);
      ASQInfo("MTF filter enabled | "+EnumToString(htfTF)+" EMA "+IntegerToString(emaFast)+"/"+IntegerToString(emaSlow));
     }

   void Deinit()
     { if(m_hEmaFast!=INVALID_HANDLE) { IndicatorRelease(m_hEmaFast); m_hEmaFast=INVALID_HANDLE; }
       if(m_hEmaSlow!=INVALID_HANDLE) { IndicatorRelease(m_hEmaSlow); m_hEmaSlow=INVALID_HANDLE; }
       if(m_hRsi!=INVALID_HANDLE)     { IndicatorRelease(m_hRsi); m_hRsi=INVALID_HANDLE; }
       if(m_hAtr!=INVALID_HANDLE)     { IndicatorRelease(m_hAtr); m_hAtr=INVALID_HANDLE; }
       if(m_hHTFEmaFast!=INVALID_HANDLE) { IndicatorRelease(m_hHTFEmaFast); m_hHTFEmaFast=INVALID_HANDLE; }
       if(m_hHTFEmaSlow!=INVALID_HANDLE) { IndicatorRelease(m_hHTFEmaSlow); m_hHTFEmaSlow=INVALID_HANDLE; }
       m_initialized=false; }

   void SetSessionFilter(bool use,int sH,int sM,int eH,int eM,bool avoidFri,int friCut)
     { m_useSession=use; m_sessStartH=sH; m_sessStartM=sM; m_sessEndH=eH; m_sessEndM=eM;
       m_avoidFriday=avoidFri; m_fridayCutoff=friCut; }

   void SetSpreadFilter(bool use,int maxSp) { m_useSpread=use; m_maxSpread=maxSp; }

   void SetNewsFilter(bool use,string t1,string t2,string t3,int minB,int minA)
     { m_useNews=use; m_newsTime[0]=t1; m_newsTime[1]=t2; m_newsTime[2]=t3;
       m_newsMinsBefore=minB; m_newsMinsAfter=minA; }

   void GetIndicators(SAsqIndicators &out) { out=m_ind; }

   bool UpdateIndicators()
     { if(!m_initialized) return false;
       int need=MathMax(m_breakoutLookback+5,m_emaSlowPeriod+5); need=MathMax(need,10);
       if(CopyBuffer(m_hEmaFast,0,0,need,m_bufEmaFast)<need) return false;
       if(CopyBuffer(m_hEmaSlow,0,0,need,m_bufEmaSlow)<need) return false;
       if(CopyBuffer(m_hRsi,0,0,5,m_bufRsi)<5) return false;
       if(CopyBuffer(m_hAtr,0,0,5,m_bufAtr)<5) return false;
       m_ind.emaFast=m_bufEmaFast[1]; m_ind.emaSlow=m_bufEmaSlow[1];
       m_ind.emaFastPrev=m_bufEmaFast[2]; m_ind.emaSlowPrev=m_bufEmaSlow[2];
       m_ind.rsi=m_bufRsi[1]; m_ind.atr=m_bufAtr[1];
       m_ind.close1=iClose(_Symbol,PERIOD_CURRENT,1);
       m_ind.close2=iClose(_Symbol,PERIOD_CURRENT,2);
       m_ind.highestHigh=0; m_ind.lowestLow=DBL_MAX;
       for(int i=2;i<=m_breakoutLookback+1;i++)
         { double h=iHigh(_Symbol,PERIOD_CURRENT,i),l=iLow(_Symbol,PERIOD_CURRENT,i);
           if(h>m_ind.highestHigh) m_ind.highestHigh=h;
           if(l<m_ind.lowestLow) m_ind.lowestLow=l; }
       // v1.10: MTF indicators
       m_ind.htfValid=false;
       if(m_useMTF&&m_hHTFEmaFast!=INVALID_HANDLE&&m_hHTFEmaSlow!=INVALID_HANDLE)
         { if(CopyBuffer(m_hHTFEmaFast,0,0,3,m_bufHTFEmaFast)>=3&&
              CopyBuffer(m_hHTFEmaSlow,0,0,3,m_bufHTFEmaSlow)>=3)
             { m_ind.htfEmaFast=m_bufHTFEmaFast[1]; m_ind.htfEmaSlow=m_bufHTFEmaSlow[1];
               m_ind.htfValid=true; } }
       m_ind.valid=true; return true; }

   ENUM_ASQ_SIGNAL GetSignal()
     { if(!m_ind.valid||m_ind.atr<=0) return ASQ_SIGNAL_NONE;
       bool bullTrend=(m_ind.emaFast>m_ind.emaSlow), bearTrend=(m_ind.emaFast<m_ind.emaSlow);
       double sep=MathAbs(m_ind.emaFast-m_ind.emaSlow), minSep=0;
       switch(m_trendStrength)
         { case ASQ_TREND_WEAK: minSep=m_ind.atr*0.1; break;
           case ASQ_TREND_MODERATE: minSep=m_ind.atr*0.3; break;
           case ASQ_TREND_STRONG: minSep=m_ind.atr*0.6; break; }
       if(sep<minSep) return ASQ_SIGNAL_NONE;
       bool aboveBoth=(m_ind.close1>m_ind.emaFast&&m_ind.close1>m_ind.emaSlow);
       bool belowBoth=(m_ind.close1<m_ind.emaFast&&m_ind.close1<m_ind.emaSlow);
       double buf=m_ind.atr*m_breakoutBuffer;
       bool bullBreak=(m_ind.close1>m_ind.highestHigh-buf)&&(m_ind.close2<=m_ind.highestHigh);
       bool bearBreak=(m_ind.close1<m_ind.lowestLow+buf)&&(m_ind.close2>=m_ind.lowestLow);
       bool rsiBuy=(m_ind.rsi>=m_rsiBuyMin&&m_ind.rsi<=m_rsiBuyMax);
       bool rsiSell=(m_ind.rsi>=m_rsiSellMin&&m_ind.rsi<=m_rsiSellMax);
       bool bullMom=(m_ind.close1>m_ind.close2), bearMom=(m_ind.close1<m_ind.close2);
       // v1.10: MTF confirmation (7th condition)
       if(m_useMTF&&m_ind.htfValid)
         { bool htfBull=(m_ind.htfEmaFast>m_ind.htfEmaSlow);
           bool htfBear=(m_ind.htfEmaFast<m_ind.htfEmaSlow);
           if(bullTrend&&aboveBoth&&bullBreak&&rsiBuy&&bullMom&&htfBull) return ASQ_SIGNAL_BUY;
           if(bearTrend&&belowBoth&&bearBreak&&rsiSell&&bearMom&&htfBear) return ASQ_SIGNAL_SELL;
           return ASQ_SIGNAL_NONE; }
       if(bullTrend&&aboveBoth&&bullBreak&&rsiBuy&&bullMom) return ASQ_SIGNAL_BUY;
       if(bearTrend&&belowBoth&&bearBreak&&rsiSell&&bearMom) return ASQ_SIGNAL_SELL;
       return ASQ_SIGNAL_NONE; }

   // v1.10: MTF trend direction for dashboard
   bool PassMTFFilter()
     { if(!m_useMTF) return true;
       return m_ind.htfValid; }

   string GetHTFTrendDirection()
     { if(!m_ind.htfValid) return "N/A";
       if(m_ind.htfEmaFast>m_ind.htfEmaSlow) return "BULLISH";
       if(m_ind.htfEmaFast<m_ind.htfEmaSlow) return "BEARISH";
       return "FLAT"; }

   bool PassSessionFilter()
     { if(!m_useSession) return true;
       MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
       int cur=dt.hour*60+dt.min, st=m_sessStartH*60+m_sessStartM, en=m_sessEndH*60+m_sessEndM;
       if(dt.day_of_week==0||dt.day_of_week==6) return false;
       if(m_avoidFriday&&dt.day_of_week==5&&cur>=m_fridayCutoff*60) return false;
       if(st<en) { if(cur<st||cur>=en) return false; }
       else { if(cur<st&&cur>=en) return false; }
       return true; }

   bool PassSpreadFilter(int currentSpread)
     { if(!m_useSpread) return true; return currentSpread<=m_maxSpread; }

   bool PassNewsFilter()
     { if(!m_useNews) return true; datetime now=TimeCurrent();
       for(int i=0;i<3;i++) if(IsNearNewsTime(m_newsTime[i],now)) return false;
       return true; }

   string GetTrendDirection()
     { if(!m_ind.valid) return "N/A";
       if(m_ind.emaFast>m_ind.emaSlow) return "BULLISH";
       if(m_ind.emaFast<m_ind.emaSlow) return "BEARISH";
       return "FLAT"; }

private:
   bool IsNearNewsTime(string ts,datetime now)
     { if(ts==""||StringLen(ts)<4) return false;
       int cp=StringFind(ts,":"); if(cp<0) return false;
       int nh=(int)StringToInteger(StringSubstr(ts,0,cp));
       int nm=(int)StringToInteger(StringSubstr(ts,cp+1));
       MqlDateTime d; TimeToStruct(now,d); d.hour=nh; d.min=nm; d.sec=0;
       datetime nt=StructToTime(d);
       return (now>=nt-m_newsMinsBefore*60&&now<=nt+m_newsMinsAfter*60); }
  };

#endif
