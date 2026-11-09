//+------------------------------------------------------------------+
//|                                                   Overlord.mq5   |
//|  TradingView "Overlord Terminal [pandich] v3" (Pine v6) ning MT5  |
//|  nusxasi. Asl "GOLD MONSTER Overlord V4" kodi yopiq - bu pandich  |
//|  qayta tiklagan versiya, foydaliligi tekshirilmagan.              |
//|  Repaint yoq: signal va struktura faqat yopilgan barda.           |
//|  Asl skriptdagi panel olib tashlangan.                            |
//+------------------------------------------------------------------+
#property copyright "Overlord (pandich) - MT5"
#property version   "1.10"
#property indicator_chart_window
#property indicator_buffers 28
#property indicator_plots   10

#property indicator_label1  "Cloud"
#property indicator_type1   DRAW_FILLING
#property indicator_color1  C'0,45,50',C'55,10,28'

#property indicator_label2  "Upper Horizon"
#property indicator_type2   DRAW_COLOR_LINE
#property indicator_color2  C'60,60,60',C'0,100,115',C'105,15,45'
#property indicator_width2  1

#property indicator_label3  "Lower Horizon"
#property indicator_type3   DRAW_COLOR_LINE
#property indicator_color3  C'60,60,60',C'0,100,115',C'105,15,45'
#property indicator_width3  1

#property indicator_label4  "Quantum Core Line"
#property indicator_type4   DRAW_COLOR_LINE
#property indicator_color4  clrGray,C'0,229,255',C'233,30,99'
#property indicator_width4  4

#property indicator_label5  "Trailing"
#property indicator_type5   DRAW_COLOR_LINE
#property indicator_color5  C'0,230,118',C'255,23,68'
#property indicator_width5  2

#property indicator_label6  "BUY"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  C'0,230,118'
#property indicator_width6  3

#property indicator_label7  "SELL"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  C'255,23,68'
#property indicator_width7  3

#property indicator_label8  "Swing High"
#property indicator_type8   DRAW_ARROW
#property indicator_color8  C'41,98,255'
#property indicator_width8  1

#property indicator_label9  "Swing Low"
#property indicator_type9   DRAW_ARROW
#property indicator_color9  C'41,98,255'
#property indicator_width9  1

// shamlar ATAYLAB oxirgi chizma: oldida tursa, keyingi strelkalar buferlari siljib ketgan edi
#property indicator_label10 "Bar Color"
#property indicator_type10  DRAW_COLOR_CANDLES
#property indicator_color10 C'0,230,118',C'255,23,68'

enum ENUM_CORE_MA { CORE_ALMA=0, CORE_HMA=1, CORE_EMA=2 };
enum ENUM_BARMODE { BAR_CANDLE=0,   // Sham bo'yicha (neon)
                    BAR_TREND=1,    // Struktura bo'yicha
                    BAR_OFF=2 };    // O'chiq
enum ENUM_SIGTEXT { TXT_VIDEO=0,    // BUY / SELL
                    TXT_QUANTUM=1,  // QUANTUM BUY / SELL
                    TXT_NONE=2 };   // Yozuvsiz

//============================= INPUTS ==============================//
input group "=== SIGNALLIB CONFIG ==="
input int    InpZoneLen  = 30;     // HIGH LOWER ZONE: ekstremum shuncha barning eng past/baland nuqtasi bolsin
input int    InpCandZ    = 5;      // CANDLES ZONES: sving uchun chapdagi barlar
input int    InpMoveZ    = 5;      // MOVEMENT ZONE: ikki BUY/SELL orasidagi eng kam bar

input group "=== Asosiy parametrlar ==="
input int    InpAtrLen   = 14;     // ATR davri (Horizon uchun)
input int    InpCoreLen  = 36;     // Core Line uzunligi
input double InpCoreOff  = 0.95;   // Core Line: ALMA offset
input int    InpEmaFast  = 50;     // EMA tez (filtr uchun)
input int    InpEmaSlow  = 200;    // EMA sekin (filtr uchun)
input double InpHorK     = 1.15;   // Horizon = Core +/- ATR x shu

input group "=== Chiziq va bulut ==="
input ENUM_CORE_MA InpMaType = CORE_ALMA;  // Core Line silliqlash turi
input bool   InpShowCloud = true;          // Bulutni korsatish
input color  InpColUp     = C'0,229,255';  // Chiziq: osish (bullish)
input color  InpColDn     = C'233,30,99';  // Chiziq: tushish (bearish)
input ENUM_BARMODE InpBarMode = BAR_CANDLE; // Sham rangi

input group "=== Struktura va signallar ==="
input int    InpSwRight   = 3;      // Sving: ongdagi barlar (signal shuncha bar keyin tasdiqlanadi)
input bool   InpShowStruct= true;   // BOS / CHoCH chiziq va yozuvlari
input bool   InpShowRev   = true;   // QUANTUM REVERSAL yozuvlari
input bool   InpShowDots  = true;   // Svinglardagi doirachalar
input bool   InpShowSig   = true;   // BUY / SELL strelkalari
input ENUM_SIGTEXT InpSigText = TXT_VIDEO; // BUY / SELL yozuvi
input bool   InpSigTrend  = false;  // BUY/SELL faqat struktura yonalishida
input bool   InpUseEma    = false;  // BUY/SELL faqat EMA 50/200 yonalishida

input group "=== Trailing chiziq (Supertrend) ==="
input bool   InpShowST    = false;  // Korsatish
input int    InpStLen     = 10;     // ATR davri
input double InpStMult    = 2.5;    // ATR koeffitsienti

input group "=== Ranglar ==="
input color  InpColBuy    = C'0,230,118';   // Buy neon
input color  InpColSell   = C'255,23,68';   // Sell neon
input color  InpColDot    = C'41,98,255';   // Doirachalar

input group "=== Korinish va ogohlantirish ==="
input int    InpHistoryBars = 2000; // Tarixda nechta bar uchun belgilar chizilsin
input bool   InpAlert     = true;   // Terminal Alert
input bool   InpPush      = false;  // Telefonga push

//============================ BUFFERS ==============================//
// Chizma buferlari HAMMA hisoblash buferlaridan OLDIN bolishi shart
double BufFillA[], BufFillB[];
double BufUp[], BufUpClr[], BufDn[], BufDnClr[], BufCore[], BufCoreClr[];
double BufSt[], BufStClr[];
double BufBuy[], BufSell[], BufDotH[], BufDotL[];
double BufO[], BufH[], BufL[], BufC[], BufCandClr[];
double Atr[], AtrSt[], E1[], E2[], StU[], StL[], StDir[], StateB[], HmaRaw[];

const double ALMA_SIGMA = 6.0;   // Pine'dagi ta.alma(..., 6)
string PFX = "OVL_";

int      g_warm = 0, g_sigFrom = 0;
int      g_lastProcessed = -1;
int      g_state = 0;                 // 1 osish, -1 tushish, 0 hali aniqlanmagan
double   g_swHi = 0, g_swLo = 0;
int      g_swHiX = -1, g_swLoX = -1;
bool     g_swHiOk = false, g_swLoOk = false;
int      g_lastSig = -1;
double   g_target = 0;
datetime g_lastAlert = 0;

//+------------------------------------------------------------------+
color Dim(const color c, const double k)
  {
   int r = (int)(((int)c       & 0xFF)*k);
   int g = (int)((((int)c>>8)  & 0xFF)*k);
   int b = (int)((((int)c>>16) & 0xFF)*k);
   return((color)(r | (g<<8) | (b<<16)));
  }

int OnInit()
  {
   if(InpZoneLen<2 || InpCandZ<1 || InpMoveZ<0 || InpAtrLen<1 || InpCoreLen<2 ||
      InpEmaFast<1 || InpEmaSlow<1 || InpSwRight<1 || InpStLen<1 || InpHistoryBars<50)
     {
      Print("Overlord: parametrlar notogri");
      return(INIT_PARAMETERS_INCORRECT);
     }

   SetIndexBuffer(0,  BufFillA,   INDICATOR_DATA);
   SetIndexBuffer(1,  BufFillB,   INDICATOR_DATA);
   SetIndexBuffer(2,  BufUp,      INDICATOR_DATA);
   SetIndexBuffer(3,  BufUpClr,   INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4,  BufDn,      INDICATOR_DATA);
   SetIndexBuffer(5,  BufDnClr,   INDICATOR_COLOR_INDEX);
   SetIndexBuffer(6,  BufCore,    INDICATOR_DATA);
   SetIndexBuffer(7,  BufCoreClr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(8,  BufSt,      INDICATOR_DATA);
   SetIndexBuffer(9,  BufStClr,   INDICATOR_COLOR_INDEX);
   SetIndexBuffer(10, BufBuy,     INDICATOR_DATA);
   SetIndexBuffer(11, BufSell,    INDICATOR_DATA);
   SetIndexBuffer(12, BufDotH,    INDICATOR_DATA);
   SetIndexBuffer(13, BufDotL,    INDICATOR_DATA);
   SetIndexBuffer(14, BufO,       INDICATOR_DATA);
   SetIndexBuffer(15, BufH,       INDICATOR_DATA);
   SetIndexBuffer(16, BufL,       INDICATOR_DATA);
   SetIndexBuffer(17, BufC,       INDICATOR_DATA);
   SetIndexBuffer(18, BufCandClr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(19, Atr,        INDICATOR_CALCULATIONS);
   SetIndexBuffer(20, AtrSt,      INDICATOR_CALCULATIONS);
   SetIndexBuffer(21, E1,         INDICATOR_CALCULATIONS);
   SetIndexBuffer(22, E2,         INDICATOR_CALCULATIONS);
   SetIndexBuffer(23, StU,        INDICATOR_CALCULATIONS);
   SetIndexBuffer(24, StL,        INDICATOR_CALCULATIONS);
   SetIndexBuffer(25, StDir,      INDICATOR_CALCULATIONS);
   SetIndexBuffer(26, StateB,     INDICATOR_CALCULATIONS);
   SetIndexBuffer(27, HmaRaw,     INDICATOR_CALCULATIONS);

   for(int p=0; p<10; p++) PlotIndexSetDouble(p, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   // ranglar - sozlamalardan (bulut va Horizon chiziqlari xiraroq)
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, Dim(InpColUp, 0.20));
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, Dim(InpColDn, 0.22));
   for(int p=1; p<=2; p++)
     {
      PlotIndexSetInteger(p, PLOT_LINE_COLOR, 0, C'60,60,60');
      PlotIndexSetInteger(p, PLOT_LINE_COLOR, 1, Dim(InpColUp, 0.45));
      PlotIndexSetInteger(p, PLOT_LINE_COLOR, 2, Dim(InpColDn, 0.45));
     }
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, 0, clrGray);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, 1, InpColUp);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, 2, InpColDn);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, 0, InpColBuy);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, 1, InpColSell);
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, 0, InpColBuy);
   PlotIndexSetInteger(6, PLOT_LINE_COLOR, 0, InpColSell);
   PlotIndexSetInteger(7, PLOT_LINE_COLOR, 0, InpColDot);
   PlotIndexSetInteger(8, PLOT_LINE_COLOR, 0, InpColDot);
   PlotIndexSetInteger(9, PLOT_LINE_COLOR, 0, InpColBuy);
   PlotIndexSetInteger(9, PLOT_LINE_COLOR, 1, InpColSell);

   // yozuv shamning ozi yonida, strelka esa yozuvning narigi tomonida
   int arrShift = (InpSigText==TXT_NONE) ? 12 : 26;
   PlotIndexSetInteger(5, PLOT_ARROW, 233);   PlotIndexSetInteger(5, PLOT_ARROW_SHIFT,  arrShift);
   PlotIndexSetInteger(6, PLOT_ARROW, 234);   PlotIndexSetInteger(6, PLOT_ARROW_SHIFT, -arrShift);
   PlotIndexSetInteger(7, PLOT_ARROW, 161);   PlotIndexSetInteger(7, PLOT_ARROW_SHIFT,  -6);
   PlotIndexSetInteger(8, PLOT_ARROW, 161);   PlotIndexSetInteger(8, PLOT_ARROW_SHIFT,   6);

   if(!InpShowCloud)         PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);
   if(!InpShowST)            PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_NONE);
   if(!InpShowSig)         { PlotIndexSetInteger(5, PLOT_DRAW_TYPE, DRAW_NONE); PlotIndexSetInteger(6, PLOT_DRAW_TYPE, DRAW_NONE); }
   if(!InpShowDots)        { PlotIndexSetInteger(7, PLOT_DRAW_TYPE, DRAW_NONE); PlotIndexSetInteger(8, PLOT_DRAW_TYPE, DRAW_NONE); }
   if(InpBarMode==BAR_OFF)   PlotIndexSetInteger(9, PLOT_DRAW_TYPE, DRAW_NONE);

   int sq = (int)MathFloor(MathSqrt(InpCoreLen));
   int coreFrom = (InpMaType==CORE_ALMA) ? InpCoreLen-1 :
                  (InpMaType==CORE_HMA)  ? InpCoreLen-1 + sq-1 : 0;
   g_warm    = MathMax(coreFrom, InpAtrLen-1);
   g_sigFrom = MathMax(g_warm, MathMax(InpCandZ, InpZoneLen-1)) + InpSwRight;

   for(int p=0; p<4; p++) PlotIndexSetInteger(p, PLOT_DRAW_BEGIN, g_warm);
   PlotIndexSetInteger(4, PLOT_DRAW_BEGIN, InpStLen);

   IndicatorSetString(INDICATOR_SHORTNAME, "Overlord");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, PFX);
  }

//=========================== YORDAMCHI =============================//
double TrueRange(const int i, const double &high[], const double &low[], const double &close[])
  {
   if(i==0) return(high[0]-low[0]);
   return(MathMax(high[i]-low[i], MathMax(MathAbs(high[i]-close[i-1]), MathAbs(low[i]-close[i-1]))));
  }

// Pine ta.atr = RMA(TR): birinchi qiymat oddiy ortacha, keyin Wilder silliqlash
void CalcAtr(double &out[], const int len, const int i,
             const double &high[], const double &low[], const double &close[])
  {
   if(i<len-1) { out[i]=EMPTY_VALUE; return; }
   if(i==len-1 || out[i-1]==EMPTY_VALUE)
     {
      double s=0;
      for(int k=i-len+1; k<=i; k++) s += TrueRange(k, high, low, close);
      out[i] = s/len;
      return;
     }
   out[i] = (out[i-1]*(len-1) + TrueRange(i, high, low, close))/len;
  }

double Wma(const double &src[], const int len, const int i)
  {
   double s=0, w=0;
   for(int k=0; k<len; k++) { double wt=len-k; s += src[i-k]*wt; w += wt; }
   return(s/w);
  }

double Alma(const double &src[], const int len, const double off, const double sigma, const int i)
  {
   double m = off*(len-1), s = len/sigma, norm=0, sum=0;
   for(int k=0; k<len; k++)
     {
      double w = MathExp(-((k-m)*(k-m))/(2.0*s*s));
      norm += w;
      sum  += src[i-(len-1-k)]*w;
     }
   return(sum/norm);
  }

bool IsPivotHigh(const int p, const double &high[])
  {
   if(p-InpCandZ<0) return(false);
   for(int k=1; k<=InpCandZ;   k++) if(high[p-k] >  high[p]) return(false);
   for(int k=1; k<=InpSwRight; k++) if(high[p+k] >= high[p]) return(false);
   return(true);
  }

bool IsPivotLow(const int p, const double &low[])
  {
   if(p-InpCandZ<0) return(false);
   for(int k=1; k<=InpCandZ;   k++) if(low[p-k] <  low[p]) return(false);
   for(int k=1; k<=InpSwRight; k++) if(low[p+k] <= low[p]) return(false);
   return(true);
  }

double Highest(const double &a[], const int p, const int len)
  {
   double v=a[p];
   for(int k=MathMax(0,p-len+1); k<p; k++) v=MathMax(v,a[k]);
   return(v);
  }

double Lowest(const double &a[], const int p, const int len)
  {
   double v=a[p];
   for(int k=MathMax(0,p-len+1); k<p; k++) v=MathMin(v,a[k]);
   return(v);
  }

void Notify(const string msg)
  {
   if(InpAlert) Alert(msg);
   if(InpPush)  SendNotification(msg);
   Print(msg);
  }

void PutText(const string name, const datetime t, const double price, const string txt,
             const color c, const ENUM_ANCHOR_POINT anchor)
  {
   if(ObjectFind(0,name)>=0) return;
   ObjectCreate(0, name, OBJ_TEXT, 0, t, price);
   ObjectSetString (0, name, OBJPROP_TEXT, txt);
   ObjectSetString (0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

void PutLevel(const string name, const datetime t1, const datetime t2, const double price, const color c)
  {
   if(ObjectFind(0,name)>=0) return;
   ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

void ResetState()
  {
   g_lastProcessed = -1;
   g_state = 0;
   g_swHi = 0;  g_swLo = 0;
   g_swHiX = -1; g_swLoX = -1;
   g_swHiOk = false; g_swLoOk = false;
   g_lastSig = -1;
   g_target = 0;
  }

//--- bitta bar uchun barcha seriyalar (holatga bogliq ranglardan tashqari)
void CalcSeries(const int i, const double &open[], const double &high[],
                const double &low[], const double &close[])
  {
   CalcAtr(Atr,   InpAtrLen, i, high, low, close);
   CalcAtr(AtrSt, InpStLen,  i, high, low, close);
   double a1 = 2.0/(InpEmaFast+1.0), a2 = 2.0/(InpEmaSlow+1.0);
   E1[i] = (i==0) ? close[0] : E1[i-1] + a1*(close[i]-E1[i-1]);
   E2[i] = (i==0) ? close[0] : E2[i-1] + a2*(close[i]-E2[i-1]);

   //--- Quantum Core Line
   double core = EMPTY_VALUE;
   int len = InpCoreLen;
   if(InpMaType==CORE_ALMA)
     {
      if(i>=len-1) core = Alma(close, len, InpCoreOff, ALMA_SIGMA, i);
     }
   else if(InpMaType==CORE_HMA)
     {
      int half = len/2, sq = (int)MathFloor(MathSqrt(len));
      HmaRaw[i] = (i>=len-1) ? 2.0*Wma(close, half, i) - Wma(close, len, i) : EMPTY_VALUE;
      if(i>=len-1+sq-1) core = Wma(HmaRaw, sq, i);
     }
   else
     {
      double a = 2.0/(len+1.0);
      core = (i==0 || BufCore[i-1]==EMPTY_VALUE) ? close[i] : BufCore[i-1] + a*(close[i]-BufCore[i-1]);
     }
   BufCore[i] = core;
   bool ok = (core!=EMPTY_VALUE && Atr[i]!=EMPTY_VALUE);
   BufUp[i] = ok ? core + InpHorK*Atr[i] : EMPTY_VALUE;
   BufDn[i] = ok ? core - InpHorK*Atr[i] : EMPTY_VALUE;

   //--- Trailing (Pine ta.supertrend)
   if(AtrSt[i]==EMPTY_VALUE)
     {
      StU[i]=EMPTY_VALUE; StL[i]=EMPTY_VALUE; StDir[i]=1; BufSt[i]=EMPTY_VALUE; BufStClr[i]=1;
     }
   else
     {
      double hl2 = (high[i]+low[i])/2.0;
      double ub = hl2 + InpStMult*AtrSt[i], lb = hl2 - InpStMult*AtrSt[i];
      int dir = 1;
      if(i>0 && AtrSt[i-1]!=EMPTY_VALUE)
        {
         double pu = StU[i-1], pl = StL[i-1];
         lb = (lb>pl || close[i-1]<pl) ? lb : pl;
         ub = (ub<pu || close[i-1]>pu) ? ub : pu;
         if((int)StDir[i-1]==1) dir = (close[i]>ub) ? -1 : 1;
         else                   dir = (close[i]<lb) ?  1 : -1;
        }
      StU[i]=ub; StL[i]=lb; StDir[i]=dir;
      BufSt[i]    = (dir==-1) ? lb : ub;
      BufStClr[i] = (dir<0) ? 0 : 1;
     }

   //--- sham ranglari uchun OHLC (rangi trend rejimida keyinroq holatdan qoyiladi)
   if(InpBarMode==BAR_OFF)
     { BufO[i]=EMPTY_VALUE; BufH[i]=EMPTY_VALUE; BufL[i]=EMPTY_VALUE; BufC[i]=EMPTY_VALUE; BufCandClr[i]=0; }
   else
     {
      BufO[i]=open[i]; BufH[i]=high[i]; BufL[i]=low[i]; BufC[i]=close[i];
      BufCandClr[i] = (close[i]>=open[i]) ? 0 : 1;
     }

   BufBuy[i]=EMPTY_VALUE; BufSell[i]=EMPTY_VALUE; BufDotH[i]=EMPTY_VALUE; BufDotL[i]=EMPTY_VALUE;
  }

//--- holatga bogliq ranglar: Core/Horizon chiziqlari, bulut, trend rejimidagi shamlar
void ApplyStateColors(const int i)
  {
   int st = (int)StateB[i];
   int ci = (st==1) ? 1 : ((st==-1) ? 2 : 0);
   BufCoreClr[i]=ci; BufUpClr[i]=ci; BufDnClr[i]=ci;

   // DRAW_FILLING ikki rangni A>B / A<B ga qarab tanlaydi - holatga qarab joyini almashtiramiz
   if(st==0 || BufUp[i]==EMPTY_VALUE) { BufFillA[i]=EMPTY_VALUE; BufFillB[i]=EMPTY_VALUE; }
   else if(st==1)                     { BufFillA[i]=BufUp[i];    BufFillB[i]=BufDn[i]; }
   else                               { BufFillA[i]=BufDn[i];    BufFillB[i]=BufUp[i]; }

   if(InpBarMode==BAR_TREND)
     {
      if(st==0) { BufO[i]=EMPTY_VALUE; BufH[i]=EMPTY_VALUE; BufL[i]=EMPTY_VALUE; BufC[i]=EMPTY_VALUE; }
      else        BufCandClr[i] = (st==1) ? 0 : 1;
     }
  }

//--- bitta YOPILGAN bar: sving, BUY/SELL, BOS/CHoCH (Pine'dagi barstate.isconfirmed bloki)
void ProcessBar(const int i, const bool draw, const bool live, const datetime &time[],
                const double &high[], const double &low[], const double &close[])
  {
   int  p = i - InpSwRight;              // sving bari (Pine: offset = -swRight)
   bool gapOk = (g_lastSig<0) || (i - g_lastSig >= InpMoveZ);
   bool sigBuy=false, sigSell=false, revUp=false, revDn=false;

   if(IsPivotHigh(p, high))
     {
      double ph = high[p];
      g_swHi = ph; g_swHiX = p; g_swHiOk = true;
      bool trOk  = !InpSigTrend || g_state==-1;
      bool emaOk = !InpUseEma   || E1[i] < E2[i];
      if(gapOk && BufUp[p]!=EMPTY_VALUE && ph > BufUp[p] && ph >= Highest(high, p, InpZoneLen) && trOk && emaOk)
        { sigSell=true; g_target=ph; g_lastSig=i; }
      if(draw && !(sigSell && InpShowSig)) BufDotH[p] = high[p];   // signal svingida strelka bor
     }
   if(IsPivotLow(p, low))
     {
      double pl = low[p];
      g_swLo = pl; g_swLoX = p; g_swLoOk = true;
      bool trOk  = !InpSigTrend || g_state==1;
      bool emaOk = !InpUseEma   || E1[i] > E2[i];
      if(gapOk && BufDn[p]!=EMPTY_VALUE && pl < BufDn[p] && pl <= Lowest(low, p, InpZoneLen) && trOk && emaOk)
        { sigBuy=true; g_target=pl; g_lastSig=i; }
      if(draw && !(sigBuy && InpShowSig)) BufDotL[p] = low[p];
     }

   if(g_swHiOk && close[i] > g_swHi)
     {
      g_swHiOk = false;
      string kind = (g_state==-1) ? "CHoCH" : "BOS";
      revUp   = (g_state!=1);
      g_state = 1;
      if(draw && InpShowStruct && g_swHiX>=0)
        {
         string id = (string)(long)time[i];
         PutLevel(PFX+"LU_"+id, time[g_swHiX], time[i], g_swHi, InpColBuy);
         PutText (PFX+"TU_"+id, time[(g_swHiX+i)/2], g_swHi, kind, InpColBuy, ANCHOR_LOWER);
        }
      if(draw && InpShowRev && revUp)
         PutText(PFX+"RU_"+(string)(long)time[i], time[i], low[i]-Atr[i],
                 "QUANTUM REVERSAL BULLISH", InpColBuy, ANCHOR_UPPER);
     }
   if(g_swLoOk && close[i] < g_swLo)
     {
      g_swLoOk = false;
      string kind = (g_state==1) ? "CHoCH" : "BOS";
      revDn   = (g_state!=-1);
      g_state = -1;
      if(draw && InpShowStruct && g_swLoX>=0)
        {
         string id = (string)(long)time[i];
         PutLevel(PFX+"LD_"+id, time[g_swLoX], time[i], g_swLo, InpColSell);
         PutText (PFX+"TD_"+id, time[(g_swLoX+i)/2], g_swLo, kind, InpColSell, ANCHOR_LOWER);
        }
      if(draw && InpShowRev && revDn)
         PutText(PFX+"RD_"+(string)(long)time[i], time[i], high[i]+Atr[i],
                 "QUANTUM REVERSAL BEARISH", InpColSell, ANCHOR_LOWER);
     }

   if(draw && InpShowSig)
     {
      // yozuv narx birligida emas, shamning ozi chetiga yopishtiriladi (masshtabga bogliq emas)
      string pre = (InpSigText==TXT_QUANTUM) ? "QUANTUM " : "";
      if(sigBuy)
        {
         BufBuy[p] = low[p];
         if(InpSigText!=TXT_NONE)
            PutText(PFX+"SB_"+(string)(long)time[p], time[p], low[p], pre+"BUY", InpColBuy, ANCHOR_UPPER);
        }
      if(sigSell)
        {
         BufSell[p] = high[p];
         if(InpSigText!=TXT_NONE)
            PutText(PFX+"SS_"+(string)(long)time[p], time[p], high[p], pre+"SELL", InpColSell, ANCHOR_LOWER);
        }
     }

   if(live && time[i]!=g_lastAlert && (sigBuy || sigSell || revUp || revDn))
     {
      g_lastAlert = time[i];
      string tf = StringSubstr(EnumToString((ENUM_TIMEFRAMES)_Period), 7);
      if(sigBuy || sigSell)
         Notify(StringFormat("Overlord %s %s: %s | ekstremum %s", _Symbol, tf,
                (sigBuy ? "BUY" : "SELL"), DoubleToString(g_target, _Digits)));
      if(revUp || revDn)
         Notify(StringFormat("Overlord %s %s: QUANTUM REVERSAL %s @ %s", _Symbol, tf,
                (revUp ? "BULLISH" : "BEARISH"), DoubleToString(close[i], _Digits)));
     }
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[], const double &close[],
                const long &tick_volume[], const long &volume[], const int &spread[])
  {
   if(rates_total < g_sigFrom + 10) return(0);

   // Barcha massivlar ODDIY tartibda: 0 = eng eski bar
   ArraySetAsSeries(time,false);  ArraySetAsSeries(open,false);
   ArraySetAsSeries(high,false);  ArraySetAsSeries(low,false);
   ArraySetAsSeries(close,false);

   int start = (prev_calculated>1) ? prev_calculated-1 : 0;
   if(start==0)
     {
      ResetState();
      ObjectsDeleteAll(0, PFX);
     }

   for(int i=start; i<rates_total; i++) CalcSeries(i, open, high, low, close);

   //--- holat mashinasi faqat YOPILGAN barlarda, ketma-ket (repaint yoq)
   int  lastClosed = rates_total-2;
   int  histFrom   = rates_total - InpHistoryBars;
   bool live       = (prev_calculated>0);
   for(int i=g_lastProcessed+1; i<=lastClosed; i++)
     {
      if(i>=g_sigFrom) ProcessBar(i, i>=histFrom, live, time, high, low, close);
      StateB[i] = g_state;
      ApplyStateColors(i);
      g_lastProcessed = i;
     }

   // hali yopilmagan joriy bar - oxirgi tasdiqlangan holat rangida
   StateB[rates_total-1] = g_state;
   ApplyStateColors(rates_total-1);
   return(rates_total);
  }
//+------------------------------------------------------------------+
