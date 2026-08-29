import WidgetKit
import SwiftUI

/// A single big countdown for the very next birthday.
struct CountdownWidget: Widget {
    let kind = "CountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BirthdayProvider()) { entry in
            CountdownWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetTheme.countdownBackground
                }
        }
        .configurationDisplayName("Countdown")
        .description("A big countdown to the next birthday.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CountdownWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BirthdayEntry

    var body: some View {
        if let person = entry.next {
            content(for: person)
                .widgetURL(person.deepLink)
        } else {
            WidgetEmptyState(compact: family == .systemSmall)
        }
    }

    private func content(for person: SnapshotEntry) -> some View {
        VStack(spacing: 5) {
            Text(person.name.uppercased())
                .font(.system(size: family == .systemSmall ? 10 : 12, weight: .bold))
                .foregroundStyle(WidgetTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(person.daysUntil == 0 ? "TODAY" : "\(person.daysUntil)")
                .font(.system(size: family == .systemSmall ? 46 : 58,
                              weight: .bold, design: .rounded))
                .foregroundStyle(WidgetTheme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(person.daysUntil == 0 ? "🎉 Happy birthday"
                 : (person.daysUntil == 1 ? "DAY LEFT" : "DAYS LEFT"))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(WidgetTheme.secondary)

            Text(person.shortDate)
                .font(.system(size: 10))
                .foregroundStyle(WidgetTheme.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
