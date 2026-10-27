# Next Birthday for Android

Android 11+ port of the Next Birthday 2.0 iPhone app. The Swift source remains the reference for copy, artwork, palette, features and portable backups. Android uses a bundled offline WebView interface with native Google Play Billing, atomic local storage, Contacts import, system photo picker, share sheets, local alarms and three resizable AppWidget providers. No website, account or backend is required to use it.

Package: `com.oanarinaldi.nextbirthday`. Version: `2.0 (1)`. Compile and target SDK: 36. Java 17, Gradle 9.3.1, AGP 9.1.1. The wrapper verifies the Gradle distribution checksum.

## Build and verify

Set `JAVA_HOME` to JDK 17 and `ANDROID_HOME` to an Android SDK with platform/build tools 36.

```sh
./gradlew assembleDebug lintDebug
TZ=Europe/Bucharest node --test tests/model.test.cjs
./gradlew connectedDebugAndroidTest
python3 scripts/build-release.py
```

The release build script reads the persistent private upload identity from `~/.local/share/nextbirthday/android-upload/signing.json`, or `NEXTBIRTHDAY_SIGNING_CONFIG`. It never creates or replaces an upload key. That private JSON holds `keystore`, `alias`, `storePassword`, `keyPassword`, and `reviewCode`. Key files and signing configuration must stay outside Git. Back up the upload key securely; updates must use the original Play upload identity.

The signed outputs are `app/build/outputs/bundle/release/app-release.aab` and `app/build/outputs/apk/release/app-release.apk`. Release builds disable WebView debugging and enable R8/resource shrinking.

## Screens and content

Onboarding; Today; Birthdays with live countdowns and grouping; searchable/filterable/sortable People; Add/Edit with optional year, custom relationships, photos, favorites and reminders; birthday details; celebration plans and budgets; Pro checklists and catch-up cadence; free dated connection journal; gift ideas, gifted filters and history; month/year calendar; quick contact actions; settings, privacy and widget help; optional Contacts import; iOS-compatible version 1/2 JSON backup import and version 2 export.

The four `Care*.png` images are copied from the iOS asset catalog. The app logo and launcher icon are copied from the current iOS AppIcon1024 asset. Colors and sizes follow the SwiftUI views. Android status bars, pickers, sharing, permissions, widgets and font rendering use Android facilities; pixel identity with Apple's proprietary fonts and system surfaces has not been certified. Compact widgets support the Lock Screen only on Android devices that provide it.

Swipe right on a person to toggle Favorite. Swipe left or long-press for row actions. The person menu also exposes editing, sharing, favorites and deletion. Saved Pro plans remain readable after access ends.

## Device UI verification

Start the debug app on an emulator. Install Playwright outside the app project, then run:

```sh
PLAYWRIGHT_MODULE=/absolute/path/to/node_modules/playwright node tests/device-ui.cjs
```

The script uses the debug WebView connection, exercises native persistence through UI journeys, restarts the process, captures `GooglePlay/screenshots/phone`, and restores the prior database in `finally`. It requires an emulator with no purchase testing in progress. Preview-only demo content can be viewed by serving `app/src/main/assets` on localhost with `?demo=1`; the preview fixture switch is unavailable when the Android bridge exists.

## Purchases

Both Play subscription products include the same features: `nextbirthday.pro.monthly` (monthly base plan) and `nextbirthday.pro.yearly` (yearly base plan). Prices are loaded from Google Play, with no hardcoded purchase prices or fake unlock. Pending purchases do not unlock Pro. Purchased transactions are acknowledged, active purchases are restored on resume, and successful empty ownership checks revoke cached access. Cached access expires after seven days without a successful ownership query.

Reviewer access is under Pro → Reviewer access. Its private code is supplied only in Play Console's app access instructions. The release embeds its SHA-256 digest; a successful code grants 30 days of review access in separate native preferences. Editable backups cannot grant entitlement. Live purchase/renewal/refund testing requires an approved Play test release and licensed test account; local tests do not certify those services.

## Local data and system behavior

`BirthdayStore` serializes app/reminder/widget access and uses AtomicFile plus revision checks. Unreadable data is preserved and produces a recovery screen. Imports validate the entire backup before merging and skip name/date duplicates. All text is escaped before HTML rendering, the WebView serves only bundled assets at its local HTTPS origin, and CSP/network interception reject remote resources. External links open another app rather than exposing the native bridge to remote pages.

No advertising, analytics, developer server, broad media-library permission or exact-alarm permission. Contacts permission is requested only after choosing import. Photos use Android's system picker. Cloud backup and device transfer are disabled; users export manually. Alarms reschedule after boot, time/timezone changes, edits and the next delivered reminder. Android may delay local reminders during battery saving. February 29 resolves to February 28 in non-leap years and returns to February 29 in leap years.

The icon linework and its applicable Lucide license are in `licenses/`. Store assets and release metadata are in `../GooglePlay/`.
