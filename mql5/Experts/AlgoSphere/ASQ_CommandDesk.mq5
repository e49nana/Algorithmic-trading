//+------------------------------------------------------------------+
//|                                       ASQ_CommandDesk_v1.00.mq5   |
//|                          Copyright 2026, AlgoSphere Quant         |
//|                    https://www.mql5.com/en/users/robin2.0         |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, AlgoSphere Quant"
#property link        "https://www.mql5.com/en/users/robin2.0"
#property version     "1.00"
#property description "Professional command center for manual traders."
#property description "One-click execution, hotkey support (B/S/X/R), staged multi-TP,"
#property description "adaptive trailing, drawdown guard, R:R display, and live metrics."
#property description "AlgoSphere Quant — Precision-engineered trading tools."

//+------------------------------------------------------------------+
//| Standard Library                                                   |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/AccountInfo.mqh>
#include <Trade/SymbolInfo.mqh>
#include <Trade/OrderInfo.mqh>

//+------------------------------------------------------------------+
//| Enumerations                                                       |
//+------------------------------------------------------------------+
enum ASQ_SIZING_METHOD
  {
   ASQ_LOT_FIXED       = 0,   // Fixed volume
   ASQ_LOT_PCT_BALANCE = 1,   // % of balance at risk
   ASQ_LOT_FLAT_AMOUNT = 2    // Fixed dollar at risk
  };

enum ASQ_TRAIL_ALGO
  {
   ASQ_TRAIL_NONE      = 0,   // Disabled
   ASQ_TRAIL_POINTS    = 1,   // Fixed-distance trailing
   ASQ_TRAIL_ATR       = 2,   // ATR-scaled trailing
   ASQ_TRAIL_SWING     = 3    // Previous bar swing trailing
  };

//+------------------------------------------------------------------+
//| User Inputs                                                        |
//+------------------------------------------------------------------+
input group              "═══ POSITION SIZING ═══"
input ASQ_SIZING_METHOD CfgSizeMethod  = ASQ_LOT_PCT_BALANCE; // Sizing algorithm
input double    CfgFixedVol            = 0.01;   // Fixed lot size
input double    CfgRiskPct             = 1.0;    // Risk as % of balance
input double    CfgRiskDollar          = 100.0;  // Risk as flat amount ($)

input group              "═══ STOP-LOSS & TAKE-PROFIT ═══"
input int       CfgSLDist              = 200;    // SL distance (pts, 0=none)
input int       CfgStage1Dist          = 150;    // Stage 1 TP distance (pts, 0=off)
input int       CfgStage2Dist          = 300;    // Stage 2 TP distance (pts, 0=off)
input int       CfgStage3Dist          = 500;    // Stage 3 TP distance (pts, 0=off)
input double    CfgStage1Pct           = 40.0;   // Stage 1 close % of original
input double    CfgStage2Pct           = 30.0;   // Stage 2 close % of original
input double    CfgStage3Pct           = 100.0;  // Stage 3 close % (remainder)

input group              "═══ TRAILING STOP ═══"
input ASQ_TRAIL_ALGO CfgTrailAlgo     = ASQ_TRAIL_ATR; // Trail algorithm
input int       CfgTrailPtsDist        = 150;    // Fixed trail distance (pts)
input int       CfgTrailStepMin        = 10;     // Minimum SL move step (pts)
input int       CfgATRBars             = 14;     // ATR lookback period
input double    CfgATRScale            = 1.5;    // ATR multiplier

input group              "═══ BREAKEVEN ═══"
input bool      CfgAutoBreakeven       = true;   // Enable automatic breakeven
input int       CfgBEActivation        = 100;    // BE activation profit (pts)
input int       CfgBELockOffset        = 5;      // BE lock above/below entry (pts)

input group              "═══ DRAWDOWN GUARD ═══"
input bool      CfgDDGuard             = false;  // Enable drawdown guard
input double    CfgDDMaxPct            = 5.0;    // Max drawdown % from session peak
input bool      CfgDDFlattenOnBreach   = true;   // Auto-flatten on DD breach

input group              "═══ PENDING ORDERS ═══"
input int       CfgPendOffset          = 100;    // Pending distance from market (pts)
input int       CfgPendSL              = 200;    // Pending SL (pts)
input int       CfgPendTP              = 400;    // Pending TP (pts)
input datetime  CfgPendExpiry          = 0;      // Pending expiration (0=GTC)

input group              "═══ HOTKEYS ═══"
input bool      CfgHotkeysOn           = true;   // Enable keyboard shortcuts
// B=Buy  S=Sell  X=Flatten All  R=Reverse  E=Breakeven  P=Purge Pendings

input group              "═══ DASHBOARD ═══"
input int       CfgPanelX              = 15;     // Panel X offset
input int       CfgPanelY              = 25;     // Panel Y offset
input int       CfgFontSz              = 9;      // Font size
input color     CfgClrBG               = C'18,18,28';   // Background
input color     CfgClrLong             = C'0,200,83';    // Long accent
input color     CfgClrShort            = C'255,23,68';   // Short accent
input color     CfgClrInfo             = C'90,180,250';  // Info accent
input color     CfgClrText             = C'180,185,195'; // Body text
input color     CfgClrHead             = C'90,180,250';  // Section header
input color     CfgClrEdge             = C'30,35,50';    // Panel border

input group              "═══ ADVANCED ═══"
input int       CfgMagic               = 990990; // Magic number
input int       CfgSlippage            = 20;     // Max slippage (pts)
input string    CfgTag                 = "ASQCD"; // Order comment prefix

//+------------------------------------------------------------------+
//| Internal Constants & Object Names                                  |
//+------------------------------------------------------------------+
const string PFX      = "ASQCD_";
const string APP      = "ASQ CommandDesk";

const string BTN_GO_LONG     = PFX + "GoLong";
const string BTN_GO_SHORT    = PFX + "GoShort";
const string BTN_LIM_BUY     = PFX + "LimBuy";
const string BTN_LIM_SELL    = PFX + "LimSell";
const string BTN_STP_BUY     = PFX + "StpBuy";
const string BTN_STP_SELL    = PFX + "StpSell";
const string BTN_NUKE        = PFX + "Nuke";
const string BTN_CUT_LONG    = PFX + "CutLong";
const string BTN_CUT_SHORT   = PFX + "CutShort";
const string BTN_WIPE_PEND   = PFX + "WipePend";
const string BTN_LOCK_BE     = PFX + "LockBE";
const string BTN_REVERSE     = PFX + "Reverse";

//+------------------------------------------------------------------+
//| Runtime Objects & State                                            |
//+------------------------------------------------------------------+
CTrade         t;
CPositionInfo  pos;
CAccountInfo   acct;
CSymbolInfo    sym;
COrderInfo     ord;

int            hATR = INVALID_HANDLE;
double         atrBuf[];

//--- staged exit tracker
struct StageTrack
  {
   ulong          ticket;
   double         baseVol;
   double         entry;
   ENUM_POSITION_TYPE dir;
   bool           s1;
   bool           s2;
   bool           s3;
  };
StageTrack     tracks[];

//--- deferred order-to-position matching
struct PendingMatch
  {
   double         price;
   double         vol;
   ENUM_POSITION_TYPE dir;
   datetime       ts;
  };
PendingMatch   pendQ[];

//--- drawdown guard state
double         dd_sessionPeak     = 0;
bool           dd_breached        = false;

//--- daily trade counter
int            dailyTradeCount    = 0;
int            dailyTradeDay      = 0;

//--- server-direct price accessors (bypass CSymbolInfo stale cache)
double  Ask_()    { return SymbolInfoDouble(_Symbol, SYMBOL_ASK); }
double  Bid_()    { return SymbolInfoDouble(_Symbol, SYMBOL_BID); }
double  Pt_()     { return SymbolInfoDouble(_Symbol, SYMBOL_POINT); }
int     Dg_()     { return (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS); }

//--- throttle for "no price" warnings
datetime       warnThrottle = 0;
const int      WARN_GAP     = 30;

//+------------------------------------------------------------------+
//| OnInit                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   sym.Name(_Symbol);
   sym.Refresh();
   sym.RefreshRates();

   t.SetExpertMagicNumber(CfgMagic);
   t.SetDeviationInPoints(CfgSlippage);
   t.SetAsyncMode(false);

   hATR = iATR(_Symbol, PERIOD_CURRENT, CfgATRBars);
   if(hATR == INVALID_HANDLE)
      PrintFormat("[%s] Could not create ATR handle", APP);
   ArraySetAsSeries(atrBuf, true);

   //--- init drawdown guard
   dd_sessionPeak = acct.Equity();
   dd_breached    = false;

   //--- init daily counter
   MqlDateTime now;
   TimeCurrent(now);
   dailyTradeDay   = now.day;
   dailyTradeCount = 0;

   BuildPanel();
   RestoreTrackedPositions();

   ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   //--- CHARTEVENT_KEYDOWN is always enabled in MQL5 — no explicit activation needed

   PrintFormat("[%s] v1.00 active on %s | Ask=%.5f Bid=%.5f",
               APP, _Symbol, Ask_(), Bid_());
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, PFX);
   if(hATR != INVALID_HANDLE)
      IndicatorRelease(hATR);
  }

//+------------------------------------------------------------------+
//| OnTick                                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   sym.Refresh();
   sym.RefreshRates();

   double a = Ask_(), b = Bid_();
   if(a <= 0 || b <= 0)
     {
      if(TimeCurrent() - warnThrottle >= WARN_GAP)
        {
         PrintFormat("[%s] Waiting for quotes (ask=%.5f bid=%.5f)", APP, a, b);
         warnThrottle = TimeCurrent();
        }
      LiveUpdate();
      return;
     }

   //--- reset daily counter on new day
   MqlDateTime now;
   TimeCurrent(now);
   if(now.day != dailyTradeDay)
     {
      dailyTradeDay   = now.day;
      dailyTradeCount = 0;
     }

   //--- drawdown guard engine
   if(CfgDDGuard)
      RunDrawdownGuard();

   //--- core engines
   ResolvePendingMatches();

   if(CfgTrailAlgo != ASQ_TRAIL_NONE)
      EngineTrail();

   if(CfgAutoBreakeven)
      EngineBreakeven();

   EngineStageExits();

   LiveUpdate();
  }

//+------------------------------------------------------------------+
//| OnChartEvent — buttons + hotkeys                                   |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   //--- hotkey handler
   if(id == CHARTEVENT_KEYDOWN && CfgHotkeysOn)
     {
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
         return;

      switch((int)lparam)
        {
         case 'B': FireMarketOrder(ORDER_TYPE_BUY);    break;
         case 'S': FireMarketOrder(ORDER_TYPE_SELL);   break;
         case 'X': NukeAll();                          break;
         case 'R': ReversePosition();                  break;
         case 'E': LockBreakevenAll();                 break;
         case 'P': WipePendings();                     break;
        }
      ChartRedraw(0);
      return;
     }

   //--- button handler
   if(id != CHARTEVENT_OBJECT_CLICK) return;
   if(StringFind(sparam, PFX) != 0) return;

   ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
   ChartRedraw(0);

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
     {
      PrintFormat("[%s] Enable Algo Trading first.", APP);
      return;
     }

   if(sparam == BTN_GO_LONG)         FireMarketOrder(ORDER_TYPE_BUY);
   else if(sparam == BTN_GO_SHORT)   FireMarketOrder(ORDER_TYPE_SELL);
   else if(sparam == BTN_LIM_BUY)    FirePending(ORDER_TYPE_BUY_LIMIT);
   else if(sparam == BTN_LIM_SELL)   FirePending(ORDER_TYPE_SELL_LIMIT);
   else if(sparam == BTN_STP_BUY)    FirePending(ORDER_TYPE_BUY_STOP);
   else if(sparam == BTN_STP_SELL)   FirePending(ORDER_TYPE_SELL_STOP);
   else if(sparam == BTN_NUKE)       NukeAll();
   else if(sparam == BTN_CUT_LONG)   CutSide(POSITION_TYPE_BUY);
   else if(sparam == BTN_CUT_SHORT)  CutSide(POSITION_TYPE_SELL);
   else if(sparam == BTN_WIPE_PEND)  WipePendings();
   else if(sparam == BTN_LOCK_BE)    LockBreakevenAll();
   else if(sparam == BTN_REVERSE)    ReversePosition();

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//|                    DRAWDOWN GUARD                                   |
//+------------------------------------------------------------------+
void RunDrawdownGuard()
  {
   double equity = acct.Equity();

   //--- update session high-water mark
   if(equity > dd_sessionPeak)
      dd_sessionPeak = equity;

   //--- compute drawdown from peak
   if(dd_sessionPeak <= 0) return;
   double ddPct = (dd_sessionPeak - equity) / dd_sessionPeak * 100.0;

   if(ddPct >= CfgDDMaxPct && !dd_breached)
     {
      dd_breached = true;
      PrintFormat("[%s] ⚠ DRAWDOWN GUARD: %.2f%% DD (limit %.2f%%). Peak=$%.2f, Equity=$%.2f",
                  APP, ddPct, CfgDDMaxPct, dd_sessionPeak, equity);

      if(CfgDDFlattenOnBreach)
        {
         PrintFormat("[%s] Auto-flattening all positions due to drawdown breach.", APP);
         NukeAll();
         WipePendings();
        }
     }

   //--- reset breach flag when equity recovers above threshold
   if(ddPct < CfgDDMaxPct * 0.5)
      dd_breached = false;
  }

//+------------------------------------------------------------------+
//|                    MARKET EXECUTION                                 |
//+------------------------------------------------------------------+
void FireMarketOrder(const ENUM_ORDER_TYPE type)
  {
   //--- block if drawdown guard has tripped
   if(CfgDDGuard && dd_breached)
     {
      PrintFormat("[%s] Order blocked — drawdown guard active.", APP);
      return;
     }

   double pt = Pt_(), a = Ask_(), b = Bid_();
   int dg = Dg_();

   if(a <= 0 || b <= 0 || pt <= 0)
     {
      PrintFormat("[%s] No quotes available — order aborted.", APP);
      return;
     }

   double entry = (type == ORDER_TYPE_BUY) ? a : b;
   double sl = 0, tp = 0;
   int minD = MinStopDist();

   //--- SL
   int slP = CfgSLDist;
   if(slP > 0)
     {
      if(slP < minD) slP = minD + 5;
      sl = (type == ORDER_TYPE_BUY)
           ? NormalizeDouble(entry - slP * pt, dg)
           : NormalizeDouble(entry + slP * pt, dg);
     }

   //--- TP at furthest stage
   int maxStage = MaxStageDist();
   if(maxStage > 0)
     {
      if(maxStage < minD) maxStage = minD + 5;
      tp = (type == ORDER_TYPE_BUY)
           ? NormalizeDouble(entry + maxStage * pt, dg)
           : NormalizeDouble(entry - maxStage * pt, dg);
     }

   double vol = SizePosition(slP);

   string side = (type == ORDER_TYPE_BUY) ? "L" : "S";
   string cmt = StringFormat("%s_%s|EX000", CfgTag, side);

   PrintFormat("[%s] >> %s Entry=%.5f SL=%.5f TP=%.5f Vol=%.2f",
               APP, EnumToString(type), entry, sl, tp, vol);

   bool ok = (type == ORDER_TYPE_BUY)
             ? t.Buy(vol, _Symbol, 0, sl, tp, cmt)
             : t.Sell(vol, _Symbol, 0, sl, tp, cmt);

   if(ok && t.ResultDeal() > 0)
     {
      double fill = t.ResultPrice();
      ulong  tk   = t.ResultOrder();

      //--- adjust SL/TP for slippage
      if(fill > 0 && MathAbs(fill - entry) > pt)
        {
         double aSL = 0, aTP = 0;
         if(slP > 0)
            aSL = (type == ORDER_TYPE_BUY)
                  ? NormalizeDouble(fill - slP * pt, dg)
                  : NormalizeDouble(fill + slP * pt, dg);
         if(maxStage > 0)
            aTP = (type == ORDER_TYPE_BUY)
                  ? NormalizeDouble(fill + maxStage * pt, dg)
                  : NormalizeDouble(fill - maxStage * pt, dg);
         Sleep(200);
         if(PositionSelectByTicket(tk))
            t.PositionModify(tk, aSL, aTP);
        }

      //--- queue deferred match
      ENUM_POSITION_TYPE d = (type == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      int qi = ArraySize(pendQ);
      ArrayResize(pendQ, qi + 1);
      pendQ[qi].price = (fill > 0) ? fill : entry;
      pendQ[qi].vol   = vol;
      pendQ[qi].dir   = d;
      pendQ[qi].ts    = TimeCurrent();

      //--- increment daily counter
      dailyTradeCount++;

      PrintFormat("[%s] Filled %s @ %.5f | Vol:%.2f",
                  APP, EnumToString(type), (fill > 0) ? fill : entry, vol);
     }
   else
      PrintFormat("[%s] Rejected — err:%d %s rc:%d", APP,
                  GetLastError(), t.ResultRetcodeDescription(), t.ResultRetcode());
  }

//+------------------------------------------------------------------+
//| Reverse: flatten all, then open opposite direction                 |
//+------------------------------------------------------------------+
void ReversePosition()
  {
   //--- determine net direction
   double netLots = 0;
   ENUM_POSITION_TYPE netSide = POSITION_TYPE_BUY;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol() != _Symbol) continue;
      if(pos.Magic() != CfgMagic) continue;

      if(pos.PositionType() == POSITION_TYPE_BUY)
         netLots += pos.Volume();
      else
         netLots -= pos.Volume();
     }

   if(MathAbs(netLots) < sym.LotsMin())
     {
      PrintFormat("[%s] No net position to reverse.", APP);
      return;
     }

   netSide = (netLots > 0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;

   //--- flatten everything
   NukeAll();

   //--- small delay for order processing
   Sleep(300);

   //--- open opposite
   ENUM_ORDER_TYPE reverseType = (netSide == POSITION_TYPE_BUY)
                                  ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   FireMarketOrder(reverseType);

   PrintFormat("[%s] Position reversed from %s",
               APP, (netSide == POSITION_TYPE_BUY) ? "LONG→SHORT" : "SHORT→LONG");
  }

//+------------------------------------------------------------------+
//|                    PENDING ORDERS                                   |
//+------------------------------------------------------------------+
void FirePending(const ENUM_ORDER_TYPE type)
  {
   double pt = Pt_(), a = Ask_(), b = Bid_();
   int dg = Dg_();

   if(a <= 0 || b <= 0 || pt <= 0)
     { PrintFormat("[%s] No quotes for pending.", APP); return; }

   int minD = MinStopDist();
   int gap  = CfgPendOffset;
   if(gap < minD) gap = minD + 5;

   int slD = CfgPendSL, tpD = CfgPendTP;
   if(slD > 0 && slD < minD) slD = minD + 5;
   if(tpD > 0 && tpD < minD) tpD = minD + 5;

   double price = 0, sl = 0, tp = 0;

   switch(type)
     {
      case ORDER_TYPE_BUY_LIMIT:
         price = NormalizeDouble(a - gap * pt, dg);
         sl = (slD > 0) ? NormalizeDouble(price - slD * pt, dg) : 0;
         tp = (tpD > 0) ? NormalizeDouble(price + tpD * pt, dg) : 0;
         break;
      case ORDER_TYPE_SELL_LIMIT:
         price = NormalizeDouble(b + gap * pt, dg);
         sl = (slD > 0) ? NormalizeDouble(price + slD * pt, dg) : 0;
         tp = (tpD > 0) ? NormalizeDouble(price - tpD * pt, dg) : 0;
         break;
      case ORDER_TYPE_BUY_STOP:
         price = NormalizeDouble(a + gap * pt, dg);
         sl = (slD > 0) ? NormalizeDouble(price - slD * pt, dg) : 0;
         tp = (tpD > 0) ? NormalizeDouble(price + tpD * pt, dg) : 0;
         break;
      case ORDER_TYPE_SELL_STOP:
        {
         price = NormalizeDouble(b - gap * pt, dg);
         double floor = MathMax(minD * pt, 20 * pt);
         if(price < floor) price = NormalizeDouble(b * 0.999, dg);
         sl = (slD > 0) ? NormalizeDouble(price + slD * pt, dg) : 0;
         tp = (tpD > 0) ? NormalizeDouble(price - tpD * pt, dg) : 0;
         if(tp < 0) tp = 0;
         break;
        }
     }

   if(price <= 0) { PrintFormat("[%s] Bad pending price %.5f", APP, price); return; }
   if(sl < 0) sl = 0;
   if(tp < 0) tp = 0;

   double vol = SizePosition(slD);
   string cmt = StringFormat("%s_PND", CfgTag);

   if(t.OrderOpen(_Symbol, type, vol, 0, price, sl, tp,
                  ORDER_TIME_GTC, CfgPendExpiry, cmt))
      PrintFormat("[%s] Pending %s %.2f @ %.5f", APP, EnumToString(type), vol, price);
   else
      PrintFormat("[%s] Pending failed — err:%d %s", APP,
                  GetLastError(), t.ResultRetcodeDescription());
  }

//+------------------------------------------------------------------+
//|                    STAGED EXIT ENGINE                               |
//+------------------------------------------------------------------+
void ArmTrack(const ulong ticket)
  {
   for(int j = 0; j < ArraySize(tracks); j++)
      if(tracks[j].ticket == ticket) return;

   if(!PositionSelectByTicket(ticket)) return;

   int n = ArraySize(tracks);
   ArrayResize(tracks, n + 1);
   tracks[n].ticket  = ticket;
   tracks[n].baseVol = PositionGetDouble(POSITION_VOLUME);
   tracks[n].entry   = PositionGetDouble(POSITION_PRICE_OPEN);
   tracks[n].dir     = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   tracks[n].s1 = false;
   tracks[n].s2 = false;
   tracks[n].s3 = false;

   PrintFormat("[%s] Track armed #%I64u vol=%.2f entry=%.5f",
               APP, ticket, tracks[n].baseVol, tracks[n].entry);
  }

void ResolvePendingMatches()
  {
   if(ArraySize(pendQ) == 0) return;
   for(int q = ArraySize(pendQ) - 1; q >= 0; q--)
     {
      if(TimeCurrent() - pendQ[q].ts > 30)
        { DropPQ(q); continue; }

      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         if(!pos.SelectByIndex(i)) continue;
         if(pos.Symbol() != _Symbol || pos.Magic() != CfgMagic) continue;
         ulong tk = pos.Ticket();
         bool already = false;
         for(int j = 0; j < ArraySize(tracks); j++)
            if(tracks[j].ticket == tk) { already = true; break; }
         if(already) continue;
         if(pos.PositionType() != pendQ[q].dir) continue;
         ArmTrack(tk);
         DropPQ(q);
         break;
        }
     }
  }

void DropPQ(const int i)
  {
   int n = ArraySize(pendQ);
   if(i < 0 || i >= n) return;
   for(int k = i; k < n - 1; k++) pendQ[k] = pendQ[k + 1];
   ArrayResize(pendQ, n - 1);
  }

string EncodeEX(bool a, bool b_, bool c) { return StringFormat("EX%d%d%d", a?1:0, b_?1:0, c?1:0); }

bool DecodeEX(const string cmt, bool &a, bool &b_, bool &c)
  {
   int p = StringFind(cmt, "|EX");
   if(p < 0) return false;
   string tag = StringSubstr(cmt, p + 1, 5);
   if(StringLen(tag) < 5) return false;
   a  = (StringGetCharacter(tag, 2) == '1');
   b_ = (StringGetCharacter(tag, 3) == '1');
   c  = (StringGetCharacter(tag, 4) == '1');
   return true;
  }

void RestoreTrackedPositions()
  {
   ArrayResize(tracks, 0);
   for(int i = 0; i < PositionsTotal(); i++)
     {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != CfgMagic) continue;

      int n = ArraySize(tracks);
      ArrayResize(tracks, n + 1);
      tracks[n].ticket = pos.Ticket();
      tracks[n].entry  = pos.PriceOpen();
      tracks[n].dir    = pos.PositionType();

      string cmt = pos.Comment();
      bool a = false, b_ = false, c = false;
      if(DecodeEX(cmt, a, b_, c))
        {
         tracks[n].s1 = a;
         tracks[n].s2 = b_;
         tracks[n].s3 = c;
         double cv = pos.Volume();
         double closed = 0;
         if(a) closed += CfgStage1Pct;
         if(b_) closed += CfgStage2Pct;
         double remain = 100.0 - closed;
         tracks[n].baseVol = (remain > 0) ? cv / (remain / 100.0) : cv;
         PrintFormat("[%s] Restored #%I64u S1=%d S2=%d S3=%d bVol=%.2f",
                     APP, pos.Ticket(), a, b_, c, tracks[n].baseVol);
        }
      else
        {
         tracks[n].baseVol = pos.Volume();
         tracks[n].s1 = false;
         tracks[n].s2 = false;
         tracks[n].s3 = false;
        }
     }
  }

void EngineStageExits()
  {
   double pt = Pt_();
   for(int i = ArraySize(tracks) - 1; i >= 0; i--)
     {
      if(i >= ArraySize(tracks)) continue;
      ulong tk = tracks[i].ticket;
      if(!PositionSelectByTicket(tk)) { DropTrack(i); continue; }

      double curP  = PositionGetDouble(POSITION_PRICE_CURRENT);
      double eP    = tracks[i].entry;
      double bV    = tracks[i].baseVol;
      double cV    = PositionGetDouble(POSITION_VOLUME);
      ENUM_POSITION_TYPE d = tracks[i].dir;

      double pnlP = (d == POSITION_TYPE_BUY) ? (curP - eP) / pt : (eP - curP) / pt;

      //--- Stage 1
      if(!tracks[i].s1 && CfgStage1Dist > 0 && pnlP >= CfgStage1Dist)
        {
         double cv = Lot(bV * CfgStage1Pct / 100.0);
         if(cv >= sym.LotsMin() && cv <= cV)
           { if(t.PositionClosePartial(tk, cv, CfgSlippage))
              { tracks[i].s1 = true; PrintFormat("[%s] S1 closed %.2f on #%I64u", APP, cv, tk); } }
         else tracks[i].s1 = true;
        }

      //--- Stage 2
      if(!tracks[i].s2 && tracks[i].s1 && CfgStage2Dist > 0 && pnlP >= CfgStage2Dist)
        {
         if(PositionSelectByTicket(tk)) cV = PositionGetDouble(POSITION_VOLUME);
         double cv = Lot(bV * CfgStage2Pct / 100.0);
         if(cv >= sym.LotsMin() && cv <= cV)
           { if(t.PositionClosePartial(tk, cv, CfgSlippage))
              { tracks[i].s2 = true; PrintFormat("[%s] S2 closed %.2f on #%I64u", APP, cv, tk); } }
         else tracks[i].s2 = true;
        }

      //--- Stage 3: full exit
      if(!tracks[i].s3 && tracks[i].s2 && CfgStage3Dist > 0 && pnlP >= CfgStage3Dist)
        {
         if(t.PositionClose(tk, CfgSlippage))
           { tracks[i].s3 = true; PrintFormat("[%s] S3 closed #%I64u", APP, tk); DropTrack(i); }
        }
     }
  }

void DropTrack(const int i)
  {
   int n = ArraySize(tracks);
   if(i < 0 || i >= n) return;
   for(int k = i; k < n - 1; k++) tracks[k] = tracks[k + 1];
   ArrayResize(tracks, n - 1);
  }

//+------------------------------------------------------------------+
//|                    TRAILING ENGINE                                  |
//+------------------------------------------------------------------+
void EngineTrail()
  {
   double pt = Pt_();
   if(pt <= 0 || Bid_() <= 0 || Ask_() <= 0) return;

   double atrV = 0;
   if(CfgTrailAlgo == ASQ_TRAIL_ATR && hATR != INVALID_HANDLE)
      if(CopyBuffer(hATR, 0, 0, 1, atrBuf) > 0) atrV = atrBuf[0];

   int sLvl = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minG = MathMax(sLvl, 1) * pt;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != CfgMagic) continue;

      double cSL = pos.StopLoss(), cTP = pos.TakeProfit();
      double oP  = pos.PriceOpen();
      ulong  tk  = pos.Ticket();
      double ref = (pos.PositionType() == POSITION_TYPE_BUY) ? Bid_() : Ask_();

      double gap = 0;
      switch(CfgTrailAlgo)
        {
         case ASQ_TRAIL_POINTS: gap = CfgTrailPtsDist * pt;        break;
         case ASQ_TRAIL_ATR:    gap = atrV * CfgATRScale;           break;
         case ASQ_TRAIL_SWING:  gap = SwingGap(pos.PositionType()); break;
         default: continue;
        }
      if(gap <= 0) continue;

      double nSL = 0;
      if(pos.PositionType() == POSITION_TYPE_BUY)
        {
         nSL = NormalizeDouble(ref - gap, Dg_());
         if(cSL > 0 && nSL <= cSL) continue;
         if(nSL <= oP) continue;
         if(cSL > 0 && (nSL - cSL) < CfgTrailStepMin * pt) continue;
         if((ref - nSL) < minG) nSL = NormalizeDouble(ref - minG, Dg_());
        }
      else
        {
         nSL = NormalizeDouble(ref + gap, Dg_());
         if(cSL > 0 && nSL >= cSL) continue;
         if(nSL >= oP) continue;
         if(cSL > 0 && (cSL - nSL) < CfgTrailStepMin * pt) continue;
         if((nSL - ref) < minG) nSL = NormalizeDouble(ref + minG, Dg_());
        }

      if(t.PositionModify(tk, nSL, cTP))
         PrintFormat("[%s] Trail → %.5f on #%I64u", APP, nSL, tk);
     }
  }

double SwingGap(const ENUM_POSITION_TYPE d)
  {
   double h[], l[];
   ArraySetAsSeries(h, true); ArraySetAsSeries(l, true);
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 1, 1, h) < 1) return 0;
   if(CopyLow(_Symbol, PERIOD_CURRENT, 1, 1, l) < 1)  return 0;
   double ref = (d == POSITION_TYPE_BUY) ? Bid_() : Ask_();
   double g = (d == POSITION_TYPE_BUY) ? (ref - l[0]) : (h[0] - ref);
   return MathMax(g, 0);
  }

//+------------------------------------------------------------------+
//|                    BREAKEVEN ENGINE                                 |
//+------------------------------------------------------------------+
void EngineBreakeven()
  {
   double pt = Pt_();
   if(pt <= 0 || Bid_() <= 0 || Ask_() <= 0) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != CfgMagic) continue;

      double oP = pos.PriceOpen(), cSL = pos.StopLoss(), cTP = pos.TakeProfit();
      ulong tk = pos.Ticket();

      if(pos.PositionType() == POSITION_TYPE_BUY)
        {
         double pnl = (Bid_() - oP) / pt;
         double be  = NormalizeDouble(oP + CfgBELockOffset * pt, Dg_());
         if(pnl >= CfgBEActivation && (cSL < be || cSL == 0))
            if(t.PositionModify(tk, be, cTP))
               PrintFormat("[%s] BE → %.5f on #%I64u", APP, be, tk);
        }
      else
        {
         double pnl = (oP - Ask_()) / pt;
         double be  = NormalizeDouble(oP - CfgBELockOffset * pt, Dg_());
         if(pnl >= CfgBEActivation && (cSL > be || cSL == 0))
            if(t.PositionModify(tk, be, cTP))
               PrintFormat("[%s] BE → %.5f on #%I64u", APP, be, tk);
        }
     }
  }

void LockBreakevenAll()
  {
   double pt = Pt_();
   int cnt = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != CfgMagic) continue;

      double oP = pos.PriceOpen(), cTP = pos.TakeProfit();
      ulong tk = pos.Ticket();

      double be = 0; bool ok = false;
      if(pos.PositionType() == POSITION_TYPE_BUY)
        { be = NormalizeDouble(oP + CfgBELockOffset * pt, Dg_()); ok = Bid_() > be; }
      else
        { be = NormalizeDouble(oP - CfgBELockOffset * pt, Dg_()); ok = Ask_() < be; }

      if(ok && t.PositionModify(tk, be, cTP)) cnt++;
     }
   PrintFormat("[%s] BE locked on %d positions", APP, cnt);
  }

//+------------------------------------------------------------------+
//|                    FLATTEN / WIPE                                   |
//+------------------------------------------------------------------+
void NukeAll()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != CfgMagic) continue;
      t.PositionClose(pos.Ticket(), CfgSlippage);
     }
  }

void CutSide(const ENUM_POSITION_TYPE d)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != CfgMagic) continue;
      if(pos.PositionType() != d) continue;
      t.PositionClose(pos.Ticket(), CfgSlippage);
     }
  }

void WipePendings()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!ord.SelectByIndex(i)) continue;
      if(ord.Symbol() != _Symbol || ord.Magic() != CfgMagic) continue;
      t.OrderDelete(ord.Ticket());
     }
  }

//+------------------------------------------------------------------+
//|                    POSITION SIZING                                  |
//+------------------------------------------------------------------+
double SizePosition(const int slP)
  {
   if(CfgSizeMethod == ASQ_LOT_FIXED)
      return Lot(CfgFixedVol);

   double bal = acct.Balance();
   double risk = (CfgSizeMethod == ASQ_LOT_PCT_BALANCE)
                 ? bal * CfgRiskPct / 100.0
                 : CfgRiskDollar;

   int sl = (slP > 0) ? slP : 100;
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pt = Pt_();
   if(tv <= 0 || ts <= 0 || pt <= 0) return Lot(CfgFixedVol);

   double vpp = tv * (pt / ts);
   return Lot(risk / (sl * vpp));
  }

double Lot(double v)
  {
   double mn = sym.LotsMin(), mx = sym.LotsMax(), st = sym.LotsStep();
   if(st <= 0) st = 0.01;
   v = MathFloor(v / st) * st;
   v = MathMax(v, mn);
   v = MathMin(v, mx);
   return NormalizeDouble(v, (int)MathCeil(-MathLog10(st)));
  }

int MaxStageDist()
  {
   int d = 0;
   if(CfgStage1Dist > d) d = CfgStage1Dist;
   if(CfgStage2Dist > d) d = CfgStage2Dist;
   if(CfgStage3Dist > d) d = CfgStage3Dist;
   return d;
  }

int MinStopDist()
  {
   int s = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int f = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   int d = MathMax(s, f);
   return (d < 1) ? 1 : d;
  }

//+------------------------------------------------------------------+
//|                    DASHBOARD                                       |
//+------------------------------------------------------------------+
void BuildPanel()
  {
   int x = CfgPanelX, y = CfgPanelY;
   int pw = 270, bh = 26, cw = 128, sp = 4, rh = 18;

   //--- background
   Rect(PFX + "BG", x - 6, y - 6, pw + 12, 10, CfgClrBG, CfgClrEdge);

   //--- title
   Lbl(PFX + "Title", x, y, "══ COMMAND DESK ══", CfgClrHead, CfgFontSz + 2);
   y += rh + 6;
   Lbl(PFX + "D0", x, y, "───────────────────────────", CfgClrEdge, CfgFontSz - 2);
   y += rh;

   //--- sizing readout
   Lbl(PFX + "SzInfo", x, y, "Vol: ...", CfgClrInfo, CfgFontSz); y += rh;
   Lbl(PFX + "RkInfo", x, y, "Risk: ...", CfgClrText, CfgFontSz); y += rh;
   Lbl(PFX + "RRInfo", x, y, "R:R  ...", CfgClrText, CfgFontSz); y += rh + 4;

   //--- LONG / SHORT
   Btn(BTN_GO_LONG,  x, y, cw, bh, "LONG",  CfgClrLong,  C'0,0,0');
   Btn(BTN_GO_SHORT, x + cw + sp + 4, y, cw, bh, "SHORT", CfgClrShort, C'255,255,255');
   y += bh + sp + 2;

   Lbl(PFX + "D1", x, y, "───────────────────────────", CfgClrEdge, CfgFontSz - 2);
   y += rh;

   //--- pending
   Lbl(PFX + "HP", x, y, "PENDING ORDERS", CfgClrHead, CfgFontSz); y += rh + 2;
   Btn(BTN_LIM_BUY,  x, y, cw, bh, "BUY LIMIT",  C'0,120,50',  C'200,255,220');
   Btn(BTN_LIM_SELL, x + cw + sp + 4, y, cw, bh, "SELL LIMIT", C'120,15,40', C'255,200,200');
   y += bh + sp;
   Btn(BTN_STP_BUY,  x, y, cw, bh, "BUY STOP",   C'0,100,40',  C'200,255,220');
   Btn(BTN_STP_SELL, x + cw + sp + 4, y, cw, bh, "SELL STOP",  C'100,10,30', C'255,200,200');
   y += bh + sp + 2;

   Lbl(PFX + "D2", x, y, "───────────────────────────", CfgClrEdge, CfgFontSz - 2);
   y += rh;

   //--- controls
   Lbl(PFX + "HC", x, y, "CONTROLS", CfgClrHead, CfgFontSz); y += rh + 2;
   Btn(BTN_NUKE, x, y, pw, bh, "NUKE ALL [X]", C'180,20,50', C'255,255,255'); y += bh + sp;
   Btn(BTN_CUT_LONG,  x, y, cw, bh, "Cut Long",  C'50,50,55', CfgClrLong);
   Btn(BTN_CUT_SHORT, x + cw + sp + 4, y, cw, bh, "Cut Short", C'50,50,55', CfgClrShort);
   y += bh + sp;
   Btn(BTN_WIPE_PEND, x, y, cw, bh, "Wipe Pend.", C'50,50,55', CfgClrText);
   Btn(BTN_LOCK_BE,   x + cw + sp + 4, y, cw, bh, "Lock B/E [E]", C'50,50,55', CfgClrInfo);
   y += bh + sp;
   Btn(BTN_REVERSE, x, y, pw, bh, "REVERSE [R]", C'140,80,200', C'255,255,255');
   y += bh + sp + 2;

   Lbl(PFX + "D3", x, y, "───────────────────────────", CfgClrEdge, CfgFontSz - 2);
   y += rh;

   //--- live metrics
   Lbl(PFX + "HM", x, y, "LIVE METRICS", CfgClrHead, CfgFontSz); y += rh + 2;
   Lbl(PFX + "mSpread",  x, y, "Spread: —",     CfgClrText, CfgFontSz); y += rh;
   Lbl(PFX + "mPos",     x, y, "Positions: —",  CfgClrText, CfgFontSz); y += rh;
   Lbl(PFX + "mExpo",    x, y, "Exposure: —",   CfgClrText, CfgFontSz); y += rh;
   Lbl(PFX + "mPnL",     x, y, "Float P&L: —",  CfgClrText, CfgFontSz); y += rh;
   Lbl(PFX + "mStage",   x, y, "Staged: —",     CfgClrText, CfgFontSz); y += rh;
   Lbl(PFX + "mTrail",   x, y, "Trail: —",      CfgClrText, CfgFontSz); y += rh;
   Lbl(PFX + "mDD",      x, y, "DD Guard: —",   CfgClrText, CfgFontSz); y += rh;
   Lbl(PFX + "mDay",     x, y, "Today: —",      CfgClrText, CfgFontSz); y += rh + 4;

   //--- hotkey legend
   if(CfgHotkeysOn)
     {
      Lbl(PFX + "HK", x, y, "Keys: B=Buy S=Sell X=Nuke R=Rev E=BE", C'60,65,80', CfgFontSz - 2);
      y += rh;
     }

   //--- branding
   Lbl(PFX + "Brand", x, y, "AlgoSphere Quant", C'50,55,70', CfgFontSz - 2);

   ObjectSetInteger(0, PFX + "BG", OBJPROP_YSIZE, y - CfgPanelY + rh + 12);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Live Dashboard Refresh                                             |
//+------------------------------------------------------------------+
void LiveUpdate()
  {
   double pt = Pt_();
   if(pt <= 0) pt = Pt_();

   //--- volume info
   double vol = SizePosition(CfgSLDist);
   string mStr = "";
   switch(CfgSizeMethod)
     {
      case ASQ_LOT_FIXED:       mStr = "Fixed";                              break;
      case ASQ_LOT_PCT_BALANCE: mStr = StringFormat("%.1f%%", CfgRiskPct);   break;
      case ASQ_LOT_FLAT_AMOUNT: mStr = StringFormat("$%.0f", CfgRiskDollar); break;
     }
   UL(PFX + "SzInfo", StringFormat("Vol: %.2f (%s | SL:%d)", vol, mStr, CfgSLDist), CfgClrInfo);

   //--- risk $
   double rDol = 0;
   if(CfgSizeMethod == ASQ_LOT_PCT_BALANCE)
      rDol = acct.Balance() * CfgRiskPct / 100.0;
   else if(CfgSizeMethod == ASQ_LOT_FLAT_AMOUNT)
      rDol = CfgRiskDollar;
   else
     {
      double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(ts > 0) rDol = CfgFixedVol * CfgSLDist * (tv * pt / ts);
     }
   UL(PFX + "RkInfo", StringFormat("Risk: $%.2f per trade", rDol), CfgClrText);

   //--- R:R ratio
   int maxTP = MaxStageDist();
   if(CfgSLDist > 0 && maxTP > 0)
     {
      double rr = (double)maxTP / (double)CfgSLDist;
      color rrC = (rr >= 2.0) ? CfgClrLong : (rr >= 1.0) ? C'255,215,0' : CfgClrShort;
      UL(PFX + "RRInfo", StringFormat("R:R  1:%.1f (SL:%d → TP:%d)", rr, CfgSLDist, maxTP), rrC);
     }
   else
      UL(PFX + "RRInfo", "R:R  N/A", CfgClrText);

   //--- spread
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   color spC = (spread < 20) ? CfgClrLong : (spread < 40) ? C'255,215,0' : CfgClrShort;
   UL(PFX + "mSpread", StringFormat("Spread: %d pts (%.1f pip)", spread, spread / 10.0), spC);

   //--- positions & PnL
   int nL = 0, nS = 0;
   double lotL = 0, lotS = 0, fPnL = 0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != CfgMagic) continue;
      double pnl = pos.Profit() + pos.Swap() + pos.Commission();
      fPnL += pnl;
      if(pos.PositionType() == POSITION_TYPE_BUY) { nL++; lotL += pos.Volume(); }
      else { nS++; lotS += pos.Volume(); }
     }

   UL(PFX + "mPos",  StringFormat("Pos: %d Long | %d Short", nL, nS), CfgClrText);
   UL(PFX + "mExpo", StringFormat("Expo: %.2f L | %.2f S", lotL, lotS), CfgClrText);

   color pC = (fPnL >= 0) ? CfgClrLong : CfgClrShort;
   UL(PFX + "mPnL", StringFormat("P&L: %s%.2f", (fPnL >= 0) ? "+" : "", fPnL), pC);

   //--- staged tracker
   int armed = ArraySize(tracks), s1c = 0, s2c = 0;
   for(int i = 0; i < armed; i++)
     { if(tracks[i].s1) s1c++; if(tracks[i].s2) s2c++; }
   UL(PFX + "mStage",
      StringFormat("Staged: %d | S1:%d S2:%d", armed, s1c, s2c), CfgClrInfo);

   //--- trail info
   string tI = "Off";
   switch(CfgTrailAlgo)
     {
      case ASQ_TRAIL_POINTS: tI = StringFormat("Pts %d", CfgTrailPtsDist); break;
      case ASQ_TRAIL_ATR:
        {
         double av = 0;
         if(hATR != INVALID_HANDLE && CopyBuffer(hATR, 0, 0, 1, atrBuf) > 0) av = atrBuf[0];
         tI = StringFormat("ATR(%.0f)x%.1f", av / pt, CfgATRScale);
         break;
        }
      case ASQ_TRAIL_SWING: tI = "Swing"; break;
     }
   UL(PFX + "mTrail",
      StringFormat("Trail: %s | BE:%s", tI,
                   CfgAutoBreakeven ? StringFormat("%dp", CfgBEActivation) : "Off"), CfgClrText);

   //--- drawdown guard
   if(CfgDDGuard)
     {
      double eq = acct.Equity();
      double ddP = (dd_sessionPeak > 0) ? (dd_sessionPeak - eq) / dd_sessionPeak * 100.0 : 0;
      color ddC = (ddP < CfgDDMaxPct * 0.5) ? CfgClrLong
                  : (ddP < CfgDDMaxPct) ? C'255,215,0' : CfgClrShort;
      UL(PFX + "mDD", StringFormat("DD: %.1f%% / %.1f%% %s",
                                    ddP, CfgDDMaxPct,
                                    dd_breached ? "⚠ BREACH" : "OK"), ddC);
     }
   else
      UL(PFX + "mDD", "DD Guard: Off", C'60,65,80');

   //--- daily trade counter
   UL(PFX + "mDay", StringFormat("Today: %d trades", dailyTradeCount), CfgClrText);
  }

//+------------------------------------------------------------------+
//|                    UI PRIMITIVES                                    |
//+------------------------------------------------------------------+
void Btn(const string n, int x, int y, int w, int h,
         const string txt, color bg, color fg)
  {
   ObjectCreate(0, n, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetString(0,  n, OBJPROP_TEXT, txt);
   ObjectSetString(0,  n, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, CfgFontSz);
   ObjectSetInteger(0, n, OBJPROP_COLOR, fg);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, n, OBJPROP_STATE, false);
  }

void Lbl(const string n, int x, int y, const string txt, color c, int sz)
  {
   ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetString(0,  n, OBJPROP_TEXT, txt);
   ObjectSetString(0,  n, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, sz);
   ObjectSetInteger(0, n, OBJPROP_COLOR, c);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
  }

void UL(const string n, const string txt, color c)
  {
   ObjectSetString(0, n, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR, c);
  }

void Rect(const string n, int x, int y, int w, int h, color bg, color bdr)
  {
   ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, bdr);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_BACK, false);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
  }
//+------------------------------------------------------------------+
