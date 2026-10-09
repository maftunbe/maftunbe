//+------------------------------------------------------------------+
//|                                            MomentumZoneOsc.mq5   |
//|  Ossillyator indikator (alohida oyna, 0-100).                    |
//|  RSI va Stochastic %K ni birlashtirib silliqlaydi, sozlanadigan  |
//|  overbought/oversold zonadan QAYTGANDA BUY/SELL beradi           |
//|  (shunchaki chegarani kesib otganda emas - shovqin kamroq).      |
//|                                                                   |
//|  TradeSupervisor EA bilan ishlatish uchun:                       |
//|    MODE_ARROWS: InpBufA=1 (BUY), InpBufB=2 (SELL)                |
//|    MODE_LEVEL : InpBufA=0, InpHi=InpOverbought, InpLo=InpOversold|
//+------------------------------------------------------------------+
#property copyright "MomentumZoneOsc"
#property version   "1.00"
#property indicator_separate_window
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_buffers 3
#property indicator_plots   3

#property indicator_type1   DRAW_LINE
#property indicator_color1  clrSilver
#property indicator_width1  2
#property indicator_label1  "Momentum Zone"

#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrLime
#property indicator_width2  2
#property indicator_label2  "Buy"

#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrRed
#property indicator_width3  2
#property indicator_label3  "Sell"

//============================= INPUTS ==============================//
input group "=== Formula ==="
input int InpRsiPeriod    = 14;   // RSI davri
input int InpStochK       = 14;   // Stochastic %K davri
input int InpStochD       = 3;    // Stochastic %D davri
input int InpStochSlow    = 3;    // Stochastic silliqlash
input int InpSmoothPeriod = 3;    // Yakuniy EMA silliqlash (shovqinni kamaytirish)

input group "=== Zonalar ==="
input double InpOversold   = 20.0;   // Pastki zona (shu yerdan yuqoriga qaytsa - BUY)
input double InpOverbought = 80.0;   // Yuqori zona (shu yerdan pastga qaytsa - SELL)

input group "=== Xabarlar ==="
input bool InpAlerts = true;   // Yangi signalda terminalda Alert
input bool InpPush   = false;  // Yangi signalda MT5 mobilga push

//============================== STATE ==============================//
double BufOsc[];
double BufBuy[];
double BufSell[];

int hRsi   = INVALID_HANDLE;
int hStoch = INVALID_HANDLE;

//+------------------------------------------------------------------+
int Warmup()
  {
   return(MathMax(InpRsiPeriod, InpStochK + InpStochD + InpStochSlow) + InpSmoothPeriod + 3);
  }

int OnInit()
  {
   if(InpRsiPeriod<2 || InpStochK<2 || InpSmoothPeriod<1)
     {
      Print("Xato: davrlar notogri (RSI/Stochastic >=2, Smooth >=1 bolishi kerak)");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpOversold >= InpOverbought)
     {
      Print("Xato: InpOversold InpOverbought dan kichik bolishi kerak");
      return(INIT_PARAMETERS_INCORRECT);
     }

   hRsi   = iRSI(_Symbol, _Period, InpRsiPeriod, PRICE_CLOSE);
   hStoch = iStochastic(_Symbol, _Period, InpStochK, InpStochD, InpStochSlow, MODE_SMA, STO_LOWHIGH);
   if(hRsi==INVALID_HANDLE || hStoch==INVALID_HANDLE)
     {
      Print("Xato: ichki indikator handle yaratilmadi (RSI/Stochastic)");
      return(INIT_FAILED);
     }

   SetIndexBuffer(0, BufOsc,  INDICATOR_DATA);
   SetIndexBuffer(1, BufBuy,  INDICATOR_DATA);
   SetIndexBuffer(2, BufSell, INDICATOR_DATA);

   ArraySetAsSeries(BufOsc,  false);
   ArraySetAsSeries(BufBuy,  false);
   ArraySetAsSeries(BufSell, false);

   PlotIndexSetInteger(1, PLOT_ARROW, 233);   // BUY - yuqoriga strelka
   PlotIndexSetInteger(2, PLOT_ARROW, 234);   // SELL - pastga strelka

   int warm = Warmup();
   for(int p=0; p<3; p++)
     {
      PlotIndexSetDouble (p, PLOT_EMPTY_VALUE, EMPTY_VALUE);
      PlotIndexSetInteger(p, PLOT_DRAW_BEGIN,  warm);
     }

   IndicatorSetDouble(INDICATOR_MINIMUM, 0.0);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 100.0);
   IndicatorSetInteger(INDICATOR_LEVELS, 3);
   IndicatorSetDouble (INDICATOR_LEVELVALUE, 0, InpOversold);
   IndicatorSetDouble (INDICATOR_LEVELVALUE, 1, 50.0);
   IndicatorSetDouble (INDICATOR_LEVELVALUE, 2, InpOverbought);
   IndicatorSetString(INDICATOR_SHORTNAME,
      StringFormat("MomentumZoneOsc(%d,%d/%d/%d,S%d)", InpRsiPeriod, InpStochK, InpStochD, InpStochSlow, InpSmoothPeriod));

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(hRsi  !=INVALID_HANDLE) IndicatorRelease(hRsi);
   if(hStoch!=INVALID_HANDLE) IndicatorRelease(hStoch);
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

   double rsiArr[], stochArr[];
   ArraySetAsSeries(rsiArr,   false);
   ArraySetAsSeries(stochArr, false);

   if(CopyBuffer(hRsi,   0, 0, rates_total, rsiArr)   <= 0) return(0);
   if(CopyBuffer(hStoch, 0, 0, rates_total, stochArr) <= 0) return(0);

   int start = (prev_calculated > 1) ? prev_calculated - 1 : warm;
   start = MathMax(start, warm);

   double k = 2.0 / (InpSmoothPeriod + 1.0);

   for(int i = start; i < rates_total; i++)
     {
      double raw = (rsiArr[i] + stochArr[i]) / 2.0;
      BufOsc[i] = (i <= warm) ? raw : BufOsc[i-1] + k*(raw - BufOsc[i-1]);

      BufBuy[i]  = EMPTY_VALUE;
      BufSell[i] = EMPTY_VALUE;

      bool backUpFromOversold   = (BufOsc[i-1] <= InpOversold   && BufOsc[i] > InpOversold);
      bool backDownFromOverbought = (BufOsc[i-1] >= InpOverbought && BufOsc[i] < InpOverbought);

      if(backUpFromOversold)        BufBuy[i]  = BufOsc[i];
      else if(backDownFromOverbought) BufSell[i] = BufOsc[i];
     }

   //--- yopilgan oxirgi bar bo'yicha xabar (shakllanayotgan barga qarab emas)
   static datetime lastAlertTime = 0;
   int closedIdx = rates_total - 2;
   if(closedIdx >= start && closedIdx >= 1 && time[closedIdx] != lastAlertTime)
     {
      string msg = "";
      if(BufBuy[closedIdx] != EMPTY_VALUE)
         msg = StringFormat("%s %s: BUY (oversold zonadan qaytish, %.1f)", _Symbol, EnumToString(_Period), BufOsc[closedIdx]);
      else if(BufSell[closedIdx] != EMPTY_VALUE)
         msg = StringFormat("%s %s: SELL (overbought zonadan qaytish, %.1f)", _Symbol, EnumToString(_Period), BufOsc[closedIdx]);

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
