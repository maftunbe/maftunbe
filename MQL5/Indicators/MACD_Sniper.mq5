//+------------------------------------------------------------------+
//|                                             MACD_Sniper.mq5      |
//|  MACD (tez EMA - sekin EMA, signal chizigi) - RSI kabi 0-100      |
//|  shkalada korsatiladi: MACD va Signal oz oxirgi N bariga nisbatan |
//|  normallashtiriladi, 30/70 da qatiy gorizontal darajalar turadi.  |
//|  Signal: MACD Signal'ni YUQORIGA kesib otsa = BUY, PASTGA = SELL. |
//|  Faqat yopilgan barda (repaint yoq).                              |
//|  Bu EA'dagi "MACD Divergence"dan FARQLI, sodda kesishish signali. |
//+------------------------------------------------------------------+
#property copyright "MACD Sniper"
#property version   "2.00"
#property indicator_separate_window
#property indicator_buffers 11
#property indicator_plots   5
#property indicator_minimum -10
#property indicator_maximum 110

#property indicator_label1  "MACD"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2

#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_width2  2

#property indicator_label3  "Hist"
#property indicator_type3   DRAW_COLOR_HISTOGRAM2
#property indicator_color3  clrLimeGreen,clrRed
#property indicator_width3  2

#property indicator_label4  "Buy"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrLime
#property indicator_width4  2

#property indicator_label5  "Sell"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrRed
#property indicator_width5  2

//============================= INPUTS ==============================//
input group "=== MACD ==="
input int      InpFastEMA   = 8;      // Tez EMA davri (kichik = tezroq, lekin ko'proq shovqin)
input int      InpSlowEMA   = 17;     // Sekin EMA davri
input int      InpSignalEMA = 5;      // Signal chizigi EMA davri

input group "=== Signal filtri ==="
input bool     InpOnlyBelowZeroBuy  = false;  // BUY faqat MACD nol chizigidan PASTDA kesishsa
input bool     InpOnlyAboveZeroSell = false;  // SELL faqat MACD nol chizigidan TEPADA kesishsa
input int      InpCooldownBars      = 5;      // Ikki signal orasidagi eng kam bar - tekis bozorda ketma-ket mayda kesishishlarni kamaytiradi

input group "=== Daraja (RSI uslubida 0-100) ==="
input int      InpLevelLookback  = 100;    // 0-100 ga otkazish uchun necha bar (MACD'ning oz tarixi)
input bool     InpUseLevelFilter = true;   // BUY faqat past zonada, SELL faqat yuqori zonada
input double   InpLevelSellZone  = 70.0;   // Yuqori daraja (RSI 70 kabi) - SELL shundan YUQORIDA
input double   InpLevelBuyZone   = 30.0;   // Past daraja (RSI 30 kabi) - BUY shundan PASTDA

input group "=== Korinish ==="
input int      InpHistoryBars = 1500;      // Tarixda nechta bar uchun signal chizilsin
input double   InpHistScale   = 3.0;       // Gistogramma ustunlarini kattalashtirish (faqat korinish)
input color    InpLevelColor  = clrGold;   // 30/70 daraja chiziqlari rangi

input group "=== Ogohlantirish ==="
input bool     InpAlert = true;    // Terminal Alert
input bool     InpPush  = false;   // Telefonga push

//============================ BUFFERS ==============================//
// Chizma buferlari HAMMA hisoblash buferlaridan OLDIN bolishi shart
double BufMacdN[], BufSigN[];                 // 0-100 dagi MACD va Signal (korinish)
double BufHistA[], BufHistB[], BufHistClr[];  // 50 dan boshlanadigan gistogramma
double BufBuy[], BufSell[];
double EmaFast[], EmaSlow[], BufMacd[], BufSignal[];   // xom MACD - signal logikasi shundan

string   PFX = "MACDX_";
int      g_lastProcessed = -1;
int      g_lastSignalIdx = -1000000;   // cooldown uchun - oxirgi signal bergan bar indeksi
datetime g_lastAlertTime = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpFastEMA<1 || InpSlowEMA<1 || InpSignalEMA<1 || InpFastEMA>=InpSlowEMA ||
      InpHistoryBars<50 || InpLevelLookback<10 || InpLevelBuyZone>=InpLevelSellZone)
     {
      Print("Parametrlar notogri: tez EMA < sekin EMA, davrlar musbat, past daraja < yuqori daraja bolishi kerak");
      return(INIT_PARAMETERS_INCORRECT);
     }

   SetIndexBuffer(0,  BufMacdN,   INDICATOR_DATA);
   SetIndexBuffer(1,  BufSigN,    INDICATOR_DATA);
   SetIndexBuffer(2,  BufHistA,   INDICATOR_DATA);
   SetIndexBuffer(3,  BufHistB,   INDICATOR_DATA);
   SetIndexBuffer(4,  BufHistClr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(5,  BufBuy,     INDICATOR_DATA);
   SetIndexBuffer(6,  BufSell,    INDICATOR_DATA);
   SetIndexBuffer(7,  EmaFast,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(8,  EmaSlow,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(9,  BufMacd,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(10, BufSignal,  INDICATOR_CALCULATIONS);

   PlotIndexSetInteger(3, PLOT_ARROW, 233);
   PlotIndexSetInteger(4, PLOT_ARROW, 234);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   int warm = MathMax(InpSlowEMA + InpSignalEMA + 5, InpLevelLookback);
   for(int p=0; p<5; p++) PlotIndexSetInteger(p, PLOT_DRAW_BEGIN, warm);

   // RSI kabi qatiy gorizontal darajalar: 30 / 50 / 70
   IndicatorSetInteger(INDICATOR_LEVELS, 3);
   IndicatorSetDouble (INDICATOR_LEVELVALUE, 0, InpLevelSellZone);
   IndicatorSetDouble (INDICATOR_LEVELVALUE, 1, 50.0);
   IndicatorSetDouble (INDICATOR_LEVELVALUE, 2, InpLevelBuyZone);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, InpLevelColor);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 1, clrDimGray);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 2, InpLevelColor);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, 0, STYLE_DASH);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, 1, STYLE_DOT);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, 2, STYLE_DASH);

   IndicatorSetString(INDICATOR_SHORTNAME,
      StringFormat("MACD Sniper (%d,%d,%d)", InpFastEMA, InpSlowEMA, InpSignalEMA));
   IndicatorSetInteger(INDICATOR_DIGITS, 1);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, PFX);
  }

//=========================== YORDAMCHI =============================//
double Ema(const double val, const double prev, const int per)
  {
   return(prev + (2.0/(per+1.0))*(val-prev));
  }

void Notify(const string msg)
  {
   if(InpAlert) Alert(msg);
   if(InpPush)  SendNotification(msg);
   Print(msg);
  }

void ResetState()
  {
   g_lastProcessed = -1;
   g_lastSignalIdx = -1000000;
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[], const double &close[],
                const long &tick_volume[], const long &volume[], const int &spread[])
  {
   int warm = MathMax(InpSlowEMA + InpSignalEMA + 5, InpLevelLookback);
   if(rates_total < warm+5) return(0);

   // Barcha massivlar ODDIY tartibda: 0 = eng eski bar
   ArraySetAsSeries(time,false); ArraySetAsSeries(close,false);

   int start = (prev_calculated>1) ? prev_calculated-1 : 0;
   if(start==0)
     {
      ResetState();
      ObjectsDeleteAll(0, PFX);
     }

   //--- xom MACD, keyin uni oz oxirgi InpLevelLookback bariga nisbatan 0-100 ga otkazish
   for(int i=start; i<rates_total; i++)
     {
      EmaFast[i]   = (i==0) ? close[i] : Ema(close[i], EmaFast[i-1], InpFastEMA);
      EmaSlow[i]   = (i==0) ? close[i] : Ema(close[i], EmaSlow[i-1], InpSlowEMA);
      BufMacd[i]   = EmaFast[i]-EmaSlow[i];
      BufSignal[i] = (i==0) ? BufMacd[i] : Ema(BufMacd[i], BufSignal[i-1], InpSignalEMA);

      // MACD va Signal bitta shkalada bolishi uchun ikkalasining umumiy min/max'i
      int lf = MathMax(0, i-InpLevelLookback+1);
      double mn = MathMin(BufMacd[lf], BufSignal[lf]);
      double mx = MathMax(BufMacd[lf], BufSignal[lf]);
      for(int k=lf+1; k<=i; k++)
        {
         mn = MathMin(mn, MathMin(BufMacd[k], BufSignal[k]));
         mx = MathMax(mx, MathMax(BufMacd[k], BufSignal[k]));
        }
      double rng = mx-mn;
      BufMacdN[i] = (rng>0) ? (BufMacd[i]-mn)/rng*100.0   : 50.0;
      BufSigN[i]  = (rng>0) ? (BufSignal[i]-mn)/rng*100.0 : 50.0;

      double d = BufMacdN[i]-BufSigN[i];
      BufHistA[i]   = 50.0;
      BufHistB[i]   = MathMax(0.0, MathMin(100.0, 50.0 + d*InpHistScale));
      BufHistClr[i] = (d>=0) ? 0 : 1;

      BufBuy[i]  = EMPTY_VALUE;
      BufSell[i] = EMPTY_VALUE;
     }

   //--- kesishish signali FAQAT yopilgan barlarda (repaint yoq)
   int lastClosed = rates_total-2;
   int histFrom   = MathMax(warm, rates_total-InpHistoryBars);
   int from       = MathMax(g_lastProcessed+1, histFrom);
   bool live      = (prev_calculated>0);

   for(int i=MathMax(from,1); i<=lastClosed; i++)
     {
      // kesishish xom qiymatdan - 0-100 ga otkazish har bar ichida tartibni ozgartirmaydi
      bool crossUp   = (BufMacd[i-1]<=BufSignal[i-1] && BufMacd[i]>BufSignal[i]);
      bool crossDown = (BufMacd[i-1]>=BufSignal[i-1] && BufMacd[i]<BufSignal[i]);
      if(InpOnlyBelowZeroBuy  && crossUp   && BufMacd[i]>0) crossUp   = false;
      if(InpOnlyAboveZeroSell && crossDown && BufMacd[i]<0) crossDown = false;
      // tekis/tebranuvchi bozorda ketma-ket mayda kesishishlarni bosib qoyish
      if((crossUp || crossDown) && (i-g_lastSignalIdx) < InpCooldownBars)
        { crossUp=false; crossDown=false; }
      // RSI uslubida: BUY faqat 30 dan pastda, SELL faqat 70 dan yuqorida
      if(InpUseLevelFilter)
        {
         if(crossUp   && BufMacdN[i] > InpLevelBuyZone)  crossUp   = false;
         if(crossDown && BufMacdN[i] < InpLevelSellZone) crossDown = false;
        }

      if(crossUp || crossDown)
        {
         g_lastSignalIdx = i;
         if(crossUp)   BufBuy[i]  = MathMin(BufMacdN[i],BufSigN[i]) - 6.0;
         if(crossDown) BufSell[i] = MathMax(BufMacdN[i],BufSigN[i]) + 6.0;

         if(live && time[i]!=g_lastAlertTime)
           {
            g_lastAlertTime = time[i];
            Notify(StringFormat("%s %s: MACD %s kesishdi @ %s",
                   _Symbol, StringSubstr(EnumToString((ENUM_TIMEFRAMES)_Period),7),
                   crossUp?"BUY":"SELL", DoubleToString(close[i],_Digits)));
           }
        }
      g_lastProcessed = i;
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
