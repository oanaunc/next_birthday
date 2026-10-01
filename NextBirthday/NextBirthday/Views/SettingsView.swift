import SwiftUI
import SwiftData
import UserNotifications
import UniformTypeIdentifiers

struct SettingsView: View {

    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Query private var people: [Person]

    @State private var showingImport = false
    @State private var showingFileImporter = false
    @State private var exportURL: URL?
    @State private var importMessage: String?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section("A little more room to care") {
                    NavigationLink { ProPlanView() } label: {
                        Label("Next Birthday Pro", systemImage: "leaf.circle")
                    }
                    NavigationLink { CalendarScreen() } label: {
                        Label("Birthday calendar", systemImage: "calendar")
                    }
                }
                // MARK: Reminders
                Section {
                    NavigationLink {
                        DefaultRemindersView()
                    } label: {
                        LabeledContent {
                            Text(settings.defaultRemindersSummary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } label: {
                            Label("Default reminders", systemImage: "bell.badge")
                        }
                    }

                    DatePicker(selection: notificationTimeBinding, displayedComponents: .hourAndMinute) {
                        Label("Notification time", systemImage: "clock")
                    }

                    Toggle(isOn: $settings.smartRemindersEnabled) {
                        Label("Smart wording", systemImage: "wand.and.stars")
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    if notificationStatus == .denied {
                        Text("Notifications are turned off for Next Birthday. Enable them in iOS Settings to get reminders.")
                            .foregroundStyle(.red)
                    } else {
                        Text("Smart wording changes early reminders into gift nudges and same-day ones into message nudges.")
                    }
                }

                // MARK: Appearance
                Section("Appearance") {
                    HStack {
                        Label("Accent colour", systemImage: "paintpalette")
                        Spacer()
                        HStack(spacing: 10) {
                            ForEach(Array(Theme.accentOptions.enumerated()), id: \.offset) { index, colour in
                                Button {
                                    settings.accentIndex = index
                                } label: {
                                    Circle()
                                        .fill(colour)
                                        .frame(width: 22, height: 22)
                                        .overlay(
                                            Circle().stroke(Color.primary.opacity(
                                                settings.accentIndex == index ? 0.8 : 0), lineWidth: 2)
                                                .padding(-3)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Toggle(isOn: $settings.showBackgroundArt) {
                        Label("Warm background wash", systemImage: "photo.on.rectangle.angled")
                    }
                }

                // MARK: Display
                Section("Birthday display") {
                    Toggle(isOn: $settings.showAge) {
                        Label("Show age", systemImage: "number")
                    }
                    Toggle(isOn: $settings.showZodiac) {
                        Label("Show zodiac signs", systemImage: "sparkles")
                    }
                    Toggle(isOn: $settings.showDaysRemaining) {
                        Label("Show days remaining", systemImage: "hourglass")
                    }
                }

                // MARK: Contacts
                Section("Contacts") {
                    Button {
                        showingImport = true
                    } label: {
                        Label("Import from Contacts", systemImage: "person.crop.circle.badge.plus")
                    }
                    if let last = settings.lastContactsCheck {
                        LabeledContent("Last import",
                                       value: last.formatted(date: .abbreviated, time: .shortened))
                            .font(.footnote)
                    }
                }

                // MARK: Data
                Section {
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Export birthdays (JSON)", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button {
                            exportURL = BackupService.writeTemporaryFile(from: people)
                        } label: {
                            Label("Prepare export", systemImage: "square.and.arrow.up")
                        }
                    }

                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("Import backup", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Data")
                } footer: {
                    if let importMessage {
                        Text(importMessage)
                    } else {
                        Text("\(people.count) \(people.count == 1 ? "person" : "people") stored on this iPhone.")
                    }
                }

                // MARK: Privacy
                Section {
                    NavigationLink {
                        PrivacyView()
                    } label: {
                        Label("Privacy & Data", systemImage: "lock.shield")
                    }
                    NavigationLink {
                        WidgetHelpView()
                    } label: {
                        Label("Widgets", systemImage: "square.grid.2x2")
                    }
                    LabeledContent("Version", value: appVersion)
                        .font(.footnote)
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground(.settings, intensity: 0.25)
            .navigationTitle("Settings")
            .sheet(isPresented: $showingImport) { ImportContactsView() }
            .fileImporter(isPresented: $showingFileImporter,
                          allowedContentTypes: [.json]) { result in
                handleFileImport(result)
            }
            .task {
                notificationStatus = await NotificationScheduler.authorizationStatus()
                let isScreenshotDemo = ProcessInfo.processInfo.environment["DEMO_SCREEN"] != nil
                    || ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("--demo-screen=") }
                if notificationStatus == .notDetermined && !isScreenshotDemo {
                    await NotificationScheduler.requestAuthorization()
                    notificationStatus = await NotificationScheduler.authorizationStatus()
                }
            }
            .onChange(of: people.count) { _, _ in exportURL = nil }
        }
    }

    private var notificationTimeBinding: Binding<Date> {
        Binding {
            var components = DateComponents()
            components.hour = settings.notificationHour
            components.minute = settings.notificationMinute
            return BirthdayMath.calendar.date(from: components) ?? Date()
        } set: { newValue in
            let components = BirthdayMath.calendar.dateComponents([.hour, .minute], from: newValue)
            settings.notificationHour = components.hour ?? 9
            settings.notificationMinute = components.minute ?? 0
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    @MainActor
    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let needsScope = url.startAccessingSecurityScopedResource()
            defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                importMessage = "Couldn't read that file."
                return
            }
            switch BackupService.importJSON(data, into: context, existing: people) {
            case .success(let added, let skipped):
                importMessage = "Imported \(added). Skipped \(skipped) already saved."
            case .failure(let message):
                importMessage = message
            }
        case .failure:
            importMessage = "Import cancelled."
        }
    }
}

// MARK: - Default reminders

struct DefaultRemindersView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        List {
            Section {
                ForEach(ReminderOffset.allCases) { offset in
                    Button {
                        toggle(offset.rawValue)
                    } label: {
                        HStack {
                            Text(offset.label).foregroundStyle(.primary)
                            Spacer()
                            if settings.defaultReminderDays.contains(offset.rawValue) {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Theme.purple)
                            }
                        }
                    }
                }
            } header: {
                Text("Pick as many as you like")
            } footer: {
                Text("These apply to everyone who doesn't have custom reminders set on their own page.")
            }

            Section("Suggested by group") {
                ForEach(Relationship.allCases) { relationship in
                    HStack {
                        Label(relationship.rawValue, systemImage: relationship.symbol)
                            .foregroundStyle(relationship.tint)
                        Spacer()
                        Text(relationship.suggestedReminderDays
                                .map { ReminderOffset.shortLabel(forDays: $0) }
                                .joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground(.settings, intensity: 0.2)
        .navigationTitle("Default reminders")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ days: Int) {
        var current = Set(settings.defaultReminderDays)
        if current.contains(days) { current.remove(days) } else { current.insert(days) }
        settings.defaultReminderDays = current.sorted(by: >)
    }
}

// MARK: - Privacy

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Your birthdays stay on your iPhone.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.deepInk)

                Text("""
Next Birthday has no account, no login and no server. Everything you add — names, dates, photos, notes, gift ideas, celebration plans and journal entries — is stored in the app's own database on this device.

Optional Pro subscriptions connect to Apple through StoreKit to load plans, process purchases and verify access. Your personal planning data is not sent with purchases. Apple handles billing.

Contacts access is optional and read-only. When you import, the app reads the names and birthdays you select and copies them locally. It never uploads them, and it never writes back to your Contacts.

Notifications are scheduled locally by iOS. Nothing about them leaves the phone.

Widgets read a small copy of your upcoming birthdays from a shared container on this device.

Deleting the app deletes all of it. Use Export in Settings first if you want to keep a copy.
""")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Label("No account · No tracking · No analytics", systemImage: "checkmark.seal.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.mint)
                    .padding(.top, 4)
            }
            .padding(20)
        }
        .screenBackground(.settings, intensity: 0.25)
        .navigationTitle("Privacy & Data")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Widget help

struct WidgetHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Add a widget")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.deepInk)

                stepRow(1, "Touch and hold an empty area of your Home Screen until the icons jiggle.")
                stepRow(2, "Tap the + button in the top corner.")
                stepRow(3, "Search for Next Birthday and pick a size.")

                Divider().padding(.vertical, 6)

                Text("Available widgets").font(.headline)
                bullet("Up Next — small, medium and large lists of who's coming up.")
                bullet("Countdown — one person, big number of days.")
                bullet("Lock Screen — inline text, a circular countdown, or a compact pair.")

                Text("Widgets refresh a few times a day and whenever you change something in the app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            .padding(20)
        }
        .screenBackground(.settings, intensity: 0.25)
        .navigationTitle("Widgets")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stepRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Theme.purple))
            Text(text).font(.subheadline)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").foregroundStyle(Theme.pink)
            Text(text).font(.subheadline)
        }
    }
}
