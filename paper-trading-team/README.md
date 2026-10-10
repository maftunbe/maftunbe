# 6 AI Bot Trading Team — faqat PAPER MODE

Bu "6 AI Bot Trading Team" qo'llanmasiga asoslangan, Claude Code subagentlari sifatida amalga oshirilgan jamoa. **Haqiqiy pul yo'q, haqiqiy order yo'q** — faqat qoidalarga rioya qilishni sinovdan o'tkazish uchun simulyatsiya.

Qoidalar: [`RULES.md`](./RULES.md). Jurnal: [`PaperTradingLog.csv`](./PaperTradingLog.csv).

## Agentlar

| Agent | Vazifa |
|---|---|
| `paper-scanner` | Potensial setuplarni topadi, PASS/SKIP beradi |
| `paper-anti-fomo` | Pump'ni quvib kirishni bloklaydi |
| `paper-sizer` | Simulyatsiya qilingan risk/pozitsiya hajmini hisoblaydi |
| `paper-buyer` | Hammasi tasdiqlansa, paper trade ticket yaratadi |
| `paper-prediction-market` | Bashorat-bozor g'oyalarini alohida tadqiq qiladi |
| `paper-logger` | Har bir savdoni/bloklangan setupni jurnalga yozadi |
| `paper-boss` | Koordinator — butun pipeline'ni (Scanner→Anti-FOMO→Sizer→Buyer→Logger) o'zi bosqichma-bosqich o'tkazib, bitta yakuniy qaror beradi |

## Ish oqimi

1. **Scanner** setup topadi (PASS/SKIP).
2. **Anti-FOMO** kirish "quvib kirish" emasligini tekshiradi (APPROVE/BLOCK).
3. **Sizer** simulyatsiya qilingan riskni hisoblaydi (APPROVE/REJECT).
4. **Buyer** — faqat uchalasi ham tasdiqlasa — paper trade yaratadi.
5. **Logger** qarorni va keyinroq natijani jurnalga yozadi.

Bashorat-bozor g'oyalari `paper-prediction-market` orqali alohida yuradi va ular ham jurnalga yoziladi.

Har safar 5 ta agentni birma-bir chaqirish o'rniga, **`paper-boss`** ga bitta token/setup berib, u butun zanjirni o'zi yurgizib, yagona yakuniy qarorni (trade ticket yoki TRADE BLOCKED) chiqarib, jurnalga ham yozib qo'yadi.

## Qanday ishlatiladi

Claude Code sessiyasida bu subagentlarni nomi bilan chaqirish mumkin (Agent tool orqali, yoki ularga mos keladigan savolni yozganingizda avtomatik tanlanadi). Masalan:

- "DOGE bo'yicha to'liq tekshiruv o'tkaz, yakuniy qaror ber" → `paper-boss`
- "DOGE uchun setup bormi, Scanner tekshirsin" → `paper-scanner`
- "Bu kirish FOMO emasmi?" → `paper-anti-fomo`
- "$1000 hisobga, entry $0.10, stop $0.095 — hajmni hisobla" → `paper-sizer`
- "Hammasi tasdiqlandi, trade ticket yoz" → `paper-buyer`
- "Bu savdoni jurnalga yoz" → `paper-logger`

## Xulosa chiqarishdan oldin

5 ta savdodan keyin baholamang. Kamida **50-100 ta** simulyatsiya qilingan savdoni yig'ing, so'ng tekshiring:
- Qoidalarga haqiqatan rioya qilinyaptimi?
- Anti-FOMO yomon kirishlarning oldini olyaptimi?
- Zararlar nazoratdami?
- Yutuqlar zararlardan kattami?

## Eslatma

Bu faqat ta'lim/eksperiment uchun. Moliyaviy maslahat emas. "$89 → $55,698" kabi viral natijalar tasdiqlanmagan va kafolatlangan natija sifatida qaralmasligi kerak. Haqiqiy pulda hech qachon yo'qotishga chiday olmaydigan miqdorda savdo qilmang.
