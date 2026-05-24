# MUHAFIZ — PROJECT BRIEF FOR AI ASSISTANT
## Complete Context — Updated with Final Design & WhatsApp Gateway

---

> **HOW TO USE THIS DOCUMENT**
> You are an AI coding assistant. The user is a Flutter developer (guided by an instructor) building a personal safety app called **Muhafiz**. All decisions — tech stack, architecture, feature scope, naming, design — have already been finalised. **Do not re-debate or suggest alternatives unless explicitly asked.** Your job is to write production-quality code, explain it clearly, and move the project forward one piece at a time.

---

## 1. WHAT IS MUHAFIZ

**Muhafiz (محافظ)** means *Guardian / Protector* in Urdu.

A cross-platform mobile safety app (Flutter, Android + iOS) designed primarily for women in Pakistan who need a fast, low-friction way to alert trusted contacts and emergency services when they feel unsafe or face a real emergency.

Core principle: **the user must be able to send an alert within 2 taps.** Trustees (trusted contacts) receive alerts via **WhatsApp** — no special app required on their end.

---

## 2. VERSION 1 SCOPE

### Included in v1:
- WhatsApp OTP registration and login
- User onboarding (name, gender, city)
- Home screen with two core action buttons:
  - **Safe Track** — notifies trustees of your location, low-urgency tone
  - **SOS** — high-urgency alert to all trustees + triggers emergency phone call with OS confirmation dialog
- Contacts screen — manage trustees, add from device phonebook
- Settings screen — profile edit, emergency number, logout

### Explicitly NOT in v1 (deferred to v2):
- Home screen widget
- Hardware trigger (volume / shake)
- Background audio/video recording
- Continuous location loop
- Push notifications

---

## 3. FINALISED TECH STACK — DO NOT CHANGE THESE

### Mobile (Flutter)
| Concern | Package | Version |
|---|---|---|
| State management | flutter_riverpod | ^2.5.1 |
| Navigation | go_router | ^13.2.0 |
| HTTP client | dio | ^5.4.3 |
| Secure token storage | flutter_secure_storage | ^9.2.2 |
| Local cache | hive_flutter | ^1.1.0 |
| Firebase | firebase_core + cloud_firestore | latest |
| Location | geolocator | ^11.1.0 |
| Permissions | permission_handler | ^11.3.1 |
| Device contacts | flutter_contacts | ^1.1.9+1 |
| Emergency call | url_launcher | ^6.3.0 |
| Phone formatting | phone_numbers_parser | ^5.0.4 |
| OTP input UI | pinput | ^4.0.0 |

### Backend (Node.js)
| Concern | Package | Notes |
|---|---|---|
| Framework | express | REST API |
| JWT | jsonwebtoken | access (15min) + refresh (30d) |
| Firebase Admin | firebase-admin | Firestore writes |
| WhatsApp gateway | whatsapp-web.js | See Section 7 for full setup |
| QR code display | qrcode-terminal | Show QR in terminal for WA auth |
| Environment | dotenv | |

### Infrastructure
| Concern | Choice |
|---|---|
| Database | Firebase Firestore |
| Backend hosting | Railway.app |
| WhatsApp | whatsapp-web.js (self-hosted bot on the backend server) |
| OTP store | In-memory Map in Node.js (v1) |
| Auth | Custom JWT |

---

## 4. DESIGN SYSTEM — FINAL, DO NOT CHANGE

This is the complete and final visual identity for Muhafiz. Every screen must follow these rules.

### Colour Palette
```
Primary Red      #F92A2A   → Splash background, all buttons, SOS button, active states
White            #FFFFFF   → Overall app background, logo colour, button text
Black            #000000   → All body text, headings, icons
Input Field      rgba(0,0,0,0.50)  → Input border and label text (50% black)
Input Fill       #F5F5F5   → Light grey input field background
Dividers/Subtle  rgba(0,0,0,0.10)  → Dividers, subtle borders
```

### Rules by Element
```
Splash screen          → Full #F92A2A background, white Muhafiz logo centred
All primary buttons    → #F92A2A background, white text, rounded corners (12px)
Disabled buttons       → rgba(249,42,42,0.40) background, white text
SOS button             → #F92A2A, large, full-width, bold white text "SOS"
Safe Track button      → White background, #F92A2A border (1.5px), #F92A2A text
                          (Safe Track is secondary — red on white, not filled red)
App background         → #FFFFFF on all screens except Splash
Navigation bar         → White background, black icons, #F92A2A for active icon
Text: headings         → Black #000000, bold
Text: body             → Black #000000, regular weight
Text: secondary/hint   → rgba(0,0,0,0.50)
Input field border     → rgba(0,0,0,0.50) default, #F92A2A on focus
Input field fill       → #F5F5F5
Input label            → rgba(0,0,0,0.50) floating label
OTP boxes (Pinput)     → White fill, rgba(0,0,0,0.50) border, #F92A2A border on focus
Logo                   → Always white on red backgrounds, red on white backgrounds
```

### Typography
```
Font family     → Inter (Google Fonts)
Heading large   → Inter 28px Bold
Heading medium  → Inter 22px SemiBold
Body            → Inter 16px Regular
Body small      → Inter 14px Regular
Button text     → Inter 16px SemiBold
Input label     → Inter 14px Medium
Caption/hint    → Inter 12px Regular
```

### Flutter ThemeData Setup
```dart
ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Color(0xFFF92A2A),
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: Colors.white,
  fontFamily: 'Inter',
  useMaterial3: true,
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontFamily: 'Inter',
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Colors.black,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Color(0xFFF92A2A),
      foregroundColor: Colors.white,
      minimumSize: Size(double.infinity, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Color(0xFFF5F5F5),
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.black54),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.black54),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Color(0xFFF92A2A), width: 1.5),
    ),
    labelStyle: TextStyle(color: Colors.black54, fontFamily: 'Inter'),
    hintStyle: TextStyle(color: Colors.black38, fontFamily: 'Inter'),
  ),
)
```

---

## 5. ARCHITECTURE OVERVIEW

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter App                            │
│  Splash → Register → OTP → Onboarding → Home               │
│                              ↕ bottom nav                   │
│                         Home | Contacts | Settings          │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTPS REST + Bearer JWT
                           ▼
┌─────────────────────────────────────────────────────────────┐
│           Node.js + Express  (Railway.app)                  │
│                                                             │
│  /auth   → OTP logic, JWT issuance                          │
│  /user   → profile CRUD                                     │
│  /trustees → trustee CRUD                                   │
│  /alerts → safe-track, SOS dispatch                         │
│  /wa-status → check WhatsApp bot connection status          │
│                                                             │
│  ┌─────────────────────────────────────────────┐            │
│  │         whatsapp-web.js Client              │            │
│  │  - Authenticates via QR scan (one-time)     │            │
│  │  - Sends plain text messages to any number  │            │
│  │  - Maintains session via .wwebjs_auth/       │            │
│  └─────────────────────────────────────────────┘            │
└──────────────┬───────────────────────────────────────────────┘
               │
     ┌─────────┴──────────┐
     ▼                    ▼
Firebase Firestore    WhatsApp (via wweb.js)
users/{uid}           Delivers to any WA number
users/{uid}/trustees  No template approval needed
users/{uid}/alerts    Plain text messages
```

---

## 6. DATABASE SCHEMA (FIRESTORE)

```
users/
  {uid}/
    phone:         string   "+923001234567" (E.164, unique)
    name:          string   "Ayesha Khan"
    gender:        string   "female" | "male" | "prefer_not_to_say"
    city:          string   "Lahore" (optional)
    emergency_no:  string   "15" (default)
    created_at:    timestamp
    updated_at:    timestamp

    trustees/
      {trustee_id}/
        name:      string   "Ammi"
        phone:     string   "+923009876543"
        added_at:  timestamp

    alerts/
      {alert_id}/
        type:      string   "safe_track" | "sos"
        lat:       number
        lng:       number
        trustees_notified: number
        created_at: timestamp
```

---

## 7. WHATSAPP-WEB.JS SETUP — FULL DETAIL

**What it is:** whatsapp-web.js is a Node.js library that controls a WhatsApp Web session programmatically. You link a real WhatsApp number to it by scanning a QR code once. After that, the bot can send messages to any WhatsApp number as if a human typed them.

**No template approval needed. No Meta account needed. Messages are plain text.**

### Install
```bash
npm install whatsapp-web.js qrcode-terminal
```

### src/services/whatsapp.js — Full implementation
```javascript
const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode-terminal');

let clientReady = false;

const client = new Client({
  authStrategy: new LocalAuth({
    dataPath: './.wwebjs_auth'   // persists session so QR only needed once
  }),
  puppeteer: {
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',     // important for Railway/Linux
      '--disable-accelerated-2d-canvas',
      '--no-first-run',
      '--no-zygote',
      '--single-process',
      '--disable-gpu'
    ]
  }
});

client.on('qr', (qr) => {
  console.log('\n\n========================================');
  console.log('Scan this QR code in WhatsApp:');
  console.log('WhatsApp → Linked Devices → Link a Device');
  console.log('========================================\n');
  qrcode.generate(qr, { small: true });
});

client.on('ready', () => {
  clientReady = true;
  console.log('✅ WhatsApp bot is ready and connected');
});

client.on('disconnected', (reason) => {
  clientReady = false;
  console.log('❌ WhatsApp disconnected:', reason);
  // Auto-reconnect after 5 seconds
  setTimeout(() => client.initialize(), 5000);
});

client.on('auth_failure', (msg) => {
  clientReady = false;
  console.error('WhatsApp auth failed:', msg);
});

// Format phone to WhatsApp chat ID: +923001234567 → 923001234567@c.us
function formatPhone(phone) {
  return phone.replace('+', '') + '@c.us';
}

async function sendMessage(phone, message) {
  if (!clientReady) {
    throw new Error('WhatsApp bot is not connected. Scan the QR code first.');
  }
  const chatId = formatPhone(phone);
  return client.sendMessage(chatId, message);
}

async function sendOTP(phone, otp) {
  const msg = `🔐 *Muhafiz Verification Code*\n\nYour OTP is: *${otp}*\n\nValid for 5 minutes. Do not share this code with anyone.`;
  return sendMessage(phone, msg);
}

async function sendSafeTrack(trusteeName, trusteePhone, senderName, lat, lng) {
  const mapsLink = `https://maps.google.com/?q=${lat},${lng}`;
  const msg = `🟡 *Muhafiz — Safe Track Alert*\n\nSalam ${trusteeName},\n\n*${senderName}* has activated Safe Track and may need your attention.\n\n📍 Current Location: ${mapsLink}\n\nPlease check in with them when you can.`;
  return sendMessage(trusteePhone, msg);
}

async function sendSOS(trusteeName, trusteePhone, senderName, lat, lng) {
  const mapsLink = `https://maps.google.com/?q=${lat},${lng}`;
  const msg = `🔴 *MUHAFIZ — EMERGENCY SOS*\n\n${trusteeName}, *${senderName}* NEEDS HELP RIGHT NOW!\n\n📍 Location: ${mapsLink}\n\nPlease call them immediately or contact emergency services (15 / 1122).`;
  return sendMessage(trusteePhone, msg);
}

function isReady() {
  return clientReady;
}

// Start the client immediately when this module is loaded
client.initialize();

module.exports = { sendOTP, sendSafeTrack, sendSOS, isReady };
```

### Important notes for Railway deployment:
1. Railway supports Puppeteer but needs the `--no-sandbox` flags (already included above)
2. Add `chromium` or `google-chrome-stable` as a dependency on Railway (add a `nixpacks.toml`):
```toml
# nixpacks.toml in project root
[phases.setup]
nixPkgs = ["chromium"]

[variables]
PUPPETEER_EXECUTABLE_PATH = "/run/current-system/sw/bin/chromium"
```
3. The `.wwebjs_auth/` folder persists the QR session. Add it to `.gitignore`. Railway's persistent volume or ephemeral filesystem means **you may need to re-scan QR on every deploy** unless you use Railway Volumes.
4. For development: run locally, scan the QR once, the session is saved in `.wwebjs_auth/`. The bot stays connected as long as the phone has internet.

### Add /wa-status endpoint (for debugging)
```javascript
// In src/routes/auth.js or a separate debug route
const { isReady } = require('../services/whatsapp');
router.get('/wa-status', (req, res) => {
  res.json({ connected: isReady() });
});
```

---

## 8. COMPLETE API REFERENCE

All protected endpoints require: `Authorization: Bearer <access_token>`

```
POST /auth/send-otp        (public) { phone }           → sends WA OTP
POST /auth/verify-otp      (public) { phone, otp }      → returns JWT pair + isNewUser
POST /auth/refresh         (public) { refreshToken }    → returns new accessToken
GET  /auth/wa-status       (public)                     → { connected: true|false }

GET  /user/profile         (JWT)                        → user object
PUT  /user/profile         (JWT) { name, gender, city, emergency_no }

GET  /trustees             (JWT)                        → [ { id, name, phone } ]
POST /trustees             (JWT) { name, phone }        → { id, name, phone }
DELETE /trustees/:id       (JWT)

POST /alerts/safe-track    (JWT) { lat, lng }           → { trustees_notified: N }
POST /alerts/sos           (JWT) { lat, lng }           → { trustees_notified: N }
```

---

## 9. BACKEND FOLDER STRUCTURE

```
muhafiz-backend/
  src/
    index.js
    config/
      firebase.js
    middleware/
      authMiddleware.js
    routes/
      auth.js          ← includes /wa-status
      user.js
      trustees.js
      alerts.js
    services/
      otp.js           ← in-memory OTP store
      whatsapp.js      ← whatsapp-web.js client (full code in Section 7)
  .wwebjs_auth/        ← WhatsApp session (gitignored)
  nixpacks.toml        ← Chromium for Railway
  .env
  .gitignore           ← include: .env, serviceAccountKey.json, .wwebjs_auth/
  package.json
```

### .env
```
PORT=3000
JWT_SECRET=<min 32 char random string>
JWT_REFRESH_SECRET=<different min 32 char random string>
FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccountKey.json
PUPPETEER_EXECUTABLE_PATH=/run/current-system/sw/bin/chromium
```

---

## 10. FLUTTER FOLDER STRUCTURE

```
lib/
  main.dart                     ← Firebase init, ProviderScope, ThemeData, Inter font
  router.dart                   ← GoRouter, auth redirect guard

  core/
    constants.dart              ← apiBase, AppColors (kRed, kWhite, kBlack, kInputBorder)
    dio_client.dart             ← Dio + JWT interceptor + auto-refresh
    secure_storage.dart         ← saveTokens, getAccessToken, getRefreshToken, clear

  models/
    user_model.dart
    trustee_model.dart

  providers/
    auth_provider.dart
    user_provider.dart
    trustees_provider.dart

  screens/
    splash_screen.dart          ← #F92A2A background, white logo, 2s then redirect
    register_screen.dart        ← phone input, red primary button
    otp_screen.dart             ← Pinput with red focus border
    onboarding_screen.dart      ← name + gender + city
    home_screen.dart            ← Safe Track card + SOS card + bottom nav
    contacts_screen.dart        ← trustee list + add from phonebook
    settings_screen.dart

  widgets/
    primary_button.dart         ← red bg, white text, full width, loading state
    outline_button.dart         ← white bg, red border, red text
    safe_track_button.dart      ← large white card, red border + red text + shield icon
    sos_button.dart             ← large red card, white text "SOS" + bold styling
    trustee_card.dart
    sos_countdown_dialog.dart   ← red countdown dialog, 5 seconds, cancel button
```

### core/constants.dart
```dart
import 'package:flutter/material.dart';

class AppColors {
  static const Color primary     = Color(0xFFF92A2A);   // Red
  static const Color white       = Color(0xFFFFFFFF);
  static const Color black       = Color(0xFF000000);
  static const Color inputBorder = Color(0x80000000);   // 50% black
  static const Color inputFill   = Color(0xFFF5F5F5);
  static const Color textHint    = Color(0x80000000);   // 50% black
  static const Color divider     = Color(0x1A000000);   // 10% black
}

class AppConstants {
  static const String apiBase = 'https://your-app.up.railway.app';
}
```

---

## 11. SCREEN-BY-SCREEN DESIGN SPECIFICATION

### Splash Screen
```
Background:     #F92A2A (full screen)
Center:         White Muhafiz logo (text or SVG)
                "محافظ" in white below logo
Duration:       2 seconds, then router redirect
Animation:      Simple fade-in on the logo
```

### Register Screen
```
Background:     White
Top area:       Red Muhafiz wordmark (small, top center)
                or red app icon
Heading:        "Enter your WhatsApp number" — Black Bold 22px
Subheading:     "We'll send you a verification code" — 50% black 14px
Input:          Phone number field, pre-filled with "+92"
                F5F5F5 fill, 50% black border, red focus border
Button:         "Send OTP" — full width, red, white text
```

### OTP Screen
```
Background:     White
Back button:    Black arrow top left
Heading:        "Verify your number" — Black Bold 22px
Sub:            "Enter the 6-digit code sent to [phone]" — 50% black
Pinput:         6 boxes, white fill, 50% black border, red active border
                Cursor colour: Red
Resend link:    "Didn't receive it? Resend" — red text, below Pinput
Button:         "Verify" — red, full width (or auto-submits on 6th digit)
```

### Onboarding Screen
```
Background:     White
Progress:       Simple red dot indicators at top (or step text "Step 1 of 1")
Heading:        "Tell us about yourself" — Black Bold 22px
Fields:         Name (text), Gender (dropdown), City (text, optional)
                All inputs: F5F5F5 fill, 50% black border
Button:         "Continue" — red, full width
```

### Home Screen
```
Background:     White
AppBar:         White, black "Muhafiz" wordmark, no elevation
Greeting:       "Assalam o Alaikum, [Name] 👋" — Black Bold 20px
Sub:            "Your trustees are ready." — 50% black 14px

Safe Track Card:
  Background:   White
  Border:       1.5px solid #F92A2A, border-radius 16px
  Icon:         Shield icon in #F92A2A
  Title:        "Safe Track" — #F92A2A Bold 18px
  Sub:          "Let your trustees know you may need attention"
                50% black 13px
  Full width, generous padding (20px)

SOS Card:
  Background:   #F92A2A
  Border-radius: 16px
  Icon:         Warning/alert icon in white
  Title:        "SOS" — White Bold 24px
  Sub:          "Send emergency alert + call for help"
                white 70% opacity 13px
  Full width, generous padding (20px)
  Slightly taller than Safe Track card to convey priority

Bottom Navigation:
  Background:   White, top border 10% black
  Items:        Home, Contacts, Settings
  Active icon:  #F92A2A
  Inactive:     50% black
```

### Contacts Screen
```
Background:     White
AppBar:         "Trustees" — Black Bold
                "+" add button in AppBar (red icon)
Empty state:    Centered illustration + "No trustees added yet"
                + red "Add Trustee" button
Trustee card:   White, subtle shadow or 10% black border
                Avatar circle: red bg, white initials
                Name: Black Bold 16px
                Phone: 50% black 14px
                Trailing: delete icon (50% black)
Add options:    Bottom sheet with two options:
                  "Pick from Contacts" (phone book icon)
                  "Add manually" (keyboard icon)
```

### Settings Screen
```
Background:     White
AppBar:         "Settings"
Sections:
  Profile       → Name, Gender, City (editable, red save button)
  Emergency     → "Emergency Number" dropdown: 15, 1122, 115, Custom
  About         → App version, "About Muhafiz"
  Account       → "Logout" button (red outline button, NOT filled red)
```

---

## 12. KEY FLOWS — LOGIC

### WhatsApp bot startup
When the Node.js server starts, `whatsapp.js` is required and `client.initialize()` runs immediately. If no saved session exists in `.wwebjs_auth/`, a QR code appears in the terminal. Scan it once with your dedicated WhatsApp number. After that the session persists.

### OTP flow
1. User enters phone (E.164 format, validate: `^\+[0-9]{10,15}$`)
2. POST /auth/send-otp → backend: generate 6-digit OTP, store with 5-min TTL, call `sendOTP(phone, otp)`
3. User receives WhatsApp message from bot number
4. POST /auth/verify-otp → backend validates, creates/finds Firestore user, returns JWT pair + isNewUser
5. Flutter saves tokens to FlutterSecureStorage
6. Route: isNewUser → /onboarding, else → /home

### Safe Track
1. Tap Safe Track card
2. Check/request location permission
3. Get GPS (LocationAccuracy.high)
4. POST /alerts/safe-track { lat, lng }
5. Backend fetches user name + trustees, sends WhatsApp to each via wweb.js (Promise.allSettled)
6. Show snackbar: "✅ Trustees notified"
7. Card shows green "Active" badge

### SOS
1. Tap SOS card
2. Show SOSCountdownDialog: red full-screen overlay, "5... 4... 3..." in white, CANCEL button
3. If cancelled → nothing
4. If countdown completes:
   - Get GPS
   - POST /alerts/sos ← fire-and-forget (no await)
   - IMMEDIATELY launchUrl(Uri.parse('tel:$emergencyNo'))
   - OS shows call confirmation dialog

### Dio JWT interceptor
- Attach `Authorization: Bearer <token>` to all requests
- On 401 → try POST /auth/refresh with refreshToken
- On success → save new accessToken, retry original request
- On refresh failure → clear SecureStorage → GoRouter redirect to /register

### GoRouter auth guard
```dart
redirect: (context, state) async {
  final token = await SecureStorage.getAccessToken();
  final loggedIn = token != null;
  final publicPaths = ['/splash', '/register', '/otp'];
  if (!loggedIn && !publicPaths.contains(state.matchedLocation))
    return '/register';
  if (loggedIn && state.matchedLocation == '/register')
    return '/home';
  return null;
},
```

---

## 13. ANDROID & IOS PERMISSIONS

### android/app/src/main/AndroidManifest.xml
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.READ_CONTACTS" />
<uses-permission android:name="android.permission.CALL_PHONE" />
<uses-permission android:name="android.permission.INTERNET" />
```

### ios/Runner/Info.plist
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Muhafiz needs your location to share with your trustees during Safe Track and SOS.</string>

<key>NSContactsUsageDescription</key>
<string>Muhafiz needs contacts access so you can add trustees from your address book.</string>
```

---

## 14. KNOWN GOTCHAS — READ CAREFULLY

1. **wweb.js needs Chromium on Railway** — without the `nixpacks.toml` (Section 7), Puppeteer will fail to launch on Railway's Linux containers. The `--no-sandbox` flags are mandatory.

2. **Session persistence on Railway** — the `.wwebjs_auth/` folder stores the QR session. Railway's filesystem is ephemeral on deploys, meaning you may need to re-scan QR after each deploy. For development this is fine. For production, mount a Railway Volume to persist `.wwebjs_auth/`.

3. **WhatsApp bot number must have an active phone** — the SIM card in the phone linked to the bot must have internet. This phone cannot be the same number the user is registering with.

4. **One WhatsApp session at a time** — if the linked phone opens WhatsApp Web on a browser, it will disconnect the bot. Keep the linked phone's WhatsApp to phone-only.

5. **Phone numbers must be E.164 everywhere** — `+923001234567` not `03001234567`. The `formatPhone()` function in whatsapp.js strips the `+` and adds `@c.us`. If the number has spaces or dashes, strip them before passing to the backend.

6. **Promise.allSettled not Promise.all** — in alerts.js, always use `Promise.allSettled` when sending to multiple trustees. If one number is invalid, others must still receive the alert.

7. **SOS HTTP request is fire-and-forget** — `DioClient.instance.post(...)` without `await` in the SOS flow. The emergency call must not wait for the network request.

8. **GoRouter redirect is async** — declare it as `async` and return `Future<String?>`. Forgetting this causes a type error at runtime.

9. **FlutterContacts normalizedNumber on iOS** — may not include the country code on iOS. After picking from contacts, show a confirmation screen where the user can review and edit the number before saving.

10. **OTP in-memory store is cleared on server restart** — acceptable for v1. If the server restarts mid-OTP, user gets "No OTP found" error and can simply request a new one.

11. **Inter font** — add `google_fonts: ^6.2.1` to Flutter dependencies, then use `GoogleFonts.inter(...)` or configure in ThemeData. Do NOT use the default Roboto.

12. **Red on red legibility** — the disabled button state uses `rgba(249,42,42,0.40)`. Never show a fully red disabled button with no text contrast change.

---

## 15. SUGGESTED BUILD ORDER

### Phase 1 — Backend
1. Init Node.js project, install dependencies, folder structure
2. `src/services/otp.js`
3. `src/config/firebase.js`
4. `src/services/whatsapp.js` ← full wweb.js implementation
5. `src/middleware/authMiddleware.js`
6. `src/routes/auth.js` (send-otp, verify-otp, refresh, wa-status)
7. `src/routes/user.js`
8. `src/routes/trustees.js`
9. `src/routes/alerts.js`
10. `src/index.js`
11. Test locally: start server, scan QR with your WhatsApp, test /auth/send-otp
12. Add `nixpacks.toml`, deploy to Railway

### Phase 2 — Flutter
1. Create project, pubspec.yaml with all dependencies
2. `core/constants.dart` (AppColors, AppConstants)
3. `core/secure_storage.dart`
4. `core/dio_client.dart` (Dio + interceptor)
5. `main.dart` (Firebase, ProviderScope, ThemeData with Inter and #F92A2A)
6. `router.dart` (GoRouter + auth guard)
7. `screens/splash_screen.dart` (red bg, white logo)
8. `screens/register_screen.dart` + `screens/otp_screen.dart`
9. `screens/onboarding_screen.dart`
10. `screens/home_screen.dart` (Safe Track card + SOS card)
11. `screens/contacts_screen.dart`
12. `screens/settings_screen.dart`
13. Test all flows end-to-end

---

## 16. CURRENT STATUS

**Nothing has been built yet.** All decisions are final. Start with Phase 1, Step 1.

---

*Muhafiz (محافظ) — Guardian*
*Flutter · Node.js · Firebase · whatsapp-web.js*
*Primary colour: #F92A2A · Pakistan · Personal Safety*
