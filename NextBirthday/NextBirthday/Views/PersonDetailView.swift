import SwiftUI
import SwiftData

struct PersonDetailView: View {
    @Bindable var person: Person

    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showingEdit = false
    @State private var showingQuickActions = false
    @State private var showingDeleteConfirm = false
    @State private var channels = ContactActions.ContactChannels()
    @State private var newGiftIdea = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                NavigationLink { CelebrationPlanView(person: person) } label: {
                    Label("Plan something meaningful", systemImage: "leaf")
                        .font(.headline).frame(maxWidth: .infinity).padding()
                }.buttonStyle(.borderedProminent)
                countdownCard
                birthdayFacts
                remindersCard
                notesCard
                giftIdeasCard
                giftHistoryCard
                contactCard
                deleteButton
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .screenBackground(.detail)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showingEdit = true } label: { Label("Edit", systemImage: "pencil") }
                    Button { person.isFavorite.toggle() } label: {
                        Label(person.isFavorite ? "Remove Favorite" : "Add to Favorites",
                              systemImage: person.isFavorite ? "star.slash" : "star")
                    }
                    ShareLink(item: "\(person.fullName)'s birthday — \(person.fullDateLabel)") {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Divider()
                    Button(role: .destructive) { showingDeleteConfirm = true } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEdit) { AddEditPersonView(person: person) }
        .sheet(isPresented: $showingQuickActions) {
            QuickActionsSheet(person: person).presentationDetents([.medium])
        }
        .confirmationDialog("Delete \(person.fullName)?",
                            isPresented: $showingDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                // Dismiss first: deleting a @Bindable model while this view is
                // still on screen makes SwiftUI re-read a deleted object.
                dismiss()
                let context = context
                let person = person
                DispatchQueue.main.async {
                    context.delete(person)
                }
            }
        } message: {
            Text("This removes their birthday, notes and gift ideas from this iPhone.")
        }
        .onAppear { channels = ContactActions.channels(for: person.contactIdentifier) }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 10) {
            AvatarView(name: person.fullName,
                       initials: person.initials,
                       photoData: person.photoData,
                       size: 120,
                       showsRing: true,
                       ringColor: person.isBirthdayToday ? Theme.rose : .white)

            HStack(spacing: 6) {
                Text(person.fullName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.deepInk)
                if person.isFavorite {
                    Image(systemName: "heart.fill").foregroundStyle(Theme.rose)
                }
            }

            Text(person.fullDateLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            RelationshipTag(raw: person.relationshipRaw)

            HStack(spacing: 12) {
                if let phone = channels.phoneNumbers.first {
                    ActionButton(icon: "message.fill", title: "Message", tint: Theme.blue) {
                        ContactActions.open(ContactActions.messageURL(
                            phone: phone, body: NotificationScheduler.birthdayMessage(for: person)))
                    }
                    ActionButton(icon: "phone.fill", title: "Call", tint: Theme.mint) {
                        ContactActions.open(ContactActions.callURL(phone: phone))
                    }
                }
                ActionButton(icon: "bolt.fill", title: "Quick", tint: Theme.purple) {
                    showingQuickActions = true
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 4)
        }
        .padding(.top, 4)
    }

    // MARK: Cards

    private var countdownCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(person.countdownLabel)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.purple)
                    Spacer()
                    if settings.showAge, let age = person.turningAge {
                        Text("Turns \(age)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                CountdownStrip(target: person.nextBirthday)
            }
        }
    }

    private var birthdayFacts: some View {
        GlassCard {
            VStack(spacing: 0) {
                DetailRow(label: "Date", value: person.fullDateLabel)
                if settings.showAge {
                    Divider()
                    if let current = person.currentAge {
                        DetailRow(label: "Age", value: "\(current) years old")
                    } else if person.birthYear == nil {
                        DetailRow(label: "Age", value: "Year not set")
                    }
                }
                if settings.showZodiac {
                    Divider()
                    DetailRow(label: "Zodiac",
                              value: "\(person.zodiacSymbol)  \(person.zodiacSign)")
                }
                Divider()
                DetailRow(label: "Next birthday",
                          value: person.nextBirthday.formatted(date: .abbreviated, time: .omitted))
            }
        }
    }

    private var remindersCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Reminders", systemImage: "bell.fill")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if person.usesCustomReminders {
                        Text("Custom")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.purple)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(Theme.purple.opacity(0.15)))
                    }
                }

                let days = person.effectiveReminderDays(defaults: settings.defaultReminderDays)
                if days.isEmpty {
                    Text("No reminders set.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    ForEach(days, id: \.self) { day in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.mint)
                                .font(.caption)
                            Text(ReminderOffset.label(forDays: day))
                                .font(.footnote)
                            Spacer()
                            Text(settings.notificationTimeLabel)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button {
                    showingEdit = true
                } label: {
                    Text(person.usesCustomReminders ? "Change reminders" : "Set custom reminders")
                        .font(.footnote.weight(.semibold))
                }
                .padding(.top, 2)
            }
        }
    }

    private var notesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("Notes", systemImage: "note.text")
                    .font(.subheadline.weight(.semibold))
                TextField("Favourite flowers, shirt size, things they mentioned wanting…",
                          text: $person.notes, axis: .vertical)
                    .font(.footnote)
                    .lineLimit(3...8)
                    .textFieldStyle(.plain)
            }
        }
    }

    private var giftIdeasCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Gift Ideas", systemImage: "gift.fill")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    NavigationLink {
                        GiftIdeasView(person: person)
                    } label: {
                        Text("All").font(.footnote.weight(.semibold))
                    }
                }

                let ideas = person.sortedGiftIdeas.prefix(4)
                if ideas.isEmpty {
                    Text("Nothing yet. Jot down ideas whenever they come up.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    ForEach(Array(ideas)) { idea in
                        GiftIdeaRow(idea: idea) { markGifted(idea) }
                    }
                }

                HStack(spacing: 8) {
                    TextField("Add an idea", text: $newGiftIdea)
                        .font(.footnote)
                        .textFieldStyle(.plain)
                        .onSubmit(addGiftIdea)
                    Button(action: addGiftIdea) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Theme.purple)
                    }
                    .disabled(newGiftIdea.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
            }
        }
    }

    @ViewBuilder
    private var giftHistoryCard: some View {
        let history = person.sortedGiftHistory
        if !history.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Gift History", systemImage: "clock.arrow.circlepath")
                        .font(.subheadline.weight(.semibold))
                    ForEach(history) { record in
                        HStack {
                            Text(String(record.year))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.purple)
                                .frame(width: 44, alignment: .leading)
                            Text(record.item).font(.footnote)
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var contactCard: some View {
        if channels.hasAny {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Contact", systemImage: "person.crop.circle")
                        .font(.subheadline.weight(.semibold))
                    ForEach(channels.phoneNumbers, id: \.self) { number in
                        Button {
                            ContactActions.open(ContactActions.callURL(phone: number))
                        } label: {
                            HStack {
                                Image(systemName: "phone.fill").font(.caption)
                                Text(number).font(.footnote)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(channels.emails, id: \.self) { email in
                        Button {
                            ContactActions.open(ContactActions.mailURL(email: email,
                                                                       subject: "Happy birthday!"))
                        } label: {
                            HStack {
                                Image(systemName: "envelope.fill").font(.caption)
                                Text(email).font(.footnote)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showingDeleteConfirm = true
        } label: {
            Label("Delete Person", systemImage: "trash")
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .padding(.top, 4)
    }

    // MARK: Actions

    private func addGiftIdea() {
        let title = newGiftIdea.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let idea = GiftIdea(title: title, person: person)
        context.insert(idea)
        newGiftIdea = ""
    }

    /// Same behaviour as GiftIdeasView: toggling on files the gift in this
    /// year's history, toggling off removes that entry again.
    private func markGifted(_ idea: GiftIdea) {
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

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).font(.footnote).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.footnote.weight(.medium))
        }
        .padding(.vertical, 8)
    }
}

struct GiftIdeaRow: View {
    @Bindable var idea: GiftIdea
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(systemName: idea.isPurchased ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(idea.isPurchased ? Theme.mint : .secondary)
                Text(idea.title)
                    .font(.footnote)
                    .strikethrough(idea.isPurchased, color: .secondary)
                    .foregroundStyle(idea.isPurchased ? .secondary : .primary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}
