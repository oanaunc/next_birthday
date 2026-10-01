import SwiftUI
import SwiftData

struct CelebrationPlanView: View {
    @Bindable var person: Person
    var startsAtJournal = false
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.modelContext) private var context
    @State private var step = ""
    @State private var journal = ""
    @State private var error: String?
    @State private var connectionDate = Date()
    var body: some View {
        ScrollViewReader { proxy in
        Form {
            Section {
                Image("CareJournal").resizable().scaledToFill().frame(height: 120).clipped().listRowInsets(EdgeInsets())
                Text(person.displayFirstName).font(.system(.largeTitle, design: .serif, weight: .semibold))
                Text("\(person.shortDateLabel) · \(person.countdownLabel)").foregroundStyle(.secondary)
                NavigationLink("Birthday details & gift ideas") { PersonDetailView(person: person) }
            }
            Section {
                TextField("A picnic at their favorite spot…", text: $person.celebrationIntent, axis: .vertical).lineLimit(3...6)
                LabeledContent("Budget (\(Locale.current.currency?.identifier ?? "local currency"))") {
                    TextField("0", value: $person.celebrationBudget, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                }
            } header: { Text("The intention") } footer: { Text("Start with who they are. A thoughtful gesture can cost nothing.") }
            Section("Make it happen") {
                ForEach(person.celebrationChecklist, id: \.self) { item in
                    Button {
                        guard store.isPro else { return }
                        if person.completedCelebrationSteps.contains(item) { person.completedCelebrationSteps.removeAll { $0 == item } }
                        else { person.completedCelebrationSteps.append(item) }
                        save()
                    } label: { Label(item, systemImage: person.completedCelebrationSteps.contains(item) ? "checkmark.circle.fill" : "circle") }.disabled(!store.isPro)
                }
                if store.isPro {
                    HStack {
                        TextField("One concrete next step", text: $step)
                        Button("Add") {
                            let title = step.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !title.isEmpty, !person.celebrationChecklist.contains(title) else { return }
                            person.celebrationChecklist.append(title); step = ""; save()
                        }.disabled(step.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if !person.celebrationChecklist.isEmpty {
                        Button("Start a fresh checklist", role: .destructive) { person.celebrationChecklist = []; person.completedCelebrationSteps = []; save() }
                    }
                } else {
                    NavigationLink { ProPlanView() } label: { Label("Unlock personal checklists with Pro", systemImage: "leaf") }
                }
            }
            Section {
                if store.isPro {
                    Picker("Catch-up cadence", selection: $person.connectionCadence) {
                        Text("No cadence").tag(0); Text("Every week").tag(7); Text("Every two weeks").tag(14); Text("Every month").tag(30); Text("Every three months").tag(90)
                    }
                } else { NavigationLink("Set a connection rhythm with Pro") { ProPlanView() } }
                if let last = person.lastConnectionDate { LabeledContent("Last time together", value: last.formatted(date: .abbreviated, time: .omitted)) }
                DatePicker("When", selection: $connectionDate, in: ...Date(), displayedComponents: .date)
                TextField("What do you want to remember?", text: $journal, axis: .vertical).lineLimit(2...5)
                Button("Save a moment together") {
                    let note = journal.trimmingCharacters(in: .whitespacesAndNewlines)
                    person.connectionJournal.insert("\(connectionDate.formatted(date: .abbreviated, time: .omitted)) — \(note.isEmpty ? "Spent time together" : note)", at: 0)
                    person.lastConnectionDate = max(person.lastConnectionDate ?? .distantPast, connectionDate)
                    journal = ""; save()
                }
            } header: { Text("Beyond the birthday") } footer: { Text("Pro cadence appears on Today when a catch-up is due. Birthday notifications are managed separately in Settings.") }
            if !person.connectionJournal.isEmpty {
                Section("Moments to keep") { ForEach(Array(person.connectionJournal.enumerated()), id: \.offset) { _, entry in Text(entry) } }.id("journal")
            }
            if let error { Section { Text(error).foregroundStyle(.red) } }
        }.scrollContentBackground(.hidden).screenBackground(.detail).navigationTitle("A thoughtful plan").navigationBarTitleDisplayMode(.inline)
            .onDisappear { save() }
            .onAppear { if startsAtJournal { proxy.scrollTo("journal", anchor: .bottom) } }
        }
    }
    private func save() {
        person.celebrationBudget = person.celebrationBudget.isFinite ? max(0, person.celebrationBudget) : 0
        do { try context.save(); error = nil } catch { self.error = "Could not save your changes. Please try again." }
    }
}
