//+------------------------------------------------------------------+
//|                                          ASQ_JournalExport.mq5   |
//|                              Copyright 2026, AlgoSphere Quant    |
//|                        https://www.mql5.com/en/users/robin2.0    |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, AlgoSphere Quant"
#property link        "https://www.mql5.com/en/users/robin2.0"
#property version     "2.00"
#property description "ASQ JournalExport v2 — One-click CSV trade journal"
#property description "Full history export with R:R, win rate, expectancy,"
#property description "max streak, best/worst trade, avg duration, summary."
#property description "AlgoSphere Quant — Precision before profit."
#property script_show_inputs

//+------------------------------------------------------------------+
//| Inputs                                                            |
//+------------------------------------------------------------------+
input group              "═══════ EXPORT SETTINGS ═══════"
input string             InpFileName        = "ASQ_Journal";   // File Name (without .csv)
input int                InpDaysBack        = 30;              // Days of History (0=all)
input string             InpSymbolFilter    = "";              // Symbol Filter (empty=all)
input long               InpMagicFilter     = -1;              // Magic Filter (-1=all)

input group              "═══════ FIELDS ═══════"
input bool               InpIncludeSwap     = true;            // Include Swap
input bool               InpIncludeComm     = true;            // Include Commission
input bool               InpIncludeDuration = true;            // Include Duration
input bool               InpIncludeRR       = true;            // Include R:R Ratio
input bool               InpIncludeMagic    = true;            // Include Magic Number
input bool               InpIncludeComment  = true;            // Include Comment

//+------------------------------------------------------------------+
//| Constants                                                         |
//+------------------------------------------------------------------+
const string SCRIPT_TAG = "ASQ JournalExport";
const string SCRIPT_VER = "2.0";

//+------------------------------------------------------------------+
//| Script start                                                      |
//+------------------------------------------------------------------+
void OnStart()
  {
//--- date range
   datetime startDate = 0;
   if(InpDaysBack > 0)
      startDate = TimeCurrent() - InpDaysBack * 86400;

   if(!HistorySelect(startDate, TimeCurrent()))
     {
      PrintFormat("%s: Failed to select history.", SCRIPT_TAG);
      Alert(SCRIPT_TAG + ": Failed to select history.");
      return;
     }

//--- build filename with date
   MqlDateTime dtNow;
   TimeToStruct(TimeCurrent(), dtNow);
   string fileName = InpFileName + "_" +
                     IntegerToString(dtNow.year) +
                     StringFormat("%02d", dtNow.mon) +
                     StringFormat("%02d", dtNow.day) + ".csv";

//--- open file
   int handle = FileOpen(fileName, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s: Cannot create file %s", SCRIPT_TAG, fileName);
      Alert(SCRIPT_TAG + ": Cannot create file.");
      return;
     }

//--- write header
   string header = "Ticket,Symbol,Direction,Open Time,Close Time,Lots,"
                   "Open Price,Close Price,SL,TP,Gross P/L";
   if(InpIncludeSwap) header += ",Swap";
   if(InpIncludeComm) header += ",Commission";
   header += ",Net P/L";
   if(InpIncludeRR) header += ",R:R";
   if(InpIncludeDuration) header += ",Duration (min)";
   if(InpIncludeMagic) header += ",Magic";
   if(InpIncludeComment) header += ",Comment";
   FileWriteString(handle, header + "\n");

//--- stats accumulators
   int totalDeals     = HistoryDealsTotal();
   int tradesExported = 0;
   double totalNetPL  = 0;
   double totalGrossPL= 0;
   int    wins        = 0;
   int    losses      = 0;
   double bestTrade   = -999999;
   double worstTrade  = 999999;
   int    totalDurMin = 0;
   int    curWinStreak= 0, curLossStreak = 0;
   int    maxWinStreak= 0, maxLossStreak = 0;
   double totalWinAmt = 0, totalLossAmt  = 0;

//--- scan closing deals
   for(int i = 0; i < totalDeals; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT)
         continue;

      string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
      if(InpSymbolFilter != "" && symbol != InpSymbolFilter)
         continue;

      long magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
      if(InpMagicFilter >= 0 && magic != InpMagicFilter)
         continue;

      ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
      double lots     = HistoryDealGetDouble(ticket, DEAL_VOLUME);
      double price    = HistoryDealGetDouble(ticket, DEAL_PRICE);
      double profit   = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      double swap     = HistoryDealGetDouble(ticket, DEAL_SWAP);
      double comm     = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      datetime closeTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      string comment  = HistoryDealGetString(ticket, DEAL_COMMENT);
      long posId      = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);

      //--- find opening deal
      double openPrice = 0, sl = 0, tp = 0;
      datetime openTime = 0;
      string direction = "";

      for(int j = 0; j < totalDeals; j++)
        {
         ulong openTicket = HistoryDealGetTicket(j);
         if(openTicket == 0) continue;
         if(HistoryDealGetInteger(openTicket, DEAL_POSITION_ID) != posId) continue;

         ENUM_DEAL_ENTRY openEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(openTicket, DEAL_ENTRY);
         if(openEntry == DEAL_ENTRY_IN)
           {
            openPrice = HistoryDealGetDouble(openTicket, DEAL_PRICE);
            openTime  = (datetime)HistoryDealGetInteger(openTicket, DEAL_TIME);
            ENUM_DEAL_TYPE openType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(openTicket, DEAL_TYPE);
            direction = (openType == DEAL_TYPE_BUY) ? "BUY" : "SELL";

            long orderId = HistoryDealGetInteger(openTicket, DEAL_ORDER);
            if(HistoryOrderSelect(orderId))
              {
               sl = HistoryOrderGetDouble(orderId, ORDER_SL);
               tp = HistoryOrderGetDouble(orderId, ORDER_TP);
              }
            break;
           }
        }

      if(openTime == 0) openTime = closeTime;
      if(direction == "") direction = (dealType == DEAL_TYPE_SELL) ? "BUY" : "SELL";

      double netPL = profit + swap + comm;
      totalGrossPL += profit;
      totalNetPL   += netPL;

      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      if(digits == 0) digits = 5;

      int durationMin = (int)((closeTime - openTime) / 60);
      totalDurMin += durationMin;

      //--- R:R calculation
      double rr = 0;
      if(sl != 0 && openPrice != 0 && tp != 0)
        {
         double slDist = MathAbs(openPrice - sl);
         double tpDist = MathAbs(tp - openPrice);
         if(slDist > 0) rr = tpDist / slDist;
        }

      //--- stats
      if(netPL > bestTrade)  bestTrade  = netPL;
      if(netPL < worstTrade) worstTrade = netPL;

      if(netPL >= 0)
        {
         wins++;
         totalWinAmt += netPL;
         curWinStreak++;
         curLossStreak = 0;
         if(curWinStreak > maxWinStreak) maxWinStreak = curWinStreak;
        }
      else
        {
         losses++;
         totalLossAmt += MathAbs(netPL);
         curLossStreak++;
         curWinStreak = 0;
         if(curLossStreak > maxLossStreak) maxLossStreak = curLossStreak;
        }

      //--- write row
      string row = IntegerToString(posId) + "," +
                   symbol + "," + direction + "," +
                   TimeToString(openTime, TIME_DATE | TIME_MINUTES) + "," +
                   TimeToString(closeTime, TIME_DATE | TIME_MINUTES) + "," +
                   DoubleToString(lots, 2) + "," +
                   DoubleToString(openPrice, digits) + "," +
                   DoubleToString(price, digits) + "," +
                   DoubleToString(sl, digits) + "," +
                   DoubleToString(tp, digits) + "," +
                   DoubleToString(profit, 2);

      if(InpIncludeSwap) row += "," + DoubleToString(swap, 2);
      if(InpIncludeComm) row += "," + DoubleToString(comm, 2);
      row += "," + DoubleToString(netPL, 2);
      if(InpIncludeRR) row += "," + DoubleToString(rr, 2);
      if(InpIncludeDuration) row += "," + IntegerToString(durationMin);
      if(InpIncludeMagic) row += "," + IntegerToString(magic);
      if(InpIncludeComment) row += "," + comment;

      FileWriteString(handle, row + "\n");
      tradesExported++;
     }

//--- summary section
   double winRate    = (tradesExported > 0) ? (double)wins / tradesExported * 100.0 : 0;
   double avgWin    = (wins > 0) ? totalWinAmt / wins : 0;
   double avgLoss   = (losses > 0) ? totalLossAmt / losses : 0;
   double expectancy= (tradesExported > 0)
                      ? (winRate/100.0 * avgWin) - ((100.0-winRate)/100.0 * avgLoss)
                      : 0;
   double profitFactor = (totalLossAmt > 0) ? totalWinAmt / totalLossAmt : 0;
   double avgDuration  = (tradesExported > 0) ? (double)totalDurMin / tradesExported : 0;

   FileWriteString(handle, "\n");
   FileWriteString(handle, "═══ SUMMARY ═══\n");
   FileWriteString(handle, "Trades Exported," + IntegerToString(tradesExported) + "\n");
   FileWriteString(handle, "Gross P/L," + DoubleToString(totalGrossPL, 2) + "\n");
   FileWriteString(handle, "Net P/L," + DoubleToString(totalNetPL, 2) + "\n");
   FileWriteString(handle, "Wins," + IntegerToString(wins) + "\n");
   FileWriteString(handle, "Losses," + IntegerToString(losses) + "\n");
   FileWriteString(handle, "Win Rate," + DoubleToString(winRate, 1) + "%\n");
   FileWriteString(handle, "Avg Win," + DoubleToString(avgWin, 2) + "\n");
   FileWriteString(handle, "Avg Loss," + DoubleToString(avgLoss, 2) + "\n");
   FileWriteString(handle, "Expectancy," + DoubleToString(expectancy, 2) + "\n");
   FileWriteString(handle, "Profit Factor," + DoubleToString(profitFactor, 2) + "\n");
   FileWriteString(handle, "Best Trade," + DoubleToString(bestTrade, 2) + "\n");
   FileWriteString(handle, "Worst Trade," + DoubleToString(worstTrade, 2) + "\n");
   FileWriteString(handle, "Max Win Streak," + IntegerToString(maxWinStreak) + "\n");
   FileWriteString(handle, "Max Loss Streak," + IntegerToString(maxLossStreak) + "\n");
   FileWriteString(handle, "Avg Duration (min)," + DoubleToString(avgDuration, 0) + "\n");
   FileWriteString(handle, "Period," + IntegerToString(InpDaysBack) + " days\n");
   FileWriteString(handle, "Generated," + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES) + "\n");
   FileWriteString(handle, "AlgoSphere Quant — Precision before profit\n");

   FileClose(handle);

//--- report
   string report = StringFormat(
      "%s v%s\n\n"
      "File: %s\n"
      "Trades: %d  |  Win Rate: %.1f%%\n"
      "Gross P/L: %.2f  |  Net P/L: %.2f\n"
      "Profit Factor: %.2f  |  Expectancy: %.2f\n"
      "Best: %.2f  |  Worst: %.2f\n"
      "Max Win Streak: %d  |  Max Loss Streak: %d\n"
      "Avg Duration: %.0f min\n"
      "Location: MQL5/Files/%s",
      SCRIPT_TAG, SCRIPT_VER, fileName,
      tradesExported, winRate,
      totalGrossPL, totalNetPL,
      profitFactor, expectancy,
      bestTrade, worstTrade,
      maxWinStreak, maxLossStreak,
      avgDuration, fileName);

   Print(report);
   Alert(report);
  }
//+------------------------------------------------------------------+
