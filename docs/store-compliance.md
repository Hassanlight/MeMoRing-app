# Memoring — Play Store & App Store compliance checklist

Status legend: ✅ done in code/CI · 🟡 you must do it in the store console · 🔴 gap

## Google Play

| Item | Status | Notes |
|---|---|---|
| Full-screen intent (`USE_FULL_SCREEN_INTENT`) | ✅ + 🟡 | Allowed only for alarm/reminder apps — Memoring qualifies. In Play Console → App content → declare the alarm use case when asked. Android 14+ runtime grant already requested in-app. |
| Exact alarms | ✅ | Play pattern applied: `SCHEDULE_EXACT_ALARM` capped at Android 12 (`maxSdkVersion=32`), `USE_EXACT_ALARM` for 13+ (restricted to alarm apps — we qualify). |
| App Bundle (AAB) | ✅ | CI now builds `app-release.aab` (Play only accepts AAB for new apps). |
| Release signing | 🟡 | Currently test-signed. Create a keystore once:<br>`keytool -genkey -v -keystore memoring.jks -keyalg RSA -keysize 2048 -validity 10000 -alias memoring`<br>then add repo secrets `MEMORING_KEYSTORE_BASE64` (`base64 -w0 memoring.jks`), `MEMORING_KEYSTORE_PASSWORD`, `MEMORING_KEY_ALIAS`, `MEMORING_KEY_PASSWORD`. CI signs automatically after that. NEVER commit the .jks. |
| Data safety form | 🟡 | Truthful answers: **no data collected, no data shared** — everything (reminders, photos, religion, voice) stays on-device; nothing is transmitted. Voice uses the device's speech service; photos labeled on-device (ML Kit bundled model). |
| Privacy policy URL | 🟡 | Page is WRITTEN: `docs/privacy-policy.html` (covers on-device storage, the religion question, all permissions, and the AdMob advertising disclosure). Remaining: host it at a public URL and paste that URL into Play Console / App Store Connect. Hosting options: a small public GitHub Pages repo, or a page on an existing domain (e.g. layal.digital) — owner's choice. |
| Sensitive data (religion) | ✅ | Optional question ("Prefer not to say"), clear purpose (tailors features), stored locally only, never transmitted. Keep it this way. |
| Permissions minimality | ✅ | Every permission maps to a feature: alarms/notifications (core), camera (photo/selfie confirm), mic (voice input), boot (reschedule after reboot), vibrate. |
| Target SDK | ✅ | `flutter create` in CI tracks the current Flutter target (meets Play's yearly requirement; rebuild refreshes it). |
| Content rating / ads / accounts | 🟡 | Questionnaire: no ads, no accounts, no user-generated public content → Everyone rating. |

## Apple App Store

| Item | Status | Notes |
|---|---|---|
| iOS build | 🔴 | Not produced yet — CI only generates Android. Needs a macOS runner + Apple Developer account ($99/yr). Say the word and I'll add the iOS lane. |
| Critical alerts | ✅ | Removed `critical: true` from the permission request — it requires a special Apple entitlement; requesting it unapproved is a rejection risk. Time-sensitive interruption level (kept) is the approved mechanism for reminders. |
| Usage strings (Info.plist) | 🟡 (when iOS lane exists) | Required: `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`. |
| Time-sensitive notifications | 🟡 | Enable the "Time Sensitive Notifications" capability in Xcode signing (no Apple approval needed). |
| Privacy nutrition label | 🟡 | Same truthful answer: no data collected. |
| Full-screen takeover | ✅ (documented) | iOS never allows OS-level takeover; app shows the full-screen note on tap / when open. This is expected and passes review. |
| Religion question | ✅ | Optional + on-device only + clear purpose — meets Apple's sensitive-data rules. |

## Monetization (AdMob)

| Item | Status | Notes |
|---|---|---|
| SDK integrated | ✅ | `google_mobile_ads` — banner on the reminders list + Insights only. NEVER on the chat (primary surface) or the alarm screen (policy + UX). Fail-safe: offline / no fill / no Google services → zero-height, app unaffected. |
| Ad IDs | 🟡 | Currently Google's PUBLIC TEST ids. Before release: create an AdMob account, make an app + banner unit, replace `APPLICATION_ID` in `ci/AndroidManifest.xml` and `kBannerAdUnitId` in `lib/features/ads/ad_banner.dart`. Shipping with test ids = no revenue; shipping real ids without an account = crashes. |
| Privacy impact | 🔴 IMPORTANT | Ads BREAK the pure "no data leaves the device" claim — AdMob collects device identifiers. You must: update the privacy policy (disclose advertising), change Play Data safety to "data collected: device IDs (advertising)", and add Google's UMP consent flow for EU users if you distribute there. The core app data (reminders/photos/religion) still never leaves the device — say exactly that. |
| Consent (GDPR/UMP) | 🟡 | Required only if distributing in the EEA/UK. Qatar-only distribution: not required. |

## Huawei (AppGallery)

| Item | Status | Notes |
|---|---|---|
| App runs without Google services | ✅ mostly | Alarms/notifications = pure Android ✓. Voice uses the device's speech service — on Huawei without Google, it may be unavailable → app already degrades gracefully (mic shows a message; typing works). Photo detection (ML Kit bundled model) generally works without Google services; if it fails it FAILS OPEN (photo accepted) by design. |
| Ads on Huawei | 🔴 by design | AdMob does NOT serve on Huawei devices (no Google services) — the banner silently doesn't render, app fully functional. To monetize on AppGallery later: integrate Huawei Ads Kit (`huawei_ads` plugin) behind the same fail-safe pattern. Do this only if Huawei traffic matters — two ad SDKs = more size + more privacy disclosures. |
| AppGallery submission | 🟡 | Create a Huawei Developer account (free), submit the same signed APK/AAB (AppGallery accepts APK). Declare the same privacy answers. Huawei also requires a privacy policy URL. |
| Push/alarm reliability on Huawei | ⚠️ | Huawei's battery manager is aggressive: users must set Memoring to "Manual manage" in Battery settings for reliable alarms (worth an in-app tip later). |

## Honest gaps summary
1. **Play upload signing** — blocked on you creating a keystore + adding 4 secrets (5 minutes; commands above).
2. **Privacy policy URL** — required by both stores; a single static page is enough.
3. **iOS lane** — doesn't exist yet; needs macOS CI + Apple account before any App Store talk.
4. Everything else in the app itself is policy-clean: offline, no tracking, no accounts, minimal permissions, sensitive data optional and local.

---

# Huawei AppGallery submission (account approved 2026-07-03)

## Why the app already works on Huawei phones (no Google services)
| Piece | Behavior without GMS |
|---|---|
| Alarms/notifications | Pure Android APIs — full function ✓ |
| Photos, vault, PIN, prayer times, parser | Pure Dart/Android — full function ✓ |
| AdMob banners | Fail-safe: simply don't render (no crash) |
| Face/scene detection | Bundled on-device models; verification FAILS OPEN if unavailable |
| Voice input | Depends on device speech service; app shows a friendly message if absent |

## Submission checklist (AppGallery Connect)
1. Create app: Android, name "Memoring", default language English.
2. Upload the **SIGNED** APK: `app-arm64-v8a-release.apk` (after signing secrets are
   set, every CI build is release-signed). AppGallery accepts APK directly.
   Optionally also upload the armeabi-v7a APK for old devices.
3. Privacy policy URL: https://hassanlight.github.io/memoring-site/
4. Permissions declaration — justify each: notifications/exact alarm (core reminder
   function), camera (photo reminders + confirmation selfies), microphone (voice
   dictation), boot (restore alarms after restart). No location, no contacts.
5. Content rating: fill the questionnaire (no violence/gambling; UGC = user's own
   photos stored locally only) → typically 3+.
6. App category: Tools or Lifestyle → Efficiency.
7. Copyright: if asked for qualification, select "individual developer" statement.
8. Note for review (recommended): "Reminder app. All user data stays on-device;
   no account required. Ads via AdMob only appear on devices with Google services;
   on Huawei devices no ads are shown."
9. Screenshots: portrait, min 3 (chat, full-screen alarm, Life hub, prayer times).

## Monetization on Huawei (later)
AdMob never serves on Huawei devices. If AppGallery revenue matters, integrate
Huawei Ads Kit (`huawei_ads` Flutter plugin) behind the same fail-safe banner
widget — separate task, adds Huawei SDK weight.
