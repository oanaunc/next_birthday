import Foundation
import SwiftData

@Model
final class Person {
    /// Stable identifier used for notification IDs and widget deep links.
    var uuid: String = UUID().uuidString

    var firstName: String = ""
    var lastName: String = ""

    var birthMonth: Int = 1
    var birthDay: Int = 1
    /// Nil when the user only knows the day and month.
    var birthYear: Int?

    /// Free-form relationship label. Matches `Relationship.rawValue` for built-ins.
    var relationshipRaw: String?

    var isFavorite: Bool = false
    var notes: String = ""

    @Attribute(.externalStorage) var photoData: Data?

    /// Set when the person was imported from, or linked to, an iOS contact.
    var contactIdentifier: String?

    /// When true, `customReminderDays` overrides the global defaults.
    var usesCustomReminders: Bool = false
    var customReminderDays: [Int] = []

    /// The calendar year the user last tapped "Done" on this birthday.
    var acknowledgedYear: Int?

    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \GiftIdea.person)
    var giftIdeas: [GiftIdea]? = []

    @Relationship(deleteRule: .cascade, inverse: \GiftRecord.person)
    var giftHistory: [GiftRecord]? = []

    init(firstName: String = "",
         lastName: String = "",
         birthMonth: Int = 1,
         birthDay: Int = 1,
         birthYear: Int? = nil,
         relationshipRaw: String? = nil,
         isFavorite: Bool = false,
         notes: String = "",
         photoData: Data? = nil,
         contactIdentifier: String? = nil) {
        self.uuid = UUID().uuidString
        self.firstName = firstName
        self.lastName = lastName
        self.birthMonth = birthMonth
        self.birthDay = birthDay
        self.birthYear = birthYear
        self.relationshipRaw = relationshipRaw
        self.isFavorite = isFavorite
        self.notes = notes
        self.photoData = photoData
        self.contactIdentifier = contactIdentifier
        self.usesCustomReminders = false
        self.customReminderDays = []
        self.createdAt = Date()
        self.giftIdeas = []
        self.giftHistory = []
    }
}

// MARK: - Derived values

extension Person {

    var fullName: String {
        let name = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? "Unnamed" : name
    }

    var displayFirstName: String {
        let trimmed = firstName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? fullName : trimmed
    }

    var initials: String {
        let first = firstName.trimmingCharacters(in: .whitespaces).first
        let last = lastName.trimmingCharacters(in: .whitespaces).first
        let letters = [first, last].compactMap { $0 }
        if letters.isEmpty { return "?" }
        return String(letters).uppercased()
    }

    var nextBirthday: Date {
        BirthdayMath.nextOccurrence(month: birthMonth, day: birthDay)
    }

    var daysUntilBirthday: Int {
        BirthdayMath.daysUntil(month: birthMonth, day: birthDay)
    }

    var isBirthdayToday: Bool { daysUntilBirthday == 0 }

    var turningAge: Int? {
        BirthdayMath.turningAge(birthYear: birthYear, month: birthMonth, day: birthDay)
    }

    var currentAge: Int? {
        BirthdayMath.currentAge(birthYear: birthYear, month: birthMonth, day: birthDay)
    }

    var countdownLabel: String {
        BirthdayMath.countdownLabel(days: daysUntilBirthday)
    }

    var shortDateLabel: String {
        BirthdayMath.shortDateLabel(month: birthMonth, day: birthDay)
    }

    var fullDateLabel: String {
        BirthdayMath.fullDateLabel(month: birthMonth, day: birthDay, year: birthYear)
    }

    var zodiacSign: String {
        BirthdayMath.zodiacSign(month: birthMonth, day: birthDay)
    }

    var zodiacSymbol: String {
        BirthdayMath.zodiacSymbol(month: birthMonth, day: birthDay)
    }

    var relationship: Relationship? {
        guard let relationshipRaw else { return nil }
        return Relationship(rawValue: relationshipRaw)
    }

    /// True once the user has tapped "Done" for the current birthday cycle.
    var isAcknowledgedThisYear: Bool {
        guard let acknowledgedYear else { return false }
        let year = BirthdayMath.calendar.component(.year, from: nextBirthday)
        return acknowledgedYear == year
    }

    var sortedGiftIdeas: [GiftIdea] {
        (giftIdeas ?? []).sorted { lhs, rhs in
            if lhs.isPurchased != rhs.isPurchased { return !lhs.isPurchased }
            return lhs.createdAt < rhs.createdAt
        }
    }

    var sortedGiftHistory: [GiftRecord] {
        (giftHistory ?? []).sorted { $0.year > $1.year }
    }

    /// Reminder offsets in effect for this person, given the app defaults.
    func effectiveReminderDays(defaults: [Int]) -> [Int] {
        let days = usesCustomReminders ? customReminderDays : defaults
        return Array(Set(days)).sorted(by: >)
    }

    func matches(searchText: String) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return true }
        if fullName.lowercased().contains(query) { return true }
        if notes.lowercased().contains(query) { return true }
        if let relationshipRaw, relationshipRaw.lowercased().contains(query) { return true }
        if BirthdayMath.monthName(birthMonth).lowercased().hasPrefix(query) { return true }
        if BirthdayMath.monthName(birthMonth, short: true).lowercased().hasPrefix(query) { return true }
        if zodiacSign.lowercased().contains(query) { return true }
        return false
    }
}

// MARK: - Gifts

@Model
final class GiftIdea {
    var uuid: String = UUID().uuidString
    var title: String = ""
    var isPurchased: Bool = false
    var createdAt: Date = Date()
    var person: Person?

    init(title: String, isPurchased: Bool = false, person: Person? = nil) {
        self.uuid = UUID().uuidString
        self.title = title
        self.isPurchased = isPurchased
        self.createdAt = Date()
        self.person = person
    }
}

@Model
final class GiftRecord {
    var uuid: String = UUID().uuidString
    var year: Int = 0
    var item: String = ""
    var person: Person?

    init(year: Int, item: String, person: Person? = nil) {
        self.uuid = UUID().uuidString
        self.year = year
        self.item = item
        self.person = person
    }
}
