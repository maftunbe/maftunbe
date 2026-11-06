//+------------------------------------------------------------------+
//|                                             MACD_Sniper.mq5      |
//|  Standart MACD (tez EMA - sekin EMA, signal chizigi).             |
//|  Signal: MACD chizigi Signal chizigidan YUQORIGA otsa = BUY,      |
//|          PASTGA otsa = SELL. Faqat yopilgan barda (repaint yoq).  |
//|  Bu EA'dagi "MACD Divergence"dan FARQLI, sodda kesishish signali. |
//+------------------------------------------------------------------+
#property copyright "MACD Sniper"
#property version   "1.30"
#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots   5

#property indicator_label1  "MACD"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2

#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_width2  2

#property indicator_label3  "Hist"
#property indicator_type3   DRAW_COLOR_HISTOGRAM
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
input bool     InpOnlyBelowZeroBuy  = false;  // BUY faqat nol chizigidan PASTDA kesishsa
input bool     InpOnlyAboveZeroSell = false;  // SELL faqat nol chizigidan TEPADA kesishsa
input int      InpCooldownBars      = 5;      // Ikki signal orasidagi eng kam bar - tekis bozorda ketma-ket mayda kesishishlarni kamaytiradi

input group "=== Daraja filtri (RSI uslubida 0-100) ==="
input bool     InpUseLevelFilter = false;  // MACD'ni oxirgi N barga nisbatan 0-100 shkalaga otkazib, ekstremal zona filtri
input int      InpLevelLookback  = 100;    // Normallashtirish uchun necha bar (MACD'ning oz tarixi)
input double   InpLevelSellZone  = 80.0;   // SELL faqat shu darajadan YUQORIDA (RSI 70 kabi)
input double   InpLevelBuyZone   = 20.0;   // BUY faqat shu darajadan PASTDA (RSI 30 kabi)

input group "=== Korinish ==="
input int      InpHistoryBars = 1500;  // Tarixda nechta bar uchun signal chizilsin
input int      InpArrowRange  = 20;    // Strelka joyini hisoblash uchun necha barlik diapazon

input group "=== Ogohlantirish ==="
input bool     InpAlert = true;    // Terminal Alert
input bool     InpPush  = false;   // Telefonga push

//============================ BUFFERS ==============================//
double BufMacd[], BufSignal[], BufHist[], BufHistClr[], BufBuy[], BufSell[];
double EmaFast[], EmaSlow[];

string   PFX = "MACDX_";
int      g_lastProcessed = -1;
int      g_lastSignalIdx = -1000000;   // cooldown uchun - oxirgi signal bergan bar indeksi
datetime g_lastAlertTime = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpFastEMA<1 || InpSlowEMA<1 || InpSignalEMA<1 || InpFastEMA>=InpSlowEMA || InpHistoryBars<50)
     {
      Print("Parametrlar notogri: tez EMA < sekin EMA bolishi, davrlar musbat bolishi kerak");
      return(INIT_PARAMETERS_INCORRECT);
     }

   SetIndexBuffer(0, BufMacd,    INDICATOR_DATA);
   SetIndexBuffer(1, BufSignal,  INDICATOR_DATA);
   SetIndexBuffer(2, BufHist,    INDICATOR_DATA);
   SetIndexBuffer(3, BufHistClr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4, BufBuy,     INDICATOR_DATA);
   SetIndexBuffer(5, BufSell,    INDICATOR_DATA);
   SetIndexBuffer(6, EmaFast,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, EmaSlow,    INDICATOR_CALCULATIONS);

   PlotIndexSetInteger(3, PLOT_ARROW, 233);
   PlotIndexSetInteger(4, PLOT_ARROW, 234);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   int warm = InpSlowEMA + InpSignalEMA + 5;
   for(int p=0; p<5; p++) PlotIndexSetInteger(p, PLOT_DRAW_BEGIN, warm);

   IndicatorSetString(INDICATOR_SHORTNAME,
      StringFormat("MACD Sniper (%d,%d,%d)", InpFastEMA, InpSlowEMA, InpSignalEMA));
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
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
   int warm = InpSlowEMA + InpSignalEMA + 5;
   if(rates_total < warm+5) return(0);

   // Barcha massivlar ODDIY tartibda: 0 = eng eski bar
   ArraySetAsSeries(time,false); ArraySetAsSeries(close,false);

   int start = (prev_calculated>1) ? prev_calculated-1 : 0;
   if(start==0)
     {
      ResetState();
      ObjectsDeleteAll(0, PFX);
     }

   //--- MACD, Signal, Hist (joriy bar ham - faqat korinish uchun)
   for(int i=start; i<rates_total; i++)
     {
      EmaFast[i]    = (i==0) ? close[i] : Ema(close[i], EmaFast[i-1], InpFastEMA);
      EmaSlow[i]    = (i==0) ? close[i] : Ema(close[i], EmaSlow[i-1], InpSlowEMA);
      BufMacd[i]    = EmaFast[i]-EmaSlow[i];
      BufSignal[i]  = (i==0) ? BufMacd[i] : Ema(BufMacd[i], BufSignal[i-1], InpSignalEMA);
      BufHist[i]    = BufMacd[i]-BufSignal[i];
      BufHistClr[i] = (BufHist[i]>=0) ? 0 : 1;
      BufBuy[i]  = EMPTY_VALUE;
      BufSell[i] = EMPTY_VALUE;
     }

   //--- kesishish signali FAQAT yopilgan barlarda (repaint yoq)
   int lastClosed = rates_total-2;
   int histFrom   = MathMax(warm, rates_total-InpHistoryBars);
   int from       = MathMax(g_lastProcessed+1, histFrom);
   bool live       = (prev_calculated>0);
   int rangeN      = MathMax(2, InpArrowRange);

   for(int i=MathMax(from,1); i<=lastClosed; i++)
     {
      bool crossUp   = (BufMacd[i-1]<=BufSignal[i-1] && BufMacd[i]>BufSignal[i]);
      bool crossDown = (BufMacd[i-1]>=BufSignal[i-1] && BufMacd[i]<BufSignal[i]);
      if(InpOnlyBelowZeroBuy  && crossUp   && BufMacd[i]>0) crossUp   = false;
      if(InpOnlyAboveZeroSell && crossDown && BufMacd[i]<0) crossDown = false;
      // tekis/tebranuvchi bozorda ketma-ket mayda kesishishlarni bosib qoyish
      if((crossUp || crossDown) && (i-g_lastSignalIdx) < InpCooldownBars)
        { crossUp=false; crossDown=false; }

      // RSI uslubidagi daraja filtri: MACD chegarasiz bolgani uchun uni oz oxirgi
      // N bariga nisbatan 0-100 ga otkazamiz, keyin BUY/SELL'ni shu zonaga bogliq qilamiz
      if(InpUseLevelFilter && (crossUp || crossDown))
        {
         int lf = MathMax(0, i-InpLevelLookback+1);
         double lmn=BufMacd[lf], lmx=BufMacd[lf];
         for(int k=lf; k<=i; k++)
           {
            lmn = MathMin(lmn, BufMacd[k]);
            lmx = MathMax(lmx, BufMacd[k]);
           }
         double lvl = (lmx>lmn) ? (BufMacd[i]-lmn)/(lmx-lmn)*100.0 : 50.0;
         if(crossUp   && lvl>InpLevelBuyZone)  crossUp   = false;
         if(crossDown && lvl<InpLevelSellZone) crossDown = false;
        }

      if(crossUp || crossDown)
        {
         g_lastSignalIdx = i;
         // strelkani chiziqlardan ozgina pastga/tepaga qoyish uchun mahalliy
         // diapazonga nisbatan dinamik masofa (MACD olchami instrumentga qarab turlicha)
         int rf = MathMax(0, i-rangeN);
         double hh=BufMacd[rf], ll=BufMacd[rf];
         for(int k=rf; k<=i; k++)
           {
            hh = MathMax(hh, MathMax(BufMacd[k],BufSignal[k]));
            ll = MathMin(ll, MathMin(BufMacd[k],BufSignal[k]));
           }
         double rng = hh-ll;
         if(rng<=0) rng = MathAbs(BufMacd[i])*0.1 + 0.0000001;
         double off = rng*0.12;

         if(crossUp)   BufBuy[i]  = MathMin(BufMacd[i],BufSignal[i]) - off;
         if(crossDown) BufSell[i] = MathMax(BufMacd[i],BufSignal[i]) + off;

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
