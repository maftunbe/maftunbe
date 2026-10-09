//+------------------------------------------------------------------+
//|                                               SniperSignal.mq5   |
//|  Kam lag (kechikish) uchun molljallangan indikator.               |
//|  Oddiy EMA kesishuvi yoki oscillator silliqlashdan farqli -       |
//|  Hull Moving Average (HMA) ishlatadi: xuddi shu davrdagi          |
//|  EMA/SMA ga qaraganda narxga tezroq moslashadi, shu sabab         |
//|  signal kamroq kech chiqadi.                                      |
//|                                                                   |
//|  Chiziq rangi qiyalik (slope) yonalishiga qarab ozgaradi          |
//|  (yashil = osish, qizil = tushish), qiyalik burilganda esa        |
//|  BUY/SELL strelkasi chiqadi.                                      |
//|                                                                   |
//|  TEZLIK/ISHONCHLILIK TANLOVI (InpConfirmOnClose):                 |
//|    true  - signal faqat yopilgan barda tasdiqlanadi (xavfsiz,     |
//|             1 bar kech bolishi mumkin, lekin qayta chizilmaydi)   |
//|    false - signal joriy (hali yopilmagan) barda chiqadi - eng     |
//|             tezkor, lekin bar yopilguncha strelka ozgarishi       |
//|             (repaint) mumkin. Ongli ravishda shu narx uchun       |
//|             tezlik tanlanadi.                                     |
//|                                                                   |
//|  TradeSupervisor EA bilan ishlatish uchun:                       |
//|    MODE_ARROWS: InpBufA=2 (BUY), InpBufB=3 (SELL)                |
//+------------------------------------------------------------------+
#property copyright "SniperSignal"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   3

#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLime,clrRed
#property indicator_width1  3
#property indicator_label1  "Sniper HMA"

#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrLime
#property indicator_width2  2
#property indicator_label2  "Buy"

#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrRed
#property indicator_width3  2
#property indicator_label3  "Sell"

//============================= INPUTS ==============================//
input group "=== Sniper HMA (kam lag) ==="
input int                InpHmaPeriod    = 21;          // Hull MA davri (kichikroq = tezroq, lekin shovqinliroq)
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE;  // Qaysi narxga qarab

input group "=== Shovqin filtri ==="
input double InpMinSlopeATR = 0.05;  // Minimal qiyalik (ATR koeffitsienti). 0 = filtrsiz
input int    InpAtrPeriod   = 14;    // ATR davri (filtr va strelka masofasi uchun)
input double InpArrowGapATR = 0.4;   // Strelka chiziqdan qancha uzoqda (ATR koeffitsienti)

input group "=== Tezlik / ishonchlilik ==="
input bool InpConfirmOnClose = true;  // true=yopilgan barda tasdiqlangan signal; false=eng tezkor (repaint mumkin)

input group "=== Xabarlar ==="
input bool InpAlerts = true;   // Yangi signalda terminalda Alert
input bool InpPush   = false;  // Yangi signalda MT5 mobilga push

//============================== STATE ==============================//
double BufHma[];
double BufColor[];
double BufBuy[];
double BufSell[];

int hWmaHalf = INVALID_HANDLE;
int hWmaFull = INVALID_HANDLE;
int hAtr     = INVALID_HANDLE;
int g_sqrtN  = 1;

//+------------------------------------------------------------------+
int Warmup()
  {
   return(InpHmaPeriod + g_sqrtN + InpAtrPeriod + 3);
  }

int OnInit()
  {
   if(InpHmaPeriod < 2)
     {
      Print("Xato: InpHmaPeriod kamida 2 bolishi kerak");
      return(INIT_PARAMETERS_INCORRECT);
     }

   int halfN = MathMax(1, (int)MathRound(InpHmaPeriod/2.0));
   g_sqrtN   = MathMax(1, (int)MathRound(MathSqrt((double)InpHmaPeriod)));

   hWmaHalf = iMA(_Symbol, _Period, halfN,         0, MODE_LWMA, InpAppliedPrice);
   hWmaFull = iMA(_Symbol, _Period, InpHmaPeriod,  0, MODE_LWMA, InpAppliedPrice);
   hAtr     = iATR(_Symbol, _Period, InpAtrPeriod);
   if(hWmaHalf==INVALID_HANDLE || hWmaFull==INVALID_HANDLE || hAtr==INVALID_HANDLE)
     {
      Print("Xato: ichki indikator handle yaratilmadi (LWMA/ATR)");
      return(INIT_FAILED);
     }

   SetIndexBuffer(0, BufHma,   INDICATOR_DATA);
   SetIndexBuffer(1, BufColor, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufBuy,   INDICATOR_DATA);
   SetIndexBuffer(3, BufSell,  INDICATOR_DATA);

   ArraySetAsSeries(BufHma,   false);
   ArraySetAsSeries(BufColor, false);
   ArraySetAsSeries(BufBuy,   false);
   ArraySetAsSeries(BufSell,  false);

   PlotIndexSetInteger(1, PLOT_ARROW, 233);   // BUY
   PlotIndexSetInteger(2, PLOT_ARROW, 234);   // SELL

   int warm = Warmup();
   for(int p=0; p<3; p++)
     {
      PlotIndexSetInteger(p, PLOT_DRAW_BEGIN, warm);
      if(p>0) PlotIndexSetDouble(p, PLOT_EMPTY_VALUE, EMPTY_VALUE);
     }
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   IndicatorSetString(INDICATOR_SHORTNAME,
      StringFormat("SniperSignal(HMA%d,%s)", InpHmaPeriod, (InpConfirmOnClose ? "safe" : "FAST/repaint")));

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(hWmaHalf!=INVALID_HANDLE) IndicatorRelease(hWmaHalf);
   if(hWmaFull!=INVALID_HANDLE) IndicatorRelease(hWmaFull);
   if(hAtr    !=INVALID_HANDLE) IndicatorRelease(hAtr);
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

   double wmaHalfArr[], wmaFullArr[], atrArr[];
   ArraySetAsSeries(wmaHalfArr, false);
   ArraySetAsSeries(wmaFullArr, false);
   ArraySetAsSeries(atrArr,     false);

   if(CopyBuffer(hWmaHalf, 0, 0, rates_total, wmaHalfArr) <= 0) return(0);
   if(CopyBuffer(hWmaFull, 0, 0, rates_total, wmaFullArr) <= 0) return(0);
   if(CopyBuffer(hAtr,     0, 0, rates_total, atrArr)     <= 0) return(0);

   //--- Hull MA'ning ichki bosqichi: raw2 = 2*WMA(n/2) - WMA(n)
   double raw2[];
   ArrayResize(raw2, rates_total);
   int fullN = InpHmaPeriod;
   for(int i = fullN-1; i < rates_total; i++)
      raw2[i] = 2.0*wmaHalfArr[i] - wmaFullArr[i];

   //--- yakuniy silliqlash: WMA(raw2, sqrt(n)) - shu Hull MA ni beradi
   double wsum = g_sqrtN*(g_sqrtN+1)/2.0;

   int start = (prev_calculated > 1) ? prev_calculated - 1 : warm;
   start = MathMax(start, warm);

   int lastClosed = rates_total - 2;   // -1 = joriy (hali yopilmagan) bar

   for(int i = start; i < rates_total; i++)
     {
      double sum = 0;
      for(int k=0; k<g_sqrtN; k++)
         sum += raw2[i-k]*(g_sqrtN-k);
      BufHma[i] = sum/wsum;

      double slope = BufHma[i] - BufHma[i-1];
      BufColor[i] = (slope >= 0) ? 0 : 1;   // 0=yashil(osish) 1=qizil(tushish)

      BufBuy[i]  = EMPTY_VALUE;
      BufSell[i] = EMPTY_VALUE;

      bool skipThisBar = (InpConfirmOnClose && i > lastClosed);   // joriy barni kutamiz
      if(skipThisBar) continue;

      double prevSlope = BufHma[i-1] - BufHma[i-2];
      bool flippedUp   = (prevSlope <= 0 && slope > 0);
      bool flippedDown = (prevSlope >= 0 && slope < 0);
      bool gapOk       = (InpMinSlopeATR<=0) || (MathAbs(slope) >= atrArr[i]*InpMinSlopeATR);

      if(flippedUp && gapOk)        BufBuy[i]  = BufHma[i] - atrArr[i]*InpArrowGapATR;
      else if(flippedDown && gapOk) BufSell[i] = BufHma[i] + atrArr[i]*InpArrowGapATR;
     }

   //--- xabar: bar yopilganda, yoki InpConfirmOnClose=false bolsa joriy barda yonalish ozgarganda
   static datetime lastAlertTime = 0;
   static int       lastAlertDir  = 0;
   int checkIdx = InpConfirmOnClose ? lastClosed : (rates_total-1);
   if(checkIdx >= start && checkIdx >= 2)
     {
      int dir = (BufBuy[checkIdx]!=EMPTY_VALUE) ? 1 : ((BufSell[checkIdx]!=EMPTY_VALUE) ? -1 : 0);
      if(dir!=0 && (time[checkIdx]!=lastAlertTime || dir!=lastAlertDir))
        {
         lastAlertTime = time[checkIdx];
         lastAlertDir  = dir;
         string msg = StringFormat("%s %s: SNIPER %s @ %s%s", _Symbol, EnumToString(_Period),
                      (dir>0?"BUY":"SELL"), DoubleToString(close[checkIdx], _Digits),
                      (InpConfirmOnClose ? "" : "  (tezkor, hali tasdiqlanmagan)"));
         if(InpAlerts) Alert(msg);
         if(InpPush)   SendNotification(msg);
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
