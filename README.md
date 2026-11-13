# DriverGuardian — Mobile App (Flutter) v2.12.0

One app for **platform admins, school admins, drivers and parents**, talking to the DriverGuardian Laravel server
through `/api/v1` (Laravel Sanctum tokens). Requires server **2.11** or newer. The same code builds the Android app and the **iPhone / browser web app (PWA)**. Developed & Powered by Marian Anbu Juwan.

## How it is organised
The server decides which modules each user gets (`GET /api/v1/modules`), and the app shows them in a
module launcher — the home screen's *Quick access* grid, the **Modules** tab (grouped by section) and the slide-out
drawer menu. Adding a module for a role on the server shows it in the app with no new build, as long as the app knows
the module key (`lib/modules.dart`).

| Role | Modules |
|---|---|
| — new in 2.2 | Trip history with replay, Incident log / Complaints (photo + GPS), Maintenance log, Driver safety, Substitute drivers; Students opens class cards with rich stats |
| — new in 2.3 | Attendance calendar (ring, Present/Absent/Late/Leave tiles, month & date filters, day by day) and admin month heat-map; online gateway payments (Razorpay, Cashfree, PhonePe, PayU, Stripe) opened in the browser; **My subscription** (usage, Renew / Pay now, UPI + UTR); **Announcements** by app / SMS / WhatsApp / email; new compass-bus icon |
| — new in 2.4 | Splash screen (native navy splash + animated compass-bus seal, name and tagline); readable AI Copilot suggestion chips; modules switched off by the platform owner are hidden |
| — new in 2.5 | **User guide & help** (role-based, searchable, from the server); indigo compass-bus icon and splash |
| — new in 2.11 | **Audit log** screen (Changes · Sign-ins · Security; tap an entry for old → new values); web app counts its install once per phone; works with the server's subscription pause (402 message) and plan modules |
| — new in 2.10 | **AI Insights → Efficiency** (score, AI recommendations, fleet load / km / idling / fuel ₹, service & documents, data to fix, children not riding with **Ask parents**, staff hours saved); Track bus: big **DriverGuardian seal** bus marker with pulse and bus number — tap for bus, driver, speed, ETA and **Call driver**; bottom card stays above the navigation bar; Android backups off (token stays on the phone) |
| — new in 2.9 | **App permissions** screen after the first sign-in (notifications, location, camera, unrestricted battery for drivers — `permission_handler`); School Code field always shown and remembered; Copilot **New / Previous chats / Clear**; announcements flash as a banner on every screen until read or closed |
| — new in 2.8 | **AI Insights** for school admins (morning briefing, watchdog alerts with “mark handled”, driver coaching, fee follow-up with one-tap reminders, route timetable suggestions) and **My performance** for drivers; Track Bus shows the **AI arrival time** learned from past trips and “running ~N min late” |
| — new in 2.7 | **Track Bus**: green circle around the parent's stop (school's alert radius), 🏠 pin, pop-up when the bus enters it; colour-coded card with distance to your stop, speed, approx. arrival, last update and driver call; jump-to-bus / my-stop buttons. Web app on Android Chrome shows an Install banner |
| — new in 2.6 | **Web build for iPhone (PWA)**: same screens and design, install banner + help sheet, web push (Firebase), browser-safe photo upload and payment links, driver keep-screen-open notice |
| Platform admin | Schools (switch into any school → full school-admin modules), platform KPIs, activity & login log, messages, notifications |
| School admin | Dashboard, approvals, students (full profile: family, transport, cards, attendance with exact times, fees, academic history), classes, siblings, parents & staff (stats, approve, reset password, message), drivers (stats, licence expiry), academic year, live tracking, routes & stops (tracking on/off), vehicles (RTO + PUC expiry), assignments, attendance day view, CCTV, RFID & cards (stats, block/lost, readers, tap log, test tap), SOS, fees (verify UTRs, **new invoice with installments**), reports (CSV), activity & login log, AI Copilot |
| Driver | Start trip (background GPS, on-trip attendance with boarded/dropped times), **scan bus pass** (QR via camera), live map, my bus & documents, bus camera, messages, SOS |
| Parent | My children (today's pickup/drop with times), track bus, attendance & leave, fees by UPI, **QR bus pass**, bus camera, messages, SOS |

**UI:** Plus Jakarta Sans (thin weights), gradient header with greeting and KPI carousel, quick-access grid,
slide-out drawer, bottom navigation (Home · Modules · Messages · Account), gradient module icons with live badges
(approvals, payments to verify, SOS, unread messages).

## Build the APK on GitHub (recommended — no Android Studio needed)

**Step-by-step guide: [BUILD_ANDROID.md](BUILD_ANDROID.md)** (Firebase, Play Store signing, troubleshooting).

1. Create a GitHub repository and upload **the contents of this `mobile/` folder** (including `.github/`).
2. *Settings → Secrets and variables → Actions*
   - **Variables → `API_BASE`** = your site, e.g. `https://driverguardian.in` (no trailing slash)
   - **Secrets → `GOOGLE_SERVICES_JSON`** *(optional, for push)* = the full contents of Firebase `google-services.json`
     (Android package name **`in.marianstudio.driverguardian`**).
3. *Actions → Build Android → Run workflow*. Download `app-release.apk` (sideload) and `app-release.aab` (Play Store) from the run's artifacts.

The workflow runs `flutter create` to generate the `android/` + `ios/` folders, then `tool/patch_platforms.py`
adds location/foreground-service/notification/camera/photo permissions, UPI app intents, `minSdk 23`, and the Google Services
plugin when the Firebase file is present.

## Build locally

```bash
flutter create --org in.marianstudio --project-name driverguardian --platforms android,ios .
rm -rf test
python3 tool/patch_platforms.py          # after copying google-services.json to android/app/ (optional)
flutter pub get
dart run flutter_launcher_icons
flutter build apk --release --dart-define=API_BASE=https://driverguardian.in
```

The server address can also be changed from the sign-in screen (server icon, top right), so one APK can be pointed at a test server.

## Push notifications

- Server: platform admin → **System → Mobile push** → paste the Firebase **service-account JSON**.
- Web app (iPhone): System → Mobile push → *iPhone / web app notifications* (Firebase web config + Web Push key).
- App: build with `GOOGLE_SERVICES_JSON`. Without it the app still works and shows in-app notifications
  (bell badge + pop-ups while the app is open; polled every 30 s).

## iPhone web app (PWA)

`flutter build web` (done by the GitHub workflow) produces `DriverGuardian-pwa-x.y.z.zip`; install it on the server under
**System → Apps** and it runs at `https://your-site/app/`. Files:

| File | Purpose |
|---|---|
| `web/index.html` | page shell: iOS meta tags, Home Screen icon, navy loading splash (removed on the first Flutter frame); no `<base>` tag, so it works in any folder |
| `web/flutter_bootstrap.js` | starts the engine (the build fills in the loader) and shows a reload hint if loading fails |
| `web/dg-pwa.js` | bridge used from Dart (`lib/web/bridge_web.dart`): install-help and “Allow notifications” sheets, Firebase web push token |
| `web/dg-sw.js` | service worker: shows push notifications, opens the app on tap (no offline cache, so updates apply on the next open) |
| `web/manifest.json`, `web/icons/` | name, colours and icons (normal + maskable + Apple touch icon) |
| `lib/web/` | `bridge.dart` (conditional import: stub on Android/iOS, `dart:js_interop` on web) and the Home-tab install / notifications banner |

The web app finds its server from its own address (`<site>/app/` → `<site>`), so `API_BASE` is not used for it.
Limits compared with Android: no background GPS (drivers must keep the trip screen open), notifications need iOS 16.4+
and the Home Screen icon, and payment pages open in a new tab after a tap.

## iOS (native)

`flutter create` also generates `ios/`, and the patch script adds the location / background / UPI query keys to
`Info.plist`. Building and signing needs a Mac with Xcode and an Apple developer account
(`flutter build ipa --dart-define=API_BASE=...`). Until then iPhone users use the web app above.

## Release signing (Play Store)

Without a keystore, release builds are signed with the debug key (fine for sideloading). For the Play Store add the
secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` —
the workflow then signs with your upload key (see BUILD_ANDROID.md, Step 8). Locally: copy `upload-keystore.jks`
to `android/app/`, export the three password variables and run `python3 tool/patch_platforms.py`.

---
Developed & Powered by Marian Anbu Juwan
