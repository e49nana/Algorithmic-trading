//+------------------------------------------------------------------+
//|                                          ASQ_EquityCurve.mq5     |
//|                        Copyright 2026, AlgoSphere Quant          |
//|                        https://www.mql5.com/en/users/robin2.0    |
//+------------------------------------------------------------------+
//| ASQ Equity Curve v1.2 — Free, Open-Source EA                     |
//|                                                                   |
//| Real-time equity curve visualization directly on your chart.      |
//| Pure MQL5 graphics — no DLLs, no external dependencies.          |
//|                                                                   |
//| FEATURES:                                                         |
//| • Live equity + balance curve on chart panel                      |
//| • 4 modes: Equity / Balance / Both / Drawdown                    |
//| • High water mark line                                            |
//| • Drawdown % tracking (current + max)                             |
//| • Return % (total and daily)                                      |
//| • Today's P&L with session tracking                               |
//| • Win/loss streak tracking with max history                       |
//| • Profit factor display                                           |
//| • 500-point data buffer                                           |
//| • Dark branded panel matching ASQ dashboard style                 |
//| • Configurable position, size                                     |
//| • 60-second update throttling for performance                     |
//|                                                                   |
//| AlgoSphere Quant — Precision before profit.                      |
//| https://www.mql5.com/en/users/robin2.0                           |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, AlgoSphere Quant"
#property link        "https://www.mql5.com/en/users/robin2.0"
#property version     "1.20"
#property description "ASQ Equity Curve v1.2 — Live equity/balance visualization on chart."
#property description " "
#property description "4 display modes, drawdown tracking, HWM, daily P&L, profit factor, streak monitoring."
#property description " "
#property description "Free and open-source by AlgoSphere Quant."

//+------------------------------------------------------------------+
//| INPUTS                                                            |
//+------------------------------------------------------------------+
input group "═══ Display ═══"
input int    InpMode     = 2;     // Mode: 0=Equity 1=Balance 2=Both 3=Drawdown
input int    InpPosition = 1;     // Position: 0=TopLeft 1=TopRight 2=BotLeft 3=BotRight
input int    InpWidth    = 420;   // Panel Width
input int    InpHeight   = 220;   // Panel Height

//+------------------------------------------------------------------+
//| CONSTANTS                                                         |
//+------------------------------------------------------------------+
#define PFX     "ASQ_EC_"
#define FNT     "Consolas"
#define MAX_PTS 500
#define UPD_SEC 60

#define CLR_BG      C'18,18,28'
#define CLR_BORDER  C'45,45,65'
#define CLR_GRID    C'35,35,50'
#define CLR_TITLE   C'200,200,240'
#define CLR_SUBTITLE C'120,120,155'
#define CLR_LABEL   C'100,100,135'
#define CLR_EQ      C'0,220,110'
#define CLR_BAL     C'80,160,255'
#define CLR_HWM     C'200,170,0'
#define CLR_DD      C'220,50,50'
#define CLR_WHITE   C'200,200,215'

//+------------------------------------------------------------------+
//| DATA                                                              |
//+------------------------------------------------------------------+
struct SECPt { datetime t; double eq, bal, dd, ddPct; };
struct SECSt
{
   double initEq, curEq, curBal, hwm, maxDD, maxDDPct, curDD, curDDPct;
   double totRet, totRetPct, dayStartEq, dayPnL, dayPnLPct;
   double grossProfit, grossLoss;
   int    wStr, lStr, mxW, mxL, totalTrades, wins, losses;
};

SECPt    g_pts[];
int      g_cnt = 0;
SECSt    g_st;
datetime g_lastUpd = 0;
int      g_lastDeals = 0;
datetime g_currentDay = 0;

//+------------------------------------------------------------------+
//| Init                                                              |
//+------------------------------------------------------------------+
int OnInit()
{
   ArrayResize(g_pts, MAX_PTS);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);

   g_st.initEq = eq; g_st.curEq = eq; g_st.curBal = bal; g_st.hwm = eq;
   g_st.maxDD = 0; g_st.maxDDPct = 0; g_st.curDD = 0; g_st.curDDPct = 0;
   g_st.totRet = 0; g_st.totRetPct = 0;
   g_st.dayStartEq = eq; g_st.dayPnL = 0; g_st.dayPnLPct = 0;
   g_st.grossProfit = 0; g_st.grossLoss = 0;
   g_st.wStr = 0; g_st.lStr = 0; g_st.mxW = 0; g_st.mxL = 0;
   g_st.totalTrades = 0; g_st.wins = 0; g_st.losses = 0;

   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   g_currentDay = StructToTime(dt);

   AddPt(eq, bal);
   HistorySelect(0, TimeCurrent());
   g_lastDeals = HistoryDealsTotal();
   EventSetMillisecondTimer(2000);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int r) { ObjectsDeleteAll(0, PFX); EventKillTimer(); }
void OnTick() { Upd(); }
void OnTimer() { Upd(); }

//+------------------------------------------------------------------+
//| Update                                                            |
//+------------------------------------------------------------------+
void Upd()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   datetime now = TimeCurrent();

   // Day change
   MqlDateTime dt; TimeToStruct(now, dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime today = StructToTime(dt);
   if(today != g_currentDay)
   {
      g_currentDay = today;
      g_st.dayStartEq = eq;
   }

   // Track closed deals
   HistorySelect(0, now);
   int tot = HistoryDealsTotal();
   for(int i = g_lastDeals; i < tot; i++)
   {
      ulong tk = HistoryDealGetTicket(i);
      if(tk == 0) continue;
      long entry = HistoryDealGetInteger(tk, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) continue;
      double p = HistoryDealGetDouble(tk, DEAL_PROFIT) +
                 HistoryDealGetDouble(tk, DEAL_SWAP) +
                 HistoryDealGetDouble(tk, DEAL_COMMISSION);
      g_st.totalTrades++;
      if(p > 0.01)
      {
         g_st.wins++; g_st.grossProfit += p;
         g_st.wStr++; g_st.lStr = 0;
         if(g_st.wStr > g_st.mxW) g_st.mxW = g_st.wStr;
      }
      else if(p < -0.01)
      {
         g_st.losses++; g_st.grossLoss += MathAbs(p);
         g_st.lStr++; g_st.wStr = 0;
         if(g_st.lStr > g_st.mxL) g_st.mxL = g_st.lStr;
      }
   }
   g_lastDeals = tot;

   // Daily P&L
   g_st.dayPnL = eq - g_st.dayStartEq;
   g_st.dayPnLPct = (g_st.dayStartEq > 0) ? g_st.dayPnL / g_st.dayStartEq * 100 : 0;

   // Add point throttled
   if(now - g_lastUpd >= UPD_SEC) { AddPt(eq, bal); g_lastUpd = now; }
   else if(g_cnt > 0) { g_pts[g_cnt-1].eq = eq; g_pts[g_cnt-1].bal = bal; }

   g_st.curEq = eq; g_st.curBal = bal;
   DrawAll();
}

//+------------------------------------------------------------------+
//| Add data point                                                    |
//+------------------------------------------------------------------+
void AddPt(double eq, double bal)
{
   if(g_cnt >= MAX_PTS)
   {
      for(int i = 0; i < MAX_PTS - 1; i++) g_pts[i] = g_pts[i+1];
      g_cnt = MAX_PTS - 1;
   }
   SECPt p; p.t = TimeCurrent(); p.eq = eq; p.bal = bal;
   if(eq > g_st.hwm) g_st.hwm = eq;
   p.dd = g_st.hwm - eq;
   p.ddPct = (g_st.hwm > 0) ? p.dd / g_st.hwm * 100 : 0;
   g_pts[g_cnt] = p; g_cnt++;
   g_st.curDD = p.dd; g_st.curDDPct = p.ddPct;
   if(p.ddPct > g_st.maxDDPct) { g_st.maxDD = p.dd; g_st.maxDDPct = p.ddPct; }
   g_st.totRet = eq - g_st.initEq;
   g_st.totRetPct = (g_st.initEq > 0) ? g_st.totRet / g_st.initEq * 100 : 0;
}

//+------------------------------------------------------------------+
//| Draw everything                                                   |
//+------------------------------------------------------------------+
void DrawAll()
{
   ObjectsDeleteAll(0, PFX);
   if(g_cnt < 2) return;

   int cw = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int ch = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   int px, py;
   switch(InpPosition)
   {
      case 0: px = 10; py = 50; break;
      case 1: px = cw - InpWidth - 10; py = 50; break;
      case 2: px = 10; py = ch - InpHeight - 50; break;
      default: px = cw - InpWidth - 10; py = ch - InpHeight - 50; break;
   }

   // Background
   MkRect(PFX+"bg", px, py, InpWidth, InpHeight, CLR_BG, CLR_BORDER);

   // Header
   MkLbl(PFX+"brand", px+10, py+5, "ALGOSPHERE QUANT", FNT, 7, CLR_SUBTITLE);
   MkLbl(PFX+"tt", px+10, py+17, "EQUITY CURVE v1.2", FNT, 9, CLR_TITLE);
   MkLbl(PFX+"ev", px+InpWidth-10, py+5, "$"+DoubleToString(g_st.curEq, 2), FNT, 10, CLR_WHITE, true);

   // Chart area
   int cx = px + 10, cy = py + 36;
   int cW = InpWidth - 20, cH = InpHeight - 100;

   // Find min/max
   double mn = 999999999, mx = 0;
   for(int i = 0; i < g_cnt; i++)
   {
      if(InpMode != 3)
      {
         if(g_pts[i].eq < mn) mn = g_pts[i].eq; if(g_pts[i].eq > mx) mx = g_pts[i].eq;
         if(g_pts[i].bal < mn) mn = g_pts[i].bal; if(g_pts[i].bal > mx) mx = g_pts[i].bal;
      }
   }
   double rng = mx - mn; if(rng == 0) rng = mx * 0.1;
   mn -= rng * 0.05; mx += rng * 0.05;

   // Grid
   for(int i = 1; i <= 3; i++)
   {
      int gy = cy + cH * i / 4;
      MkRect(PFX+"gh"+IntegerToString(i), cx, gy, cW, 1, CLR_GRID, CLR_GRID);
   }

   if(InpMode != 3)
   {
      // Draw curve lines
      for(int i = 1; i < g_cnt; i++)
      {
         int x1 = cx + (int)((double)(i-1) / (g_cnt-1) * cW);
         int x2 = cx + (int)((double)i / (g_cnt-1) * cW);
         int y1, y2;

         if(InpMode == 0 || InpMode == 2)
         {
            y1 = cy + cH - (int)(((g_pts[i-1].eq - mn) / (mx - mn)) * cH);
            y2 = cy + cH - (int)(((g_pts[i].eq - mn) / (mx - mn)) * cH);
            MkRect(PFX+"eq"+IntegerToString(i), MathMin(x1,x2), MathMin(y1,y2),
                   MathAbs(x2-x1)+1, MathMax(2, MathAbs(y2-y1)+1), CLR_EQ, CLR_EQ);
         }
         if(InpMode == 1 || InpMode == 2)
         {
            y1 = cy + cH - (int)(((g_pts[i-1].bal - mn) / (mx - mn)) * cH);
            y2 = cy + cH - (int)(((g_pts[i].bal - mn) / (mx - mn)) * cH);
            MkRect(PFX+"bl"+IntegerToString(i), MathMin(x1,x2), MathMin(y1,y2),
                   MathAbs(x2-x1)+1, MathMax(1, MathAbs(y2-y1)+1), CLR_BAL, CLR_BAL);
         }
      }

      // HWM line
      int hwmY = cy + cH - (int)(((g_st.hwm - mn) / (mx - mn)) * cH);
      MkRect(PFX+"hwm", cx, hwmY, cW, 1, CLR_HWM, CLR_HWM);

      // Legend
      if(InpMode == 2)
      {
         MkRect(PFX+"leg_eq", px+InpWidth-90, py+17, 8, 8, CLR_EQ, CLR_EQ);
         MkLbl(PFX+"leg_et", px+InpWidth-78, py+17, "Equity", FNT, 7, CLR_EQ);
         MkRect(PFX+"leg_bl", px+InpWidth-90, py+28, 8, 8, CLR_BAL, CLR_BAL);
         MkLbl(PFX+"leg_bt", px+InpWidth-78, py+28, "Balance", FNT, 7, CLR_BAL);
      }
   }
   else
   {
      // Drawdown bars
      double maxDDv = 0;
      for(int i = 0; i < g_cnt; i++) if(g_pts[i].ddPct > maxDDv) maxDDv = g_pts[i].ddPct;
      if(maxDDv == 0) maxDDv = 10; maxDDv *= 1.2;
      int bw = MathMax(1, cW / g_cnt);
      for(int i = 0; i < g_cnt; i++)
      {
         int bx = cx + (int)((double)i / MathMax(1, g_cnt-1) * cW);
         int bh = (int)(g_pts[i].ddPct / maxDDv * cH);
         if(bh < 1) bh = 1;
         MkRect(PFX+"dd"+IntegerToString(i), bx, cy, bw, bh, CLR_DD, CLR_DD);
      }
   }

   // ─── Stats bar ───
   int sy = py + InpHeight - 58;

   // Return
   string retStr = (g_st.totRetPct >= 0 ? "+" : "") + DoubleToString(g_st.totRetPct, 2) + "%";
   color retClr = (g_st.totRetPct >= 0) ? CLR_EQ : CLR_DD;
   MkLbl(PFX+"s_ret_l", px+10, sy, "Return", FNT, 7, CLR_LABEL);
   MkLbl(PFX+"s_ret_v", px+60, sy, retStr, FNT, 7, retClr);

   // Today P&L
   string dayStr = (g_st.dayPnL >= 0 ? "+" : "") + "$" + DoubleToString(g_st.dayPnL, 2);
   color dayClr = (g_st.dayPnL >= 0) ? CLR_EQ : CLR_DD;
   MkLbl(PFX+"s_day_l", px+130, sy, "Today", FNT, 7, CLR_LABEL);
   MkLbl(PFX+"s_day_v", px+170, sy, dayStr, FNT, 7, dayClr);

   // Max DD
   MkLbl(PFX+"s_dd_l", px+280, sy, "MaxDD", FNT, 7, CLR_LABEL);
   MkLbl(PFX+"s_dd_v", px+320, sy, DoubleToString(g_st.maxDDPct, 2) + "%", FNT, 7, CLR_DD);
   sy += 15;

   // Streak
   MkLbl(PFX+"s_str", px+10, sy, "Streak W" + IntegerToString(g_st.wStr) + " L" + IntegerToString(g_st.lStr) +
         " | maxW:" + IntegerToString(g_st.mxW) + " maxL:" + IntegerToString(g_st.mxL), FNT, 7, CLR_WHITE);

   // Profit factor
   double pf = (g_st.grossLoss > 0) ? g_st.grossProfit / g_st.grossLoss : 0;
   color pfClr = (pf >= 1.5) ? CLR_EQ : (pf >= 1.0 ? CLR_HWM : CLR_DD);
   MkLbl(PFX+"s_pf", px+280, sy, "PF:" + DoubleToString(pf, 2), FNT, 7, pfClr);
   sy += 15;

   // Trades
   MkLbl(PFX+"s_trades", px+10, sy, "Trades:" + IntegerToString(g_st.totalTrades) +
         " W:" + IntegerToString(g_st.wins) + " L:" + IntegerToString(g_st.losses), FNT, 7, CLR_SUBTITLE);

   // Current DD
   MkLbl(PFX+"s_cdd", px+280, sy, "DD:" + DoubleToString(g_st.curDDPct, 2) + "%", FNT, 7,
         (g_st.curDDPct > 0) ? CLR_DD : CLR_SUBTITLE);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Drawing helpers                                                   |
//+------------------------------------------------------------------+
void MkRect(string n, int x, int y, int w, int h, color bg, color bd)
{
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w); ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg); ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,bd);
   ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_BACK,true);
}

void MkLbl(string n, int x, int y, string t, string font, int sz, color c, bool rightAlign = false)
{
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,n,OBJPROP_TEXT,t); ObjectSetString(0,n,OBJPROP_FONT,font);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,sz); ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_ANCHOR,rightAlign ? ANCHOR_RIGHT_UPPER : ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
}
//+------------------------------------------------------------------+
