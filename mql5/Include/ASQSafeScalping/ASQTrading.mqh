//+------------------------------------------------------------------+
//|                                                  ASQTrading.mqh  |
//|            ASQ Safe Scalping v1.10 - Trading Engine Module       |
//|  Execution, Risk, Breakeven, Trailing, Partial Close, Peak DD    |
//+------------------------------------------------------------------+
#property copyright   "AlgoSphere Quant"
#property link        "https://www.mql5.com/en/users/robin2.0"
#property version     "1.10"
#property strict

#ifndef ASQ_TRADING_MQH
#define ASQ_TRADING_MQH

#include "ASQCore.mqh"
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

class CASQTrading
  {
private:
   CTrade            m_trade;
   CPositionInfo     m_position;
   CSymbolInfo       m_symbol;
   CAccountInfo      m_account;
   SAsqMarketData    m_market;
   SAsqTradeStats    m_stats;
   ulong             m_magic;
   string            m_comment;
   double            m_peakBalance;
   double            m_dayStartBalance;
   datetime          m_dayStart;
   double            m_peakDD;           // v1.10: historical peak DD
   string            m_gvPeakDD;         // GlobalVariable name for persistence
   int               m_ordersSent,m_ordersOK,m_ordersFail;

public:
   CASQTrading() : m_magic(0),m_peakBalance(0),m_dayStartBalance(0),m_dayStart(0),
                   m_peakDD(0),m_ordersSent(0),m_ordersOK(0),m_ordersFail(0)
     { m_market.Reset(); m_stats.Reset(); }
  ~CASQTrading() {}

   bool Init(string symbol,ulong magic,int slippage,string comment)
     {
      m_magic=magic; m_comment=comment;
      if(!m_symbol.Name(symbol)) { ASQError("Symbol init failed: "+symbol); return false; }
      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetDeviationInPoints(slippage);
      m_trade.SetMarginMode();
      long fp=SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE);
      if((fp&SYMBOL_FILLING_IOC)!=0) m_trade.SetTypeFilling(ORDER_FILLING_IOC);
      else if((fp&SYMBOL_FILLING_FOK)!=0) m_trade.SetTypeFilling(ORDER_FILLING_FOK);
      else m_trade.SetTypeFilling(ORDER_FILLING_RETURN);
      RefreshMarket();
      m_peakBalance=m_account.Balance(); m_dayStartBalance=m_peakBalance;
      m_dayStart=ASQGetDayStart();
      // Restore peak DD from GlobalVariable
      m_gvPeakDD="ASQ_PeakDD_"+symbol+"_"+IntegerToString(magic);
      if(GlobalVariableCheck(m_gvPeakDD)) m_peakDD=GlobalVariableGet(m_gvPeakDD);
      else { m_peakDD=0; GlobalVariableSet(m_gvPeakDD,0); }
      LoadHistory();
      ASQInfo("Trading engine initialized | "+symbol+
              " | Pip="+DoubleToString(m_market.point,6)+
              " | Digits="+IntegerToString(m_market.digits)+
              " | LotMin="+DoubleToString(m_market.lotMin,2)+
              " | PeakDD="+DoubleToString(m_peakDD,2)+"%");
      return true;
     }

   void RefreshMarket()
     {
      m_symbol.RefreshRates();
      m_market.symbol=m_symbol.Name(); m_market.point=m_symbol.Point();
      m_market.digits=m_symbol.Digits(); m_market.tickSize=m_symbol.TickSize();
      m_market.tickValue=m_symbol.TickValue();
      m_market.lotMin=m_symbol.LotsMin(); m_market.lotMax=m_symbol.LotsMax();
      m_market.lotStep=m_symbol.LotsStep();
      m_market.bid=m_symbol.Bid(); m_market.ask=m_symbol.Ask();
      m_market.spreadPoints=(int)m_symbol.Spread(); m_market.leverage=m_account.Leverage();
      datetime today=ASQGetDayStart();
      if(today!=m_dayStart) { m_dayStart=today; m_dayStartBalance=m_account.Balance(); }
      if(m_account.Balance()>m_peakBalance) m_peakBalance=m_account.Balance();
      // Track peak DD
      double dd=GetDrawdownPct();
      if(dd>m_peakDD) { m_peakDD=dd; GlobalVariableSet(m_gvPeakDD,m_peakDD); }
     }

   // Accessors
   void   GetMarket(SAsqMarketData &out) { out=m_market; }
   void   GetStats(SAsqTradeStats &out)  { out=m_stats; }
   double GetBid()        { return m_market.bid; }
   double GetAsk()        { return m_market.ask; }
   int    GetSpread()     { return m_market.spreadPoints; }
   double GetBalance()    { return m_account.Balance(); }
   double GetEquity()     { return m_account.Equity(); }
   double GetFreeMargin() { return m_account.FreeMargin(); }
   double GetDailyPnL()   { return m_account.Balance()-m_dayStartBalance; }
   double GetPeakDD()     { return m_peakDD; }
   int    GetTodayTrades(){ return m_stats.todayTrades; }
   int    GetTodayLosses(){ return m_stats.todayLosses; }

   double GetDrawdownPct()
     { if(m_peakBalance<=0) return 0;
       return ASQClamp((m_peakBalance-m_account.Equity())/m_peakBalance*100.0,0,100); }

   //=================================================================
   // ORDER EXECUTION
   //=================================================================
   bool OpenBuy(double lot,int slPts,int tpPts)
     {
      RefreshMarket(); double ask=m_market.ask;
      double sl=NormalizeDouble(ask-slPts*m_market.point,m_market.digits);
      double tp=NormalizeDouble(ask+tpPts*m_market.point,m_market.digits);
      if(!ValidateLot(lot)||!CheckMargin(lot)) return false;
      m_ordersSent++;
      for(int a=0;a<ASQ_MAX_RETRIES;a++)
        { if(m_trade.Buy(lot,m_market.symbol,ask,sl,tp,m_comment))
            { m_ordersOK++; ASQLogTrade("BUY OPENED",lot,ask,sl,tp); return true; }
          uint rc=m_trade.ResultRetcode();
          if(!IsRecoverable(rc))
            { ASQError("BUY FAILED | Code="+IntegerToString(rc)+" | "+m_trade.ResultComment()); break; }
          ASQWarn("BUY retry "+(string)(a+1)); Sleep(ASQ_RETRY_DELAY_MS);
          RefreshMarket(); ask=m_market.ask;
          sl=NormalizeDouble(ask-slPts*m_market.point,m_market.digits);
          tp=NormalizeDouble(ask+tpPts*m_market.point,m_market.digits); }
      m_ordersFail++; return false;
     }

   bool OpenSell(double lot,int slPts,int tpPts)
     {
      RefreshMarket(); double bid=m_market.bid;
      double sl=NormalizeDouble(bid+slPts*m_market.point,m_market.digits);
      double tp=NormalizeDouble(bid-tpPts*m_market.point,m_market.digits);
      if(!ValidateLot(lot)||!CheckMargin(lot)) return false;
      m_ordersSent++;
      for(int a=0;a<ASQ_MAX_RETRIES;a++)
        { if(m_trade.Sell(lot,m_market.symbol,bid,sl,tp,m_comment))
            { m_ordersOK++; ASQLogTrade("SELL OPENED",lot,bid,sl,tp); return true; }
          uint rc=m_trade.ResultRetcode();
          if(!IsRecoverable(rc)) { ASQError("SELL FAILED | Code="+IntegerToString(rc)); break; }
          ASQWarn("SELL retry "+(string)(a+1)); Sleep(ASQ_RETRY_DELAY_MS);
          RefreshMarket(); bid=m_market.bid;
          sl=NormalizeDouble(bid+slPts*m_market.point,m_market.digits);
          tp=NormalizeDouble(bid-tpPts*m_market.point,m_market.digits); }
      m_ordersFail++; return false;
     }

   bool CloseAllPositions()
     { bool ok=true;
       for(int i=PositionsTotal()-1;i>=0;i--)
         { if(!m_position.SelectByIndex(i)) continue;
           if(m_position.Symbol()!=m_market.symbol||m_position.Magic()!=m_magic) continue;
           if(!m_trade.PositionClose(m_position.Ticket())) ok=false;
           else ASQInfo("Closed #"+IntegerToString(m_position.Ticket())); }
       return ok; }

   //=================================================================
   // POSITION QUERIES
   //=================================================================
   bool HasOpenPosition()
     { for(int i=PositionsTotal()-1;i>=0;i--)
         if(m_position.SelectByIndex(i))
           if(m_position.Symbol()==m_market.symbol&&m_position.Magic()==m_magic) return true;
       return false; }

   int CountPositions()
     { int c=0; for(int i=PositionsTotal()-1;i>=0;i--)
         if(m_position.SelectByIndex(i))
           if(m_position.Symbol()==m_market.symbol&&m_position.Magic()==m_magic) c++;
       return c; }

   double GetFloatingPnL()
     { double p=0; for(int i=PositionsTotal()-1;i>=0;i--)
         if(m_position.SelectByIndex(i))
           if(m_position.Symbol()==m_market.symbol&&m_position.Magic()==m_magic)
             p+=m_position.Profit()+m_position.Swap()+m_position.Commission();
       return p; }

   //=================================================================
   // BREAKEVEN
   //=================================================================
   void ManageBreakeven(int triggerPts,int offsetPts)
     { if(triggerPts<=0) return;
       for(int i=PositionsTotal()-1;i>=0;i--)
         { if(!m_position.SelectByIndex(i)) continue;
           if(m_position.Symbol()!=m_market.symbol||m_position.Magic()!=m_magic) continue;
           double op=m_position.PriceOpen(),sl=m_position.StopLoss(),pt=m_market.point;
           if(m_position.PositionType()==POSITION_TYPE_BUY)
             { double be=NormalizeDouble(op+offsetPts*pt,m_market.digits);
               if(m_market.bid>=op+triggerPts*pt&&sl<be)
                 m_trade.PositionModify(m_position.Ticket(),be,m_position.TakeProfit()); }
           else if(m_position.PositionType()==POSITION_TYPE_SELL)
             { double be=NormalizeDouble(op-offsetPts*pt,m_market.digits);
               if(m_market.ask<=op-triggerPts*pt&&(sl>be||sl==0))
                 m_trade.PositionModify(m_position.Ticket(),be,m_position.TakeProfit()); }
         }
     }

   //=================================================================
   // v1.10: TRAILING STOP
   //=================================================================
   void ManageTrailing(int trailStartPts,int trailStepPts)
     { if(trailStartPts<=0||trailStepPts<=0) return;
       for(int i=PositionsTotal()-1;i>=0;i--)
         { if(!m_position.SelectByIndex(i)) continue;
           if(m_position.Symbol()!=m_market.symbol||m_position.Magic()!=m_magic) continue;
           double op=m_position.PriceOpen(),sl=m_position.StopLoss(),pt=m_market.point;
           int dg=m_market.digits;
           if(m_position.PositionType()==POSITION_TYPE_BUY)
             { double profitPts=(m_market.bid-op)/pt;
               if(profitPts>=trailStartPts)
                 { double newSL=NormalizeDouble(m_market.bid-trailStepPts*pt,dg);
                   if(newSL>sl+pt) m_trade.PositionModify(m_position.Ticket(),newSL,m_position.TakeProfit()); } }
           else if(m_position.PositionType()==POSITION_TYPE_SELL)
             { double profitPts=(op-m_market.ask)/pt;
               if(profitPts>=trailStartPts)
                 { double newSL=NormalizeDouble(m_market.ask+trailStepPts*pt,dg);
                   if(newSL<sl-pt||sl==0) m_trade.PositionModify(m_position.Ticket(),newSL,m_position.TakeProfit()); } }
         }
     }

   //=================================================================
   // v1.10: PARTIAL CLOSE AT TP1
   //=================================================================
   void ManagePartialClose(int tp1Pts,double closePercent)
     { if(tp1Pts<=0||closePercent<=0) return;
       for(int i=PositionsTotal()-1;i>=0;i--)
         { if(!m_position.SelectByIndex(i)) continue;
           if(m_position.Symbol()!=m_market.symbol||m_position.Magic()!=m_magic) continue;
           double op=m_position.PriceOpen(),vol=m_position.Volume(),pt=m_market.point;
           double closeLot=NormalizeDouble(vol*closePercent/100.0,2);
           if(closeLot<m_market.lotMin) continue; // can't split further
           if(vol-closeLot<m_market.lotMin) continue; // remainder too small
           // Check if TP1 comment already applied (prevent re-closing)
           string cm=m_position.Comment();
           if(StringFind(cm,"TP1")>=0) continue;
           if(m_position.PositionType()==POSITION_TYPE_BUY)
             { if(m_market.bid>=op+tp1Pts*pt)
                 { m_trade.PositionClosePartial(m_position.Ticket(),closeLot);
                   ASQInfo("PARTIAL CLOSE BUY "+DoubleToString(closeLot,2)+" at TP1"); } }
           else if(m_position.PositionType()==POSITION_TYPE_SELL)
             { if(m_market.ask<=op-tp1Pts*pt)
                 { m_trade.PositionClosePartial(m_position.Ticket(),closeLot);
                   ASQInfo("PARTIAL CLOSE SELL "+DoubleToString(closeLot,2)+" at TP1"); } }
         }
     }

   //=================================================================
   // LOT CALCULATION
   //=================================================================
   double CalculateLot(bool useLotMode,double fixedLot,double riskPct,int slPts)
     { double lots=fixedLot;
       if(!useLotMode&&riskPct>0&&slPts>0)
         { double bal=m_account.Balance();
           double risk=bal*(ASQClamp(riskPct,0.1,5.0)/100.0);
           double tv=m_market.tickValue,ts=m_market.tickSize;
           if(tv>0&&ts>0) { double slM=slPts*m_market.point/ts*tv;
             if(slM>0) lots=NormalizeDouble(risk/slM,2); } }
       if(lots<m_market.lotMin) lots=m_market.lotMin;
       if(lots>m_market.lotMax) lots=m_market.lotMax;
       if(m_market.lotStep>0) lots=MathFloor(lots/m_market.lotStep)*m_market.lotStep;
       return NormalizeDouble(lots,2); }

   bool CheckDrawdown(double maxDDPct)
     { if(maxDDPct<=0) return true; return GetDrawdownPct()<maxDDPct; }

   bool CheckMargin(double lot)
     { double margin=0;
       if(!OrderCalcMargin(ORDER_TYPE_BUY,m_market.symbol,lot,m_market.ask,margin)) return true;
       return margin<m_account.FreeMargin()*0.9; }

   //=================================================================
   // HISTORY & STATS (now tracks todayTrades/todayLosses)
   //=================================================================
   void LoadHistory()
     { m_stats.Reset();
       HistorySelect(0,TimeCurrent());
       int total=HistoryDealsTotal();
       datetime dayStart=ASQGetDayStart();
       for(int i=0;i<total;i++)
         { ulong tk=HistoryDealGetTicket(i); if(tk==0) continue;
           if(HistoryDealGetInteger(tk,DEAL_MAGIC)!=(long)m_magic) continue;
           if(HistoryDealGetString(tk,DEAL_SYMBOL)!=m_market.symbol) continue;
           if(HistoryDealGetInteger(tk,DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
           double profit=HistoryDealGetDouble(tk,DEAL_PROFIT)
                        +HistoryDealGetDouble(tk,DEAL_SWAP)
                        +HistoryDealGetDouble(tk,DEAL_COMMISSION);
           datetime dealTime=(datetime)HistoryDealGetInteger(tk,DEAL_TIME);
           m_stats.totalTrades++;
           if(profit>0)
             { m_stats.wins++; m_stats.grossProfit+=profit;
               if(m_stats.currentStreak>=0) m_stats.currentStreak++; else m_stats.currentStreak=1;
               if(m_stats.currentStreak>m_stats.maxWinStreak) m_stats.maxWinStreak=m_stats.currentStreak; }
           else if(profit<0)
             { m_stats.losses++; m_stats.grossLoss+=profit;
               if(m_stats.currentStreak<=0) m_stats.currentStreak--; else m_stats.currentStreak=-1;
               if(MathAbs(m_stats.currentStreak)>m_stats.maxLossStreak)
                 m_stats.maxLossStreak=MathAbs(m_stats.currentStreak); }
           if(dealTime>=dayStart)
             { m_stats.todayPnL+=profit; m_stats.todayTrades++;
               if(profit<0) m_stats.todayLosses++; }
         }
       m_stats.totalPnL=m_stats.grossProfit+m_stats.grossLoss;
       m_stats.Recalculate(); }

   string GetExecStats()
     { return "Sent="+IntegerToString(m_ordersSent)+
              " OK="+IntegerToString(m_ordersOK)+
              " Fail="+IntegerToString(m_ordersFail); }

private:
   bool ValidateLot(double lot)
     { if(lot<m_market.lotMin||lot>m_market.lotMax)
         { ASQError("Invalid lot: "+DoubleToString(lot,2)); return false; }
       return true; }

   bool IsRecoverable(uint rc)
     { switch(rc) { case TRADE_RETCODE_REQUOTE: case TRADE_RETCODE_CONNECTION:
         case TRADE_RETCODE_TIMEOUT: case TRADE_RETCODE_PRICE_CHANGED:
         case TRADE_RETCODE_PRICE_OFF: case TRADE_RETCODE_TOO_MANY_REQUESTS: return true;
         default: return false; } }
  };

#endif
