//+------------------------------------------------------------------+
//|                                      ExMachina_TradePilot.mq5    |
//|                        Copyright 2026, ExMachina Trading Systems  |
//|                        https://www.mql5.com/en/users/algosphere   |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, ExMachina Trading Systems"
#property link        "https://www.mql5.com/en/users/algosphere"
#property version     "1.00"
#property description "Professional order management panel: one-click trading,"
#property description "smart trailing (ATR/Breakeven/Partial), pending orders,"
#property description "and multi-TP system with real-time dashboard."
#property description "Precision before profit."

//+------------------------------------------------------------------+
//| Includes                                                          |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/AccountInfo.mqh>
#include <Trade/SymbolInfo.mqh>
#include <Trade/OrderInfo.mqh>

//+------------------------------------------------------------------+
//| Enums                                                             |
//+------------------------------------------------------------------+
enum ENUM_LOT_MODE
  {
   LOT_FIXED        = 0,   // Fixed lot
   LOT_RISK_PERCENT = 1,   // Risk % of balance
   LOT_RISK_MONEY   = 2    // Risk fixed amount
  };

enum ENUM_TRAIL_MODE
  {
   TRAIL_NONE       = 0,   // No trailing
   TRAIL_FIXED      = 1,   // Fixed points trailing
   TRAIL_ATR        = 2,   // ATR-based trailing
   TRAIL_CANDLE     = 3    // Previous candle high/low
  };

//+------------------------------------------------------------------+
//| Inputs                                                            |
//+------------------------------------------------------------------+
input group              "══════ LOT SIZING ══════"
input ENUM_LOT_MODE InpLotMode       = LOT_RISK_PERCENT; // Lot sizing mode
input double    InpFixedLot          = 0.01;   // Fixed lot size
input double    InpRiskPercent       = 1.0;    // Risk % per trade
input double    InpRiskMoney         = 100.0;  // Risk $ per trade

input group              "══════ STOP LOSS / TAKE PROFIT ══════"
input int       InpDefaultSL         = 200;    // Default SL (points, 0=none)
input int       InpTP1_Points        = 150;    // TP1 distance (points, 0=off)
input int       InpTP2_Points        = 300;    // TP2 distance (points, 0=off)
input int       InpTP3_Points        = 500;    // TP3 distance (points, 0=off)
input double    InpTP1_ClosePct      = 40.0;   // TP1 close % of volume
input double    InpTP2_ClosePct      = 30.0;   // TP2 close % of volume
input double    InpTP3_ClosePct      = 100.0;  // TP3 close % (remainder)

input group              "══════ TRAILING STOP ══════"
input ENUM_TRAIL_MODE InpTrailMode   = TRAIL_ATR;  // Trailing mode
input int       InpTrailPoints       = 150;    // Fixed trail distance (points)
input int       InpTrailStep         = 10;     // Min step to move SL (points)
input int       InpATR_Period        = 14;     // ATR period
input double    InpATR_Multiplier    = 1.5;    // ATR multiplier for trail
input bool      InpBreakevenEnabled  = true;   // Enable breakeven
input int       InpBreakevenTrigger  = 100;    // Breakeven trigger (points profit)
input int       InpBreakevenOffset   = 5;      // Breakeven offset (points above entry)

input group              "══════ PENDING ORDERS ══════"
input int       InpPendingOffset     = 100;    // Default pending offset from price (points)
input int       InpPendingSL         = 200;    // Pending order SL (points)
input int       InpPendingTP         = 400;    // Pending order TP (points)
input datetime  InpPendingExpiry     = 0;      // Pending expiry (0=GTC)

input group              "══════ PANEL SETTINGS ══════"
input int       InpPanelX            = 15;     // Panel X position
input int       InpPanelY            = 25;     // Panel Y position
input int       InpFontSize          = 9;      // Font size
input color     InpPanelBg           = C'14,17,24';   // Panel background
input color     InpBuyColor          = C'0,200,83';   // Buy button color
input color     InpSellColor         = C'255,23,68';  // Sell button color
input color     InpNeutralColor      = C'90,180,250'; // Neutral/info color
input color     InpTextColor         = C'180,185,195';// Text color
input color     InpHeaderColor       = C'90,180,250'; // Header color
input color     InpBorderColor       = C'30,35,50';   // Border color

input group              "══════ ADVANCED ══════"
input int       InpMagic             = 777777; // Magic number
input int       InpSlippage          = 20;     // Max slippage (points)
input string    InpComment           = "EXTP"; // Order comment prefix

//+------------------------------------------------------------------+
//| Constants                                                         |
//+------------------------------------------------------------------+
const string OBJ_PREFIX = "EXTP_";
const string EA_NAME    = "ExMachina Trade Pilot";

//--- button names
const string BTN_BUY        = OBJ_PREFIX + "BtnBuy";
const string BTN_SELL       = OBJ_PREFIX + "BtnSell";
const string BTN_BUYLIMIT   = OBJ_PREFIX + "BtnBuyLimit";
const string BTN_SELLLIMIT  = OBJ_PREFIX + "BtnSellLimit";
const string BTN_BUYSTOP    = OBJ_PREFIX + "BtnBuyStop";
const string BTN_SELLSTOP   = OBJ_PREFIX + "BtnSellStop";
const string BTN_CLOSEALL   = OBJ_PREFIX + "BtnCloseAll";
const string BTN_CLOSEBUY   = OBJ_PREFIX + "BtnCloseBuy";
const string BTN_CLOSESELL  = OBJ_PREFIX + "BtnCloseSell";
const string BTN_DELPENDING = OBJ_PREFIX + "BtnDelPending";
const string BTN_BREAKEVEN  = OBJ_PREFIX + "BtnBE";

//+------------------------------------------------------------------+
//| Globals                                                           |
//+------------------------------------------------------------------+
CTrade         g_trade;
CPositionInfo  g_pos;
CAccountInfo   g_account;
CSymbolInfo    g_sym;
COrderInfo     g_order;

int            g_atrHandle = INVALID_HANDLE;
double         g_atrBuffer[];

//--- multi-TP tracking: store original volume keyed by ticket
struct TP_TRACK
  {
   ulong          ticket;
   double         origVolume;
   double         entryPrice;
   ENUM_POSITION_TYPE direction;
   bool           tp1Hit;
   bool           tp2Hit;
   bool           tp3Hit;
  };

TP_TRACK       g_tpTracks[];

//+------------------------------------------------------------------+
//| Expert initialization                                              |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_sym.Name(_Symbol);
   g_sym.Refresh();

   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(InpSlippage);

   //--- ATR indicator
   if(InpTrailMode == TRAIL_ATR)
     {
      g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpATR_Period);
      if(g_atrHandle == INVALID_HANDLE)
         PrintFormat("%s: Failed to create ATR handle", EA_NAME);
     }

   ArraySetAsSeries(g_atrBuffer, true);

   //--- build panel
   CreatePanel();

   //--- scan existing positions for TP tracking
   ScanExistingPositions();

   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   PrintFormat("%s initialized on %s", EA_NAME, _Symbol);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization                                            |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, OBJ_PREFIX);
   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);
  }

//+------------------------------------------------------------------+
//| Tick function                                                      |
//+------------------------------------------------------------------+
void OnTick()
  {
   g_sym.Refresh();

   //--- trailing stop management
   if(InpTrailMode != TRAIL_NONE)
      ManageTrailing();

   //--- breakeven management
   if(InpBreakevenEnabled)
      ManageBreakeven();

   //--- multi-TP management
   ManageMultiTP();

   //--- update dashboard info
   UpdateInfoLabels();
  }

//+------------------------------------------------------------------+
//| Chart event handler (button clicks)                                |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   if(id != CHARTEVENT_OBJECT_CLICK) return;

   //--- reset button state
   ObjectSetInteger(0, sparam, OBJPROP_STATE, false);

   if(sparam == BTN_BUY)         ExecuteMarketOrder(ORDER_TYPE_BUY);
   else if(sparam == BTN_SELL)   ExecuteMarketOrder(ORDER_TYPE_SELL);
   else if(sparam == BTN_BUYLIMIT)  PlacePendingOrder(ORDER_TYPE_BUY_LIMIT);
   else if(sparam == BTN_SELLLIMIT) PlacePendingOrder(ORDER_TYPE_SELL_LIMIT);
   else if(sparam == BTN_BUYSTOP)   PlacePendingOrder(ORDER_TYPE_BUY_STOP);
   else if(sparam == BTN_SELLSTOP)  PlacePendingOrder(ORDER_TYPE_SELL_STOP);
   else if(sparam == BTN_CLOSEALL)  CloseAllPositions();
   else if(sparam == BTN_CLOSEBUY)  CloseByDirection(POSITION_TYPE_BUY);
   else if(sparam == BTN_CLOSESELL) CloseByDirection(POSITION_TYPE_SELL);
   else if(sparam == BTN_DELPENDING) DeleteAllPendings();
   else if(sparam == BTN_BREAKEVEN)  ApplyBreakevenAll();

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//|                    ORDER EXECUTION                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Execute market order with auto lot and multi-TP                    |
//+------------------------------------------------------------------+
void ExecuteMarketOrder(const ENUM_ORDER_TYPE type)
  {
   g_sym.Refresh();
   double point = g_sym.Point();
   double ask   = g_sym.Ask();
   double bid   = g_sym.Bid();

   double price = (type == ORDER_TYPE_BUY) ? ask : bid;
   double sl    = 0;
   double tp    = 0;

   //--- SL
   if(InpDefaultSL > 0)
     {
      if(type == ORDER_TYPE_BUY)
         sl = NormalizeDouble(price - InpDefaultSL * point, g_sym.Digits());
      else
         sl = NormalizeDouble(price + InpDefaultSL * point, g_sym.Digits());
     }

   //--- TP: use furthest TP for broker TP level, partials handled internally
   int furthestTP = GetFurthestTP();
   if(furthestTP > 0)
     {
      if(type == ORDER_TYPE_BUY)
         tp = NormalizeDouble(price + furthestTP * point, g_sym.Digits());
      else
         tp = NormalizeDouble(price - furthestTP * point, g_sym.Digits());
     }

   //--- lot calculation
   double lot = CalculateLot(InpDefaultSL);

   //--- send order
   string comment = StringFormat("%s_%s", InpComment, (type == ORDER_TYPE_BUY) ? "BUY" : "SELL");
   bool result = false;

   if(type == ORDER_TYPE_BUY)
      result = g_trade.Buy(lot, _Symbol, price, sl, tp, comment);
   else
      result = g_trade.Sell(lot, _Symbol, price, sl, tp, comment);

   if(result && g_trade.ResultDeal() > 0)
     {
      //--- register for multi-TP tracking
      ulong ticket = g_trade.ResultOrder();
      //--- need to wait for position to appear
      Sleep(100);
      RegisterTPTrack(price, lot, (type == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);
      PrintFormat("%s: %s %.2f lots @ %.5f SL:%.5f TP:%.5f",
                  EA_NAME, EnumToString(type), lot, price, sl, tp);
     }
   else
      PrintFormat("%s: Order failed. Error: %d", EA_NAME, GetLastError());
  }

//+------------------------------------------------------------------+
//| Place pending order                                                |
//+------------------------------------------------------------------+
void PlacePendingOrder(const ENUM_ORDER_TYPE type)
  {
   g_sym.Refresh();
   double point = g_sym.Point();
   double ask   = g_sym.Ask();
   double bid   = g_sym.Bid();
   double price = 0;
   double sl    = 0;
   double tp    = 0;

   //--- calculate pending price
   switch(type)
     {
      case ORDER_TYPE_BUY_LIMIT:
         price = NormalizeDouble(ask - InpPendingOffset * point, g_sym.Digits());
         sl = (InpPendingSL > 0) ? NormalizeDouble(price - InpPendingSL * point, g_sym.Digits()) : 0;
         tp = (InpPendingTP > 0) ? NormalizeDouble(price + InpPendingTP * point, g_sym.Digits()) : 0;
         break;
      case ORDER_TYPE_SELL_LIMIT:
         price = NormalizeDouble(bid + InpPendingOffset * point, g_sym.Digits());
         sl = (InpPendingSL > 0) ? NormalizeDouble(price + InpPendingSL * point, g_sym.Digits()) : 0;
         tp = (InpPendingTP > 0) ? NormalizeDouble(price - InpPendingTP * point, g_sym.Digits()) : 0;
         break;
      case ORDER_TYPE_BUY_STOP:
         price = NormalizeDouble(ask + InpPendingOffset * point, g_sym.Digits());
         sl = (InpPendingSL > 0) ? NormalizeDouble(price - InpPendingSL * point, g_sym.Digits()) : 0;
         tp = (InpPendingTP > 0) ? NormalizeDouble(price + InpPendingTP * point, g_sym.Digits()) : 0;
         break;
      case ORDER_TYPE_SELL_STOP:
         price = NormalizeDouble(bid - InpPendingOffset * point, g_sym.Digits());
         sl = (InpPendingSL > 0) ? NormalizeDouble(price + InpPendingSL * point, g_sym.Digits()) : 0;
         tp = (InpPendingTP > 0) ? NormalizeDouble(price - InpPendingTP * point, g_sym.Digits()) : 0;
         break;
     }

   double lot = CalculateLot(InpPendingSL);
   string comment = StringFormat("%s_PEND", InpComment);

   if(g_trade.OrderOpen(_Symbol, type, lot, price, price, sl, tp,
                        ORDER_TIME_GTC, InpPendingExpiry, comment))
      PrintFormat("%s: Pending %s %.2f @ %.5f", EA_NAME, EnumToString(type), lot, price);
   else
      PrintFormat("%s: Pending failed. Error: %d", EA_NAME, GetLastError());
  }

//+------------------------------------------------------------------+
//|                    MULTI-TP SYSTEM                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Register a new position for multi-TP tracking                      |
//+------------------------------------------------------------------+
void RegisterTPTrack(const double entryPrice,
                     const double volume,
                     const ENUM_POSITION_TYPE direction)
  {
   //--- find the position ticket
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Symbol() != _Symbol) continue;
      if(g_pos.Magic() != InpMagic) continue;

      ulong ticket = g_pos.Ticket();

      //--- check not already tracked
      bool exists = false;
      for(int j = 0; j < ArraySize(g_tpTracks); j++)
        {
         if(g_tpTracks[j].ticket == ticket) { exists = true; break; }
        }
      if(exists) continue;

      //--- add to tracking
      int idx = ArraySize(g_tpTracks);
      ArrayResize(g_tpTracks, idx + 1);
      g_tpTracks[idx].ticket     = ticket;
      g_tpTracks[idx].origVolume = volume;
      g_tpTracks[idx].entryPrice = entryPrice;
      g_tpTracks[idx].direction  = direction;
      g_tpTracks[idx].tp1Hit     = false;
      g_tpTracks[idx].tp2Hit     = false;
      g_tpTracks[idx].tp3Hit     = false;
      return;
     }
  }

//+------------------------------------------------------------------+
//| Scan existing positions on init                                    |
//+------------------------------------------------------------------+
void ScanExistingPositions()
  {
   ArrayResize(g_tpTracks, 0);
   for(int i = 0; i < PositionsTotal(); i++)
     {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Symbol() != _Symbol) continue;
      if(g_pos.Magic() != InpMagic) continue;

      int idx = ArraySize(g_tpTracks);
      ArrayResize(g_tpTracks, idx + 1);
      g_tpTracks[idx].ticket     = g_pos.Ticket();
      g_tpTracks[idx].origVolume = g_pos.Volume();
      g_tpTracks[idx].entryPrice = g_pos.PriceOpen();
      g_tpTracks[idx].direction  = g_pos.PositionType();
      g_tpTracks[idx].tp1Hit     = false;
      g_tpTracks[idx].tp2Hit     = false;
      g_tpTracks[idx].tp3Hit     = false;
     }
  }

//+------------------------------------------------------------------+
//| Manage multi-TP partial closes                                     |
//+------------------------------------------------------------------+
void ManageMultiTP()
  {
   double point = g_sym.Point();

   for(int i = ArraySize(g_tpTracks) - 1; i >= 0; i--)
     {
      ulong ticket = g_tpTracks[i].ticket;

      //--- check position still exists
      if(!PositionSelectByTicket(ticket))
        {
         RemoveTPTrack(i);
         continue;
        }

      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double entryPrice   = g_tpTracks[i].entryPrice;
      double origVol      = g_tpTracks[i].origVolume;
      double currentVol   = PositionGetDouble(POSITION_VOLUME);
      ENUM_POSITION_TYPE dir = g_tpTracks[i].direction;

      //--- calculate profit in points
      double profitPoints = 0;
      if(dir == POSITION_TYPE_BUY)
         profitPoints = (currentPrice - entryPrice) / point;
      else
         profitPoints = (entryPrice - currentPrice) / point;

      //--- TP1
      if(!g_tpTracks[i].tp1Hit && InpTP1_Points > 0 && profitPoints >= InpTP1_Points)
        {
         double closeVol = NormalizeLot(origVol * InpTP1_ClosePct / 100.0);
         if(closeVol >= g_sym.LotsMin() && closeVol <= currentVol)
           {
            if(g_trade.PositionClosePartial(ticket, closeVol, InpSlippage))
              {
               g_tpTracks[i].tp1Hit = true;
               PrintFormat("%s: TP1 hit! Closed %.2f lots on #%I64u", EA_NAME, closeVol, ticket);
              }
           }
         else
            g_tpTracks[i].tp1Hit = true; // skip if too small
        }

      //--- TP2
      if(!g_tpTracks[i].tp2Hit && g_tpTracks[i].tp1Hit &&
         InpTP2_Points > 0 && profitPoints >= InpTP2_Points)
        {
         currentVol = PositionGetDouble(POSITION_VOLUME);
         double closeVol = NormalizeLot(origVol * InpTP2_ClosePct / 100.0);
         if(closeVol >= g_sym.LotsMin() && closeVol <= currentVol)
           {
            if(g_trade.PositionClosePartial(ticket, closeVol, InpSlippage))
              {
               g_tpTracks[i].tp2Hit = true;
               PrintFormat("%s: TP2 hit! Closed %.2f lots on #%I64u", EA_NAME, closeVol, ticket);
              }
           }
         else
            g_tpTracks[i].tp2Hit = true;
        }

      //--- TP3: close remainder
      if(!g_tpTracks[i].tp3Hit && g_tpTracks[i].tp2Hit &&
         InpTP3_Points > 0 && profitPoints >= InpTP3_Points)
        {
         if(g_trade.PositionClose(ticket, InpSlippage))
           {
            g_tpTracks[i].tp3Hit = true;
            PrintFormat("%s: TP3 hit! Fully closed #%I64u", EA_NAME, ticket);
            RemoveTPTrack(i);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Remove a TP track entry                                            |
//+------------------------------------------------------------------+
void RemoveTPTrack(const int index)
  {
   int total = ArraySize(g_tpTracks);
   if(index < 0 || index >= total) return;
   for(int i = index; i < total - 1; i++)
      g_tpTracks[i] = g_tpTracks[i + 1];
   ArrayResize(g_tpTracks, total - 1);
  }

//+------------------------------------------------------------------+
//|                    TRAILING STOP                                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Manage trailing stop for all positions                             |
//+------------------------------------------------------------------+
void ManageTrailing()
  {
   double point = g_sym.Point();

   //--- get ATR if needed
   double atrValue = 0;
   if(InpTrailMode == TRAIL_ATR && g_atrHandle != INVALID_HANDLE)
     {
      if(CopyBuffer(g_atrHandle, 0, 0, 1, g_atrBuffer) > 0)
         atrValue = g_atrBuffer[0];
     }

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Symbol() != _Symbol) continue;
      if(g_pos.Magic() != InpMagic) continue;

      double currentSL    = g_pos.StopLoss();
      double currentTP    = g_pos.TakeProfit();
      double openPrice    = g_pos.PriceOpen();
      double currentPrice = g_pos.PriceCurrent();
      ulong  ticket       = g_pos.Ticket();

      double trailDist = 0;

      switch(InpTrailMode)
        {
         case TRAIL_FIXED:
            trailDist = InpTrailPoints * point;
            break;
         case TRAIL_ATR:
            trailDist = atrValue * InpATR_Multiplier;
            break;
         case TRAIL_CANDLE:
            trailDist = GetCandleTrailDistance(g_pos.PositionType());
            break;
         default:
            continue;
        }

      if(trailDist <= 0) continue;

      double newSL = 0;

      if(g_pos.PositionType() == POSITION_TYPE_BUY)
        {
         newSL = NormalizeDouble(currentPrice - trailDist, g_sym.Digits());
         //--- only move SL up, never down
         if(newSL <= currentSL && currentSL > 0) continue;
         //--- must be above entry (or no existing SL)
         if(newSL <= openPrice) continue;
         //--- min step check
         if(currentSL > 0 && (newSL - currentSL) < InpTrailStep * point) continue;
        }
      else
        {
         newSL = NormalizeDouble(currentPrice + trailDist, g_sym.Digits());
         if(newSL >= currentSL && currentSL > 0) continue;
         if(newSL >= openPrice) continue;
         if(currentSL > 0 && (currentSL - newSL) < InpTrailStep * point) continue;
        }

      if(g_trade.PositionModify(ticket, newSL, currentTP))
         PrintFormat("%s: Trail SL moved to %.5f on #%I64u", EA_NAME, newSL, ticket);
     }
  }

//+------------------------------------------------------------------+
//| Get trail distance from previous candle                            |
//+------------------------------------------------------------------+
double GetCandleTrailDistance(const ENUM_POSITION_TYPE dir)
  {
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   if(CopyHigh(_Symbol, PERIOD_CURRENT, 1, 1, high) < 1) return 0;
   if(CopyLow(_Symbol, PERIOD_CURRENT, 1, 1, low) < 1)   return 0;

   double currentPrice = (dir == POSITION_TYPE_BUY) ? g_sym.Bid() : g_sym.Ask();

   if(dir == POSITION_TYPE_BUY)
      return currentPrice - low[0];
   else
      return high[0] - currentPrice;
  }

//+------------------------------------------------------------------+
//|                    BREAKEVEN                                        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Manage breakeven for all positions                                 |
//+------------------------------------------------------------------+
void ManageBreakeven()
  {
   double point = g_sym.Point();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Symbol() != _Symbol) continue;
      if(g_pos.Magic() != InpMagic) continue;

      double openPrice = g_pos.PriceOpen();
      double currentSL = g_pos.StopLoss();
      double currentTP = g_pos.TakeProfit();
      double bid       = g_sym.Bid();
      double ask       = g_sym.Ask();
      ulong  ticket    = g_pos.Ticket();

      if(g_pos.PositionType() == POSITION_TYPE_BUY)
        {
         double profitPts = (bid - openPrice) / point;
         double beSL = NormalizeDouble(openPrice + InpBreakevenOffset * point, g_sym.Digits());
         if(profitPts >= InpBreakevenTrigger && (currentSL < beSL || currentSL == 0))
           {
            if(g_trade.PositionModify(ticket, beSL, currentTP))
               PrintFormat("%s: Breakeven set at %.5f on #%I64u", EA_NAME, beSL, ticket);
           }
        }
      else
        {
         double profitPts = (openPrice - ask) / point;
         double beSL = NormalizeDouble(openPrice - InpBreakevenOffset * point, g_sym.Digits());
         if(profitPts >= InpBreakevenTrigger && (currentSL > beSL || currentSL == 0))
           {
            if(g_trade.PositionModify(ticket, beSL, currentTP))
               PrintFormat("%s: Breakeven set at %.5f on #%I64u", EA_NAME, beSL, ticket);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Apply breakeven to all positions (button)                          |
//+------------------------------------------------------------------+
void ApplyBreakevenAll()
  {
   double point = g_sym.Point();
   int count = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Symbol() != _Symbol) continue;
      if(g_pos.Magic() != InpMagic) continue;

      double openPrice = g_pos.PriceOpen();
      double currentSL = g_pos.StopLoss();
      double currentTP = g_pos.TakeProfit();
      ulong  ticket    = g_pos.Ticket();

      double beSL = 0;
      if(g_pos.PositionType() == POSITION_TYPE_BUY)
         beSL = NormalizeDouble(openPrice + InpBreakevenOffset * point, g_sym.Digits());
      else
         beSL = NormalizeDouble(openPrice - InpBreakevenOffset * point, g_sym.Digits());

      bool inProfit = false;
      if(g_pos.PositionType() == POSITION_TYPE_BUY)
         inProfit = g_sym.Bid() > beSL;
      else
         inProfit = g_sym.Ask() < beSL;

      if(inProfit && g_trade.PositionModify(ticket, beSL, currentTP))
         count++;
     }

   PrintFormat("%s: Breakeven applied to %d positions", EA_NAME, count);
  }

//+------------------------------------------------------------------+
//|                    CLOSE / DELETE                                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Close all positions                                                |
//+------------------------------------------------------------------+
void CloseAllPositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Symbol() != _Symbol) continue;
      if(g_pos.Magic() != InpMagic) continue;
      g_trade.PositionClose(g_pos.Ticket(), InpSlippage);
     }
  }

//+------------------------------------------------------------------+
//| Close positions by direction                                       |
//+------------------------------------------------------------------+
void CloseByDirection(const ENUM_POSITION_TYPE dir)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Symbol() != _Symbol) continue;
      if(g_pos.Magic() != InpMagic) continue;
      if(g_pos.PositionType() != dir) continue;
      g_trade.PositionClose(g_pos.Ticket(), InpSlippage);
     }
  }

//+------------------------------------------------------------------+
//| Delete all pending orders                                          |
//+------------------------------------------------------------------+
void DeleteAllPendings()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!g_order.SelectByIndex(i)) continue;
      if(g_order.Symbol() != _Symbol) continue;
      if(g_order.Magic() != InpMagic) continue;
      g_trade.OrderDelete(g_order.Ticket());
     }
  }

//+------------------------------------------------------------------+
//|                    LOT CALCULATION                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate lot based on risk settings                                |
//+------------------------------------------------------------------+
double CalculateLot(const int slPoints)
  {
   if(InpLotMode == LOT_FIXED)
      return NormalizeLot(InpFixedLot);

   double balance   = g_account.Balance();
   double riskMoney = 0;

   if(InpLotMode == LOT_RISK_PERCENT)
      riskMoney = balance * InpRiskPercent / 100.0;
   else
      riskMoney = InpRiskMoney;

   int sl = (slPoints > 0) ? slPoints : 100;

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pointVal  = g_sym.Point();

   if(tickValue <= 0 || tickSize <= 0 || pointVal <= 0)
      return NormalizeLot(InpFixedLot);

   double valuePerPoint = tickValue * (pointVal / tickSize);
   double rawLot = riskMoney / (sl * valuePerPoint);

   return NormalizeLot(rawLot);
  }

//+------------------------------------------------------------------+
//| Normalize lot to broker constraints                                |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
  {
   double minLot  = g_sym.LotsMin();
   double maxLot  = g_sym.LotsMax();
   double lotStep = g_sym.LotsStep();
   if(lotStep <= 0) lotStep = 0.01;

   lot = MathFloor(lot / lotStep) * lotStep;
   lot = MathMax(lot, minLot);
   lot = MathMin(lot, maxLot);
   return NormalizeDouble(lot, (int)MathCeil(-MathLog10(lotStep)));
  }

//+------------------------------------------------------------------+
//| Get furthest TP in points                                          |
//+------------------------------------------------------------------+
int GetFurthestTP()
  {
   int tp = 0;
   if(InpTP1_Points > tp) tp = InpTP1_Points;
   if(InpTP2_Points > tp) tp = InpTP2_Points;
   if(InpTP3_Points > tp) tp = InpTP3_Points;
   return tp;
  }

//+------------------------------------------------------------------+
//|                    PANEL / UI                                       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create the full trading panel                                      |
//+------------------------------------------------------------------+
void CreatePanel()
  {
   int x = InpPanelX;
   int y = InpPanelY;
   int panelW = 260;
   int btnH   = 26;
   int halfW  = 124;
   int gap    = 4;
   int lineH  = 18;

   //--- background
   CreateRect(OBJ_PREFIX + "PanelBG", x - 6, y - 6, panelW + 12, 540, InpPanelBg, InpBorderColor);

   //--- title
   CreateLabel(OBJ_PREFIX + "Title", x, y, "══ TRADE PILOT ══", InpHeaderColor, InpFontSize + 2);
   y += lineH + 6;
   CreateLabel(OBJ_PREFIX + "Sep0", x, y, "──────────────────────────", InpBorderColor, InpFontSize - 2);
   y += lineH;

   //--- lot info line
   CreateLabel(OBJ_PREFIX + "LotInfo", x, y, "Lot: calculating...", InpNeutralColor, InpFontSize);
   y += lineH;
   CreateLabel(OBJ_PREFIX + "RiskInfo", x, y, "Risk: calculating...", InpTextColor, InpFontSize);
   y += lineH + 4;

   //--- BUY / SELL
   CreateButton(BTN_BUY,  x, y, halfW, btnH, "BUY", InpBuyColor, C'0,0,0');
   CreateButton(BTN_SELL, x + halfW + gap + 4, y, halfW, btnH, "SELL", InpSellColor, C'255,255,255');
   y += btnH + gap + 2;

   CreateLabel(OBJ_PREFIX + "Sep1", x, y, "──────────────────────────", InpBorderColor, InpFontSize - 2);
   y += lineH;

   //--- Pending orders section
   CreateLabel(OBJ_PREFIX + "PendTitle", x, y, "PENDING ORDERS", InpHeaderColor, InpFontSize);
   y += lineH + 2;

   CreateButton(BTN_BUYLIMIT,  x, y, halfW, btnH, "BUY LIMIT", C'0,120,50', C'200,255,220');
   CreateButton(BTN_SELLLIMIT, x + halfW + gap + 4, y, halfW, btnH, "SELL LIMIT", C'120,15,40', C'255,200,200');
   y += btnH + gap;

   CreateButton(BTN_BUYSTOP,  x, y, halfW, btnH, "BUY STOP", C'0,100,40', C'200,255,220');
   CreateButton(BTN_SELLSTOP, x + halfW + gap + 4, y, halfW, btnH, "SELL STOP", C'100,10,30', C'255,200,200');
   y += btnH + gap + 2;

   CreateLabel(OBJ_PREFIX + "Sep2", x, y, "──────────────────────────", InpBorderColor, InpFontSize - 2);
   y += lineH;

   //--- Management section
   CreateLabel(OBJ_PREFIX + "MgmtTitle", x, y, "MANAGEMENT", InpHeaderColor, InpFontSize);
   y += lineH + 2;

   CreateButton(BTN_CLOSEALL, x, y, panelW, btnH, "CLOSE ALL", C'180,20,50', C'255,255,255');
   y += btnH + gap;

   CreateButton(BTN_CLOSEBUY,  x, y, halfW, btnH, "Close Buy", C'50,50,55', InpBuyColor);
   CreateButton(BTN_CLOSESELL, x + halfW + gap + 4, y, halfW, btnH, "Close Sell", C'50,50,55', InpSellColor);
   y += btnH + gap;

   CreateButton(BTN_DELPENDING, x, y, halfW, btnH, "Del Pending", C'50,50,55', InpTextColor);
   CreateButton(BTN_BREAKEVEN,  x + halfW + gap + 4, y, halfW, btnH, "Set B/E", C'50,50,55', InpNeutralColor);
   y += btnH + gap + 2;

   CreateLabel(OBJ_PREFIX + "Sep3", x, y, "──────────────────────────", InpBorderColor, InpFontSize - 2);
   y += lineH;

   //--- Info section
   CreateLabel(OBJ_PREFIX + "InfoTitle", x, y, "LIVE STATUS", InpHeaderColor, InpFontSize);
   y += lineH + 2;

   CreateLabel(OBJ_PREFIX + "InfoSpread",  x, y, "Spread: —", InpTextColor, InpFontSize); y += lineH;
   CreateLabel(OBJ_PREFIX + "InfoPos",     x, y, "Positions: —", InpTextColor, InpFontSize); y += lineH;
   CreateLabel(OBJ_PREFIX + "InfoLots",    x, y, "Exposure: —", InpTextColor, InpFontSize); y += lineH;
   CreateLabel(OBJ_PREFIX + "InfoPnL",     x, y, "Float P&L: —", InpTextColor, InpFontSize); y += lineH;
   CreateLabel(OBJ_PREFIX + "InfoTP",      x, y, "TP Tracker: —", InpTextColor, InpFontSize); y += lineH;
   CreateLabel(OBJ_PREFIX + "InfoTrail",   x, y, "Trail: —", InpTextColor, InpFontSize); y += lineH + 4;

   //--- branding
   CreateLabel(OBJ_PREFIX + "Brand", x, y, "ExMachina Trading Systems", C'50,55,70', InpFontSize - 2);

   //--- resize bg
   ObjectSetInteger(0, OBJ_PREFIX + "PanelBG", OBJPROP_YSIZE, y - InpPanelY + lineH + 12);

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Update live info labels                                            |
//+------------------------------------------------------------------+
void UpdateInfoLabels()
  {
   double point = g_sym.Point();

   //--- lot info
   double lot = CalculateLot(InpDefaultSL);
   string lotMode = "";
   switch(InpLotMode)
     {
      case LOT_FIXED:        lotMode = "Fixed"; break;
      case LOT_RISK_PERCENT: lotMode = StringFormat("%.1f%%", InpRiskPercent); break;
      case LOT_RISK_MONEY:   lotMode = StringFormat("$%.0f", InpRiskMoney); break;
     }
   UpdateLabel(OBJ_PREFIX + "LotInfo",
               StringFormat("Lot: %.2f (%s | SL:%d pts)", lot, lotMode, InpDefaultSL),
               InpNeutralColor);

   //--- risk in money
   double riskMoney = 0;
   if(InpLotMode == LOT_RISK_PERCENT)
      riskMoney = g_account.Balance() * InpRiskPercent / 100.0;
   else if(InpLotMode == LOT_RISK_MONEY)
      riskMoney = InpRiskMoney;
   else
     {
      double tvp = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double ts  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(ts > 0)
         riskMoney = InpFixedLot * InpDefaultSL * (tvp * point / ts);
     }
   UpdateLabel(OBJ_PREFIX + "RiskInfo",
               StringFormat("Risk: $%.2f per trade", riskMoney), InpTextColor);

   //--- spread
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   color spClr = (spread < 20) ? InpBuyColor : (spread < 40) ? C'255,215,0' : InpSellColor;
   UpdateLabel(OBJ_PREFIX + "InfoSpread",
               StringFormat("Spread: %d pts (%.1f pips)", spread, spread / 10.0), spClr);

   //--- positions
   int posBuy = 0, posSell = 0;
   double lotsBuy = 0, lotsSell = 0, totalPnL = 0;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Symbol() != _Symbol) continue;
      if(g_pos.Magic() != InpMagic) continue;

      double pnl = g_pos.Profit() + g_pos.Swap() + g_pos.Commission();
      totalPnL += pnl;

      if(g_pos.PositionType() == POSITION_TYPE_BUY)
        { posBuy++; lotsBuy += g_pos.Volume(); }
      else
        { posSell++; lotsSell += g_pos.Volume(); }
     }

   UpdateLabel(OBJ_PREFIX + "InfoPos",
               StringFormat("Positions: %d Buy | %d Sell", posBuy, posSell), InpTextColor);
   UpdateLabel(OBJ_PREFIX + "InfoLots",
               StringFormat("Exposure: %.2f B | %.2f S", lotsBuy, lotsSell), InpTextColor);

   color pnlClr = (totalPnL >= 0) ? InpBuyColor : InpSellColor;
   UpdateLabel(OBJ_PREFIX + "InfoPnL",
               StringFormat("Float P&L: %s%.2f", (totalPnL >= 0) ? "+" : "", totalPnL), pnlClr);

   //--- TP tracker
   int tracked = ArraySize(g_tpTracks);
   int tp1Count = 0, tp2Count = 0;
   for(int i = 0; i < tracked; i++)
     {
      if(g_tpTracks[i].tp1Hit) tp1Count++;
      if(g_tpTracks[i].tp2Hit) tp2Count++;
     }
   UpdateLabel(OBJ_PREFIX + "InfoTP",
               StringFormat("TP Track: %d pos | TP1:%d TP2:%d", tracked, tp1Count, tp2Count),
               InpNeutralColor);

   //--- trailing info
   string trailTxt = "None";
   switch(InpTrailMode)
     {
      case TRAIL_FIXED: trailTxt = StringFormat("Fixed %d pts", InpTrailPoints); break;
      case TRAIL_ATR:
        {
         double atr = 0;
         if(g_atrHandle != INVALID_HANDLE && CopyBuffer(g_atrHandle, 0, 0, 1, g_atrBuffer) > 0)
            atr = g_atrBuffer[0];
         trailTxt = StringFormat("ATR(%.0f) x%.1f", atr / point, InpATR_Multiplier);
         break;
        }
      case TRAIL_CANDLE: trailTxt = "Prev Candle"; break;
     }
   UpdateLabel(OBJ_PREFIX + "InfoTrail",
               StringFormat("Trail: %s | BE:%s",
                            trailTxt,
                            InpBreakevenEnabled ? StringFormat("%dpts", InpBreakevenTrigger) : "Off"),
               InpTextColor);
  }

//+------------------------------------------------------------------+
//|                    UI HELPERS                                       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create a button                                                    |
//+------------------------------------------------------------------+
void CreateButton(const string name, int x, int y, int w, int h,
                  const string text, color bgClr, color txtClr)
  {
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0,  name, OBJPROP_TEXT, text);
   ObjectSetString(0,  name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, txtClr);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgClr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, bgClr);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
  }

//+------------------------------------------------------------------+
//| Create a label                                                     |
//+------------------------------------------------------------------+
void CreateLabel(const string name, int x, int y,
                 const string text, color clr, int fontSize)
  {
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0,  name, OBJPROP_TEXT, text);
   ObjectSetString(0,  name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//| Update a label                                                     |
//+------------------------------------------------------------------+
void UpdateLabel(const string name, const string text, color clr)
  {
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
  }

//+------------------------------------------------------------------+
//| Create a rectangle label (panel background)                        |
//+------------------------------------------------------------------+
void CreateRect(const string name, int x, int y, int w, int h,
                color bgClr, color borderClr)
  {
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgClr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, borderClr);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }
//+------------------------------------------------------------------+
