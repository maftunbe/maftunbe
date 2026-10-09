//+------------------------------------------------------------------+
//|                                            TradeSupervisor.mq5   |
//|  Sizning EA ngiz savdo ochganda chartdagi indikatorlarni soraydi  |
//|  va ular savdoni tasdiqlaganmi yoki qarshimi - xabar beradi.      |
//|                                                                   |
//|  Savdo yopilganda natijani yozib boradi va statistika yigadi:     |
//|    "3 ta tasdiq bilan: 18 savdo, WR 61%"                          |
//|    "0-1 tasdiq bilan: 25 savdo, WR 28%"                           |
//|                                                                   |
//|  Sizning EA ngizning kodiga tegilmaydi. Bu alohida EA.            |
//+------------------------------------------------------------------+
#property copyright "TradeSupervisor"
#include <Trade\Trade.mqh>
#property version   "2.70"

enum EIndMode
  {
   MODE_DIR    = 0,   // Bufer: +1 osish / -1 tushish (TrendMatrix, SuperTrend)
   MODE_ARROWS = 1,   // Ikki bufer: BUY va SELL strelkalari
   MODE_LEVEL  = 2    // Ossillyator: yuqori va quyi chegara
  };

enum EAIProvider
  {
   AI_ANTHROPIC = 0,  // api.anthropic.com/v1/messages
   AI_OPENAI    = 1   // api.openai.com/v1/chat/completions (OpenAI-moslashgan boshqa provayderlar ham)
  };

//============================= INPUTS ==============================//
input group "=== Indikator 1 ==="
input bool     InpUse1   = true;
input string   InpName1  = "SuperTrendLiquidity";  // Fayl nomi (.ex5 siz)
input EIndMode InpMode1  = MODE_DIR;
input int      InpBufA1  = 5;      // Asosiy bufer (DIR yoki BUY)
input int      InpBufB1  = 0;      // Ikkinchi bufer (faqat ARROWS: SELL)
input double   InpHi1    = 0;      // LEVEL: yuqori chegara
input double   InpLo1    = 0;      // LEVEL: quyi chegara
input double   InpWeight1= 1.0;    // Vazn (ovoz salmogi, 0 = eslatma uchun, hisobga olinmaydi)

input group "=== Indikator 2 ==="
input bool     InpUse2   = true;
input string   InpName2  = "TrendMatrix_MTF";
input EIndMode InpMode2  = MODE_DIR;
input int      InpBufA2  = 0;
input int      InpBufB2  = 0;
input double   InpHi2    = 0;
input double   InpLo2    = 0;
input double   InpWeight2= 1.0;    // Vazn (ovoz salmogi)

input group "=== Indikator 3 ==="
input bool     InpUse3   = true;
input string   InpName3  = "IndibotOsc";
input EIndMode InpMode3  = MODE_ARROWS;
input int      InpBufA3  = 4;      // BUY strelka buferi
input int      InpBufB3  = 5;      // SELL strelka buferi
input double   InpHi3    = 0;
input double   InpLo3    = 0;
input double   InpWeight3= 1.0;    // Vazn (ovoz salmogi)

input group "=== Indikator 4 ==="
input bool     InpUse4   = false;
input string   InpName4  = "";
input EIndMode InpMode4  = MODE_DIR;
input int      InpBufA4  = 0;
input int      InpBufB4  = 0;
input double   InpHi4    = 0;
input double   InpLo4    = 0;
input double   InpWeight4= 1.0;    // Vazn (ovoz salmogi)

input group "=== Umumiy ==="
input int      InpLookback   = 3;      // ARROWS rejimi: signal necha bar ichida bolgani hisoblansin
input long     InpMagicWatch = -1;     // Faqat shu magic (-1 = hamma savdolar)
input bool     InpUsePush    = true;   // MT5 mobilga push
input bool     InpUseAlert   = false;  // Terminalda Alert
input bool     InpUseTelegram= true;   // Telegram xabarlari
input string   InpBotToken   = "";  // Telegram bot tokeni (BotFather'dan). Bu yerga yozmang - EA sozlamalarida kiriting!
input string   InpChatId     = "";        // Telegram chat id
input bool     InpJournal    = true;   // CSV jurnal (MQL5\\Files)

input group "=== Qoshimcha bitim (averaging) - EHTIYOT BOLING ==="
input bool   InpAddEnable   = false;   // Zarardagi savdoga qoshimcha ochish
input double InpAddTrigger  = 50.0;    // Har necha USD zararda yangi bitim
input int    InpMaxAdds     = 8;       // Maksimal qoshimcha bitimlar soni
input double InpAddLot      = 0;       // Lot (0 = asl bitim bilan bir xil)
input bool   InpAddConfirm  = false;   // Indikator tasdigi talab qilinsinmi
input int    InpAddPauseSec = 60;      // Ikki qoshimcha orasidagi min vaqt (soniya)
input double InpAddStopDay  = 300.0;   // Kunlik zarar shu USD ga yetsa - toxtatish
input double InpAddMinEquity= 200.0;   // Ekviti shundan pastga tushsa - toxtatish

input group "=== Telegram orqali qolda savdo ==="
input bool   InpAllowTrade  = true;    // /buy va /sell buyruqlariga ruxsat
input double InpDefLot      = 1.0;     // Standart lot (/buy desa shu ishlatiladi)
input double InpMaxManualLot= 5.0;     // Bitta buyruqda maksimal lot
input double InpManualSLATR = 0;       // SL (ATR x). 0 = SL qoyilmaydi
input double InpManualTPATR = 0;       // TP (ATR x). 0 = TP qoyilmaydi

input group "=== Moslashuvchan vaznlar ==="
input bool   InpAdaptive       = false;  // Indikator vaznini ozining tarixiy aniqligiga qarab avtomatik moslashtirish
input int    InpAdaptMinTrades = 10;     // Vazn ozgarishi uchun kamida shuncha "mos kelgan" savdo kerak
input double InpAdaptSensitivity=1.0;    // Moslashish kuchi (0 = ozgarmaydi, 1 = normal, 2 = kuchli)
input double InpAdaptMinMult   = 0.2;    // Minimal multiplikator (asl vaznga nisbatan)
input double InpAdaptMaxMult   = 2.0;    // Maksimal multiplikator (asl vaznga nisbatan)

input group "=== AI tahlili (ixtiyoriy, pullik API) ==="
input bool        InpUseAI     = false;  // Savdo ochilganda AI'dan qisqa izoh sorash
input EAIProvider  InpAIProvider = AI_ANTHROPIC;  // AI provayderi
input string       InpAIApiKey  = "";    // API kalit. Bu yerga yozmang - EA sozlamalarida kiriting!
input string       InpAIModel   = "";    // Model nomi (masalan: claude-3-5-haiku-20241022 yoki gpt-4o-mini)
input string       InpAIUrl     = "";    // Maxsus URL (bosh = provayderning standart manzili)

input group "=== Chart skrinshoti ==="
input bool     InpSendShot   = true;   // Savdo ochilganda chart rasmini yuborish
input bool     InpShotOnClose= false;  // Savdo yopilganda ham rasm yuborish
input long     InpShotChart  = 0;      // Qaysi chart (0 = EA turgan chart). ID jurnalda yoziladi
input int      InpShotW      = 1280;   // Rasm eni (piksel)
input int      InpShotH      = 720;    // Rasm boyi (piksel)
input int      InpPollSec    = 3;      // Telegram buyruqlarini necha soniyada tekshirish
input bool     InpPanel      = true;   // Chartda statistika paneli
input int      InpPanelX     = 10;
input int      InpPanelY     = 22;
input int      InpPanelFont  = 9;

//============================== STATE ==============================//
struct IndSlot
  {
   bool     use;
   string   name;
   EIndMode mode;
   int      bufA, bufB;
   double   hi, lo;
   double   weight;      // joriy (moslashgan bolishi mumkin) ovoz salmogi
   double   baseWeight;  // InpWeightN - foydalanuvchi bergan asl vazn
   int      handle;
   int      vote;        // oxirgi hisoblangan ovoz
  };
IndSlot g_ind[4];

struct TradeRec
  {
   long     posId;
   int      dir;          // 1 BUY, -1 SELL
   int      agree;        // nechta indikator tasdiqladi
   int      total;        // nechta indikator ishladi
   int      votes[4];     // har indikatorning ochilish paytidagi ovozi
   double   wscore;        // vaznli xulosa skori (-1..+1)
   string   detail;
   double   price;
   datetime time;
  };
TradeRec g_rec[];

int    s_cnt[5], s_win[5];      // tasdiqlar soni boyicha (0..4)
int    s_indAgrCnt[4], s_indAgrWin[4];   // indikator "mos kelgan" savdolari
int    s_indAgnCnt[4], s_indAgnWin[4];   // indikator "qarshi bolgan" savdolari
double s_indAgrSum[4], s_indAgnSum[4];
double g_grossWin = 0, g_grossLoss = 0;
bool     g_muted      = false;     // Telegram /mute bilan yoqiladi
CTrade   g_trade;
bool     g_addOn      = false;     // Telegram /add_on bilan yoqiladi
int      g_addsBuy    = 0, g_addsSell = 0;
datetime g_lastAdd    = 0;
double   g_dayStart   = 0;
int      g_day        = -1;
long     g_tgOffset   = 0;
ulong    g_seen[];                 // qayta ishlangan bitimlar (takrorlanmasligi uchun)

bool AlreadySeen(const ulong deal)
  {
   for(int i=ArraySize(g_seen)-1; i>=0; i--) if(g_seen[i]==deal) return(true);
   int n=ArraySize(g_seen);
   if(n>=200) { for(int i=0;i<n-1;i++) g_seen[i]=g_seen[i+1]; g_seen[n-1]=deal; }
   else { ArrayResize(g_seen, n+1, 64); g_seen[n]=deal; }
   return(false);
  }
double s_sum[5];
string PFX = "SUP_";

//+------------------------------------------------------------------+
void SetSlot(const int i, const bool use, const string name, const EIndMode m,
             const int a, const int b, const double hi, const double lo, const double weight)
  {
   g_ind[i].use=use; g_ind[i].name=name; g_ind[i].mode=m;
   g_ind[i].bufA=a; g_ind[i].bufB=b; g_ind[i].hi=hi; g_ind[i].lo=lo;
   g_ind[i].baseWeight = (weight>0 ? weight : 1.0);
   g_ind[i].weight = g_ind[i].baseWeight;
   g_ind[i].handle=INVALID_HANDLE; g_ind[i].vote=0;
  }

int OnInit()
  {
   SetSlot(0, InpUse1, InpName1, InpMode1, InpBufA1, InpBufB1, InpHi1, InpLo1, InpWeight1);
   SetSlot(1, InpUse2, InpName2, InpMode2, InpBufA2, InpBufB2, InpHi2, InpLo2, InpWeight2);
   SetSlot(2, InpUse3, InpName3, InpMode3, InpBufA3, InpBufB3, InpHi3, InpLo3, InpWeight3);
   SetSlot(3, InpUse4, InpName4, InpMode4, InpBufA4, InpBufB4, InpHi4, InpLo4, InpWeight4);

   int ok = 0;
   for(int i=0; i<4; i++)
     {
      if(!g_ind[i].use || StringLen(g_ind[i].name)<2) { g_ind[i].use=false; continue; }
      g_ind[i].handle = iCustom(_Symbol, _Period, g_ind[i].name);
      if(g_ind[i].handle == INVALID_HANDLE)
        {
         PrintFormat("Indikator yuklanmadi: %s. Nomini va kompilyatsiyani tekshiring.", g_ind[i].name);
         g_ind[i].use = false;
        }
      else ok++;
     }
   if(ok==0) { Print("Birorta indikator yuklanmadi"); return(INIT_FAILED); }

   if(InpUseTelegram)
     {
      if(StringFind(InpBotToken,"BU_YERGA")>=0 || StringFind(InpChatId,"BU_YERGA")>=0 ||
         StringLen(InpBotToken)<20 || StringLen(InpChatId)<3)
        {
         Print("Telegram yoqilgan, lekin token yoki chat id kiritilmagan. ",
               "EA sozlamalarida InpBotToken va InpChatId ni toldiring.");
         return(INIT_PARAMETERS_INCORRECT);
        }
      Print("Telegram yoqilgan. WebRequest royxatida https://api.telegram.org borligini tekshiring.");
     }

   ArrayInitialize(s_cnt,0); ArrayInitialize(s_win,0); ArrayInitialize(s_sum,0.0);
   ArrayInitialize(s_indAgrCnt,0); ArrayInitialize(s_indAgrWin,0); ArrayInitialize(s_indAgrSum,0.0);
   ArrayInitialize(s_indAgnCnt,0); ArrayInitialize(s_indAgnWin,0); ArrayInitialize(s_indAgnSum,0.0);
   g_grossWin=0; g_grossLoss=0; g_muted=false;
   g_trade.SetExpertMagicNumber(777001);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_addOn = InpAddEnable;
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   g_day = dt.day; g_dayStart = AccountInfoDouble(ACCOUNT_BALANCE);
   if(InpAddEnable)
      Print("DIQQAT: averaging yoqilgan. Maks ", InpMaxAdds, " qoshimcha, har ", InpAddTrigger, " USD zararda.");
   EventSetTimer(MathMax(1, InpPollSec));
   // bir xil EA ikkinchi chartda ham ishlayotgan bolsa - ogohlantiramiz
   int copies = 0;
   long c2 = ChartFirst();
   while(c2 >= 0)
     {
      if(ChartGetInteger(c2, CHART_IS_OBJECT)==false && ChartSymbol(c2)!="")
        {
         string nm = ChartGetString(c2, CHART_EXPERT_NAME);
         if(StringFind(nm, "TradeSupervisor")>=0) copies++;
        }
      c2 = ChartNext(c2);
     }
   if(copies > 1)
      Print("DIQQAT: TradeSupervisor ", copies, " ta chartda ishlayapti. Xabarlar takrorlanadi. ",
            "Faqat bittasini qoldiring.");

   long ch = ChartFirst();
   while(ch >= 0)
     {
      PrintFormat("Chart ID %I64d : %s %s%s", ch, ChartSymbol(ch),
                  EnumToString((ENUM_TIMEFRAMES)ChartPeriod(ch)),
                  (ch==ChartID() ? "  <- EA shu yerda" : ""));
      ch = ChartNext(ch);
     }
   RegisterCommands();
   SendKeyboard("TradeSupervisor tayyor. Quyidagi tugmalardan foydalaning.");
   PrintFormat("TradeSupervisor: %d ta indikator yuklandi. Telegram: %s",
               ok, (InpUseTelegram ? "yoqilgan" : "ochirilgan"));
   Send(StringFormat("TradeSupervisor ishga tushdi. Kuzatilayotgan indikatorlar: %d", ok));
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   for(int i=0; i<4; i++) if(g_ind[i].handle!=INVALID_HANDLE) IndicatorRelease(g_ind[i].handle);
   ObjectsDeleteAll(0, PFX);
  }
void OnTick() { }

//=========================== YUBORISH ==============================//
string UrlEncode(const string src)
  {
   string out=""; uchar b[];
   int n = StringToCharArray(src, b, 0, -1, CP_UTF8) - 1;
   for(int i=0; i<n; i++)
     {
      uchar c=b[i];
      if((c>='0'&&c<='9')||(c>='A'&&c<='Z')||(c>='a'&&c<='z')||c=='-'||c=='_'||c=='.'||c=='~')
         out += CharToString(c);
      else out += StringFormat("%%%02X", c);
     }
   return(out);
  }

//=================== CHART SKRINSHOTI =============================//
void AppendStr(char &buf[], const string s)
  {
   uchar t[];
   int n = StringToCharArray(s, t, 0, -1, CP_UTF8) - 1;    // oxirgi 0 ni tashlaymiz
   if(n<=0) return;
   int old = ArraySize(buf);
   ArrayResize(buf, old+n);
   for(int i=0; i<n; i++) buf[old+i] = (char)t[i];
  }

void AppendBytes(char &buf[], const char &src[], const int n)
  {
   int old = ArraySize(buf);
   ArrayResize(buf, old+n);
   for(int i=0; i<n; i++) buf[old+i] = src[i];
  }

// Chart rasmini olib, Telegramga rasm sifatida yuboradi
void SendChartShot(const string caption, const bool force=false)
  {
   if((!InpSendShot && !force) || !InpUseTelegram) return;
   long cid = (InpShotChart>0) ? InpShotChart : ChartID();
   string fname = "TS_shot.png";

   if(!ChartScreenShot(cid, fname, InpShotW, InpShotH, ALIGN_RIGHT))
     { PrintFormat("TELEGRAM: skrinshot olinmadi (%d)", GetLastError()); return; }

   int h = FileOpen(fname, FILE_READ|FILE_BIN);
   if(h==INVALID_HANDLE) { PrintFormat("TELEGRAM: rasm oqilmadi (%d)", GetLastError()); return; }
   int size = (int)FileSize(h);
   char img[];
   ArrayResize(img, size);
   FileReadArray(h, img, 0, size);
   FileClose(h);
   if(size<=0) return;

   string bnd = "MT5Boundary7817";
   char body[];
   ArrayResize(body, 0);
   AppendStr(body, "--"+bnd+"\r\nContent-Disposition: form-data; name=\"chat_id\"\r\n\r\n"+InpChatId+"\r\n");
   AppendStr(body, "--"+bnd+"\r\nContent-Disposition: form-data; name=\"caption\"\r\n\r\n"+caption+"\r\n");
   AppendStr(body, "--"+bnd+"\r\nContent-Disposition: form-data; name=\"photo\"; filename=\""+fname+
                   "\"\r\nContent-Type: image/png\r\n\r\n");
   AppendBytes(body, img, size);
   AppendStr(body, "\r\n--"+bnd+"--\r\n");

   string url = "https://api.telegram.org/bot"+InpBotToken+"/sendPhoto";
   string hdr = "Content-Type: multipart/form-data; boundary="+bnd+"\r\n";
   char res[]; string rh="";
   ResetLastError();
   int code = WebRequest("POST", url, hdr, 10000, body, res, rh);
   if(code == -1)      PrintFormat("TELEGRAM: rasm yuborilmadi, xato %d", GetLastError());
   else if(code != 200) Print("TELEGRAM: rasm javobi ", code, " ", CharArrayToString(res, 0, WHOLE_ARRAY, CP_UTF8));
   else                 Print("TELEGRAM: chart rasmi yuborildi");
  }

void Send(const string text)
  {
   Print("SUPERVISOR: ", text);
   if(g_muted) return;   // /mute yoqilgan - faqat jurnalga yoziladi
   if(InpUseAlert) Alert(text);
   if(InpUsePush)
     {
      string p = (StringLen(text)>250) ? StringSubstr(text,0,250) : text;
      SendNotification(p);
     }
   if(InpUseTelegram && StringLen(InpBotToken)>10)
     {
      string url = "https://api.telegram.org/bot"+InpBotToken+"/sendMessage?chat_id="+InpChatId+
                   "&text="+UrlEncode(text);
      char d[], r[]; string rh="";
      ResetLastError();
      int code = WebRequest("GET", url, "", 7000, d, r, rh);
      if(code == -1)
        {
         int err = GetLastError();
         if(err==4014) Print("TELEGRAM: WebRequest ruxsati yoq. Servis -> Sozlamalar -> Ekspertlar -> ",
                             "WebRequest royxatiga https://api.telegram.org ni qoshing va EA ni qayta yuklang.");
         else          PrintFormat("TELEGRAM: WebRequest xatosi %d", err);
        }
      else if(code != 200)
        {
         string body = CharArrayToString(r, 0, WHOLE_ARRAY, CP_UTF8);
         if(code==401)      Print("TELEGRAM: 401 - token notogri. BotFather dan tokenni qayta nusxalang.");
         else if(code==403) Print("TELEGRAM: 403 - botga Start bosilmagan yoki chat id notogri. ",
                                  "Telegramda botni ochib Start bosing.");
         else if(code==400) Print("TELEGRAM: 400 - chat id notogri. Javob: ", body);
         else               PrintFormat("TELEGRAM: javob kodi %d. Matn: %s", code, body);
        }
      else Print("TELEGRAM: xabar yuborildi");
     }
  }

//====================== INDIKATORNI SOROQ ==========================//
// qaytaradi: +1 osish / BUY, -1 tushish / SELL, 0 neytral
int AskIndicator(const int i)
  {
   if(!g_ind[i].use) return(0);
   double a[], b[];
   ArraySetAsSeries(a,true); ArraySetAsSeries(b,true);

   if(g_ind[i].mode == MODE_DIR)
     {
      if(CopyBuffer(g_ind[i].handle, g_ind[i].bufA, 1, 1, a) < 1) return(0);
      if(a[0]==EMPTY_VALUE) return(0);
      if(a[0] > 0) return(1);
      if(a[0] < 0) return(-1);
      return(0);
     }

   if(g_ind[i].mode == MODE_ARROWS)
     {
      int n = MathMax(1, InpLookback);
      if(CopyBuffer(g_ind[i].handle, g_ind[i].bufA, 1, n, a) < n) return(0);
      if(CopyBuffer(g_ind[i].handle, g_ind[i].bufB, 1, n, b) < n) return(0);
      for(int k=0; k<n; k++)
        {
         bool buy  = (a[k]!=EMPTY_VALUE && a[k]!=0);
         bool sell = (b[k]!=EMPTY_VALUE && b[k]!=0);
         if(buy)  return(1);
         if(sell) return(-1);
        }
      return(0);
     }

   // MODE_LEVEL
   if(CopyBuffer(g_ind[i].handle, g_ind[i].bufA, 1, 1, a) < 1) return(0);
   if(a[0]==EMPTY_VALUE) return(0);
   if(a[0] >= g_ind[i].hi) return(1);
   if(a[0] <= g_ind[i].lo) return(-1);
   return(0);
  }

string VoteText(const int v)
  {
   if(v>0) return("osish/BUY");
   if(v<0) return("tushish/SELL");
   return("neytral");
  }

// Indikatorning "mos kelganda"gi haqiqiy WR'iga qarab vaznini qayta hisoblaydi.
// Yetarli namuna bolmaguncha (InpAdaptMinTrades) asl vazn (baseWeight) saqlanadi.
void RecalcWeight(const int i)
  {
   if(!InpAdaptive || s_indAgrCnt[i] < InpAdaptMinTrades)
     { g_ind[i].weight = g_ind[i].baseWeight; return; }
   double wr   = (double)s_indAgrWin[i]/s_indAgrCnt[i];              // 0..1
   double mult = 1.0 + (wr-0.5)*2.0*InpAdaptSensitivity;             // wr=0.5 -> 1.0
   mult = MathMax(InpAdaptMinMult, MathMin(InpAdaptMaxMult, mult));
   g_ind[i].weight = g_ind[i].baseWeight * mult;
  }

//========================== JURNAL =================================//
void JournalWrite(const string line)
  {
   if(!InpJournal) return;
   int h = FileOpen("TradeSupervisor.csv", FILE_CSV|FILE_ANSI|FILE_READ|FILE_WRITE, ';');
   if(h==INVALID_HANDLE) return;
   FileSeek(h, 0, SEEK_END);
   FileWrite(h, line);
   FileClose(h);
  }

//========================== HISOBOT =================================//
string BuildReport()
  {
   int used=0; for(int i=0;i<4;i++) if(g_ind[i].use) used++;
   int totalTrades=0, totalWin=0; double totalNet=0;
   for(int k=0;k<=4;k++) { totalTrades+=s_cnt[k]; totalWin+=s_win[k]; totalNet+=s_sum[k]; }
   double wr = (totalTrades>0) ? 100.0*totalWin/totalTrades : 0;
   double pf = (g_grossLoss>0) ? g_grossWin/g_grossLoss : (g_grossWin>0 ? 0 : -1);

   string t = "HISOBOT\n";
   t += StringFormat("Jami: %d savdo, WR %.0f%%, natija %+.2f %s\n",
        totalTrades, wr, totalNet, AccountInfoString(ACCOUNT_CURRENCY));
   t += (pf>=0) ? StringFormat("Profit factor: %.2f\n", pf) : "Profit factor: hali zarar yoq\n";

   t += "\n--- Tasdiqlar soni boyicha ---\n";
   bool any=false;
   for(int k=used; k>=0; k--)
     {
      if(s_cnt[k]==0) continue;
      any=true;
      double kwr = 100.0*s_win[k]/s_cnt[k];
      t += StringFormat("%d/%d tasdiq: %d savdo, WR %.0f%%, %+.2f\n", k, used, s_cnt[k], kwr, s_sum[k]);
     }
   if(!any) t += "hali savdo yopilmagan\n";

   t += "\n--- Indikatorlar boyicha ---\n";
   for(int i=0;i<4;i++)
     {
      if(!g_ind[i].use) continue;
      string wtxt = (MathAbs(g_ind[i].weight-g_ind[i].baseWeight)>0.001)
                    ? StringFormat("joriy vazn %.2f, asl %.2f", g_ind[i].weight, g_ind[i].baseWeight)
                    : StringFormat("vazn %.2f", g_ind[i].weight);
      t += g_ind[i].name+" ("+wtxt+"):\n";
      if(s_indAgrCnt[i]>0)
         t += StringFormat("  mos kelganda:  %d savdo, WR %.0f%%, %+.2f\n",
              s_indAgrCnt[i], 100.0*s_indAgrWin[i]/s_indAgrCnt[i], s_indAgrSum[i]);
      else
         t += "  mos kelganda:  malumot yoq\n";
      if(s_indAgnCnt[i]>0)
         t += StringFormat("  qarshi bolganda: %d savdo, WR %.0f%%, %+.2f\n",
              s_indAgnCnt[i], 100.0*s_indAgnWin[i]/s_indAgnCnt[i], s_indAgnSum[i]);
      else
         t += "  qarshi bolganda: malumot yoq\n";
     }
   return(t);
  }

//============================ PANEL ================================//
void Row(const int r, const string txt, const color c)
  {
   string nm = PFX+"R"+IntegerToString(r);
   if(ObjectFind(0,nm)<0)
     {
      ObjectCreate(0,nm,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,nm,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetString (0,nm,OBJPROP_FONT,"Consolas");
      ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nm,OBJPROP_HIDDEN,true);
     }
   ObjectSetInteger(0,nm,OBJPROP_XDISTANCE,InpPanelX);
   ObjectSetInteger(0,nm,OBJPROP_YDISTANCE,InpPanelY + r*(InpPanelFont+6));
   ObjectSetInteger(0,nm,OBJPROP_FONTSIZE,InpPanelFont);
   ObjectSetInteger(0,nm,OBJPROP_COLOR,c);
   ObjectSetString (0,nm,OBJPROP_TEXT,txt);
  }

void DrawPanel()
  {
   if(!InpPanel) return;
   int used=0; for(int i=0;i<4;i++) if(g_ind[i].use) used++;

   Row(0, "TradeSupervisor - EA ni nazorat qilish", C'150,155,165');
   // hozirgi holat: har indikator alohida qatorda
   int row = 1;
   for(int i=0;i<4;i++)
     {
      if(!g_ind[i].use) continue;
      g_ind[i].vote = AskIndicator(i);
      string sig = (g_ind[i].vote>0) ? "BUY" : ((g_ind[i].vote<0) ? "SELL" : "signal yoq");
      color  c   = (g_ind[i].vote>0) ? C'0,200,110' : ((g_ind[i].vote<0) ? C'220,70,80' : C'130,135,145');
      Row(row++, StringFormat("%-26s %s", g_ind[i].name, sig), c);
     }
   Row(row++, StringFormat("%-14s %6s %6s %9s", "tasdiq", "savdo", "WR", "natija"), C'150,155,165');
   for(int k=used; k>=0; k--)
     {
      if(s_cnt[k]==0) continue;
      double wr = 100.0*s_win[k]/s_cnt[k];
      color c = (wr>=50) ? C'0,200,110' : C'220,70,80';
      Row(row++, StringFormat("%d/%d indikator %6d %5.0f%% %+9.2f",
          k, used, s_cnt[k], wr, s_sum[k]), c);
     }
  }

//====================== SAVDO HODISALARI ===========================//
int FindRec(const long posId)
  {
   for(int i=ArraySize(g_rec)-1; i>=0; i--) if(g_rec[i].posId==posId) return(i);
   return(-1);
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal<=0) return;
   if(AlreadySeen(trans.deal)) return;          // bitta bitim - bitta xabar
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol) return;

   long magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   if(InpMagicWatch>=0 && magic!=InpMagicWatch) return;

   long dtype = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
   if(dtype!=DEAL_TYPE_BUY && dtype!=DEAL_TYPE_SELL) return;

   long   entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   long   posId = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   double price = HistoryDealGetDouble (trans.deal, DEAL_PRICE);
   double vol   = HistoryDealGetDouble (trans.deal, DEAL_VOLUME);

   //--- SAVDO OCHILDI: indikatorlarni sorash
   if(entry == DEAL_ENTRY_IN)
     {
      int dir = (dtype==DEAL_TYPE_BUY) ? 1 : -1;
      string dirTxt = (dir>0) ? "BUY" : "SELL";
      int agree=0, against=0, neutral=0, total=0;
      double wAgree=0, wAgainst=0, wTotal=0;
      string lines = "", okList="", badList="", neuList="";
      int votes[4]; ArrayInitialize(votes,0);

      for(int i=0;i<4;i++)
        {
         if(!g_ind[i].use) continue;
         total++;
         int v = AskIndicator(i);
         g_ind[i].vote = v;
         votes[i] = v;

         string sig  = (v>0) ? "BUY" : ((v<0) ? "SELL" : "neytral");
         string mark;
         wTotal += g_ind[i].weight;
         if(v==dir)       { agree++;   wAgree   += g_ind[i].weight; mark = "tasdiqladi";  okList  += g_ind[i].name+" "; }
         else if(v==-dir) { against++; wAgainst += g_ind[i].weight; mark = "QARSHI";      badList += g_ind[i].name+" "; }
         else             { neutral++;                              mark = "signal yoq";  neuList += g_ind[i].name+" "; }

         // har bir indikator alohida qatorda: nomi -> vazni -> signali -> bahosi
         lines += StringFormat("%d) %s (vazn %.1f)\n     signal: %s  (%s)\n", total, g_ind[i].name, g_ind[i].weight, sig, mark);
        }

      double wscore = (wTotal>0) ? (wAgree-wAgainst)/wTotal : 0;   // -1..+1
      string verdict;
      if(wTotal<=0)             verdict = "indikator yoq";
      else if(wscore <= -0.34)  verdict = StringFormat("indikatorlar QARSHI (vaznli skor %+.2f)", wscore);
      else if(wscore >= 0.50)   verdict = StringFormat("indikatorlar KUCHLI MOS (vaznli skor %+.2f)", wscore);
      else if(wscore > 0)       verdict = StringFormat("indikatorlar MOS (vaznli skor %+.2f)", wscore);
      else                      verdict = StringFormat("kuchsiz moslik (vaznli skor %+.2f)", wscore);

      TradeRec rec;
      rec.posId=posId; rec.dir=dir; rec.agree=agree; rec.total=total; rec.wscore=wscore;
      for(int i=0;i<4;i++) rec.votes[i]=votes[i];
      rec.price=price; rec.time=TimeCurrent();
      rec.detail=StringFormat("tasdiq: %s| qarshi: %s| neytral: %s",
                 (okList=="" ? "yoq " : okList), (badList=="" ? "yoq " : badList),
                 (neuList=="" ? "yoq " : neuList));
      int n=ArraySize(g_rec); ArrayResize(g_rec, n+1, 32); g_rec[n]=rec;

      string msg = StringFormat("EA %s ochdi %.2f lot @ %s\n----- INDIKATORLAR -----\n%s-----------------------\nXULOSA: %d tasdiq, %d qarshi, %d signalsiz\n%s",
                   dirTxt, vol, DoubleToString(price,_Digits), lines,
                   agree, against, neutral, verdict);

      if(InpUseAI)
        {
         string aiPrompt = StringFormat(
              "Savdo %s %s %.2f lot @ %s ochildi. %d indikatordan %d tasi tasdiqladi, %d qarshi, "+
              "%d signalsiz, vaznli skor %.2f (-1 kuchli qarshi, +1 kuchli mos). Tafsilot: %s\n"+
              "Faqat 2-3 jumlada, shu savdoning e'tiborga olish kerak bolgan riski yoki jihati haqida "+
              "qisqa, aniq izoh ber. Savdoni ochish yoki yopish haqida buyruq berma - faqat izoh.",
              _Symbol, dirTxt, vol, DoubleToString(price,_Digits), total, agree, against, neutral, wscore, rec.detail);
         string aiNote = AskAI(aiPrompt);
         if(aiNote!="") msg += "\n\n--- AI IZOHI ---\n"+aiNote;
        }
      Send(msg);
      SendChartShot(msg);
      JournalWrite(StringFormat("OPEN;%s;%s;%.2f;%s;%d;%d;%s",
           TimeToString(TimeCurrent()), (dir>0?"BUY":"SELL"), vol,
           DoubleToString(price,_Digits), agree, total, rec.detail));
      return;
     }

   //--- SAVDO YOPILDI: natijani yozamiz
   if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY)
     {
      double net = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                 + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                 + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
      int idx = FindRec(posId);
      int agree = (idx>=0) ? g_rec[idx].agree : 0;
      int total = (idx>=0) ? g_rec[idx].total : 0;
      if(agree>=0 && agree<5)
        {
         s_cnt[agree]++; s_sum[agree]+=net; if(net>=0) s_win[agree]++;
        }
      if(net>=0) g_grossWin+=net; else g_grossLoss+=-net;
      if(idx>=0)
        {
         int dir = g_rec[idx].dir;
         for(int i=0;i<4;i++)
           {
            if(!g_ind[i].use) continue;
            int v = g_rec[idx].votes[i];
            if(v==dir)
              { s_indAgrCnt[i]++; s_indAgrSum[i]+=net; if(net>=0) s_indAgrWin[i]++; }
            else if(v==-dir)
              { s_indAgnCnt[i]++; s_indAgnSum[i]+=net; if(net>=0) s_indAgnWin[i]++; }
            RecalcWeight(i);
           }
        }
      string stat = "";
      if(s_cnt[agree]>0)
         stat = StringFormat("\n%d tasdiqli savdolar: %d ta, WR %.0f%%, jami %+.2f",
                agree, s_cnt[agree], 100.0*s_win[agree]/s_cnt[agree], s_sum[agree]);

      string cmsg = StringFormat("Savdo yopildi: %+.2f %s\nOchilganda tasdiq: %d/%d%s",
                    net, AccountInfoString(ACCOUNT_CURRENCY), agree, total, stat);
      Send(cmsg);
      if(InpShotOnClose) SendChartShot(cmsg);
      JournalWrite(StringFormat("CLOSE;%s;%.2f;%s;%d;%d",
           TimeToString(TimeCurrent()), net, DoubleToString(price,_Digits), agree, total));
      DrawPanel();
     }
  }

//================= QOSHIMCHA BITIM (AVERAGING) =====================//
// Bir yonalishdagi barcha pozitsiyalarning suzuvchi natijasi va jami loti
void DirInfo(const int dir, double &floatPL, double &lots, int &count, double &lastLot)
  {
   floatPL=0; lots=0; count=0; lastLot=0;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      long ty = PositionGetInteger(POSITION_TYPE);
      if((dir>0 && ty!=POSITION_TYPE_BUY) || (dir<0 && ty!=POSITION_TYPE_SELL)) continue;
      floatPL += PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      double v = PositionGetDouble(POSITION_VOLUME);
      lots += v; count++;
      if(lastLot==0) lastLot = v;
     }
  }

double NormLot(double lot)
  {
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(st<=0) st=mn;
   lot = MathFloor(lot/st)*st;
   if(lot<mn) lot=mn;
   if(lot>mx) lot=mx;
   return(NormalizeDouble(lot,8));
  }

void CheckAveraging()
  {
   if(!g_addOn) return;

   // xavfsizlik toxtatgichlari
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double dayPL = eq - g_dayStart;
   if(eq <= InpAddMinEquity)
     { g_addOn=false; Send(StringFormat("AVERAGING TOXTATILDI: ekviti %.2f, chegara %.2f", eq, InpAddMinEquity)); return; }
   if(dayPL <= -InpAddStopDay)
     { g_addOn=false; Send(StringFormat("AVERAGING TOXTATILDI: kunlik zarar %.2f, chegara %.2f", dayPL, InpAddStopDay)); return; }
   if(TimeCurrent()-g_lastAdd < InpAddPauseSec) return;

   for(int dir=1; dir>=-1; dir-=2)
     {
      double pl, lots, lastLot; int cnt;
      DirInfo(dir, pl, lots, cnt, lastLot);
      if(cnt==0) { if(dir>0) g_addsBuy=0; else g_addsSell=0; continue; }

      int adds = (dir>0) ? g_addsBuy : g_addsSell;
      if(adds >= InpMaxAdds) continue;

      // navbatdagi chegara: -50, -100, -150 ...
      double need = -InpAddTrigger*(adds+1);
      if(pl > need) continue;

      if(InpAddConfirm)
        {
         int v=0;
         for(int i=0;i<4;i++) if(g_ind[i].use && AskIndicator(i)==dir) v++;
         if(v==0) continue;
        }

      double lot = (InpAddLot>0) ? InpAddLot : lastLot;
      lot = NormLot(lot);
      bool ok = (dir>0) ? g_trade.Buy(lot, _Symbol, 0, 0, 0, "SUP add")
                        : g_trade.Sell(lot, _Symbol, 0, 0, 0, "SUP add");
      if(ok)
        {
         if(dir>0) g_addsBuy++; else g_addsSell++;
         g_lastAdd = TimeCurrent();
         Send(StringFormat("QOSHIMCHA BITIM: %s %.2f lot\nSuzuvchi zarar: %.2f USD\nQoshimchalar: %d/%d\nJami lot: %.2f",
              (dir>0?"BUY":"SELL"), lot, pl, (dir>0?g_addsBuy:g_addsSell), InpMaxAdds, lots+lot));
        }
      else
         PrintFormat("Qoshimcha bitim ochilmadi: %d %s", g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
     }
  }

//============================ AI TAHLILI ============================//
// JSON matn ichiga xavfsiz joylash uchun maxsus belgilarni escape qiladi
string JsonEscape(const string s)
  {
   string r = s;
   StringReplace(r, "\\", "\\\\");
   StringReplace(r, "\"", "\\\"");
   StringReplace(r, "\r", "");
   StringReplace(r, "\n", "\\n");
   StringReplace(r, "\t", " ");
   return(r);
  }

// JSON javobidan "key":"qiymat" korinishidagi matnni ajratib oladi (\n, \", \\ ni qayta tiklaydi)
string ExtractJsonString(const string &json, const string &key)
  {
   string pat = "\""+key+"\":\"";
   int p = StringFind(json, pat);
   if(p<0) return("");
   p += StringLen(pat);
   int n = StringLen(json);
   string out="";
   while(p<n)
     {
      ushort c = StringGetCharacter(json, p);
      if(c=='\\' && p+1<n)
        {
         ushort c2 = StringGetCharacter(json, p+1);
         if(c2=='n')       out += "\n";
         else if(c2=='"')  out += "\"";
         else if(c2=='\\') out += "\\";
         else               out += CharToString((uchar)c2);
         p += 2;
         continue;
        }
      if(c=='"') break;
      out += CharToString((uchar)c);
      p++;
     }
   return(out);
  }

// LLM (Claude yoki OpenAI-moslashgan) API'ga savol yuboradi, qisqa matn javob qaytaradi.
// Xato bolsa yoki sozlanmagan bolsa - bosh satr qaytaradi (chaqiruvchi shunga qarab oladi).
string AskAI(const string prompt)
  {
   if(!InpUseAI) return("");
   if(StringLen(InpAIApiKey)<10) { Print("AI: API kalit kiritilmagan (InpAIApiKey)"); return(""); }
   if(StringLen(InpAIModel)<2)   { Print("AI: model nomi kiritilmagan (InpAIModel)"); return(""); }

   string url, hdr, body;
   string esc = JsonEscape(prompt);

   if(InpAIProvider==AI_ANTHROPIC)
     {
      url = (StringLen(InpAIUrl)>0) ? InpAIUrl : "https://api.anthropic.com/v1/messages";
      hdr = "content-type: application/json\r\nx-api-key: "+InpAIApiKey+"\r\nanthropic-version: 2023-06-01\r\n";
      body = StringFormat("{\"model\":\"%s\",\"max_tokens\":220,\"messages\":[{\"role\":\"user\",\"content\":\"%s\"}]}",
             InpAIModel, esc);
     }
   else
     {
      url = (StringLen(InpAIUrl)>0) ? InpAIUrl : "https://api.openai.com/v1/chat/completions";
      hdr = "content-type: application/json\r\nAuthorization: Bearer "+InpAIApiKey+"\r\n";
      body = StringFormat("{\"model\":\"%s\",\"max_tokens\":220,\"messages\":[{\"role\":\"user\",\"content\":\"%s\"}]}",
             InpAIModel, esc);
     }

   char reqBody[]; ArrayResize(reqBody,0);
   AppendStr(reqBody, body);
   char res[]; string rh="";
   ResetLastError();
   int code = WebRequest("POST", url, hdr, 20000, reqBody, res, rh);
   if(code==-1)
     {
      int err = GetLastError();
      if(err==4014) PrintFormat("AI: WebRequest ruxsati yoq. Ekspertlar sozlamalarida %s ni royxatga qoshing.", url);
      else          PrintFormat("AI: WebRequest xatosi %d", err);
      return("");
     }
   string resp = CharArrayToString(res, 0, WHOLE_ARRAY, CP_UTF8);
   if(code!=200)
     {
      PrintFormat("AI: javob kodi %d: %s", code, resp);
      return("");
     }
   string text = (InpAIProvider==AI_ANTHROPIC) ? ExtractJsonString(resp,"text") : ExtractJsonString(resp,"content");
   if(text=="") PrintFormat("AI: javobni ajratib bolmadi: %s", resp);
   return(text);
  }

//==================== TELEGRAM BUYRUQLARI ==========================//
void TgSendText(const string t) { Send(t); }

// buyruqdan sonni ajratib oladi: "/buy 0.5" -> 0.5
double CmdNumber(const string cmd, const double def)
  {
   int sp = StringFind(cmd, " ");
   if(sp < 0) return(def);
   string tail = StringSubstr(cmd, sp+1);
   StringTrimLeft(tail); StringTrimRight(tail);
   double v = StringToDouble(tail);
   return(v > 0 ? v : def);
  }

double AtrNow()
  {
   int h = iATR(_Symbol, _Period, 14);
   if(h==INVALID_HANDLE) return(0);
   double a[]; ArraySetAsSeries(a,true);
   double v = (CopyBuffer(h,0,1,1,a)==1) ? a[0] : 0;
   IndicatorRelease(h);
   return(v);
  }

// Telegram orqali bitim ochish
void ManualTrade(const int dir, double lot)
  {
   if(!InpAllowTrade) { Send("Qolda savdo ochirilgan (InpAllowTrade = false)"); return; }
   if(lot > InpMaxManualLot)
     { Send(StringFormat("Lot juda katta: %.2f. Chegara: %.2f", lot, InpMaxManualLot)); return; }
   lot = NormLot(lot);

   double atr = AtrNow();
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double entry = (dir>0) ? ask : bid;
   double sl = 0, tp = 0;
   if(InpManualSLATR>0 && atr>0) sl = (dir>0) ? entry-atr*InpManualSLATR : entry+atr*InpManualSLATR;
   if(InpManualTPATR>0 && atr>0) tp = (dir>0) ? entry+atr*InpManualTPATR : entry-atr*InpManualTPATR;
   if(sl>0) sl = NormalizeDouble(sl,_Digits);
   if(tp>0) tp = NormalizeDouble(tp,_Digits);

   bool ok = (dir>0) ? g_trade.Buy(lot, _Symbol, 0, sl, tp, "TG manual")
                     : g_trade.Sell(lot, _Symbol, 0, sl, tp, "TG manual");
   if(ok)
      Send(StringFormat("Telegram buyrugi bajarildi: %s %.2f lot @ %s%s%s",
           (dir>0?"BUY":"SELL"), lot, DoubleToString(entry,_Digits),
           (sl>0 ? "  SL "+DoubleToString(sl,_Digits) : ""),
           (tp>0 ? "  TP "+DoubleToString(tp,_Digits) : "")));
   else
      Send(StringFormat("Bitim ochilmadi: %d - %s", g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()));
  }

// Pozitsiyalarni yopish: dir 1 = BUY, -1 = SELL, 0 = hammasi
void ManualClose(const int dir)
  {
   int n = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      long ty = PositionGetInteger(POSITION_TYPE);
      if(dir>0 && ty!=POSITION_TYPE_BUY)  continue;
      if(dir<0 && ty!=POSITION_TYPE_SELL) continue;
      if(g_trade.PositionClose(t)) n++;
     }
   Send(StringFormat("Yopildi: %d ta pozitsiya (%s)", n,
        (dir>0 ? "BUY" : (dir<0 ? "SELL" : "hammasi"))));
  }

// Pastki doimiy tugmalar paneli (reply keyboard)
void SendKeyboard(const string text)
  {
   if(!InpUseTelegram) return;
   string kb = "{\"keyboard\":["
               "[\"Holat\",\"Pozitsiyalar\",\"Skrinshot\"],"
               "[\"BUY 1 lot\",\"SELL 1 lot\"],"
               "[\"1-ni yopish\",\"2-ni yopish\",\"3-ni yopish\"],"
               "[\"TP 10\",\"TP 30\",\"TP 50\"],"
               "[\"BUY larni yopish\",\"SELL larni yopish\"],"
               "[\"Hammasini yopish\"],"
               "[\"Hisobot\"],"
               "[\"Averaging ON\",\"Averaging OFF\",\"Yordam\"]"
               "],\"resize_keyboard\":true,\"is_persistent\":true}";
   string url = "https://api.telegram.org/bot"+InpBotToken+"/sendMessage?chat_id="+InpChatId+
                "&text="+UrlEncode(text)+"&reply_markup="+UrlEncode(kb);
   char d[], r[]; string rh="";
   int code = WebRequest("GET", url, "", 7000, d, r, rh);
   if(code==200) Print("TELEGRAM: tugmalar paneli yuborildi");
   else          Print("TELEGRAM: panel yuborilmadi, kod ", code);
  }

// Telegram pastki panelidagi buyruqlar royxatini royxatdan otkazadi
void RegisterCommands()
  {
   if(!InpUseTelegram) return;
   string json = "[";
   json += "{\"command\":\"status\",\"description\":\"Hisob holati\"},";
   json += "{\"command\":\"shot\",\"description\":\"Chart skrinshoti\"},";
   json += "{\"command\":\"buy\",\"description\":\"BUY ochish (/buy 1)\"},";
   json += "{\"command\":\"sell\",\"description\":\"SELL ochish (/sell 1)\"},";
   json += "{\"command\":\"close_buy\",\"description\":\"BUY larni yopish\"},";
   json += "{\"command\":\"close_sell\",\"description\":\"SELL larni yopish\"},";
   json += "{\"command\":\"close_all\",\"description\":\"Hammasini yopish\"},";
   json += "{\"command\":\"add_on\",\"description\":\"Averagingni yoqish\"},";
   json += "{\"command\":\"add_off\",\"description\":\"Averagingni ochirish\"},";
   json += "{\"command\":\"list\",\"description\":\"Pozitsiyalar va natijalar\"},";
   json += "{\"command\":\"report\",\"description\":\"Statistika hisoboti\"},";
   json += "{\"command\":\"ai\",\"description\":\"AI dan savol sorash (/ai savol)\"},";
   json += "{\"command\":\"mute\",\"description\":\"Xabarlarni vaqtincha ochirish\"},";
   json += "{\"command\":\"unmute\",\"description\":\"Xabarlarni qayta yoqish\"},";
   json += "{\"command\":\"menu\",\"description\":\"Tugmalar paneli\"},";
   json += "{\"command\":\"help\",\"description\":\"Buyruqlar royxati\"}]";

   string url = "https://api.telegram.org/bot"+InpBotToken+"/setMyCommands?commands="+UrlEncode(json);
   char d[], r[]; string rh="";
   int code = WebRequest("GET", url, "", 7000, d, r, rh);
   if(code==200) Print("TELEGRAM: buyruqlar menyusi royxatdan otkazildi");
   else          Print("TELEGRAM: menyu royxatdan otmadi, kod ", code);
  }

// ---- pozitsiyalarni tartibli royxatlash (1-raqam = eng eski savdo) ----
int PosTickets(ulong &out[])
  {
   ArrayResize(out,0);
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      int n=ArraySize(out); ArrayResize(out,n+1); out[n]=t;
     }
   int n=ArraySize(out);
   for(int i=0;i<n-1;i++)
      for(int j=0;j<n-1-i;j++)
         if(out[j]>out[j+1]) { ulong tmp=out[j]; out[j]=out[j+1]; out[j+1]=tmp; }
   return(n);
  }

ulong TicketFromArg(const double num)
  {
   ulong list[]; int n = PosTickets(list);
   if(n==0) return(0);
   if(num>=1 && num<=n && num==MathFloor(num)) return(list[(int)num-1]);
   for(int i=0;i<n;i++) if((double)list[i]==num) return(list[i]);
   return(0);
  }

// Inline tugmalar bilan xabar yuborish
void SendWithInline(const string text, const string inlineJson)
  {
   if(!InpUseTelegram) { Print("INLINE: ", text); return; }
   string url = "https://api.telegram.org/bot"+InpBotToken+"/sendMessage?chat_id="+InpChatId+
                "&text="+UrlEncode(text)+"&reply_markup="+UrlEncode(inlineJson);
   char d[], r[]; string rh="";
   int code = WebRequest("GET", url, "", 7000, d, r, rh);
   if(code!=200) Print("TELEGRAM: inline xabar kodi ", code);
  }

void SendPositions()
  {
   ulong list[]; int n = PosTickets(list);
   if(n==0) { Send("Ochiq pozitsiya yoq"); return; }
   string txt = "OCHIQ POZITSIYALAR\n";
   double total = 0;
   for(int i=0;i<n;i++)
     {
      if(!PositionSelectByTicket(list[i])) continue;
      int    dg = (int)SymbolInfoInteger(PositionGetString(POSITION_SYMBOL), SYMBOL_DIGITS);
      double pl = PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      total += pl;
      txt += StringFormat("%d) %s %.2f lot @ %s\n     SL %s | TP %s\n     natija: %+.2f %s\n",
             i+1, (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY ? "BUY" : "SELL"),
             PositionGetDouble(POSITION_VOLUME),
             DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),dg),
             (PositionGetDouble(POSITION_SL)>0 ? DoubleToString(PositionGetDouble(POSITION_SL),dg) : "yoq"),
             (PositionGetDouble(POSITION_TP)>0 ? DoubleToString(PositionGetDouble(POSITION_TP),dg) : "yoq"),
             pl, AccountInfoString(ACCOUNT_CURRENCY));
     }
   txt += StringFormat("-----------------\nJAMI: %+.2f %s\n\nTP qoyish: /tp 2 45  (2-savdoga 45 USD)",
          total, AccountInfoString(ACCOUNT_CURRENCY));

   // har bir savdo uchun alohida yopish tugmasi
   string kb = "{\"inline_keyboard\":[";
   for(int i=0;i<n;i++)
     {
      if(i>0) kb += ",";
      kb += StringFormat("[{\"text\":\"%d-ni yopish\",\"callback_data\":\"close%d\"}]", i+1, i+1);
     }
   kb += ",[{\"text\":\"Hammasini yopish\",\"callback_data\":\"closeall\"}]]}";
   SendWithInline(txt, kb);
  }

void CloseOne(const double num)
  {
   ulong t = TicketFromArg(num);
   if(t==0) { Send("Bunday pozitsiya yoq. /list ni koring."); return; }
   if(!PositionSelectByTicket(t)) return;
   double pl = PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
   if(g_trade.PositionClose(t))
      Send(StringFormat("Yopildi: #%d, natija %+.2f %s", (int)num, pl, AccountInfoString(ACCOUNT_CURRENCY)));
   else
      Send(StringFormat("Yopilmadi: %d - %s", g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()));
  }

// 1 narx birligi necha pul turadi (shu lot uchun)
double MoneyPerPrice(const string sym, const double lot)
  {
   double tv = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   if(tv<=0 || ts<=0 || lot<=0) return(0);
   return(lot*tv/ts);
  }

// Bitta pozitsiyaga TP qoyish (val = USD)
bool SetTpMoney(const ulong t, const double val, string &info)
  {
   if(!PositionSelectByTicket(t)) { info="pozitsiya topilmadi"; return(false); }
   double lot = PositionGetDouble(POSITION_VOLUME);
   double mpp = MoneyPerPrice(PositionGetString(POSITION_SYMBOL), lot);
   if(mpp<=0) { info="pul hisobi aniqlanmadi"; return(false); }
   double dist = val/mpp;
   double op   = PositionGetDouble(POSITION_PRICE_OPEN);
   bool   buy  = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double tp   = NormalizeDouble(buy ? op+dist : op-dist, _Digits);
   double sl   = PositionGetDouble(POSITION_SL);
   if(g_trade.PositionModify(t, sl, tp)) { info=DoubleToString(tp,_Digits); return(true); }
   info = IntegerToString(g_trade.ResultRetcode())+" "+g_trade.ResultRetcodeDescription();
   return(false);
  }

void ModifyOne(const string cmd)
  {
   string parts[];
   int k = StringSplit(cmd, (ushort)StringGetCharacter(" ",0), parts);
   if(k < 2) { Send("Format:\n/tp 30 - hamma savdoga 30 USD\n/tp 2 45 - faqat 2-savdoga 45 USD"); return; }

   // /tp 30  -> hamma ochiq savdoga
   if(k == 2)
     {
      string a0 = parts[1];
      StringReplace(a0,"$",""); StringReplace(a0,"usd","");
      double v = MathAbs(StringToDouble(a0));
      if(v<=0) { Send("Qiymat notogri. Masalan: /tp 30"); return; }
      ulong list[]; int n = PosTickets(list);
      if(n==0) { Send("Ochiq savdo yoq"); return; }
      int done=0; string inf;
      for(int i=0;i<n;i++) if(SetTpMoney(list[i], v, inf)) done++;
      Send(StringFormat("TP qoyildi: %d ta savdoga, har biriga %.0f USD foyda", done, v));
      return;
     }

   ulong t = TicketFromArg(StringToDouble(parts[1]));
   if(t==0) { Send("Pozitsiya topilmadi. Pozitsiyalar tugmasini bosing."); return; }
   if(!PositionSelectByTicket(t)) return;

   string arg = parts[2];
   StringReplace(arg, "$", ""); StringReplace(arg, "usd", "");
   double val = MathAbs(StringToDouble(arg));
   if(val<=0) { Send("Qiymat notogri. Masalan: /tp 2 45"); return; }

   string inf;
   if(SetTpMoney(t, val, inf))
      Send(StringFormat("Savdo %d: TP = %.0f USD foyda\nTP narxi: %s",
           (int)StringToDouble(parts[1]), val, inf));
   else
      Send("Ozgartirilmadi: "+inf);
  }


// Tugmalardagi matnni buyruqqa aylantiradi
string NormalizeCmd(string t)
  {
   StringToLower(t);
   StringTrimLeft(t); StringTrimRight(t);
   if(StringFind(t,"/")==0) return(t);                       // allaqachon buyruq

   if(StringFind(t,"holat")>=0)            return("/status");
   if(StringFind(t,"hisobot")>=0)          return("/report");
   if(StringFind(t,"pozitsiya")>=0)        return("/list");
   if(StringFind(t,"skrinshot")>=0)        return("/shot");
   if(StringFind(t,"yordam")>=0)           return("/help");
   if(StringFind(t,"hammasini yopish")>=0) return("/close_all");
   if(StringFind(t,"buy larni yopish")>=0) return("/close_buy");
   if(StringFind(t,"sell larni yopish")>=0)return("/close_sell");
   if(StringFind(t,"averaging on")>=0)     return("/add_on");
   if(StringFind(t,"averaging off")>=0)    return("/add_off");
   if(StringFind(t,"1-ni yopish")>=0)      return("/close 1");
   if(StringFind(t,"2-ni yopish")>=0)      return("/close 2");
   if(StringFind(t,"3-ni yopish")>=0)      return("/close 3");
   if(StringFind(t,"4-ni yopish")>=0)      return("/close 4");
   if(StringFind(t,"tp ")==0)                     // "TP 30" -> hamma savdoga
     {
      string n = t; StringReplace(n,"tp ","");
      return("/tp "+n);
     }
   if(StringFind(t,"buy")>=0)  return("/buy 1");
   if(StringFind(t,"sell")>=0) return("/sell 1");
   return(t);
  }

void HandleCmd(string raw)
  {
   string cmd = NormalizeCmd(raw);
   if(StringFind(cmd,"/add_on")==0)
     { g_addOn=true;  Send("Averaging YOQILDI. Maks "+IntegerToString(InpMaxAdds)+" qoshimcha."); }
   else if(StringFind(cmd,"/add_off")==0)
     { g_addOn=false; Send("Averaging OCHIRILDI."); }
   else if(StringFind(cmd,"/status")==0)
     {
      double plB,lotB,llB, plS,lotS,llS; int cB,cS;
      DirInfo(1,plB,lotB,cB,llB); DirInfo(-1,plS,lotS,cS,llS);
      Send(StringFormat("HOLAT\nBalans: %.2f  Ekviti: %.2f\nBUY: %d ta, %.2f lot, %+.2f\nSELL: %d ta, %.2f lot, %+.2f\nAveraging: %s (%d/%d BUY, %d/%d SELL)",
           AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_EQUITY),
           cB, lotB, plB, cS, lotS, plS,
           (g_addOn ? "yoqilgan" : "ochirilgan"), g_addsBuy, InpMaxAdds, g_addsSell, InpMaxAdds));
     }
   else if(StringFind(cmd,"/buy")==0)        ManualTrade( 1, CmdNumber(cmd, InpDefLot));
   else if(StringFind(cmd,"/sell")==0)       ManualTrade(-1, CmdNumber(cmd, InpDefLot));
   else if(StringFind(cmd,"/shot")==0 || StringFind(cmd,"/screenshot")==0)
     {
      SendChartShot(StringFormat("Chart skrinshoti  %s  %s",
                    _Symbol, TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)), true);
     }
   else if(StringFind(cmd,"/list")==0 || StringFind(cmd,"/positions")==0) SendPositions();
   else if(StringFind(cmd,"/report")==0)     Send(BuildReport());
   else if(StringFind(cmd,"/ai")==0)
     {
      if(!InpUseAI) { Send("AI ochirilgan. EA sozlamalarida InpUseAI ni yoqing."); }
      else
        {
         int sp = StringFind(cmd," ");
         string question = (sp>=0) ? StringSubstr(cmd,sp+1) : "Joriy savdo holatini qisqacha tahlil qil.";
         double plB,lotB,llB, plS,lotS,llS; int cB,cS;
         DirInfo(1,plB,lotB,cB,llB); DirInfo(-1,plS,lotS,cS,llS);
         string ctx = StringFormat("%s grafigi. Ochiq: BUY %d ta (%.2f lot, %+.2f), SELL %d ta (%.2f lot, %+.2f). Savol: %s",
                      _Symbol, cB,lotB,plB, cS,lotS,plS, question);
         string ans = AskAI(ctx);
         Send(ans!="" ? ans : "AI javob bera olmadi. Sozlamalarni (API kalit, model) tekshiring.");
        }
     }
   else if(StringFind(cmd,"/unmute")==0)     { g_muted=false; Send("Xabarlar qayta yoqildi."); }
   else if(StringFind(cmd,"/mute")==0)       { Send("Xabarlar vaqtincha ochirildi. /unmute bilan qayta yoqasiz."); g_muted=true; }
   else if(StringFind(cmd,"/close_buy")==0)  ManualClose( 1);
   else if(StringFind(cmd,"/close_sell")==0) ManualClose(-1);
   else if(StringFind(cmd,"/close_all")==0)  ManualClose( 0);
   else if(StringFind(cmd,"/close")==0)      CloseOne(CmdNumber(cmd, 0));
   else if(StringFind(cmd,"/tp")==0)         ModifyOne(cmd);
   else if(StringFind(cmd,"/menu")==0)
      SendKeyboard("Tugmalar paneli yangilandi");
   else if(StringFind(cmd,"/help")==0 || StringFind(cmd,"/start")==0)
      SendKeyboard("Buyruqlar:\n/list - pozitsiyalar, har birining foyda/zarari\n/close 1 - 1-pozitsiyani yopish\n/tp 30 - hamma savdoga 30 USD\n/tp 2 45 - faqat 2-savdoga 45 USD\n/close 3 - 3-savdoni yopish\nPozitsiyalar tugmasida har savdoning yopish tugmasi chiqadi\n/be 1 - SL ni kirish narxiga\n/be_all - hammasiga breakeven\n/shot - chart skrinshoti\n/buy 1  - BUY ochish (son = lot)\n/sell 1 - SELL ochish\n/close_buy - BUY larni yopish\n/close_sell - SELL larni yopish\n/close_all - hammasini yopish\n/status - hisob holati\n/report - statistika hisoboti\n/ai savol - AI'dan savol sorash (InpUseAI yoqilgan bolsa)\n/mute, /unmute - xabarlarni vaqtincha ochirish/yoqish\n/add_on, /add_off - averaging\n/menu - panelni qayta chizish");
  }

// Update blokidan "chat":{"id":N...} ni ajratib oladi. Topilmasa 0 qaytaradi.
long ExtractChatId(const string &ans, const int from, const int to)
  {
   int p = StringFind(ans, "\"chat\":{\"id\":", from);
   if(p<0 || (to>=0 && p>=to)) return(0);
   p += 13;
   int e = p, len = StringLen(ans);
   while(e<len)
     {
      ushort ch = StringGetCharacter(ans, e);
      if((ch>='0' && ch<='9') || ch=='-') e++;
      else break;
     }
   if(e<=p) return(0);
   return(StringToInteger(StringSubstr(ans, p, e-p)));
  }

void PollTelegram()
  {
   if(!InpUseTelegram) return;
   string url = "https://api.telegram.org/bot"+InpBotToken+"/getUpdates?timeout=0&limit=5"+
                (g_tgOffset>0 ? "&offset="+IntegerToString(g_tgOffset+1) : "");
   char d[], r[]; string rh="";
   if(WebRequest("GET", url, "", 7000, d, r, rh) != 200) return;
   string ans = CharArrayToString(r, 0, WHOLE_ARRAY, CP_UTF8);
   long cfgChat = StringToInteger(InpChatId);

   int pos=0;
   while(true)
     {
      int iu = StringFind(ans, "\"update_id\":", pos);
      if(iu<0) break;
      int ids=iu+12, ide=StringFind(ans, ",", ids);
      if(ide<0) break;
      long uid = StringToInteger(StringSubstr(ans, ids, ide-ids));
      if(uid>g_tgOffset) g_tgOffset=uid;

      int nxu = StringFind(ans, "\"update_id\":", iu+5);
      int blockEnd = (nxu<0) ? StringLen(ans) : nxu;

      // XAVFSIZLIK: faqat InpChatId dan kelgan buyruqlar bajariladi.
      // Chat id topilmasa yoki mos kelmasa - butunlay e'tiborsiz qoldiriladi.
      long cid = ExtractChatId(ans, iu, blockEnd);
      if(cid != cfgChat)
        {
         PrintFormat("TELEGRAM: ruxsatsiz chat (%I64d) dan kelgan buyruq rad etildi", cid);
         pos = iu+12;
         continue;
        }

      // inline tugma bosilgan bolsa
      int ic = StringFind(ans, "\"callback_query\"", iu);
      if(ic>=0 && ic<blockEnd)
        {
         int ds = StringFind(ans, "\"data\":\"", ic);
         if(ds>=0)
           {
            ds += 8;
            int de = StringFind(ans, "\"", ds);
            if(de>ds)
              {
               string data = StringSubstr(ans, ds, de-ds);
               if(data=="closeall") HandleCmd("/close_all");
               else if(StringFind(data,"close")==0)
                  HandleCmd("/close "+StringSubstr(data,5));
              }
           }
         pos = iu+12;
         continue;
        }

      int it = StringFind(ans, "\"text\":\"", iu);
      if(it>=0 && it<blockEnd)
        {
         int ts=it+8, te=StringFind(ans, "\"", ts);
         if(te>ts) HandleCmd(StringSubstr(ans, ts, te-ts));
        }
      pos = iu+12;
     }
  }

void OnTimer()
  {
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   if(dt.day != g_day) { g_day=dt.day; g_dayStart=AccountInfoDouble(ACCOUNT_BALANCE); }
   CheckAveraging();
   PollTelegram();
   DrawPanel();
  }
//+------------------------------------------------------------------+
