# DrapeAI -- Store Submission Guide

Step-by-step for publishing to Google Play Store and Apple App Store. Covers signing, building, screenshots, listing copy, review guidelines, and common rejection reasons.

---

## Table of Contents

- [1. Pre-Submission Checklist](#1-pre-submission-checklist)
- [2. Google Play Store](#2-google-play-store)
- [3. Apple App Store](#3-apple-app-store)
- [4. App Store Listing Copy](#4-app-store-listing-copy)
- [5. Screenshots and Graphics](#5-screenshots-and-graphics)
- [6. Privacy Policy and Terms](#6-privacy-policy-and-terms)
- [7. Common Rejection Reasons](#7-common-rejection-reasons)
- [8. Post-Launch Updates](#8-post-launch-updates)

---

## 1. Pre-Submission Checklist

Complete ALL of these before submitting to either store:

- [ ] App icon: 1024x1024px PNG, no transparency, no rounded corners (stores add rounding)
- [ ] Splash screen works on all screen sizes
- [ ] All screens tested on:
  - [ ] Small phone (5" -- e.g., iPhone SE, Pixel 4a)
  - [ ] Medium phone (6.1" -- e.g., iPhone 15, Pixel 8)
  - [ ] Large phone (6.7" -- e.g., iPhone 15 Pro Max, Pixel 8 Pro)
- [ ] Camera permission request shows clear rationale ("DrapeAI needs camera access to photograph your clothes")
- [ ] Photo library permission request shows clear rationale
- [ ] Notification permission request (iOS: asked at appropriate moment, not on first launch)
- [ ] Internet connectivity: graceful offline handling (show cached data or "No connection" screen)
- [ ] All API endpoints return proper errors, never crash the app
- [ ] No test data, lorem ipsum, or placeholder images
- [ ] Version number set: `1.0.0+1` in `pubspec.yaml`
- [ ] Bundle ID set:
  - Android: `app.drapeai.android`
  - iOS: `app.drapeai.ios`
- [ ] Privacy policy URL live and accessible
- [ ] Terms of service URL live and accessible
- [ ] Firebase Analytics (or alternative) integrated for crash reporting
- [ ] Deep links configured and tested
- [ ] No hardcoded API keys in client code
- [ ] ProGuard / R8 configured for Android release build
- [ ] App size < 100 MB (target < 50 MB)

---

## 2. Google Play Store

### 2.1 Developer Account

1. Go to https://play.google.com/console
2. Create account: $25 one-time fee
3. Complete identity verification (takes 1-3 days)
4. Set up payment profile (for future in-app purchases)

### 2.2 Android Signing

**Generate upload key (one time, keep this safe forever):**

```bash
keytool -genkey -v \
  -keystore ~/drapeai-upload-key.jks \
  -keyalg RSA -keysize 2048 \
  -validity 10000 \
  -alias drapeai-upload

# Enter password, name, organization when prompted
# SAVE THE PASSWORD AND KEYSTORE FILE SECURELY
```

**Configure in Flutter:**

Create `app/android/key.properties` (DO NOT commit to git):
```properties
storePassword=<your-password>
keyPassword=<your-password>
keyAlias=drapeai-upload
storeFile=/Users/avinash/drapeai-upload-key.jks
```

Update `app/android/app/build.gradle`:
```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    ...
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

Add to `.gitignore`:
```
android/key.properties
*.jks
```

### 2.3 Build Android App Bundle

```bash
cd app

# Clean build
flutter clean
flutter pub get

# Build release AAB (App Bundle, required by Play Store)
flutter build appbundle --release

# Output: app/build/app/outputs/bundle/release/app-release.aab
```

### 2.4 Play Console Setup

1. **Create app:** Play Console > Create app
   - App name: "DrapeAI - AI Outfit Assistant"
   - Default language: English (India)
   - App type: App (not Game)
   - Free or paid: Free

2. **Store listing:**
   - Short description (80 chars): "AI stylist that creates outfits from your wardrobe"
   - Full description (4000 chars): See section 4 below
   - Screenshots: See section 5
   - Feature graphic: 1024x500px
   - App icon: 512x512px (uploaded separately)

3. **Content rating:**
   - Fill out IARC questionnaire
   - Expected rating: Everyone / 3+
   - No violence, no gambling, no user-generated content sharing (in MVP)

4. **Target audience:**
   - Age: 18-65+
   - Not designed for children under 13

5. **App content:**
   - Privacy policy URL: `https://drapeai.app/privacy`
   - Ads: No
   - Government apps: No

6. **Data safety:**
   - Data collected: Phone number (auth), Photos (wardrobe), Location (city for weather)
   - Data shared: None
   - Data encrypted in transit: Yes
   - Data deletion: User can delete account (delete all data)

7. **Release:**
   - Create internal testing track first (invite 20 testers by email)
   - After testing: Create production release
   - Upload AAB
   - Set rollout: 100% (or staged: 20% -> 50% -> 100%)
   - Submit for review

### 2.5 Review Timeline

- Internal testing: Available immediately (no review)
- Closed testing: 1-3 days review
- Production: 1-7 days review (first submission can take longer)

---

## 3. Apple App Store

### 3.1 Developer Account

1. Go to https://developer.apple.com
2. Enroll in Apple Developer Program: $99/year
3. Complete enrollment (if individual: takes 24-48 hours)

### 3.2 iOS Signing and Certificates

**In Xcode (one-time setup):**

1. Open `app/ios/Runner.xcworkspace` in Xcode
2. Select "Runner" target
3. Go to "Signing & Capabilities" tab
4. Team: Select your Apple Developer account
5. Bundle Identifier: `app.drapeai.ios`
6. Check "Automatically manage signing"
7. Xcode will create:
   - Development certificate
   - Distribution certificate
   - Provisioning profiles

**If automatic signing fails:**

```bash
# Manual steps (rarely needed)
# 1. Apple Developer > Certificates > Create distribution certificate
# 2. Apple Developer > Identifiers > Create App ID: app.drapeai.ios
# 3. Apple Developer > Profiles > Create distribution profile
# 4. Download and double-click to install
```

### 3.3 Capabilities and Permissions

In `app/ios/Runner/Info.plist`, ensure these keys exist:

```xml
<!-- Camera access -->
<key>NSCameraUsageDescription</key>
<string>DrapeAI needs camera access to photograph your clothes for wardrobe management.</string>

<!-- Photo library access -->
<key>NSPhotoLibraryUsageDescription</key>
<string>DrapeAI needs photo library access to import clothing photos from your gallery.</string>

<!-- Push notifications -->
<!-- Handled by Firebase SDK, but ensure Push Notifications capability is added in Xcode -->
```

In Xcode > Runner > Signing & Capabilities:
- Add "Push Notifications" capability
- Add "Background Modes" > "Remote notifications" (for FCM)

### 3.4 Build iOS

```bash
cd app

flutter clean
flutter pub get

# Build iOS release
flutter build ios --release

# Open Xcode for archiving
open ios/Runner.xcworkspace
```

In Xcode:
1. Select "Any iOS Device" as build target (not a simulator)
2. Product > Archive
3. Wait for archive to complete
4. Organizer window opens automatically
5. Click "Distribute App"
6. Select "App Store Connect"
7. Upload

### 3.5 App Store Connect Setup

1. Go to https://appstoreconnect.apple.com
2. My Apps > "+" > New App
   - Platform: iOS
   - Name: "DrapeAI - AI Outfit Assistant"
   - Primary language: English
   - Bundle ID: Select `app.drapeai.ios`
   - SKU: `drapeai-ios-001`

3. **App Information:**
   - Category: Lifestyle
   - Secondary category: Shopping (optional)
   - Content rights: Does not contain third-party content
   - Age rating: 4+ (fill out questionnaire)

4. **Pricing and Availability:**
   - Price: Free
   - Availability: All countries (or select India only for initial launch)

5. **App Privacy:**
   - Privacy policy URL: `https://drapeai.app/privacy`
   - Data types collected:
     - Contact Info: Phone number (for account creation)
     - Photos: User clothing photos (for app functionality)
     - Location: City name (for weather, not precise location)
     - Identifiers: User ID
     - Usage Data: App interactions (analytics)
   - For each: "Used for App Functionality", "Linked to Identity"

6. **Version Information:**
   - Screenshots: See section 5
   - Description: See section 4
   - Keywords: "outfit, wardrobe, AI stylist, fashion, clothes, ethnic wear, kurta, saree"
   - Support URL: `https://drapeai.app/support`
   - Marketing URL: `https://drapeai.app`

7. **Build:**
   - Select the uploaded build from Xcode
   - Submit for review

### 3.6 TestFlight (Beta Testing)

Before production submission:

1. App Store Connect > TestFlight
2. After uploading a build, it becomes available in TestFlight within 1-2 hours
3. Add internal testers (your Apple ID, team members) -- no review needed
4. Add external testers (up to 10,000) -- requires brief review (1-2 days)
5. Testers install TestFlight app and access the beta

### 3.7 Review Timeline

- TestFlight (internal): Immediate
- TestFlight (external): 1-2 days
- App Store production: 1-3 days (can take up to 7 days for first submission)

---

## 4. App Store Listing Copy

### App Name
```
DrapeAI - AI Outfit Assistant
```

### Short Description (Google Play, 80 chars)
```
AI stylist that creates daily outfits from your own wardrobe. Built for India.
```

### Full Description

```
DrapeAI is your personal AI stylist. Photograph your clothes, and the AI creates
outfit combinations you never thought of -- including ethnic, fusion, and western looks.

WHAT DRAPEAI DOES

Upload your clothes
Snap a photo of each item. AI removes the background and tags it automatically --
category, color, fabric, style, formality. Works with kurtas, sarees, t-shirts,
jeans, and everything in between.

Get AI outfit recommendations
Every day, DrapeAI suggests 3 outfits from YOUR wardrobe. Weather-aware.
Occasion-based: casual, work, party, date, festive. Thumbs up or down to teach
the AI your taste.

Shuffle for surprises
One tap. Random outfit. Swipe right to save, left to skip. Rediscover clothes
you forgot you owned.

Save to lookbooks
Organize your favorite outfits: Work, Weekend, Party, Travel. Your personal
style library.

BUILT FOR INDIA

Full ethnic wear support: saree, kurta, lehenga, sherwani, dhoti, dupatta.
AI understands fusion styling: kurta + jeans + sneakers works. Sherwani + jeans
does not. No other app does this.

Weather-aware for Indian climates -- from Mumbai monsoons to Delhi winters.

WHY DRAPEAI

- Uses what you ALREADY own. No shopping required.
- AI gets smarter with your feedback.
- Clean, fast, minimal design.
- Works offline for browsing your wardrobe.
- Your data stays private. No social sharing required.

COMING SOON

- AI chat stylist: ask "What should I wear to a wedding?"
- Personal color analysis
- Trip packing planner
- Import from Myntra and Ajio purchase history

Download DrapeAI and find out what your wardrobe can really do.
```

### Keywords (App Store, comma-separated, 100 char limit)
```
outfit,wardrobe,AI stylist,fashion,clothes,ethnic,kurta,saree,daily outfit,style
```

---

## 5. Screenshots and Graphics

### Google Play Store requirements

| Asset | Size | Count |
|---|---|---|
| Phone screenshots | 1080x1920px (or 1284x2778px) | 2-8 (minimum 2) |
| Feature graphic | 1024x500px | 1 |
| App icon | 512x512px | 1 |

### Apple App Store requirements

| Device | Size | Count |
|---|---|---|
| iPhone 6.7" (15 Pro Max) | 1290x2796px | 3-10 |
| iPhone 6.1" (15) | 1179x2556px | 3-10 (optional if 6.7" provided) |

### Screenshot content plan (6 screenshots, in order)

1. **Wardrobe grid** -- "Your entire wardrobe, organized" -- show a clean grid of 20+ items
2. **AI outfit recommendation** -- "AI picks your outfit daily" -- show 3 outfit cards with reason text
3. **Outfit shuffle** -- "Swipe to discover" -- show the Tinder-style card deck
4. **Ethnic wear support** -- "Saree to sneakers, AI gets it" -- show ethnic + fusion outfit
5. **Photo upload + tagging** -- "Snap, tag, done" -- show camera + tag chips
6. **Lookbooks** -- "Save your best looks" -- show lookbook grid

### Screenshot design style

- White or very light gray background
- Device frame: use a modern device mockup (iPhone 15 / Pixel 8)
- Headline text above the device: Inter Bold 48px, #111827
- Subheadline: Inter Regular 24px, #6B7280
- No cluttered marketing text. One headline per screenshot.
- Use actual app screenshots (not mockups of the UI)

### Tools for creating screenshots

- **Figma** (free): Create frames at exact sizes, add device mockups
- **screenshots.pro** (free): Upload screenshots, auto-add device frames
- **LaunchMatic** (paid): AI-generated store screenshots

---

## 6. Privacy Policy and Terms

### Privacy Policy (required by both stores)

Host at `https://drapeai.app/privacy`. Must cover:

1. **What data we collect:**
   - Phone number (for authentication via OTP)
   - Email (if signing in with Google)
   - Photos of clothing items (stored in cloud)
   - City/location (for weather-based recommendations, not GPS tracking)
   - App usage data (which features used, for improving the product)

2. **How we use data:**
   - Clothing photos: processed by AI for tagging, stored for wardrobe management
   - Phone/email: authentication only, never shared
   - City: weather API calls for outfit recommendations
   - Usage data: aggregate analytics, no individual tracking sold

3. **Third-party services:**
   - Firebase (Google) for authentication and push notifications
   - OpenAI for AI image analysis (images sent to OpenAI API)
   - Cloudflare for image storage
   - OpenWeatherMap for weather data

4. **Data retention:**
   - Account data kept until user deletes account
   - Photos deleted within 30 days of account deletion
   - Analytics data anonymized after 12 months

5. **User rights:**
   - Right to delete account and all data
   - Right to export wardrobe data (future feature)
   - Contact: privacy@drapeai.app

6. **Children's privacy:**
   - Not intended for users under 13

### Terms of Service

Host at `https://drapeai.app/terms`. Standard terms covering:
- Acceptable use
- Intellectual property (user owns their photos)
- Limitation of liability
- Account termination

### Where to host

Simplest: create a single-page site on Cloudflare Pages or GitHub Pages.

```
drapeai.app/          -- landing page (can be minimal at launch)
drapeai.app/privacy   -- privacy policy
drapeai.app/terms     -- terms of service
drapeai.app/support   -- contact email or form
```

---

## 7. Common Rejection Reasons

### Google Play

| Reason | How to avoid |
|---|---|
| Missing privacy policy | Ensure URL is live and linked in store listing AND in-app settings |
| Requesting unnecessary permissions | Only request camera + photos + notifications. No location (you use city name, not GPS) |
| Misleading description | Screenshots must match actual app. No "coming soon" features shown |
| Broken functionality | Test on at least 3 different Android versions (12, 13, 14) |
| Data safety form incomplete | Fill out every field accurately |

### Apple App Store

| Reason | How to avoid |
|---|---|
| Guideline 2.1 -- App Completeness | No placeholder content, no demo-only features, no broken links |
| Guideline 4.0 -- Design (minimum functionality) | App must do something meaningful. Our MVP is well beyond minimum |
| Guideline 5.1.1 -- Data Collection (privacy) | List ALL data collected in App Privacy. OpenAI usage must be disclosed |
| Guideline 5.1.2 -- Data Use and Sharing | If sending photos to OpenAI, disclose this clearly |
| Login required | Must provide a way for reviewers to test. Include a test account in review notes |
| Push notification permission timing | Do NOT ask for push permission on first launch. Ask after user has used the app (e.g., after first outfit generation) |

### Apple review notes (include with submission)

```
Test account:
Phone: +91 9999900000
OTP: 123456 (test mode)

Or use Google Sign-In with: test@drapeai.app / password123

The app requires uploading clothing photos. We have included a "Demo wardrobe"
feature (accessible from the welcome screen) that loads 20 pre-tagged items so
reviewers can test outfit generation without uploading photos.

Primary functionality: AI-powered outfit recommendation from user's wardrobe.
Clothing photos are sent to OpenAI's API for automated tagging (disclosed in
privacy policy). No user data is shared with third parties for advertising.
```

---

## 8. Post-Launch Updates

### Version numbering

```
Major.Minor.Patch+BuildNumber
1.0.0+1   -- initial release
1.0.1+2   -- bug fix
1.1.0+3   -- calendar + analytics (v1.1)
2.0.0+10  -- chat stylist, pro subscription (v2)
```

### Update frequency

- First 2 weeks: daily bug fix releases if needed (be responsive)
- After stabilization: bi-weekly updates
- Major versions: per roadmap

### Staged rollout (Google Play)

```
1. Upload new AAB
2. Create release in Production track
3. Set rollout: 10%
4. Monitor crash reports for 24 hours
5. If clean: increase to 50%
6. 24 hours later: 100%
```

### App Store phased release (Apple)

1. In App Store Connect, enable "Phased Release"
2. Apple automatically rolls out to 1% -> 2% -> 5% -> 10% -> 20% -> 50% -> 100% over 7 days
3. You can pause or accelerate at any time
