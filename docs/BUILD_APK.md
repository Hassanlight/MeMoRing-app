# Get the Memoring APK on your phone (cloud build)

No tools to install. GitHub builds the APK for you; you download and install it.

## One-time setup
1. Create a **new, separate, private** GitHub repo (NOT the Layal/StyleByAsma repo).
   Suggested name: `memoring`.
2. From this folder, push the code:
   ```bash
   cd "Memoring App"
   git init
   git add .
   git commit -m "feat: Memoring v1 — intelligence engine + UI"
   git branch -M main
   git remote add origin https://github.com/<your-account>/memoring.git
   git push -u origin main
   ```
   The push triggers the build automatically (see `.github/workflows/build-apk.yml`).

## Each time you want a fresh APK
- Push a change, **or** go to the repo → **Actions** → **Build APK** → **Run workflow**.
- Open the finished run → **Artifacts** → download **memoring-apk** → unzip →
  `app-release.apk`.

## Install on your phone
1. Copy `app-release.apk` to the phone (USB, Google Drive, or email to yourself).
2. Tap it. Android will ask to allow "install unknown apps" — allow it for that app.
3. Install and open Memoring.

> The release APK is debug-signed by Flutter's default config, so it installs for
> personal testing without a keystore. For the Play Store you'll add a real signing
> key later (deployment-engineer step).

## Note on full-screen alerts
This build runs the app and all in-app screens. For the alert to take over the
**whole screen** from the background, the Android manifest needs `USE_FULL_SCREEN_INTENT`,
exact-alarm, and `POST_NOTIFICATIONS`. Ask and I'll add a committed `android/` folder
with those entries so CI stops regenerating a default one.
