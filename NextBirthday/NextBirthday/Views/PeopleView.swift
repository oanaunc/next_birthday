import SwiftUI
import SwiftData

/// The full database: search, filter by group, sort, or browse alphabetically.
struct PeopleView: View {

    @Binding var showingAdd: Bool

    @Query private var people: [Person]
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @State private var searchText = ""
    @State private var filter: Filter = .all
    @State private var sort: SortOption = .nextBirthday
    @State private var editTarget: Person?

    enum Filter: Hashable, Identifiable {
        case all
        case favorites
        case group(String)

        var id: String {
            switch self {
            case .all: return "all"
            case .favorites: return "favorites"
            case .group(let name): return "group-\(name)"
            }
        }

        var title: String {
            switch self {
            case .all: return "All"
            case .favorites: return "Favorites"
            case .group(let name): return name
            }
        }
    }

    enum SortOption: String, CaseIterable, Identifiable {
        case nextBirthday = "Next Birthday"
        case name = "Name"
        case age = "Age"
        case date = "Date"
        var id: String { rawValue }
    }

    /// Built-in groups plus any custom relationship the user has typed.
    private var availableGroups: [String] {
        let used = Set(people.compactMap { $0.relationshipRaw }.filter { !$0.isEmpty })
        let builtIn = Relationship.allCases.map(\.rawValue).filter { used.contains($0) }
        let custom = used.subtracting(Set(Relationship.allCases.map(\.rawValue))).sorted()
        return builtIn + custom
    }

    private var filtered: [Person] {
        var result = people.filter { $0.matches(searchText: searchText) }
        switch filter {
        case .all: break
        case .favorites: result = result.filter(\.isFavorite)
        case .group(let name): result = result.filter { $0.relationshipRaw == name }
        }
        return sorted(result)
    }

    private func sorted(_ list: [Person]) -> [Person] {
        switch sort {
        case .nextBirthday:
            return list.sorted { lhs, rhs in
                if lhs.daysUntilBirthday != rhs.daysUntilBirthday {
                    return lhs.daysUntilBirthday < rhs.daysUntilBirthday
                }
                return lhs.fullName < rhs.fullName
            }
        case .name:
            return list.sorted { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending }
        case .age:
            return list.sorted { ($0.currentAge ?? -1) > ($1.currentAge ?? -1) }
        case .date:
            return list.sorted { lhs, rhs in
                if lhs.birthMonth != rhs.birthMonth { return lhs.birthMonth < rhs.birthMonth }
                return lhs.birthDay < rhs.birthDay
            }
        }
    }

    struct LetterSection: Identifiable {
        var id: String { letter }
        let letter: String
        let people: [Person]
    }

    /// A → Z sections, used when sorting by name.
    private var alphabetical: [LetterSection] {
        let grouped = Dictionary(grouping: filtered) { person -> String in
            let first = person.fullName.first.map { String($0).uppercased() } ?? "#"
            return first.rangeOfCharacter(from: .letters) != nil ? first : "#"
        }
        return grouped
            .sorted { $0.key < $1.key }
            .map { LetterSection(letter: $0.key, people: $0.value) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if people.isEmpty {
                    ContentUnavailableView {
                        Label("No people yet", systemImage: "person.2")
                    } description: {
                        Text("Add a birthday to start building your list.")
                    } actions: {
                        Button("Add a Birthday") { showingAdd = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    listContent
                }
            }
            .screenBackground(.people)
            .navigationTitle("People")
            .searchable(text: $searchText, prompt: "Search name, note, month…")
            .navigationDestination(for: Person.self) { PersonDetailView(person: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort by", selection: $sort) {
                            ForEach(SortOption.allCases) { Text($0.rawValue).tag($0) }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus").font(.body.weight(.semibold))
                    }
                }
            }
            .sheet(item: $editTarget) { AddEditPersonView(person: $0) }
        }
    }

    private var listContent: some View {
        VStack(spacing: 0) {
            filterBar

            List {
                if sort == .name {
                    ForEach(alphabetical) { section in
                        Section(section.letter) {
                            ForEach(section.people) { personRow($0) }
                        }
                    }
                } else {
                    ForEach(filtered) { personRow($0) }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .overlay {
                if filtered.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }

    private func personRow(_ person: Person) -> some View {
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
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                context.delete(person)
            } label: { Label("Delete", systemImage: "trash") }

            Button { editTarget = person } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(Theme.peach)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { person.isFavorite.toggle() } label: {
                Label("Favorite", systemImage: person.isFavorite ? "star.slash" : "star.fill")
            }
            .tint(Theme.butter)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(.all)
                chip(.favorites)
                ForEach(availableGroups, id: \.self) { name in
                    chip(.group(name))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func chip(_ option: Filter) -> some View {
        let isSelected = filter == option
        return Button {
            filter = option
        } label: {
            Text(option.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .white : Theme.deepInk)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(isSelected
                                   ? AnyShapeStyle(Theme.purple)
                                   : AnyShapeStyle(Material.ultraThinMaterial))
                )
        }
        .buttonStyle(.plain)
    }
}
