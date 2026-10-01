# Next Birthday 2.0 — make people feel remembered

A private celebration planner and connection journal, built with SwiftUI, SwiftData, WidgetKit and StoreKit 2. The Today workspace turns upcoming birthdays into personal intentions, budgets and moments together. Optional Pro adds editable celebration checklists and a per-person catch-up cadence. Core birthdays, reminders, gift ideas, journal, intentions, budgets and backups stay free.

Open `NextBirthday/NextBirthday.xcodeproj`. Bundle IDs and App Group remain tied to the existing App Store Connect record. Personal data stays local; Apple handles subscription product loading, purchases and entitlement verification.

Build: `xcodebuild -project NextBirthday/NextBirthday.xcodeproj -scheme NextBirthday -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO`

Backup tests: `scripts/test-backups.sh` (Apple silicon macOS 14+). Covers planning/journal round trips, legacy JSON, duplicates and malformed data.

Release assets and review copy: `Release-2.0/`. Subscription product IDs are in `SubscriptionStore.swift`; configure both in one App Store Connect group at the same service level. Real product setup and sandbox lifecycle testing are still required before paid release. Unavailable products show an honest retry state; there is no fake unlock.

Original implementation notes below describe version 1 and are retained for historical context. The network-free statements do not apply to optional StoreKit subscriptions in version 2.

---

# Next Birthday — iOS app + widgets

A complete, offline-first birthday app for iPhone: SwiftUI + SwiftData + WidgetKit, no account, no server, no network calls at all.

Open `NextBirthday/NextBirthday.xcodeproj` in Xcode 15.4 or later and press Run.

---

## Read this first

**This project has never been compiled.** It was written without access to Xcode or a Swift toolchain, so it has been verified structurally (project file integrity, resource paths, imports, target boundaries, plist validity) and reviewed statically for API and concurrency errors — but not built. Expect to fix a handful of compile errors on the first build. They should be small and local.

**Two settings you must change before it will run on a device:**

1. **Signing team.** Select the project → both targets (`NextBirthday` and `NextBirthdayWidgetExtension`) → Signing & Capabilities → pick your team.
2. **Bundle IDs and App Group.** These are pinned to the existing App Store Connect record for **Next Birthday Reminder**, which is bound to `com.nextbirthday.app`. Do not change them — a bundle ID becomes permanent on that record the moment a build is accepted.

   - app: `com.nextbirthday.app`
   - widget: `com.nextbirthday.app.widget`
   - App Group: `group.com.nextbirthday.app`

   If you ever do need to change the prefix, change it in **three** places or the widgets will show nothing:
   - both targets' `PRODUCT_BUNDLE_IDENTIFIER`
   - `NextBirthday/NextBirthday.entitlements` and `NextBirthdayWidget/NextBirthdayWidget.entitlements`
   - `Shared/SharedConstants.swift` → `appGroupID`

   The App Group also has to be created in your Apple Developer account and enabled on both targets under Signing & Capabilities.

The simulator will run without any of this; the App Group falls back to the app's own documents directory when the group isn't available, so the app works and only the widgets go blank.

---

## Uploading to App Store Connect / TestFlight

Archiving does **not** require any of this. Uploading does. If Xcode fails with
`The operation couldn't be completed. (IDEDistribution.DistributionAppRecordProviderError error 0.)`
it means it could not resolve an App Store Connect record for the bundle ID. Do these in order:

The app record **Next Birthday Reminder** already exists and is bound to `com.nextbirthday.app` (registered by Xcode as "XC com nextbirthday app"). No build has ever been uploaded to it. What's still missing is the widget's identifier and the App Group.

1. **developer.apple.com → Certificates, Identifiers & Profiles → Identifiers.** You should already see the app ID. Add the other two:
   - App ID `com.nextbirthday.app.widget`
   - App Group `group.com.nextbirthday.app`

   Then enable the **App Groups** capability on *both* App IDs and assign that group to each (edit App ID → App Groups → Configure). Xcode's automatic signing registers app IDs on its own but does not create App Groups — that one is manual.

2. **Xcode → Signing & Capabilities**, on both targets: set your team, confirm Automatically manage signing resolves without a red error, and confirm the App Group row shows `group.com.nextbirthday.app` ticked.

3. Archive and upload. The archive you made earlier is stale — discard it and build a fresh one.

If it still fails: check the record was not created against the widget's bundle ID, that your Apple Developer role is App Manager or Admin, and try Xcode → Settings → Accounts, remove and re-add the Apple ID to clear a stale session.

### Do not change the bundle ID

`com.nextbirthday.app` is now load-bearing. App Store Connect lets you repoint a record's bundle ID only while no build has been accepted; after that it's permanent, because purchases, analytics and updates all hang off it. If the project and the record ever disagree again, change the *project* to match the record.

### Name

The store listing is "Next Birthday Reminder"; the Home Screen name is "Next Birthday" (`CFBundleDisplayName` in `NextBirthday/Info.plist`). A shorter Home Screen name is normal and allowed — iOS truncates anything longer anyway. Change that key if you'd rather they match exactly.

---

## What's in it

**Upcoming** — hero card for the next birthday with a live day/hour/minute/second countdown, a stats strip, then birthdays grouped Today / Tomorrow / This Week / Next Week / by month. Swipe right on a row to favourite; swipe left for Done, Edit and Message. A badge appears when Contacts has birthdays the app doesn't.

**Calendar** — month grid with dots on birthday days, tap a day to see who, plus a Year view showing how many birthdays land in each month.

**People** — the full database with search across name, notes, relationship, month and zodiac; filter chips for All / Favorites / each group; sort by next birthday, name (A–Z sections), age or calendar date.

**Person detail** — countdown, age, zodiac, per-person reminder overrides, notes, gift ideas with a checklist, gift history by year, and Message / Call / WhatsApp / copy-a-message actions when the person is linked to a contact.

**Add / Edit** — photo picker, names, month/day pickers with an optional year (leave it off and no age is shown), relationship including custom groups, favourite, custom reminders, notes.

**Import from Contacts** — lists only contacts that already have a birthday saved, preselects the new ones, marks anything already imported, and flags possible duplicates by name + date. Nothing is written until you tap Import.

**Reminders** — multi-select offsets (day of, 1 day, 3 days, 1 week, 2 weeks, 1 month), a global notification time, and "smart wording" that turns early reminders into gift nudges and same-day ones into message nudges.

**Widgets** — Up Next (small / medium / large), Countdown (small / medium), and Lock Screen (inline, circular, rectangular). All deep-link into the right person via `nextbirthday://person/<uuid>`.

Home Screen widget colours all come from colorsets in `NextBirthdayWidget/Assets.xcassets` (`WidgetInk`, `WidgetInkSecondary`, `WidgetAccent`, `WidgetAccentSoft`, `WidgetBackground`, `WidgetBackgroundAlt`), each with an explicit light and dark variant. **Don't reintroduce `.primary` or `.secondary` in those files** — they follow the system appearance while a hardcoded background does not, which is what made the first build unreadable in dark mode. The Lock Screen widget is the exception and deliberately uses system colours, because iOS applies its own vibrancy treatment there.

**Settings** — default reminders, notification time, theme, six accent colours, background artwork on/off, age/zodiac/countdown display toggles, JSON export and import, and a privacy page.

## Structure

```
NextBirthday/
├── NextBirthday.xcodeproj
├── NextBirthday/          app target
│   ├── Models/            Person, GiftIdea, GiftRecord, Relationship, ReminderOffset
│   ├── Core/              Theme, backgrounds, AppSettings, AvatarView, grouping
│   ├── Services/          notifications, Contacts import, widget sync, backup
│   ├── Views/             one file per screen
│   └── Assets.xcassets    app icon + 9 screen backgrounds + AppLogo
├── Shared/                compiled into BOTH targets
│   ├── BirthdayMath.swift date, countdown, age and zodiac logic
│   ├── WidgetSnapshot.swift
│   └── SharedConstants.swift
└── NextBirthdayWidget/    widget extension
```

`Shared/` is the only code the widget can see — it holds no app types, so the widget never touches SwiftData directly. The app writes a small JSON snapshot into the App Group container and the widget reads it.

## Assets

The app icon and the onboarding logo come from your `logo.png`. Nine of the images in `images/` were picked as per-screen backgrounds and baked into the asset catalog at 828×1300, JPEG, blurred and scrimmed at runtime so text stays legible in both light and dark mode. Settings → Appearance → Background artwork turns them off entirely.

The originals in `images/` are untouched — swap any background by replacing the JPEG inside the matching `.imageset` folder.

## Known limits and deliberate omissions

- **64 pending notifications.** iOS caps this per app. The scheduler always keeps the soonest ~60 and rebuilds the queue every time the app becomes active or the data changes. With three reminders per person that covers roughly the next 20 birthdays — fine in practice, but if someone never opens the app for a year, later reminders won't have been registered.
- **No Facebook import.** As you said: Facebook restricted friend birthday access years ago, and building on it invites App Store and maintenance problems. JSON export/import is in; CSV and `.ics` import are not.
- **No iCloud sync.** The store is local-only. Adding CloudKit later means a `ModelConfiguration(cloudKitDatabase:)` change plus making every SwiftData property optional or defaulted — the models are already written that way, so the migration is small.
- **No share extension** ("Share → Add to Next Birthday"), no anniversaries or other date types, no per-group default reminders (groups exist and filter, but reminder defaults are global or per person).
- **Portrait iPhone only.** `TARGETED_DEVICE_FAMILY = 1`, portrait-locked.

## If the project file won't open

`project.pbxproj` was generated programmatically and checked (balanced syntax, no duplicate or dangling object IDs, every source file compiled exactly once per target, every group path resolving to a real file). If Xcode still rejects it, the fallback is to create a fresh iOS App project plus a Widget Extension target in Xcode and drag in the `NextBirthday/`, `Shared/` and `NextBirthdayWidget/` folders — adding the three `Shared/` files to both targets. Nothing in the source depends on the generated project file.
