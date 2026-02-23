//+------------------------------------------------------------------+
//|                                                  SSPTrading.mqh  |
//|              SafeScalperPro v3.0 - Trading Engine Module          |
//|       Order Execution, Position Management, Risk, Breakeven      |
//+------------------------------------------------------------------+
#property copyright   "AlgoSphere Quant"
#property version     "3.10"
#property strict

#ifndef SSP_TRADING_MQH
#define SSP_TRADING_MQH

#include "SSPCore.mqh"
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//| TRADING ENGINE CLASS                                             |
//+------------------------------------------------------------------+
class CSSPTrading
  {
private:
   CTrade            m_trade;
   CPositionInfo     m_position;
   CSymbolInfo       m_symbol;
   CAccountInfo      m_account;
   
   SSspMarketData    m_market;
   SSspTradeStats    m_stats;
   
   ulong             m_magic;
   string            m_comment;
   
   // Risk state
   double            m_peakBalance;
   double            m_dayStartBalance;
   datetime          m_dayStart;
   
   // Execution stats
   int               m_ordersSent;
   int               m_ordersOK;
   int               m_ordersFail;
   
public:
   //--- Construction
                     CSSPTrading() : m_magic(0), m_peakBalance(0), m_dayStartBalance(0), m_dayStart(0),
                                     m_ordersSent(0), m_ordersOK(0), m_ordersFail(0)
                       { m_market.Reset(); m_stats.Reset(); }
                    ~CSSPTrading() {}
   
   //--- Initialization
   bool Init(string symbol, ulong magic, int slippage, string comment)
     {
      m_magic   = magic;
      m_comment = comment;
      
      if(!m_symbol.Name(symbol))
        { SSPError("Symbol init failed: " + symbol); return false; }
      
      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetDeviationInPoints(slippage);
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
      m_trade.SetMarginMode();
      
      RefreshMarket();
      
      m_peakBalance    = m_account.Balance();
      m_dayStartBalance= m_peakBalance;
      m_dayStart       = SSPGetDayStart();
      
      LoadHistory();
      
      SSPInfo("Trading engine initialized | " + symbol +
              " | Pip=" + DoubleToString(m_market.point, 6) +
              " | Digits=" + IntegerToString(m_market.digits) +
              " | LotMin=" + DoubleToString(m_market.lotMin, 2));
      return true;
     }
   
   //--- Market data
   void RefreshMarket()
     {
      m_symbol.RefreshRates();
      m_market.symbol       = m_symbol.Name();
      m_market.point        = m_symbol.Point();
      m_market.digits       = m_symbol.Digits();
      m_market.tickSize     = m_symbol.TickSize();
      m_market.tickValue    = m_symbol.TickValue();
      m_market.lotMin       = m_symbol.LotsMin();
      m_market.lotMax       = m_symbol.LotsMax();
      m_market.lotStep      = m_symbol.LotsStep();
      m_market.bid          = m_symbol.Bid();
      m_market.ask          = m_symbol.Ask();
      m_market.spreadPoints = (int)m_symbol.Spread();
      m_market.leverage     = m_account.Leverage();
      
      // Day tracking
      datetime today = SSPGetDayStart();
      if(today != m_dayStart)
        { m_dayStart = today; m_dayStartBalance = m_account.Balance(); }
      if(m_account.Balance() > m_peakBalance)
         m_peakBalance = m_account.Balance();
     }
   
   void GetMarket(SSspMarketData &out)  { out = m_market; }
   void GetStats(SSspTradeStats &out)   { out = m_stats; }
   double GetBid()                      { return m_market.bid; }
   double GetAsk()                      { return m_market.ask; }
   int    GetSpread()                   { return m_market.spreadPoints; }
   double GetBalance()                  { return m_account.Balance(); }
   double GetEquity()                   { return m_account.Equity(); }
   double GetFreeMargin()               { return m_account.FreeMargin(); }
   double GetDailyPnL()                 { return m_account.Balance() - m_dayStartBalance; }
   double GetTotalPnL()                 { return m_account.Balance() - m_peakBalance; }
   
   // -- Drawdown --
   double GetDrawdownPct()
     {
      if(m_peakBalance <= 0) return 0;
      return SSPClamp((m_peakBalance - m_account.Equity()) / m_peakBalance * 100.0, 0, 100);
     }
   
   //=================================================================
   // ORDER EXECUTION
   //=================================================================
   
   bool OpenBuy(double lot, int slPts, int tpPts)
     {
      RefreshMarket();
      double ask = m_market.ask;
      double sl  = NormalizeDouble(ask - slPts * m_market.point, m_market.digits);
      double tp  = NormalizeDouble(ask + tpPts * m_market.point, m_market.digits);
      
      // Validate
      if(!ValidateLot(lot)) return false;
      if(!CheckMargin(lot)) return false;
      
      m_ordersSent++;
      
      // Retry loop
      for(int attempt = 0; attempt < SSP_MAX_RETRIES; attempt++)
        {
         if(m_trade.Buy(lot, m_market.symbol, ask, sl, tp, m_comment))
           {
            m_ordersOK++;
            SSPLogTrade("BUY OPENED", lot, ask, sl, tp);
            return true;
           }
         
         uint retcode = m_trade.ResultRetcode();
         if(!IsRecoverable(retcode))
           {
            SSPError("BUY FAILED (non-recoverable) | Code=" + IntegerToString(retcode) +
                     " | " + m_trade.ResultComment());
            break;
           }
         
         SSPWarn("BUY retry " + IntegerToString(attempt + 1) + "/" + IntegerToString(SSP_MAX_RETRIES) +
                 " | Code=" + IntegerToString(retcode));
         Sleep(SSP_RETRY_DELAY_MS);
         RefreshMarket();
         ask = m_market.ask;
         sl  = NormalizeDouble(ask - slPts * m_market.point, m_market.digits);
         tp  = NormalizeDouble(ask + tpPts * m_market.point, m_market.digits);
        }
      
      m_ordersFail++;
      SSPError("BUY FAILED after " + IntegerToString(SSP_MAX_RETRIES) + " retries");
      return false;
     }
   
   bool OpenSell(double lot, int slPts, int tpPts)
     {
      RefreshMarket();
      double bid = m_market.bid;
      double sl  = NormalizeDouble(bid + slPts * m_market.point, m_market.digits);
      double tp  = NormalizeDouble(bid - tpPts * m_market.point, m_market.digits);
      
      if(!ValidateLot(lot)) return false;
      if(!CheckMargin(lot)) return false;
      
      m_ordersSent++;
      
      for(int attempt = 0; attempt < SSP_MAX_RETRIES; attempt++)
        {
         if(m_trade.Sell(lot, m_market.symbol, bid, sl, tp, m_comment))
           {
            m_ordersOK++;
            SSPLogTrade("SELL OPENED", lot, bid, sl, tp);
            return true;
           }
         
         uint retcode = m_trade.ResultRetcode();
         if(!IsRecoverable(retcode))
           { SSPError("SELL FAILED (non-recoverable) | Code=" + IntegerToString(retcode)); break; }
         
         SSPWarn("SELL retry " + IntegerToString(attempt + 1));
         Sleep(SSP_RETRY_DELAY_MS);
         RefreshMarket();
         bid = m_market.bid;
         sl  = NormalizeDouble(bid + slPts * m_market.point, m_market.digits);
         tp  = NormalizeDouble(bid - tpPts * m_market.point, m_market.digits);
        }
      
      m_ordersFail++;
      return false;
     }
   
   bool CloseAllPositions()
     {
      bool allClosed = true;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         if(!m_position.SelectByIndex(i)) continue;
         if(m_position.Symbol() != m_market.symbol || m_position.Magic() != m_magic) continue;
         if(!m_trade.PositionClose(m_position.Ticket()))
           { SSPWarn("Failed to close ticket " + IntegerToString(m_position.Ticket())); allClosed = false; }
         else
            SSPInfo("Closed ticket " + IntegerToString(m_position.Ticket()));
        }
      return allClosed;
     }
   
   //=================================================================
   // POSITION QUERIES
   //=================================================================
   
   bool HasOpenPosition()
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
         if(m_position.SelectByIndex(i))
            if(m_position.Symbol() == m_market.symbol && m_position.Magic() == m_magic)
               return true;
      return false;
     }
   
   int CountPositions()
     {
      int cnt = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
         if(m_position.SelectByIndex(i))
            if(m_position.Symbol() == m_market.symbol && m_position.Magic() == m_magic)
               cnt++;
      return cnt;
     }
   
   double GetFloatingPnL()
     {
      double pnl = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
         if(m_position.SelectByIndex(i))
            if(m_position.Symbol() == m_market.symbol && m_position.Magic() == m_magic)
               pnl += m_position.Profit() + m_position.Swap() + m_position.Commission();
      return pnl;
     }
   
   //=================================================================
   // BREAKEVEN MANAGEMENT
   //=================================================================
   
   void ManageBreakeven(int triggerPts, int offsetPts)
     {
      if(triggerPts <= 0) return;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         if(!m_position.SelectByIndex(i)) continue;
         if(m_position.Symbol() != m_market.symbol || m_position.Magic() != m_magic) continue;
         
         double op = m_position.PriceOpen();
         double sl = m_position.StopLoss();
         double pt = m_market.point;
         
         if(m_position.PositionType() == POSITION_TYPE_BUY)
           {
            double beLevel = NormalizeDouble(op + offsetPts * pt, m_market.digits);
            if(m_market.bid >= op + triggerPts * pt && sl < beLevel)
               m_trade.PositionModify(m_position.Ticket(), beLevel, m_position.TakeProfit());
           }
         else if(m_position.PositionType() == POSITION_TYPE_SELL)
           {
            double beLevel = NormalizeDouble(op - offsetPts * pt, m_market.digits);
            if(m_market.ask <= op - triggerPts * pt && (sl > beLevel || sl == 0))
               m_trade.PositionModify(m_position.Ticket(), beLevel, m_position.TakeProfit());
           }
        }
     }
   
   //=================================================================
   // LOT SIZE CALCULATION
   //=================================================================
   
   double CalculateLot(bool useLotMode, double fixedLot, double riskPct, int slPts)
     {
      double lots = fixedLot;
      
      if(!useLotMode && riskPct > 0 && slPts > 0)
        {
         double balance  = m_account.Balance();
         double risk     = balance * (SSPClamp(riskPct, 0.1, 5.0) / 100.0);
         double tv       = m_market.tickValue;
         double ts       = m_market.tickSize;
         if(tv > 0 && ts > 0)
           {
            double slMoney = slPts * m_market.point / ts * tv;
            if(slMoney > 0)
               lots = NormalizeDouble(risk / slMoney, 2);
           }
        }
      
      // Clamp to broker limits
      if(lots < m_market.lotMin) lots = m_market.lotMin;
      if(lots > m_market.lotMax) lots = m_market.lotMax;
      if(m_market.lotStep > 0)
         lots = MathFloor(lots / m_market.lotStep) * m_market.lotStep;
      
      return NormalizeDouble(lots, 2);
     }
   
   //=================================================================
   // RISK CHECKS
   //=================================================================
   
   bool CheckDrawdown(double maxDDPct)
     {
      if(maxDDPct <= 0) return true;
      return GetDrawdownPct() < maxDDPct;
     }
   
   bool CheckSpread(int maxSpread)
     {
      return m_market.spreadPoints <= maxSpread;
     }
   
   bool CheckMargin(double lot)
     {
      double margin = 0;
      if(!OrderCalcMargin(ORDER_TYPE_BUY, m_market.symbol, lot, m_market.ask, margin))
         return true; // Can't calculate -> allow (conservative: would block)
      return margin < m_account.FreeMargin() * 0.9;
     }
   
   //=================================================================
   // HISTORY & STATS TRACKING
   //=================================================================
   
   void LoadHistory()
     {
      m_stats.Reset();
      HistorySelect(0, TimeCurrent());
      int total = HistoryDealsTotal();
      
      datetime dayStart = SSPGetDayStart();
      m_stats.todayPnL = 0;
      
      for(int i = 0; i < total; i++)
        {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0) continue;
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != (long)m_magic) continue;
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != m_market.symbol) continue;
         if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
         
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                       + HistoryDealGetDouble(ticket, DEAL_SWAP)
                       + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         datetime dealTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         
         m_stats.totalTrades++;
         
         if(profit > 0)
           {
            m_stats.wins++;
            m_stats.grossProfit += profit;
            if(m_stats.currentStreak >= 0) m_stats.currentStreak++; else m_stats.currentStreak = 1;
            if(m_stats.currentStreak > m_stats.maxWinStreak) m_stats.maxWinStreak = m_stats.currentStreak;
           }
         else if(profit < 0)
           {
            m_stats.losses++;
            m_stats.grossLoss += profit;
            if(m_stats.currentStreak <= 0) m_stats.currentStreak--; else m_stats.currentStreak = -1;
            if(MathAbs(m_stats.currentStreak) > m_stats.maxLossStreak)
               m_stats.maxLossStreak = MathAbs(m_stats.currentStreak);
           }
         
         if(dealTime >= dayStart)
            m_stats.todayPnL += profit;
        }
      
      m_stats.totalPnL = m_stats.grossProfit + m_stats.grossLoss;
      m_stats.Recalculate();
     }
   
   // Execution statistics
   string GetExecStats()
     {
      return "Sent=" + IntegerToString(m_ordersSent) +
             " OK=" + IntegerToString(m_ordersOK) +
             " Fail=" + IntegerToString(m_ordersFail);
     }

private:
   bool ValidateLot(double lot)
     {
      if(lot < m_market.lotMin || lot > m_market.lotMax)
        { SSPError("Invalid lot: " + DoubleToString(lot, 2) + " (range: " +
                   DoubleToString(m_market.lotMin, 2) + "-" + DoubleToString(m_market.lotMax, 2) + ")");
          return false; }
      return true;
     }
   
   bool IsRecoverable(uint retcode)
     {
      switch(retcode)
        {
         case TRADE_RETCODE_REQUOTE:
         case TRADE_RETCODE_CONNECTION:
         case TRADE_RETCODE_TIMEOUT:
         case TRADE_RETCODE_PRICE_CHANGED:
         case TRADE_RETCODE_PRICE_OFF:
         case TRADE_RETCODE_TOO_MANY_REQUESTS:
            return true;
         default:
            return false;
        }
     }
  };

#endif // SSP_TRADING_MQH
