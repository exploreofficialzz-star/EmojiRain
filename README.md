# 🎮 Emoji Rain: Focus or Fail

A fast-paced, addictive Flutter mobile game where players tap the correct falling emojis while ignoring distractions. Built for Android & iOS with full AdMob monetization and local notifications.

---

## 📦 Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) — stable channel |
| State | Provider |
| Ads | Google Mobile Ads (AdMob) |
| Audio | audioplayers |
| Notifications | flutter_local_notifications |
| Animations | flutter_animate |
| Storage | shared_preferences |
| CI/CD | GitHub Actions |

---

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (stable channel) — `flutter channel stable && flutter upgrade`
- Android Studio / Xcode for device testing
- Java 17

```bash
# Clone
git clone https://github.com/YourOrg/emoji_rain.git
cd emoji_rain

# Install dependencies
flutter pub get

# Generate launcher icons
flutter pub run flutter_launcher_icons

# Run on connected device
flutter run
```

---

## 💰 AdMob Setup (REQUIRED before publishing)

The project ships with **Google's official test Ad IDs**. You MUST replace them before going live.

### Step 1 — Get your AdMob App IDs
1. Go to [admob.google.com](https://admob.google.com)
2. Create an app for Android and one for iOS
3. Note your **App IDs** (format: `ca-app-pub-XXXXXXXXXX~XXXXXXXXXX`)

### Step 2 — Replace App IDs

**Android** — `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-YOUR_ANDROID_APP_ID"/>
```

**iOS** — `ios/Runner/Info.plist`:
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-YOUR_IOS_APP_ID</string>
```

### Step 3 — Replace Ad Unit IDs

In `lib/constants/app_constants.dart`, replace all values inside `AdIds`:
```dart
static String get banner      => 'ca-app-pub-XXXX/YYYY';
static String get interstitial => 'ca-app-pub-XXXX/YYYY';
static String get rewarded     => 'ca-app-pub-XXXX/YYYY';
```

---

## 🔔 Notifications

Notifications use the **device's default system sound** — no custom audio file needed.  
They are wired for:
- **Daily reminder** at 8 PM (repeating)
- **Come-back nudge** 4 hours after the player closes the app

No extra setup needed. Works out of the box.

---

## 🤖 GitHub Actions CI/CD

The workflow (`.github/workflows/build.yml`) automatically builds:

| Trigger | Output |
|---|---|
| Pull Request | Debug APK |
| Push to `main` | Debug APK + Release APK + Release AAB |
| Git tag `v*.*.*` | All of above + GitHub Release |

### Required GitHub Secrets (for signed release builds)

Go to **Settings → Secrets and Variables → Actions** in your repo:

| Secret | Description |
|---|---|
| `KEYSTORE_BASE64` | Base64-encoded `.jks` keystore file |
| `KEY_ALIAS` | Key alias inside the keystore |
| `KEY_PASSWORD` | Key password |
| `STORE_PASSWORD` | Keystore password |
| `IOS_CERT_BASE64` | Base64-encoded `.p12` signing certificate |
| `IOS_CERT_PASSWORD` | Certificate password |
| `IOS_PROVISIONING_BASE64` | Base64-encoded `.mobileprovision` file |

### Generate keystore (Android)
```bash
keytool -genkey -v \
  -keystore emoji_rain.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias emoji_rain

# Encode for GitHub secret
base64 -i emoji_rain.jks | pbcopy   # macOS
base64 emoji_rain.jks               # Linux
```

> **Note:** Without secrets set, the workflow builds an **unsigned release APK** — valid for testing but not for store submission.

---

## 🗂 Project Structure

```
lib/
├── constants/
│   ├── app_constants.dart    # Colors, text styles, AdMob IDs, game tuning
│   └── emoji_data.dart       # Emoji pools, level configs, fail messages
├── models/
│   └── emoji_item.dart       # Falling emoji data model
├── providers/
│   └── game_provider.dart    # Core game state machine + game loop
├── screens/
│   ├── home_screen.dart      # Home / main menu
│   ├── game_screen.dart      # Live gameplay
│   └── game_over_screen.dart # Game over with ads + retry
├── services/
│   ├── ad_service.dart       # Banner / Interstitial / Rewarded ad management
│   ├── audio_service.dart    # Sound effects singleton
│   └── notification_service.dart  # Local notifications
├── widgets/
│   ├── falling_emoji_widget.dart  # Tappable falling emoji + score popup
│   ├── rule_display.dart          # Rule banner + level-up overlay
│   └── score_hud.dart             # Lives / score / combo HUD
└── main.dart
```

---

## 🎮 Gameplay

- Emojis fall from the top — tap correct ones, avoid wrong ones
- Wrong tap = **instant game over**
- 10 levels, each with a unique rule (tap specific emoji, avoid a category, etc.)
- Combo multiplier: 2× at 5 streak, 3× at 15, 5× at 30, 10× at 60
- Rewarded ad lets the player continue after game over
- Interstitial shown every 3 fails

---

## 📱 Build Commands

```bash
# Android
flutter build apk --release          # APK
flutter build appbundle --release     # AAB for Play Store

# iOS
flutter build ios --release --no-codesign    # Unsigned
flutter build ipa --release                  # With signing
```

---

## 📝 License

© 2025 ChAs Tech Group. All rights reserved.
