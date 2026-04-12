//+------------------------------------------------------------------+
//|                                   ASQ_RecoveryEngine_Demo.mq5    |
//|                        Copyright 2026, AlgoSphere Quant          |
//|                        https://www.mql5.com/en/users/robin2.0    |
//+------------------------------------------------------------------+
//| ASQ Recovery Engine v1.2 — Demo Expert Advisor                   |
//|                                                                   |
//| Full visual showcase of the ASQ Recovery Engine:                  |
//| • Recovery state with risk multiplier bar                         |
//| • Emotional state indicator (Calm/Focused/Tilted/Reckless)        |
//| • Heat score gauge (0-100 session stress)                         |
//| • Revenge trading guard with block counter                        |
//| • Martingale guard indicator                                      |
//| • Trade log (last 10 results as W/L dots)                         |
//| • Cooling timer with countdown                                    |
//| • Session stats and recommendations                               |
//|                                                                   |
//| Automatically detects closed trades from account history.         |
//| Does NOT place trades — monitors and advises only.               |
//|                                                                   |
//| AlgoSphere Quant — Precision before profit.                      |
//| https://www.mql5.com/en/users/robin2.0                           |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, AlgoSphere Quant"
#property link        "https://www.mql5.com/en/users/robin2.0"
#property version     "1.20"
#property description "ASQ Recovery Engine v1.2 — Anti-tilt risk management with revenge guard, heat scoring, emotional state tracking, and martingale protection."
#property description " "
#property description "Automatically tracks closed trades and adjusts risk. Dashboard shows state, heat, emotion, trade log, and recommendations."
#property description " "
#property description "Free and open-source by AlgoSphere Quant."

#include "ASQ_RecoveryEngine.mqh"

//+------------------------------------------------------------------+
//| INPUTS                                                            |
//+------------------------------------------------------------------+
input group "═══ Recovery Settings ═══"
input ENUM_ASQ_RECOVERY_MODE InpMode  = ASQ_RECOVERY_MODERATE;  // Recovery Mode
input double  InpBaseRisk    = 1.0;    // Base Risk %
input double  InpBaseLot     = 0.01;   // Base Lot Size

input group "═══ Protection ═══"
input bool    InpUseCooling  = true;   // Use Cooling Period
input int     InpCoolMinutes = 30;     // Cooling Minutes
input double  InpCoolThresh  = 2.0;    // Big Loss Threshold %
input bool    InpRevengeGuard = true;  // Revenge Trading Guard
input int     InpRevengeSec  = 120;    // Revenge Guard Seconds
input bool    InpMartGuard   = true;   // Martingale Guard
input bool    InpAutoConsv   = true;   // Auto-Switch Conservative on DD
input double  InpAutoConsvDD = 5.0;    // Auto-Conservative DD Threshold %

input group "═══ Streak Bonus ═══"
input bool    InpUseStreak   = false;  // Enable Win Streak Bonus
input int     InpStreakThresh = 3;     // Streak Threshold (wins)
input double  InpStreakBonus  = 1.25;  // Streak Multiplier

input group "═══ Dashboard ═══"
input int     InpDashX       = 20;     // Dashboard X
input int     InpDashY       = 30;     // Dashboard Y
input bool    InpVerbose     = false;  // Verbose Logging

//+------------------------------------------------------------------+
//| CONSTANTS                                                         |
//+------------------------------------------------------------------+
#define PFX          "ASQ_RE_"
#define FONT_TITLE   "Segoe UI Semibold"
#define FONT_BODY    "Consolas"

#define C_BG         C'18,18,28'
#define C_BORDER     C'45,45,65'
#define C_ACCENT     C'50,50,75'
#define C_TITLE      C'200,200,240'
#define C_SUBTITLE   C'120,120,155'
#define C_LABEL      C'100,100,135'
#define C_VALUE      C'200,200,215'
#define C_SAFE       C'0,220,110'
#define C_WARN       C'255,180,0'
#define C_DANGER     C'220,50,50'
#define C_BLUE       C'80,160,255'
#define C_OFF        C'80,80,100'
#define C_MUTED      C'60,60,80'

#define BAR_W        120
#define BAR_H        6

//+------------------------------------------------------------------+
//| GLOBALS                                                           |
//+------------------------------------------------------------------+
CASQRecoveryEngine g_rec;
int                g_lastDealsTotal = 0;

//+------------------------------------------------------------------+
//| Init                                                              |
//+------------------------------------------------------------------+
int OnInit()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal <= 0) bal = 10000;

   if(!g_rec.Initialize(InpBaseRisk, InpBaseLot, bal))
      return INIT_FAILED;

   g_rec.SetMode(InpMode);
   g_rec.SetCoolingPeriod(InpUseCooling, InpCoolMinutes, InpCoolThresh);
   g_rec.SetStreakBonus(InpUseStreak, InpStreakThresh, InpStreakBonus, 1.5);
   g_rec.SetRevengeGuard(InpRevengeGuard, InpRevengeSec);
   g_rec.SetMartingaleGuard(InpMartGuard);
   g_rec.SetAutoConservative(InpAutoConsv, InpAutoConsvDD);
   g_rec.SetVerbose(InpVerbose);

   HistorySelect(0, TimeCurrent());
   g_lastDealsTotal = HistoryDealsTotal();

   EventSetMillisecondTimer(500);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, PFX);
   EventKillTimer();
}

void OnTick()
{
   g_rec.Update();
   CheckNewDeals();
   DrawDashboard();
}

void OnTimer()
{
   g_rec.Update();
   DrawDashboard();
}

//+------------------------------------------------------------------+
//| Check for new closed deals                                        |
//+------------------------------------------------------------------+
void CheckNewDeals()
{
   HistorySelect(0, TimeCurrent());
   int total = HistoryDealsTotal();
   if(total <= g_lastDealsTotal) { g_lastDealsTotal = total; return; }

   for(int i = g_lastDealsTotal; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) continue;

      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                      HistoryDealGetDouble(ticket, DEAL_SWAP) +
                      HistoryDealGetDouble(ticket, DEAL_COMMISSION);

      if(profit > 0.01) g_rec.OnTradeWin(profit, 0);
      else if(profit < -0.01) g_rec.OnTradeLoss(profit, 0);
      else g_rec.OnTradeBreakEven();
   }
   g_lastDealsTotal = total;
}

//+------------------------------------------------------------------+
//| Dashboard                                                         |
//+------------------------------------------------------------------+
void DrawDashboard()
{
   SASQRecoveryStatus st = g_rec.GetStatus();
   int x = InpDashX, y = InpDashY, w = 270;
   int rowH = 18, section = 6, pad = 10;
   int h = 500;

   CreateRect(PFX + "bg", x, y, w, h, C_BG, C_BORDER);
   int cy = y + pad;

   // ─── Header ───
   CreateLabel(PFX + "brand", x + pad, cy, "ALGOSPHERE QUANT", FONT_TITLE, 7, C_SUBTITLE);
   cy += 14;
   CreateLabel(PFX + "title", x + pad, cy, "RECOVERY ENGINE v1.2", FONT_TITLE, 10, C_TITLE);
   cy += 18;
   CreateRect(PFX + "sep1", x + pad, cy, w - pad * 2, 1, C_ACCENT, C_ACCENT);
   cy += section;

   // ─── State & Emotion ───
   string stateStr = g_rec.StateToString(st.state);
   color stateClr = C_SAFE;
   switch(st.state)
   {
      case ASQ_STATE_CAUTION:    stateClr = C_WARN;   break;
      case ASQ_STATE_DEFENSIVE:  stateClr = C_DANGER;  break;
      case ASQ_STATE_COOLING:    stateClr = C_DANGER;  break;
      case ASQ_STATE_RECOVERING: stateClr = C_BLUE;   break;
      case ASQ_STATE_STREAK:     stateClr = C_SAFE;   break;
      default: stateClr = C_SAFE; break;
   }
   CreateLabel(PFX + "st_lbl", x + pad, cy, "State", FONT_BODY, 8, C_LABEL);
   CreateLabel(PFX + "st_val", x + w - pad, cy, stateStr, FONT_BODY, 9, stateClr, true);
   cy += rowH;

   string emotionStr = g_rec.EmotionToString(st.emotion);
   color emotionClr = C_SAFE;
   switch(st.emotion)
   {
      case ASQ_EMOTION_FOCUSED:  emotionClr = C_BLUE;   break;
      case ASQ_EMOTION_STRESSED: emotionClr = C_WARN;   break;
      case ASQ_EMOTION_TILTED:   emotionClr = C_WARN;   break;
      case ASQ_EMOTION_RECKLESS: emotionClr = C_DANGER;  break;
      default: emotionClr = C_SAFE; break;
   }
   CreateLabel(PFX + "em_lbl", x + pad, cy, "Emotion", FONT_BODY, 8, C_LABEL);
   CreateLabel(PFX + "em_val", x + w - pad, cy, emotionStr, FONT_BODY, 9, emotionClr, true);
   cy += rowH;

   // Heat score bar
   CreateLabel(PFX + "ht_lbl", x + pad, cy, "Heat", FONT_BODY, 8, C_LABEL);
   CreateLabel(PFX + "ht_val", x + w - pad, cy, IntegerToString(st.heatScore) + "/100", FONT_BODY, 8, C_VALUE, true);
   cy += 14;
   int heatFill = (int)(BAR_W * MathMin(100, st.heatScore) / 100);
   if(heatFill < 1) heatFill = 1;
   color heatClr = (st.heatScore < 30) ? C_SAFE : (st.heatScore < 60) ? C_WARN : C_DANGER;
   CreateRect(PFX + "ht_bg", x + pad, cy, BAR_W, BAR_H, C_MUTED, C_MUTED);
   CreateRect(PFX + "ht_fill", x + pad, cy, heatFill, BAR_H, heatClr, heatClr);
   cy += BAR_H + section + 2;

   CreateRect(PFX + "sep2", x + pad, cy, w - pad * 2, 1, C_ACCENT, C_ACCENT);
   cy += section;

   // ─── Risk Multiplier ───
   string multStr = DoubleToString(st.riskMultiplier * 100, 0) + "%";
   color multClr = (st.riskMultiplier >= 1.0) ? C_SAFE : (st.riskMultiplier >= 0.5 ? C_WARN : C_DANGER);
   CreateLabel(PFX + "rm_lbl", x + pad, cy, "Risk Mult", FONT_BODY, 8, C_LABEL);
   CreateLabel(PFX + "rm_val", x + w - pad, cy, multStr, FONT_BODY, 9, multClr, true);
   cy += rowH;

   CreateLabel(PFX + "ar_lbl", x + pad, cy, "Adj Risk", FONT_BODY, 8, C_LABEL);
   CreateLabel(PFX + "ar_val", x + w - pad, cy, DoubleToString(g_rec.GetAdjustedRisk(), 2) + "%", FONT_BODY, 8, C_VALUE, true);
   cy += rowH;

   CreateLabel(PFX + "al_lbl", x + pad, cy, "Adj Lot", FONT_BODY, 8, C_LABEL);
   CreateLabel(PFX + "al_val", x + w - pad, cy, DoubleToString(g_rec.GetAdjustedLot(), 3), FONT_BODY, 8, C_VALUE, true);
   cy += rowH + section;

   CreateRect(PFX + "sep3", x + pad, cy, w - pad * 2, 1, C_ACCENT, C_ACCENT);
   cy += section;

   // ─── Streaks ───
   color lClr = (st.consecutiveLosses == 0) ? C_SAFE : (st.consecutiveLosses < 3 ? C_WARN : C_DANGER);
   CreateLabel(PFX + "cl_lbl", x + pad, cy, "Consec L", FONT_BODY, 8, C_LABEL);
   CreateLabel(PFX + "cl_val", x + w - pad, cy, IntegerToString(st.consecutiveLosses) + " (max " + IntegerToString(st.maxConsecLosses) + ")", FONT_BODY, 8, lClr, true);
   cy += rowH;

   color wClr = (st.consecutiveWins > 0) ? C_SAFE : C_OFF;
   CreateLabel(PFX + "cw_lbl", x + pad, cy, "Consec W", FONT_BODY, 8, C_LABEL);
   CreateLabel(PFX + "cw_val", x + w - pad, cy, IntegerToString(st.consecutiveWins) + " (max " + IntegerToString(st.maxConsecWins) + ")", FONT_BODY, 8, wClr, true);
   cy += rowH;

   // Session P/L
   color plClr = (st.sessionProfit >= 0) ? C_SAFE : C_DANGER;
   CreateLabel(PFX + "sp_lbl", x + pad, cy, "Session", FONT_BODY, 8, C_LABEL);
   CreateLabel(PFX + "sp_val", x + w - pad, cy, "W" + IntegerToString(st.sessionWins) + "/L" + IntegerToString(st.sessionLosses) + " $" + DoubleToString(st.sessionProfit, 2), FONT_BODY, 8, plClr, true);
   cy += rowH;

   // ─── Trade Log (W/L dots) ───
   CreateLabel(PFX + "tl_lbl", x + pad, cy, "Last " + IntegerToString(st.tradeLogCount), FONT_BODY, 8, C_LABEL);
   string dots = "";
   for(int i = 0; i < st.tradeLogCount && i < ASQ_REC_TRADE_LOG_SIZE; i++)
      dots += st.tradeLog[i].win ? "W " : "L ";
   if(dots == "") dots = "---";
   CreateLabel(PFX + "tl_val", x + w - pad, cy, dots, FONT_BODY, 8, C_VALUE, true);
   cy += rowH + section;

   CreateRect(PFX + "sep4", x + pad, cy, w - pad * 2, 1, C_ACCENT, C_ACCENT);
   cy += section;

   // ─── Guards ───
   // Cooling
   if(st.inCooling)
   {
      CreateLabel(PFX + "co_lbl", x + pad, cy, "Cooling", FONT_BODY, 8, C_LABEL);
      CreateLabel(PFX + "co_val", x + w - pad, cy, IntegerToString(g_rec.GetCoolingRemainingMinutes()) + "m left", FONT_BODY, 8, C_DANGER, true);
   }
   else
   {
      CreateLabel(PFX + "co_lbl", x + pad, cy, "Cooling", FONT_BODY, 8, C_LABEL);
      CreateLabel(PFX + "co_val", x + w - pad, cy, "Off (" + IntegerToString(st.coolingsToday) + " today)", FONT_BODY, 8, C_OFF, true);
   }
   cy += rowH;

   // Revenge guard
   string revStr = st.revengeTradeBlocked ? "BLOCKED" : "Clear";
   color revClr = st.revengeTradeBlocked ? C_DANGER : C_SAFE;
   if(st.revengeBlocksToday > 0) revStr += " (" + IntegerToString(st.revengeBlocksToday) + " today)";
   CreateLabel(PFX + "rv_lbl", x + pad, cy, "Revenge", FONT_BODY, 8, C_LABEL);
   CreateLabel(PFX + "rv_val", x + w - pad, cy, revStr, FONT_BODY, 8, revClr, true);
   cy += rowH;

   // Martingale
   string mrgStr = st.martingaleBlocked ? "BLOCKED" : "Clear";
   color mrgClr = st.martingaleBlocked ? C_DANGER : C_SAFE;
   CreateLabel(PFX + "mg_lbl", x + pad, cy, "Martingale", FONT_BODY, 8, C_LABEL);
   CreateLabel(PFX + "mg_val", x + w - pad, cy, mrgStr, FONT_BODY, 8, mrgClr, true);
   cy += rowH;

   // Trading
   bool allowed = g_rec.IsTradingAllowed();
   CreateLabel(PFX + "ta_lbl", x + pad, cy, "Trading", FONT_BODY, 8, C_LABEL);
   CreateLabel(PFX + "ta_val", x + w - pad, cy, allowed ? "ALLOWED" : "BLOCKED", FONT_BODY, 9, allowed ? C_SAFE : C_DANGER, true);
   cy += rowH + section;

   CreateRect(PFX + "sep5", x + pad, cy, w - pad * 2, 1, C_ACCENT, C_ACCENT);
   cy += section;

   // ─── Recommendation ───
   string rec = st.recommendation;
   if(rec == "") rec = "All clear";
   color recClr = C_SUBTITLE;
   if(st.emotion >= ASQ_EMOTION_TILTED) recClr = C_WARN;
   if(st.emotion >= ASQ_EMOTION_RECKLESS) recClr = C_DANGER;
   CreateLabel(PFX + "rc_val", x + pad, cy, rec, FONT_BODY, 7, recClr);
   cy += rowH;

   // Resize
   cy += pad;
   int finalH = cy - InpDashY;
   ObjectSetInteger(0, PFX + "bg", OBJPROP_YSIZE, finalH);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Drawing helpers                                                   |
//+------------------------------------------------------------------+
void CreateRect(string name, int x, int y, int w, int h, color bg, color bd)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w); ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg); ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, bd);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER); ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void CreateLabel(string name, int x, int y, string text, string font, int sz, color clr, bool rightAlign = false)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text); ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, sz); ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, rightAlign ? ANCHOR_RIGHT_UPPER : ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}
//+------------------------------------------------------------------+
