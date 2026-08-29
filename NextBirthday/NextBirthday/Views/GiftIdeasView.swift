import SwiftUI
import SwiftData

/// Gift ideas and gift history for one person.
struct GiftIdeasView: View {
    @Bindable var person: Person

    @Environment(\.modelContext) private var context
    @State private var newIdea = ""
    @State private var filter: Filter = .open

    enum Filter: String, CaseIterable, Identifiable {
        case open = "To consider"
        case gifted = "Gifted"
        case all = "All"
        var id: String { rawValue }
    }

    private var ideas: [GiftIdea] {
        switch filter {
        case .open: return person.sortedGiftIdeas.filter { !$0.isPurchased }
        case .gifted: return person.sortedGiftIdeas.filter(\.isPurchased)
        case .all: return person.sortedGiftIdeas
        }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    TextField("Add a gift idea", text: $newIdea)
                        .onSubmit(add)
                    Button(action: add) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Theme.purple)
                    }
                    .disabled(newIdea.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } footer: {
                Text("Tip: note what they mention wanting during the year — that's what makes this list useful.")
            }

            Section {
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }

            Section("Ideas") {
                if ideas.isEmpty {
                    Text("Nothing here yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(ideas) { idea in
                        GiftIdeaRow(idea: idea) { toggle(idea) }
                            .swipeActions {
                                Button(role: .destructive) {
                                    context.delete(idea)
                                } label: { Label("Delete", systemImage: "trash") }

                                Button {
                                    toggle(idea)
                                } label: {
                                    Label(idea.isPurchased ? "Undo" : "Gifted",
                                          systemImage: idea.isPurchased ? "arrow.uturn.backward" : "checkmark")
                                }
                                .tint(Theme.mint)
                            }
                    }
                }
            }

            if !person.sortedGiftHistory.isEmpty {
                Section("Gift History") {
                    ForEach(person.sortedGiftHistory) { record in
                        HStack {
                            Text(String(record.year))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.purple)
                                .frame(width: 52, alignment: .leading)
                            Text(record.item)
                            Spacer()
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                context.delete(record)
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground(.gifts, intensity: 0.22)
        .navigationTitle("Gift Ideas")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func add() {
        let title = newIdea.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        context.insert(GiftIdea(title: title, person: person))
        newIdea = ""
    }

    /// Marking an idea as gifted also files it in the history for this year.
    private func toggle(_ idea: GiftIdea) {
        idea.isPurchased.toggle()
        let year = BirthdayMath.calendar.component(.year, from: person.nextBirthday)

        if idea.isPurchased {
            let alreadyLogged = (person.giftHistory ?? []).contains {
                $0.year == year && $0.item == idea.title
            }
            if !alreadyLogged {
                context.insert(GiftRecord(year: year, item: idea.title, person: person))
            }
        } else if let record = (person.giftHistory ?? []).first(where: {
            $0.year == year && $0.item == idea.title
        }) {
            context.delete(record)
        }
    }
}
