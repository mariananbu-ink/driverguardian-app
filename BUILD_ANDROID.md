# DriverGuardian 2.12 — Build the Android app and the iPhone web app on GitHub (step by step)

No Android Studio, no Flutter on your PC — GitHub builds the APK (install on phones), the AAB (Play Store) and the
iPhone web app (PWA zip, installed on your server) for free.
Total time: about 15 minutes the first time, then one click per build (≈ 8–12 minutes on GitHub).

Developed & Powered by Marian Anbu Juwan

---

## What you need
- A GitHub account (free) — https://github.com/signup
- Your DriverGuardian **web site running on HTTPS**, e.g. `https://driverguardian.in`
- The `mobile/` folder from `DriverGuardian-2.12.0.zip` (55 files)
- *(optional)* Firebase project for push notifications
- *(optional, Play Store only)* an upload keystore — see Step 8

---

## Step 1 — Create the repository
1. Sign in to GitHub → **+** (top right) → **New repository**.
2. Repository name: `driverguardian-app` · Visibility: **Private** (recommended).
3. Tick **Add a README file** → **Create repository**.

## Step 2 — Upload the app source
1. Unzip `DriverGuardian-2.12.0.zip` on your computer and open the **`mobile`** folder.
2. In the repository: **Add file → Upload files**.
3. Select **everything inside** `mobile/` — the folders `lib`, `assets`, `tool`, `web` and the files `pubspec.yaml`,
   `analysis_options.yaml`, `README.md`, `BUILD_ANDROID.md` — and drag them into the page.
   *Upload the contents, not the `mobile` folder itself*: `pubspec.yaml` must be at the top of the repository.
4. Commit message `DriverGuardian 2.7.0` → **Commit changes**.

## Step 3 — Add the build workflow
The `.github` folder is hidden on Windows / Mac and is often skipped by drag-and-drop, so create it by hand:
1. **Add file → Create new file**.
2. File name — type exactly: `.github/workflows/build-android.yml`
   (typing the `/` creates the folders).
3. Open `mobile/.github/workflows/build-android.yml` from the zip in Notepad, copy everything, paste it into the editor.
4. **Commit changes**.

Check: the repository front page shows `.github`, `assets`, `lib`, `tool`, `web`, `pubspec.yaml` … at the top level.

## Step 4 — Point the app at your server
1. Repository → **Settings** → **Secrets and variables** → **Actions** → tab **Variables** → **New repository variable**.
2. Name `API_BASE` · Value `https://driverguardian.in` (your site, **no trailing slash**, no `/api`) → **Add variable**.

(If you skip this, the app opens with a placeholder address — users can still change it with the server icon on the sign-in screen.
The iPhone web app does not need it: it always talks to the site it is installed on.)

## Step 5 — *(optional)* Push notifications with Firebase
1. https://console.firebase.google.com → **Add project** (Analytics not needed).
2. **Add app → Android** · package name **`in.marianstudio.driverguardian`** → **Register app** →
   **Download `google-services.json`** (skip the remaining SDK steps).
3. GitHub → Settings → Secrets and variables → Actions → tab **Secrets** → **New repository secret**:
   Name `GOOGLE_SERVICES_JSON` · Value = open the JSON file in Notepad and paste the **whole content**.
4. Server side: Firebase → ⚙ Project settings → **Service accounts** → **Generate new private key** →
   DriverGuardian web (platform admin) → **System → Mobile push** → paste that JSON → Save.

Without Firebase the app still works; alerts show inside the app (bell + pop-ups, checked every 30 s).

## Step 6 — Build
1. Repository → **Actions** tab. If asked, click **I understand my workflows, go ahead and enable them**.
2. Left side: **Build Android** → **Run workflow** (right) → branch `main` → **Run workflow**.
3. Wait for the green ✔ (≈ 10–15 min). Click the run → scroll to **Artifacts** → download:
   - **DriverGuardian-android** (zip) → `DriverGuardian-2.12.0.apk` (install on phones) and `DriverGuardian-2.12.0.aab` (Play Store)
   - **DriverGuardian-pwa** (zip) → unzip once → `DriverGuardian-pwa-2.12.0.zip` (the iPhone web app — Step 10)

## Step 7 — Install the APK on phones
1. Easiest: DriverGuardian web (platform admin) → **System → Apps → Android app** → choose the `.apk` → **Upload APK**.
   Parents then download it from **`https://driverguardian.in/get-app`** (one link for Android and iPhone, with a QR code).
   Upload the **.apk file itself** (unzip the DriverGuardian-android download first). Do not paste the GitHub Actions page / artifact
   link as the APK link — it needs a GitHub login, downloads a zip and expires, so parents cannot install from it.
   Or send the `.apk` by WhatsApp / Drive / email.
2. On the phone, open the file → allow **Install unknown apps** for WhatsApp / Chrome / Files when Android asks → **Install**.
3. Open DriverGuardian → sign in with the **School Code**, login and password → the **App permissions** screen appears → tap **Allow all**.
   (Android never grants location, camera or notifications at install time — not even from the Play Store; every app has to ask.
   Later: Account → App permissions.)
4. **Drivers**: on the App permissions screen also tap **Unrestricted battery** (Settings → Battery → Unrestricted), so GPS keeps
   running with the screen off during a trip.

Updating later: install the new APK over the old one — the app keeps its sign-in. (APKs signed with different keys
can’t replace each other; see Step 8.)

## Step 8 — *(optional)* Play Store release signing
Without this, builds are signed with a temporary debug key — fine for sharing the APK, **not accepted by the Play Store**.
Do this once and keep the keystore + passwords safe for ever (Google needs the same key for every update).

1. On any PC with Java (or Android Studio), run:
   ```
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   Choose a password; answer the name / organisation questions.
2. Convert it to text:
   - Windows PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Content key.txt`
   - Mac / Linux: `base64 -i upload-keystore.jks -o key.txt` (Linux: `base64 -w0 upload-keystore.jks > key.txt`)
3. GitHub → Settings → Secrets and variables → Actions → **Secrets** → add four secrets:

   | Name | Value |
   |---|---|
   | `ANDROID_KEYSTORE_BASE64` | whole content of `key.txt` |
   | `ANDROID_KEYSTORE_PASSWORD` | the keystore password |
   | `ANDROID_KEY_ALIAS` | `upload` |
   | `ANDROID_KEY_PASSWORD` | the key password (same as keystore password if you pressed Enter) |
4. Run the workflow again. The log line *“release signing: upload key configured”* confirms it.
5. Play Console (one-time US $25 developer fee) → **Create app** → **Production** (or Internal testing) →
   **Create new release** → upload `DriverGuardian-2.12.0.aab` → fill the store listing, privacy policy URL,
   data-safety form (location is collected for live bus tracking) → **Review & roll out**.
   Every build has a higher version code automatically, so new AABs are always accepted.

Note: phones that installed the debug-signed APK must uninstall it once before installing the Play Store / upload-key version.

## Step 9 — Next versions
- Replace the changed files: **Add file → Upload files** → drag the new `lib`, `assets`, `web`, `pubspec.yaml` … (overwrite) → Commit.
  Also replace `.github/workflows/build-android.yml` (Step 3) when the version notes say it changed — 2.6 changed it (adds the web build) — if the run shows no **DriverGuardian-pwa** artifact, the old file is still there.
  **2.11:** upload `lib`, `web` and `pubspec.yaml`. **2.10:** upload `lib`, `assets` (new `assets/icon/marker.png` — the map bus marker), `web`, `pubspec.yaml` and `tool/patch_platforms.py` (Android backups off).
- **Actions → Build Android → Run workflow.**
- Or tag a release: **Releases → Draft a new release → Choose a tag** `v2.12.0` → **Publish** — the workflow builds and
  attaches the APK, AAB and PWA zip to that release page automatically (a shareable download link).
- After every build install the new PWA zip on the server (Step 10) so iPhone users get the same version.

---

## If the build fails (red ✖)
Open the failed run → click the red step → read the last lines.

| Message | Fix |
|---|---|
| `pubspec.yaml is not at the repository root` | You uploaded the `mobile` folder itself. Move files to the top level (Step 2). |
| Workflow not listed under Actions | `.github/workflows/build-android.yml` path is wrong — recreate it (Step 3). |
| `File google-services.json is missing` / `No matching client found for package name` | The Firebase Android app must use package `in.marianstudio.driverguardian`; paste the full JSON into the secret. |
| `Keystore was tampered with, or password was incorrect` | Wrong `ANDROID_KEYSTORE_PASSWORD`. |
| `Failed to read key upload from store` / alias error | `ANDROID_KEY_ALIAS` / `ANDROID_KEY_PASSWORD` wrong. |
| `Invalid keystore format` | `ANDROID_KEYSTORE_BASE64` incomplete — paste the whole `key.txt` with no extra spaces. |
| App opens but sign-in says *cannot reach server* | `API_BASE` wrong, site not on HTTPS, or a firewall/ModSecurity rule blocks `/api/v1`. Open `https://your-site/api/v1/ping` in the phone browser. |
| `Because driverguardian depends on … version solving failed` | A temporary Flutter/package mismatch — re-run; if it persists, send the log. |
| `requires … compileSdk of at least 37` / `checkReleaseAarMetadata` | Fixed since 2.9.0 (build 2): replace `tool/patch_platforms.py` and `.github/workflows/build-android.yml` in the repository with the ones from the zip and run the workflow again. |
| `Target dart2js failed … exit code -15` / `The operation was canceled` (step *Build web app*) | The web build was stopped on the GitHub machine. Since 2.10 the APK and the web app build in two separate jobs, so this no longer loses the APK — replace `.github/workflows/build-android.yml` with the one from the zip and run again (or press **Re-run failed jobs**). |
| `web/index.html was replaced` | The `web` folder was not uploaded — upload it (Step 2). |
| System → Apps says *not a DriverGuardian web app build* | You chose the artifact zip itself or the APK zip — unzip **DriverGuardian-pwa** once and upload the `DriverGuardian-pwa-x.y.z.zip` inside. |
| iPhone shows a white page / old version | Close the app from the app switcher and reopen it; check `https://your-site/app/version.json`. |
| No *Turn on notifications* button on iPhone | The app was opened in Safari, not from the Home Screen icon, or iOS is older than 16.4. |

## What the workflow does (for reference)
`flutter create` generates the Android/iOS project → writes `google-services.json` and the keystore from secrets →
`tool/patch_platforms.py` adds permissions (location incl. background/foreground service, notifications, camera),
UPI app queries, minSdk 23, Firebase plugin and release signing → `flutter pub get` → app icons (compass-bus logo) and splash screen (`flutter_native_splash`) →
`flutter build apk` and `flutter build appbundle` with your `API_BASE` → `flutter build web` (iPhone web app, from the `web/` folder) →
artifacts (and a GitHub Release for `v*` tags).

## Step 10 — iPhone web app (PWA)
Same app, same design, running in Safari — until the native iOS app is built on a Mac.
1. From Step 6 take `DriverGuardian-pwa-2.12.0.zip` (unzip the **DriverGuardian-pwa** artifact once; do **not** unzip the inner zip).
2. DriverGuardian web (platform admin) → **System → Apps → iPhone / browser web app** → choose the zip → **Install**.
   It is sent in small parts, so the hosting upload limit does not matter. The app is live at `https://driverguardian.in/app/`.
3. *(optional — notifications on iPhone)* Firebase console (same project as Step 5):
   - ⚙ Project settings → General → **Add app → Web (</>)** → any nickname → **Register** → copy the `const firebaseConfig = { … }` block.
   - Project settings → **Cloud Messaging** → *Web configuration* → **Web Push certificates** → **Generate key pair** → copy the key.
   - DriverGuardian → **System → Mobile push → iPhone / web app notifications** → paste both → **Save / test**
     (the service-account JSON from Step 5 must be saved too — it sends to Android and iPhone).
4. On the iPhone: open `https://driverguardian.in/get-app` (or `/app/`) in **Safari** → **Share** → **Add to Home Screen** → **Add** →
   open **DriverGuardian** from the Home Screen → sign in → tap **Turn on notifications** → **Allow** (iOS 16.4+).

Notes: the site must be on HTTPS. iPhone stops web GPS when the screen locks, so drivers should use Android
(or keep the trip screen open). Without the System page: unzip the PWA zip with File Manager into `web/public/app/`.

---
Developed & Powered by Marian Anbu Juwan
