# Muhafiz App Audit Brief (May 15, 2026)

## 1) Project Structure
- Flutter/Dart: Flutter 3.41.1, Dart 3.11.0 (from recent SDK check)
- Root layout: `lib/`, `assets/`, `android/`, `ios/`, `web/`, `macos/`, `windows/`, `linux/`
- Entry point: `lib/main.dart`
- Routing: `lib/router.dart` (named routes, splash redirect)
- State management: Riverpod (`StateNotifierProvider`)
- Storage:
  - `shared_preferences` for user/mode/trustees
  - `flutter_secure_storage` for tokens
- Notable packages: `flutter_riverpod`, `flutter_svg`, `shared_preferences`, `flutter_secure_storage`

## 2) Current App Status
- Implemented:
  - Onboarding flow: welcome -> register -> details
  - Local user persistence (name/phone/gender)
  - Trustees list with add/delete
  - Vulnerable and emergency modes (local state only)
  - Settings profile edit + clear data
- Partial:
  - Emergency/Vulnerable mode has no messaging, location, or notifications
  - Auth is local-only (no OTP or backend)
- Missing:
  - Backend/API, real auth, location sharing, alerts, background tasks

## 3) Screen-by-Screen Breakdown
- `lib/screens/splash_screen.dart`
  - Purpose: Animated splash
  - UI: Logo + app name + slogan on red background
  - Navigation: Redirect handled by `lib/router.dart`
  - Notes: No loading/error states

- `lib/screens/welcome_screen.dart`
  - Purpose: Intro/CTA
  - UI: Illustration + text + “Get Started”
  - Navigation: `AppRoutes.register`
  - Issues: Fixed large image size; may overflow small screens

- `lib/screens/register_screen.dart`
  - Purpose: Phone input, user check
  - UI: Phone field, continue button
  - Actions: `authStateProvider.checkUser`
  - Navigation: Details (new) or Home (existing)
  - Missing: OTP/verification

- `lib/screens/details_screen.dart`
  - Purpose: Complete profile
  - UI: Name input, gender radio, read-only phone
  - Actions: `registerUser`
  - Navigation: Home

- `lib/screens/app_shell.dart`
  - Purpose: Bottom nav container
  - UI: IndexedStack + BottomNavigationBar
  - Screens: Home, Contacts, Settings

- `lib/screens/home_screen.dart`
  - Purpose: Dashboard + mode actions
  - UI: Current mode card + buttons
  - Data: `userProvider`, `modeProvider`
  - Missing: Any real alert side effects

- `lib/screens/contacts_screen.dart`
  - Purpose: Trustees list
  - UI: Cards, bottom sheet add form, swipe delete
  - Data: `trusteesProvider`
  - Missing: Edit contact, import, tiers logic

- `lib/screens/settings_screen.dart`
  - Purpose: Profile edit + clear local data
  - UI: Name/gender/phone fields, save, clear
  - Data: `userProvider`, `modeProvider`, `trusteesProvider`
  - Missing: Validation for phone/name

- `lib/screens/vulnerable_mode_screen.dart`
  - Purpose: Configure vulnerable mode
  - UI: Message, interval, preview card
  - Data: `modeProvider`, `userProvider`
  - Missing: Actual sharing/alerts

- `lib/screens/emergency_mode_screen.dart`
  - Purpose: Emergency activation
  - UI: Status card, activate button, countdown
  - Data: `modeProvider`, `userProvider`
  - Missing: Actual alert/notification workflows

- Widgets
  - `lib/widgets/primary_button.dart`: Primary CTA with loading
  - `lib/widgets/outline_button.dart`: Secondary CTA
  - `lib/widgets/trustee_card.dart`: Trustee card

## 4) Code Quality Review
- Architecture: No service/repository layer; providers mix data + logic
- Reuse: Inputs and gender selection repeated
- Responsiveness: Fixed sizes in welcome screen
- Error handling: Limited; Settings lacks validation
- Security: PII stored in SharedPreferences; tokens are local/fake

## 5) Design/UI/UX Review
- Style: Consistent color + typography
- Gaps: Missing loading/empty/error states on several screens
- Accessibility: No semantics or large-text adjustments
- Suggestions: Add adaptive layouts, error states, and common components

## 6) Build/Run Status
- Analyzer: No issues found
- Web build: Succeeds; wasm warnings from `flutter_secure_storage_web`
- Dependencies: Outdated but no conflicts

## 7) Next Development Roadmap
1. Add real auth (OTP) + backend integration
2. Add location + permissions
3. Add alert messaging + notification system
4. Introduce services/repositories layer
5. Refactor shared form components
6. Add validation + improved error UX
7. Add tests for providers/models

---

## Handoff Summary
- App: Muhafiz, a personal safety app (onboarding, trustees, safety modes)
- Built: Onboarding flow, local persistence, trustees list, vulnerable/emergency UI, settings
- Incomplete: No backend, OTP, location, alerts, or notifications
- Main files: `lib/main.dart`, `lib/router.dart`, `lib/screens/*`, `lib/providers/*`, `lib/widgets/*`
- Stack: Flutter 3.41.1, Dart 3.11.0, Riverpod, SharedPreferences, Secure Storage
- Next steps: Add backend auth, location + alerts, notifications, refactor architecture

