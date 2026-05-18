# Claude Design Prompt -- DrapeAI

> Copy-paste this entire prompt into claude.ai/design to generate all screens.

---

## THE PROMPT

Design a complete mobile app (iPhone 15 Pro dimensions, 393x852pt) for **DrapeAI** -- an AI-powered personal stylist app built for India. Design ALL screens listed below as high-fidelity, production-ready mobile UI mockups.

### Brand & Aesthetic

- **Vibe:** Modern, clean, Gen-Z friendly. Think Linear meets Pinterest meets Notion Mobile. No clutter, no gimmicks.
- **Theme:** Light mode only. Warm white backgrounds (#FAFAF9), not cold white.
- **Font:** Inter (Google Fonts). Clean, geometric, highly legible.
- **Accent color:** Orange (#F97316) -- used for AI elements, highlights, active states, progress indicators.
- **Primary text:** Near-black (#1A1A1A). Secondary text: Gray (#6B7280). Muted: (#9CA3AF).
- **Cards:** White (#FFFFFF) with subtle 1px border (#E5E7EB). Flat, no heavy shadows.
- **Chips:** Inactive = light gray bg (#F3F4F6), Active = dark (#1A1A1A) with white text.
- **Buttons:** Primary = dark (#1A1A1A) with white text, 48px height, 12px border-radius. Secondary = outlined.
- **Corner radius:** 12px for cards, 20px for chips, 12px for buttons.
- **Spacing:** Generous whitespace. 20px screen horizontal padding. 4px base grid.
- **Icons:** Outlined style (not filled). Minimal.
- **Feel:** Premium but approachable. Like a fashion app a 22-year-old in Mumbai would love.

### Navigation

Bottom navigation bar with 4 tabs (icon + label):
1. **Wardrobe** (hanger icon) -- default landing
2. **Outfits** (sparkle/magic icon) -- AI recommendations
3. **Lookbooks** (bookmark/collection icon) -- saved outfit collections
4. **Profile** (person icon) -- settings & stats

Active tab: Orange icon + label. Inactive: Gray (#9CA3AF).

---

### SCREEN LIST (Design all of these)

---

#### Screen 1: Splash Screen
- Warm white background (#FAFAF9)
- Center: "DrapeAI" wordmark in Inter Bold 28px, dark
- Below wordmark: "AI Outfit Assistant" in 14px gray
- Clean, fast, no animation needed -- just the static frame
- No logo icon, just the text wordmark

---

#### Screen 2: Auth / Login Screen
- Warm white background
- Top 40% is empty breathing room
- Bottom section, centered stack:
  - "Welcome to DrapeAI" -- large heading, 24px bold
  - "Your AI stylist, built for India" -- 14px gray subtitle
  - 24px gap
  - [Continue with Google] button -- secondary/outlined style, Google "G" icon on left
  - 12px gap
  - [Continue with Phone] button -- primary dark style, phone icon on left
  - 16px gap
  - "By continuing, you agree to our Terms and Privacy Policy" -- 12px muted text, Terms and Privacy underlined

---

#### Screen 3: Phone OTP Flow (2 states)

**State A -- Enter Phone Number:**
- Back arrow top-left
- "Enter your phone number" heading
- Phone input field with "+91" prefix fixed, placeholder "98765 43210"
- [Send OTP] primary button, full width
- Minimal, clean

**State B -- Enter OTP:**
- Back arrow top-left
- "Verify your number" heading
- "We sent a code to +91 98765 43210" subtitle in gray
- 6 individual digit boxes in a row (auto-focus style), slightly separated
- [Verify] primary button
- "Resend code in 0:28" muted text below, countdown timer

---

#### Screen 4: Onboarding Quiz (5 steps + completion)

Show a thin progress bar at the very top (orange fill, gray track). Each step is one full screen.

**Step 1 -- "What is your style?"**
- Progress: 20%
- Heading: "What is your style?"
- Subtitle: "Pick up to 3 that match you"
- 2-column grid of visual tiles (6 tiles): Minimalist, Streetwear, Classic, Ethnic, Bohemian, Sporty
- Each tile: rounded 16px card with a small illustration/icon + label below
- Selected state: orange border + light orange bg (#FFF7ED)
- [Next] button at bottom

**Step 2 -- "What do you dress for?"**
- Progress: 40%
- Same tile grid layout
- Options: Casual, Work, Party, Gym, Date Night, Festive, Travel
- Multi-select

**Step 3 -- "Your go-to colors?"**
- Progress: 60%
- 6 large color circles (48px) with labels below each
- Neutrals (beige/gray gradient), Earth Tones (brown/olive), Pastels (pink/lavender), Bold (red/blue), Monochrome (black/white), Jewel Tones (emerald/ruby)
- Selected: orange ring around circle

**Step 4 -- "How do you like the fit?"**
- Progress: 80%
- 4 full-width stacked cards, single-select
- Each card: small silhouette illustration on left + "Slim" / "Regular" / "Relaxed" / "Oversized" label + short description
- Selected card: orange left border accent

**Step 5 -- "Where are you based?"**
- Progress: 100%
- City text input with search/autocomplete dropdown showing cities (Mumbai, Delhi, Bangalore, Chennai, Hyderabad...)
- Below: "Climate" section with chips: Tropical, Subtropical, Temperate, Arid, Cold
- Auto-selected based on city

**Completion Screen:**
- Checkmark or confetti-style subtle celebration
- "You're all set!" heading
- Summary card showing their selections (style tags, occasions, colors, fit, city) in a clean grid of chips/labels
- [Start exploring] primary button

---

#### Screen 5: Welcome / Demo Mode Choice
- After quiz, before wardrobe
- "Let's build your wardrobe" -- H1 heading
- "Add your clothes or try a sample wardrobe first" -- gray subtitle
- Illustration/icon of a wardrobe or hanger
- [+ Add my clothes] primary button
- [Try demo wardrobe] secondary/outlined button
- Clean, centered layout, lots of whitespace

---

#### Screen 6: Wardrobe Grid (Main Screen)
- Bottom nav visible, "Wardrobe" tab active (orange)
- Top bar: "Wardrobe" heading left, search icon + notification bell right
- Below top bar: horizontal scrollable filter chip row: "All" (active/dark), "Tops", "Bottoms", "Ethnic", "Footwear", "Accessories", "Outerwear"
- Item count: "24 items" in small muted text
- 3-column grid of clothing item photos (square, rounded 12px, object-fit cover)
- Below each photo: item name in 12px gray ("Navy Kurta", "White Sneakers", etc.)
- Show ~12 items in the mockup with realistic clothing photos
- Floating Action Button (FAB): bottom-right, circular, dark (#1A1A1A), white "+" icon
- Clean, Pinterest-style minimal grid

---

#### Screen 7: Wardrobe -- Empty State
- Same layout as Screen 6 but the grid area shows:
- Centered hanger icon (48px, light gray)
- "Your wardrobe is empty" -- heading
- "Add your first item to get AI outfit suggestions" -- gray subtitle
- [+ Add item] primary button
- Bottom nav still visible

---

#### Screen 8: Camera / Photo Capture Screen
- Full-screen camera preview (dark)
- Semi-transparent overlay with a white dashed/rounded frame in the center (guide to frame the clothing item)
- Bottom center: large circular white capture button (64px)
- Bottom left: small gallery/photos icon to pick from gallery
- Top right: flash toggle icon
- Bottom area (below capture button): rotating tip text in white: "Lay flat on a plain surface"
- No bottom nav on this screen

---

#### Screen 9: Photo Preview + Quality Check
- Full-screen preview of captured clothing photo
- Bottom sheet slides up with:
  - Green checkmark + "Looks good!" in green text (or warning icon + "Retake -- too dark" in amber)
  - [Use this photo] primary button
  - [Retake] secondary button
- Clean, minimal

---

#### Screen 10: AI Tag Review Screen
- Back arrow top-left, "Review Tags" title
- Large item photo centered at top (200px height, rounded)
- Small badge: "AI 92%" in orange chip next to photo
- Below photo, scrollable sections:
  - **Category:** chip row -- [Top] [Bottom] [Ethnic] [Footwear] [Accessory] -- one pre-selected by AI (dark/active)
  - **Sub-category:** chip row -- [Kurta] [Shirt] [Polo] [T-Shirt] -- AI-selected one active
  - **Color:** color circle chips -- [Navy] [Black] [White] [Beige] -- with filled circles + labels
  - **Pattern:** chip row -- [Solid] [Striped] [Floral] [Checked]
  - **Fabric:** chip row -- [Cotton] [Silk] [Denim] [Linen]
  - **Formality:** numbered chips -- [1] [2] [3] [4] [5] -- like a rating scale
  - **Season:** multi-select chips -- [Summer] [Winter] [Monsoon] [All Season]
- [Save to wardrobe] primary button at bottom, full width
- All chips tappable to override AI

---

#### Screen 11: Item Detail Screen
- Full-screen view, back arrow top-left
- Hero image of the clothing item (top 50-60% of screen)
- Below image, card section:
  - Item name: "Navy Cotton Kurta" -- heading
  - Tag chips displayed read-only style (Category: Ethnic, Color: Navy, Fabric: Cotton, etc.)
  - Stats row: "Worn 3 times" + "Added Mar 20, 2026" in gray caption
  - Optional: "Cost per wear: Rs 833" in orange accent if price entered
- Action buttons at bottom:
  - [Edit tags] secondary button
  - [Delete] ghost button with red text
- Clean, detail-focused layout

---

#### Screen 12: Today's Outfits (Outfits Tab)
- Bottom nav visible, "Outfits" tab active (orange)
- Top bar: "Today's Outfits" heading left, shuffle icon right (to go to shuffle mode)
- Weather badge top-right area: "28C Clear" with small sun icon
- Occasion filter chips below: [Casual] (active), [Work], [Party], [Festive], [Date Night]
- 3 outfit cards stacked vertically (scrollable):

Each outfit card:
  - White card, rounded 16px, 1px border, thin 2px orange top border (AI indicator)
  - Top row: "Casual -- 28C Clear" left, "Score 87" in orange right
  - Middle: horizontal row of 4 circular item photos (80px each): Top, Bottom, Shoes, Accessory
  - Below items: AI reason text in 14px gray italic: "Navy polo with beige chinos is a timeless casual combo for a warm day."
  - Bottom row: three icon buttons spaced evenly -- Thumbs Up, Thumbs Down, Bookmark/Save
  - Each icon: outlined, 40px, gray. Tapped state: filled, orange (thumbs up) or red (thumbs down)

---

#### Screen 13: Outfit Shuffle (Swipe Mode)
- No bottom nav (full screen experience)
- Back arrow top-left, "Shuffle" title
- Large card (90% width, ~65% height) centered on screen
- Card shows a flat-lay style arrangement: top item, bottom item, shoes arranged vertically inside the card
- Occasion badge: "Casual" chip top-left of card
- Score badge: "92" in orange circle top-right of card
- Below card: left arrow (reject/red tint hint) and right arrow (save/green tint hint) -- or just show the swipe gesture hint
- Bottom: "Shuffle again" ghost button
- Tinder-style feel but for outfits

---

#### Screen 14: Lookbooks Grid
- Bottom nav visible, "Lookbooks" tab active (orange)
- Top bar: "Lookbooks" heading left
- 2-column grid of lookbook cover cards:
  - Each card: 3:4 aspect ratio, rounded 16px
  - Cover image: mini grid of the first outfit's item photos (2x2 tiny thumbnails)
  - Dark gradient overlay at bottom
  - Lookbook name in white bold text at bottom: "Work Fits", "Weekend Vibes", "Party Ready", "Festival Looks"
  - Outfit count badge: "12 outfits" in small white text
- Last grid position: "+" card (dashed border, gray plus icon, "New Lookbook" label)
- Show 4-5 lookbook cards + the "+" card

---

#### Screen 15: Lookbook Detail
- Back arrow + lookbook name as title ("Work Fits")
- Outfit count: "12 outfits" in gray subtitle
- Vertical list of outfit cards (same format as Today's Outfits cards from Screen 12)
- Each card shows the circular item photos + AI reason + action buttons
- Clean scrollable list

---

#### Screen 16: Profile Screen
- Bottom nav visible, "Profile" tab active (orange)
- Top section:
  - User avatar circle (large, 72px) with initials or photo
  - User name: "Avinash" -- heading
  - Plan badge: "Free" chip or "Pro" chip in orange
  - [Edit profile] small ghost button
- Section 1 -- **Style Profile:**
  - Card showing quiz results as small chips (Minimalist, Casual, Neutrals, Regular, Mumbai)
  - "Retake quiz" link in orange
- Section 2 -- **Wardrobe Stats:**
  - Clean stat row: "24 Items" | "18 Outfits Saved" | "73% Utilization"
  - Each stat with a number above and label below
- Section 3 -- **Settings list:**
  - Morning outfit notification -- toggle switch (orange when on)
  - Appearance -- "Light" (only option for now)
  - About DrapeAI -- arrow right
  - Terms & Privacy -- arrow right
  - Help & Feedback -- arrow right
- Bottom:
  - [Sign out] ghost button, gray text
  - [Delete account] ghost button, red text

---

#### Screen 17: 3-Upload Trigger (Bottom Sheet)
- This is a bottom sheet overlay on top of the Wardrobe Grid
- Slides up from bottom, rounded top corners
- Content:
  - Small confetti/sparkle icon
  - "Your first outfit is ready!" -- heading
  - "We've created 3 outfit suggestions from your items" -- gray subtitle
  - [See my outfits] primary button, full width
- Background: wardrobe grid dimmed/blurred behind

---

#### Screen 18: Search (Wardrobe)
- Top: expanded search bar with text input, back arrow, clear (X) button
- Below: real-time filtered results in the same 3-column grid
- Show search for "kurta" with 3-4 matching items highlighted
- If no results: "No items match 'xyz'" empty state

---

### DESIGN INSTRUCTIONS

1. Design each screen as a separate, clearly labeled frame/artboard
2. Use realistic placeholder clothing photos (kurtas, shirts, jeans, sneakers, sarees -- mix of Western and Indian ethnic wear)
3. Keep spacing generous -- this is a premium app, not a cluttered marketplace
4. Every interactive element should be obvious (buttons look tappable, chips look toggleable)
5. Show the iPhone status bar (time, signal, battery) at the top of every screen for realism
6. Use the orange accent (#F97316) sparingly -- only for AI elements, active states, and key CTAs
7. The overall feeling should be: "this app was designed by someone who uses Linear and reads Monocle"
8. No gradients on backgrounds. No glassmorphism. No dark mode. Flat and clean.
9. Group the screens in this order: Auth flow (1-3) -> Onboarding (4-5) -> Core wardrobe (6-11) -> Outfit experience (12-13) -> Collections (14-15) -> Profile (16) -> Overlays (17-18)

---

### EXPORT NOTE

After design is complete, I will need:
- Handoff bundle for Claude Code (to implement in Flutter)
- PDF export of all screens for reference
- Individual screen exports for App Store screenshots
