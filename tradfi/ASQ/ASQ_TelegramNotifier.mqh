//+------------------------------------------------------------------+
//|                                       ASQ_TelegramNotifier.mqh   |
//|                        Copyright 2026, AlgoSphere Quant          |
//|                        https://www.mql5.com/en/users/robin2.0    |
//+------------------------------------------------------------------+
//| ASQ Telegram Notifier v1.2 — Free, Open-Source                   |
//|                                                                   |
//| Professional Telegram integration for MQL5 EAs.                   |
//|                                                                   |
//| FEATURES:                                                         |
//| • Trade open/close/modify notifications                           |
//| • Daily and weekly P/L summaries                                  |
//| • Error, warning, signal, and custom alerts                       |
//| • Startup/shutdown notifications                                   |
//| • Multi-chat support (up to 3 chat IDs)                           |
//| • Silent hours (suppress notifications during off-hours)          |
//| • Markdown formatting with tag labels                             |
//| • Rate limiting (20 msg/min) to respect Telegram API              |
//| • Message queue with retry on failure                              |
//| • Daily message stats (sent/failed counters)                      |
//| • Connection health check via getMe                               |
//| • URL encoding and Markdown escaping                              |
//|                                                                   |
//| SETUP (3 steps):                                                  |
//| 1. Create bot via @BotFather on Telegram -> get BOT_TOKEN         |
//| 2. Get your Chat ID via @userinfobot -> get CHAT_ID              |
//| 3. In MT5: Tools -> Options -> Expert Advisors ->                 |
//|    Add https://api.telegram.org to "Allow WebRequest for..."      |
//|                                                                   |
//| USAGE:                                                            |
//|   #include "ASQ_TelegramNotifier.mqh"                            |
//|   CASQTelegramNotifier tg;                                        |
//|   tg.Initialize("BOT_TOKEN", "CHAT_ID", _Symbol);                |
//|   tg.SendTestMessage();                                           |
//|   tg.SendTradeOpen(_Symbol, "BUY", 0.10, ask, sl, tp);          |
//|                                                                   |
//| AlgoSphere Quant — Precision before profit.                      |
//| https://www.mql5.com/en/users/robin2.0                           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, AlgoSphere Quant"
#property link      "https://www.mql5.com/en/users/robin2.0"
#property version   "1.20"
#property strict

#ifndef ASQ_TELEGRAM_NOTIFIER_MQH
#define ASQ_TELEGRAM_NOTIFIER_MQH

//+------------------------------------------------------------------+
//| CONSTANTS                                                         |
//+------------------------------------------------------------------+
#define ASQ_TG_API_URL       "https://api.telegram.org/bot"
#define ASQ_TG_SEND_MSG      "/sendMessage"
#define ASQ_TG_SEND_PHOTO    "/sendPhoto"
#define ASQ_TG_GET_ME        "/getMe"
#define ASQ_TG_TIMEOUT       5000
#define ASQ_TG_MAX_RETRIES   3
#define ASQ_TG_MAX_MSG_LEN   4096
#define ASQ_TG_MAX_CHATS     3
#define ASQ_TG_QUEUE_SIZE    10

//+------------------------------------------------------------------+
//| NOTIFICATION TYPE                                                 |
//+------------------------------------------------------------------+
enum ENUM_ASQ_TG_NOTIFY
{
   ASQ_TG_TRADE_OPEN    = 0,
   ASQ_TG_TRADE_CLOSE   = 1,
   ASQ_TG_TRADE_MODIFY  = 2,
   ASQ_TG_DAILY_SUMMARY = 3,
   ASQ_TG_WEEKLY_SUMMARY= 4,
   ASQ_TG_ERROR         = 5,
   ASQ_TG_WARNING       = 6,
   ASQ_TG_INFO          = 7,
   ASQ_TG_SIGNAL        = 8,
   ASQ_TG_STARTUP       = 9,
   ASQ_TG_SHUTDOWN      = 10,
   ASQ_TG_CUSTOM        = 11
};

//+------------------------------------------------------------------+
//| MESSAGE QUEUE ENTRY                                               |
//+------------------------------------------------------------------+
struct SASQTGQueueEntry
{
   string   text;
   int      retries;
   datetime queued;
   bool     pending;
   void Reset() { text = ""; retries = 0; queued = 0; pending = false; }
};

//+------------------------------------------------------------------+
//| SETTINGS                                                          |
//+------------------------------------------------------------------+
struct SASQTelegramSettings
{
   bool   enabled;
   string botToken;
   string chatIds[ASQ_TG_MAX_CHATS];
   int    chatCount;
   bool   notifyTradeOpen, notifyTradeClose, notifyDailySummary;
   bool   notifyErrors, notifySignals, sendScreenshots, useEmoji;
   bool   notifyStartup, notifyShutdown;
   bool   useSilentHours;
   int    silentStart, silentEnd;    // GMT hours
   string eaName;

   void Reset()
   {
      enabled = false; botToken = ""; chatCount = 0;
      for(int i = 0; i < ASQ_TG_MAX_CHATS; i++) chatIds[i] = "";
      notifyTradeOpen = true; notifyTradeClose = true;
      notifyDailySummary = true; notifyErrors = true;
      notifySignals = false; sendScreenshots = false;
      useEmoji = true; eaName = "ASQ EA";
      notifyStartup = true; notifyShutdown = true;
      useSilentHours = false; silentStart = 22; silentEnd = 6;
   }
};

//+------------------------------------------------------------------+
//| TELEGRAM NOTIFIER CLASS                                           |
//+------------------------------------------------------------------+
class CASQTelegramNotifier
{
private:
   SASQTelegramSettings m_settings;
   string               m_symbol;
   bool                 m_initialized;
   datetime             m_lastSend;
   int                  m_sendCount, m_errorCount;
   int                  m_dailySendCount, m_dailyErrorCount;
   string               m_lastError;
   int                  m_messagesThisMinute;
   datetime             m_minuteStart;
   datetime             m_currentDay;
   bool                 m_verbose;
   bool                 m_connectionVerified;

   // Message queue
   SASQTGQueueEntry     m_queue[ASQ_TG_QUEUE_SIZE];
   int                  m_queueCount;

   bool                 SendMessageToChat(string chatId, string text, bool silent);
   bool                 SendMessageAll(string text, bool silent = false);
   bool                 SendPhoto(string filePath, string caption = "");
   string               UrlEncode(string text);
   bool                 CheckRateLimit();
   bool                 IsSilentHour();
   string               GetTag(ENUM_ASQ_TG_NOTIFY type);
   string               FormatPrice(double price, int digits) { return DoubleToString(price, digits); }
   string               FormatProfit(double profit);
   string               EscapeMarkdown(string text);
   void                 ProcessQueue();
   void                 AddToQueue(string text);
   void                 CheckNewDay();
   void                 ASQLog(string msg);

public:
                        CASQTelegramNotifier();
                       ~CASQTelegramNotifier() {}

   // Initialization
   bool                 Initialize(string botToken, string chatId, string symbol);
   void                 AddChatId(string chatId);
   void                 SetSettings(SASQTelegramSettings &s) { m_settings = s; if(m_settings.botToken != "" && m_settings.chatCount > 0) m_initialized = true; }
   void                 SetEAName(string name)               { m_settings.eaName = name; }
   void                 SetVerbose(bool v)                   { m_verbose = v; }
   bool                 VerifyConnection();

   // Toggle notifications
   void                 Enable(bool e)                       { m_settings.enabled = e; }
   void                 EnableTradeOpen(bool e)              { m_settings.notifyTradeOpen = e; }
   void                 EnableTradeClose(bool e)             { m_settings.notifyTradeClose = e; }
   void                 EnableDailySummary(bool e)           { m_settings.notifyDailySummary = e; }
   void                 EnableErrors(bool e)                 { m_settings.notifyErrors = e; }
   void                 EnableSignals(bool e)                { m_settings.notifySignals = e; }
   void                 EnableScreenshots(bool e)            { m_settings.sendScreenshots = e; }
   void                 EnableEmoji(bool e)                  { m_settings.useEmoji = e; }
   void                 EnableStartupShutdown(bool s, bool d) { m_settings.notifyStartup = s; m_settings.notifyShutdown = d; }
   void                 SetSilentHours(bool use, int startGMT, int endGMT) { m_settings.useSilentHours = use; m_settings.silentStart = startGMT; m_settings.silentEnd = endGMT; }

   // Send notifications
   bool                 SendTradeOpen(string symbol, string direction, double lot,
                                      double price, double sl, double tp, string comment = "");
   bool                 SendTradeClose(string symbol, string direction, double lot,
                                       double openPrice, double closePrice, double profit,
                                       double pips, string reason = "");
   bool                 SendTradeModify(string symbol, double newSL, double newTP, string reason = "");
   bool                 SendDailySummary(double profit, int trades, int wins, int losses,
                                         double drawdown, double balance);
   bool                 SendWeeklySummary(double profit, int trades, int wins, int losses,
                                          double drawdown, double balance, double weeklyPct);
   bool                 SendError(string errorMsg);
   bool                 SendWarning(string warningMsg);
   bool                 SendInfo(string infoMsg);
   bool                 SendSignal(string symbol, string direction, double confidence, string reason);
   bool                 SendCustom(string message);
   bool                 SendStartup();
   bool                 SendShutdown(double sessionProfit, int sessionTrades);
   bool                 SendScreenshot(string caption = "");
   bool                 SendTestMessage();

   // Update (call periodically to process queue)
   void                 Update();

   // Status
   bool                 IsEnabled()            { return m_settings.enabled && m_initialized; }
   bool                 IsConfigured()          { return (m_settings.botToken != "" && m_settings.chatCount > 0); }
   bool                 IsConnectionVerified()  { return m_connectionVerified; }
   int                  GetSendCount()          { return m_sendCount; }
   int                  GetErrorCount()         { return m_errorCount; }
   int                  GetDailySendCount()     { return m_dailySendCount; }
   int                  GetDailyErrorCount()    { return m_dailyErrorCount; }
   int                  GetQueueSize()          { return m_queueCount; }
   string               GetLastError()          { return m_lastError; }
   int                  GetChatCount()          { return m_settings.chatCount; }
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CASQTelegramNotifier::CASQTelegramNotifier()
{
   m_settings.Reset(); m_symbol = ""; m_initialized = false;
   m_lastSend = 0; m_sendCount = 0; m_errorCount = 0;
   m_dailySendCount = 0; m_dailyErrorCount = 0;
   m_lastError = ""; m_messagesThisMinute = 0; m_minuteStart = 0;
   m_currentDay = 0; m_verbose = false; m_connectionVerified = false;
   m_queueCount = 0;
   for(int i = 0; i < ASQ_TG_QUEUE_SIZE; i++) m_queue[i].Reset();
}

//+------------------------------------------------------------------+
//| Initialize                                                        |
//+------------------------------------------------------------------+
bool CASQTelegramNotifier::Initialize(string botToken, string chatId, string symbol)
{
   m_settings.botToken = botToken;
   m_symbol = symbol;
   m_currentDay = TimeCurrent() - (TimeCurrent() % 86400);

   if(botToken == "" || chatId == "")
   {
      m_lastError = "Bot token or chat ID not configured";
      m_initialized = false; return false;
   }

   m_settings.chatIds[0] = chatId;
   m_settings.chatCount = 1;
   m_settings.enabled = true;
   m_initialized = true;
   ASQLog("Telegram v1.2 initialized | Symbol: " + symbol + " | Chats: 1");
   return true;
}

//+------------------------------------------------------------------+
//| Add additional chat ID                                            |
//+------------------------------------------------------------------+
void CASQTelegramNotifier::AddChatId(string chatId)
{
   if(chatId == "" || m_settings.chatCount >= ASQ_TG_MAX_CHATS) return;
   m_settings.chatIds[m_settings.chatCount] = chatId;
   m_settings.chatCount++;
   ASQLog("Added chat ID #" + IntegerToString(m_settings.chatCount));
}

//+------------------------------------------------------------------+
//| Verify connection via getMe                                       |
//+------------------------------------------------------------------+
bool CASQTelegramNotifier::VerifyConnection()
{
   string url = ASQ_TG_API_URL + m_settings.botToken + ASQ_TG_GET_ME;
   char post[], result[];
   string headers = "", resultHeaders;
   ArrayResize(post, 0);

   int res = WebRequest("GET", url, headers, ASQ_TG_TIMEOUT, post, result, resultHeaders);
   m_connectionVerified = (res == 200);
   if(!m_connectionVerified)
   {
      m_lastError = "Connection verification failed (HTTP " + IntegerToString(res) + ")";
      if(res == -1) m_lastError += " — Add https://api.telegram.org to allowed URLs";
   }
   ASQLog("Connection verify: " + (m_connectionVerified ? "OK" : "FAILED"));
   return m_connectionVerified;
}

//+------------------------------------------------------------------+
//| Update — process queue and daily reset                            |
//+------------------------------------------------------------------+
void CASQTelegramNotifier::Update()
{
   CheckNewDay();
   ProcessQueue();
}

void CASQTelegramNotifier::CheckNewDay()
{
   datetime today = TimeCurrent() - (TimeCurrent() % 86400);
   if(today != m_currentDay)
   {
      m_currentDay = today;
      m_dailySendCount = 0;
      m_dailyErrorCount = 0;
   }
}

//+------------------------------------------------------------------+
//| Send trade open                                                   |
//+------------------------------------------------------------------+
bool CASQTelegramNotifier::SendTradeOpen(string symbol, string direction, double lot,
                                          double price, double sl, double tp, string comment)
{
   if(!IsEnabled() || !m_settings.notifyTradeOpen) return false;
   if(IsSilentHour()) return false;
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   string msg = GetTag(ASQ_TG_TRADE_OPEN) + " *TRADE OPENED*\n\n";
   msg += "* *EA:* " + m_settings.eaName + "\n";
   msg += "* *Symbol:* " + symbol + "\n";
   msg += "* *Direction:* " + direction + "\n";
   msg += "* *Lot:* " + DoubleToString(lot, 2) + "\n";
   msg += "* *Entry:* " + FormatPrice(price, digits) + "\n";
   if(sl > 0) msg += "* *SL:* " + FormatPrice(sl, digits) + "\n";
   if(tp > 0) msg += "* *TP:* " + FormatPrice(tp, digits) + "\n";
   if(comment != "") msg += "* *Comment:* " + comment + "\n";
   msg += "\n" + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
   return SendMessageAll(msg);
}

//+------------------------------------------------------------------+
//| Send trade close                                                  |
//+------------------------------------------------------------------+
bool CASQTelegramNotifier::SendTradeClose(string symbol, string direction, double lot,
                                           double openPrice, double closePrice, double profit,
                                           double pips, string reason)
{
   if(!IsEnabled() || !m_settings.notifyTradeClose) return false;
   if(IsSilentHour()) return false;
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   string resultTag = (profit >= 0) ? "WIN" : "LOSS";
   string msg = GetTag(ASQ_TG_TRADE_CLOSE) + " *TRADE CLOSED — " + resultTag + "*\n\n";
   msg += "* *EA:* " + m_settings.eaName + "\n";
   msg += "* *Symbol:* " + symbol + " | " + direction + "\n";
   msg += "* *Lot:* " + DoubleToString(lot, 2) + "\n";
   if(openPrice > 0)
      msg += "* *Entry:* " + FormatPrice(openPrice, digits) + " -> *Exit:* " + FormatPrice(closePrice, digits) + "\n";
   msg += "* *Result:* " + FormatProfit(profit) + " (" + DoubleToString(pips, 1) + " pips)\n";
   if(reason != "") msg += "* *Reason:* " + reason + "\n";
   msg += "\n" + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
   return SendMessageAll(msg);
}

//+------------------------------------------------------------------+
//| Send trade modify                                                 |
//+------------------------------------------------------------------+
bool CASQTelegramNotifier::SendTradeModify(string symbol, double newSL, double newTP, string reason)
{
   if(!IsEnabled()) return false;
   if(IsSilentHour()) return false;
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   string msg = GetTag(ASQ_TG_TRADE_MODIFY) + " *TRADE MODIFIED*\n\n";
   msg += "* *Symbol:* " + symbol + "\n";
   if(newSL > 0) msg += "* *New SL:* " + FormatPrice(newSL, digits) + "\n";
   if(newTP > 0) msg += "* *New TP:* " + FormatPrice(newTP, digits) + "\n";
   if(reason != "") msg += "* *Reason:* " + reason + "\n";
   return SendMessageAll(msg);
}

//+------------------------------------------------------------------+
//| Send daily summary                                                |
//+------------------------------------------------------------------+
bool CASQTelegramNotifier::SendDailySummary(double profit, int trades, int wins, int losses,
                                             double drawdown, double balance)
{
   if(!IsEnabled() || !m_settings.notifyDailySummary) return false;
   double winRate = (trades > 0) ? (double)wins / trades * 100 : 0;
   string msg = GetTag(ASQ_TG_DAILY_SUMMARY) + " *DAILY SUMMARY*\n\n";
   msg += "* *EA:* " + m_settings.eaName + " | " + m_symbol + "\n\n";
   msg += "* *P/L:* " + FormatProfit(profit) + "\n";
   msg += "* *Trades:* " + IntegerToString(trades) + " (W:" + IntegerToString(wins) + " L:" + IntegerToString(losses) + ")\n";
   msg += "* *Win Rate:* " + DoubleToString(winRate, 1) + "%\n";
   msg += "* *Drawdown:* " + DoubleToString(drawdown, 2) + "%\n";
   msg += "* *Balance:* $" + DoubleToString(balance, 2) + "\n";
   msg += "\n" + TimeToString(TimeCurrent(), TIME_DATE);
   return SendMessageAll(msg);
}

//+------------------------------------------------------------------+
//| Send weekly summary                                               |
//+------------------------------------------------------------------+
bool CASQTelegramNotifier::SendWeeklySummary(double profit, int trades, int wins, int losses,
                                              double drawdown, double balance, double weeklyPct)
{
   if(!IsEnabled()) return false;
   double winRate = (trades > 0) ? (double)wins / trades * 100 : 0;
   string msg = GetTag(ASQ_TG_WEEKLY_SUMMARY) + " *WEEKLY SUMMARY*\n\n";
   msg += "* *EA:* " + m_settings.eaName + " | " + m_symbol + "\n\n";
   msg += "* *Weekly P/L:* " + FormatProfit(profit) + " (" + DoubleToString(weeklyPct, 2) + "%)\n";
   msg += "* *Trades:* " + IntegerToString(trades) + " (W:" + IntegerToString(wins) + " L:" + IntegerToString(losses) + ")\n";
   msg += "* *Win Rate:* " + DoubleToString(winRate, 1) + "%\n";
   msg += "* *Max DD:* " + DoubleToString(drawdown, 2) + "%\n";
   msg += "* *Balance:* $" + DoubleToString(balance, 2) + "\n";
   return SendMessageAll(msg);
}

//+------------------------------------------------------------------+
//| Send error / warning / info / signal / custom                     |
//+------------------------------------------------------------------+
bool CASQTelegramNotifier::SendError(string errorMsg)
{
   if(!IsEnabled() || !m_settings.notifyErrors) return false;
   return SendMessageAll(GetTag(ASQ_TG_ERROR) + " *ERROR*\n\n* " + m_settings.eaName + " | " + m_symbol + "\n* " + EscapeMarkdown(errorMsg));
}

bool CASQTelegramNotifier::SendWarning(string warningMsg)
{
   if(!IsEnabled()) return false;
   return SendMessageAll(GetTag(ASQ_TG_WARNING) + " *WARNING*\n\n" + EscapeMarkdown(warningMsg));
}

bool CASQTelegramNotifier::SendInfo(string infoMsg)
{
   if(!IsEnabled()) return false;
   return SendMessageAll(GetTag(ASQ_TG_INFO) + " *INFO*\n\n" + EscapeMarkdown(infoMsg));
}

bool CASQTelegramNotifier::SendSignal(string symbol, string direction, double confidence, string reason)
{
   if(!IsEnabled() || !m_settings.notifySignals) return false;
   string msg = GetTag(ASQ_TG_SIGNAL) + " *SIGNAL: " + direction + " " + symbol + "*\n\n";
   msg += "* *Confidence:* " + DoubleToString(confidence, 0) + "%\n";
   msg += "* *Reason:* " + EscapeMarkdown(reason) + "\n";
   msg += "\n" + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
   return SendMessageAll(msg);
}

bool CASQTelegramNotifier::SendCustom(string message)
{
   if(!IsEnabled()) return false;
   return SendMessageAll(message);
}

//+------------------------------------------------------------------+
//| Send startup / shutdown                                           |
//+------------------------------------------------------------------+
bool CASQTelegramNotifier::SendStartup()
{
   if(!IsEnabled() || !m_settings.notifyStartup) return false;
   string msg = GetTag(ASQ_TG_STARTUP) + " *EA STARTED*\n\n";
   msg += "* *EA:* " + m_settings.eaName + "\n";
   msg += "* *Symbol:* " + m_symbol + "\n";
   msg += "* *Balance:* $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n";
   msg += "* *Broker:* " + AccountInfoString(ACCOUNT_COMPANY) + "\n";
   msg += "\n" + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
   return SendMessageAll(msg);
}

bool CASQTelegramNotifier::SendShutdown(double sessionProfit, int sessionTrades)
{
   if(!IsEnabled() || !m_settings.notifyShutdown) return false;
   string msg = GetTag(ASQ_TG_SHUTDOWN) + " *EA STOPPED*\n\n";
   msg += "* *EA:* " + m_settings.eaName + "\n";
   msg += "* *Session P/L:* " + FormatProfit(sessionProfit) + "\n";
   msg += "* *Session Trades:* " + IntegerToString(sessionTrades) + "\n";
   msg += "* *Messages Sent:* " + IntegerToString(m_dailySendCount) + "\n";
   msg += "\n" + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
   return SendMessageAll(msg);
}

//+------------------------------------------------------------------+
//| Send screenshot                                                   |
//+------------------------------------------------------------------+
bool CASQTelegramNotifier::SendScreenshot(string caption)
{
   if(!IsEnabled() || !m_settings.sendScreenshots) return false;
   string filename = "asq_screenshot_" + IntegerToString(GetTickCount()) + ".png";
   if(!ChartScreenShot(0, filename, 1920, 1080, ALIGN_RIGHT))
   {
      m_lastError = "Failed to create screenshot"; return false;
   }
   return SendPhoto(filename, caption);
}

//+------------------------------------------------------------------+
//| Send test message                                                 |
//+------------------------------------------------------------------+
bool CASQTelegramNotifier::SendTestMessage()
{
   string msg = GetTag(ASQ_TG_INFO) + " *ASQ TELEGRAM TEST*\n\n";
   msg += "* *EA:* " + m_settings.eaName + "\n";
   msg += "* *Symbol:* " + m_symbol + "\n";
   msg += "* *Status:* Connected!\n";
   msg += "* *Chats:* " + IntegerToString(m_settings.chatCount) + "\n";
   msg += "\n" + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
   return SendMessageAll(msg);
}

//+------------------------------------------------------------------+
//| Internal: Send to all chat IDs                                    |
//+------------------------------------------------------------------+
bool CASQTelegramNotifier::SendMessageAll(string text, bool silent)
{
   if(IsSilentHour()) silent = true;

   bool anySuccess = false;
   for(int i = 0; i < m_settings.chatCount; i++)
   {
      if(m_settings.chatIds[i] != "")
      {
         if(SendMessageToChat(m_settings.chatIds[i], text, silent))
            anySuccess = true;
      }
   }
   if(!anySuccess) AddToQueue(text);
   return anySuccess;
}

//+------------------------------------------------------------------+
//| Internal: Send to single chat                                     |
//+------------------------------------------------------------------+
bool CASQTelegramNotifier::SendMessageToChat(string chatId, string text, bool silent)
{
   if(!CheckRateLimit()) { m_lastError = "Rate limit exceeded"; return false; }

   string url = ASQ_TG_API_URL + m_settings.botToken + ASQ_TG_SEND_MSG;
   string postData = "chat_id=" + chatId + "&text=" + UrlEncode(text) + "&parse_mode=Markdown";
   if(silent) postData += "&disable_notification=true";

   char post[], result[];
   string headers = "Content-Type: application/x-www-form-urlencoded\r\n";
   string resultHeaders;
   StringToCharArray(postData, post, 0, WHOLE_ARRAY, CP_UTF8);
   ArrayResize(post, ArraySize(post) - 1);

   int res = WebRequest("POST", url, headers, ASQ_TG_TIMEOUT, post, result, resultHeaders);
   if(res == -1)
   {
      int error = GetLastError();
      m_lastError = "WebRequest error: " + IntegerToString(error);
      if(error == 4014) m_lastError += " — Add https://api.telegram.org to allowed URLs";
      m_errorCount++; m_dailyErrorCount++;
      ASQLog("Send failed: " + m_lastError);
      return false;
   }
   if(res != 200) { m_lastError = "HTTP " + IntegerToString(res); m_errorCount++; m_dailyErrorCount++; return false; }

   m_sendCount++; m_dailySendCount++; m_lastSend = TimeCurrent(); m_messagesThisMinute++;
   return true;
}

//+------------------------------------------------------------------+
//| Internal: Send photo (placeholder for multipart)                  |
//+------------------------------------------------------------------+
bool CASQTelegramNotifier::SendPhoto(string filePath, string caption)
{
   m_lastError = "Photo sending requires multipart/form-data (not yet implemented)";
   return false;
}

//+------------------------------------------------------------------+
//| Message queue                                                     |
//+------------------------------------------------------------------+
void CASQTelegramNotifier::AddToQueue(string text)
{
   if(m_queueCount >= ASQ_TG_QUEUE_SIZE)
   {
      // Drop oldest
      for(int i = 0; i < ASQ_TG_QUEUE_SIZE - 1; i++)
         m_queue[i] = m_queue[i + 1];
      m_queueCount = ASQ_TG_QUEUE_SIZE - 1;
   }
   m_queue[m_queueCount].text = text;
   m_queue[m_queueCount].retries = 0;
   m_queue[m_queueCount].queued = TimeCurrent();
   m_queue[m_queueCount].pending = true;
   m_queueCount++;
}

void CASQTelegramNotifier::ProcessQueue()
{
   if(m_queueCount == 0) return;

   for(int i = 0; i < m_queueCount; i++)
   {
      if(!m_queue[i].pending) continue;
      if(m_queue[i].retries >= ASQ_TG_MAX_RETRIES)
      {
         m_queue[i].pending = false;
         continue;
      }

      bool sent = false;
      for(int c = 0; c < m_settings.chatCount; c++)
      {
         if(m_settings.chatIds[c] != "" && SendMessageToChat(m_settings.chatIds[c], m_queue[i].text, false))
            sent = true;
      }

      if(sent)
         m_queue[i].pending = false;
      else
         m_queue[i].retries++;
   }

   // Compact queue
   int writeIdx = 0;
   for(int i = 0; i < m_queueCount; i++)
   {
      if(m_queue[i].pending)
      {
         if(writeIdx != i) m_queue[writeIdx] = m_queue[i];
         writeIdx++;
      }
   }
   m_queueCount = writeIdx;
}

//+------------------------------------------------------------------+
//| Silent hours check                                                |
//+------------------------------------------------------------------+
bool CASQTelegramNotifier::IsSilentHour()
{
   if(!m_settings.useSilentHours) return false;
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int h = dt.hour;
   if(m_settings.silentStart < m_settings.silentEnd)
      return (h >= m_settings.silentStart && h < m_settings.silentEnd);
   else
      return (h >= m_settings.silentStart || h < m_settings.silentEnd);
}

//+------------------------------------------------------------------+
//| URL encode                                                        |
//+------------------------------------------------------------------+
string CASQTelegramNotifier::UrlEncode(string text)
{
   string result = "";
   int len = StringLen(text);
   for(int i = 0; i < len; i++)
   {
      ushort c = StringGetCharacter(text, i);
      if((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
         (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '~')
         result += CharToString((uchar)c);
      else if(c == ' ') result += "+";
      else if(c == '\n') result += "%0A";
      else if(c == '*') result += "%2A";
      else result += StringFormat("%%%02X", c);
   }
   return result;
}

//+------------------------------------------------------------------+
//| Rate limit (20 msg/min)                                           |
//+------------------------------------------------------------------+
bool CASQTelegramNotifier::CheckRateLimit()
{
   datetime now = TimeCurrent();
   if(now - m_minuteStart >= 60) { m_minuteStart = now; m_messagesThisMinute = 0; }
   return (m_messagesThisMinute < 20);
}

//+------------------------------------------------------------------+
//| Tag helper                                                        |
//+------------------------------------------------------------------+
string CASQTelegramNotifier::GetTag(ENUM_ASQ_TG_NOTIFY type)
{
   if(!m_settings.useEmoji) return "";
   switch(type)
   {
      case ASQ_TG_TRADE_OPEN:     return "[OPEN]";
      case ASQ_TG_TRADE_CLOSE:    return "[CLOSE]";
      case ASQ_TG_TRADE_MODIFY:   return "[MODIFY]";
      case ASQ_TG_DAILY_SUMMARY:  return "[DAILY]";
      case ASQ_TG_WEEKLY_SUMMARY: return "[WEEKLY]";
      case ASQ_TG_ERROR:          return "[ERROR]";
      case ASQ_TG_WARNING:        return "[WARN]";
      case ASQ_TG_INFO:           return "[INFO]";
      case ASQ_TG_SIGNAL:         return "[SIGNAL]";
      case ASQ_TG_STARTUP:        return "[START]";
      case ASQ_TG_SHUTDOWN:       return "[STOP]";
      default:                    return "[NOTE]";
   }
}

string CASQTelegramNotifier::FormatProfit(double profit)
{
   return (profit >= 0 ? "+" : "") + "$" + DoubleToString(profit, 2);
}

string CASQTelegramNotifier::EscapeMarkdown(string text)
{
   StringReplace(text, "_", "\\_"); StringReplace(text, "[", "\\[");
   StringReplace(text, "]", "\\]"); StringReplace(text, "(", "\\(");
   StringReplace(text, ")", "\\)"); StringReplace(text, "`", "\\`");
   return text;
}

void CASQTelegramNotifier::ASQLog(string msg)
{
   if(!m_verbose) return;
   if(MQLInfoInteger(MQL_TESTER)) return;
   Print("[ASQ Telegram] ", msg);
}

#endif // ASQ_TELEGRAM_NOTIFIER_MQH
