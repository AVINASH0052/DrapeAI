# Design System Master File

> **LOGIC:** When building a specific page, first check `design-system/pages/[page-name].md`.
> If that file exists, its rules **override** this Master file.
> If not, strictly follow the rules below.

---

**Project:** Sugatai  
**Positioning:** Modern + global product UI, with Indian context (not ethnic-niche)  
**Category:** Wardrobe & Outfit Planner  
**Updated:** 2026-07-18

---

## Brand Voice

- **Do:** modern, calm, confident, global product language
- **Do:** Indian context as lived experience (heat, humidity, mix-and-match wardrobes, occasions)
- **Don't:** wedding-only / ethnic-costume marketing
- **Don't:** AI purple gradients, neon, emoji icons
- **Tagline:** See your look, before you wear it
- **Pitch:** Modern wardrobe AI — global style, Indian context

---

## Global Rules

### Color Palette

| Role | Hex | CSS Variable |
|------|-----|--------------|
| Ink | `#161018` | `--ink` |
| Ink soft | `#675b68` | `--ink-soft` |
| Paper | `#fffaf5` | `--paper` |
| Paper deep | `#f5eadf` | `--paper-deep` |
| Accent rose | `#e11d48` | `--pink` |
| Accent terracotta | `#c2410c` | `--orange` |
| Warm accent | `#d4a574` | `--lime` |
| Line | `#ded2c6` | `--line` |
| CTA gradient | `#c2410c → #e11d48` | — |

**Color notes:** Warm cream paper + rose/terracotta — India-adjacent warmth without purple AI cliché.

### Logo

Vector originals live in `web/public/brand/` (outlined Syne ExtraBold — no font dependency):

| Asset | File | Use |
|-------|------|-----|
| Wordmark (ink) | `sugatai-wordmark.svg` / `.png` | Light backgrounds, site header, print |
| Wordmark (paper) | `sugatai-wordmark-light.svg` / `.png` | Dark backgrounds |
| Mark, ink tile | `sugatai-mark.svg`, `-512.png`, `-1024.png` | App icon, favicon, avatars |
| Mark, paper tile | `sugatai-mark-paper.svg` | Dark surfaces |
| Mark, no tile | `sugatai-mark-transparent.svg` | Inline lockups |
| Apple touch icon | `apple-touch-icon.png` (180px) | iOS home screen |

**Construction:** lowercase `sugatai` in Syne ExtraBold, tracking −0.05em, rose dot (`--pink`) sitting on the baseline. The mark is the lowercase `s` + rose dot on an ink rounded square (radius 116/512). Do not rotate, outline, recolor the dot, or set the wordmark in another weight.

### Typography

- **Display:** Syne (bold headlines)
- **Accent / italic:** Instrument Serif
- **Body:** DM Sans
- **Mood:** modern fashion editorial, global, premium-calm

```css
@import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=Instrument+Serif:ital@0;1&family=Syne:wght@600;700;800&display=swap');
```

### Imagery

- Mix **street / work / occasion** — not all ethnic wear
- Occasional Indian garment is fine as one beat among modern looks
- Prefer natural light, clean compositions, diverse contemporary styling

### Sections (landing)

1. Hero — brand + one headline + one sentence + CTA + phone mock
2. Problem statement
3. Lifestyle looks (street → occasion → work)
4. Features (closet, life, try-on, weather)
5. Early access CTA
6. Footer

### Avoid

- Excessive decoration, purple/indigo SaaS look
- Wedding/sangeet/mehendi as the primary story
- Emoji as icons (use Lucide / Material Icons)
- Card clutter in the hero

### Pre-delivery checklist

- [ ] No emojis as icons
- [ ] cursor-pointer / clear tap targets
- [ ] Hover transitions 150–300ms
- [ ] Text contrast ≥ 4.5:1
- [ ] Focus states visible
- [ ] prefers-reduced-motion respected
- [ ] Responsive: 375 / 768 / 1024 / 1440
