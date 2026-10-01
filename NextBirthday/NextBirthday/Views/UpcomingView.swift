import SwiftUI
import SwiftData

struct UpcomingView: View {

    @Binding var showingAdd: Bool

    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Query private var people: [Person]

    @State private var path = NavigationPath()
    @State private var newContactBirthdays = 0
    @State private var showingImport = false
    @State private var messageTarget: Person?
    @State private var editTarget: Person?

    private var sorted: [Person] {
        people.sorted { lhs, rhs in
            if lhs.daysUntilBirthday != rhs.daysUntilBirthday {
                return lhs.daysUntilBirthday < rhs.daysUntilBirthday
            }
            return lhs.fullName < rhs.fullName
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if people.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .screenBackground(.upcoming)
            .navigationTitle("Birthdays")
            .navigationDestination(for: Person.self) { PersonDetailView(person: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if newContactBirthdays > 0 {
                        Button { showingImport = true } label: {
                            Label("\(newContactBirthdays) new", systemImage: "bell.badge.fill")
                                .font(.caption.weight(.semibold))
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus").font(.body.weight(.semibold))
                    }
                    .accessibilityLabel("Add birthday")
                }
            }
            .sheet(isPresented: $showingImport) { ImportContactsView() }
            .sheet(item: $editTarget) { AddEditPersonView(person: $0) }
            .sheet(item: $messageTarget) { person in
                QuickActionsSheet(person: person)
                    .presentationDetents([.medium])
            }
            .task { await checkForNewContactBirthdays() }
        }
    }

    // MARK: Content

    private var listContent: some View {
        List {
            if let next = sorted.first {
                Section {
                    HeroCard(person: next) { messageTarget = next }
                        .contentShape(Rectangle())
                        .onTapGesture { path.append(next) }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    statsStrip
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            ForEach(BirthdayGrouping.sections(from: people, skippingFirst: true)) { section in
                Section {
                    ForEach(section.people) { person in
                        NavigationLink(value: person) {
                            PersonRow(person: person)
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 2)
                        )
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button { toggleAcknowledged(person) } label: {
                                Label(person.isAcknowledgedThisYear ? "Undo" : "Done",
                                      systemImage: person.isAcknowledgedThisYear
                                        ? "arrow.uturn.backward" : "checkmark")
                            }
                            .tint(Theme.mint)

                            Button { editTarget = person } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(Theme.peach)

                            Button { messageTarget = person } label: {
                                Label("Message", systemImage: "message.fill")
                            }
                            .tint(Theme.blue)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button { person.isFavorite.toggle() } label: {
                                Label("Favorite", systemImage: person.isFavorite ? "star.slash" : "star.fill")
                            }
                            .tint(Theme.butter)
                        }
                    }
                } header: {
                    HStack(spacing: 8) {
                        Text(section.title.uppercased())
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text("\(section.people.count)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.primary.opacity(0.07)))
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var statsStrip: some View {
        let stats = BirthdayGrouping.stats(for: people)
        return HStack(spacing: 10) {
            StatPill(value: stats.thisWeek, label: "this week", tint: Theme.purple)
            StatPill(value: stats.thisMonth, label: "this month", tint: Theme.pink)
            StatPill(value: people.count, label: "people", tint: Theme.blue)
        }
    }

    private func toggleAcknowledged(_ person: Person) {
        let year = BirthdayMath.calendar.component(.year, from: person.nextBirthday)
        person.acknowledgedYear = person.isAcknowledgedThisYear ? nil : year
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 130, height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .shadow(color: Theme.deepInk.opacity(0.15), radius: 18, y: 8)

            Text("No birthdays yet")
                .font(.title3.weight(.semibold))
            Text("Add someone, or bring in the birthdays already saved in your Contacts.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 10) {
                Button { showingImport = true } label: {
                    Label("Import from Contacts", systemImage: "person.crop.circle.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button { showingAdd = true } label: {
                    Label("Add a Birthday", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 40)
            .padding(.top, 6)
        }
    }

    // MARK: New contacts badge

    @MainActor
    private func checkForNewContactBirthdays() async {
        guard ContactsImporter.authorizationStatus == .authorized else { return }
        let candidates = await ContactsImporter.fetchCandidates()
        let known = Set(people.compactMap { $0.contactIdentifier })
        let existingKeys = Set(people.map { "\($0.fullName.lowercased())|\($0.birthMonth)-\($0.birthDay)" })
        newContactBirthdays = candidates.filter {
            !known.contains($0.id) && !existingKeys.contains($0.matchKey)
        }.count
    }
}

struct StatPill: View {
    let value: Int
    let label: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Text("\(value)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}
