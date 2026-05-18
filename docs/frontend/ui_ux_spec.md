# DrapeAI -- UI/UX Specification

Modern, minimal, fast. Inspired by the latest YC-backed consumer apps (Linear, Arc, Lemon Squeezy, Notion Mobile). No clutter. No gimmicks. Every screen earns its place.

---

## Table of Contents

- [Design Principles](#design-principles)
- [Design System](#design-system)
- [Typography](#typography)
- [Spacing and Layout](#spacing-and-layout)
- [Component Library](#component-library)
- [Screen Specifications](#screen-specifications)
- [Navigation Structure](#navigation-structure)
- [Animations and Transitions](#animations-and-transitions)
- [Accessibility](#accessibility)

---

## Design Principles

1. **Instant clarity.** User understands what to do within 2 seconds of seeing any screen.
2. **Content is the UI.** Clothing images are the hero. UI elements recede.
3. **One action per screen.** Every screen has a primary action. Secondary actions are de-emphasized.
4. **Speed over decoration.** No loading spinners longer than 300ms without a skeleton. No animations longer than 400ms.
5. **Breathing room.** Generous whitespace. Never cram.
6. **India-aware.** RTL-ready typography. Ethnic wear categories first-class. OTP as primary auth.

---

## Design System

### Color Palette

```
Primary:          #111827  (Gray-900)     -- buttons, headings, active nav
Primary Surface:  #F9FAFB  (Gray-50)      -- selected card bg, active chip bg
Accent:           #6366F1  (Indigo-500)   -- AI elements, outfit score, highlights
Accent Light:     #EEF2FF  (Indigo-50)    -- AI card backgrounds
Background:       #FFFFFF  (White)         -- main bg
Surface:          #F9FAFB  (Gray-50)      -- cards, bottom sheet bg
Border:           #E5E7EB  (Gray-200)     -- dividers, card borders
Text Primary:     #111827  (Gray-900)     -- headings, primary labels
Text Secondary:   #6B7280  (Gray-500)     -- body text, descriptions
Text Muted:       #9CA3AF  (Gray-400)     -- placeholders, hints
Success:          #059669  (Emerald-600)  -- "liked", "saved" confirmations
Error:            #DC2626  (Red-600)      -- errors, delete actions
Warning:          #D97706  (Amber-600)    -- "retake photo" nudge
```

### Surfaces and Elevation

| Surface | Background | Border | Shadow |
|---|---|---|---|
| Screen background | #FFFFFF | none | none |
| Card | #FFFFFF | 1px #E5E7EB | none (flat) or `elevation: 1` max |
| Bottom sheet | #FFFFFF | top 1px #E5E7EB | 0 2px 8px rgba(0,0,0,0.06) |
| Modal / dialog | #FFFFFF | none | 0 4px 16px rgba(0,0,0,0.1) |
| Chip (inactive) | #F3F4F6 | none | none |
| Chip (active) | #111827 | none | none |
| Input field | #F9FAFB | 1px #E5E7EB | none |
| Input field (focused) | #FFFFFF | 2px #111827 | none |

No gradients on backgrounds. No dark mode. No glassmorphism.

---

## Typography

**Font:** Inter (Google Fonts) -- clean, legible, modern. Fallback: system sans-serif.

| Style | Size | Weight | Color | Usage |
|---|---|---|---|---|
| Display | 28px | 700 (Bold) | textPrimary | Splash title only |
| H1 | 24px | 700 | textPrimary | Screen titles |
| H2 | 20px | 600 (SemiBold) | textPrimary | Section headers |
| H3 | 16px | 600 | textPrimary | Card titles, lookbook names |
| Body | 14px | 400 (Regular) | textSecondary | Descriptions, body text |
| Caption | 12px | 400 | textMuted | Timestamps, hints, metadata |
| Button | 14px | 600 | White or textPrimary | Button labels |
| Chip | 13px | 500 | White (active) or textSecondary (inactive) | Filter chips, tags |

Line height: 1.5 for body text, 1.3 for headings.

---

## Spacing and Layout

**Base unit:** 4px. All spacing is a multiple of 4.

| Token | Value | Usage |
|---|---|---|
| `xs` | 4px | Tight gaps (chip icon to label) |
| `sm` | 8px | Between related elements (chip to chip) |
| `md` | 16px | Card padding, section gaps |
| `lg` | 24px | Between sections |
| `xl` | 32px | Screen top/bottom padding |
| `2xl` | 48px | Hero spacing |

**Screen padding:** 20px horizontal on all screens.
**Card padding:** 16px all sides.
**Grid gap:** 12px between grid items.

### Grid Layouts

| Screen | Grid | Item Size |
|---|---|---|
| Wardrobe grid | 3 columns | (screen_width - 40 - 24) / 3, square, rounded 12px |
| Outfit items (horizontal scroll) | N items | 80x80px circles |
| Lookbook grid | 2 columns | (screen_width - 40 - 12) / 2, 3:4 aspect ratio |

---

## Component Library

### Buttons

**Primary button:**
- Background: #111827, text: white, height: 48px, border-radius: 12px, full width.
- Pressed: #374151. Disabled: #D1D5DB with #9CA3AF text.

**Secondary button:**
- Background: transparent, border: 1px #E5E7EB, text: #111827, height: 48px, border-radius: 12px.

**Ghost button:**
- Background: transparent, no border, text: #6B7280. Used for tertiary actions.

**Icon button:**
- 40x40px, border-radius: 20px (circle). Background: transparent. Tap target: 48x48px minimum.

### Cards

**Item card (wardrobe grid):**
```
+------------------+
|                  |
|   [Item Photo]   |   Square, rounded 12px, object-fit: cover
|                  |
+------------------+
| Navy Kurta       |   Caption, 12px, textSecondary, 1 line truncated
+------------------+
```
No border, no shadow. Just the image and a label below.

**Outfit card (today's outfits):**
```
+----------------------------------------------+
| Casual  --  28C  Clear               Score 87|   Caption row
+----------------------------------------------+
|                                              |
|  [Top]    [Bottom]    [Shoes]    [+1]        |   Horizontal row, 80x80 circles
|                                              |
+----------------------------------------------+
| "Navy polo with beige chinos is a            |   LLM reason, Body, 14px
|  timeless casual combo."                     |
+----------------------------------------------+
|  [Thumbs Up]    [Thumbs Down]    [Save]      |   Icon buttons row
+----------------------------------------------+
```
White card, 1px border, rounded 16px, padding 16px.

**AI accent:** Outfit cards generated by AI have a thin top border in Indigo-500 (2px) to signal "AI picked this."

### Chips (filter/tag)

- Inactive: bg #F3F4F6, text #6B7280, rounded 20px, height 32px, padding 0 12px.
- Active: bg #111827, text white.
- Tap to toggle. Single-select for category, multi-select for color/season.

### Bottom Navigation

4 tabs, icon + label, height 64px + safe area:

| Tab | Icon | Label |
|---|---|---|
| Wardrobe | `Icons.checkroom_outlined` | Wardrobe |
| Outfits | `Icons.auto_awesome_outlined` | Outfits |
| Lookbooks | `Icons.collections_bookmark_outlined` | Lookbooks |
| Profile | `Icons.person_outline` | Profile |

Active: icon + label in #111827. Inactive: #9CA3AF.

### Empty States

Every list/grid screen has an empty state with:
- Icon: 48px, #D1D5DB
- Title: H3, #111827
- Subtitle: Body, #6B7280, max 2 lines
- CTA button (optional)

Example (empty wardrobe):
```
        [Hanger icon]

    Your wardrobe is empty

  Add your first item to get
     AI outfit suggestions

      [+ Add item]  (primary button)
```

### Skeleton Loading

Every data-dependent screen shows a shimmer skeleton before data loads. Never a bare spinner.
- Use `ShimmerEffect` widget: light gray (#F3F4F6) pulsing to white.
- Match exact layout of real content.
- Duration: show for minimum 200ms to avoid flash.

---

## Screen Specifications

### S1: Splash Screen

- White background.
- Center: DrapeAI wordmark in Inter Bold 28px, #111827.
- Below: "AI Outfit Assistant" in 14px, #9CA3AF.
- Duration: 1.5 seconds, then navigate to auth or home.
- No logo animation. Clean and fast.

### S2: Auth Screen

- White background. Top 40% empty (breathing room).
- Center-bottom stack:
  1. "Welcome to DrapeAI" -- H1
  2. "Your AI stylist, built for India" -- Body, textSecondary
  3. [Continue with Google] -- Secondary button with Google icon
  4. [Continue with Phone] -- Primary button with phone icon
  5. "By continuing, you agree to our Terms and Privacy Policy" -- Caption, textMuted, with underlined links.

Phone OTP flow:
- Enter phone number (Indian format, +91 prefix auto-added)
- 6-digit OTP input (auto-focus, auto-advance)
- Verify button

### S3: Onboarding Quiz (5 screens)

Each question is a full screen. One question at a time. Swipe or tap to advance. Progress bar at top (thin, Indigo-500).

**Question 1: "What is your style?"**
Visual tiles in a 2-column grid, each tile:
- 120x120px illustration or photo
- Label below: "Minimalist", "Streetwear", "Classic", "Ethnic", "Bohemian", "Sporty"
- Tap to select (multi-select, max 3). Selected tile: Indigo-50 bg + Indigo-500 border.

**Question 2: "What do you dress for?"**
Same tile grid: "Casual", "Work", "Party", "Gym", "Date Night", "Festive", "Travel"
Multi-select.

**Question 3: "Your go-to colors?"**
Color circles (48px) with labels: "Neutrals", "Earth Tones", "Pastels", "Bold", "Monochrome", "Jewel Tones".
Each circle filled with representative gradient.

**Question 4: "How do you like the fit?"**
Single-select cards (full width, stacked): "Slim", "Regular", "Relaxed", "Oversized".
Each with a small silhouette illustration.

**Question 5: "Where are you based?"**
City text input with autocomplete (top 50 Indian cities pre-loaded).
Climate auto-detected from city. Manual override: chips for Tropical, Subtropical, Temperate, Arid, Cold.

Final screen: "You are all set" with a summary card of their preferences. [Start] button.

### S4: Welcome / Demo Mode

After quiz, before wardrobe:
```
+--------------------------------------------+
|                                            |
|    "Let's build your wardrobe"             |    H1
|                                            |
|    "Add your clothes or try with           |    Body
|     a sample wardrobe first"               |
|                                            |
|    [+ Add my clothes]     Primary button   |
|                                            |
|    [Try demo wardrobe]    Secondary button |
|                                            |
+--------------------------------------------+
```

Demo mode loads 20 pre-tagged items instantly. User sees the full wardrobe + outfit experience before uploading anything.

### S5: Camera + Photo Guide

**Camera view:**
- Full-screen camera preview.
- Translucent overlay frame (white border, rounded corners, 80% of screen width, centered).
- Rotating tip text at bottom: "Lay flat on a plain surface", "Use daylight", "One item per photo", "Get full item in frame". Cycles every 3 seconds.
- Capture button: large circle (64px), white fill, bottom center.
- Gallery pick button: small icon bottom-left.
- Flash toggle: top-right.

**Post-capture preview:**
- Full-screen image preview.
- Bottom sheet slides up:
  - Quality indicator: "Looks good" (green check) or "Retake suggested -- too dark" (warning).
  - [Use this photo] primary button.
  - [Retake] secondary button.

**Batch mode (gallery pick):**
- Standard system photo picker, multi-select enabled.
- After selection: horizontal scrollable row of thumbnails with upload progress bars.

### S6: Auto-Tag Review Screen

After upload, before saving to wardrobe:
```
+--------------------------------------------+
|  [Item Photo]     Large, 200px, centered   |
+--------------------------------------------+
|                                            |
|  Category:    [Top] [Bottom] [Ethnic] ...  |  Chip row, AI-selected one highlighted
|  Sub-cat:     [Kurta] [Shirt] [Polo] ...   |  Chip row
|  Color:       [Navy] [Black] [White] ...   |  Color chips (filled circles)
|  Pattern:     [Solid] [Striped] [Floral]   |  Chip row
|  Fabric:      [Cotton] [Silk] [Denim]      |  Chip row
|  Formality:   [1] [2] [3] [4] [5]         |  Number chips
|  Season:      [Summer] [Winter] [All]      |  Multi-select chips
|                                            |
|  [Save to wardrobe]     Primary button     |
+--------------------------------------------+
```

All chips are tappable. AI-selected ones are pre-activated. User taps to override.
Confidence badge: small "AI 92%" caption next to the photo.

### S7: Wardrobe Grid (Main Hub)

**Top bar:** "Wardrobe" (H1 left) + search icon (right) + add button (right).

**Filter row:** Horizontal scrollable chip row: All, Tops, Bottoms, Ethnic, Footwear, Accessories, Outerwear.

**Grid:** 3-column masonry-style grid. Square item photos, rounded 12px. Tap to open item detail.

**Floating action button:** Bottom-right, circular, #111827, white "+" icon. Opens camera/gallery picker.

**3-upload trigger:** After the 3rd item is added, a bottom sheet auto-appears:
```
"Your first outfit is ready!"
[See my outfit]   Primary button
```

**Search:** Expands into a search bar from the icon. Real-time filter as user types. Searches across sub_category, color, fabric, notes.

### S8: Item Detail

Full-screen bottom sheet or page:
- Large item photo (hero, 60% of screen height).
- Below: all tag chips (read-only style, but tappable to edit).
- Stats row: "Worn 3 times", "Added Mar 20".
- Cost per wear (if price entered): "Rs 833/wear" in accent color.
- Actions: [Edit tags] secondary button, [Delete] ghost button (red text).

### S9: Today's Outfits

**Top:** "Today's Outfits" (H1) + occasion chip row (Casual selected by default).

**Body:** Vertical stack of 3 outfit cards (see component spec above). Each card shows:
- Row of item photos (circular, 80px).
- LLM reason text.
- Thumbs up / thumbs down / save buttons.

**Pull to refresh:** Regenerates outfits (new GPT call, ignores cache).

**Weather badge:** Top-right corner: "28C Clear" with a small weather icon.

### S10: Outfit Shuffle

Full-screen Tinder-style swipe deck.

**Card:** Large card (90% screen width, 70% height). Shows:
- Vertical stack of item images (top + bottom + shoes), arranged like a flat lay.
- Occasion + score badge.
- Swipe left = reject (card flies left with red tint).
- Swipe right = save (card flies right with green tint, saved to default lookbook).
- Tap to see details.

**Bottom:** "Shuffle again" ghost button.

### S11: Lookbooks

**Grid:** 2-column grid of lookbook covers.

Each lookbook cover:
- 3:4 aspect ratio card.
- Cover = first outfit's item photos arranged in a small grid.
- Lookbook name overlay at bottom (white text on dark scrim).
- Outfit count badge.

**Tap:** Opens lookbook detail -- vertical list of outfit cards.

**Create:** "+" card at the end of the grid. Tapping opens a dialog: "Lookbook name" text field + [Create] button.

### S12: Profile / Settings

**Top:** User avatar (or initial circle) + name + plan badge ("Free" or "Pro").

**Sections:**
1. **Style Profile** -- summary of quiz answers, tap to re-take quiz.
2. **Wardrobe Stats** -- item count, outfits saved, utilisation % (v1.1: link to full analytics).
3. **Notifications** -- toggle morning outfit push.
4. **About** -- version, terms, privacy, feedback email.
5. **Sign out** -- ghost button, red text.
6. **Delete account** -- ghost button, red text, confirmation dialog.

---

## Navigation Structure

```
Bottom Nav (persistent)
  |
  +-- Wardrobe (S7)
  |     +-- Item Detail (S8) -- push
  |     +-- Camera + Photo Guide (S5) -- push (from FAB)
  |     +-- Auto-Tag Review (S6) -- push (after capture)
  |
  +-- Outfits (S9)
  |     +-- Shuffle (S10) -- push (from shuffle icon in app bar)
  |
  +-- Lookbooks (S11)
  |     +-- Lookbook Detail -- push
  |
  +-- Profile (S12)
        +-- Edit Preferences -- push
        +-- Analytics (v1.1) -- push
```

Deep links:
- `drapeai://outfits/today` -- from push notification
- `drapeai://wardrobe` -- default

---

## Animations and Transitions

| Trigger | Animation | Duration |
|---|---|---|
| Screen transition | Shared axis (Material 3 forward/backward) | 300ms |
| Card appear (list) | Fade in + slide up 8px, staggered 50ms per item | 200ms each |
| Chip toggle | Scale 0.95 -> 1.0 + color transition | 150ms |
| Outfit shuffle swipe | Physics-based card throw (Tinder-like) | 400ms |
| Bottom sheet | Slide up with spring curve | 350ms |
| Skeleton shimmer | Linear gradient sweep | 1200ms loop |
| Photo capture | White flash overlay | 100ms |
| Thumbs up/down | Icon scale bounce 1.0 -> 1.3 -> 1.0 | 200ms |
| Pull to refresh | Custom Lottie or simple rotation | 500ms |

No gratuitous animation. Every animation has a purpose: confirm an action, provide spatial context, or reduce perceived latency.

---

## Accessibility

- Minimum tap target: 48x48px.
- Color contrast: all text meets WCAG AA (4.5:1 for body, 3:1 for large text).
- All images have `semanticLabel` in Flutter for screen readers.
- All interactive elements have `tooltip` or `Semantics` label.
- Font scaling: support up to 1.3x system font size without layout breakage.
- Keyboard navigation: not critical for mobile-first, but text fields must work with system keyboard + autofill.
