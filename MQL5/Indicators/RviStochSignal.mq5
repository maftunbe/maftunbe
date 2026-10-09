//+------------------------------------------------------------------+
//|                                             RviStochSignal.mq5   |
//|  RVI (Relative Vigor Index) va Stochastic'ni BITTA signalga      |
//|  birlashtiradi: ikkisi bir yonalishda "rozi" bolgan HAR BIR barda |
//|  BUY/SELL strelkasi chiqadi (kelishuv davom etar ekan, har barda  |
//|  qaytariladi). Faqat bittasi signal bersa - hisobga olinmaydi.   |
//|                                                                   |
//|  RVI ovozi : RVI asosiy chizigi > signal chizigi -> +1 (osish)   |
//|  Stoch ovozi: %K > %D -> +1 (osish)                               |
//|  Ikkisi mos kelgan har bir bar uchun -> strelka                  |
//|                                                                   |
//|  Strelka faqat BAR YOPILGANDAN keyin qoyiladi, shu sabab bir     |
//|  marta chiqgan strelka hech qachon ozgarmaydi/ochib ketmaydi -   |
//|  tarixda doim shunday qolaveradi (repaint yoq).                  |
//|                                                                   |
//|  TradeSupervisor EA bilan ishlatish uchun:                       |
//|    MODE_ARROWS: InpBufA=0 (BUY), InpBufB=1 (SELL)                |
//+------------------------------------------------------------------+
#property copyright "RviStochSignal"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   2

#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_width1  2
#property indicator_label1  "Buy"

#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  2
#property indicator_label2  "Sell"

//============================= INPUTS ==============================//
input group "=== RVI ==="
input int InpRviPeriod = 10;   // RVI davri

input group "=== Stochastic ==="
input int InpStochK    = 14;   // %K davri
input int InpStochD    = 3;    // %D davri
input int InpStochSlow = 3;    // Silliqlash

input group "=== Filtr ==="
input bool   InpAvoidExtreme = true;   // Stochastic allaqachon ortiqcha zonada bolsa signal bermaydi
input double InpExtremeHi    = 80.0;   // Shundan yuqorida BUY berilmaydi (allaqachon overbought)
input double InpExtremeLo    = 20.0;   // Shundan pastda SELL berilmaydi (allaqachon oversold)

input group "=== Chizish ==="
input int    InpAtrPeriod   = 14;   // Masshtab uchun ATR davri
input double InpArrowGapATR = 0.5;  // Strelka candle'dan qancha uzoqda (ATR koeffitsienti)

input group "=== Xabarlar ==="
input bool InpAlerts = true;   // Yangi signalda terminalda Alert
input bool InpPush   = false;  // Yangi signalda MT5 mobilga push

//============================== STATE ==============================//
double BufBuy[];
double BufSell[];
double BufState[];   // yashirin: oxirgi "kelishilgan" yonalish (-1/0/+1), uzilishsiz hisob uchun

int hRvi   = INVALID_HANDLE;
int hStoch = INVALID_HANDLE;
int hAtr   = INVALID_HANDLE;

//+------------------------------------------------------------------+
int Warmup()
  {
   return(MathMax(InpRviPeriod+4, InpStochK+InpStochD+InpStochSlow) + InpAtrPeriod + 3);
  }

int Sign(const double a, const double b)
  {
   if(a>b) return(1);
   if(a<b) return(-1);
   return(0);
  }

int OnInit()
  {
   if(InpRviPeriod<2 || InpStochK<2)
     {
      Print("Xato: RVI/Stochastic davrlari kamida 2 bolishi kerak");
      return(INIT_PARAMETERS_INCORRECT);
     }

   hRvi   = iRVI(_Symbol, _Period, InpRviPeriod);
   hStoch = iStochastic(_Symbol, _Period, InpStochK, InpStochD, InpStochSlow, MODE_SMA, STO_LOWHIGH);
   hAtr   = iATR(_Symbol, _Period, InpAtrPeriod);
   if(hRvi==INVALID_HANDLE || hStoch==INVALID_HANDLE || hAtr==INVALID_HANDLE)
     {
      Print("Xato: ichki indikator handle yaratilmadi (RVI/Stochastic/ATR)");
      return(INIT_FAILED);
     }

   SetIndexBuffer(0, BufBuy,   INDICATOR_DATA);
   SetIndexBuffer(1, BufSell,  INDICATOR_DATA);
   SetIndexBuffer(2, BufState, INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufBuy,   false);
   ArraySetAsSeries(BufSell,  false);
   ArraySetAsSeries(BufState, false);

   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(1, PLOT_ARROW, 234);

   int warm = Warmup();
   for(int p=0; p<2; p++)
     {
      PlotIndexSetDouble (p, PLOT_EMPTY_VALUE, EMPTY_VALUE);
      PlotIndexSetInteger(p, PLOT_DRAW_BEGIN,  warm);
     }

   IndicatorSetString(INDICATOR_SHORTNAME,
      StringFormat("RviStochSignal(RVI%d,Sto%d/%d/%d)", InpRviPeriod, InpStochK, InpStochD, InpStochSlow));

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(hRvi  !=INVALID_HANDLE) IndicatorRelease(hRvi);
   if(hStoch!=INVALID_HANDLE) IndicatorRelease(hStoch);
   if(hAtr  !=INVALID_HANDLE) IndicatorRelease(hAtr);
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

   double rviMain[], rviSig[], stochK[], stochD[], atrArr[];
   ArraySetAsSeries(rviMain, false); ArraySetAsSeries(rviSig,  false);
   ArraySetAsSeries(stochK,  false); ArraySetAsSeries(stochD,  false);
   ArraySetAsSeries(atrArr,  false);

   if(CopyBuffer(hRvi,   0, 0, rates_total, rviMain) <= 0) return(0);
   if(CopyBuffer(hRvi,   1, 0, rates_total, rviSig)  <= 0) return(0);
   if(CopyBuffer(hStoch, 0, 0, rates_total, stochK)  <= 0) return(0);
   if(CopyBuffer(hStoch, 1, 0, rates_total, stochD)  <= 0) return(0);
   if(CopyBuffer(hAtr,   0, 0, rates_total, atrArr)  <= 0) return(0);

   int start = (prev_calculated > 1) ? prev_calculated - 1 : warm;
   start = MathMax(start, warm);

   for(int i = start; i < rates_total; i++)
     {
      int rviVote   = Sign(rviMain[i], rviSig[i]);
      int stochVote = Sign(stochK[i],  stochD[i]);
      int combined  = (rviVote==stochVote && rviVote!=0) ? rviVote : 0;

      if(combined>0 && InpAvoidExtreme && stochK[i]>=InpExtremeHi) combined = 0;
      if(combined<0 && InpAvoidExtreme && stochK[i]<=InpExtremeLo) combined = 0;

      BufBuy[i]  = EMPTY_VALUE;
      BufSell[i] = EMPTY_VALUE;
      BufState[i] = combined;

      bool isFormingBar = (i == rates_total-1);   // hali yopilmagan bar - strelka qoyilmaydi
      if(isFormingBar) continue;                   // bar yopilgach, keyingi chaqiriqda yakuniy qiymat bilan chiziladi va shundan keyin ozgarmaydi

      if(combined>0)      BufBuy[i]  = low[i]  - atrArr[i]*InpArrowGapATR;
      else if(combined<0) BufSell[i] = high[i] + atrArr[i]*InpArrowGapATR;
     }

   //--- yopilgan oxirgi bar bo'yicha xabar
   static datetime lastAlertTime = 0;
   int closedIdx = rates_total - 2;
   if(closedIdx >= start && closedIdx >= 1 && time[closedIdx] != lastAlertTime)
     {
      string msg = "";
      if(BufBuy[closedIdx] != EMPTY_VALUE)
         msg = StringFormat("%s %s: BUY (RVI + Stochastic kelishdi)", _Symbol, EnumToString(_Period));
      else if(BufSell[closedIdx] != EMPTY_VALUE)
         msg = StringFormat("%s %s: SELL (RVI + Stochastic kelishdi)", _Symbol, EnumToString(_Period));

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
