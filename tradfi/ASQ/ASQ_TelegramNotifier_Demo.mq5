//+------------------------------------------------------------------+
//|                                 ASQ_TelegramNotifier_Demo.mq5    |
//|                        Copyright 2026, AlgoSphere Quant          |
//|                        https://www.mql5.com/en/users/robin2.0    |
//+------------------------------------------------------------------+
//| ASQ Telegram Notifier v1.2 — Demo Expert Advisor                 |
//|                                                                   |
//| Full showcase: sends test on init, monitors closed trades,        |
//| sends startup/shutdown messages, and displays connection          |
//| health, message stats, and queue status on chart.                 |
//|                                                                   |
//| SETUP: Enter Bot Token + Chat ID. Add api.telegram.org to MT5.   |
//|                                                                   |
//| AlgoSphere Quant — Precision before profit.                      |
//| https://www.mql5.com/en/users/robin2.0                           |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, AlgoSphere Quant"
#property link        "https://www.mql5.com/en/users/robin2.0"
#property version     "1.20"
#property description "ASQ Telegram Notifier v1.2 — Trade alerts, daily/weekly summaries, multi-chat, silent hours, message queue with retry."
#property description " "
#property description "SETUP: 1) Create bot via @BotFather  2) Get Chat ID via @userinfobot  3) Add https://api.telegram.org to MT5 allowed URLs"
#property description " "
#property description "Free and open-source by AlgoSphere Quant."

#include "ASQ_TelegramNotifier.mqh"

//+------------------------------------------------------------------+
//| INPUTS                                                            |
//+------------------------------------------------------------------+
input group "═══ Telegram Credentials ═══"
input string InpBotToken     = "";            // Bot Token (from @BotFather)
input string InpChatId       = "";            // Chat ID (from @userinfobot)
input string InpChatId2      = "";            // 2nd Chat ID (optional)

input group "═══ Notifications ═══"
input string InpEAName       = "ASQ Demo EA"; // EA Name in messages
input bool   InpNotifyOpen   = true;          // Notify Trade Open
input bool   InpNotifyClose  = true;          // Notify Trade Close
input bool   InpNotifyDaily  = true;          // Notify Daily Summary
input bool   InpNotifyErrors = true;          // Notify Errors
input bool   InpNotifyStart  = true;          // Notify EA Start/Stop
input bool   InpUseEmoji     = true;          // Use Tag Labels

input group "═══ Silent Hours (GMT) ═══"
input bool   InpSilentHours  = false;         // Enable Silent Hours
input int    InpSilentStart  = 22;            // Silent Start (GMT hour)
input int    InpSilentEnd    = 6;             // Silent End (GMT hour)

input group "═══ Test ═══"
input bool   InpSendTest     = true;          // Send Test Message on Init
input bool   InpVerifyConn   = true;          // Verify Connection on Init

//+------------------------------------------------------------------+
//| CONSTANTS                                                         |
//+------------------------------------------------------------------+
#define PFX          "ASQ_TG_"
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
#define C_DANGER     C'220,50,50'
#define C_WARN       C'255,180,0'
#define C_OFF        C'80,80,100'

CASQTelegramNotifier g_tg;
int                  g_lastDeals = 0;
double               g_sessionProfit = 0;
int                  g_sessionTrades = 0;

//+------------------------------------------------------------------+
//| Init                                                              |
//+------------------------------------------------------------------+
int OnInit()
{
   if(InpBotToken != "" && InpChatId != "")
   {
      g_tg.Initialize(InpBotToken, InpChatId, _Symbol);
      if(InpChatId2 != "") g_tg.AddChatId(InpChatId2);

      g_tg.SetEAName(InpEAName);
      g_tg.EnableTradeOpen(InpNotifyOpen);
      g_tg.EnableTradeClose(InpNotifyClose);
      g_tg.EnableDailySummary(InpNotifyDaily);
      g_tg.EnableErrors(InpNotifyErrors);
      g_tg.EnableEmoji(InpUseEmoji);
      g_tg.EnableStartupShutdown(InpNotifyStart, InpNotifyStart);
      g_tg.SetSilentHours(InpSilentHours, InpSilentStart, InpSilentEnd);

      if(InpVerifyConn) g_tg.VerifyConnection();
      if(InpSendTest) g_tg.SendTestMessage();
      if(InpNotifyStart) g_tg.SendStartup();
   }
   else
   {
      Print("[ASQ TG Demo] Bot Token and Chat ID required!");
   }

   HistorySelect(0, TimeCurrent());
   g_lastDeals = HistoryDealsTotal();
   EventSetMillisecondTimer(2000);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_tg.IsEnabled()) g_tg.SendShutdown(g_sessionProfit, g_sessionTrades);
   ObjectsDeleteAll(0, PFX);
   EventKillTimer();
}

void OnTick()
{
   g_tg.Update();
   CheckNewDeals();
   DrawStatus();
}

void OnTimer()
{
   g_tg.Update();
   DrawStatus();
}

//+------------------------------------------------------------------+
//| Check for closed deals                                            |
//+------------------------------------------------------------------+
void CheckNewDeals()
{
   if(!g_tg.IsEnabled()) return;
   HistorySelect(0, TimeCurrent());
   int total = HistoryDealsTotal();
   if(total <= g_lastDeals) { g_lastDeals = total; return; }

   for(int i = g_lastDeals; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) continue;

      string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
      long dealType = HistoryDealGetInteger(ticket, DEAL_TYPE);
      double lot = HistoryDealGetDouble(ticket, DEAL_VOLUME);
      double price = HistoryDealGetDouble(ticket, DEAL_PRICE);
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                      HistoryDealGetDouble(ticket, DEAL_SWAP) +
                      HistoryDealGetDouble(ticket, DEAL_COMMISSION);

      string dir = (dealType == DEAL_TYPE_BUY) ? "SELL" : "BUY";
      g_tg.SendTradeClose(symbol, dir, lot, 0, price, profit, 0, "Closed");
      g_sessionProfit += profit;
      g_sessionTrades++;
   }
   g_lastDeals = total;
}

//+------------------------------------------------------------------+
//| Dashboard                                                         |
//+------------------------------------------------------------------+
void DrawStatus()
{
   int x = 20, y = 30, w = 270;
   int rowH = 18, section = 6, pad = 10;
   int h = 300;

   CreateRect(PFX + "bg", x, y, w, h, C_BG, C_BORDER);
   int cy = y + pad;

   CreateLabel(PFX + "brand", x + pad, cy, "ALGOSPHERE QUANT", FONT_TITLE, 7, C_SUBTITLE);
   cy += 14;
   CreateLabel(PFX + "title", x + pad, cy, "TELEGRAM v1.2", FONT_TITLE, 10, C_TITLE);
   cy += 18;
   CreateRect(PFX + "sep1", x + pad, cy, w - pad * 2, 1, C_ACCENT, C_ACCENT);
   cy += section;

   // Connection
   bool connected = g_tg.IsEnabled();
   bool verified = g_tg.IsConnectionVerified();
   string connStr = !connected ? "NOT CONFIGURED" : (verified ? "VERIFIED" : "CONNECTED");
   color connClr = !connected ? C_DANGER : (verified ? C_SAFE : C_WARN);
   CreateLabel(PFX + "cn_lbl", x + pad, cy, "Connection", FONT_BODY, 8, C_LABEL);
   CreateLabel(PFX + "cn_val", x + w - pad, cy, connStr, FONT_BODY, 8, connClr, true);
   cy += rowH;

   // Chats
   CreateLabel(PFX + "ch_lbl", x + pad, cy, "Chat IDs", FONT_BODY, 8, C_LABEL);
   CreateLabel(PFX + "ch_val", x + w - pad, cy, IntegerToString(g_tg.GetChatCount()), FONT_BODY, 8, C_VALUE, true);
   cy += rowH;

   // Sent today
   CreateLabel(PFX + "st_lbl", x + pad, cy, "Sent today", FONT_BODY, 8, C_LABEL);
   CreateLabel(PFX + "st_val", x + w - pad, cy, IntegerToString(g_tg.GetDailySendCount()), FONT_BODY, 8, C_VALUE, true);
   cy += rowH;

   // Errors today
   int dailyErr = g_tg.GetDailyErrorCount();
   CreateLabel(PFX + "er_lbl", x + pad, cy, "Errors today", FONT_BODY, 8, C_LABEL);
   CreateLabel(PFX + "er_val", x + w - pad, cy, IntegerToString(dailyErr), FONT_BODY, 8, (dailyErr == 0) ? C_SAFE : C_DANGER, true);
   cy += rowH;

   // Queue
   int qSize = g_tg.GetQueueSize();
   CreateLabel(PFX + "qu_lbl", x + pad, cy, "Queue", FONT_BODY, 8, C_LABEL);
   CreateLabel(PFX + "qu_val", x + w - pad, cy, IntegerToString(qSize) + " pending", FONT_BODY, 8, (qSize == 0) ? C_OFF : C_WARN, true);
   cy += rowH;

   // Total stats
   CreateLabel(PFX + "ts_lbl", x + pad, cy, "Total sent", FONT_BODY, 8, C_LABEL);
   CreateLabel(PFX + "ts_val", x + w - pad, cy, IntegerToString(g_tg.GetSendCount()), FONT_BODY, 8, C_VALUE, true);
   cy += rowH;

   // Last error
   string lastErr = g_tg.GetLastError();
   if(lastErr == "") lastErr = "None";
   if(StringLen(lastErr) > 28) lastErr = StringSubstr(lastErr, 0, 28) + "..";
   CreateLabel(PFX + "le_lbl", x + pad, cy, "Last error", FONT_BODY, 8, C_LABEL);
   CreateLabel(PFX + "le_val", x + pad, cy + 14, lastErr, FONT_BODY, 7, C_SUBTITLE);
   cy += rowH + 14;

   // Resize
   cy += pad;
   ObjectSetInteger(0, PFX + "bg", OBJPROP_YSIZE, cy - 30);
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
