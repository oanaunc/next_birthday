import Foundation
import UIKit
import WidgetKit

/// Keeps the widget's shared snapshot in step with the app's data.
enum WidgetSync {

    /// How many upcoming people the widgets can show at most.
    static let maxEntries = 12

    @MainActor
    static func refresh(with people: [Person]) {
        let upcoming = people
            .sorted { $0.daysUntilBirthday < $1.daysUntilBirthday }
            .prefix(maxEntries)

        let entries = upcoming.map { person in
            SnapshotEntry(
                id: person.uuid,
                name: person.fullName,
                initials: person.initials,
                month: person.birthMonth,
                day: person.birthDay,
                birthYear: person.birthYear,
                relationship: person.relationshipRaw,
                isFavorite: person.isFavorite,
                photo: widgetPhoto(from: person.photoData)
            )
        }

        SnapshotStore.write(WidgetSnapshot(generatedAt: Date(), entries: Array(entries)))
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Widgets get a tiny copy of the photo so the shared payload stays small.
    private static func widgetPhoto(from data: Data?) -> Data? {
        ContactsImporter.downscale(data, maxDimension: 120, quality: 0.7)
    }
}
