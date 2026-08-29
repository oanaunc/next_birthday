import Foundation

/// A single upcoming birthday, flattened for the widget.
struct SnapshotEntry: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var initials: String
    var month: Int
    var day: Int
    var birthYear: Int?
    var relationship: String?
    var isFavorite: Bool
    /// JPEG data, already downscaled small enough for a widget payload.
    var photo: Data?

    var daysUntil: Int {
        BirthdayMath.daysUntil(month: month, day: day)
    }

    var turningAge: Int? {
        BirthdayMath.turningAge(birthYear: birthYear, month: month, day: day)
    }

    var shortDate: String {
        BirthdayMath.shortDateLabel(month: month, day: day)
    }

    var countdown: String {
        BirthdayMath.countdownLabel(days: daysUntil)
    }
}

/// Everything the widget needs, written by the app into the App Group container.
struct WidgetSnapshot: Codable {
    var generatedAt: Date
    var entries: [SnapshotEntry]

    static let empty = WidgetSnapshot(generatedAt: .distantPast, entries: [])

    /// Placeholder content so widgets look right in the gallery and previews.
    static var placeholder: WidgetSnapshot {
        let cal = BirthdayMath.calendar
        func offset(_ days: Int) -> (Int, Int) {
            let date = cal.date(byAdding: .day, value: days, to: Date()) ?? Date()
            return (cal.component(.month, from: date), cal.component(.day, from: date))
        }
        let a = offset(1), b = offset(4), c = offset(8), d = offset(15)
        return WidgetSnapshot(generatedAt: Date(), entries: [
            SnapshotEntry(id: "1", name: "Emma Johnson", initials: "EJ", month: a.0, day: a.1,
                          birthYear: 1995, relationship: "Friend", isFavorite: true, photo: nil),
            SnapshotEntry(id: "2", name: "James Smith", initials: "JS", month: b.0, day: b.1,
                          birthYear: 1991, relationship: "Work", isFavorite: false, photo: nil),
            SnapshotEntry(id: "3", name: "Olivia Davis", initials: "OD", month: c.0, day: c.1,
                          birthYear: 1998, relationship: "Family", isFavorite: false, photo: nil),
            SnapshotEntry(id: "4", name: "Noah Brown", initials: "NB", month: d.0, day: d.1,
                          birthYear: nil, relationship: "Friend", isFavorite: false, photo: nil)
        ])
    }
}

/// Reads and writes the snapshot file in the shared App Group container.
enum SnapshotStore {

    static func write(_ snapshot: WidgetSnapshot) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try data.write(to: SharedConstants.snapshotURL, options: .atomic)
        } catch {
            #if DEBUG
            print("SnapshotStore write failed: \(error)")
            #endif
        }
    }

    static func read() -> WidgetSnapshot {
        do {
            let data = try Data(contentsOf: SharedConstants.snapshotURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(WidgetSnapshot.self, from: data)
        } catch {
            return .empty
        }
    }
}
