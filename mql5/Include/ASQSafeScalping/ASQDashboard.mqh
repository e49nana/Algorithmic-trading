//+------------------------------------------------------------------+
//|                                              ASQDashboard.mqh    |
//|         ASQ Safe Scalping v1.10 - Dashboard GUI Module           |
//|         SCARLET FORGE Theme + MTF/DayCap/PeakDD/Trailing         |
//+------------------------------------------------------------------+
#property copyright   "AlgoSphere Quant"
#property link        "https://www.mql5.com/en/users/robin2.0"
#property version     "1.10"
#property strict

#ifndef ASQ_DASHBOARD_MQH
#define ASQ_DASHBOARD_MQH

#include "ASQCore.mqh"

//+------------------------------------------------------------------+
//| SCARLET FORGE PALETTE                                            |
//+------------------------------------------------------------------+
#define CLR_BASE          C'16,12,10'
#define CLR_PANEL         C'28,20,18'
#define CLR_CARD          C'40,30,26'
#define CLR_INSET         C'20,14,12'
#define CLR_EDGE          C'60,44,38'
#define CLR_RULE          C'48,34,28'
#define CLR_GLOW          C'224,72,40'
#define CLR_HI            C'240,220,210'
#define CLR_MID           C'195,175,165'
#define CLR_LO            C'130,115,105'
#define CLR_DIM           C'80,65,58'
#define CLR_INV           C'16,12,10'
#define CLR_CHROME        C'200,185,175'
#define CLR_CHROME_BR     C'230,215,205'
#define CLR_CHROME_DK     C'150,135,125'
#define CLR_UP            C'64,200,128'
#define CLR_UP_BG         C'14,34,22'
#define CLR_DN            C'224,72,40'
#define CLR_DN_BG         C'42,16,10'
#define CLR_WARN          C'245,175,55'
#define CLR_FLAT          C'100,85,78'

#define FN_UI   "Segoe UI"
#define FN_NUM  "Consolas"
#define FN_HEAD "Segoe UI Semibold"
#define SZ_H1 11
#define SZ_H2 9
#define SZ_BODY 8
#define SZ_NUM 9
#define SZ_SM 7
#define SZ_BTN 8

struct SChartTheme
  { color bg,fg,grid,barUp,barDn,bullC,bearC,lineC,vol,bidLn,askLn,stopLn;
    bool chartFg,saved; void Reset(){saved=false;} };

class CASQGui
  {
private: long m_ch; SChartTheme m_bak; bool m_themed;
public:
   CASQGui():m_ch(0),m_themed(false){m_bak.Reset();}
   bool Init(long c){m_ch=c;return true;}
   int W(){return(int)ChartGetInteger(m_ch,CHART_WIDTH_IN_PIXELS);}
   int H(){return(int)ChartGetInteger(m_ch,CHART_HEIGHT_IN_PIXELS);}
   void ApplyTheme()
     { if(m_themed) return; SaveTheme();
       ChartSetInteger(m_ch,CHART_FOREGROUND,false);
       ChartSetInteger(m_ch,CHART_COLOR_BACKGROUND,CLR_BASE);
       ChartSetInteger(m_ch,CHART_COLOR_FOREGROUND,CLR_LO);
       ChartSetInteger(m_ch,CHART_COLOR_GRID,C'22,16,14');
       ChartSetInteger(m_ch,CHART_COLOR_CANDLE_BULL,CLR_CHROME_BR);
       ChartSetInteger(m_ch,CHART_COLOR_CANDLE_BEAR,C'50,36,30');
       ChartSetInteger(m_ch,CHART_COLOR_CHART_UP,CLR_CHROME);
       ChartSetInteger(m_ch,CHART_COLOR_CHART_DOWN,CLR_CHROME_DK);
       ChartSetInteger(m_ch,CHART_COLOR_CHART_LINE,CLR_CHROME);
       ChartSetInteger(m_ch,CHART_COLOR_VOLUME,C'48,35,28');
       ChartSetInteger(m_ch,CHART_COLOR_BID,CLR_CHROME_DK);
       ChartSetInteger(m_ch,CHART_COLOR_ASK,CLR_DIM);
       ChartSetInteger(m_ch,CHART_COLOR_STOP_LEVEL,CLR_DN);
       ChartRedraw(m_ch); m_themed=true; }
   void OpaqueOnly()
     { if(!m_bak.saved) SaveTheme(); ChartSetInteger(m_ch,CHART_FOREGROUND,false); m_themed=true; ChartRedraw(m_ch); }
   void Restore()
     { if(!m_themed||!m_bak.saved) return;
       ChartSetInteger(m_ch,CHART_COLOR_BACKGROUND,m_bak.bg);
       ChartSetInteger(m_ch,CHART_COLOR_FOREGROUND,m_bak.fg);
       ChartSetInteger(m_ch,CHART_COLOR_GRID,m_bak.grid);
       ChartSetInteger(m_ch,CHART_COLOR_CHART_UP,m_bak.barUp);
       ChartSetInteger(m_ch,CHART_COLOR_CHART_DOWN,m_bak.barDn);
       ChartSetInteger(m_ch,CHART_COLOR_CANDLE_BULL,m_bak.bullC);
       ChartSetInteger(m_ch,CHART_COLOR_CANDLE_BEAR,m_bak.bearC);
       ChartSetInteger(m_ch,CHART_COLOR_CHART_LINE,m_bak.lineC);
       ChartSetInteger(m_ch,CHART_COLOR_VOLUME,m_bak.vol);
       ChartSetInteger(m_ch,CHART_COLOR_BID,m_bak.bidLn);
       ChartSetInteger(m_ch,CHART_COLOR_ASK,m_bak.askLn);
       ChartSetInteger(m_ch,CHART_COLOR_STOP_LEVEL,m_bak.stopLn);
       ChartSetInteger(m_ch,CHART_FOREGROUND,m_bak.chartFg);
       ChartRedraw(m_ch); m_themed=false; }
   void Cleanup(){Restore();ObjectsDeleteAll(m_ch,ASQ_PREFIX);}
   void Box(string n,int x,int y,int w,int h,color bg,color brd=clrNONE)
     { bool e=(ObjectFind(m_ch,n)>=0);
       if(!e){ObjectCreate(m_ch,n,OBJ_RECTANGLE_LABEL,0,0,0);
         ObjectSetInteger(m_ch,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);
         ObjectSetInteger(m_ch,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
         ObjectSetInteger(m_ch,n,OBJPROP_BACK,false);ObjectSetInteger(m_ch,n,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(m_ch,n,OBJPROP_HIDDEN,true);ObjectSetInteger(m_ch,n,OBJPROP_ZORDER,0);}
       ObjectSetInteger(m_ch,n,OBJPROP_XDISTANCE,x);ObjectSetInteger(m_ch,n,OBJPROP_YDISTANCE,y);
       ObjectSetInteger(m_ch,n,OBJPROP_XSIZE,w);ObjectSetInteger(m_ch,n,OBJPROP_YSIZE,h);
       ObjectSetInteger(m_ch,n,OBJPROP_BGCOLOR,bg);ObjectSetInteger(m_ch,n,OBJPROP_BORDER_COLOR,brd==clrNONE?bg:brd);}
   void Txt(string n,int x,int y,string t,color c,int sz=SZ_BODY,string f=FN_UI,int anch=ANCHOR_LEFT_UPPER)
     { bool e=(ObjectFind(m_ch,n)>=0);
       if(!e){ObjectCreate(m_ch,n,OBJ_LABEL,0,0,0);
         ObjectSetInteger(m_ch,n,OBJPROP_ANCHOR,anch);ObjectSetInteger(m_ch,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
         ObjectSetInteger(m_ch,n,OBJPROP_BACK,false);ObjectSetInteger(m_ch,n,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(m_ch,n,OBJPROP_HIDDEN,true);}
       ObjectSetInteger(m_ch,n,OBJPROP_XDISTANCE,x);ObjectSetInteger(m_ch,n,OBJPROP_YDISTANCE,y);
       ObjectSetString(m_ch,n,OBJPROP_TEXT,t);ObjectSetInteger(m_ch,n,OBJPROP_COLOR,c);
       ObjectSetString(m_ch,n,OBJPROP_FONT,f);ObjectSetInteger(m_ch,n,OBJPROP_FONTSIZE,sz);}
   void Btn(string n,int x,int y,int w,int h,string t,color bg,color tc,int sz=SZ_BTN,int z=100)
     { bool e=(ObjectFind(m_ch,n)>=0);
       if(!e){ObjectCreate(m_ch,n,OBJ_BUTTON,0,0,0);ObjectSetInteger(m_ch,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
         ObjectSetInteger(m_ch,n,OBJPROP_BACK,false);ObjectSetInteger(m_ch,n,OBJPROP_SELECTABLE,false);}
       ObjectSetInteger(m_ch,n,OBJPROP_XDISTANCE,x);ObjectSetInteger(m_ch,n,OBJPROP_YDISTANCE,y);
       ObjectSetInteger(m_ch,n,OBJPROP_XSIZE,w);ObjectSetInteger(m_ch,n,OBJPROP_YSIZE,h);
       ObjectSetString(m_ch,n,OBJPROP_TEXT,t);ObjectSetInteger(m_ch,n,OBJPROP_BGCOLOR,bg);
       ObjectSetInteger(m_ch,n,OBJPROP_COLOR,tc);ObjectSetString(m_ch,n,OBJPROP_FONT,FN_UI);
       ObjectSetInteger(m_ch,n,OBJPROP_FONTSIZE,sz);ObjectSetInteger(m_ch,n,OBJPROP_ZORDER,z);}
   void Hide(string n)
     { if(ObjectFind(m_ch,n)>=0){ObjectSetInteger(m_ch,n,OBJPROP_XDISTANCE,-5000);ObjectSetInteger(m_ch,n,OBJPROP_YDISTANCE,-5000);}}
private:
   void SaveTheme()
     { if(m_bak.saved) return;
       m_bak.bg=(color)ChartGetInteger(m_ch,CHART_COLOR_BACKGROUND);
       m_bak.fg=(color)ChartGetInteger(m_ch,CHART_COLOR_FOREGROUND);
       m_bak.grid=(color)ChartGetInteger(m_ch,CHART_COLOR_GRID);
       m_bak.barUp=(color)ChartGetInteger(m_ch,CHART_COLOR_CHART_UP);
       m_bak.barDn=(color)ChartGetInteger(m_ch,CHART_COLOR_CHART_DOWN);
       m_bak.bullC=(color)ChartGetInteger(m_ch,CHART_COLOR_CANDLE_BULL);
       m_bak.bearC=(color)ChartGetInteger(m_ch,CHART_COLOR_CANDLE_BEAR);
       m_bak.lineC=(color)ChartGetInteger(m_ch,CHART_COLOR_CHART_LINE);
       m_bak.vol=(color)ChartGetInteger(m_ch,CHART_COLOR_VOLUME);
       m_bak.bidLn=(color)ChartGetInteger(m_ch,CHART_COLOR_BID);
       m_bak.askLn=(color)ChartGetInteger(m_ch,CHART_COLOR_ASK);
       m_bak.stopLn=(color)ChartGetInteger(m_ch,CHART_COLOR_STOP_LEVEL);
       m_bak.chartFg=(bool)ChartGetInteger(m_ch,CHART_FOREGROUND);
       m_bak.saved=true;}
  };

//+------------------------------------------------------------------+
//| DASHBOARD v1.10                                                  |
//+------------------------------------------------------------------+
class CASQDashboard
  {
private:
   CASQGui m_g; SAsqGuiCommands m_cmd;
   bool m_vis,m_open,m_prevOpen; uint m_lastClk;
   int m_panelW,m_cpW,m_cpH,m_ri,m_ci;
   bool m_confirmActive; uint m_confirmTime; bool m_bgCreated;
public:
   CASQDashboard():m_vis(false),m_open(true),m_prevOpen(true),m_lastClk(0),
     m_panelW(260),m_cpW(760),m_cpH(88),m_ri(0),m_ci(0),
     m_confirmActive(false),m_confirmTime(0),m_bgCreated(false){m_cmd.Reset();}

   bool Init(long id,bool sync)
     {if(!m_g.Init(id)) return false; if(sync) m_g.ApplyTheme(); else m_g.OpaqueOnly(); m_vis=true; return true;}
   void Deinit(){m_g.Cleanup();m_vis=false;}
   void GetCommands(SAsqGuiCommands &o){o=m_cmd;}
   void ClearCommands(){m_cmd.Reset();}
   void SetPanelVisible(bool v){m_open=v;}

   void Draw(SAsqCockpitData &d)
     { if(!m_vis) return; ChartSetInteger(0,CHART_FOREGROUND,false);
       if(m_confirmActive&&GetTickCount()-m_confirmTime>3000){m_confirmActive=false;m_confirmTime=0;}
       if(!m_bgCreated){CreatePanelBG();m_bgCreated=true;}
       DrawStrip(d); DrawCockpit(d);
       if(m_open){DrawPanel(d);if(!m_prevOpen){m_g.Hide(P("TAB"));m_g.Hide(P("TT"));}}
       else{DrawTab();HidePanel();}
       m_prevOpen=m_open; ChartRedraw(); }

   bool OnEvent(const int id,const long &lp,const double &dp,const string &sp)
     { if(!m_vis||id!=CHARTEVENT_OBJECT_CLICK) return false;
       if(StringFind(sp,ASQ_CP_PREFIX)==0)
         {ObjectSetInteger(0,sp,OBJPROP_STATE,false);
          if(StringSubstr(sp,StringLen(ASQ_CP_PREFIX))=="TOG"){m_open=!m_open;return true;} return false;}
       if(StringFind(sp,ASQ_CK_PREFIX)==0)
         {ObjectSetInteger(0,sp,OBJPROP_STATE,false);HandleClick(StringSubstr(sp,StringLen(ASQ_CK_PREFIX)));return true;}
       if(StringFind(sp,ASQ_AN_PREFIX)==0)
         {ObjectSetInteger(0,sp,OBJPROP_STATE,false);HandleClick(StringSubstr(sp,StringLen(ASQ_AN_PREFIX)));return true;}
       return false; }
   bool OnResize(){m_bgCreated=false;return true;}

private:
   string S(string n){return ASQ_CP_PREFIX+n;}
   string K(string n){return ASQ_CK_PREFIX+n;}
   string P(string n){return ASQ_AN_PREFIX+n;}
   color PnlC(double v){return v>0.005?CLR_UP:v<-0.005?CLR_DN:CLR_FLAT;}

   void CreatePanelBG()
     { int cW=m_g.W(),cH=m_g.H(),pw=m_panelW,px=cW-pw-4,py=32,ph=cH-py-m_cpH-20;
       m_g.Box(P("SH"),px-2,py-2,pw+4,ph+4,CLR_BASE);
       m_g.Box(P("BG"),px,py,pw,ph,CLR_PANEL,CLR_EDGE);
       m_g.Box(P("GL"),px+1,py,pw-2,2,CLR_GLOW);
       for(int i=0;i<6;i++) m_g.Box(P("CF"+IntegerToString(i)),0,0,1,1,CLR_CARD,CLR_EDGE);
       m_g.Box(P("DDB"),0,0,1,1,CLR_INSET,CLR_EDGE);
       m_g.Box(P("DDF"),0,0,1,1,CLR_INSET); }

   void HidePanel()
     { m_g.Hide(P("SH"));m_g.Hide(P("BG"));m_g.Hide(P("GL"));
       for(int i=0;i<6;i++) m_g.Hide(P("CF"+IntegerToString(i)));
       m_g.Hide(P("DDB"));m_g.Hide(P("DDF"));
       for(int i=0;i<50;i++){m_g.Hide(P("RL"+IntegerToString(i)));m_g.Hide(P("RV"+IntegerToString(i)));}
       m_g.Hide(P("AH"));m_g.Hide(P("SH2"));m_g.Hide(P("RH"));m_g.Hide(P("SSH"));m_g.Hide(P("TH"));m_g.Hide(P("MH"));
       m_g.Hide(P("FT"));m_g.Hide(P("FB")); }

   //--- STATUS STRIP
   void DrawStrip(SAsqCockpitData &d)
     { int cW=m_g.W(),sH=28;
       m_g.Box(S("BG"),0,0,cW,sH,CLR_BASE,CLR_EDGE);
       m_g.Box(S("LN"),0,sH-1,cW,1,CLR_GLOW);
       int x=10,y=7;
       m_g.Txt(S("NM"),x,y,"ASQ",CLR_GLOW,SZ_H2,FN_HEAD); x+=30;
       color stC; string stT; StatusLbl(d,stC,stT);
       m_g.Txt(S("ST"),x,y,stT,stC,SZ_SM,FN_NUM); x+=50;
       m_g.Box(S("D1"),x,5,1,18,CLR_RULE); x+=8;
       m_g.Txt(S("SY"),x,y,d.symbol,CLR_HI,SZ_BODY,FN_HEAD); x+=62;
       m_g.Txt(S("TF"),x,y+1,d.timeframe,CLR_CHROME_DK,SZ_SM,FN_NUM); x+=28;
       m_g.Txt(S("SP"),x,y+1,IntegerToString(d.spreadPoints)+"sp",d.spreadOK?CLR_UP:CLR_DN,SZ_SM,FN_NUM); x+=36;
       m_g.Box(S("D2"),x,5,1,18,CLR_RULE); x+=8;
       m_g.Txt(S("EQ"),x,y,ASQFmtMoney(d.equity),CLR_HI,SZ_BODY,FN_NUM); x+=85;
       m_g.Txt(S("DY"),x,y,ASQFmtMoney(d.dailyPnL,true),PnlC(d.dailyPnL),SZ_BODY,FN_NUM); x+=75;
       m_g.Box(S("D3"),x,5,1,18,CLR_RULE); x+=8;
       int dy=y+3;
       m_g.Box(S("F1"),x,dy,6,6,d.spreadOK?CLR_UP:CLR_DN);
       m_g.Box(S("F2"),x+10,dy,6,6,d.sessionON?CLR_UP:CLR_DN);
       m_g.Box(S("F3"),x+20,dy,6,6,d.newsClear?CLR_UP:CLR_DN);
       m_g.Box(S("F4"),x+30,dy,6,6,d.mtfOK?CLR_UP:CLR_DIM);      // v1.10: MTF dot
       m_g.Box(S("F5"),x+40,dy,6,6,d.daycapOK?CLR_UP:CLR_WARN);   // v1.10: DayCap dot
       x+=54;
       string sigT="--"; color sigC=CLR_DIM;
       if(d.lastSignal==ASQ_SIGNAL_BUY){sigT="BUY";sigC=CLR_UP;}
       if(d.lastSignal==ASQ_SIGNAL_SELL){sigT="SELL";sigC=CLR_DN;}
       m_g.Txt(S("SG"),x,y,sigT,sigC,SZ_SM,FN_NUM);
       m_g.Btn(S("TOG"),cW-36,3,32,22,m_open?">>":"<<",CLR_CARD,CLR_CHROME_DK,SZ_SM,100); }

   //--- COCKPIT
   void DrawCockpit(SAsqCockpitData &d)
     { int cW=m_g.W(),cH=m_g.H(),bx=MathMax(8,(cW-m_cpW)/2),by=cH-m_cpH-8;
       m_g.Box(K("SH"),bx-1,by-1,m_cpW+2,m_cpH+2,CLR_BASE);
       m_g.Box(K("BG"),bx,by,m_cpW,m_cpH,CLR_PANEL,CLR_EDGE);
       m_g.Box(K("TOP"),bx+1,by,m_cpW-2,2,CLR_GLOW);
       int c1=bx+12,c2=bx+150,c3=bx+314,c4=bx+510,c5=bx+650;
       int dY=by+10,dH=m_cpH-20;
       m_g.Box(K("D1"),bx+144,dY,1,dH,CLR_RULE);m_g.Box(K("D2"),bx+308,dY,1,dH,CLR_RULE);
       m_g.Box(K("D3"),bx+504,dY,1,dH,CLR_RULE);m_g.Box(K("D4"),bx+644,dY,1,dH,CLR_RULE);
       // COL 1
       int y=by+8;
       m_g.Txt(K("TTL"),c1,y,"ALGOSPHERE",CLR_GLOW,SZ_H1,FN_HEAD);
       m_g.Txt(K("VER"),c1,y+16,"v"+ASQ_VERSION+" Safe Scalping",CLR_DIM,SZ_SM);
       color stBg,stTx; string stTxt; StatusStyle(d,stBg,stTx,stTxt);
       m_g.Box(K("SBG"),c1,y+34,66,17,stBg);
       m_g.Txt(K("STX"),c1+6,y+37,stTxt,stTx,SZ_SM,FN_HEAD);
       m_g.Btn(K("AUTO"),c1,y+56,50,18,d.autoTrading?"AUTO":"OFF",d.autoTrading?CLR_UP_BG:CLR_CARD,d.autoTrading?CLR_UP:CLR_LO,SZ_SM,50);
       string sigT="WAIT"; color sigC=CLR_DIM;
       if(d.lastSignal==ASQ_SIGNAL_BUY){sigT="BUY";sigC=CLR_UP;}
       if(d.lastSignal==ASQ_SIGNAL_SELL){sigT="SELL";sigC=CLR_DN;}
       m_g.Txt(K("SIG"),c1+56,y+59,sigT,sigC,SZ_SM,FN_NUM);
       // COL 2
       y=by+8; int dg=(int)SymbolInfoInteger(d.symbol,SYMBOL_DIGITS);
       m_g.Txt(K("SYM"),c2,y,d.symbol,CLR_HI,SZ_H1,FN_HEAD);
       m_g.Txt(K("TFM"),c2+80,y+2,d.timeframe,CLR_CHROME_DK,SZ_BODY,FN_NUM);
       m_g.Txt(K("SPL"),c2,y+18,"Spread",CLR_LO,SZ_SM);
       m_g.Txt(K("SPV"),c2+48,y+18,IntegerToString(d.spreadPoints)+" pts",d.spreadOK?CLR_UP:CLR_DN,SZ_SM,FN_NUM);
       m_g.Txt(K("BDL"),c2,y+32,"Bid",CLR_LO,SZ_SM);
       m_g.Txt(K("BDV"),c2+48,y+32,DoubleToString(d.bid,dg),CLR_MID,SZ_SM,FN_NUM);
       m_g.Txt(K("EQL"),c2,y+46,"Equity",CLR_LO,SZ_SM);
       m_g.Txt(K("EQV"),c2+48,y+46,ASQFmtMoney(d.equity),CLR_HI,SZ_SM,FN_NUM);
       m_g.Txt(K("DYL"),c2,y+60,"Today",CLR_LO,SZ_SM);
       m_g.Txt(K("DYV"),c2+48,y+60,ASQFmtMoney(d.dailyPnL,true),PnlC(d.dailyPnL),SZ_SM,FN_NUM);
       // COL 3: BUTTONS
       y=by+8; int bW=65,bH=24,bG=5;
       m_g.Btn(K("BUY"),c3,y,bW,bH,"BUY",CLR_UP_BG,CLR_UP,SZ_BTN,50);
       m_g.Btn(K("SELL"),c3+bW+bG,y,bW,bH,"SELL",CLR_DN_BG,CLR_DN,SZ_BTN,50);
       m_g.Btn(K("CLS"),c3,y+bH+4,2*bW+bG,20,m_confirmActive?"CONFIRM":"CLS ALL",m_confirmActive?CLR_DN:CLR_CARD,m_confirmActive?CLR_HI:CLR_LO,SZ_SM,50);
       m_g.Txt(K("POS"),c3,y+56,"Pos: "+IntegerToString(d.openPositions),CLR_MID,SZ_SM,FN_NUM);
       m_g.Txt(K("FLT"),c3+58,y+56,"PnL: "+ASQFmtMoney(d.floatingPnL,true),PnlC(d.floatingPnL),SZ_SM,FN_NUM);
       // COL 4: LOT
       y=by+8;
       m_g.Btn(K("MLOT"),c4,y,46,18,"LOT",d.useLotMode?CLR_CHROME_DK:CLR_CARD,d.useLotMode?CLR_INV:CLR_LO,SZ_SM,50);
       m_g.Btn(K("MRSK"),c4+50,y,54,18,"RISK%",d.useLotMode?CLR_CARD:CLR_CHROME_DK,d.useLotMode?CLR_LO:CLR_INV,SZ_SM,50);
       y+=24;
       m_g.Btn(K("DN"),c4,y,24,24,"-",CLR_CARD,CLR_MID,SZ_H1,50);
       m_g.Box(K("VBG"),c4+26,y,58,24,CLR_INSET,CLR_GLOW);
       m_g.Txt(K("VAL"),c4+55,y+5,d.useLotMode?DoubleToString(d.lotSize,2):ASQFmtPct(d.riskPct),CLR_CHROME_BR,SZ_NUM,FN_NUM,ANCHOR_UPPER);
       m_g.Btn(K("UP"),c4+86,y,24,24,"+",CLR_CARD,CLR_MID,SZ_H1,50);
       y+=30;
       m_g.Btn(K("L01"),c4,y,28,16,".01",CLR_CARD,CLR_DIM,SZ_SM,50);
       m_g.Btn(K("L05"),c4+32,y,28,16,".05",CLR_CARD,CLR_DIM,SZ_SM,50);
       m_g.Btn(K("L10"),c4+64,y,28,16,".10",CLR_CARD,CLR_DIM,SZ_SM,50);
       m_g.Btn(K("L50"),c4+96,y,28,16,".50",CLR_CARD,CLR_DIM,SZ_SM,50);
       // COL 5: FILTERS (v1.10: +MTF, +DayCap)
       y=by+8;
       m_g.Txt(K("FLBL"),c5,y,"FILTERS",CLR_CHROME_DK,SZ_SM,FN_HEAD); y+=14;
       CpF(K("FS"),c5,y,"Spread",d.spreadOK?"OK":"HIGH",d.spreadOK); y+=14;
       CpF(K("FE"),c5,y,"Session",d.sessionON?"ON":"OFF",d.sessionON); y+=14;
       CpF(K("FN"),c5,y,"News",d.newsClear?"CLR":"EVT",d.newsClear); y+=14;
       CpF(K("FM"),c5,y,"MTF",d.mtfOK?"OK":"--",d.mtfOK); y+=14;
       string dcT=d.daycapOK?IntegerToString(d.todayTrades)+"/"+IntegerToString(d.maxDayTrades):"LIMIT";
       CpF(K("FD"),c5,y,"Day",dcT,d.daycapOK); }

   void CpF(string p,int x,int y,string l,string v,bool ok)
     { color c=ok?CLR_UP:CLR_DN; m_g.Box(p+"D",x,y+3,5,5,c); m_g.Txt(p+"L",x+9,y,l+":",CLR_LO,SZ_SM); m_g.Txt(p+"V",x+55,y,v,c,SZ_SM,FN_NUM); }

   void StatusStyle(SAsqCockpitData &d,color &bg,color &tx,string &t)
     { if(!d.autoTrading){bg=CLR_CARD;tx=CLR_WARN;t="MANUAL";}
       else if(d.status==ASQ_STATUS_DD_PAUSE){bg=CLR_DN_BG;tx=CLR_DN;t="DD STOP";}
       else if(d.status==ASQ_STATUS_DAYCAP){bg=CLR_CARD;tx=CLR_WARN;t="DAYCAP";}
       else if(d.status==ASQ_STATUS_PAUSED){bg=CLR_CARD;tx=CLR_WARN;t="PAUSED";}
       else{bg=CLR_UP_BG;tx=CLR_UP;t="ACTIVE";} }

   void StatusLbl(SAsqCockpitData &d,color &c,string &t)
     { if(!d.autoTrading){c=CLR_WARN;t="MANUAL";}
       else if(d.status==ASQ_STATUS_DD_PAUSE){c=CLR_DN;t="DD STOP";}
       else if(d.status==ASQ_STATUS_DAYCAP){c=CLR_WARN;t="DAYCAP";}
       else if(d.status==ASQ_STATUS_PAUSED){c=CLR_WARN;t="PAUSED";}
       else{c=CLR_UP;t="ACTIVE";} }

   void DrawTab()
     { int cW=m_g.W(); m_g.Box(P("TAB"),cW-24,34,20,60,CLR_PANEL,CLR_EDGE); m_g.Txt(P("TT"),cW-19,56,"Q",CLR_GLOW,SZ_H1,FN_HEAD); }

   //--- RIGHT PANEL (v1.10: +MTF section, +Peak DD, +Day Trades)
   void DrawPanel(SAsqCockpitData &d)
     { m_ri=0; m_ci=0;
       int cW=m_g.W(),cH=m_g.H(),pw=m_panelW,px=cW-pw-4,py=32,ph=cH-py-m_cpH-20;
       m_g.Box(P("SH"),px-2,py-2,pw+4,ph+4,CLR_BASE);
       m_g.Box(P("BG"),px,py,pw,ph,CLR_PANEL,CLR_EDGE);
       m_g.Box(P("GL"),px+1,py,pw-2,2,CLR_GLOW);
       int cx=px+12,cw=pw-24,vx=px+pw-14,cy=py+10;
       // ACCOUNT
       int ct=cy; cy+=4;
       m_g.Txt(P("AH"),cx,cy,"ACCOUNT",CLR_CHROME_DK,SZ_SM,FN_HEAD); cy+=15;
       Row(cx,vx,cy,"Balance",ASQFmtMoney(d.balance),CLR_HI);
       Row(cx,vx,cy,"Equity",ASQFmtMoney(d.equity),CLR_HI);
       Row(cx,vx,cy,"Floating",ASQFmtMoney(d.floatingPnL,true),PnlC(d.floatingPnL));
       Row(cx,vx,cy,"Free Margin",ASQFmtMoney(d.freeMargin),CLR_MID);
       cy+=4; Card(px,ct,pw,cy-ct); cy+=6;
       // SIGNAL + MTF
       ct=cy; cy+=4;
       m_g.Txt(P("SH2"),cx,cy,"SIGNAL",CLR_CHROME_DK,SZ_SM,FN_HEAD); cy+=15;
       color tC=d.trendDir=="BULLISH"?CLR_UP:d.trendDir=="BEARISH"?CLR_DN:CLR_FLAT;
       Row(cx,vx,cy,"Trend",d.trendDir,tC);
       color htC=d.htfTrendDir=="BULLISH"?CLR_UP:d.htfTrendDir=="BEARISH"?CLR_DN:CLR_FLAT;
       Row(cx,vx,cy,"HTF Trend",d.htfTrendDir,htC);  // v1.10
       int dg=(int)SymbolInfoInteger(d.symbol,SYMBOL_DIGITS);
       Row(cx,vx,cy,"EMA Fast",DoubleToString(d.emaFast,dg),CLR_CHROME);
       Row(cx,vx,cy,"EMA Slow",DoubleToString(d.emaSlow,dg),CLR_CHROME_DK);
       color rC=d.rsi>70?CLR_DN:d.rsi<30?CLR_UP:CLR_MID;
       Row(cx,vx,cy,"RSI",DoubleToString(d.rsi,1),rC);
       Row(cx,vx,cy,"ATR",DoubleToString(d.atr,dg),CLR_MID);
       cy+=4; Card(px,ct,pw,cy-ct); cy+=6;
       // RISK (v1.10: +Peak DD, +Day Trades)
       ct=cy; cy+=4;
       m_g.Txt(P("RH"),cx,cy,"RISK",CLR_CHROME_DK,SZ_SM,FN_HEAD); cy+=15;
       double ddA=MathAbs(d.currentDD);
       color ddC=ddA<d.allowedDD*0.5?CLR_UP:ddA<d.allowedDD*0.8?CLR_WARN:CLR_DN;
       Row(cx,vx,cy,"Drawdown",DoubleToString(ddA,2)+"%",ddC);
       double pct=d.allowedDD>0?ASQClamp(ddA/d.allowedDD,0,1):0;
       m_g.Box(P("DDB"),cx,cy,cw,5,CLR_INSET,CLR_EDGE);
       m_g.Box(P("DDF"),cx+1,cy+1,MathMax(1,(int)((cw-2)*pct)),3,pct>0.01?ddC:CLR_INSET);
       cy+=9;
       Row(cx,vx,cy,"Peak DD",DoubleToString(d.peakDD,2)+"%",d.peakDD>d.allowedDD*0.8?CLR_DN:CLR_DIM);  // v1.10
       Row(cx,vx,cy,"Limit",DoubleToString(d.allowedDD,1)+"%",CLR_DIM);
       Row(cx,vx,cy,"Day Trades",IntegerToString(d.todayTrades)+"/"+IntegerToString(d.maxDayTrades),d.daycapOK?CLR_MID:CLR_WARN);  // v1.10
       cy+=4; Card(px,ct,pw,cy-ct); cy+=6;
       // SESSION
       ct=cy; cy+=4;
       m_g.Txt(P("SSH"),cx,cy,"SESSION",CLR_CHROME_DK,SZ_SM,FN_HEAD); cy+=15;
       string sn=ASQGetSessionName();
       Row(cx,vx,cy,"Current",d.sessionON?sn:"OFF HOURS",d.sessionON?CLR_UP:CLR_DIM);
       cy+=4; Card(px,ct,pw,cy-ct); cy+=6;
       // PERFORMANCE
       ct=cy; cy+=4;
       m_g.Txt(P("TH"),cx,cy,"PERFORMANCE",CLR_CHROME_DK,SZ_SM,FN_HEAD); cy+=15;
       Row(cx,vx,cy,"Trades",IntegerToString(d.stats.totalTrades),CLR_HI);
       color wrC=d.stats.winRate>=55?CLR_UP:d.stats.winRate>=45?CLR_WARN:CLR_DN;
       Row(cx,vx,cy,"Win Rate",ASQFmtPct(d.stats.winRate),wrC);
       color pfC=d.stats.profitFactor>=1.5?CLR_UP:d.stats.profitFactor>=1.0?CLR_WARN:CLR_DN;
       Row(cx,vx,cy,"PF",DoubleToString(d.stats.profitFactor,2),pfC);
       Row(cx,vx,cy,"Today",ASQFmtMoney(d.stats.todayPnL,true),PnlC(d.stats.todayPnL));
       Row(cx,vx,cy,"Avg Win",ASQFmtMoney(d.stats.avgWin),CLR_UP);
       Row(cx,vx,cy,"Avg Loss",ASQFmtMoney(d.stats.avgLoss),CLR_DN);
       Row(cx,vx,cy,"Expect.",ASQFmtMoney(d.stats.expectancy,true),PnlC(d.stats.expectancy));
       Row(cx,vx,cy,"W/L",IntegerToString(d.stats.wins)+"/"+IntegerToString(d.stats.losses),CLR_MID);
       cy+=4; Card(px,ct,pw,cy-ct); cy+=6;
       // FOOTER
       m_g.Txt(P("FT"),cx,py+ph-18,ASQFmtTime(d.uptimeSec),CLR_DIM,SZ_SM,FN_NUM);
       m_g.Txt(P("FB"),vx,py+ph-18,"AlgoSphere Quant",CLR_DIM,SZ_SM,FN_UI,ANCHOR_RIGHT_UPPER); }

   void Card(int px,int top,int pw,int h)
     { m_g.Box(P("CF"+IntegerToString(m_ci++)),px+4,top,pw-8,h,CLR_CARD,CLR_EDGE); }

   void Row(int lx,int rx,int &y,string lab,string val,color vc)
     { string id=IntegerToString(m_ri++);
       m_g.Txt(P("RL"+id),lx,y,lab,CLR_LO,SZ_SM);
       m_g.Txt(P("RV"+id),rx,y,val,vc,SZ_NUM,FN_NUM,ANCHOR_RIGHT_UPPER); y+=15; }

   void HandleClick(string btn)
     { uint now=GetTickCount(); if(now-m_lastClk<150) return; m_lastClk=now;
       if(btn=="BUY") m_cmd.cmdBuy=true;
       else if(btn=="SELL") m_cmd.cmdSell=true;
       else if(btn=="CLS"){if(m_confirmActive){m_cmd.cmdCloseAll=true;m_confirmActive=false;m_confirmTime=0;}
         else{m_confirmActive=true;m_confirmTime=now;}}
       else if(btn=="AUTO") m_cmd.cmdToggleAuto=true;
       else if(btn=="MLOT") m_cmd.cmdModeLot=true;
       else if(btn=="MRSK") m_cmd.cmdModeRisk=true;
       else if(btn=="DN") m_cmd.cmdLotDown=true;
       else if(btn=="UP") m_cmd.cmdLotUp=true;
       else if(btn=="L01") m_cmd.cmdLot001=true;
       else if(btn=="L05") m_cmd.cmdLot005=true;
       else if(btn=="L10") m_cmd.cmdLot010=true;
       else if(btn=="L50") m_cmd.cmdLot050=true; }
  };

#endif
