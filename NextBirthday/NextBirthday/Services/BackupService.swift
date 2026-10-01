import Foundation
import SwiftData
import UniformTypeIdentifiers
import SwiftUI

/// Plain-JSON export and import, so nobody's birthdays are trapped in the app.
enum BackupService {

    struct BackupPerson: Codable {
        var firstName: String
        var lastName: String
        var month: Int
        var day: Int
        var year: Int?
        var relationship: String?
        var isFavorite: Bool
        var notes: String
        var usesCustomReminders: Bool
        var customReminderDays: [Int]
        var giftIdeas: [String]
        var giftedIdeas: [String]
        var giftHistory: [BackupGift]
        var celebrationIntent: String?
        var celebrationBudget: Double?
        var celebrationChecklist: [String]?
        var completedCelebrationSteps: [String]?
        var connectionCadence: Int?
        var lastConnectionDate: Date?
        var connectionJournal: [String]?
    }

    struct BackupGift: Codable {
        var year: Int
        var item: String
    }

    struct Backup: Codable {
        var app = "Next Birthday"
        var version = 2
        var exportedAt = Date()
        var people: [BackupPerson]
    }

    // MARK: Export

    @MainActor
    static func makeBackup(from people: [Person]) -> Backup {
        Backup(people: people.map { person in
            BackupPerson(
                firstName: person.firstName,
                lastName: person.lastName,
                month: person.birthMonth,
                day: person.birthDay,
                year: person.birthYear,
                relationship: person.relationshipRaw,
                isFavorite: person.isFavorite,
                notes: person.notes,
                usesCustomReminders: person.usesCustomReminders,
                customReminderDays: person.customReminderDays,
                giftIdeas: person.sortedGiftIdeas.filter { !$0.isPurchased }.map(\.title),
                giftedIdeas: person.sortedGiftIdeas.filter(\.isPurchased).map(\.title),
                giftHistory: person.sortedGiftHistory.map { BackupGift(year: $0.year, item: $0.item) },
                celebrationIntent: person.celebrationIntent,
                celebrationBudget: person.celebrationBudget,
                celebrationChecklist: person.celebrationChecklist,
                completedCelebrationSteps: person.completedCelebrationSteps,
                connectionCadence: person.connectionCadence,
                lastConnectionDate: person.lastConnectionDate,
                connectionJournal: person.connectionJournal
            )
        })
    }

    @MainActor
    static func exportJSON(from people: [Person]) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(makeBackup(from: people))
    }

    /// Writes the backup to a temporary file and returns its URL, ready for ShareLink.
    @MainActor
    static func writeTemporaryFile(from people: [Person]) -> URL? {
        guard let data = exportJSON(from: people) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let name = "NextBirthday-\(formatter.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    // MARK: Import

    enum ImportResult {
        case success(added: Int, skipped: Int)
        case failure(String)
    }

    /// Imports a backup, skipping anyone who is already stored with the same
    /// name and date.
    @MainActor
    static func importJSON(_ data: Data, into context: ModelContext, existing: [Person]) -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(Backup.self, from: data) else {
            return .failure("That file isn't a Next Birthday backup.")
        }

        var existingKeys = Set(existing.map { "\($0.fullName.lowercased())|\($0.birthMonth)-\($0.birthDay)" })
        var added = 0
        var skipped = 0

        for entry in backup.people {
            let name = [entry.firstName, entry.lastName]
                .filter { !$0.isEmpty }.joined(separator: " ").lowercased()
            let key = "\(name)|\(entry.month)-\(entry.day)"
            if existingKeys.contains(key) {
                skipped += 1
                continue
            }

            let person = Person(firstName: entry.firstName,
                                lastName: entry.lastName,
                                birthMonth: entry.month,
                                birthDay: entry.day,
                                birthYear: entry.year,
                                relationshipRaw: entry.relationship,
                                isFavorite: entry.isFavorite,
                                notes: entry.notes)
            person.usesCustomReminders = entry.usesCustomReminders
            person.customReminderDays = entry.customReminderDays
            person.celebrationIntent = entry.celebrationIntent ?? ""
            person.celebrationBudget = max(0, entry.celebrationBudget ?? 0)
            person.celebrationChecklist = entry.celebrationChecklist ?? []
            person.completedCelebrationSteps = entry.completedCelebrationSteps ?? []
            person.connectionCadence = entry.connectionCadence ?? 0
            person.lastConnectionDate = entry.lastConnectionDate
            person.connectionJournal = entry.connectionJournal ?? []
            context.insert(person)

            for title in entry.giftIdeas {
                context.insert(GiftIdea(title: title, person: person))
            }
            for title in entry.giftedIdeas {
                context.insert(GiftIdea(title: title, isPurchased: true, person: person))
            }
            for gift in entry.giftHistory {
                context.insert(GiftRecord(year: gift.year, item: gift.item, person: person))
            }

            existingKeys.insert(key)
            added += 1
        }

        do { try context.save() } catch { context.rollback(); return .failure("Could not save the imported backup. Please try again.") }
        return .success(added: added, skipped: skipped)
    }
}
