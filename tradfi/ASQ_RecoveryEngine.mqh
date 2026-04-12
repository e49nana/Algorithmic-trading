//+------------------------------------------------------------------+
//|                                        ASQ_RecoveryEngine.mqh    |
//|                        Copyright 2026, AlgoSphere Quant          |
//|                        https://www.mql5.com/en/users/robin2.0    |
//+------------------------------------------------------------------+
//| ASQ Recovery Engine v1.2 — Free, Open-Source                     |
//|                                                                   |
//| Intelligent risk management after consecutive losses.             |
//|                                                                   |
//| FEATURES:                                                         |
//| • Automatic risk reduction after consecutive losses               |
//| • Gradual risk restoration after wins                             |
//| • Anti-tilt protection (defensive mode at 3+ losses)              |
//| • Revenge trading detector (trades too fast after loss)           |
//| • Martingale guard (blocks lot increases after losses)            |
//| • Cooling-off periods after big losses (configurable)             |
//| • Win streak capitalization with bonus multiplier                 |
//| • Session heat score (aggregate stress level 0-100)               |
//| • Drawdown-triggered auto-conservative switch                     |
//| • Emotional state tracking (Calm/Focused/Tilted/Reckless)         |
//| • Trade mini-log (last 10 results)                                |
//| • 3 presets: Conservative / Moderate / Aggressive                 |
//| • Daily reset option                                              |
//|                                                                   |
//| USAGE:                                                            |
//|   #include "ASQ_RecoveryEngine.mqh"                              |
//|   CASQRecoveryEngine recovery;                                    |
//|   recovery.Initialize(1.0, 0.01, AccountBalance());              |
//|   recovery.SetMode(ASQ_RECOVERY_MODERATE);                       |
//|   // After each trade:                                            |
//|   recovery.OnTradeWin(profit, pips);                              |
//|   recovery.OnTradeLoss(loss, pips);                               |
//|   double adjRisk = recovery.GetAdjustedRisk();                   |
//|   if(recovery.IsRevengeTrade()) { /* block entry */ }            |
//|                                                                   |
//| AlgoSphere Quant — Precision before profit.                      |
//| https://www.mql5.com/en/users/robin2.0                           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, AlgoSphere Quant"
#property link      "https://www.mql5.com/en/users/robin2.0"
#property version   "1.20"
#property strict

#ifndef ASQ_RECOVERY_ENGINE_MQH
#define ASQ_RECOVERY_ENGINE_MQH

//+------------------------------------------------------------------+
//| CONSTANTS                                                         |
//+------------------------------------------------------------------+
#define ASQ_REC_TRADE_LOG_SIZE   10
#define ASQ_REC_REVENGE_SEC      120    // Seconds — trade within 2min of loss = revenge
#define ASQ_REC_HEAT_DECAY       5      // Heat decays 5 points per win

//+------------------------------------------------------------------+
//| UTILITY                                                           |
//+------------------------------------------------------------------+
double ASQ_Clamp(double value, double minVal, double maxVal)
{
   return MathMax(minVal, MathMin(maxVal, value));
}

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                      |
//+------------------------------------------------------------------+
enum ENUM_ASQ_RECOVERY_MODE
{
   ASQ_RECOVERY_OFF          = 0,
   ASQ_RECOVERY_CONSERVATIVE = 1,
   ASQ_RECOVERY_MODERATE     = 2,
   ASQ_RECOVERY_AGGRESSIVE   = 3
};

enum ENUM_ASQ_RECOVERY_STATE
{
   ASQ_STATE_NORMAL          = 0,
   ASQ_STATE_CAUTION         = 1,
   ASQ_STATE_DEFENSIVE       = 2,
   ASQ_STATE_COOLING         = 3,
   ASQ_STATE_RECOVERING      = 4,
   ASQ_STATE_STREAK          = 5
};

enum ENUM_ASQ_EMOTIONAL_STATE
{
   ASQ_EMOTION_CALM          = 0,     // Normal, no stress
   ASQ_EMOTION_FOCUSED       = 1,     // Win streak, confident
   ASQ_EMOTION_STRESSED      = 2,     // Losing but controlled
   ASQ_EMOTION_TILTED        = 3,     // Multiple losses, fast trading
   ASQ_EMOTION_RECKLESS      = 4      // Revenge trading detected
};

//+------------------------------------------------------------------+
//| TRADE LOG ENTRY                                                   |
//+------------------------------------------------------------------+
struct SASQTradeLogEntry
{
   datetime time;
   double   profit;
   bool     win;
   double   riskMult;

   void Reset() { time = 0; profit = 0; win = false; riskMult = 1.0; }
};

//+------------------------------------------------------------------+
//| SETTINGS                                                          |
//+------------------------------------------------------------------+
struct SASQRecoverySettings
{
   ENUM_ASQ_RECOVERY_MODE mode;
   int                   lossesBeforeReduction;
   double                reductionPerLoss;
   double                minRiskMultiplier;
   int                   winsToRecover;
   double                recoveryPerWin;
   bool                  useCoolingPeriod;
   int                   coolingMinutes;
   double                bigLossThreshold;
   bool                  useStreakBonus;
   int                   streakThreshold;
   double                streakBonusMultiplier;
   double                maxStreakMultiplier;
   bool                  resetDaily;
   bool                  useRevengeGuard;
   int                   revengeSeconds;
   bool                  useMartingaleGuard;
   bool                  autoConservativeOnDD;
   double                autoConservativeDDPct;

   void Reset()
   {
      mode = ASQ_RECOVERY_MODERATE;
      lossesBeforeReduction = 2; reductionPerLoss = 20; minRiskMultiplier = 0.25;
      winsToRecover = 2; recoveryPerWin = 25;
      useCoolingPeriod = true; coolingMinutes = 30; bigLossThreshold = 2.0;
      useStreakBonus = false; streakThreshold = 3;
      streakBonusMultiplier = 1.25; maxStreakMultiplier = 1.5;
      resetDaily = true;
      useRevengeGuard = true; revengeSeconds = ASQ_REC_REVENGE_SEC;
      useMartingaleGuard = true;
      autoConservativeOnDD = true; autoConservativeDDPct = 5.0;
   }

   void SetConservative()
   {
      lossesBeforeReduction = 1; reductionPerLoss = 30; minRiskMultiplier = 0.20;
      winsToRecover = 3; recoveryPerWin = 20;
      useCoolingPeriod = true; coolingMinutes = 60; bigLossThreshold = 1.5;
      useStreakBonus = false;
      useRevengeGuard = true; revengeSeconds = 180;
      useMartingaleGuard = true;
   }

   void SetModerate()
   {
      lossesBeforeReduction = 2; reductionPerLoss = 25; minRiskMultiplier = 0.30;
      winsToRecover = 2; recoveryPerWin = 30;
      useCoolingPeriod = true; coolingMinutes = 30; bigLossThreshold = 2.0;
      useStreakBonus = false;
      useRevengeGuard = true; revengeSeconds = ASQ_REC_REVENGE_SEC;
      useMartingaleGuard = true;
   }

   void SetAggressive()
   {
      lossesBeforeReduction = 3; reductionPerLoss = 20; minRiskMultiplier = 0.40;
      winsToRecover = 1; recoveryPerWin = 40;
      useCoolingPeriod = false; coolingMinutes = 15; bigLossThreshold = 3.0;
      useStreakBonus = true; streakThreshold = 3; streakBonusMultiplier = 1.25;
      useRevengeGuard = true; revengeSeconds = 90;
      useMartingaleGuard = true;
   }
};

//+------------------------------------------------------------------+
//| STATUS                                                            |
//+------------------------------------------------------------------+
struct SASQRecoveryStatus
{
   ENUM_ASQ_RECOVERY_STATE state;
   ENUM_ASQ_EMOTIONAL_STATE emotion;
   double                riskMultiplier;
   int                   consecutiveLosses, consecutiveWins;
   int                   maxConsecLosses, maxConsecWins;
   int                   sessionWins, sessionLosses;
   double                sessionProfit, biggestLoss, biggestWin;
   bool                  inCooling;
   datetime              coolingEndTime;
   int                   coolingsToday;
   int                   heatScore;           // 0-100 stress level
   bool                  revengeTradeBlocked;
   int                   revengeBlocksToday;
   bool                  martingaleBlocked;
   bool                  autoSwitchedConservative;
   double                sessionDrawdownPct;
   string                statusMessage, recommendation;

   // Trade log
   SASQTradeLogEntry     tradeLog[ASQ_REC_TRADE_LOG_SIZE];
   int                   tradeLogCount;

   void Reset()
   {
      state = ASQ_STATE_NORMAL; emotion = ASQ_EMOTION_CALM;
      riskMultiplier = 1.0;
      consecutiveLosses = 0; consecutiveWins = 0;
      maxConsecLosses = 0; maxConsecWins = 0;
      sessionWins = 0; sessionLosses = 0;
      sessionProfit = 0; biggestLoss = 0; biggestWin = 0;
      inCooling = false; coolingEndTime = 0; coolingsToday = 0;
      heatScore = 0;
      revengeTradeBlocked = false; revengeBlocksToday = 0;
      martingaleBlocked = false;
      autoSwitchedConservative = false;
      sessionDrawdownPct = 0;
      statusMessage = "Normal"; recommendation = "";
      tradeLogCount = 0;
      for(int i = 0; i < ASQ_REC_TRADE_LOG_SIZE; i++) tradeLog[i].Reset();
   }
};

//+------------------------------------------------------------------+
//| RECOVERY ENGINE CLASS                                             |
//+------------------------------------------------------------------+
class CASQRecoveryEngine
{
private:
   SASQRecoverySettings  m_settings;
   SASQRecoveryStatus    m_status;
   double                m_baseRisk, m_baseLot, m_accountBalance;
   datetime              m_lastTradeTime, m_lastLossTime, m_dayStart;
   double                m_dayStartBalance, m_sessionPeak;
   bool                  m_enabled, m_initialized, m_verbose;
   ENUM_ASQ_RECOVERY_MODE m_originalMode;

   void                  UpdateState();
   void                  UpdateMultiplier();
   void                  UpdateEmotionalState();
   void                  UpdateHeatScore(bool win, double lossPct);
   void                  UpdateStatusMessage();
   void                  AddToTradeLog(double profit, bool win);
   void                  StartCooling();
   void                  EndCooling();
   bool                  CheckCoolingComplete();
   void                  CheckAutoConservative();
   datetime              GetDayStart(datetime time);
   void                  ASQLog(string msg);

public:
                         CASQRecoveryEngine();
                        ~CASQRecoveryEngine() {}

   bool                  Initialize(double baseRisk, double baseLot, double balance);
   void                  SetSettings(SASQRecoverySettings &s) { m_settings = s; }
   void                  SetMode(ENUM_ASQ_RECOVERY_MODE mode);
   void                  SetLossThreshold(int losses, double pct) { m_settings.lossesBeforeReduction = MathMax(1, losses); m_settings.reductionPerLoss = ASQ_Clamp(pct, 5, 50); }
   void                  SetRecoveryRate(int wins, double pct)    { m_settings.winsToRecover = MathMax(1, wins); m_settings.recoveryPerWin = ASQ_Clamp(pct, 5, 100); }
   void                  SetMinMultiplier(double mult)            { m_settings.minRiskMultiplier = ASQ_Clamp(mult, 0.1, 0.5); }
   void                  SetCoolingPeriod(bool use, int min, double thr) { m_settings.useCoolingPeriod = use; m_settings.coolingMinutes = MathMax(5, MathMin(120, min)); m_settings.bigLossThreshold = ASQ_Clamp(thr, 0.5, 10); }
   void                  SetStreakBonus(bool use, int thr, double bonus, double max) { m_settings.useStreakBonus = use; m_settings.streakThreshold = MathMax(2, thr); m_settings.streakBonusMultiplier = ASQ_Clamp(bonus, 1.0, 2.0); m_settings.maxStreakMultiplier = ASQ_Clamp(max, 1.0, 3.0); }
   void                  SetRevengeGuard(bool use, int seconds)   { m_settings.useRevengeGuard = use; m_settings.revengeSeconds = MathMax(30, MathMin(600, seconds)); }
   void                  SetMartingaleGuard(bool use)             { m_settings.useMartingaleGuard = use; }
   void                  SetAutoConservative(bool use, double ddPct) { m_settings.autoConservativeOnDD = use; m_settings.autoConservativeDDPct = ASQ_Clamp(ddPct, 2, 20); }
   void                  SetDailyReset(bool r)                    { m_settings.resetDaily = r; }
   void                  Enable(bool e)                           { m_enabled = e; }
   bool                  IsEnabled()                              { return m_enabled; }
   void                  SetVerbose(bool v)                       { m_verbose = v; }

   void                  OnTradeWin(double profit, double pips);
   void                  OnTradeLoss(double loss, double pips);
   void                  OnTradeBreakEven()                       { m_lastTradeTime = TimeCurrent(); }
   void                  Update();
   void                  CheckNewDay();

   SASQRecoveryStatus    GetStatus()                              { return m_status; }
   ENUM_ASQ_RECOVERY_STATE GetState()                             { return m_status.state; }
   ENUM_ASQ_EMOTIONAL_STATE GetEmotion()                          { return m_status.emotion; }
   double                GetRiskMultiplier()                      { return m_status.riskMultiplier; }
   double                GetAdjustedRisk()                        { return m_baseRisk * m_status.riskMultiplier; }
   double                GetAdjustedLot()                         { return NormalizeDouble(m_baseLot * m_status.riskMultiplier, 2); }
   int                   GetHeatScore()                           { return m_status.heatScore; }
   bool                  IsTradingAllowed();
   bool                  IsInCooling()                            { return m_status.inCooling; }
   bool                  IsOnStreak()                             { return m_status.state == ASQ_STATE_STREAK; }
   bool                  IsDefensive()                            { return m_status.state == ASQ_STATE_DEFENSIVE; }
   bool                  IsRevengeTrade();
   bool                  IsMartingaleBlocked()                    { return m_status.martingaleBlocked; }
   int                   GetCoolingRemainingMinutes();
   string                GetStatusMessage()                       { return m_status.statusMessage; }
   string                GetRecommendation()                      { return m_status.recommendation; }
   string                EmotionToString(ENUM_ASQ_EMOTIONAL_STATE emotion);
   string                StateToString(ENUM_ASQ_RECOVERY_STATE state);
   string                GetDetailedStatus();

   void                  Reset();
   void                  ResetDaily();
   void                  ForceNormal();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CASQRecoveryEngine::CASQRecoveryEngine()
{
   m_settings.Reset(); m_status.Reset();
   m_baseRisk = 1.0; m_baseLot = 0.01; m_accountBalance = 10000;
   m_lastTradeTime = 0; m_lastLossTime = 0; m_dayStart = 0;
   m_dayStartBalance = 0; m_sessionPeak = 0;
   m_enabled = false; m_initialized = false; m_verbose = false;
   m_originalMode = ASQ_RECOVERY_MODERATE;
}

//+------------------------------------------------------------------+
//| Initialize                                                        |
//+------------------------------------------------------------------+
bool CASQRecoveryEngine::Initialize(double baseRisk, double baseLot, double balance)
{
   m_baseRisk = baseRisk; m_baseLot = baseLot; m_accountBalance = balance;
   m_dayStart = GetDayStart(TimeCurrent()); m_dayStartBalance = balance;
   m_sessionPeak = balance;
   m_status.Reset(); m_status.riskMultiplier = 1.0;
   m_enabled = true; m_initialized = true;
   ASQLog("Recovery v1.2 initialized | Risk: " + DoubleToString(baseRisk, 1) +
          "% | Lot: " + DoubleToString(baseLot, 2) +
          " | Mode: " + IntegerToString(m_settings.mode));
   return true;
}

//+------------------------------------------------------------------+
//| Set mode                                                          |
//+------------------------------------------------------------------+
void CASQRecoveryEngine::SetMode(ENUM_ASQ_RECOVERY_MODE mode)
{
   m_settings.mode = mode;
   m_originalMode = mode;
   switch(mode)
   {
      case ASQ_RECOVERY_OFF:          m_enabled = false; m_status.riskMultiplier = 1.0; break;
      case ASQ_RECOVERY_CONSERVATIVE: m_settings.SetConservative(); break;
      case ASQ_RECOVERY_MODERATE:     m_settings.SetModerate(); break;
      case ASQ_RECOVERY_AGGRESSIVE:   m_settings.SetAggressive(); break;
   }
}

//+------------------------------------------------------------------+
//| On winning trade                                                  |
//+------------------------------------------------------------------+
void CASQRecoveryEngine::OnTradeWin(double profit, double pips)
{
   if(!m_enabled) return;
   m_status.sessionWins++; m_status.sessionProfit += profit;
   m_status.consecutiveWins++; m_status.consecutiveLosses = 0;
   if(profit > m_status.biggestWin) m_status.biggestWin = profit;
   if(m_status.consecutiveWins > m_status.maxConsecWins) m_status.maxConsecWins = m_status.consecutiveWins;
   m_lastTradeTime = TimeCurrent();
   m_status.revengeTradeBlocked = false;
   m_status.martingaleBlocked = false;
   AddToTradeLog(profit, true);
   UpdateHeatScore(true, 0);
   UpdateState(); UpdateMultiplier(); UpdateEmotionalState(); UpdateStatusMessage();
   ASQLog("WIN | W" + IntegerToString(m_status.consecutiveWins) +
          " | Mult: " + DoubleToString(m_status.riskMultiplier, 2) +
          " | Heat: " + IntegerToString(m_status.heatScore));
}

//+------------------------------------------------------------------+
//| On losing trade                                                   |
//+------------------------------------------------------------------+
void CASQRecoveryEngine::OnTradeLoss(double loss, double pips)
{
   if(!m_enabled) return;
   double absLoss = MathAbs(loss);
   m_status.sessionLosses++; m_status.sessionProfit -= absLoss;
   m_status.consecutiveLosses++; m_status.consecutiveWins = 0;
   if(absLoss > m_status.biggestLoss) m_status.biggestLoss = absLoss;
   if(m_status.consecutiveLosses > m_status.maxConsecLosses) m_status.maxConsecLosses = m_status.consecutiveLosses;
   m_lastTradeTime = TimeCurrent();
   m_lastLossTime = TimeCurrent();

   double lossPct = (m_accountBalance > 0) ? absLoss / m_accountBalance * 100 : 0;

   if(m_settings.useCoolingPeriod && lossPct >= m_settings.bigLossThreshold)
      StartCooling();

   // Martingale guard: block if next entry would be larger after a loss
   if(m_settings.useMartingaleGuard && m_status.consecutiveLosses >= 2)
      m_status.martingaleBlocked = true;

   AddToTradeLog(-absLoss, false);
   UpdateHeatScore(false, lossPct);
   CheckAutoConservative();
   UpdateState(); UpdateMultiplier(); UpdateEmotionalState(); UpdateStatusMessage();
   ASQLog("LOSS | L" + IntegerToString(m_status.consecutiveLosses) +
          " | Mult: " + DoubleToString(m_status.riskMultiplier, 2) +
          " | Heat: " + IntegerToString(m_status.heatScore) +
          " | Emotion: " + EmotionToString(m_status.emotion));
}

//+------------------------------------------------------------------+
//| Update — call periodically                                        |
//+------------------------------------------------------------------+
void CASQRecoveryEngine::Update()
{
   if(!m_enabled) return;
   CheckNewDay();
   if(m_status.inCooling && CheckCoolingComplete()) EndCooling();
   m_accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   // Track session drawdown
   if(m_accountBalance > m_sessionPeak) m_sessionPeak = m_accountBalance;
   if(m_sessionPeak > 0)
      m_status.sessionDrawdownPct = (m_sessionPeak - m_accountBalance) / m_sessionPeak * 100;

   // Update revenge trade status
   if(m_settings.useRevengeGuard && m_lastLossTime > 0)
   {
      int secSinceLoss = (int)(TimeCurrent() - m_lastLossTime);
      m_status.revengeTradeBlocked = (secSinceLoss < m_settings.revengeSeconds && m_status.consecutiveLosses > 0);
   }
}

void CASQRecoveryEngine::CheckNewDay()
{
   datetime today = GetDayStart(TimeCurrent());
   if(today != m_dayStart) { m_dayStart = today; if(m_settings.resetDaily) ResetDaily(); }
}

//+------------------------------------------------------------------+
//| Is revenge trade?                                                 |
//+------------------------------------------------------------------+
bool CASQRecoveryEngine::IsRevengeTrade()
{
   if(!m_settings.useRevengeGuard) return false;
   if(m_lastLossTime == 0 || m_status.consecutiveLosses == 0) return false;
   int secSinceLoss = (int)(TimeCurrent() - m_lastLossTime);
   if(secSinceLoss < m_settings.revengeSeconds)
   {
      m_status.revengeBlocksToday++;
      ASQLog("REVENGE TRADE BLOCKED — " + IntegerToString(secSinceLoss) + "s since last loss");
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Is trading allowed                                                |
//+------------------------------------------------------------------+
bool CASQRecoveryEngine::IsTradingAllowed()
{
   if(!m_enabled) return true;
   if(m_status.inCooling) return false;
   if(m_status.revengeTradeBlocked) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Update heat score (0-100 stress indicator)                        |
//+------------------------------------------------------------------+
void CASQRecoveryEngine::UpdateHeatScore(bool win, double lossPct)
{
   if(win)
   {
      m_status.heatScore = MathMax(0, m_status.heatScore - ASQ_REC_HEAT_DECAY);
   }
   else
   {
      int heatAdd = 10 + (int)(lossPct * 5);
      if(m_status.consecutiveLosses >= 3) heatAdd += 15;
      m_status.heatScore = MathMin(100, m_status.heatScore + heatAdd);
   }
}

//+------------------------------------------------------------------+
//| Update emotional state                                            |
//+------------------------------------------------------------------+
void CASQRecoveryEngine::UpdateEmotionalState()
{
   if(m_status.revengeTradeBlocked || m_status.heatScore >= 80)
      m_status.emotion = ASQ_EMOTION_RECKLESS;
   else if(m_status.heatScore >= 50 || m_status.consecutiveLosses >= 3)
      m_status.emotion = ASQ_EMOTION_TILTED;
   else if(m_status.consecutiveLosses >= 1)
      m_status.emotion = ASQ_EMOTION_STRESSED;
   else if(m_status.consecutiveWins >= 3)
      m_status.emotion = ASQ_EMOTION_FOCUSED;
   else
      m_status.emotion = ASQ_EMOTION_CALM;
}

//+------------------------------------------------------------------+
//| Check auto-conservative switch                                    |
//+------------------------------------------------------------------+
void CASQRecoveryEngine::CheckAutoConservative()
{
   if(!m_settings.autoConservativeOnDD) return;
   if(m_status.autoSwitchedConservative) return;

   if(m_dayStartBalance > 0)
   {
      double ddPct = (m_dayStartBalance - m_accountBalance) / m_dayStartBalance * 100;
      if(ddPct >= m_settings.autoConservativeDDPct)
      {
         m_settings.SetConservative();
         m_status.autoSwitchedConservative = true;
         ASQLog("AUTO-SWITCH to Conservative — session DD " + DoubleToString(ddPct, 1) + "%");
      }
   }
}

//+------------------------------------------------------------------+
//| Add to trade log                                                  |
//+------------------------------------------------------------------+
void CASQRecoveryEngine::AddToTradeLog(double profit, bool win)
{
   // Shift
   for(int i = ASQ_REC_TRADE_LOG_SIZE - 1; i > 0; i--)
      m_status.tradeLog[i] = m_status.tradeLog[i - 1];
   m_status.tradeLog[0].time = TimeCurrent();
   m_status.tradeLog[0].profit = profit;
   m_status.tradeLog[0].win = win;
   m_status.tradeLog[0].riskMult = m_status.riskMultiplier;
   if(m_status.tradeLogCount < ASQ_REC_TRADE_LOG_SIZE) m_status.tradeLogCount++;
}

//+------------------------------------------------------------------+
//| Update state                                                      |
//+------------------------------------------------------------------+
void CASQRecoveryEngine::UpdateState()
{
   if(m_status.inCooling) { m_status.state = ASQ_STATE_COOLING; return; }
   if(m_settings.useStreakBonus && m_status.consecutiveWins >= m_settings.streakThreshold)
   { m_status.state = ASQ_STATE_STREAK; return; }
   if(m_status.consecutiveLosses >= m_settings.lossesBeforeReduction + 2)
      m_status.state = ASQ_STATE_DEFENSIVE;
   else if(m_status.consecutiveLosses >= m_settings.lossesBeforeReduction)
      m_status.state = ASQ_STATE_CAUTION;
   else if(m_status.riskMultiplier < 1.0)
      m_status.state = ASQ_STATE_RECOVERING;
   else
      m_status.state = ASQ_STATE_NORMAL;
}

//+------------------------------------------------------------------+
//| Update multiplier                                                 |
//+------------------------------------------------------------------+
void CASQRecoveryEngine::UpdateMultiplier()
{
   double newMult = 1.0;
   switch(m_status.state)
   {
      case ASQ_STATE_NORMAL: newMult = 1.0; break;
      case ASQ_STATE_CAUTION:
      case ASQ_STATE_DEFENSIVE:
      {
         int over = m_status.consecutiveLosses - m_settings.lossesBeforeReduction + 1;
         double red = over * (m_settings.reductionPerLoss / 100.0);
         newMult = MathMax(m_settings.minRiskMultiplier, 1.0 - red);
      }
      break;
      case ASQ_STATE_COOLING: newMult = m_settings.minRiskMultiplier; break;
      case ASQ_STATE_RECOVERING:
      {
         double rest = m_status.consecutiveWins * (m_settings.recoveryPerWin / 100.0);
         newMult = MathMin(1.0, m_status.riskMultiplier + rest);
      }
      break;
      case ASQ_STATE_STREAK:
         if(m_settings.useStreakBonus)
         {
            int extra = m_status.consecutiveWins - m_settings.streakThreshold;
            newMult = MathMin(m_settings.maxStreakMultiplier, m_settings.streakBonusMultiplier + extra * 0.1);
         }
         else newMult = 1.0;
         break;
   }
   m_status.riskMultiplier = newMult;
}

//+------------------------------------------------------------------+
//| Update status message                                             |
//+------------------------------------------------------------------+
void CASQRecoveryEngine::UpdateStatusMessage()
{
   switch(m_status.state)
   {
      case ASQ_STATE_NORMAL:
         m_status.statusMessage = "Normal";
         m_status.recommendation = "";
         break;
      case ASQ_STATE_CAUTION:
         m_status.statusMessage = "Caution (" + IntegerToString(m_status.consecutiveLosses) + " losses)";
         m_status.recommendation = "Risk at " + DoubleToString(m_status.riskMultiplier * 100, 0) + "%";
         break;
      case ASQ_STATE_DEFENSIVE:
         m_status.statusMessage = "DEFENSIVE MODE";
         m_status.recommendation = "Consider pausing — risk at minimum";
         break;
      case ASQ_STATE_COOLING:
         m_status.statusMessage = "Cooling (" + IntegerToString(GetCoolingRemainingMinutes()) + "m)";
         m_status.recommendation = "Wait for cooldown";
         break;
      case ASQ_STATE_RECOVERING:
         m_status.statusMessage = "Recovering";
         m_status.recommendation = "Rebuilding risk";
         break;
      case ASQ_STATE_STREAK:
         m_status.statusMessage = "STREAK W" + IntegerToString(m_status.consecutiveWins);
         m_status.recommendation = "Bonus +" + DoubleToString((m_status.riskMultiplier - 1) * 100, 0) + "%";
         break;
   }

   if(m_status.emotion == ASQ_EMOTION_RECKLESS)
      m_status.recommendation = "STOP TRADING — revenge risk detected";
   else if(m_status.emotion == ASQ_EMOTION_TILTED)
      m_status.recommendation = "Take a break — tilt detected";
}

//+------------------------------------------------------------------+
//| Cooling                                                           |
//+------------------------------------------------------------------+
void CASQRecoveryEngine::StartCooling()
{
   m_status.inCooling = true;
   m_status.coolingEndTime = TimeCurrent() + m_settings.coolingMinutes * 60;
   m_status.coolingsToday++;
   m_status.state = ASQ_STATE_COOLING;
   ASQLog("Cooling started (" + IntegerToString(m_settings.coolingMinutes) + "m)");
}

void CASQRecoveryEngine::EndCooling()
{
   m_status.inCooling = false; m_status.coolingEndTime = 0;
   UpdateState(); UpdateStatusMessage();
   ASQLog("Cooling ended");
}

bool CASQRecoveryEngine::CheckCoolingComplete()
{
   return (TimeCurrent() >= m_status.coolingEndTime);
}

int CASQRecoveryEngine::GetCoolingRemainingMinutes()
{
   if(!m_status.inCooling) return 0;
   datetime now = TimeCurrent();
   if(now >= m_status.coolingEndTime) return 0;
   return (int)((m_status.coolingEndTime - now) / 60);
}

//+------------------------------------------------------------------+
//| String helpers                                                    |
//+------------------------------------------------------------------+
string CASQRecoveryEngine::EmotionToString(ENUM_ASQ_EMOTIONAL_STATE emotion)
{
   switch(emotion)
   {
      case ASQ_EMOTION_CALM:     return "CALM";
      case ASQ_EMOTION_FOCUSED:  return "FOCUSED";
      case ASQ_EMOTION_STRESSED: return "STRESSED";
      case ASQ_EMOTION_TILTED:   return "TILTED";
      case ASQ_EMOTION_RECKLESS: return "RECKLESS";
      default:                   return "---";
   }
}

string CASQRecoveryEngine::StateToString(ENUM_ASQ_RECOVERY_STATE state)
{
   switch(state)
   {
      case ASQ_STATE_NORMAL:     return "NORMAL";
      case ASQ_STATE_CAUTION:    return "CAUTION";
      case ASQ_STATE_DEFENSIVE:  return "DEFENSIVE";
      case ASQ_STATE_COOLING:    return "COOLING";
      case ASQ_STATE_RECOVERING: return "RECOVERING";
      case ASQ_STATE_STREAK:     return "STREAK";
      default:                   return "---";
   }
}

string CASQRecoveryEngine::GetDetailedStatus()
{
   string s = "=== ASQ RECOVERY ENGINE v1.2 ===\n";
   s += "State: " + m_status.statusMessage + " | Emotion: " + EmotionToString(m_status.emotion) + "\n";
   s += "Risk Mult: " + DoubleToString(m_status.riskMultiplier * 100, 0) + "% | Heat: " + IntegerToString(m_status.heatScore) + "/100\n";
   s += "Adj Risk: " + DoubleToString(GetAdjustedRisk(), 2) + "% | Adj Lot: " + DoubleToString(GetAdjustedLot(), 3) + "\n\n";
   s += "Consec L: " + IntegerToString(m_status.consecutiveLosses) + " (max " + IntegerToString(m_status.maxConsecLosses) + ")\n";
   s += "Consec W: " + IntegerToString(m_status.consecutiveWins) + " (max " + IntegerToString(m_status.maxConsecWins) + ")\n";
   s += "Session: W" + IntegerToString(m_status.sessionWins) + " L" + IntegerToString(m_status.sessionLosses) + " | P/L: $" + DoubleToString(m_status.sessionProfit, 2) + "\n";
   if(m_status.recommendation != "") s += ">> " + m_status.recommendation + "\n";
   return s;
}

//+------------------------------------------------------------------+
//| Reset                                                             |
//+------------------------------------------------------------------+
void CASQRecoveryEngine::Reset()
{
   m_status.Reset(); m_status.riskMultiplier = 1.0;
   m_lastLossTime = 0;
}

void CASQRecoveryEngine::ResetDaily()
{
   m_status.sessionWins = 0; m_status.sessionLosses = 0; m_status.sessionProfit = 0;
   m_status.biggestLoss = 0; m_status.biggestWin = 0; m_status.coolingsToday = 0;
   m_status.heatScore = 0; m_status.revengeBlocksToday = 0;
   m_status.autoSwitchedConservative = false;
   m_sessionPeak = AccountInfoDouble(ACCOUNT_BALANCE);
   if(m_settings.resetDaily)
   {
      m_status.riskMultiplier = 1.0; m_status.consecutiveLosses = 0;
      m_status.consecutiveWins = 0; m_status.state = ASQ_STATE_NORMAL;
      m_status.inCooling = false; m_status.emotion = ASQ_EMOTION_CALM;
      // Restore original mode if auto-switched
      if(m_originalMode != m_settings.mode)
      {
         SetMode(m_originalMode);
         ASQLog("Mode restored to original");
      }
   }
   m_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   ASQLog("Daily reset | Heat: 0 | Balance: $" + DoubleToString(m_dayStartBalance, 2));
}

void CASQRecoveryEngine::ForceNormal()
{
   m_status.state = ASQ_STATE_NORMAL; m_status.riskMultiplier = 1.0;
   m_status.inCooling = false; m_status.emotion = ASQ_EMOTION_CALM;
   m_status.heatScore = 0; m_status.revengeTradeBlocked = false;
   m_status.martingaleBlocked = false;
   UpdateStatusMessage();
}

datetime CASQRecoveryEngine::GetDayStart(datetime time)
{
   MqlDateTime dt; TimeToStruct(time, dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   return StructToTime(dt);
}

void CASQRecoveryEngine::ASQLog(string msg)
{
   if(!m_verbose) return;
   if(MQLInfoInteger(MQL_TESTER)) return;
   Print("[ASQ Recovery] ", msg);
}

#endif // ASQ_RECOVERY_ENGINE_MQH
