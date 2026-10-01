import SwiftUI
import SwiftData

/// Tab shell + the one place where notifications and widgets get resynced.
struct RootView: View {

    @Environment(AppSettings.self) private var settings
    @Environment(SubscriptionStore.self) private var subscriptions
    @Environment(\.scenePhase) private var scenePhase
    @Query private var people: [Person]

    @State private var selectedTab: Tab = .studio
    @State private var showingAdd = false
    @State private var deepLinkedPerson: Person?

    enum Tab: Hashable { case upcoming, calendar, people, settings, studio }

    var body: some View {
        Group {
            if settings.hasCompletedOnboarding {
                mainTabs
            } else {
                OnboardingView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: settings.hasCompletedOnboarding)
        .task { await syncEverything() }
        .onChange(of: syncKey) { _, _ in
            Task { await syncEverything() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await syncEverything() } }
        }
        .onOpenURL { url in handleDeepLink(url) }
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            CelebrationStudioView(showingAdd: $showingAdd)
                .tabItem { Label("Today", systemImage: "leaf.fill") }
                .tag(Tab.studio)

            UpcomingView(showingAdd: $showingAdd)
                .tabItem { Label("Birthdays", systemImage: "gift.fill") }
                .tag(Tab.upcoming)


            PeopleView(showingAdd: $showingAdd)
                .tabItem { Label("People", systemImage: "person.2.fill") }
                .tag(Tab.people)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .tint(Theme.accent(at: settings.accentIndex))
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .sheet(isPresented: $showingAdd) {
            AddEditPersonView(person: nil)
        }
        .sheet(item: $deepLinkedPerson) { person in
            NavigationStack { PersonDetailView(person: person) }
        }
    }

    // MARK: - Sync

    /// Changes whenever anything the widgets or reminders depend on changes.
    /// Watching `people.count` alone would miss edits to an existing person.
    private var syncKey: String {
        people
            .map { person in
                let reminders = person.usesCustomReminders
                    ? person.customReminderDays.map(String.init).joined(separator: ".")
                    : "-"
                return "\(person.uuid):\(person.birthMonth)/\(person.birthDay)/\(person.birthYear ?? 0):\(person.firstName)\(person.lastName):\(person.isFavorite ? 1 : 0):\(reminders)"
            }
            .sorted()
            .joined(separator: "|")
    }

    @MainActor
    private func syncEverything() async {
        await subscriptions.refreshEntitlements()
        WidgetSync.refresh(with: people)
        await NotificationScheduler.rebuild(for: people, settings: settings)
    }

    /// nextbirthday://person/<uuid> — used by the widgets.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == SharedConstants.deepLinkScheme else { return }
        if url.host == "add" {
            showingAdd = true
            return
        }
        guard url.host == "person" else { return }
        let uuid = url.lastPathComponent
        deepLinkedPerson = people.first { $0.uuid == uuid }
    }
}
