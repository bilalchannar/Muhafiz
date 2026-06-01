# Muhafiz — Personal Safety App

Muhafiz is a personal safety mobile app built with Flutter. It lets users activate safety modes (Vulnerable and Emergency), manage trusted contacts, and authenticate via OTP sent through WhatsApp. The backend is split into two Node.js microservices: a main API server and a WhatsApp bot service.

---

## Features

- **Phone-based OTP authentication** — users register and verify their identity via a 6-digit OTP delivered through WhatsApp
- **Trusted contacts management** — add, view, and delete trusted contacts who can be notified in an emergency
- **Vulnerable mode** — a configurable low-level safety mode with a custom message and check-in interval
- **Emergency mode** — activates an emergency alert state with a countdown timer
- **Alert history** — view past safety alerts
- **Background service** — keeps the app running and responsive in the background (Android/iOS)
- **Push notifications** — local and Firebase Cloud Messaging notifications
- **Location permission flow** — guided permission request for location access
- **Admin dashboard** — a basic admin view for oversight (in progress)
- **Secure session storage** — session tokens are stored in secure (encrypted) storage on device

---

## Tech Stack

### Mobile App (`muhafiz/`)

| Layer | Technology |
|---|---|
| Framework | Flutter 3.41.1 / Dart 3.11.0 |
| State Management | flutter_riverpod |
| Firebase | firebase_core, firebase_auth, cloud_firestore, firebase_messaging |
| Local Notifications | flutter_local_notifications |
| Background Tasks | flutter_background_service |
| Location | geolocator, permission_handler |
| Secure Storage | flutter_secure_storage |
| Local Storage | shared_preferences |
| Networking | http |
| UI | Material 3, Inter font, flutter_svg |
| Home Widget | home_widget |

### Backend API (`muhafiz-backend/app/`)

| Layer | Technology |
|---|---|
| Runtime | Node.js |
| Framework | Express.js v5 |
| OTP Delivery | whatsapp-web.js (via WhatsApp bot service) |
| Session Storage | MongoDB Atlas (RemoteAuth) / Local filesystem (LocalAuth) |
| Database Client | mongodb |
| Containerisation | Docker |

### WhatsApp Bot (`muhafiz-backend/whatsApp-bot/`)

| Layer | Technology |
|---|---|
| Runtime | Node.js |
| Framework | Express.js v5 |
| WhatsApp Automation | whatsapp-web.js (Puppeteer) |
| Containerisation | Docker |

---

## Project Structure

```
Muhafiz/
├── muhafiz/                        # Flutter mobile app
│   ├── lib/
│   │   ├── main.dart               # App entry point
│   │   ├── router.dart             # Named route definitions
│   │   ├── firebase_options.dart   # Firebase config (auto-generated)
│   │   ├── core/                   # Constants, secure storage helpers
│   │   ├── models/                 # Data models
│   │   ├── providers/              # Riverpod state providers
│   │   ├── repositories/           # Data access layer
│   │   ├── screens/                # All app screens (18 screens)
│   │   ├── services/               # Firebase, location, notification, background services
│   │   └── widgets/                # Reusable UI components
│   ├── assets/                     # Fonts, images, SVG logo
│   ├── android/                    # Android platform files
│   ├── ios/                        # iOS platform files
│   └── pubspec.yaml                # Flutter dependencies
│
└── muhafiz-backend/
    ├── app/                        # Main API server (OTP auth + WhatsApp gateway)
    │   ├── Routes/
    │   │   └── auth/
    │   │       └── index.js        # POST /auth/reqOTP, POST /auth/verifyOTP
    │   ├── index.js                # Express server + WhatsApp client setup
    │   ├── .env.example            # Environment variable template
    │   ├── Dockerfile
    │   └── package.json
    │
    └── whatsApp-bot/               # WhatsApp bot microservice
        ├── index.js                # Express server + WhatsApp bot (message relay)
        ├── Dockerfile
        └── package.json
```

---

## Setup and Installation

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (≥ 3.11.0)
- [Node.js](https://nodejs.org/) (≥ 18.x recommended)
- A [Firebase project](https://console.firebase.google.com/) with Android/iOS apps registered
- Google Chrome installed (required by whatsapp-web.js on Windows)
- A WhatsApp account to pair with the bot (for OTP delivery)

---

### 1. Clone the repository

```bash
git clone https://github.com/your-username/Muhafiz.git
cd Muhafiz
```

---

### 2. Flutter App (`muhafiz/`)

```bash
cd muhafiz
flutter pub get
```

Make sure your `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) from your Firebase project is placed in the correct platform directories before running.

**Run the app:**

```bash
flutter run
```

> Supports Android, iOS, and Web. Background services and notifications only work on Android/iOS.

---

### 3. WhatsApp Bot (`muhafiz-backend/whatsApp-bot/`)

This service acts as a message relay. It must be running before the API server can send OTPs.

```bash
cd muhafiz-backend/whatsApp-bot
npm install
```

Create a `.env` file:

```env
PORT=3001
SESSION_PATH=./auth_session
```

Start the bot:

```bash
npm start
```

On first run, open `http://localhost:3001` and follow the logs — a QR code will appear in the terminal. Scan it with WhatsApp on your phone to authenticate the bot.

---

### 4. API Server (`muhafiz-backend/app/`)

```bash
cd muhafiz-backend/app
npm install
```

Copy the example environment file and fill in your values:

```bash
cp .env.example .env
```

**.env values explained below** — see the [Environment Variables](#environment-variables) section.

Start the server:

```bash
npm start
```

The API will run at `http://localhost:3000` by default.

---

### Docker (Optional)

Both backend services include a `Dockerfile`. You can build and run them as containers if preferred.

```bash
# From muhafiz-backend/app/
docker build -t muhafiz-app .
docker run -p 3000:3000 --env-file .env muhafiz-app

# From muhafiz-backend/whatsApp-bot/
docker build -t muhafiz-bot .
docker run -p 3001:3001 --env-file .env muhafiz-bot
```

---

## Environment Variables

### `muhafiz-backend/app/.env`

| Variable | Description | Required |
|---|---|---|
| `PORT` | Port for the API server (default: `3000`) | No |
| `WHATSAPP_BOT_URL` | URL of the WhatsApp bot service (e.g. `http://localhost:3001`) | Yes |
| `SESSION_SECRET` | Secret key used to sign session tokens | Yes |
| `MONGODB_URI` | MongoDB Atlas connection string for persistent WhatsApp sessions | No (falls back to local auth) |
| `MONGODB_DB_NAME` | MongoDB database name (default: `muhafiz`) | No |
| `MONGODB_COLLECTION` | Collection name for sessions (default: `whatsapp_sessions`) | No |
| `SESSION_ID` | WhatsApp session identifier (default: `main-whatsapp-session`) | No |

### `muhafiz-backend/whatsApp-bot/.env`

| Variable | Description | Required |
|---|---|---|
| `PORT` | Port for the bot server (default: none, must be set) | Yes |
| `SESSION_PATH` | Path to store local WhatsApp session files | No |
| `PUPPETEER_EXECUTABLE_PATH` | Path to Chrome/Chromium (needed on Linux/Docker) | Conditional |

---

## API Endpoints

### Auth (`/auth`)

| Method | Endpoint | Description |
|---|---|---|
| POST | `/auth/reqOTP` | Request a 6-digit OTP sent via WhatsApp |
| POST | `/auth/verifyOTP` | Verify the OTP and receive a session token |

### WhatsApp / Bot

| Method | Endpoint | Description |
|---|---|---|
| POST | `/sendMessage` | Send a WhatsApp message to a phone number |
| GET | `/qr` | View QR code to pair the bot (browser page) |
| GET | `/health` | Health check — returns bot ready status |
| GET | `/botInfo` | Returns WhatsApp account info of the bot |
| GET | `/checkMessages` | Fetch recent messages from a chat |

---

## Screenshots

> Screenshots are coming soon. Add your screenshots to the [`/screenshots`](./screenshots/) folder and link them here.

---

## Project Status

| Area | Status |
|---|---|
| Flutter app UI & screens | ✅ Built |
| OTP auth (WhatsApp-based) | ✅ Built |
| Trusted contacts | ✅ Built |
| Vulnerable & Emergency mode UI | ✅ Built |
| Alert delivery to contacts | 🚧 In progress |
| Real-time location sharing | 🚧 In progress |
| Firebase integration (Firestore/FCM) | 🚧 In progress |
| Admin dashboard | 🚧 In progress |
| Automated tests | ❌ Not started |

---

## Future Improvements

- Send real-time location to trusted contacts when emergency mode is activated
- Firebase Firestore sync for user data and alert history
- Push notification delivery for emergency alerts (Firebase Cloud Messaging)
- SMS or email OTP fallback if WhatsApp is unavailable
- Edit trusted contact details (currently only add/delete)
- Input validation and better error messages throughout the app
- Unit and widget tests for providers and core logic
- Production deployment guide (Render, Railway, etc.)

---

## License

This project does not currently have a license specified. Contact the author for usage permissions.
