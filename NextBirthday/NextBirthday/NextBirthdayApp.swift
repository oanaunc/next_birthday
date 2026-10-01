import SwiftUI
import SwiftData
import UIKit

@main
struct NextBirthdayApp: App {

    @State private var settings = AppSettings()
    @State private var subscriptions = SubscriptionStore()

    /// Everything lives on the device. No account, no server.
    private let container: ModelContainer = {
        let schema = Schema([Person.self, GiftIdea.self, GiftRecord.self])
        let isDemo = ProcessInfo.processInfo.environment["DEMO_SCREEN"] != nil
            || ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("--demo-screen=") }
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isDemo)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A corrupt store shouldn't hard-crash on launch; fall back to memory
            // so the user can still use the app and re-import.
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }()

    var body: some Scene {
        WindowGroup {
            appRoot
                .environment(settings)
                .environment(subscriptions)
                .task { await subscriptions.start() }
                .tint(settings.accentColor)
                .preferredColorScheme(.light)
        }
        .modelContainer(container)
    }

    @ViewBuilder
    private var appRoot: some View {
#if DEBUG
        if let route = ProcessInfo.processInfo.environment["DEMO_SCREEN"]
            ?? ProcessInfo.processInfo.arguments
                .first(where: { $0.hasPrefix("--demo-screen=") })?
                .replacingOccurrences(of: "--demo-screen=", with: "") {
            DemoScreenshotRoot(route: route)
        } else {
            RootView()
        }
#else
        RootView()
#endif
    }
}

#if DEBUG
/// Debug-only showroom used to capture deterministic App Store screenshots.
private struct DemoScreenshotRoot: View {
    let route: String

    @Environment(\.modelContext) private var context
    @Query private var people: [Person]
    @State private var showingAdd = false

    var body: some View {
        Group {
            if route == "welcome" {
                OnboardingView()
            } else if route == "start" {
                OnboardingView(initialPage: 1)
            } else if people.isEmpty {
                ZStack {
                    ScreenBackground(art: .upcoming)
                    ProgressView()
                }
            } else {
                screen
            }
        }
        .task { seedIfNeeded() }
    }

    @ViewBuilder
    private var screen: some View {
        switch route {
        case "studio": CelebrationStudioView(showingAdd: $showingAdd)
        case "journal": NavigationStack { CelebrationPlanView(person: person(named: "Emma"), startsAtJournal: true) }
        case "privacy": NavigationStack { PrivacyView() }
        case "plan": NavigationStack { CelebrationPlanView(person: person(named: "Emma")) }
        case "pro": NavigationStack { ProPlanView() }
        case "calendar": CalendarScreen()
        case "people": PeopleView(showingAdd: $showingAdd)
        case "settings": SettingsView()
        case "detail-emma":
            NavigationStack { PersonDetailView(person: person(named: "Emma")) }
        case "detail-james":
            NavigationStack { PersonDetailView(person: person(named: "James")) }
        case "gifts":
            NavigationStack { GiftIdeasView(person: person(named: "Emma")) }
        case "add": AddEditPersonView(person: nil)
        default: UpcomingView(showingAdd: $showingAdd)
        }
    }

    private func person(named name: String) -> Person {
        people.first { $0.firstName == name } ?? people[0]
    }

    @MainActor
    private func seedIfNeeded() {
        guard people.isEmpty else { return }

        let specs: [(String, String, Int, Int, String, Bool, String, String)] = [
            ("Emma", "Johnson", 1, 1997, "Sister", true, "Loves coffee, sunsets, and little weekend trips.", "DemoEmma"),
            ("James", "Smith", 0, 1992, "Best Friend", true, "Call in the morning. Dinner booked for 7:30 PM.", "DemoJames"),
            ("Olivia", "Davis", 4, 1999, "Friend", false, "Collects ceramics and loves botanical gardens.", "DemoOlivia"),
            ("Noah", "Brown", 9, 1994, "Work", false, "Team card is hidden in the top drawer.", "DemoNoah"),
            ("Ava", "Williams", 18, 1996, "Family", true, "Favorite flowers: peonies.", "DemoAva"),
            ("Alex", "Johnson", 34, 1991, "Friend", false, "Planning a hiking trip this autumn.", "DemoAlex")
        ]

        for spec in specs {
            let birthday = Calendar.current.date(byAdding: .day, value: spec.2, to: Date()) ?? Date()
            let parts = Calendar.current.dateComponents([.month, .day], from: birthday)
            let photo = UIImage(named: spec.7)?.jpegData(compressionQuality: 0.86)
            let person = Person(firstName: spec.0,
                                lastName: spec.1,
                                birthMonth: parts.month ?? 1,
                                birthDay: parts.day ?? 1,
                                birthYear: spec.3,
                                relationshipRaw: spec.4,
                                isFavorite: spec.5,
                                notes: spec.6,
                                photoData: photo)
            context.insert(person)

            if spec.0 == "Emma" {
                person.celebrationIntent = "A sunrise picnic, just the two of us."
                person.celebrationBudget = 40
                person.celebrationChecklist = ["Find a quiet spot", "Bring her favorite coffee", "Write a handwritten note"]
                person.completedCelebrationSteps = ["Find a quiet spot"]
                person.connectionJournal = ["September 24 — A long walk and a good conversation."]
                person.lastConnectionDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())
                for title in ["Personalized necklace", "Spa day", "Weekend getaway"] {
                    let idea = GiftIdea(title: title, person: person)
                    context.insert(idea)
                    person.giftIdeas?.append(idea)
                }
                let history = GiftRecord(year: 2025, item: "Handmade photo album", person: person)
                context.insert(history)
                person.giftHistory?.append(history)
            }
        }
        try? context.save()
    }
}
#endif
