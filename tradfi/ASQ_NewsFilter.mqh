//+------------------------------------------------------------------+
//|                                             ASQ_NewsFilter.mqh   |
//|                        Copyright 2026, AlgoSphere Quant          |
//|                        https://www.mql5.com/en/users/robin2.0    |
//+------------------------------------------------------------------+
//| ASQ News Filter v1.2 — Free, Open-Source                         |
//|                                                                   |
//| Economic calendar trading guard library for MQL5.                 |
//|                                                                   |
//| FEATURES:                                                         |
//| • MQL5 Calendar API live integration (auto-fetch events)          |
//| • High/Medium/Low impact event filtering                          |
//| • Configurable pre-news and post-news trading pauses              |
//| • Special event extended cooldowns (NFP 60m, FOMC 90m)            |
//| • Currency-specific event filtering (auto-detects pair)           |
//| • NFP, FOMC, ECB, BOE, BOJ, RBA, BOC, SNB, RBNZ coverage        |
//| • Built-in event scheduler for all major central banks            |
//| • News intensity scoring (calm/caution/danger/blackout)           |
//| • Custom event support                                            |
//| • Event deduplication                                              |
//| • Next 3 upcoming events list                                     |
//|                                                                   |
//| USAGE:                                                            |
//|   #include "ASQ_NewsFilter.mqh"                                  |
//|   CASQNewsFilter news;                                            |
//|   news.Initialize(_Symbol);                                       |
//|   news.SetMode(ASQ_NEWS_HIGH_ONLY);                              |
//|   news.Update();  // Call on every tick or timer                  |
//|   if(news.IsTradingAllowed()) { ... }                            |
//|                                                                   |
//| AlgoSphere Quant — Precision before profit.                      |
//| https://www.mql5.com/en/users/robin2.0                           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, AlgoSphere Quant"
#property link      "https://www.mql5.com/en/users/robin2.0"
#property version   "1.20"
#property strict

#ifndef ASQ_NEWS_FILTER_MQH
#define ASQ_NEWS_FILTER_MQH

//+------------------------------------------------------------------+
//| CONSTANTS                                                         |
//+------------------------------------------------------------------+
#define ASQ_MAX_NEWS_EVENTS       100
#define ASQ_NEWS_LOOKBACK_DAYS    7
#define ASQ_NEWS_LOOKAHEAD_DAYS   7
#define ASQ_DEFAULT_PRE_NEWS_MIN  30
#define ASQ_DEFAULT_POST_NEWS_MIN 30
#define ASQ_NFP_POST_NEWS_MIN     60
#define ASQ_FOMC_POST_NEWS_MIN    90
#define ASQ_CALENDAR_REFRESH_SEC  300    // Refresh MQL5 Calendar every 5 min
#define ASQ_UPCOMING_LIST_SIZE    3

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                      |
//+------------------------------------------------------------------+
enum ENUM_ASQ_NEWS_IMPACT
{
   ASQ_NEWS_IMPACT_NONE    = 0,
   ASQ_NEWS_IMPACT_LOW     = 1,
   ASQ_NEWS_IMPACT_MEDIUM  = 2,
   ASQ_NEWS_IMPACT_HIGH    = 3
};

enum ENUM_ASQ_NEWS_TYPE
{
   ASQ_NEWS_GENERAL        = 0,
   ASQ_NEWS_NFP            = 1,
   ASQ_NEWS_FOMC           = 2,
   ASQ_NEWS_ECB            = 3,
   ASQ_NEWS_BOE            = 4,
   ASQ_NEWS_BOJ            = 5,
   ASQ_NEWS_RBA            = 6,
   ASQ_NEWS_RBNZ           = 7,
   ASQ_NEWS_SNB            = 8,
   ASQ_NEWS_BOC            = 9,
   ASQ_NEWS_GDP            = 10,
   ASQ_NEWS_CPI            = 11,
   ASQ_NEWS_RETAIL         = 12,
   ASQ_NEWS_PMI            = 13,
   ASQ_NEWS_EMPLOYMENT     = 14,
   ASQ_NEWS_SPEECH         = 15,
   ASQ_NEWS_CUSTOM         = 99
};

enum ENUM_ASQ_NEWS_MODE
{
   ASQ_NEWS_FILTER_OFF     = 0,
   ASQ_NEWS_HIGH_ONLY      = 1,
   ASQ_NEWS_HIGH_MEDIUM    = 2,
   ASQ_NEWS_ALL            = 3
};

enum ENUM_ASQ_NEWS_INTENSITY
{
   ASQ_INTENSITY_CALM      = 0,     // No events nearby
   ASQ_INTENSITY_CAUTION   = 1,     // Event within 2 hours
   ASQ_INTENSITY_DANGER    = 2,     // Event within pre-news window
   ASQ_INTENSITY_BLACKOUT  = 3      // Trading blocked
};

//+------------------------------------------------------------------+
//| DATA STRUCTURES                                                   |
//+------------------------------------------------------------------+
struct SASQNewsEvent
{
   datetime                time;
   string                  title;
   string                  currency;
   ENUM_ASQ_NEWS_IMPACT    impact;
   ENUM_ASQ_NEWS_TYPE      type;
   string                  forecast;
   string                  previous;
   string                  actual;
   bool                    passed;
   bool                    affectsSymbol;
   int                     customPreMin;      // -1 = use default
   int                     customPostMin;     // -1 = use default

   void Reset()
   {
      time = 0; title = ""; currency = "";
      impact = ASQ_NEWS_IMPACT_NONE; type = ASQ_NEWS_GENERAL;
      forecast = ""; previous = ""; actual = "";
      passed = false; affectsSymbol = false;
      customPreMin = -1; customPostMin = -1;
   }
};

struct SASQNewsStatus
{
   bool                    tradingAllowed;
   bool                    inPreNewsWindow;
   bool                    inPostNewsWindow;
   bool                    inNewsWindow;
   ENUM_ASQ_NEWS_INTENSITY intensity;

   SASQNewsEvent           nextEvent;
   SASQNewsEvent           lastEvent;
   int                     minutesToNext;
   int                     minutesSinceLast;

   SASQNewsEvent           upcoming[ASQ_UPCOMING_LIST_SIZE];
   int                     upcomingCount;

   int                     upcomingHighCount;
   int                     upcomingMediumCount;
   int                     upcomingLowCount;

   string                  statusMessage;
   datetime                updated;

   int                     activePreMin;      // Effective pre window
   int                     activePostMin;     // Effective post window

   void Reset()
   {
      tradingAllowed = true;
      inPreNewsWindow = false; inPostNewsWindow = false; inNewsWindow = false;
      intensity = ASQ_INTENSITY_CALM;
      nextEvent.Reset(); lastEvent.Reset();
      minutesToNext = 9999; minutesSinceLast = 9999;
      upcomingCount = 0;
      for(int i = 0; i < ASQ_UPCOMING_LIST_SIZE; i++) upcoming[i].Reset();
      upcomingHighCount = 0; upcomingMediumCount = 0; upcomingLowCount = 0;
      statusMessage = "No news filter active"; updated = 0;
      activePreMin = 0; activePostMin = 0;
   }
};

//+------------------------------------------------------------------+
//| NEWS FILTER CLASS                                                 |
//+------------------------------------------------------------------+
class CASQNewsFilter
{
private:
   string               m_symbol;
   string               m_baseCurrency;
   string               m_quoteCurrency;

   SASQNewsEvent        m_events[];
   int                  m_eventCount;

   SASQNewsStatus       m_status;

   ENUM_ASQ_NEWS_MODE   m_mode;
   int                  m_preNewsMinutes;
   int                  m_postNewsMinutes;
   bool                 m_filterNFP;
   bool                 m_filterFOMC;
   bool                 m_filterECB;
   bool                 m_filterAll;
   bool                 m_useSpecialCooldowns;
   bool                 m_useMQL5Calendar;

   bool                 m_initialized;
   bool                 m_verbose;
   datetime             m_lastUpdate;
   datetime             m_lastCalendarFetch;

   // Internal
   void                 ParseSymbolCurrencies();
   void                 UpdateEventStatus();
   void                 SortEvents();
   bool                 ShouldFilterEvent(SASQNewsEvent &event);
   int                  GetEffectivePreMinutes(SASQNewsEvent &event);
   int                  GetEffectivePostMinutes(SASQNewsEvent &event);
   void                 AddRecurringEvents();
   void                 AddNFPDates();
   void                 AddFOMCDates();
   void                 AddECBDates();
   void                 AddBOEDates();
   void                 AddBOJDates();
   void                 AddRBADates();
   void                 AddBOCDates();
   bool                 IsDuplicateEvent(datetime time, string title);
   void                 FetchMQL5Calendar();
   ENUM_ASQ_NEWS_IMPACT MapCalendarImportance(int importance);
   ENUM_ASQ_NEWS_TYPE   ClassifyEvent(string title, string currency);
   datetime             GetNthWeekdayOfMonth(int year, int month, int dayOfWeek, int n, int hour, int minute);
   void                 ASQLog(string msg);

public:
                        CASQNewsFilter();
                       ~CASQNewsFilter();

   //--- Initialization
   bool                 Initialize(string symbol);
   void                 SetMode(ENUM_ASQ_NEWS_MODE mode)    { m_mode = mode; }
   void                 SetPreNewsMinutes(int minutes)      { m_preNewsMinutes = MathMax(5, MathMin(120, minutes)); }
   void                 SetPostNewsMinutes(int minutes)     { m_postNewsMinutes = MathMax(5, MathMin(120, minutes)); }
   void                 SetFilterNFP(bool filter)           { m_filterNFP = filter; }
   void                 SetFilterFOMC(bool filter)          { m_filterFOMC = filter; }
   void                 SetFilterECB(bool filter)           { m_filterECB = filter; }
   void                 SetFilterAll(bool filter)           { m_filterAll = filter; }
   void                 SetSpecialCooldowns(bool use)       { m_useSpecialCooldowns = use; }
   void                 SetUseMQL5Calendar(bool use)        { m_useMQL5Calendar = use; }
   void                 SetVerbose(bool v)                  { m_verbose = v; }

   //--- Event management
   void                 AddEvent(SASQNewsEvent &event);
   void                 AddEvent(datetime time, string title, string currency,
                                ENUM_ASQ_NEWS_IMPACT impact, ENUM_ASQ_NEWS_TYPE type = ASQ_NEWS_GENERAL);
   void                 LoadBuiltInEvents();
   void                 ClearEvents();
   int                  GetEventCount()                     { return m_eventCount; }

   //--- Update (call on every tick or timer)
   void                 Update();
   void                 CheckNewsWindows();

   //--- Status
   SASQNewsStatus       GetStatus()                         { return m_status; }
   bool                 IsTradingAllowed();
   bool                 IsInNewsWindow()                    { return m_status.inNewsWindow; }
   bool                 IsHighImpactSoon(int minutesAhead = 60);
   ENUM_ASQ_NEWS_INTENSITY GetIntensity()                   { return m_status.intensity; }

   //--- Event queries
   bool                 GetNextEvent(SASQNewsEvent &event);
   bool                 GetLastEvent(SASQNewsEvent &event);
   int                  GetMinutesToNextNews()              { return m_status.minutesToNext; }
   int                  GetUpcomingEventCount(ENUM_ASQ_NEWS_IMPACT minImpact);

   //--- Utility
   string               GetStatusMessage()                  { return m_status.statusMessage; }
   string               ImpactToString(ENUM_ASQ_NEWS_IMPACT impact);
   string               TypeToString(ENUM_ASQ_NEWS_TYPE type);
   string               IntensityToString(ENUM_ASQ_NEWS_INTENSITY intensity);
   bool                 CurrencyAffectsSymbol(string currency);
   void                 Reset();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CASQNewsFilter::CASQNewsFilter()
{
   m_symbol = ""; m_baseCurrency = ""; m_quoteCurrency = "";
   m_eventCount = 0;
   m_mode = ASQ_NEWS_HIGH_ONLY;
   m_preNewsMinutes = ASQ_DEFAULT_PRE_NEWS_MIN;
   m_postNewsMinutes = ASQ_DEFAULT_POST_NEWS_MIN;
   m_filterNFP = true; m_filterFOMC = true; m_filterECB = true; m_filterAll = false;
   m_useSpecialCooldowns = true;
   m_useMQL5Calendar = true;
   m_initialized = false; m_verbose = false;
   m_lastUpdate = 0; m_lastCalendarFetch = 0;
   m_status.Reset();
   ArrayResize(m_events, ASQ_MAX_NEWS_EVENTS);
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CASQNewsFilter::~CASQNewsFilter()
{
   ArrayFree(m_events);
}

//+------------------------------------------------------------------+
//| Initialize                                                        |
//+------------------------------------------------------------------+
bool CASQNewsFilter::Initialize(string symbol)
{
   m_symbol = symbol;
   ParseSymbolCurrencies();
   LoadBuiltInEvents();
   m_status.Reset();
   m_initialized = true;
   ASQLog("News Filter v1.2 initialized for " + symbol +
          " | Base: " + m_baseCurrency + " | Quote: " + m_quoteCurrency +
          " | Events: " + IntegerToString(m_eventCount));
   return true;
}

//+------------------------------------------------------------------+
//| Add event (struct)                                                |
//+------------------------------------------------------------------+
void CASQNewsFilter::AddEvent(SASQNewsEvent &event)
{
   // Deduplication
   if(IsDuplicateEvent(event.time, event.title)) return;

   if(m_eventCount >= ASQ_MAX_NEWS_EVENTS)
   {
      // Remove oldest passed event
      for(int i = 0; i < m_eventCount; i++)
      {
         if(m_events[i].passed)
         {
            for(int j = i; j < m_eventCount - 1; j++)
               m_events[j] = m_events[j + 1];
            m_eventCount--;
            break;
         }
      }
      if(m_eventCount >= ASQ_MAX_NEWS_EVENTS)
      {
         for(int i = 0; i < m_eventCount - 1; i++)
            m_events[i] = m_events[i + 1];
         m_eventCount = ASQ_MAX_NEWS_EVENTS - 1;
      }
   }

   event.affectsSymbol = CurrencyAffectsSymbol(event.currency);

   // Auto-assign special cooldowns
   if(m_useSpecialCooldowns && event.customPostMin < 0)
   {
      if(event.type == ASQ_NEWS_NFP)  event.customPostMin = ASQ_NFP_POST_NEWS_MIN;
      if(event.type == ASQ_NEWS_FOMC) event.customPostMin = ASQ_FOMC_POST_NEWS_MIN;
   }

   m_events[m_eventCount] = event;
   m_eventCount++;
   SortEvents();
}

//+------------------------------------------------------------------+
//| Add event (parameters)                                            |
//+------------------------------------------------------------------+
void CASQNewsFilter::AddEvent(datetime time, string title, string currency,
                              ENUM_ASQ_NEWS_IMPACT impact, ENUM_ASQ_NEWS_TYPE type)
{
   SASQNewsEvent event;
   event.Reset();
   event.time = time; event.title = title; event.currency = currency;
   event.impact = impact; event.type = type;
   AddEvent(event);
}

//+------------------------------------------------------------------+
//| Check for duplicate event                                         |
//+------------------------------------------------------------------+
bool CASQNewsFilter::IsDuplicateEvent(datetime time, string title)
{
   for(int i = 0; i < m_eventCount; i++)
   {
      if(m_events[i].time == time && m_events[i].title == title)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Load built-in economic calendar                                   |
//+------------------------------------------------------------------+
void CASQNewsFilter::LoadBuiltInEvents()
{
   ClearEvents();
   AddNFPDates();
   AddFOMCDates();
   AddECBDates();
   AddBOEDates();
   AddBOJDates();
   AddRBADates();
   AddBOCDates();
   if(m_useMQL5Calendar)
      FetchMQL5Calendar();
   ASQLog("Loaded " + IntegerToString(m_eventCount) + " events");
}

//+------------------------------------------------------------------+
//| Fetch events from MQL5 Calendar API                               |
//+------------------------------------------------------------------+
void CASQNewsFilter::FetchMQL5Calendar()
{
   datetime now = TimeCurrent();
   datetime from = now - ASQ_NEWS_LOOKBACK_DAYS * 86400;
   datetime to   = now + ASQ_NEWS_LOOKAHEAD_DAYS * 86400;

   MqlCalendarValue values[];
   int count = CalendarValueHistory(values, from, to);
   if(count <= 0) return;

   for(int i = 0; i < count && m_eventCount < ASQ_MAX_NEWS_EVENTS; i++)
   {
      MqlCalendarEvent calEvent;
      if(!CalendarEventById(values[i].event_id, calEvent)) continue;

      MqlCalendarCountry calCountry;
      if(!CalendarCountryById(calEvent.country_id, calCountry)) continue;

      string currency = calCountry.currency;
      if(!CurrencyAffectsSymbol(currency) && !m_filterAll) continue;

      ENUM_ASQ_NEWS_IMPACT impact = MapCalendarImportance((int)calEvent.importance);
      if(impact == ASQ_NEWS_IMPACT_NONE) continue;

      // Filter by mode
      if(m_mode == ASQ_NEWS_HIGH_ONLY && impact < ASQ_NEWS_IMPACT_HIGH) continue;
      if(m_mode == ASQ_NEWS_HIGH_MEDIUM && impact < ASQ_NEWS_IMPACT_MEDIUM) continue;

      ENUM_ASQ_NEWS_TYPE type = ClassifyEvent(calEvent.name, currency);

      SASQNewsEvent event;
      event.Reset();
      event.time = values[i].time;
      event.title = calEvent.name;
      event.currency = currency;
      event.impact = impact;
      event.type = type;
      if(values[i].HasActualValue())  event.actual   = DoubleToString(values[i].GetActualValue(), 2);
      if(values[i].HasForecastValue()) event.forecast = DoubleToString(values[i].GetForecastValue(), 2);
      if(values[i].HasPreviousValue()) event.previous = DoubleToString(values[i].GetPreviousValue(), 2);

      AddEvent(event);
   }

   m_lastCalendarFetch = now;
   ASQLog("MQL5 Calendar: fetched " + IntegerToString(count) + " raw events");
}

//+------------------------------------------------------------------+
//| Map MQL5 Calendar importance to ASQ impact                        |
//+------------------------------------------------------------------+
ENUM_ASQ_NEWS_IMPACT CASQNewsFilter::MapCalendarImportance(int importance)
{
   switch(importance)
   {
      case 0:  return ASQ_NEWS_IMPACT_NONE;
      case 1:  return ASQ_NEWS_IMPACT_LOW;
      case 2:  return ASQ_NEWS_IMPACT_MEDIUM;
      case 3:  return ASQ_NEWS_IMPACT_HIGH;
      default: return ASQ_NEWS_IMPACT_LOW;
   }
}

//+------------------------------------------------------------------+
//| Classify event type from title and currency                       |
//+------------------------------------------------------------------+
ENUM_ASQ_NEWS_TYPE CASQNewsFilter::ClassifyEvent(string title, string currency)
{
   string lower = title;
   StringToLower(lower);

   if(StringFind(lower, "non-farm")      >= 0 || StringFind(lower, "nonfarm") >= 0) return ASQ_NEWS_NFP;
   if(StringFind(lower, "fomc")          >= 0 || StringFind(lower, "fed fund") >= 0) return ASQ_NEWS_FOMC;
   if(StringFind(lower, "ecb")           >= 0 && currency == "EUR") return ASQ_NEWS_ECB;
   if(StringFind(lower, "boe")           >= 0 || (StringFind(lower, "bank rate") >= 0 && currency == "GBP")) return ASQ_NEWS_BOE;
   if(StringFind(lower, "boj")           >= 0 || (StringFind(lower, "interest rate") >= 0 && currency == "JPY")) return ASQ_NEWS_BOJ;
   if(StringFind(lower, "rba")           >= 0 || (StringFind(lower, "cash rate") >= 0 && currency == "AUD")) return ASQ_NEWS_RBA;
   if(StringFind(lower, "boc")           >= 0 || (StringFind(lower, "overnight rate") >= 0 && currency == "CAD")) return ASQ_NEWS_BOC;
   if(StringFind(lower, "gdp")           >= 0) return ASQ_NEWS_GDP;
   if(StringFind(lower, "cpi")           >= 0 || StringFind(lower, "inflation") >= 0) return ASQ_NEWS_CPI;
   if(StringFind(lower, "retail")        >= 0) return ASQ_NEWS_RETAIL;
   if(StringFind(lower, "pmi")           >= 0) return ASQ_NEWS_PMI;
   if(StringFind(lower, "employment")    >= 0 || StringFind(lower, "unemployment") >= 0 || StringFind(lower, "payroll") >= 0) return ASQ_NEWS_EMPLOYMENT;
   if(StringFind(lower, "speech")        >= 0 || StringFind(lower, "speaks") >= 0 || StringFind(lower, "press conference") >= 0) return ASQ_NEWS_SPEECH;

   return ASQ_NEWS_GENERAL;
}

//+------------------------------------------------------------------+
//| Add NFP dates (First Friday of each month, 13:30 GMT)             |
//+------------------------------------------------------------------+
void CASQNewsFilter::AddNFPDates()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);

   for(int m = 0; m < 6; m++)
   {
      int year = dt.year;
      int month = dt.mon + m;
      if(month > 12) { month -= 12; year++; }

      datetime nfpDate = GetNthWeekdayOfMonth(year, month, 5, 1, 13, 30);
      if(nfpDate > now)
      {
         AddEvent(nfpDate, "Non-Farm Payrolls", "USD", ASQ_NEWS_IMPACT_HIGH, ASQ_NEWS_NFP);
         AddEvent(nfpDate, "Unemployment Rate", "USD", ASQ_NEWS_IMPACT_HIGH, ASQ_NEWS_EMPLOYMENT);
      }
   }
}

//+------------------------------------------------------------------+
//| Add FOMC dates (8 meetings per year, 19:00 GMT)                   |
//+------------------------------------------------------------------+
void CASQNewsFilter::AddFOMCDates()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   int year = dt.year;

   int fomcMonths[] = {1, 3, 5, 6, 7, 9, 11, 12};
   for(int i = 0; i < ArraySize(fomcMonths); i++)
   {
      datetime fomcDate = GetNthWeekdayOfMonth(year, fomcMonths[i], 3, 3, 19, 0);
      if(fomcDate > now)
      {
         AddEvent(fomcDate, "FOMC Interest Rate Decision", "USD", ASQ_NEWS_IMPACT_HIGH, ASQ_NEWS_FOMC);
         AddEvent(fomcDate + 30 * 60, "FOMC Press Conference", "USD", ASQ_NEWS_IMPACT_HIGH, ASQ_NEWS_SPEECH);
      }
   }
}

//+------------------------------------------------------------------+
//| Add ECB dates (13:15 GMT)                                         |
//+------------------------------------------------------------------+
void CASQNewsFilter::AddECBDates()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   int year = dt.year;

   int ecbMonths[] = {1, 3, 4, 6, 7, 9, 10, 12};
   for(int i = 0; i < ArraySize(ecbMonths); i++)
   {
      datetime ecbDate = GetNthWeekdayOfMonth(year, ecbMonths[i], 4, 2, 13, 15);
      if(ecbDate > now)
      {
         AddEvent(ecbDate, "ECB Interest Rate Decision", "EUR", ASQ_NEWS_IMPACT_HIGH, ASQ_NEWS_ECB);
         AddEvent(ecbDate + 30 * 60, "ECB Press Conference", "EUR", ASQ_NEWS_IMPACT_HIGH, ASQ_NEWS_SPEECH);
      }
   }
}

//+------------------------------------------------------------------+
//| Add BOE dates (12:00 GMT, 8 meetings/year)                        |
//+------------------------------------------------------------------+
void CASQNewsFilter::AddBOEDates()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   int year = dt.year;

   int boeMonths[] = {2, 3, 5, 6, 8, 9, 11, 12};
   for(int i = 0; i < ArraySize(boeMonths); i++)
   {
      datetime boeDate = GetNthWeekdayOfMonth(year, boeMonths[i], 4, 2, 12, 0);
      if(boeDate > now)
         AddEvent(boeDate, "BOE Interest Rate Decision", "GBP", ASQ_NEWS_IMPACT_HIGH, ASQ_NEWS_BOE);
   }
}

//+------------------------------------------------------------------+
//| Add BOJ dates (approximate — varies, early month)                 |
//+------------------------------------------------------------------+
void CASQNewsFilter::AddBOJDates()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   int year = dt.year;

   int bojMonths[] = {1, 3, 4, 6, 7, 9, 10, 12};
   for(int i = 0; i < ArraySize(bojMonths); i++)
   {
      datetime bojDate = GetNthWeekdayOfMonth(year, bojMonths[i], 5, 3, 3, 0);
      if(bojDate > now)
         AddEvent(bojDate, "BOJ Interest Rate Decision", "JPY", ASQ_NEWS_IMPACT_HIGH, ASQ_NEWS_BOJ);
   }
}

//+------------------------------------------------------------------+
//| Add RBA dates (first Tuesday of month, 4:30 GMT)                  |
//+------------------------------------------------------------------+
void CASQNewsFilter::AddRBADates()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);

   for(int m = 0; m < 6; m++)
   {
      int year = dt.year;
      int month = dt.mon + m;
      if(month > 12) { month -= 12; year++; }
      if(month == 1) continue; // RBA doesn't meet in January

      datetime rbaDate = GetNthWeekdayOfMonth(year, month, 2, 1, 4, 30);
      if(rbaDate > now)
         AddEvent(rbaDate, "RBA Interest Rate Decision", "AUD", ASQ_NEWS_IMPACT_HIGH, ASQ_NEWS_RBA);
   }
}

//+------------------------------------------------------------------+
//| Add BOC dates (10:00 GMT, 8 meetings/year)                        |
//+------------------------------------------------------------------+
void CASQNewsFilter::AddBOCDates()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   int year = dt.year;

   int bocMonths[] = {1, 3, 4, 6, 7, 9, 10, 12};
   for(int i = 0; i < ArraySize(bocMonths); i++)
   {
      datetime bocDate = GetNthWeekdayOfMonth(year, bocMonths[i], 3, 3, 15, 0);
      if(bocDate > now)
         AddEvent(bocDate, "BOC Interest Rate Decision", "CAD", ASQ_NEWS_IMPACT_HIGH, ASQ_NEWS_BOC);
   }
}

//+------------------------------------------------------------------+
//| Clear all events                                                  |
//+------------------------------------------------------------------+
void CASQNewsFilter::ClearEvents()
{
   for(int i = 0; i < ASQ_MAX_NEWS_EVENTS; i++)
      m_events[i].Reset();
   m_eventCount = 0;
}

//+------------------------------------------------------------------+
//| Main update — call on every tick or timer                         |
//+------------------------------------------------------------------+
void CASQNewsFilter::Update()
{
   if(!m_initialized) return;
   if(m_mode == ASQ_NEWS_FILTER_OFF)
   {
      m_status.tradingAllowed = true;
      m_status.intensity = ASQ_INTENSITY_CALM;
      m_status.statusMessage = "News filter disabled";
      return;
   }

   // Periodic MQL5 Calendar refresh
   datetime now = TimeCurrent();
   if(m_useMQL5Calendar && (now - m_lastCalendarFetch) > ASQ_CALENDAR_REFRESH_SEC)
      FetchMQL5Calendar();

   UpdateEventStatus();
   CheckNewsWindows();
   m_status.updated = now;
   m_lastUpdate = now;
}

//+------------------------------------------------------------------+
//| Update event status                                               |
//+------------------------------------------------------------------+
void CASQNewsFilter::UpdateEventStatus()
{
   datetime now = TimeCurrent();
   m_status.upcomingHighCount = 0;
   m_status.upcomingMediumCount = 0;
   m_status.upcomingLowCount = 0;
   m_status.upcomingCount = 0;

   bool foundNext = false, foundLast = false;

   for(int i = 0; i < m_eventCount; i++)
   {
      m_events[i].passed = (m_events[i].time <= now);
      if(!m_events[i].affectsSymbol && !m_filterAll) continue;

      if(!m_events[i].passed)
      {
         switch(m_events[i].impact)
         {
            case ASQ_NEWS_IMPACT_HIGH:   m_status.upcomingHighCount++;   break;
            case ASQ_NEWS_IMPACT_MEDIUM: m_status.upcomingMediumCount++; break;
            case ASQ_NEWS_IMPACT_LOW:    m_status.upcomingLowCount++;    break;
            default: break;
         }
         if(!foundNext && ShouldFilterEvent(m_events[i]))
         {
            m_status.nextEvent = m_events[i];
            m_status.minutesToNext = (int)((m_events[i].time - now) / 60);
            foundNext = true;
         }
         // Fill upcoming list
         if(ShouldFilterEvent(m_events[i]) && m_status.upcomingCount < ASQ_UPCOMING_LIST_SIZE)
         {
            m_status.upcoming[m_status.upcomingCount] = m_events[i];
            m_status.upcomingCount++;
         }
      }
      else
      {
         if(ShouldFilterEvent(m_events[i]))
         {
            m_status.lastEvent = m_events[i];
            m_status.minutesSinceLast = (int)((now - m_events[i].time) / 60);
            foundLast = true;
         }
      }
   }

   if(!foundNext) { m_status.nextEvent.Reset(); m_status.minutesToNext = 9999; }
   if(!foundLast) { m_status.lastEvent.Reset(); m_status.minutesSinceLast = 9999; }
}

//+------------------------------------------------------------------+
//| Get effective pre/post minutes for an event                       |
//+------------------------------------------------------------------+
int CASQNewsFilter::GetEffectivePreMinutes(SASQNewsEvent &event)
{
   if(event.customPreMin >= 0) return event.customPreMin;
   return m_preNewsMinutes;
}

int CASQNewsFilter::GetEffectivePostMinutes(SASQNewsEvent &event)
{
   if(event.customPostMin >= 0) return event.customPostMin;
   return m_postNewsMinutes;
}

//+------------------------------------------------------------------+
//| Check news windows                                                |
//+------------------------------------------------------------------+
void CASQNewsFilter::CheckNewsWindows()
{
   m_status.inPreNewsWindow = false;
   m_status.inPostNewsWindow = false;
   m_status.inNewsWindow = false;
   m_status.tradingAllowed = true;
   m_status.intensity = ASQ_INTENSITY_CALM;
   m_status.activePreMin = 0;
   m_status.activePostMin = 0;

   // Pre-news check
   if(m_status.minutesToNext < 9999)
   {
      int preMin = GetEffectivePreMinutes(m_status.nextEvent);
      m_status.activePreMin = preMin;

      if(m_status.minutesToNext <= preMin && m_status.minutesToNext >= 0)
      {
         m_status.inPreNewsWindow = true;
         m_status.inNewsWindow = true;
         m_status.tradingAllowed = false;
         m_status.intensity = ASQ_INTENSITY_BLACKOUT;
         m_status.statusMessage = "PRE-NEWS: " + m_status.nextEvent.title +
                                  " in " + IntegerToString(m_status.minutesToNext) + "m";
      }
      else if(m_status.minutesToNext <= 120)
      {
         m_status.intensity = ASQ_INTENSITY_CAUTION;
      }
   }

   // Post-news check
   if(m_status.minutesSinceLast < 9999)
   {
      int postMin = GetEffectivePostMinutes(m_status.lastEvent);
      m_status.activePostMin = postMin;

      if(m_status.minutesSinceLast <= postMin && m_status.minutesSinceLast >= 0)
      {
         m_status.inPostNewsWindow = true;
         m_status.inNewsWindow = true;
         m_status.tradingAllowed = false;
         m_status.intensity = ASQ_INTENSITY_BLACKOUT;
         m_status.statusMessage = "POST-NEWS: " + m_status.lastEvent.title +
                                  " — " + IntegerToString(m_status.minutesSinceLast) + "m ago" +
                                  " (cooldown " + IntegerToString(postMin) + "m)";
      }
   }

   if(m_status.tradingAllowed)
   {
      if(m_status.minutesToNext < 9999)
      {
         string timeStr = "";
         if(m_status.minutesToNext >= 60)
            timeStr = IntegerToString(m_status.minutesToNext / 60) + "h" + IntegerToString(m_status.minutesToNext % 60) + "m";
         else
            timeStr = IntegerToString(m_status.minutesToNext) + "m";
         m_status.statusMessage = "Next: " + m_status.nextEvent.title +
                                  " (" + m_status.nextEvent.currency + ") in " + timeStr;
      }
      else
         m_status.statusMessage = "No upcoming news events";
   }
}

//+------------------------------------------------------------------+
//| Is trading allowed?                                               |
//+------------------------------------------------------------------+
bool CASQNewsFilter::IsTradingAllowed()
{
   if(m_mode == ASQ_NEWS_FILTER_OFF) return true;
   return m_status.tradingAllowed;
}

//+------------------------------------------------------------------+
//| Is high impact news coming soon?                                  |
//+------------------------------------------------------------------+
bool CASQNewsFilter::IsHighImpactSoon(int minutesAhead)
{
   datetime now = TimeCurrent();
   for(int i = 0; i < m_eventCount; i++)
   {
      if(m_events[i].passed) continue;
      if(!m_events[i].affectsSymbol && !m_filterAll) continue;
      if(m_events[i].impact != ASQ_NEWS_IMPACT_HIGH) continue;
      int minutes = (int)((m_events[i].time - now) / 60);
      if(minutes <= minutesAhead && minutes >= 0) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Get next / last event                                             |
//+------------------------------------------------------------------+
bool CASQNewsFilter::GetNextEvent(SASQNewsEvent &event)
{
   if(m_status.minutesToNext >= 9999) return false;
   event = m_status.nextEvent;
   return true;
}

bool CASQNewsFilter::GetLastEvent(SASQNewsEvent &event)
{
   if(m_status.minutesSinceLast >= 9999) return false;
   event = m_status.lastEvent;
   return true;
}

//+------------------------------------------------------------------+
//| Get upcoming event count by minimum impact                        |
//+------------------------------------------------------------------+
int CASQNewsFilter::GetUpcomingEventCount(ENUM_ASQ_NEWS_IMPACT minImpact)
{
   switch(minImpact)
   {
      case ASQ_NEWS_IMPACT_HIGH:   return m_status.upcomingHighCount;
      case ASQ_NEWS_IMPACT_MEDIUM: return m_status.upcomingHighCount + m_status.upcomingMediumCount;
      case ASQ_NEWS_IMPACT_LOW:    return m_status.upcomingHighCount + m_status.upcomingMediumCount + m_status.upcomingLowCount;
      default: return 0;
   }
}

//+------------------------------------------------------------------+
//| String helpers                                                    |
//+------------------------------------------------------------------+
string CASQNewsFilter::ImpactToString(ENUM_ASQ_NEWS_IMPACT impact)
{
   switch(impact)
   {
      case ASQ_NEWS_IMPACT_HIGH:   return "HIGH";
      case ASQ_NEWS_IMPACT_MEDIUM: return "MEDIUM";
      case ASQ_NEWS_IMPACT_LOW:    return "LOW";
      default:                     return "NONE";
   }
}

string CASQNewsFilter::TypeToString(ENUM_ASQ_NEWS_TYPE type)
{
   switch(type)
   {
      case ASQ_NEWS_NFP:        return "NFP";
      case ASQ_NEWS_FOMC:       return "FOMC";
      case ASQ_NEWS_ECB:        return "ECB";
      case ASQ_NEWS_BOE:        return "BOE";
      case ASQ_NEWS_BOJ:        return "BOJ";
      case ASQ_NEWS_RBA:        return "RBA";
      case ASQ_NEWS_RBNZ:       return "RBNZ";
      case ASQ_NEWS_SNB:        return "SNB";
      case ASQ_NEWS_BOC:        return "BOC";
      case ASQ_NEWS_GDP:        return "GDP";
      case ASQ_NEWS_CPI:        return "CPI";
      case ASQ_NEWS_RETAIL:     return "Retail";
      case ASQ_NEWS_PMI:        return "PMI";
      case ASQ_NEWS_EMPLOYMENT: return "Employment";
      case ASQ_NEWS_SPEECH:     return "Speech";
      default:                  return "General";
   }
}

string CASQNewsFilter::IntensityToString(ENUM_ASQ_NEWS_INTENSITY intensity)
{
   switch(intensity)
   {
      case ASQ_INTENSITY_CALM:     return "CALM";
      case ASQ_INTENSITY_CAUTION:  return "CAUTION";
      case ASQ_INTENSITY_DANGER:   return "DANGER";
      case ASQ_INTENSITY_BLACKOUT: return "BLACKOUT";
      default:                     return "---";
   }
}

bool CASQNewsFilter::CurrencyAffectsSymbol(string currency)
{
   if(currency == "") return false;
   return (StringFind(m_baseCurrency, currency) >= 0 ||
           StringFind(m_quoteCurrency, currency) >= 0);
}

//+------------------------------------------------------------------+
//| Reset                                                             |
//+------------------------------------------------------------------+
void CASQNewsFilter::Reset()
{
   ClearEvents();
   m_status.Reset();
}

//+------------------------------------------------------------------+
//| Parse symbol to extract base/quote currencies                     |
//+------------------------------------------------------------------+
void CASQNewsFilter::ParseSymbolCurrencies()
{
   // Handle standard 6-char pairs and suffixed pairs (EURUSDm, EURUSD.r, etc.)
   string clean = m_symbol;
   int len = StringLen(clean);

   // Strip common suffixes
   if(len > 6)
   {
      string last = StringSubstr(clean, 6);
      if(StringFind(last, ".") >= 0 || StringFind(last, "_") >= 0 ||
         StringFind(last, "m") >= 0 || StringFind(last, "M") >= 0 ||
         StringFind(last, "c") >= 0 || StringFind(last, "#") >= 0)
         clean = StringSubstr(clean, 0, 6);
   }

   if(StringLen(clean) >= 6)
   {
      m_baseCurrency = StringSubstr(clean, 0, 3);
      m_quoteCurrency = StringSubstr(clean, 3, 3);
   }
   else
   {
      m_baseCurrency = clean;
      m_quoteCurrency = "";
   }
}

//+------------------------------------------------------------------+
//| Sort events by time (bubble sort)                                 |
//+------------------------------------------------------------------+
void CASQNewsFilter::SortEvents()
{
   for(int i = 0; i < m_eventCount - 1; i++)
   {
      for(int j = 0; j < m_eventCount - i - 1; j++)
      {
         if(m_events[j].time > m_events[j + 1].time)
         {
            SASQNewsEvent temp = m_events[j];
            m_events[j] = m_events[j + 1];
            m_events[j + 1] = temp;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Should this event be filtered?                                    |
//+------------------------------------------------------------------+
bool CASQNewsFilter::ShouldFilterEvent(SASQNewsEvent &event)
{
   if(!event.affectsSymbol && !m_filterAll) return false;
   switch(m_mode)
   {
      case ASQ_NEWS_FILTER_OFF:  return false;
      case ASQ_NEWS_HIGH_ONLY:   return (event.impact == ASQ_NEWS_IMPACT_HIGH);
      case ASQ_NEWS_HIGH_MEDIUM: return (event.impact >= ASQ_NEWS_IMPACT_MEDIUM);
      case ASQ_NEWS_ALL:         return (event.impact >= ASQ_NEWS_IMPACT_LOW);
   }
   return false;
}

//+------------------------------------------------------------------+
//| Get Nth weekday of a given month                                  |
//+------------------------------------------------------------------+
datetime CASQNewsFilter::GetNthWeekdayOfMonth(int year, int month, int dayOfWeek, int n, int hour, int minute)
{
   MqlDateTime dt;
   dt.year = year; dt.mon = month; dt.day = 1;
   dt.hour = hour; dt.min = minute; dt.sec = 0;

   datetime firstOfMonth = StructToTime(dt);
   TimeToStruct(firstOfMonth, dt);

   int daysToFirst = dayOfWeek - dt.day_of_week;
   if(daysToFirst < 0) daysToFirst += 7;
   int totalDays = daysToFirst + (n - 1) * 7;
   dt.day = 1 + totalDays;
   return StructToTime(dt);
}

//+------------------------------------------------------------------+
//| Internal logging                                                  |
//+------------------------------------------------------------------+
void CASQNewsFilter::ASQLog(string msg)
{
   if(!m_verbose) return;
   if(MQLInfoInteger(MQL_TESTER)) return;
   Print("[ASQ NewsFilter] ", msg);
}

#endif // ASQ_NEWS_FILTER_MQH
