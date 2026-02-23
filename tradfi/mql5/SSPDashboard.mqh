//+------------------------------------------------------------------+
//|                                              SSPDashboard.mqh    |
//|            SafeScalperPro v3.1 - Dashboard GUI Module             |
//|     CYBER FROST THEME - Blue/Pink/Cyan Neon Design               |
//+------------------------------------------------------------------+
//|  FIXES FROM v3.0:                                                |
//|  * Full opaque panel backgrounds (no chart bleed-through)        |
//|  * Fixed all text overlaps with proper column widths             |
//|  * New Cyber Frost theme (blue/pink/cyan) - no gold anywhere    |
//|  * Better spacing, padding, and alignment                        |
//|  * Larger collapse button with proper hitbox                     |
//|  * Clean footer bar with no text clipping                        |
//|  * Consistent value alignment (right-aligned monospace)          |
//|  * Panel width increased to 290px for breathing room             |
//|  * Cockpit reorganized with cleaner column spacing               |
//+------------------------------------------------------------------+
#property copyright   "AlgoSphere Quant"
#property version     "3.10"
#property strict

#ifndef SSP_DASHBOARD_MQH
#define SSP_DASHBOARD_MQH

#include "SSPCore.mqh"

//+------------------------------------------------------------------+
//| CYBER FROST COLOR PALETTE                                        |
//+------------------------------------------------------------------+
// Backgrounds - deep blue-black gradient
#define CLR_BG_DEEP       C'6,8,18'
#define CLR_BG_PRIMARY    C'10,14,28'
#define CLR_BG_SECONDARY  C'16,22,40'
#define CLR_BG_TERTIARY   C'24,32,56'
#define CLR_BG_HOVER      C'32,42,72'

// Borders
#define CLR_BORDER_MAIN   C'30,45,80'
#define CLR_BORDER_GLOW   C'60,120,220'
#define CLR_DIVIDER       C'20,30,55'

// Text
#define CLR_TEXT_PRIMARY   C'220,230,250'
#define CLR_TEXT_SECONDARY C'150,165,200'
#define CLR_TEXT_MUTED     C'80,95,130'
#define CLR_TEXT_INVERSE   C'10,12,24'

// Accent - Frost Blue
#define CLR_ACCENT        C'60,160,255'
#define CLR_ACCENT_DIM    C'40,100,180'
#define CLR_ACCENT_GLOW   C'80,180,255'

// Accent 2 - Neon Pink
#define CLR_PINK          C'255,80,160'
#define CLR_PINK_DIM      C'160,50,100'
#define CLR_PINK_BG       C'40,15,30'

// Accent 3 - Cyan
#define CLR_CYAN          C'0,220,220'
#define CLR_CYAN_DIM      C'0,140,140'

// Semantic
#define CLR_PROFIT        C'0,210,140'
#define CLR_PROFIT_BG     C'10,40,30'
#define CLR_LOSS          C'255,70,90'
#define CLR_LOSS_BG       C'45,15,20'
#define CLR_WARNING       C'255,180,40'
#define CLR_NEUTRAL       C'90,105,140'

// Typography
#define FONT_UI           "Segoe UI"
#define FONT_MONO         "Consolas"
#define FONT_TITLE        "Segoe UI Semibold"
#define SZ_TITLE          12
#define SZ_SECTION        8
#define SZ_LABEL          8
#define SZ_VALUE          9
#define SZ_SMALL          7
#define SZ_BUTTON         8
#define SZ_BIG            11

//+------------------------------------------------------------------+
//| CHART THEME BACKUP                                               |
//+------------------------------------------------------------------+
struct SThemeBackup
  {
   color bg, fg, grid, barUp, barDown, bullC, bearC, chartLn, vol, bidLn, askLn, stopLn;
   bool  chartFg, saved;
   void Reset() { saved = false; }
  };

//+------------------------------------------------------------------+
//| GUI CORE                                                         |
//+------------------------------------------------------------------+
class CSSPGui
  {
private:
   long              m_chart;
   SThemeBackup      m_bak;
   bool              m_themed;
public:
                     CSSPGui() : m_chart(0), m_themed(false) { m_bak.Reset(); }

   bool Init(long ch) { m_chart = ch; return true; }
   int  ChW() { return (int)ChartGetInteger(m_chart, CHART_WIDTH_IN_PIXELS); }
   int  ChH() { return (int)ChartGetInteger(m_chart, CHART_HEIGHT_IN_PIXELS); }

   void ApplyTheme()
     {
      if(m_themed) return;
      SaveTheme();
      // CHART_FOREGROUND=false means chart candles render BEHIND graphical objects
      // Combined with OBJPROP_BACK=false on our panels, this makes them fully opaque
      ChartSetInteger(m_chart, CHART_FOREGROUND, false);
      ChartSetInteger(m_chart, CHART_COLOR_BACKGROUND, C'8,10,22');
      ChartSetInteger(m_chart, CHART_COLOR_FOREGROUND, C'100,115,150');
      ChartSetInteger(m_chart, CHART_COLOR_GRID, C'14,20,38');
      ChartSetInteger(m_chart, CHART_COLOR_CANDLE_BULL, C'0,190,130');
      ChartSetInteger(m_chart, CHART_COLOR_CANDLE_BEAR, C'240,60,80');
      ChartSetInteger(m_chart, CHART_COLOR_CHART_UP, C'0,190,130');
      ChartSetInteger(m_chart, CHART_COLOR_CHART_DOWN, C'240,60,80');
      ChartSetInteger(m_chart, CHART_COLOR_CHART_LINE, CLR_ACCENT);
      ChartSetInteger(m_chart, CHART_COLOR_VOLUME, C'30,80,160');
      ChartSetInteger(m_chart, CHART_COLOR_BID, C'60,90,140');
      ChartSetInteger(m_chart, CHART_COLOR_ASK, C'140,60,80');
      ChartSetInteger(m_chart, CHART_COLOR_STOP_LEVEL, CLR_LOSS);
      ChartRedraw(m_chart);
      m_themed = true;
     }

   void EnableOpaque()
     {
      if(!m_bak.saved) SaveTheme();
      // CHART_FOREGROUND=false: candles behind objects, making panels opaque
      ChartSetInteger(m_chart, CHART_FOREGROUND, false);
      m_themed = true;
      ChartRedraw(m_chart);
     }

   void RestoreTheme()
     {
      if(!m_themed || !m_bak.saved) return;
      ChartSetInteger(m_chart, CHART_COLOR_BACKGROUND, m_bak.bg);
      ChartSetInteger(m_chart, CHART_COLOR_FOREGROUND, m_bak.fg);
      ChartSetInteger(m_chart, CHART_COLOR_GRID, m_bak.grid);
      ChartSetInteger(m_chart, CHART_COLOR_CHART_UP, m_bak.barUp);
      ChartSetInteger(m_chart, CHART_COLOR_CHART_DOWN, m_bak.barDown);
      ChartSetInteger(m_chart, CHART_COLOR_CANDLE_BULL, m_bak.bullC);
      ChartSetInteger(m_chart, CHART_COLOR_CANDLE_BEAR, m_bak.bearC);
      ChartSetInteger(m_chart, CHART_COLOR_CHART_LINE, m_bak.chartLn);
      ChartSetInteger(m_chart, CHART_COLOR_VOLUME, m_bak.vol);
      ChartSetInteger(m_chart, CHART_COLOR_BID, m_bak.bidLn);
      ChartSetInteger(m_chart, CHART_COLOR_ASK, m_bak.askLn);
      ChartSetInteger(m_chart, CHART_COLOR_STOP_LEVEL, m_bak.stopLn);
      ChartSetInteger(m_chart, CHART_FOREGROUND, m_bak.chartFg);
      ChartRedraw(m_chart);
      m_themed = false;
     }

   void Cleanup() { RestoreTheme(); ObjectsDeleteAll(m_chart, SSP_PREFIX); }
   void DelPrefix(string p) { ObjectsDeleteAll(m_chart, p); }

   void Panel(string n, int x, int y, int w, int h, color bg, color brd = clrNONE, int z = 0)
     {
      ObjectCreate(m_chart, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(m_chart, n, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(m_chart, n, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(m_chart, n, OBJPROP_XSIZE, w);
      ObjectSetInteger(m_chart, n, OBJPROP_YSIZE, h);
      ObjectSetInteger(m_chart, n, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(m_chart, n, OBJPROP_BORDER_COLOR, brd == clrNONE ? bg : brd);
      ObjectSetInteger(m_chart, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(m_chart, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(m_chart, n, OBJPROP_BACK, false);
      ObjectSetInteger(m_chart, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chart, n, OBJPROP_HIDDEN, true);
      ObjectSetInteger(m_chart, n, OBJPROP_ZORDER, z);
     }

   void Label(string n, int x, int y, string txt, color c, int sz = SZ_LABEL,
              string f = FONT_UI, int anch = ANCHOR_LEFT_UPPER)
     {
      ObjectCreate(m_chart, n, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(m_chart, n, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(m_chart, n, OBJPROP_YDISTANCE, y);
      ObjectSetString(m_chart, n, OBJPROP_TEXT, txt);
      ObjectSetInteger(m_chart, n, OBJPROP_COLOR, c);
      ObjectSetString(m_chart, n, OBJPROP_FONT, f);
      ObjectSetInteger(m_chart, n, OBJPROP_FONTSIZE, sz);
      ObjectSetInteger(m_chart, n, OBJPROP_ANCHOR, anch);
      ObjectSetInteger(m_chart, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(m_chart, n, OBJPROP_BACK, false);
      ObjectSetInteger(m_chart, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chart, n, OBJPROP_HIDDEN, true);
     }

   void Button(string n, int x, int y, int w, int h, string txt,
               color bg, color tc, int sz = SZ_BUTTON, int z = 100)
     {
      ObjectCreate(m_chart, n, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(m_chart, n, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(m_chart, n, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(m_chart, n, OBJPROP_XSIZE, w);
      ObjectSetInteger(m_chart, n, OBJPROP_YSIZE, h);
      ObjectSetString(m_chart, n, OBJPROP_TEXT, txt);
      ObjectSetInteger(m_chart, n, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(m_chart, n, OBJPROP_COLOR, tc);
      ObjectSetString(m_chart, n, OBJPROP_FONT, FONT_UI);
      ObjectSetInteger(m_chart, n, OBJPROP_FONTSIZE, sz);
      ObjectSetInteger(m_chart, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(m_chart, n, OBJPROP_BACK, false);
      ObjectSetInteger(m_chart, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chart, n, OBJPROP_ZORDER, z);
     }

   void SetTxt(string n, string t) { if(ObjectFind(m_chart, n) >= 0) ObjectSetString(m_chart, n, OBJPROP_TEXT, t); }
   void SetClr(string n, color c)  { if(ObjectFind(m_chart, n) >= 0) ObjectSetInteger(m_chart, n, OBJPROP_COLOR, c); }
   void SetBg(string n, color c)   { if(ObjectFind(m_chart, n) >= 0) ObjectSetInteger(m_chart, n, OBJPROP_BGCOLOR, c); }

private:
   void SaveTheme()
     {
      if(m_bak.saved) return;
      m_bak.bg      = (color)ChartGetInteger(m_chart, CHART_COLOR_BACKGROUND);
      m_bak.fg      = (color)ChartGetInteger(m_chart, CHART_COLOR_FOREGROUND);
      m_bak.grid    = (color)ChartGetInteger(m_chart, CHART_COLOR_GRID);
      m_bak.barUp   = (color)ChartGetInteger(m_chart, CHART_COLOR_CHART_UP);
      m_bak.barDown = (color)ChartGetInteger(m_chart, CHART_COLOR_CHART_DOWN);
      m_bak.bullC   = (color)ChartGetInteger(m_chart, CHART_COLOR_CANDLE_BULL);
      m_bak.bearC   = (color)ChartGetInteger(m_chart, CHART_COLOR_CANDLE_BEAR);
      m_bak.chartLn = (color)ChartGetInteger(m_chart, CHART_COLOR_CHART_LINE);
      m_bak.vol     = (color)ChartGetInteger(m_chart, CHART_COLOR_VOLUME);
      m_bak.bidLn   = (color)ChartGetInteger(m_chart, CHART_COLOR_BID);
      m_bak.askLn   = (color)ChartGetInteger(m_chart, CHART_COLOR_ASK);
      m_bak.stopLn  = (color)ChartGetInteger(m_chart, CHART_COLOR_STOP_LEVEL);
      m_bak.chartFg = (bool)ChartGetInteger(m_chart, CHART_FOREGROUND);
      m_bak.saved   = true;
     }
  };

//+------------------------------------------------------------------+
//| DASHBOARD CLASS                                                  |
//+------------------------------------------------------------------+
class CSSPDashboard
  {
private:
   CSSPGui           m_gui;
   SSspGuiCommands   m_cmd;
   bool              m_visible;
   bool              m_panelVisible;
   bool              m_panelCollapsed;
   uint              m_lastClick;
   int               m_cpW, m_cpH;
   int               m_anW;
   int               m_rowCnt, m_secCnt;

public:
                     CSSPDashboard() : m_visible(false), m_panelVisible(true), m_panelCollapsed(false),
                                       m_lastClick(0), m_cpW(920), m_cpH(88), m_anW(290) { m_cmd.Reset(); }

   bool Init(long chartId, bool syncTheme)
     {
      if(!m_gui.Init(chartId)) return false;
      if(syncTheme) m_gui.ApplyTheme();
      else m_gui.EnableOpaque();
      m_visible = true;
      return true;
     }

   void Deinit() { m_gui.Cleanup(); m_visible = false; }
   // Cleanup also handles SSP_OV_PREFIX via the SSP_PREFIX wildcard in gui.Cleanup()
   void GetCommands(SSspGuiCommands &out) { out = m_cmd; }
   void ClearCommands()                   { m_cmd.Reset(); }
   void SetPanelVisible(bool v)           { m_panelVisible = v; }

   void Draw(SSspCockpitData &d)
     {
      if(!m_visible) return;
      m_gui.DelPrefix(SSP_CP_PREFIX);
      m_gui.DelPrefix(SSP_AN_PREFIX);
      m_gui.DelPrefix(SSP_OV_PREFIX);
      // Force foreground mode every redraw (some MT5 builds reset this)
      ChartSetInteger(0, CHART_FOREGROUND, false);
      DrawCockpit(d);
      if(m_panelVisible) DrawAnalytics(d);
      ChartRedraw();
     }

   bool OnEvent(const int id, const long &lp, const double &dp, const string &sp)
     {
      if(!m_visible || id != CHARTEVENT_OBJECT_CLICK) return false;
      if(StringFind(sp, SSP_CP_PREFIX) == 0)
        { ObjectSetInteger(0, sp, OBJPROP_STATE, false); HandleClick(StringSubstr(sp, StringLen(SSP_CP_PREFIX))); return true; }
      if(StringFind(sp, SSP_AN_PREFIX) == 0)
        { ObjectSetInteger(0, sp, OBJPROP_STATE, false);
          if(StringSubstr(sp, StringLen(SSP_AN_PREFIX)) == "COLLAPSE") m_panelCollapsed = !m_panelCollapsed;
          return true; }
      return false;
     }

   bool OnResize() { return true; }

private:
   string CP(string n) { return SSP_CP_PREFIX + n; }
   string AN(string n) { return SSP_AN_PREFIX + n; }
   color  PnlC(double v) { return v > 0.005 ? CLR_PROFIT : v < -0.005 ? CLR_LOSS : CLR_NEUTRAL; }

   //=================================================================
   // COCKPIT BAR
   //=================================================================
   void DrawCockpit(SSspCockpitData &d)
     {
      int chW = m_gui.ChW();
      int chH = m_gui.ChH();
      int bx = MathMax(8, (chW - m_cpW) / 2);
      int by = chH - m_cpH - 8;

      // Background + frost accent
      // Shield panel: extra background layer for guaranteed opacity
      m_gui.Panel(CP("SH"), bx - 1, by - 1, m_cpW + 2, m_cpH + 2, CLR_BG_DEEP, CLR_BG_DEEP, 0);
      m_gui.Panel(CP("BG"), bx, by, m_cpW, m_cpH, CLR_BG_PRIMARY, CLR_BORDER_MAIN, 1);
      m_gui.Panel(CP("TOP"), bx + 1, by, m_cpW - 2, 2, CLR_ACCENT, CLR_ACCENT, 2);

      // Column X positions
      int c1 = bx + 10, c2 = bx + 144, c3 = bx + 306, c4 = bx + 520, c5 = bx + 678, c6 = bx + 816;

      // Dividers
      int dY = by + 10, dH = m_cpH - 20;
      m_gui.Panel(CP("D1"), bx + 138, dY, 1, dH, CLR_DIVIDER);
      m_gui.Panel(CP("D2"), bx + 300, dY, 1, dH, CLR_DIVIDER);
      m_gui.Panel(CP("D3"), bx + 514, dY, 1, dH, CLR_DIVIDER);
      m_gui.Panel(CP("D4"), bx + 672, dY, 1, dH, CLR_DIVIDER);
      m_gui.Panel(CP("D5"), bx + 810, dY, 1, dH, CLR_DIVIDER);

      // COL 1: EA STATUS
      int y = by + 8;
      m_gui.Label(CP("TITLE"), c1, y, "SAFE SCALPER PRO", CLR_ACCENT, SZ_TITLE, FONT_TITLE);
      m_gui.Label(CP("VER"), c1, y + 16, "v3.1 Breakout Scalper", CLR_TEXT_MUTED, SZ_SMALL);

      color stBg, stTx; string stTxt;
      GetStatusStyle(d, stBg, stTx, stTxt);
      m_gui.Panel(CP("STBG"), c1, y + 34, 66, 17, stBg, stBg, 5);
      m_gui.Label(CP("STTX"), c1 + 6, y + 37, stTxt, stTx, SZ_SMALL, FONT_TITLE);

      color aBg = d.autoTrading ? C'15,50,35' : CLR_BG_TERTIARY;
      color aTx = d.autoTrading ? CLR_PROFIT : CLR_TEXT_MUTED;
      m_gui.Button(CP("AUTO"), c1, y + 56, 60, 18, d.autoTrading ? "AUTO" : "OFF", aBg, aTx, SZ_SMALL);

      string sigT = "WAIT"; color sigC = CLR_TEXT_MUTED;
      if(d.lastSignal == SSP_SIGNAL_BUY) { sigT = "^ BUY"; sigC = CLR_PROFIT; }
      else if(d.lastSignal == SSP_SIGNAL_SELL) { sigT = "v SELL"; sigC = CLR_LOSS; }
      m_gui.Label(CP("SIG"), c1 + 66, y + 59, sigT, sigC, SZ_SMALL, FONT_MONO);

      // COL 2: MARKET
      y = by + 8;
      m_gui.Label(CP("SYM"), c2, y, d.symbol, CLR_TEXT_PRIMARY, SZ_BIG, FONT_TITLE);
      m_gui.Label(CP("TF"), c2 + 80, y + 2, d.timeframe, CLR_ACCENT, SZ_LABEL, FONT_MONO);

      color spC = d.spreadOK ? CLR_PROFIT : CLR_LOSS;
      m_gui.Label(CP("SP"), c2, y + 16, "Spread", CLR_TEXT_MUTED, SZ_SMALL);
      m_gui.Label(CP("SPV"), c2 + 50, y + 16, IntegerToString(d.spreadPoints) + " pts", spC, SZ_SMALL, FONT_MONO);

      int dgts = (int)SymbolInfoInteger(d.symbol, SYMBOL_DIGITS);
      m_gui.Label(CP("BID"), c2, y + 32, "Bid", CLR_TEXT_MUTED, SZ_SMALL);
      m_gui.Label(CP("BIDV"), c2 + 50, y + 32, DoubleToString(d.bid, dgts), CLR_TEXT_SECONDARY, SZ_SMALL, FONT_MONO);
      m_gui.Label(CP("EQ"), c2, y + 48, "Equity", CLR_TEXT_MUTED, SZ_SMALL);
      m_gui.Label(CP("EQV"), c2 + 50, y + 48, SSPFmtMoney(d.equity), CLR_TEXT_PRIMARY, SZ_SMALL, FONT_MONO);
      m_gui.Label(CP("DY"), c2, y + 64, "Today", CLR_TEXT_MUTED, SZ_SMALL);
      m_gui.Label(CP("DYV"), c2 + 50, y + 64, SSPFmtMoney(d.dailyPnL, true), PnlC(d.dailyPnL), SZ_SMALL, FONT_MONO);

      // COL 3: TRADE BUTTONS
      y = by + 8;
      int bW = 68, bH = 26, bG = 5;
      m_gui.Button(CP("BUY"), c3, y, bW, bH, "^ BUY", C'10,45,35', CLR_PROFIT, SZ_BUTTON);
      m_gui.Button(CP("SELL"), c3 + bW + bG, y, bW, bH, "v SELL", C'45,15,20', CLR_LOSS, SZ_BUTTON);

      string clsT = m_cmd.confirmCloseAll ? "CONFIRM?" : "CLS ALL";
      color clsB = m_cmd.confirmCloseAll ? CLR_LOSS : CLR_BG_TERTIARY;
      color clsF = m_cmd.confirmCloseAll ? CLR_TEXT_PRIMARY : CLR_TEXT_SECONDARY;
      m_gui.Button(CP("CLS"), c3, y + bH + 4, 2 * bW + bG, 20, clsT, clsB, clsF, SZ_SMALL);

      m_gui.Label(CP("POS"), c3, y + 56, "Pos: " + IntegerToString(d.openPositions), CLR_TEXT_SECONDARY, SZ_SMALL, FONT_MONO);
      m_gui.Label(CP("FLT"), c3 + 60, y + 56, "PnL: " + SSPFmtMoney(d.floatingPnL, true), PnlC(d.floatingPnL), SZ_SMALL, FONT_MONO);
      m_gui.Label(CP("OTT"), c3, y + 70, "One-trade mode", CLR_TEXT_MUTED, SZ_SMALL);

      // COL 4: LOT/RISK
      y = by + 8;
      color lBg = d.useLotMode ? CLR_ACCENT : CLR_BG_TERTIARY;
      color lTx = d.useLotMode ? CLR_TEXT_INVERSE : CLR_TEXT_MUTED;
      color rBg = d.useLotMode ? CLR_BG_TERTIARY : CLR_PINK;
      color rTx = d.useLotMode ? CLR_TEXT_MUTED : CLR_TEXT_INVERSE;
      m_gui.Button(CP("MLOT"), c4, y, 50, 18, d.useLotMode ? "* LOT" : "o LOT", lBg, lTx, SZ_SMALL, 50);
      m_gui.Button(CP("MRSK"), c4 + 54, y, 58, 18, d.useLotMode ? "o RISK%" : "* RISK%", rBg, rTx, SZ_SMALL, 50);

      y += 24;
      m_gui.Button(CP("DN"), c4, y, 26, 24, "-", CLR_BG_TERTIARY, CLR_TEXT_PRIMARY, SZ_BIG, 50);
      m_gui.Panel(CP("VBG"), c4 + 28, y, 62, 24, CLR_BG_SECONDARY, CLR_BORDER_GLOW, 3);
      string valT = d.useLotMode ? DoubleToString(d.lotSize, 2) : SSPFmtPct(d.riskPct);
      m_gui.Label(CP("VAL"), c4 + 59, y + 5, valT, CLR_ACCENT_GLOW, SZ_VALUE, FONT_MONO, ANCHOR_UPPER);
      m_gui.Button(CP("UP"), c4 + 92, y, 26, 24, "+", CLR_BG_TERTIARY, CLR_TEXT_PRIMARY, SZ_BIG, 50);

      y += 30;
      int pw = 30, pg = 4;
      m_gui.Button(CP("L01"), c4, y, pw, 16, ".01", CLR_BG_TERTIARY, CLR_ACCENT_DIM, SZ_SMALL, 50);
      m_gui.Button(CP("L05"), c4 + pw + pg, y, pw, 16, ".05", CLR_BG_TERTIARY, CLR_ACCENT_DIM, SZ_SMALL, 50);
      m_gui.Button(CP("L10"), c4 + 2 * (pw + pg), y, pw, 16, ".10", CLR_BG_TERTIARY, CLR_ACCENT_DIM, SZ_SMALL, 50);
      m_gui.Button(CP("L50"), c4 + 3 * (pw + pg), y, pw, 16, ".50", CLR_BG_TERTIARY, CLR_ACCENT_DIM, SZ_SMALL, 50);

      // COL 5: FILTERS
      y = by + 8;
      m_gui.Label(CP("FLBL"), c5, y, "FILTERS", CLR_ACCENT_DIM, SZ_SMALL, FONT_TITLE);
      y += 16;
      FilterDot(CP("FS"), c5, y, "Spread", d.spreadOK ? "OK" : "HIGH", d.spreadOK); y += 16;
      FilterDot(CP("FE"), c5, y, "Session", d.sessionON ? "ON" : "OFF", d.sessionON); y += 16;
      FilterDot(CP("FN"), c5, y, "News", d.newsClear ? "CLEAR" : "EVENT", d.newsClear); y += 18;

      double ddAbs = MathAbs(d.currentDD);
      color ddC = ddAbs < d.allowedDD * 0.5 ? CLR_PROFIT : ddAbs < d.allowedDD * 0.8 ? CLR_WARNING : CLR_LOSS;
      m_gui.Label(CP("DDL"), c5, y, "DD", CLR_TEXT_MUTED, SZ_SMALL);
      m_gui.Label(CP("DDV"), c5 + 24, y, DoubleToString(ddAbs, 1) + "%", ddC, SZ_SMALL, FONT_MONO);

      string panT = m_panelVisible ? "Panel <" : "Panel >";
      m_gui.Button(CP("PANL"), c5, by + m_cpH - 22, 80, 16, panT, CLR_BG_TERTIARY, CLR_ACCENT, SZ_SMALL, 50);

      // COL 6: STATS
      y = by + 8;
      m_gui.Label(CP("STLBL"), c6, y, "STATS", CLR_PINK_DIM, SZ_SMALL, FONT_TITLE);
      y += 16;
      CpStat(CP("S1"), c6, y, "Trades", IntegerToString(d.stats.totalTrades), CLR_TEXT_PRIMARY); y += 14;
      color wrC = d.stats.winRate >= 55 ? CLR_PROFIT : d.stats.winRate >= 45 ? CLR_WARNING : CLR_LOSS;
      CpStat(CP("S2"), c6, y, "WR", SSPFmtPct(d.stats.winRate), wrC); y += 14;
      CpStat(CP("S3"), c6, y, "W/L", IntegerToString(d.stats.wins) + "/" + IntegerToString(d.stats.losses), CLR_TEXT_SECONDARY); y += 14;
      color pfC = d.stats.profitFactor >= 1.5 ? CLR_PROFIT : d.stats.profitFactor >= 1.0 ? CLR_WARNING : CLR_LOSS;
      CpStat(CP("S4"), c6, y, "PF", DoubleToString(d.stats.profitFactor, 2), pfC);
     }

   void FilterDot(string p, int x, int y, string lab, string val, bool ok)
     {
      color c = ok ? CLR_PROFIT : CLR_LOSS;
      m_gui.Panel(p + "D", x, y + 3, 7, 7, c, c, 5);
      m_gui.Label(p + "L", x + 11, y, lab + ":", CLR_TEXT_MUTED, SZ_SMALL);
      m_gui.Label(p + "V", x + 62, y, val, c, SZ_SMALL, FONT_MONO);
     }

   void CpStat(string p, int x, int y, string lab, string val, color vc)
     { m_gui.Label(p + "L", x, y, lab, CLR_TEXT_MUTED, SZ_SMALL); m_gui.Label(p + "V", x + 40, y, val, vc, SZ_SMALL, FONT_MONO); }

   void GetStatusStyle(SSspCockpitData &d, color &bg, color &tx, string &txt)
     {
      if(!d.autoTrading) { bg = CLR_BG_TERTIARY; tx = CLR_WARNING; txt = "MANUAL"; }
      else if(d.status == SSP_STATUS_DD_PAUSE) { bg = CLR_LOSS_BG; tx = CLR_LOSS; txt = "DD PAUSE"; }
      else if(d.status == SSP_STATUS_PAUSED) { bg = CLR_BG_TERTIARY; tx = CLR_WARNING; txt = "PAUSED"; }
      else { bg = CLR_PROFIT_BG; tx = CLR_PROFIT; txt = "RUNNING"; }
     }

   //=================================================================
   // ANALYTICS PANEL (left side, fully opaque, no bleed-through)
   //=================================================================
   void DrawAnalytics(SSspCockpitData &d)
     {
      int px = 8, py = 8;
      m_rowCnt = 0; m_secCnt = 0;

      if(m_panelCollapsed)
        {
         // Shield + collapsed bar
         m_gui.Panel(AN("SH"), px - 1, py - 1, 30, 522, CLR_BG_DEEP, CLR_BG_DEEP, 0);
         m_gui.Panel(AN("BG"), px, py, 28, 520, CLR_BG_PRIMARY, CLR_BORDER_MAIN, 1);
         m_gui.Panel(AN("TOPBAR"), px + 1, py, 26, 2, CLR_PINK, CLR_PINK, 2);
         m_gui.Button(AN("COLLAPSE"), px + 2, py + 6, 24, 24, ">", CLR_BG_TERTIARY, CLR_ACCENT, SZ_BIG);
         return;
        }

      int cpTop = m_gui.ChH() - m_cpH - 8;
      int anH = MathMax(460, cpTop - py - 12);

      // OPAQUE background - shield + main panel for guaranteed opacity
      m_gui.Panel(AN("SH"), px - 1, py - 1, m_anW + 2, anH + 2, CLR_BG_DEEP, CLR_BG_DEEP, 0);
      m_gui.Panel(AN("BG"), px, py, m_anW, anH, CLR_BG_PRIMARY, CLR_BORDER_MAIN, 1);
      m_gui.Panel(AN("TOPBAR"), px + 1, py, m_anW - 2, 2, CLR_PINK, CLR_PINK, 2);

      int cx = px + 12;
      int cy = py + 10;
      m_gui.Label(AN("HDR"), cx, cy, "ANALYTICS", CLR_PINK, SZ_TITLE, FONT_TITLE);
      m_gui.Button(AN("COLLAPSE"), px + m_anW - 32, py + 8, 26, 22, "<", CLR_BG_TERTIARY, CLR_ACCENT, SZ_LABEL);

      cy = py + 36;
      int vx = px + m_anW - 14;

      // ACCOUNT
      SecHdr(cx, cy, "ACCOUNT", CLR_ACCENT);
      DRow(cx, vx, cy, "Balance", SSPFmtMoney(d.balance), CLR_TEXT_PRIMARY);
      DRow(cx, vx, cy, "Equity", SSPFmtMoney(d.equity), CLR_TEXT_PRIMARY);
      DRow(cx, vx, cy, "Floating", SSPFmtMoney(d.floatingPnL, true), PnlC(d.floatingPnL));
      DRow(cx, vx, cy, "Free Margin", SSPFmtMoney(d.freeMargin), CLR_TEXT_SECONDARY);
      cy += 6;
      m_gui.Panel(AN("V1"), px + 8, cy, m_anW - 16, 1, CLR_DIVIDER); cy += 8;

      // SIGNAL
      SecHdr(cx, cy, "SIGNAL", CLR_CYAN);
      color tC = d.trendDir == "BULLISH" ? CLR_PROFIT : d.trendDir == "BEARISH" ? CLR_LOSS : CLR_NEUTRAL;
      DRow(cx, vx, cy, "Trend", d.trendDir, tC);
      int dg = (int)SymbolInfoInteger(d.symbol, SYMBOL_DIGITS);
      DRow(cx, vx, cy, "EMA 50", DoubleToString(d.emaFast, dg), CLR_ACCENT);
      DRow(cx, vx, cy, "EMA 200", DoubleToString(d.emaSlow, dg), CLR_PINK);
      color rC = d.rsi > 70 ? CLR_LOSS : d.rsi < 30 ? CLR_PROFIT : CLR_TEXT_PRIMARY;
      DRow(cx, vx, cy, "RSI", DoubleToString(d.rsi, 1), rC);
      DRow(cx, vx, cy, "ATR", DoubleToString(d.atr, dg), CLR_TEXT_SECONDARY);
      cy += 6;
      m_gui.Panel(AN("V2"), px + 8, cy, m_anW - 16, 1, CLR_DIVIDER); cy += 8;

      // RISK
      SecHdr(cx, cy, "RISK", CLR_WARNING);
      double ddA = MathAbs(d.currentDD);
      color ddc = ddA < d.allowedDD * 0.5 ? CLR_PROFIT : ddA < d.allowedDD * 0.8 ? CLR_WARNING : CLR_LOSS;
      DRow(cx, vx, cy, "Drawdown", DoubleToString(ddA, 2) + "%", ddc);
      DRow(cx, vx, cy, "Max Allowed", DoubleToString(d.allowedDD, 1) + "%", CLR_TEXT_MUTED);
      int barW = m_anW - 28;
      double pct = d.allowedDD > 0 ? SSPClamp(ddA / d.allowedDD, 0, 1) : 0;
      m_gui.Panel(AN("DDB"), cx, cy, barW, 6, CLR_BG_SECONDARY, CLR_BORDER_MAIN, 2);
      if(pct > 0.01) m_gui.Panel(AN("DDF"), cx + 1, cy + 1, (int)((barW - 2) * pct), 4, ddc, ddc, 3);
      cy += 14;
      m_gui.Panel(AN("V3"), px + 8, cy, m_anW - 16, 1, CLR_DIVIDER); cy += 8;

      // SESSION
      SecHdr(cx, cy, "SESSION", CLR_ACCENT_DIM);
      string sn = SSPGetSessionName();
      DRow(cx, vx, cy, "Session", d.sessionON ? sn : "OFF HOURS", d.sessionON ? CLR_PROFIT : CLR_NEUTRAL);
      cy += 6;
      m_gui.Panel(AN("V4"), px + 8, cy, m_anW - 16, 1, CLR_DIVIDER); cy += 8;

      // TRADES
      SecHdr(cx, cy, "TRADES", CLR_PINK);
      DRow(cx, vx, cy, "Total", IntegerToString(d.stats.totalTrades), CLR_TEXT_PRIMARY);
      DRow(cx, vx, cy, "W / L", IntegerToString(d.stats.wins) + " / " + IntegerToString(d.stats.losses), CLR_TEXT_SECONDARY);
      color wr = d.stats.winRate >= 55 ? CLR_PROFIT : d.stats.winRate >= 45 ? CLR_WARNING : CLR_LOSS;
      DRow(cx, vx, cy, "Win Rate", SSPFmtPct(d.stats.winRate), wr);
      color pf = d.stats.profitFactor >= 1.5 ? CLR_PROFIT : d.stats.profitFactor >= 1.0 ? CLR_WARNING : CLR_LOSS;
      DRow(cx, vx, cy, "Profit Factor", DoubleToString(d.stats.profitFactor, 2), pf);
      DRow(cx, vx, cy, "Today P/L", SSPFmtMoney(d.stats.todayPnL, true), PnlC(d.stats.todayPnL));
      DRow(cx, vx, cy, "Avg Win", SSPFmtMoney(d.stats.avgWin), CLR_PROFIT);
      DRow(cx, vx, cy, "Avg Loss", SSPFmtMoney(d.stats.avgLoss), CLR_LOSS);
      DRow(cx, vx, cy, "Expectancy", SSPFmtMoney(d.stats.expectancy, true), PnlC(d.stats.expectancy));
      DRow(cx, vx, cy, "Streak W/L", IntegerToString(d.stats.maxWinStreak) + " / " + IntegerToString(d.stats.maxLossStreak),
           d.stats.maxWinStreak > d.stats.maxLossStreak ? CLR_PROFIT : CLR_TEXT_SECONDARY);

      // Footer
      int fY = py + anH - 24;
      m_gui.Panel(AN("FOOT"), px + 1, fY, m_anW - 2, 23, CLR_BG_SECONDARY, CLR_BG_SECONDARY, 1);
      m_gui.Label(AN("FUP"), cx, fY + 5, "Up: " + SSPFmtTime(d.uptimeSec), CLR_TEXT_MUTED, SZ_SMALL, FONT_MONO);
      m_gui.Label(AN("FPOS"), vx, fY + 5, "Pos: " + IntegerToString(d.openPositions), CLR_TEXT_SECONDARY, SZ_SMALL, FONT_MONO, ANCHOR_RIGHT_UPPER);
     }

   void SecHdr(int x, int &y, string title, color c)
     { m_gui.Label(AN("S" + IntegerToString(m_secCnt++)), x, y, title, c, SZ_SECTION, FONT_TITLE); y += 16; }

   void DRow(int lx, int rx, int &y, string lab, string val, color vc)
     {
      string i = IntegerToString(m_rowCnt++);
      m_gui.Label(AN("L" + i), lx, y, lab, CLR_TEXT_SECONDARY, SZ_LABEL);
      m_gui.Label(AN("V" + i), rx, y, val, vc, SZ_VALUE, FONT_MONO, ANCHOR_RIGHT_UPPER);
      y += 18;
     }

   //=================================================================
   // CLICK HANDLER
   //=================================================================
   void HandleClick(string btn)
     {
      uint now = GetTickCount();
      if(now - m_lastClick < 250) return;
      m_lastClick = now;
      if(btn == "BUY")        m_cmd.cmdBuy = true;
      else if(btn == "SELL")  m_cmd.cmdSell = true;
      else if(btn == "CLS")
        { if(m_cmd.confirmCloseAll) { m_cmd.cmdCloseAll = true; m_cmd.confirmCloseAll = false; }
          else { m_cmd.confirmCloseAll = true; m_cmd.confirmTime = now; } }
      else if(btn == "AUTO")  m_cmd.cmdToggleAuto = true;
      else if(btn == "MLOT")  m_cmd.cmdModeLot = true;
      else if(btn == "MRSK")  m_cmd.cmdModeRisk = true;
      else if(btn == "DN")    m_cmd.cmdLotDown = true;
      else if(btn == "UP")    m_cmd.cmdLotUp = true;
      else if(btn == "L01")   m_cmd.cmdLot001 = true;
      else if(btn == "L05")   m_cmd.cmdLot005 = true;
      else if(btn == "L10")   m_cmd.cmdLot010 = true;
      else if(btn == "L50")   m_cmd.cmdLot050 = true;
      else if(btn == "PANL")  m_cmd.cmdTogglePanel = true;
     }
  };

#endif // SSP_DASHBOARD_MQH
