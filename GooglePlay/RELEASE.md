# Next Birthday Reminder — Android 2.0 (1)

Package: `com.oanarinaldi.nextbirthday`.

Google Play app: `4972394195669658497` in developer account `8359156760975569195`.

Console: https://play.google.com/console/u/0/developers/8359156760975569195/app/4972394195669658497/app-dashboard

The Android app ports the Next Birthday 2.0 source, original artwork and content. Native Android services replace StoreKit, Contacts, Photos, notifications, WidgetKit and sharing. Pixel parity with Apple's fonts and platform controls remains unverified.

Validation completed on 27 October 2026:

- Signed release AAB/APK, R8/resource shrinking, `lintRelease`, `lintDebug` and debug build passed.
- 16 portable model tests passed (leap years, DST calendar days, iOS backups, all-or-nothing malformed import, duplicate detection, gifts, connection cadence, entitlement isolation).
- 7 Android instrumented tests passed (atomic persistence, stale writes, invalid/duplicate data, date arithmetic, local reminders, custom reminders, entitlement isolation, widget resources).
- 6 emulator UI verification groups passed (onboarding/editor, free plans/journal and Pro gating, gift history/undo, search/settings/backups, process restart persistence, showroom rendering). Twelve actual Android screenshots are under `screenshots/phone/`.
- Google Play purchase lifecycle testing is still required with a licensed account; local tests do not simulate real payments.

Release bundle SHA-256: `499fe26dea2937f2db25b4f83797e0818c3e04ee88025f4994dae7c1fd14b2b1`.

Subscription setup mirrors the iOS StoreKit configuration: monthly USD 1.99 and yearly USD 14.99, with localized Play prices shown by the app. Product IDs: `nextbirthday.pro.monthly` and `nextbirthday.pro.yearly`.

Private signing identity and reviewer code: `~/.local/share/nextbirthday/android-upload/`. Never commit those files or include the reviewer code in public release copy.

Privacy and terms were published through `oanaunc/oanarina_website` commit `08a4955`; the hosting workflow succeeded and the privacy page returned HTTP 200.

Submission status: app record created; listing, declarations, products and production release are being configured. Not yet submitted for review.
