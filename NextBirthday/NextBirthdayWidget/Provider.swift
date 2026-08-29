import WidgetKit
import SwiftUI

/// One timeline entry: the snapshot plus the moment it represents.
struct BirthdayEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot

    var entries: [SnapshotEntry] {
        snapshot.entries.sorted { $0.daysUntil < $1.daysUntil }
    }

    var next: SnapshotEntry? { entries.first }
}

/// Reads the shared snapshot the app writes, and refreshes at the next midnight
/// so countdowns roll over on time.
struct BirthdayProvider: TimelineProvider {

    func placeholder(in context: Context) -> BirthdayEntry {
        BirthdayEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (BirthdayEntry) -> Void) {
        let stored = SnapshotStore.read()
        let snapshot = (context.isPreview || stored.entries.isEmpty) ? WidgetSnapshot.placeholder : stored
        completion(BirthdayEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BirthdayEntry>) -> Void) {
        let snapshot = SnapshotStore.read()
        let now = Date()
        let entry = BirthdayEntry(date: now, snapshot: snapshot)

        let calendar = BirthdayMath.calendar
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(3600)

        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}
