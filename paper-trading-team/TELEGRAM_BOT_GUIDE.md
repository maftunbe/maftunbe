# Paper-Boss Telegram Bot — qo'llanma

Bu hujjat ertangi ish uchun tayyorlangan: `paper-boss` (DOGE soatlik paper-trading pipeline) natijalarini Telegram orqali kuzatish va qo'lda boshqarish uchun bot qanday ulanishi kerakligi.

## 1. Mavjud namuna: `TradeSupervisor.mq5`

Loyihada allaqachon ishlayotgan Telegram integratsiyasi bor — `MQL5/Experts/TradeSupervisor.mq5`. Undan quyidagi naqshlarni meros qilib olamiz (lekin MQL5 emas, Bash/curl bilan qayta yozamiz, chunki `paper-boss` Claude Code sessiyasida ishlaydi, MT5 terminalida emas):

| TradeSupervisor.mq5'dagi funksiya | Nima qiladi | Bizda ekvivalenti |
|---|---|---|
| `Send()` (qator ~356) | `sendMessage` orqali matn yuboradi | Bash: `curl -s "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id=$CHAT_ID -d text="..."` |
| `SendChartShot()` (qator ~307) | `sendPhoto` orqali grafik yuboradi | Kerak bo'lsa keyinroq — hozircha shart emas, matn yetarli |
| `RegisterTelegramCommands()` (qator ~949) | `setMyCommands` — pastki tugmalar paneli | Bot sozlashda bir martalik `curl` chaqiruvi |
| `PollTelegram()` (qator ~1228) | `getUpdates` bilan yangi buyruqlarni so'raydi (offset asosida) | Har soatlik routine ishga tushganda bir marta so'raladi (pastga qarang) |

**Muhim farq:** MT5 bot doimiy ishlaydigan dastur (har necha soniyada poll qiladi), `paper-boss` esa faqat soatlik `routine` ishga tushganda uyg'onadi. Shuning uchun bizda "real-vaqt" emas, "har soatda bir marta tekshiramiz" modeli bo'ladi — bu yetarli, chunki tekshiruv ham soatlik.

## 2. Kerakli narsalar (ertaga tayyorlab qo'ying)

1. **Bot tokeni** — Telegram'da [@BotFather](https://t.me/BotFather)'ga `/newbot` yuborib yarating (yoki mavjud botni ishlating). Token shunday ko'rinadi: `123456789:AAH...`.
2. **Chat ID** — botga `/start` deb yozing, keyin brauzerda `https://api.telegram.org/bot<TOKEN>/getUpdates` ochib `"chat":{"id": ...}` qiymatini oling. Yoki [@userinfobot](https://t.me/userinfobot)'dan shaxsiy chat id oling.

**Hech qachon tokenni chatga yozmang yoki repo fayliga qo'ymang.** TradeSupervisor.mq5'da ham xuddi shunday ogohlantirish bor (qator 76: "Bu yerga yozmang").

## 3. Sozlash qadamlari (environment)

Xuddi Polymarket/Kalshi uchun qilganimiz kabi, "Edit environment" oynasida:

1. **Network access** → Custom ro'yxatiga qo'shing: `api.telegram.org`
2. **Network secrets** bo'limida (**"Add secret"** tugmasi) ikkita o'zgaruvchi qo'shing:
   - `TELEGRAM_BOT_TOKEN`
   - `TELEGRAM_CHAT_ID`
3. **Save changes**, so'ng (avvalgi tajribamizdan ma'lum) **yangi sessiyada** ishlatish kerak bo'ladi — joriy sessiya eski tarmoq siyosati bilan qoladi.

## 4. Arxitektura: ikki tomonlama aloqa

### A) Chiqish (paper-boss → Telegram) — asosiy va oson qism
Har soatlik `routine` oxirida, `paper-boss` natijasidan keyin (hozir faqat git push va dashboard yangilash bor), qo'shimcha bitta qadam:
```bash
curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
  --data-urlencode "chat_id=$TELEGRAM_CHAT_ID" \
  --data-urlencode "text=DOGE #<N>: <Scanner>/<AntiFOMO> -> <Result>. Narx: $<price>" \
  --data-urlencode "parse_mode=Markdown" > /dev/null
```
RULES.md'ning "faqat trade ochilsa yoki xato bo'lsa xabar ber" qoidasini Telegram'da ham davom ettirish mumkin (shovqin qilmaslik uchun), yoki foydalanuvchi xohlasa — har bir BLOCK haqida ham qisqa xabar (bitta qator) yuborish mumkin. Buni ertaga tanlaysiz.

### B) Kirish (Telegram → paper-boss buyruqlari) — murakkabroq qism
Doimiy serverimiz yo'qligi sababli **webhook** ishlatolmaymiz (webhook uchun doim ochiq URL kerak). O'rniga **polling**:
- Har soatlik routine boshida, asosiy ishdan oldin, bitta marta `getUpdates?offset=<oxirgi_offset>` chaqiramiz.
- Agar foydalanuvchidan yangi buyruq kelgan bo'lsa (masalan `/status`, `/check` — darhol tekshiruv so'rash, `/stats` — statistika), shuni bajarib, javob yuboramiz.
- Oxirgi ko'rilgan `update_id`ni biror joyda saqlash kerak (masalan `paper-trading-team/.telegram_offset` faylida, git'ga commit qilinadi) — TradeSupervisor.mq5'dagi `g_tgOffset` o'zgaruvchisiga ekvivalent.

**Cheklov:** bu faqat soatlik firing paytida ishlaydi — ya'ni `/status` yozsangiz, javobni darhol emas, keyingi soatlik tsikl boshlanganda olasiz. Agar tezroq javob kerak bo'lsa, buyruq kelganda **darhol** yangi sessiya/routine ishga tushiradigan alohida, tezroq tiklanadigan trigger kerak bo'ladi (masalan har 5 daqiqada faqat `getUpdates`ni tekshiradigan yengil routine) — buni ertaga muhokama qilamiz.

## 5. Taklif qilinadigan buyruqlar ro'yxati (TradeSupervisor'dagi kabi)

| Buyruq | Vazifa |
|---|---|
| `/status` | So'nggi tekshiruv natijasi (narx, Scanner/Anti-FOMO/Sizer, Result) |
| `/stats` | Jami tekshiruv, BLOCKED/OPEN/WIN/LOSS soni, jami P&L |
| `/check` | Navbatdagi soatlik tekshiruvni kutmasdan, darhol bitta tekshiruv o'tkazishni so'rash |
| `/dashboard` | Dashboard havolasini qaytarish (https://claude.ai/artifact/YQw1WMLCFPyJFBETSCC9Nf) |
| `/rules` | RULES.md'dan qisqacha eslatma (faqat paper, 1% risk va h.k.) |

## 6. Ertangi ish rejasi (qadam-baqadam)

1. Bot token + chat id tayyorlang (BotFather).
2. Environment'da `api.telegram.org`ni Allowed domains'ga, tokenlarni Network secrets'ga qo'shing.
3. Yangi sessiyada `curl` orqali `sendMessage`ni sinab ko'ramiz (ulanish ishlayotganini tasdiqlash).
4. Hourly routine promptiga Telegram xabar yuborish qadamini qo'shamiz (4-bo'lim, A qismi).
5. Agar vaqt bo'lsa — polling/buyruqlar qismini (4-bo'lim, B qismi) qo'shamiz.
6. `paper-trading-team/README.md`ga Telegram bot haqida qisqa bo'lim qo'shamiz.

## Ogohlantirish

Bu ham FAQAT PAPER TRADING monitoring vositasi. Telegram bot hech qachon haqiqiy order yubormaydi, haqiqiy hamyon bilan ishlamaydi — faqat `paper-boss` natijalarini o'qish va mavjud soatlik tekshiruvni so'rash uchun.
