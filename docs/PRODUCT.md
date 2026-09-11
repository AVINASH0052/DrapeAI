# Sugatai — product brief

> **Audience:** new sessions, teammates, investors, anyone who needs to explain the product.  
> **Not this file:** architecture, APIs, or how to run the stack — see [README.md](README.md).  
> **Last updated:** 2026-08-15

---

## One line

**Sugatai is an AI wardrobe stylist for India.** Photograph the clothes you already own. Get daily looks. See them on you before you get dressed.

Tagline: *see your look, before you wear it.*  
Short pitch: *Modern wardrobe AI — global style, Indian context.*

---

## 30-second pitch

Most people own enough clothes and still feel they have nothing to wear. Global closet apps treat a kurta like a generic “top.” Shopping apps want you to buy more. A human stylist is expensive and not there on a Tuesday morning.

Sugatai is a phone app. You snap your pieces (or a full outfit — it can split a selfie into shirt, pants, shoes, accessories). The AI tags them, then builds outfits from *your* closet: work, festive, date, travel, monsoon. It understands Indian weather and ethnic + fusion dressing. You can preview a look on your photo, save it, wear it, and learn what to buy next — so you shop less and wear more.

---

## The problem

| Pain | What people do today |
|---|---|
| “I have nothing to wear” with a full cupboard | Repeat the same 5 outfits; forget what they own |
| Getting dressed takes too long | Scroll Instagram / Pinterest for looks they cannot actually wear |
| Ethnic + western in one life | Global apps do not know when kurta + jeans works and sherwani + jeans does not |
| Heat, humidity, monsoon, Delhi winter | Outfit ideas ignore the city and the day |
| Buying more does not fix it | Myntra / Ajio / Amazon optimize for the next purchase, not the wardrobe at home |
| “Will this look good on me?” | Guess, or spend on a stylist |

India is a fashion market where one person needs office, wedding, festival, gym, and street in the same closet. That mix is the product, not an afterthought.

---

## What the product is

**Sugatai** is a consumer mobile app (iOS and Android). It is a *personal stylist that lives on your clothes*, not a shopping feed and not a social network.

The person using it:

1. Sets a style profile (occasions, colors, fit, city).
2. Adds a full-body photo so looks can be previewed on them.
3. Photographs their wardrobe. One hung item or one mirror selfie — the app isolates each piece and labels it (category, color, fabric, formality, season, ethnic vs western).
4. Asks for outfits: today’s looks, a shuffle, or “make this more formal.”
5. Tries the look on their photo, saves it to a lookbook, marks it worn on a calendar, and sees what is unused.

In the app the four tabs are:

| Tab | What it is |
|---|---|
| **Closet** | Digital wardrobe. Search and filter. Add pieces with the camera. |
| **Fit** | Daily outfits, shuffle, chat tweaks, lookbooks. |
| **Studio** | Dress a private avatar / preview a look on you. |
| **You** | Profile, style quiz, analytics, “what should I buy next?” |

There is also a marketing site and waitlist at sugatai.com. This is not a social app. Closets are private.

---

## Who it is for

**Primary:** urban Indians (and the diaspora) who dress for more than one world — office, festive, weekend, travel — and are tired of wasting a wardrobe they already paid for.

**Also:** anyone who wants a stylist that uses *their* clothes, with Indian climate and ethnic wear treated as normal, not “other.”

**Not for (yet):** people who only want to shop; brands that need a marketplace; users who will not photograph anything.

---

## How it works (the loop)

```
Photograph clothes  →  Closet is tagged  →  Get a look
        ↑                                      ↓
   Buy the gap                    See it on you / wear it / save it
        ←——————  App learns from likes, skips, and wears  ←——————
```

- **Upload.** Snap a piece or a worn outfit. Pieces land in Closet as clean item cards.
- **Style.** Today’s looks use weather + occasion. Shuffle is for “surprise me.” Chat is for “darker” or “more festive.”
- **See.** Studio / try-on answers “does this work on me?” before you change.
- **Remember.** Lookbooks, calendar, wear counts, cost-per-wear.
- **Decide.** Gap analysis: the next 3–5 things worth buying, given this closet, this city, this life — not a generic trend list.

The AI gets better from thumbs up/down, saves, and “I wore this.” It is a stylist that learns one person, not a feed that copies everyone.

---

## Main USP

**1. Built for how India actually dresses.**  
Saree, kurta, lehenga, sherwani, dupatta, fusion. The product knows which mixes are real life and which are costume. Global closet apps do not.

**2. Styles what you already own.**  
The win is not a new cart. It is wearing the cupboard. Shopping is a later, smaller step (“fill this gap”), not the homepage.

**3. See the look before you wear it.**  
A private body photo + studio preview. Decide in 10 seconds instead of three outfit changes.

**4. One photo, many pieces.**  
A gym selfie or a dressed mirror shot can become t-shirt, joggers, sneakers, kada — each as its own closet card. That is how people actually take photos.

**5. Weather and occasion for Indian cities.**  
Mumbai rain, Bengaluru “summer,” Delhi winter, festive week — not a generic “seasonal” toggle.

**6. A closet that teaches the stylist.**  
Likes, skips, and wears change the next recommendation. The product gets more *you* over time.

Those six together are the wedge. Any one of them exists somewhere. The combination — India-native rules + own-wardrobe + on-you preview + learning loop — is the product.

---

## Benefit (why someone keeps it)

| If they feel… | Sugatai does… |
|---|---|
| Decision fatigue every morning | Three looks from *their* clothes, for *today’s* weather |
| Clothes they forgot they owned | Shuffle and pairings surface them |
| Fear of looking “off” at a wedding or office | Ethnic + fusion rules + preview on their photo |
| Buying more and wearing less | Utilization and “buy this next” instead of more of the same |
| Stylist is too expensive / too rare | Daily stylist in the pocket, private, no appointment |
| “Will this shop item work with what I have?” | Try a shop piece against the closet / on their photo |

**Emotional benefit:** confidence and time.  
**Practical benefit:** more outfits per rupee already spent.  
**Long-term benefit:** a wardrobe that is understood, so the next purchase is deliberate.

---

## Comparison

| | Sugatai | Closet apps (Whering, Acloset, Stylebook, Cladwell) | Shopping / try-on (Myntra, Ajio, Amazon) | ChatGPT / generic AI | Human stylist |
|---|---|---|---|---|---|
| Uses *your* clothes | Yes | Yes | No — catalog | No wardrobe | Yes, if you bring them |
| Ethnic + fusion as first-class | Yes | Weak / western taxonomy | Catalog merchandising | Generic advice | Yes, if they know India |
| Daily looks + weather | Yes, Indian cities | Sometimes | No | No | No |
| See it on you | Yes (private photo / studio) | Rare | Yes, to sell a SKU | No | In person |
| Learns your taste | Yes | Light | Purchase graph | Session only | Yes |
| Price to the user | App (free tier planned; Pro ~₹99/mo planned) | Often subscription, western pricing | You pay by buying | Free / plus | ₹2,000–10,000+ per session |
| Social / sharing required | No | Sometimes | Feed | No | No |

**Vs closet apps:** they digitize a wardrobe. Sugatai *styles* an Indian one and lets you see the result on yourself.

**Vs shopping apps:** they are stores with a try-on widget. Sugatai is the cupboard. Buy is optional and targeted.

**Vs generic AI:** a chat can say “wear navy.” It cannot see the navy shirt you own, the monsoon, or you in it.

**Vs a human stylist:** a stylist is better for a once-a-year overhaul. Sugatai is for every morning and every festive week, at consumer price.

---

## Why this, why now

- Phones and camera quality are good enough that a cupboard can become a catalog in an evening.
- People already take mirror selfies; the product can use that habit instead of demanding perfect flat-lays only.
- AI can tag, split, and rank looks cheaply enough for a daily consumer loop.
- Indian fashion is not a localization of a US closet app. The mix of ethnic, fusion, and western *is* the market.
- Climate and occasion change weekly. A static Pinterest board does not.

---

## Business (plain language)

**Today:** working product, early access / waitlist. The loop above is real in the app.

**Planned model (not a live store listing yet):**

- **Free:** digitize a closet, light daily use.
- **Pro (~₹99/month, from the original plan):** more items, more looks, more try-on / studio.
- **Later:** “buy the gap” with affiliate links (Myntra / Ajio and similar) — earn when someone fills a hole the closet actually has. Resale and a stylist marketplace are further out.

The economic story is: low cost to run a recommendation, high repeat use (morning habit), then take a cut of *fewer, better* purchases — not a tax on impulse.

---

## What is live vs next

**Live in the product**

- Account (phone / Google / Apple)
- Style onboarding
- Closet upload, auto-tag, split a worn photo into pieces
- Daily looks, shuffle, chat refine, lookbooks
- Studio / try-on on your photo
- Calendar, wear tracking, analytics, gap “what to buy next”
- Weather-aware suggestions

**Next (market, not science projects)**

- Paid Pro + hard usage caps
- Import from purchase history / product URLs
- Deeper chat stylist over the whole closet (“wedding in Jaipur, 3 days”)
- Indian-language UI
- Trip packing
- Affiliate “buy this gap”
- Human stylist and resale only when the closet habit is proven

---

## How to say it

**To a friend**  
“You photograph your clothes. It tells you what to wear today, including kurta-and-jeans days, and you can see the look on your photo first.”

**To an investor**  
“Sugatai is the AI stylist for the Indian wardrobe. We turn the cupboard into a private catalog, generate occasion- and weather-aware looks from what people already own, and preview on the user. Global closet apps miss ethnic/fusion. Commerce apps optimize for the next SKU. We own the daily dressing habit, then monetize subscription plus high-intent gap shopping.”

**To a new teammate or a new chat session**  
Start here. The app is Sugatai. The wardrobe tab is Closet. The promise is: *your clothes, your look, before you wear it.* Engineering detail lives in [architecture/OVERVIEW.md](architecture/OVERVIEW.md).

---

## What it is not

- Not a social network or a “fit check” feed.
- Not a marketplace (yet). We do not hold inventory.
- Not “AI fashion” as moodboards. The unit of value is *an outfit you can put on this morning*.
- Not a Western closet app with a saree filter taped on.

---

## Remember

**Product:** Sugatai — AI wardrobe stylist, India-first.  
**Application:** iOS / Android app (Closet, Fit, Studio, You).  
**USP:** own-wardrobe styling + ethnic/fusion + on-you preview + a stylist that learns.  
**Benefit:** less “nothing to wear,” more of the cupboard used, smarter next buy.  
**Compare against:** closet apps (no India), shopping apps (no cupboard), generic AI (no closet), human stylists (no daily habit).
