//+------------------------------------------------------------------+
//|                                                     ASQCore.mqh  |
//|            ASQ Safe Scalping v1.10 - Core Definitions            |
//|          Enums, Data Structures, Logging, Utility Functions       |
//+------------------------------------------------------------------+
#property copyright   "AlgoSphere Quant"
#property link        "https://www.mql5.com/en/users/robin2.0"
#property version     "1.10"
#property strict

#ifndef ASQ_CORE_MQH
#define ASQ_CORE_MQH

#define ASQ_VERSION          "1.10"
#define ASQ_BUILD            "20260327"
#define ASQ_NAME             "ASQ Safe Scalping"
#define ASQ_COMMENT          "ASQv1"

#define ASQ_MIN_BARS         250
#define ASQ_GUI_UPDATE_MS    500
#define ASQ_MAX_RETRIES      3
#define ASQ_RETRY_DELAY_MS   300

#define ASQ_PREFIX           "ASQ_"
#define ASQ_CP_PREFIX        "ASQ_CP_"
#define ASQ_AN_PREFIX        "ASQ_AN_"
#define ASQ_OV_PREFIX        "ASQ_OV_"
#define ASQ_CK_PREFIX        "ASQ_CK_"

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                     |
//+------------------------------------------------------------------+
enum ENUM_ASQ_LOT_MODE
  { ASQ_LOT_FIXED=0, ASQ_LOT_RISK_PCT=1 };

enum ENUM_ASQ_TREND_STRENGTH
  { ASQ_TREND_WEAK=0, ASQ_TREND_MODERATE=1, ASQ_TREND_STRONG=2 };

enum ENUM_ASQ_LOG_LEVEL
  { ASQ_LOG_DEBUG=0, ASQ_LOG_INFO=1, ASQ_LOG_WARNING=2, ASQ_LOG_ERROR=3 };

enum ENUM_ASQ_STATUS
  { ASQ_STATUS_RUNNING=0, ASQ_STATUS_PAUSED=1, ASQ_STATUS_DD_PAUSE=2,
    ASQ_STATUS_OFF_HOURS=3, ASQ_STATUS_SPREAD=4, ASQ_STATUS_NEWS=5,
    ASQ_STATUS_DAYCAP=6, ASQ_STATUS_ERROR=7 };

enum ENUM_ASQ_SIGNAL
  { ASQ_SIGNAL_NONE=0, ASQ_SIGNAL_BUY=1, ASQ_SIGNAL_SELL=-1 };

//+------------------------------------------------------------------+
//| DATA STRUCTURES                                                  |
//+------------------------------------------------------------------+
struct SAsqMarketData
  {
   string symbol; double point; int digits;
   double tickSize,tickValue,lotMin,lotMax,lotStep;
   double bid,ask; int spreadPoints; long leverage;
   void Reset()
     { symbol=""; point=0; digits=0; tickSize=0; tickValue=0;
       lotMin=0.01; lotMax=100; lotStep=0.01;
       bid=0; ask=0; spreadPoints=0; leverage=0; }
  };

struct SAsqIndicators
  {
   double emaFast,emaSlow,emaFastPrev,emaSlowPrev;
   double rsi,atr,close1,close2,highestHigh,lowestLow;
   double htfEmaFast,htfEmaSlow;
   bool   htfValid,valid;
   void Reset()
     { emaFast=0; emaSlow=0; emaFastPrev=0; emaSlowPrev=0;
       rsi=50; atr=0; close1=0; close2=0; highestHigh=0; lowestLow=0;
       htfEmaFast=0; htfEmaSlow=0; htfValid=false; valid=false; }
  };

struct SAsqTradeStats
  {
   int    totalTrades,wins,losses;
   double grossProfit,grossLoss,winRate,profitFactor;
   double avgWin,avgLoss,expectancy;
   int    maxWinStreak,maxLossStreak,currentStreak;
   double todayPnL,totalPnL;
   int    todayTrades,todayLosses;
   void Reset()
     { totalTrades=0; wins=0; losses=0; grossProfit=0; grossLoss=0;
       winRate=0; profitFactor=0; avgWin=0; avgLoss=0; expectancy=0;
       maxWinStreak=0; maxLossStreak=0; currentStreak=0;
       todayPnL=0; totalPnL=0; todayTrades=0; todayLosses=0; }
   void Recalculate()
     { winRate      = totalTrades>0 ? (double)wins/totalTrades*100.0 : 0;
       profitFactor = grossLoss!=0 ? grossProfit/MathAbs(grossLoss) : 0;
       avgWin       = wins>0 ? grossProfit/wins : 0;
       avgLoss      = losses>0 ? grossLoss/losses : 0;
       expectancy   = totalTrades>0 ? (grossProfit+grossLoss)/totalTrades : 0; }
  };

struct SAsqCockpitData
  {
   string symbol,timeframe;
   double bid,ask; int spreadPoints;
   double balance,equity,freeMargin,floatingPnL,dailyPnL;
   double lotSize,riskPct; bool useLotMode;
   ENUM_ASQ_STATUS status; string statusText;
   bool   autoTrading,spreadOK,sessionON,newsClear,mtfOK,daycapOK;
   ENUM_ASQ_SIGNAL lastSignal;
   string trendDir,htfTrendDir;
   double emaFast,emaSlow,rsi,atr;
   double currentDD,peakDD,allowedDD;
   int    openPositions,todayTrades,maxDayTrades;
   SAsqTradeStats stats;
   int    uptimeSec;
   void Reset()
     { symbol=""; timeframe=""; bid=0; ask=0; spreadPoints=0;
       balance=0; equity=0; freeMargin=0; floatingPnL=0; dailyPnL=0;
       lotSize=0.01; riskPct=1.0; useLotMode=true;
       status=ASQ_STATUS_RUNNING; statusText="RUNNING"; autoTrading=true;
       spreadOK=true; sessionON=true; newsClear=true; mtfOK=true; daycapOK=true;
       lastSignal=ASQ_SIGNAL_NONE; trendDir="FLAT"; htfTrendDir="FLAT";
       emaFast=0; emaSlow=0; rsi=50; atr=0;
       currentDD=0; peakDD=0; allowedDD=10;
       openPositions=0; todayTrades=0; maxDayTrades=0;
       stats.Reset(); uptimeSec=0; }
  };

struct SAsqGuiCommands
  {
   bool cmdBuy,cmdSell,cmdCloseAll,cmdToggleAuto;
   bool cmdModeLot,cmdModeRisk,cmdLotUp,cmdLotDown;
   bool cmdLot001,cmdLot005,cmdLot010,cmdLot050;
   void Reset()
     { cmdBuy=false; cmdSell=false; cmdCloseAll=false; cmdToggleAuto=false;
       cmdModeLot=false; cmdModeRisk=false; cmdLotUp=false; cmdLotDown=false;
       cmdLot001=false; cmdLot005=false; cmdLot010=false; cmdLot050=false; }
  };

//+------------------------------------------------------------------+
//| LOGGING                                                          |
//+------------------------------------------------------------------+
ENUM_ASQ_LOG_LEVEL g_asqLogLevel = ASQ_LOG_INFO;

void ASQLog(string message, ENUM_ASQ_LOG_LEVEL level=ASQ_LOG_INFO)
  { if(level<g_asqLogLevel) return;
    string p;
    switch(level)
      { case ASQ_LOG_DEBUG: p="[DEBUG] "; break; case ASQ_LOG_INFO: p="[INFO]  "; break;
        case ASQ_LOG_WARNING: p="[WARN]  "; break; case ASQ_LOG_ERROR: p="[ERROR] "; break; }
    Print(ASQ_NAME," v",ASQ_VERSION," ",p,message); }

void ASQDebug(string m) { ASQLog(m,ASQ_LOG_DEBUG); }
void ASQInfo(string m)  { ASQLog(m,ASQ_LOG_INFO); }
void ASQWarn(string m)  { ASQLog(m,ASQ_LOG_WARNING); }
void ASQError(string m) { ASQLog(m,ASQ_LOG_ERROR); }

void ASQLogTrade(string action,double lot,double price,double sl,double tp)
  { int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
    ASQInfo(action+" "+DoubleToString(lot,2)+" @ "+DoubleToString(price,dg)+
            " SL="+DoubleToString(sl,dg)+" TP="+DoubleToString(tp,dg)); }

//+------------------------------------------------------------------+
//| UTILITIES                                                        |
//+------------------------------------------------------------------+
double ASQSafeDiv(double a,double b,double def=0) { return b!=0?a/b:def; }
double ASQClamp(double v,double lo,double hi)      { return v<lo?lo:v>hi?hi:v; }
int    ASQClampI(int v,int lo,int hi)              { return v<lo?lo:v>hi?hi:v; }

string ASQFmtMoney(double v,bool sign=false)
  { string p=(sign&&v>0)?"+$":(v<0?"-$":"$"); double a=MathAbs(v);
    if(a>=1000) { int w=(int)MathFloor(a); int c=(int)MathRound((a-w)*100);
      string ws=IntegerToString(w),f=""; int len=StringLen(ws);
      for(int i=0;i<len;i++){if(i>0&&(len-i)%3==0)f+=",";f+=StringSubstr(ws,i,1);}
      return p+f+"."+StringFormat("%02d",c); }
    return p+DoubleToString(a,2); }

string ASQFmtPct(double v,int dec=1) { return DoubleToString(v,dec)+"%"; }

string ASQFmtTime(int sec)
  { int h=sec/3600,m=(sec%3600)/60,s=sec%60;
    return StringFormat("%d:%02d:%02d",h,m,s); }

color ASQPnlColor(double v,color pos,color neg,color zero)
  { return v>0?pos:v<0?neg:zero; }

string ASQGetSessionName()
  { MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); int h=dt.hour;
    if(h>=0&&h<8) return "ASIAN"; if(h>=8&&h<12) return "LONDON";
    if(h>=12&&h<16) return "LON-NY OVERLAP"; if(h>=16&&h<21) return "NEW YORK";
    return "OFF HOURS"; }

datetime ASQGetDayStart()
  { MqlDateTime dt; TimeCurrent(dt); dt.hour=0; dt.min=0; dt.sec=0;
    return StructToTime(dt); }

bool ASQIsWeekend()
  { MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
    return (dt.day_of_week==0||dt.day_of_week==6); }

#endif
