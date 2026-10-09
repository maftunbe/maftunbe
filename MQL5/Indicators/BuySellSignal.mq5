//+------------------------------------------------------------------+
//|                                               BuySellSignal.mq5  |
//|  Mustaqil indikator: MA kesishuvi + RSI filtri asosida chartda   |
//|  BUY / SELL strelkalarini chiqaradi.                             |
//|                                                                   |
//|  TradeSupervisor EA bilan ishlatish uchun:                       |
//|    InpMode  = MODE_ARROWS                                        |
//|    InpBufA  = 0   (BUY strelka buferi)                           |
//|    InpBufB  = 1   (SELL strelka buferi)                          |
//+------------------------------------------------------------------+
#property copyright "BuySellSignal"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   4

#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_width1  2
#property indicator_label1  "Buy signal"

#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  2
#property indicator_label2  "Sell signal"

#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDodgerBlue
#property indicator_width3  1
#property indicator_label3  "Fast MA"

#property indicator_type4   DRAW_LINE
#property indicator_color4  clrOrange
#property indicator_width4  1
#property indicator_label4  "Slow MA"

//============================= INPUTS ==============================//
input group "=== Trend (MA kesishuvi) ==="
input int                InpFastPeriod   = 12;          // Tez MA davri
input int                InpSlowPeriod   = 26;          // Sekin MA davri
input ENUM_MA_METHOD     InpMAMethod     = MODE_EMA;    // MA usuli
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE;  // Qaysi narxga qarab

input group "=== RSI filtri ==="
input int    InpRsiPeriod    = 14;    // RSI davri
input double InpRsiBuyLevel  = 50.0;  // BUY uchun: RSI shundan yuqori bolsin
input double InpRsiSellLevel = 50.0;  // SELL uchun: RSI shundan past bolsin

input group "=== Chizish / filtr ==="
input int    InpAtrPeriod   = 14;   // ATR davri (masshtab uchun)
input double InpArrowGapATR = 0.5;  // Strelka candle'dan qancha uzoqda (ATR koeffitsienti)
input double InpMinGapATR   = 0.0;  // MA lar orasidagi minimal masofa (ATR koeffitsienti), 0 = filtrsiz

input group "=== Xabarlar ==="
input bool InpAlerts = true;   // Yangi signalda terminalda Alert
input bool InpPush   = false;  // Yangi signalda MT5 mobilga push

//============================== STATE ==============================//
double BufBuy[];
double BufSell[];
double BufFast[];
double BufSlow[];
double BufTrend[];   // yashirin: oxirgi malum trend holati (1/-1), uzilishsiz hisob uchun

int hFast = INVALID_HANDLE;
int hSlow = INVALID_HANDLE;
int hRsi  = INVALID_HANDLE;
int hAtr  = INVALID_HANDLE;

//+------------------------------------------------------------------+
int Warmup()
  {
   return(MathMax(InpSlowPeriod, MathMax(InpRsiPeriod, InpAtrPeriod)) + 2);
  }

int OnInit()
  {
   if(InpFastPeriod >= InpSlowPeriod)
     {
      Print("Xato: Tez MA davri Sekin MA davridan kichik bolishi kerak");
      return(INIT_PARAMETERS_INCORRECT);
     }

   hFast = iMA(_Symbol, _Period, InpFastPeriod, 0, InpMAMethod, InpAppliedPrice);
   hSlow = iMA(_Symbol, _Period, InpSlowPeriod, 0, InpMAMethod, InpAppliedPrice);
   hRsi  = iRSI(_Symbol, _Period, InpRsiPeriod, InpAppliedPrice);
   hAtr  = iATR(_Symbol, _Period, InpAtrPeriod);
   if(hFast==INVALID_HANDLE || hSlow==INVALID_HANDLE || hRsi==INVALID_HANDLE || hAtr==INVALID_HANDLE)
     {
      Print("Xato: ichki indikator handle yaratilmadi (MA/RSI/ATR)");
      return(INIT_FAILED);
     }

   SetIndexBuffer(0, BufBuy,   INDICATOR_DATA);
   SetIndexBuffer(1, BufSell,  INDICATOR_DATA);
   SetIndexBuffer(2, BufFast,  INDICATOR_DATA);
   SetIndexBuffer(3, BufSlow,  INDICATOR_DATA);
   SetIndexBuffer(4, BufTrend, INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufBuy,   false);
   ArraySetAsSeries(BufSell,  false);
   ArraySetAsSeries(BufFast,  false);
   ArraySetAsSeries(BufSlow,  false);
   ArraySetAsSeries(BufTrend, false);

   PlotIndexSetInteger(0, PLOT_ARROW, 233);   // yuqoriga strelka
   PlotIndexSetInteger(1, PLOT_ARROW, 234);   // pastga strelka

   int warm = Warmup();
   for(int p=0; p<4; p++)
     {
      PlotIndexSetDouble (p, PLOT_EMPTY_VALUE, EMPTY_VALUE);
      PlotIndexSetInteger(p, PLOT_DRAW_BEGIN,  warm);
     }

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   IndicatorSetString(INDICATOR_SHORTNAME,
      StringFormat("BuySellSignal(%d,%d,RSI%d)", InpFastPeriod, InpSlowPeriod, InpRsiPeriod));

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(hFast!=INVALID_HANDLE) IndicatorRelease(hFast);
   if(hSlow!=INVALID_HANDLE) IndicatorRelease(hSlow);
   if(hRsi !=INVALID_HANDLE) IndicatorRelease(hRsi);
   if(hAtr !=INVALID_HANDLE) IndicatorRelease(hAtr);
  }

//+------------------------------------------------------------------+
int OnCalculate(const int        rates_total,
                const int        prev_calculated,
                const datetime  &time[],
                const double    &open[],
                const double    &high[],
                const double    &low[],
                const double    &close[],
                const long      &tick_volume[],
                const long      &volume[],
                const int       &spread[])
  {
   int warm = Warmup();
   if(rates_total < warm) return(0);

   double fastArr[], slowArr[], rsiArr[], atrArr[];
   ArraySetAsSeries(fastArr, false);
   ArraySetAsSeries(slowArr, false);
   ArraySetAsSeries(rsiArr,  false);
   ArraySetAsSeries(atrArr,  false);

   if(CopyBuffer(hFast, 0, 0, rates_total, fastArr) <= 0) return(0);
   if(CopyBuffer(hSlow, 0, 0, rates_total, slowArr) <= 0) return(0);
   if(CopyBuffer(hRsi,  0, 0, rates_total, rsiArr)  <= 0) return(0);
   if(CopyBuffer(hAtr,  0, 0, rates_total, atrArr)  <= 0) return(0);

   int start = (prev_calculated > 1) ? prev_calculated - 1 : warm;
   start = MathMax(start, warm);

   for(int i = start; i < rates_total; i++)
     {
      BufBuy[i]  = EMPTY_VALUE;
      BufSell[i] = EMPTY_VALUE;
      BufFast[i] = fastArr[i];
      BufSlow[i] = slowArr[i];

      bool crossUp = (fastArr[i-1] <= slowArr[i-1] && fastArr[i] > slowArr[i]);
      bool crossDn = (fastArr[i-1] >= slowArr[i-1] && fastArr[i] < slowArr[i]);
      bool gapOk   = (InpMinGapATR <= 0) || (MathAbs(fastArr[i]-slowArr[i]) >= atrArr[i]*InpMinGapATR);

      if(crossUp && rsiArr[i] > InpRsiBuyLevel && gapOk)
        {
         BufBuy[i]    = low[i] - atrArr[i]*InpArrowGapATR;
         BufTrend[i]  = 1;
        }
      else if(crossDn && rsiArr[i] < InpRsiSellLevel && gapOk)
        {
         BufSell[i]   = high[i] + atrArr[i]*InpArrowGapATR;
         BufTrend[i]  = -1;
        }
      else
        {
         BufTrend[i] = BufTrend[i-1];
        }
     }

   //--- yopilgan oxirgi bar bo'yicha xabar (shakllanayotgan barga qarab emas)
   static datetime lastAlertTime = 0;
   int closedIdx = rates_total - 2;
   if(closedIdx >= start && closedIdx >= 1 && time[closedIdx] != lastAlertTime)
     {
      string msg = "";
      if(BufBuy[closedIdx] != EMPTY_VALUE)
         msg = StringFormat("%s %s: BUY signal @ %s", _Symbol, EnumToString(_Period), DoubleToString(close[closedIdx], _Digits));
      else if(BufSell[closedIdx] != EMPTY_VALUE)
         msg = StringFormat("%s %s: SELL signal @ %s", _Symbol, EnumToString(_Period), DoubleToString(close[closedIdx], _Digits));

      if(msg != "")
        {
         lastAlertTime = time[closedIdx];
         if(InpAlerts) Alert(msg);
         if(InpPush)   SendNotification(msg);
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
