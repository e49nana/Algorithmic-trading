//+------------------------------------------------------------------+
//|                                       ASQ_NewsFilter_Demo.mq5    |
//|                        Copyright 2026, AlgoSphere Quant          |
//|                        https://www.mql5.com/en/users/robin2.0    |
//+------------------------------------------------------------------+
//| ASQ News Filter v1.2 — Demo Expert Advisor                       |
//|                                                                   |
//| Full visual showcase of the ASQ News Filter library:              |
//| • On-chart news dashboard with upcoming events list               |
//| • Trading allowed / blocked status with intensity meter           |
//| • Countdown timer to next high-impact event                       |
//| • Pre-news and post-news window indicators with cooldowns         |
//| • Next 3 upcoming events with impact color coding                 |
//| • News intensity gauge (Calm/Caution/Danger/Blackout)             |
//| • MQL5 Calendar API live integration                              |
//|                                                                   |
//| USAGE: Attach to any forex chart. Does NOT place trades.          |
//|                                                                   |
//| This is the open-source news engine behind Quant Cristina         |
//| on the MQL5 Market. Same logic, same accuracy.                    |
//|                                                                   |
//| AlgoSphere Quant — Precision before profit.                      |
//| https://www.mql5.com/en/users/robin2.0                           |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, AlgoSphere Quant"
#property link        "https://www.mql5.com/en/users/robin2.0"
#property version     "1.20"
#property description "ASQ News Filter v1.2 — Economic calendar trading guard with MQL5 Calendar API, special event cooldowns, and intensity scoring."
#property description " "
#property description "Live news dashboard with next 3 events, countdown timer, intensity meter, and trading status."
#property description " "
#property description "Free and open-source by AlgoSphere Quant."

#include "ASQ_NewsFilter.mqh"

//+------------------------------------------------------------------+
//| INPUTS                                                            |
//+------------------------------------------------------------------+
input group "═══ News Filter Settings ═══"
input ENUM_ASQ_NEWS_MODE InpMode          = ASQ_NEWS_HIGH_ONLY; // Filter Mode
input int                InpPreMinutes    = 30;                  // Pre-News Pause (minutes)
input int                InpPostMinutes   = 30;                  // Post-News Pause (minutes)
input bool               InpSpecialCool   = true;               // Special Cooldowns (NFP=60m, FOMC=90m)
input bool               InpUseMQL5Cal    = true;               // Use MQL5 Calendar API (live events)

input group "═══ Event Filters ═══"
input bool               InpFilterNFP     = true;               // Filter NFP
input bool               InpFilterFOMC    = true;               // Filter FOMC
input bool               InpFilterECB     = true;               // Filter ECB
input bool               InpFilterAll     = false;              // Filter All Currencies

input group "═══ Dashboard ═══"
input bool               InpShowDashboard = true;               // Show Dashboard
input int                InpDashX         = 20;                  // Dashboard X
input int                InpDashY         = 30;                  // Dashboard Y
input bool               InpVerbose       = false;              // Verbose Logging

//+------------------------------------------------------------------+
//| CONSTANTS                                                         |
//+------------------------------------------------------------------+
#define PREFIX          "ASQ_NF_"
#define FONT_TITLE      "Segoe UI Semibold"
#define FONT_BODY       "Consolas"

#define CLR_BG          C'18,18,28'
#define CLR_BG2         C'24,24,38'
#define CLR_BORDER      C'45,45,65'
#define CLR_ACCENT      C'50,50,75'
#define CLR_TITLE       C'200,200,240'
#define CLR_SUBTITLE    C'120,120,155'
#define CLR_LABEL       C'100,100,135'
#define CLR_VALUE       C'200,200,215'
#define CLR_SAFE        C'0,220,110'
#define CLR_DANGER      C'220,50,50'
#define CLR_WARNING     C'255,180,0'
#define CLR_OFF         C'80,80,100'
#define CLR_MUTED       C'60,60,80'

#define CLR_HIGH        C'220,50,50'
#define CLR_MEDIUM      C'255,160,0'
#define CLR_LOW         C'60,140,180'

#define CLR_CALM        C'0,200,100'
#define CLR_CAUTION     C'255,180,0'
#define CLR_BLACKOUT    C'220,40,40'

//+------------------------------------------------------------------+
//| GLOBALS                                                           |
//+------------------------------------------------------------------+
CASQNewsFilter g_news;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!g_news.Initialize(_Symbol))
   {
      Print("[ASQ News Demo] Failed to initialize");
      return INIT_FAILED;
   }

   g_news.SetMode(InpMode);
   g_news.SetPreNewsMinutes(InpPreMinutes);
   g_news.SetPostNewsMinutes(InpPostMinutes);
   g_news.SetFilterNFP(InpFilterNFP);
   g_news.SetFilterFOMC(InpFilterFOMC);
   g_news.SetFilterECB(InpFilterECB);
   g_news.SetFilterAll(InpFilterAll);
   g_news.SetSpecialCooldowns(InpSpecialCool);
   g_news.SetUseMQL5Calendar(InpUseMQL5Cal);
   g_news.SetVerbose(InpVerbose);

   EventSetMillisecondTimer(500);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                            |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, PREFIX);
   EventKillTimer();
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   g_news.Update();
   if(InpShowDashboard)
      UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Timer                                                              |
//+------------------------------------------------------------------+
void OnTimer()
{
   g_news.Update();
   if(InpShowDashboard)
      UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Update dashboard                                                  |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   SASQNewsStatus st = g_news.GetStatus();
   int x = InpDashX;
   int y = InpDashY;
   int w = 280;
   int rowH = 18;
   int section = 6;
   int pad = 10;

   // Estimate height
   int h = 400;
   CreateRect(PREFIX + "bg", x, y, w, h, CLR_BG, CLR_BORDER);

   int cy = y + pad;

   // ─── Header ───
   CreateLabel(PREFIX + "brand", x + pad, cy, "ALGOSPHERE QUANT", FONT_TITLE, 7, CLR_SUBTITLE);
   cy += 14;
   CreateLabel(PREFIX + "title", x + pad, cy, "NEWS FILTER v1.2", FONT_TITLE, 10, CLR_TITLE);
   cy += 18;
   CreateRect(PREFIX + "sep1", x + pad, cy, w - pad * 2, 1, CLR_ACCENT, CLR_ACCENT);
   cy += section;

   // ─── Trading Status ───
   string tradeText = st.tradingAllowed ? "ALLOWED" : "BLOCKED";
   color tradeClr = st.tradingAllowed ? CLR_SAFE : CLR_DANGER;
   CreateLabel(PREFIX + "st_lbl", x + pad, cy, "Trading", FONT_BODY, 8, CLR_LABEL);
   CreateLabel(PREFIX + "st_val", x + w - pad, cy, tradeText, FONT_BODY, 9, tradeClr, true);
   cy += rowH;

   // Intensity
   ENUM_ASQ_NEWS_INTENSITY intensity = st.intensity;
   string intText = g_news.IntensityToString(intensity);
   color intClr = CLR_CALM;
   switch(intensity)
   {
      case ASQ_INTENSITY_CAUTION:  intClr = CLR_CAUTION;  break;
      case ASQ_INTENSITY_DANGER:   intClr = CLR_WARNING;  break;
      case ASQ_INTENSITY_BLACKOUT: intClr = CLR_BLACKOUT; break;
      default: intClr = CLR_CALM; break;
   }
   CreateLabel(PREFIX + "in_lbl", x + pad, cy, "Intensity", FONT_BODY, 8, CLR_LABEL);
   CreateLabel(PREFIX + "in_val", x + w - pad, cy, intText, FONT_BODY, 9, intClr, true);
   cy += rowH;

   // News window
   string windowText = "None";
   color windowClr = CLR_OFF;
   if(st.inPreNewsWindow) { windowText = "PRE-NEWS"; windowClr = CLR_WARNING; }
   else if(st.inPostNewsWindow) { windowText = "POST-NEWS"; windowClr = CLR_WARNING; }
   CreateLabel(PREFIX + "wn_lbl", x + pad, cy, "Window", FONT_BODY, 8, CLR_LABEL);
   CreateLabel(PREFIX + "wn_val", x + w - pad, cy, windowText, FONT_BODY, 8, windowClr, true);
   cy += rowH;

   // Active cooldowns
   if(st.inPostNewsWindow && st.activePostMin > 0)
   {
      string coolStr = IntegerToString(st.activePostMin) + "m cooldown";
      CreateLabel(PREFIX + "cd_info", x + w - pad, cy, coolStr, FONT_BODY, 7, CLR_MUTED, true);
      cy += 14;
   }
   else
   {
      ObjectDelete(0, PREFIX + "cd_info");
   }

   cy += section;
   CreateRect(PREFIX + "sep2", x + pad, cy, w - pad * 2, 1, CLR_ACCENT, CLR_ACCENT);
   cy += section;

   // ─── Next Event ───
   string nextTitle = "None";
   color nextClr = CLR_OFF;
   if(st.minutesToNext < 9999)
   {
      nextTitle = st.nextEvent.title;
      if(StringLen(nextTitle) > 25) nextTitle = StringSubstr(nextTitle, 0, 25) + "..";
      nextClr = CLR_VALUE;
   }
   CreateLabel(PREFIX + "ne_lbl", x + pad, cy, "Next Event", FONT_BODY, 8, CLR_LABEL);
   cy += rowH;
   CreateLabel(PREFIX + "ne_val", x + pad + 4, cy, nextTitle, FONT_BODY, 8, nextClr);
   cy += rowH;

   // Countdown
   string cdText = "---";
   color cdClr = CLR_OFF;
   if(st.minutesToNext < 9999)
   {
      if(st.minutesToNext >= 60)
         cdText = IntegerToString(st.minutesToNext / 60) + "h " + IntegerToString(st.minutesToNext % 60) + "m";
      else
         cdText = IntegerToString(st.minutesToNext) + " min";

      if(st.minutesToNext <= 30) cdClr = CLR_DANGER;
      else if(st.minutesToNext <= 60) cdClr = CLR_WARNING;
      else cdClr = CLR_SAFE;
   }
   CreateLabel(PREFIX + "cd_lbl", x + pad, cy, "Countdown", FONT_BODY, 8, CLR_LABEL);
   CreateLabel(PREFIX + "cd_val", x + w - pad, cy, cdText, FONT_BODY, 8, cdClr, true);
   cy += rowH;

   // Currency + Impact
   string curText = (st.minutesToNext < 9999) ? st.nextEvent.currency : "---";
   string impText = (st.minutesToNext < 9999) ? g_news.ImpactToString(st.nextEvent.impact) : "---";
   color impClr = CLR_OFF;
   if(st.minutesToNext < 9999)
   {
      if(st.nextEvent.impact == ASQ_NEWS_IMPACT_HIGH) impClr = CLR_HIGH;
      else if(st.nextEvent.impact == ASQ_NEWS_IMPACT_MEDIUM) impClr = CLR_MEDIUM;
      else impClr = CLR_LOW;
   }
   CreateLabel(PREFIX + "ci_lbl", x + pad, cy, "Currency", FONT_BODY, 8, CLR_LABEL);
   CreateLabel(PREFIX + "ci_val", x + w - pad, cy, curText + " | " + impText, FONT_BODY, 8, impClr, true);
   cy += rowH;

   // Type
   if(st.minutesToNext < 9999)
   {
      string typeText = g_news.TypeToString(st.nextEvent.type);
      CreateLabel(PREFIX + "ty_lbl", x + pad, cy, "Type", FONT_BODY, 8, CLR_LABEL);
      CreateLabel(PREFIX + "ty_val", x + w - pad, cy, typeText, FONT_BODY, 8, CLR_VALUE, true);
      cy += rowH;
   }
   else
   {
      ObjectDelete(0, PREFIX + "ty_lbl"); ObjectDelete(0, PREFIX + "ty_val");
   }

   cy += section;
   CreateRect(PREFIX + "sep3", x + pad, cy, w - pad * 2, 1, CLR_ACCENT, CLR_ACCENT);
   cy += section;

   // ─── Upcoming Events List ───
   CreateLabel(PREFIX + "up_title", x + pad, cy, "UPCOMING EVENTS", FONT_BODY, 7, CLR_LABEL);
   cy += 14;

   for(int i = 0; i < ASQ_UPCOMING_LIST_SIZE; i++)
   {
      string eName = PREFIX + "ev" + IntegerToString(i);
      if(i < st.upcomingCount)
      {
         SASQNewsEvent ev = st.upcoming[i];
         color evClr = CLR_LOW;
         string evDot = "";
         if(ev.impact == ASQ_NEWS_IMPACT_HIGH) { evClr = CLR_HIGH; evDot = "H"; }
         else if(ev.impact == ASQ_NEWS_IMPACT_MEDIUM) { evClr = CLR_MEDIUM; evDot = "M"; }
         else { evClr = CLR_LOW; evDot = "L"; }

         datetime now = TimeCurrent();
         int evMin = (int)((ev.time - now) / 60);
         string evTimeStr = "";
         if(evMin >= 1440)
            evTimeStr = IntegerToString(evMin / 1440) + "d";
         else if(evMin >= 60)
            evTimeStr = IntegerToString(evMin / 60) + "h" + IntegerToString(evMin % 60) + "m";
         else
            evTimeStr = IntegerToString(evMin) + "m";

         string evTitle = ev.title;
         if(StringLen(evTitle) > 20) evTitle = StringSubstr(evTitle, 0, 20) + "..";

         CreateLabel(eName + "_dot", x + pad, cy, evDot, FONT_BODY, 7, evClr);
         CreateLabel(eName + "_name", x + pad + 16, cy, evTitle, FONT_BODY, 7, CLR_VALUE);
         CreateLabel(eName + "_time", x + w - pad, cy, ev.currency + " " + evTimeStr, FONT_BODY, 7, CLR_SUBTITLE, true);
      }
      else
      {
         CreateLabel(eName + "_dot", x + pad, cy, "-", FONT_BODY, 7, CLR_MUTED);
         CreateLabel(eName + "_name", x + pad + 16, cy, "---", FONT_BODY, 7, CLR_MUTED);
         ObjectDelete(0, eName + "_time");
      }
      cy += 15;
   }

   cy += section;
   CreateRect(PREFIX + "sep4", x + pad, cy, w - pad * 2, 1, CLR_ACCENT, CLR_ACCENT);
   cy += section;

   // ─── Stats ───
   string upText = "H:" + IntegerToString(st.upcomingHighCount) +
                   "  M:" + IntegerToString(st.upcomingMediumCount) +
                   "  L:" + IntegerToString(st.upcomingLowCount);
   CreateLabel(PREFIX + "up_lbl", x + pad, cy, "Upcoming", FONT_BODY, 8, CLR_LABEL);
   CreateLabel(PREFIX + "up_val", x + w - pad, cy, upText, FONT_BODY, 8, CLR_VALUE, true);
   cy += rowH;

   // Mode
   string modeText = "OFF";
   switch(InpMode)
   {
      case ASQ_NEWS_HIGH_ONLY:   modeText = "HIGH ONLY"; break;
      case ASQ_NEWS_HIGH_MEDIUM: modeText = "HIGH+MED";  break;
      case ASQ_NEWS_ALL:         modeText = "ALL";       break;
   }
   CreateLabel(PREFIX + "md_lbl", x + pad, cy, "Mode", FONT_BODY, 8, CLR_LABEL);
   CreateLabel(PREFIX + "md_val", x + w - pad, cy, modeText, FONT_BODY, 8, CLR_VALUE, true);
   cy += rowH;

   // Total events loaded
   CreateLabel(PREFIX + "tot_lbl", x + pad, cy, "Events", FONT_BODY, 8, CLR_LABEL);
   CreateLabel(PREFIX + "tot_val", x + w - pad, cy, IntegerToString(g_news.GetEventCount()) + " loaded", FONT_BODY, 8, CLR_SUBTITLE, true);
   cy += rowH;

   // Resize background
   cy += pad;
   int finalH = cy - y;
   ObjectSetInteger(0, PREFIX + "bg", OBJPROP_YSIZE, finalH);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Drawing helpers                                                   |
//+------------------------------------------------------------------+
void CreateRect(string name, int x, int y, int w, int h, color bgClr, color borderClr)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgClr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, borderClr);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void CreateLabel(string name, int x, int y, string text,
                 string font, int fontSize, color clr, bool rightAlign = false)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, rightAlign ? ANCHOR_RIGHT_UPPER : ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}
//+------------------------------------------------------------------+
