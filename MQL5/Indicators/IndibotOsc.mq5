//+------------------------------------------------------------------+
//|                                                  IndibotOsc.mq5  |
//|  "Strategy Indibot" mantiqining ochiq qayta qurilishi            |
//|  - Ossillyator: DSS Bressert yoki WaveTrend (LazyBear), 0..100   |
//|  - Signal: ekstremal zonada chiziqlar kesishishi (yopilgan barda)|
//|  - B.E / TP1 / TP2 / TP3 bosqichlari va ularning STATISTIKASI     |
//|  - Narx grafigida va ossillyatorda signal qutilari               |
//+------------------------------------------------------------------+
#property copyright "Indibot logic rebuild"
#property version   "1.10"
#property indicator_separate_window
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_buffers 9
#property indicator_plots   5

#property indicator_label1  "Fast"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDeepPink
#property indicator_width1  2

#property indicator_label2  "Slow"
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

enum ENUM_OSC_MODE
  {
   OSC_DSS       = 0,   // DSS Bressert (double smoothed stochastic)
   OSC_WAVETREND = 1    // WaveTrend (LazyBear)
  };

//============================= INPUTS ==============================//
input group "=== Ossillyator ==="
input ENUM_OSC_MODE InpMode       = OSC_DSS; // Ossillyator turi
input int      InpPDS             = 40;      // DSS: Stochastic davri (swing o'lchamiga mos bo'lsin)
input int      InpEmaLen          = 12;      // DSS: EMA silliqlash
input int      InpTriggerLen      = 5;       // DSS: signal chizig'i EMA
input int      InpChannelLen      = 10;      // WaveTrend: n1 (Channel)
input int      InpAverageLen      = 21;      // WaveTrend: n2 (Average)
input int      InpSignalLen       = 4;       // WaveTrend: signal SMA
input double   InpWTScale         = 0.6;     // WaveTrend: 0..100 ga o'tkazish koeffitsienti

input group "=== Zonalar (sotish) ==="
input double   InpSellZone        = 80.0;    // SELL ZONE: kesishish shundan yuqorida
input double   InpSellBE          = 75.0;    // B.E
input double   InpSellTP1         = 65.0;    // TP1
input double   InpSellTP2         = 55.0;    // TP2
input double   InpSellTP3         = 45.0;    // TP3

input group "=== Zonalar (sotib olish) ==="
input double   InpBuyZone         = 20.0;    // BUY ZONE: kesishish shundan pastda
input double   InpBuyBE           = 25.0;    // B.E
input double   InpBuyTP1          = 35.0;    // TP1
input double   InpBuyTP2          = 45.0;    // TP2
input double   InpBuyTP3          = 55.0;    // TP3

input group "=== Signal filtrlari ==="
input bool     InpUseExtreme      = true;    // Narx haqiqiy ekstremumda bo'lsin (tepada BUY, pastda SELL yo'q)
input int      InpExtLookback     = 40;      // Ekstremum: necha bar ichidagi eng baland/past
input int      InpExtRecent       = 8;       // Ekstremum oxirgi necha barda bo'lgan bo'lsin
input bool     InpUseSL           = true;    // Stop-loss (xato signal yopiladi, yangisiga yo'l ochiladi)
input double   InpSLATR           = 0.5;     // SL: quti ekstremumidan ATR x narida
input int      InpAtrLen          = 14;      // ATR davri

input group "=== Ko'rinish ==="
input int      InpHistoryBars     = 1500;    // Tarixda nechta bar uchun signal/statistika
input bool     InpDrawBoxes       = true;    // Qutilarni chizish
input int      InpBoxBars         = 4;       // Quti necha barni qamrasin
input int      InpBoxExtend       = 3;       // Qutini o'ngga necha bar cho'zish
input bool     InpDrawStages      = false;   // B.E/TP1/TP2/TP3 yozuvlarini chizish (yopiq - panelni band qilmasin)
input bool     InpShowStats       = false;   // "Signal N | B.E/TP foizlari" statistika yozuvini korsatish
input double   InpHistScale       = 1.5;     // Gistogramma masshtabi
input double   InpHistMax         = 12.0;    // Gistogramma maksimal balandligi
input color    InpSellColor       = clrRed;
input color    InpBuyColor        = clrLimeGreen;

input group "=== Ogohlantirish ==="
input bool     InpAlert           = true;    // Terminal Alert
input bool     InpPush            = false;   // Telefonga push
input bool     InpStageAlerts     = true;    // B.E / TP bosqichlarida ham xabar

//============================ BUFFERS ==============================//
double BufFast[], BufSlow[], BufHist[], BufHistClr[], BufBuy[], BufSell[];
double B1[], B2[], B3[];   // hisob-kitob uchun

string PFX = "IBOSC_";

//============================= STATE ===============================//
int      g_lastProcessed = -1;  // oxirgi qayta ishlangan yopilgan bar
int      g_dir   = 0;           // 1 = buy faol, -1 = sell faol, 0 = yo'q
int      g_stage = 0;           // 0=kirish, 1=B.E, 2=TP1, 3=TP2, 4=TP3
double   g_entry = 0.0;
double   g_sl    = 0.0;
datetime g_lastAlertTime = 0;

// statistika
int    s_signals = 0;
int    s_hit[4];       // B.E, TP1, TP2, TP3 ga yetganlar
int    s_pos[4];       // shu bosqichda narx bo'yicha foydada bo'lganlar
double s_pts[4];       // shu bosqichdagi jami punkt
int    s_sl = 0;       // stop-loss bilan yopilganlar

//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpPDS<2 || InpEmaLen<1 || InpTriggerLen<1 || InpChannelLen<1 ||
      InpAverageLen<1 || InpSignalLen<1 || InpBoxBars<1 || InpHistoryBars<50 ||
      InpExtLookback<2 || InpExtRecent<1 || InpExtRecent>InpExtLookback || InpAtrLen<1 || InpSLATR<0 ||
      !(InpSellTP3 < InpSellTP2 && InpSellTP2 < InpSellTP1 && InpSellTP1 < InpSellBE && InpSellBE <= InpSellZone) ||
      !(InpBuyZone <= InpBuyBE && InpBuyBE < InpBuyTP1 && InpBuyTP1 < InpBuyTP2 && InpBuyTP2 < InpBuyTP3))
     {
      Print("Parametrlar noto'g'ri: davrlar musbat, darajalar tartibli bo'lishi kerak");
      return(INIT_PARAMETERS_INCORRECT);
     }

   SetIndexBuffer(0, BufFast,    INDICATOR_DATA);
   SetIndexBuffer(1, BufSlow,    INDICATOR_DATA);
   SetIndexBuffer(2, BufHist,    INDICATOR_DATA);
   SetIndexBuffer(3, BufHistClr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4, BufBuy,     INDICATOR_DATA);
   SetIndexBuffer(5, BufSell,    INDICATOR_DATA);
   SetIndexBuffer(6, B1,         INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, B2,         INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, B3,         INDICATOR_CALCULATIONS);

   PlotIndexSetInteger(3, PLOT_ARROW, 233);
   PlotIndexSetInteger(4, PLOT_ARROW, 234);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   int warm = WarmBars();
   for(int p=0; p<5; p++) PlotIndexSetInteger(p, PLOT_DRAW_BEGIN, warm);

   //--- darajalar
   double lv[13];
   lv[0]=MathMin(InpSellZone+3.46,100.0); lv[1]=InpSellZone; lv[2]=InpSellBE; lv[3]=InpSellTP1;
   lv[4]=InpSellTP2; lv[5]=InpSellTP3; lv[6]=50.0; lv[7]=InpBuyTP3; lv[8]=InpBuyTP2;
   lv[9]=InpBuyTP1; lv[10]=InpBuyBE; lv[11]=InpBuyZone; lv[12]=MathMax(InpBuyZone-3.15,0.0);
   string tx[13] = {"FULL SELL NOW","SELL ZONE","B.E","TP1","TP2","TP3","",
                    "TP3","TP2","TP1","B.E","FULL BUY NOW","BUY 100%"};
   IndicatorSetInteger(INDICATOR_LEVELS, 13);
   for(int k=0; k<13; k++)
     {
      IndicatorSetDouble(INDICATOR_LEVELVALUE, k, lv[k]);
      IndicatorSetString(INDICATOR_LEVELTEXT, k, tx[k]);
      color c = (k<6) ? InpSellColor : (k==6 ? clrGray : InpBuyColor);
      IndicatorSetInteger(INDICATOR_LEVELCOLOR, k, c);
      IndicatorSetInteger(INDICATOR_LEVELSTYLE, k, (k==1 || k==11) ? STYLE_SOLID : STYLE_DOT);
     }

   IndicatorSetString(INDICATOR_SHORTNAME,
      InpMode==OSC_DSS ? "IndibotOsc (DSS)" : "IndibotOsc (WaveTrend)");
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, PFX);
   ChartRedraw();
  }

//=========================== YORDAMCHI =============================//
int WarmBars()
  {
   int w = (InpMode==OSC_DSS) ? InpPDS*2 + InpEmaLen*3 + InpTriggerLen*2 + 5
                              : InpChannelLen*3 + InpAverageLen*3 + InpSignalLen + 5;
   return(MathMax(w, MathMax(InpExtLookback, InpAtrLen) + 2));
  }

double Ema(const double val, const double prev, const int per)
  {
   return(prev + (2.0/(per+1.0))*(val-prev));
  }

double Clamp(const double v)
  {
   return(MathMax(0.0, MathMin(100.0, v)));
  }

double RangeATR(const int i, const double &high[], const double &low[])
  {
   double s=0; int n=0;
   for(int k=i; k>i-InpAtrLen && k>=0; k--){ s+=high[k]-low[k]; n++; }
   return(n>0 ? s/n : 0.0);
  }

// true = oxirgi InpExtRecent bar ichida InpExtLookback barlik eng past (buy) / eng baland (sell) bo'lgan
bool AtExtreme(const int i, const bool buy, const double &high[], const double &low[])
  {
   int fromAll = MathMax(0, i-InpExtLookback+1);
   int fromRec = MathMax(0, i-InpExtRecent+1);
   double recent = buy ? low[fromRec] : high[fromRec];
   for(int k=fromRec; k<=i; k++) recent = buy ? MathMin(recent,low[k]) : MathMax(recent,high[k]);
   double all = recent;
   for(int k=fromAll; k<=i; k++) all = buy ? MathMin(all,low[k]) : MathMax(all,high[k]);
   return(buy ? recent<=all : recent>=all);
  }

void ResetState()
  {
   g_lastProcessed = -1;
   g_dir = 0; g_stage = 0; g_entry = 0.0;
   s_signals = 0; s_sl = 0; g_sl = 0.0;
   ArrayInitialize(s_hit, 0);
   ArrayInitialize(s_pos, 0);
   ArrayInitialize(s_pts, 0.0);
  }

void Notify(const string msg)
  {
   if(InpAlert) Alert(msg);
   if(InpPush)  SendNotification(msg);
   Print(msg);
  }

//======================= OSSILLYATOR HISOBI ========================//
void CalcBar(const int i, const double &high[], const double &low[], const double &close[])
  {
   if(InpMode==OSC_DSS)
     {
      int from = MathMax(0, i-InpPDS+1);
      double hh=high[from], ll=low[from];
      for(int k=from+1; k<=i; k++){ hh=MathMax(hh,high[k]); ll=MathMin(ll,low[k]); }
      double sto1 = (hh>ll) ? (close[i]-ll)/(hh-ll)*100.0 : 50.0;

      B1[i] = (i==0) ? sto1 : Ema(sto1, B1[i-1], InpEmaLen);

      double xh=B1[from], xl=B1[from];
      for(int k=from+1; k<=i; k++){ xh=MathMax(xh,B1[k]); xl=MathMin(xl,B1[k]); }
      double sto2 = (xh>xl) ? (B1[i]-xl)/(xh-xl)*100.0 : 50.0;

      BufFast[i] = (i==0) ? sto2 : Ema(sto2, BufFast[i-1], InpEmaLen);
      BufSlow[i] = (i==0) ? BufFast[i] : Ema(BufFast[i], BufSlow[i-1], InpTriggerLen);
     }
   else
     {
      double ap = (high[i]+low[i]+close[i])/3.0;
      if(i==0){ B1[i]=ap; B2[i]=0.0; B3[i]=0.0; }
      else
        {
         B1[i] = Ema(ap, B1[i-1], InpChannelLen);                    // esa
         B2[i] = Ema(MathAbs(ap-B1[i]), B2[i-1], InpChannelLen);     // d
         double ci = (B2[i]>0) ? (ap-B1[i])/(0.015*B2[i]) : 0.0;
         B3[i] = Ema(ci, B3[i-1], InpAverageLen);                    // wt1
        }
      double s=0; int c=0;
      for(int k=0; k<InpSignalLen && i-k>=0; k++){ s+=B3[i-k]; c++; }
      double wt2 = s/c;
      BufFast[i] = Clamp(50.0 + B3[i]*InpWTScale);
      BufSlow[i] = Clamp(50.0 + wt2  *InpWTScale);
     }

   double diff = BufFast[i]-BufSlow[i];
   BufHist[i]    = MathMin(MathAbs(diff)*InpHistScale, InpHistMax);
   BufHistClr[i] = (diff>=0) ? 0 : 1;
   BufBuy[i]  = EMPTY_VALUE;
   BufSell[i] = EMPTY_VALUE;
  }

//============================ CHIZISH ==============================//
void DrawBox(const int i, const bool buy, const int win, const datetime &time[],
             const double &high[], const double &low[])
  {
   if(!InpDrawBoxes) return;
   int from = MathMax(0, i-InpBoxBars+1);
   double hh=high[from], ll=low[from], rng=0;
   for(int k=from; k<=i; k++){ hh=MathMax(hh,high[k]); ll=MathMin(ll,low[k]); rng+=high[k]-low[k]; }
   rng /= (i-from+1);

   datetime t1 = time[from];
   datetime t2 = time[i] + PeriodSeconds()*InpBoxExtend;
   color    col = buy ? InpBuyColor : InpSellColor;
   string   id  = (string)(long)time[i];

   string nm = PFX+"BOX_"+id;
   double top = buy ? ll+rng : hh;
   double bot = buy ? ll     : hh-rng;
   if(ObjectCreate(0, nm, OBJ_RECTANGLE, 0, t1, top, t2, bot))
     {
      ObjectSetInteger(0, nm, OBJPROP_COLOR, col);
      ObjectSetInteger(0, nm, OBJPROP_FILL, true);
      ObjectSetInteger(0, nm, OBJPROP_BACK, true);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
     }

   if(win>0)
     {
      string ns = PFX+"SBOX_"+id;
      double st = buy ? InpBuyBE : 100.0;
      double sb = buy ? 0.0      : InpSellBE;
      if(ObjectCreate(0, ns, OBJ_RECTANGLE, win, t1, st, t2, sb))
        {
         ObjectSetInteger(0, ns, OBJPROP_COLOR, col);
         ObjectSetInteger(0, ns, OBJPROP_FILL, true);
         ObjectSetInteger(0, ns, OBJPROP_BACK, true);
         ObjectSetInteger(0, ns, OBJPROP_SELECTABLE, false);
        }
     }
  }

void DrawStageText(const int win, const datetime t, const double level,
                   const string label, const double pts)
  {
   if(!InpDrawStages || win<=0) return;
   string nm = PFX+"ST_"+label+"_"+(string)(long)t;
   if(!ObjectCreate(0, nm, OBJ_TEXT, win, t, level)) return;
   ObjectSetString(0, nm, OBJPROP_TEXT, StringFormat("%s %+.0f", label, pts));
   ObjectSetString(0, nm, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, 7);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, pts>0 ? clrLimeGreen : clrTomato);
   ObjectSetInteger(0, nm, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
  }

void DrawStats(const int win)
  {
   string nm = PFX+"STATS";
   if(!InpShowStats || win<=0)
     {
      ObjectDelete(0, nm);
      return;
     }
   if(ObjectFind(0, nm)<0)
     {
      ObjectCreate(0, nm, OBJ_LABEL, win, 0, 0);
      ObjectSetInteger(0, nm, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, nm, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
      ObjectSetInteger(0, nm, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, nm, OBJPROP_YDISTANCE, 15);
      ObjectSetString(0, nm, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, clrSilver);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
     }
   string s = StringFormat("Signal %d | SL %.0f%%", s_signals, s_signals>0 ? 100.0*s_sl/s_signals : 0.0);
   string names[4] = {"B.E","TP1","TP2","TP3"};
   for(int k=0; k<4; k++)
     {
      double pctHit = s_signals>0 ? 100.0*s_hit[k]/s_signals : 0.0;
      double avgPts = s_hit[k]>0 ? s_pts[k]/s_hit[k] : 0.0;
      double pctPos = s_hit[k]>0 ? 100.0*s_pos[k]/s_hit[k] : 0.0;
      s += StringFormat(" | %s %.0f%% (o'rt %+.0f pt, foyda %.0f%%)", names[k], pctHit, avgPts, pctPos);
     }
   ObjectSetString(0, nm, OBJPROP_TEXT, s);
  }

//================= BITTA YOPILGAN BARNI QAYTA ISHLASH ===============//
void ProcessBar(const int i, const bool live, const int win, const datetime &time[],
                const double &high[], const double &low[], const double &close[])
  {
   string names[4] = {"B.E","TP1","TP2","TP3"};

   //--- 0) stop-loss: narx signalga qarshi ketdi -> signal xato, yopamiz
   if(g_dir!=0 && InpUseSL)
     {
      bool   be    = (g_stage>=2);                 // TP1 dan keyin stop kirish narxida (B.E)
      double slNow = be ? g_entry : g_sl;
      bool hit = (g_dir<0) ? (high[i] >= slNow) : (low[i] <= slNow);
      if(hit)
        {
         double pts = (g_dir<0 ? g_entry-slNow : slNow-g_entry)/_Point;
         if(!be) s_sl++;
         DrawStageText(win, time[i], BufFast[i], be ? "B.E" : "SL", pts);
         if(live && InpStageAlerts)
            Notify(StringFormat("%s %s: %s %s yopildi | %+.0f pt", _Symbol,
                   StringSubstr(EnumToString((ENUM_TIMEFRAMES)_Period),7), g_dir<0?"SELL":"BUY",
                   be ? "B.E" : "SL", pts));
         g_dir = 0;
        }
     }

   //--- 1) faol pozitsiya bosqichlari (ossillyator darajalari bo'yicha)
   if(g_dir!=0)
     {
      double lv[4];
      if(g_dir<0){ lv[0]=InpSellBE; lv[1]=InpSellTP1; lv[2]=InpSellTP2; lv[3]=InpSellTP3; }
      else       { lv[0]=InpBuyBE;  lv[1]=InpBuyTP1;  lv[2]=InpBuyTP2;  lv[3]=InpBuyTP3;  }

      while(g_stage<4)
        {
         double L = lv[g_stage];
         bool reached = (g_dir<0) ? (BufFast[i] <= L) : (BufFast[i] >= L);
         if(!reached) break;

         double pts = (g_dir<0 ? g_entry-close[i] : close[i]-g_entry)/_Point;
         s_hit[g_stage]++;
         s_pts[g_stage] += pts;
         if(pts>0) s_pos[g_stage]++;
         DrawStageText(win, time[i], L, names[g_stage], pts);

         if(live && InpStageAlerts)
            Notify(StringFormat("%s %s: %s %s | narx %s | %+.0f pt",
                   _Symbol, StringSubstr(EnumToString((ENUM_TIMEFRAMES)_Period),7),
                   g_dir<0?"SELL":"BUY", names[g_stage],
                   DoubleToString(close[i],_Digits), pts));
         g_stage++;
        }
      if(g_stage>=4) g_dir=0;   // TP3 -> pozitsiya tugadi
     }

   //--- 2) yangi signal: ekstremal zonada kesishish
   bool crossDown = (BufFast[i-1] >= BufSlow[i-1] && BufFast[i] < BufSlow[i]);
   bool crossUp   = (BufFast[i-1] <= BufSlow[i-1] && BufFast[i] > BufSlow[i]);
   bool sell = crossDown && MathMax(BufFast[i-1], BufSlow[i-1]) >= InpSellZone;
   bool buy  = crossUp   && MathMin(BufFast[i-1], BufSlow[i-1]) <= InpBuyZone;

   // shu yo'nalishda faol pozitsiya bo'lsa, qo'shimcha kirish (averaging) yo'q
   if(sell && g_dir<0) sell = false;
   if(buy  && g_dir>0) buy  = false;

   // narx ekstremumda bo'lmasa signal yo'q (masalan, tepadagi konsolidatsiyada BUY chiqmasin)
   if(InpUseExtreme)
     {
      if(buy  && !AtExtreme(i, true,  high, low)) buy  = false;
      if(sell && !AtExtreme(i, false, high, low)) sell = false;
     }
   if(!sell && !buy) return;

   int dir = buy ? 1 : -1;
   g_dir = dir; g_stage = 0; g_entry = close[i];

   // SL: signal atrofidagi barlarning ekstremumi + ATR zaxira
   int fromB = MathMax(0, i-InpBoxBars+1);
   double ext = buy ? low[fromB] : high[fromB];
   for(int k=fromB; k<=i; k++) ext = buy ? MathMin(ext,low[k]) : MathMax(ext,high[k]);
   double atr = RangeATR(i, high, low);
   g_sl = buy ? ext - atr*InpSLATR : ext + atr*InpSLATR;
   s_signals++;

   if(buy)  BufBuy[i]  = MathMax(BufSlow[i]-6.0, 1.0);
   else     BufSell[i] = MathMin(BufSlow[i]+6.0, 99.0);
   DrawBox(i, buy, win, time, high, low);

   if(live && time[i]!=g_lastAlertTime)
     {
      g_lastAlertTime = time[i];
      Notify(StringFormat("%s %s: INDIBOT %s @ %s | osc %.1f",
             _Symbol, StringSubstr(EnumToString((ENUM_TIMEFRAMES)_Period),7),
             buy?"BUY":"SELL", DoubleToString(close[i],_Digits), BufFast[i]));
     }
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[], const double &close[],
                const long &tick_volume[], const long &volume[], const int &spread[])
  {
   int warm = WarmBars();
   if(rates_total < warm+10) return(0);

   // Barcha massivlar ODDIY tartibda: 0 = eng eski bar
   ArraySetAsSeries(time,false); ArraySetAsSeries(high,false);
   ArraySetAsSeries(low,false);  ArraySetAsSeries(close,false);

   int start = (prev_calculated>1) ? prev_calculated-1 : 0;
   if(start==0)
     {
      ResetState();
      ObjectsDeleteAll(0, PFX);
     }

   //--- ossillyator (joriy bar ham, u faqat ko'rinish uchun)
   for(int i=start; i<rates_total; i++)
      CalcBar(i, high, low, close);

   //--- signal va bosqichlar FAQAT yopilgan barlarda (repaint yo'q)
   int win       = ChartWindowFind();
   int lastClosed= rates_total-2;
   int histFrom  = MathMax(warm, rates_total-InpHistoryBars);
   int from      = MathMax(g_lastProcessed+1, histFrom);
   bool live     = (prev_calculated>0);

   for(int i=MathMax(from,1); i<=lastClosed; i++)
     {
      ProcessBar(i, live, win, time, high, low, close);
      g_lastProcessed = i;
     }

   DrawStats(win);
   return(rates_total);
  }
//+------------------------------------------------------------------+
