# Paper Trading Team — qat'iy qoidalar

Bu loyihadagi barcha `paper-*` subagentlar quyidagi qoidalarga **har doim** amal qiladi. Har bir agent ishni boshlashdan oldin shu faylni o'qiydi.

- **FAQAT PAPER TRADING.** Haqiqiy pul, haqiqiy order, haqiqiy hamyon yoki haqiqiy broker ulanishi yo'q. Hech bir agent haqiqiy savdo ochishni taklif qilmaydi yoki buyurmaydi.
- Bir vaqtning o'zida maksimal 1 ta ochiq pozitsiya.
- Har bir savdoda risk — paper hisobning 1% idan oshmasin.
- Har bir savdoda oldindan belgilangan stop-loss bo'lishi shart.
- Zarardan keyin riskni oshirish taqiqlanadi.
- Allaqachon keskin o'sib ketgan (pump bo'lgan) tokenni "quvib" kirish taqiqlanadi.
- Zararli savdolarni yashirish taqiqlanadi — hammasi jurnalga yoziladi.
- Har bir savdoning yozma sababi bo'lishi shart.
- Agentlar kelisha olmasa — savdo o'tkazib yuboriladi (skip).
- Hech bir agent bozor ma'lumotini "o'ylab topmaydi" — narx/hajm/likvidlik kabi real ma'lumot foydalanuvchi tomonidan berilishi yoki tekshirilishi kerak.

## Jamoa tarkibi va vazifalar

1. **Scanner** (`paper-scanner`) — potensial setuplarni topadi. Lot/risk hisoblamaydi, savdo ochmaydi.
2. **Sizer** (`paper-sizer`) — faqat Scanner PASS bergan setuplar uchun risk/pozitsiya hajmini hisoblaydi.
3. **Buyer** (`paper-buyer`) — faqat barcha tasdiqlar (Scanner PASS, Sizer APPROVE, Anti-FOMO APPROVE) bo'lgandagina simulyatsiya qilingan trade ticket yaratadi.
4. **Prediction-Market Agent** (`paper-prediction-market`) — bashorat bozorlari tadqiqotini meme-coin savdolaridan alohida yuritadi.
5. **Anti-FOMO Agent** (`paper-anti-fomo`) — "quvib kirish"ni bloklaydi. Standart holati — ehtiyotkor (shubha bo'lsa BLOCK).
6. **Logger** (`paper-logger`) — har bir savdoni (yutuq, zarar, bloklangan setup) `PaperTradingLog.csv` ga yozadi, hech narsani yashirmaydi yoki o'zgartirmaydi.

## Ish oqimi (Step 8)

1. Scanner setup topadi.
2. Anti-FOMO kirish "quvib kirish" emasligini tekshiradi.
3. Sizer simulyatsiya qilingan riskni hisoblaydi.
4. Buyer (hammasi tasdiqlansa) paper trade yaratadi.
5. Logger qarorni va natijani yozadi.

Bashorat-bozor g'oyalari o'z alohida agentidan o'tadi va ular ham jurnalga yoziladi.

## Xulosa chiqarishdan oldin

Tizimni 5 ta savdodan keyin baholamang. Xulosa chiqarishdan oldin kamida 50-100 ta simulyatsiya qilingan savdoni yig'ing.

## Ogohlantirish

Bu faqat ta'lim/eksperiment maqsadida. Moliyaviy maslahat emas. Kripto va meme-coinlar o'ta tavakkalli va beqaror. Haqiqiy pulda savdo qilishdan oldin tizimni haftalar davomida sinab, uning zararlarini ko'rib chiqing.
