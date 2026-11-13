# DriverGuardian 2.12 — From a new GitHub account to Google Play (step by step)

Server: **https://driverguardian.in** · Package name: **in.marianstudio.driverguardian** · Version **2.12.0**

Developed & Powered by Marian Anbu Juwan

---

## What is in this kit

| Folder / file | What it is |
|---|---|
| `1-upload-key-on-your-pc/` | Scripts that create your Play Store **upload key** (Windows / Mac / Linux) |
| `2-app-source/` | The complete DriverGuardian 2.12 app — upload its **contents** to GitHub |
| `3-play-store-listing/` | Store texts, reviewer notes, data-safety answers, **app icon 512** and **feature graphic** |
| `PLAY-STORE-GUIDE.md / .html` | This guide |

What changed in this app source compared with the earlier 2.12 mobile zip:
- The app now connects to **https://driverguardian.in** by default (no setting needed).
- Targets **Android 16 (API 36)** — required by Google Play.
- **Build menu**: choose *Play Store AAB only*, *APK only*, *Web app only* or *everything* — saves GitHub minutes.
- The build **checks your upload key** first and stops with a clear message if a password or alias is wrong.
- New workflow **Create upload key** — makes the key on GitHub if you have no Java on your PC.

---

## Part A — New GitHub account and repository (10 min)

1. Sign up at **https://github.com/signup** and verify the email.
2. **+** (top right) → **New repository**
   - Name: `driverguardian-app`
   - Visibility: **Public** ← recommended: GitHub Actions minutes are **free and unlimited** for public repositories.
     The app source holds no passwords or keys (those go into *Secrets*, which are never public).
     Choose **Private** only if you must — then you get 2,000 free minutes a month (a full build uses about 25–35).
   - Tick **Add a README file** → **Create repository**.

## Part B — Upload the app source (10 min)

1. Unzip this kit and open **`2-app-source`**.
2. In the repository: **Add file → Upload files**.
3. Select **everything inside** `2-app-source` — `lib`, `assets`, `tool`, `web`, `pubspec.yaml`, `analysis_options.yaml`,
   `README.md`, `BUILD_ANDROID.md` — drag them into the page → **Commit changes**.
   *Upload the contents, not the folder itself: `pubspec.yaml` must be at the top of the repository.*
4. The **`.github`** folder is hidden on Windows and is usually skipped, so create the two workflow files by hand:
   - **Add file → Create new file** → name: `.github/workflows/build-android.yml`
     → open `2-app-source/.github/workflows/build-android.yml` in Notepad → copy all → paste → **Commit changes**.
   - Again: **Add file → Create new file** → `.github/workflows/create-upload-key.yml` → paste that file → **Commit**.
   *(Windows: in File Explorer → View → Show → Hidden items, to see the `.github` folder.)*
5. Check: the repository front page shows `.github  assets  lib  tool  web  pubspec.yaml …` at the top level.

## Part C — Point the app at your site (2 min, optional)

The app already uses **https://driverguardian.in**. Only if you move the site:
**Settings → Secrets and variables → Actions → Variables → New repository variable**
`API_BASE` = `https://your-new-site.in` (no `/` at the end).

## Part D — Push notifications (5 min)

You already have Firebase from the earlier account — the same file works (same package name):
**Settings → Secrets and variables → Actions → Secrets → New repository secret**
- Name `GOOGLE_SERVICES_JSON` · Value: open your `google-services.json` in Notepad, paste the **whole** content.

(No file? Firebase Console → your project → ⚙ Project settings → *Your apps* → Android app → **Download google-services.json**.
The server part — *System → Mobile push* on the website — is already set and does not change.)

## Part E — Create the upload key (5 min, once in a lifetime)

Google Play only accepts apps signed with **your own upload key**. Make it **once** and keep it forever.

**Option 1 — on your Windows PC** (needs Java: install **Temurin 17** from https://adoptium.net or Android Studio)
1. Open `1-upload-key-on-your-pc` → double-click **`create-upload-key-windows.bat`**.
2. Type a password twice (8+ characters, letters and numbers, no spaces), press Enter for name and city.
3. It creates **`upload-keystore.jks`**, **`keystore-base64.txt`** and **`KEY-DETAILS.txt`** (opens in Notepad).

*Mac / Linux:* `bash create-upload-key-mac-linux.sh`

**Option 2 — on GitHub** (no Java needed)
1. Repository → **Actions** → (first time: *I understand my workflows, enable them*) → **Create upload key** → **Run workflow**.
2. Type a password (8+ characters, no spaces), keep name *Marian Technologies* and city *Bengaluru* → **Run workflow**.
3. When it turns green (≈ 1 min) open the run → **Artifacts → upload-key** → download and unzip.
4. Then **delete the run** (⋯ → *Delete workflow run*) so the key does not stay on GitHub.

**Add the four secrets** — Settings → Secrets and variables → Actions → **Secrets** → *New repository secret*:

| Name | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the whole content of `keystore-base64.txt` (one long line) |
| `ANDROID_KEYSTORE_PASSWORD` | your password |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | the same password |

> **Keep `upload-keystore.jks` and the password in two safe places** (Google Drive + pen drive).
> Every future update must be signed with the same key. Never email it or put it in the repository.

## Part F — Build the Play Store file (≈ 15 min, one click)

1. **Actions → Build Android → Run workflow** → *What to build*:
   - **Play Store AAB only** — for Google Play (fastest)
   - **Play Store AAB + APK + web app** — everything (APK for direct install, web app for iPhone)
   → **Run workflow**.
2. Open the run. In **android → Check settings** you should see `App will connect to: https://driverguardian.in`,
   and in **Upload key** → `Upload key OK`.
3. When it is green: **Artifacts → DriverGuardian-android** → download → unzip →
   **`DriverGuardian-2.12.0.aab`** (and `BUILD-INFO.txt` must say *signed with your upload key*).
4. If you built the web app too: download **DriverGuardian-pwa**, unzip once, and upload
   `DriverGuardian-pwa-2.12.0.zip` on the website → **System → Apps → web app**.

## Part G — Google Play Console (first release)

### G1. Create the app
**Play Console → Create app** → App name **DriverGuardian** · Default language **English (India) – en-IN** ·
**App** · **Free** → tick the declarations → **Create app**.

### G2. App content (Dashboard → *Set up your app*)
Use **`3-play-store-listing/store-listing.txt`** — every answer is written there:
- **Privacy policy**: `https://driverguardian.in/privacy`
- **App access**: give the reviewers a demo **parent** login and a demo **driver** login (create them in your school first).
- **Ads**: No · **Content rating**: questionnaire as in the file · **Target audience**: **18+ only**
- **Data safety**: copy the table from the file
- **Data deletion**: account-deletion link (see the note in the file)
- **Foreground service permission** (location): short reason + a screen-recording video link (steps in the file)
- **Government / financial / health / news**: No

### G3. Store listing (Grow → Store presence → Main store listing)
- Name, short and full description: from `store-listing.txt`
- **App icon**: `graphics/app-icon-512.png`
- **Feature graphic**: `graphics/feature-graphic-1024x500.png`
- **Phone screenshots**: at least **2** (4–6 is better) — take them on a phone with the app open:
  sign-in, Track bus map, Attendance, Fees, Copilot. (Portrait, PNG/JPEG, no status-bar notifications showing.)
- Category **Education** · Contact email · Website `https://driverguardian.in`

### G4. Closed testing (needed once for new personal developer accounts)
1. **Test and release → Testing → Closed testing → Create track** (name: *School pilot*).
2. **Testers** → create an email list with **at least 12 Gmail IDs** (drivers, staff, a few parents) → Save.
3. **Create new release** → **Play App Signing: Continue / Use Google-generated key** (Google keeps the app-signing key; you keep the upload key)
   → **Upload `DriverGuardian-2.12.0.aab`** → release name `2.12.0` → release notes from the file → **Next → Save → Send for review**.
4. After approval (usually 1–3 days) copy the **opt-in link** and send it to the testers:
   each one opens it, taps *Become a tester*, then installs from Play.
5. Keep **12+ testers opted in for 14 days in a row** — then **Dashboard → Apply for production** (answer the short questions).

*(Organisation developer accounts skip G4 and can go straight to Production.)*

### G5. Production
**Test and release → Production → Create new release → Add from library** (the tested 2.12.0 build) → **Next → Save →
Send for review → Start rollout**. Review usually takes 1–7 days.

## Part H — Every later update
1. Upload the changed app files to GitHub (same repository).
2. **Actions → Build Android → Run workflow → Play Store AAB only**.
3. Play Console → Production (or Closed testing) → **Create new release** → upload the new `.aab` → notes → rollout.
The build number goes up automatically, so Play always accepts the new file.

## Troubleshooting

| Message | Fix |
|---|---|
| *pubspec.yaml is not at the repository root* | You uploaded the `2-app-source` folder itself — upload its **contents** |
| *The upload key could not be opened* | Wrong `ANDROID_KEYSTORE_PASSWORD` / alias — alias is `upload`; re-paste the secrets |
| Play: *You uploaded an APK or Android App Bundle that was signed in debug mode* | The 4 key secrets are missing — Part E, then rebuild |
| Play: *signed with the wrong key* | You built with a different key from the first upload — use the original `upload-keystore.jks` (lost? Play Console → App integrity → *Request upload key reset*) |
| Play: *Version code … has already been used* | Rebuild — every build gets a new number |
| Play: *targets API level …* | This source targets API 36 — make sure you uploaded the new `tool/patch_platforms.py` |
| GitHub: *You've used 100% of included minutes* | Make the repository **Public** (Settings → General → Danger zone → Change visibility) or wait for next month |
| No push notifications | Secret `GOOGLE_SERVICES_JSON` missing, or server *System → Mobile push* not set |

---

Developed & Powered by Marian Anbu Juwan
