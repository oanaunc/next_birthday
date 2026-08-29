import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// Add a new person, or edit an existing one. Pass `nil` to add.
struct AddEditPersonView: View {

    let person: Person?

    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var month = BirthdayMath.calendar.component(.month, from: Date())
    @State private var day = BirthdayMath.calendar.component(.day, from: Date())
    @State private var includeYear = true
    @State private var year = 1995
    @State private var relationshipRaw: String = ""
    @State private var customRelationship = ""
    @State private var isFavorite = false
    @State private var notes = ""
    @State private var usesCustomReminders = false
    @State private var customReminderDays: Set<Int> = []
    @State private var photoData: Data?
    @State private var photoItem: PhotosPickerItem?

    private var isEditing: Bool { person != nil }

    private var currentYear: Int {
        BirthdayMath.calendar.component(.year, from: Date())
    }

    private var daysInMonth: Int {
        var components = DateComponents()
        components.year = includeYear ? year : 2000  // leap year keeps Feb 29 selectable
        components.month = month
        components.day = 1
        guard let date = BirthdayMath.calendar.date(from: components),
              let range = BirthdayMath.calendar.range(of: .day, in: .month, for: date)
        else { return 31 }
        return range.count
    }

    private var canSave: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty ||
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                nameSection
                birthdaySection
                relationshipSection
                reminderSection
                notesSection
            }
            .scrollContentBackground(.hidden)
            .screenBackground(.add, intensity: 0.25)
            .navigationTitle(isEditing ? "Edit Birthday" : "Add Birthday")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: load)
            .onChange(of: photoItem) { _, item in
                Task { await loadPhoto(item) }
            }
            .onChange(of: month) { _, _ in clampDay() }
            .onChange(of: year) { _, _ in clampDay() }
            .onChange(of: includeYear) { _, _ in clampDay() }
        }
    }

    // MARK: Sections

    private var photoSection: some View {
        Section {
            HStack {
                Spacer()
                PhotosPicker(selection: $photoItem, matching: .images) {
                    ZStack {
                        if let photoData, let image = UIImage(data: photoData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 96, height: 96)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Theme.lavender.opacity(0.28))
                                .frame(width: 96, height: 96)
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundStyle(Theme.purple)
                        }
                    }
                    .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 2))
                }
                Spacer()
            }
            .listRowBackground(Color.clear)
            if photoData != nil {
                Button("Remove Photo", role: .destructive) {
                    photoData = nil
                    photoItem = nil
                }
                .font(.footnote)
            }
        }
    }

    private var nameSection: some View {
        Section("Person") {
            TextField("First name", text: $firstName)
                .textContentType(.givenName)
            TextField("Last name", text: $lastName)
                .textContentType(.familyName)
            Toggle(isOn: $isFavorite) {
                Label("Favorite", systemImage: "star.fill")
            }
            .tint(Theme.butter)
        }
    }

    private var birthdaySection: some View {
        Section {
            Picker("Month", selection: $month) {
                ForEach(1...12, id: \.self) { value in
                    Text(BirthdayMath.monthName(value)).tag(value)
                }
            }
            Picker("Day", selection: $day) {
                ForEach(1...daysInMonth, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            Toggle("Include year", isOn: $includeYear)
                .tint(Theme.mint)
            if includeYear {
                Picker("Year", selection: $year) {
                    ForEach(Array((1900...currentYear).reversed()), id: \.self) { value in
                        Text(String(value)).tag(value)
                    }
                }
            }
        } header: {
            Text("Birthday")
        } footer: {
            Text(includeYear
                 ? "Shown as \(BirthdayMath.fullDateLabel(month: month, day: day, year: year))."
                 : "Leave the year off if you don't know it — the age simply won't be shown.")
        }
    }

    private var relationshipSection: some View {
        Section("Relationship") {
            Picker("Relationship", selection: $relationshipRaw) {
                Text("None").tag("")
                ForEach(Relationship.allCases) { option in
                    Label(option.rawValue, systemImage: option.symbol).tag(option.rawValue)
                }
                Text("Custom…").tag("__custom__")
            }
            if relationshipRaw == "__custom__" {
                TextField("Group name", text: $customRelationship)
            }
        }
    }

    private var reminderSection: some View {
        Section {
            Toggle("Use custom reminders", isOn: $usesCustomReminders)
                .tint(Theme.purple)

            if usesCustomReminders {
                ForEach(ReminderOffset.allCases) { offset in
                    Button {
                        toggleReminder(offset.rawValue)
                    } label: {
                        HStack {
                            Text(offset.label)
                                .foregroundStyle(.primary)
                            Spacer()
                            if customReminderDays.contains(offset.rawValue) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.purple)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text(usesCustomReminders
                 ? "These override the app defaults for this person."
                 : "Using the app default: \(settings.defaultRemindersSummary) at \(settings.notificationTimeLabel).")
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Loves ceramics and gardening…", text: $notes, axis: .vertical)
                .lineLimit(3...8)
        }
    }

    // MARK: Behaviour

    private func toggleReminder(_ days: Int) {
        if customReminderDays.contains(days) {
            customReminderDays.remove(days)
        } else {
            customReminderDays.insert(days)
        }
    }

    private func clampDay() {
        if day > daysInMonth { day = daysInMonth }
    }

    private func load() {
        guard let person else {
            // Sensible default for a new entry: today's month/day.
            customReminderDays = Set(settings.defaultReminderDays)
            return
        }
        firstName = person.firstName
        lastName = person.lastName
        month = person.birthMonth
        day = person.birthDay
        includeYear = person.birthYear != nil
        year = person.birthYear ?? 1995
        isFavorite = person.isFavorite
        notes = person.notes
        photoData = person.photoData
        usesCustomReminders = person.usesCustomReminders
        customReminderDays = Set(person.usesCustomReminders
                                 ? person.customReminderDays
                                 : settings.defaultReminderDays)
        if let raw = person.relationshipRaw, !raw.isEmpty {
            if Relationship(rawValue: raw) != nil {
                relationshipRaw = raw
            } else {
                relationshipRaw = "__custom__"
                customRelationship = raw
            }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self) {
            photoData = ContactsImporter.downscale(data, maxDimension: 600, quality: 0.85)
        }
    }

    private func resolvedRelationship() -> String? {
        if relationshipRaw == "__custom__" {
            let trimmed = customRelationship.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }
        return relationshipRaw.isEmpty ? nil : relationshipRaw
    }

    private func save() {
        let target: Person
        if let person {
            target = person
        } else {
            target = Person()
            context.insert(target)
        }

        target.firstName = firstName.trimmingCharacters(in: .whitespaces)
        target.lastName = lastName.trimmingCharacters(in: .whitespaces)
        target.birthMonth = month
        target.birthDay = min(day, daysInMonth)
        target.birthYear = includeYear ? year : nil
        target.relationshipRaw = resolvedRelationship()
        target.isFavorite = isFavorite
        target.notes = notes
        target.photoData = photoData
        target.usesCustomReminders = usesCustomReminders
        target.customReminderDays = usesCustomReminders
            ? Array(customReminderDays).sorted(by: >)
            : []

        try? context.save()
        dismiss()
    }
}
