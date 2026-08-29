import WidgetKit
import SwiftUI

/// Lock Screen complications: inline, circular and rectangular.
struct LockScreenWidget: Widget {
    let kind = "LockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BirthdayProvider()) { entry in
            LockScreenWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Next Birthday")
        .description("Who's next, on your Lock Screen.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

struct LockScreenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BirthdayEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            inline
        case .accessoryCircular:
            circular
        default:
            rectangular
        }
    }

    private var firstName: String {
        guard let name = entry.next?.name else { return "" }
        return name.components(separatedBy: " ").first ?? name
    }

    private var inline: some View {
        if let person = entry.next {
            return Text("🎂 \(firstName) · \(BirthdayMath.compactCountdown(days: person.daysUntil))")
        } else {
            return Text("🎂 No birthdays")
        }
    }

    private var circular: some View {
        Group {
            if let person = entry.next {
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: -1) {
                        Text("🎂").font(.system(size: 11))
                        Text(person.daysUntil == 0 ? "!" : "\(person.daysUntil)")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                        Text(person.daysUntil == 1 ? "day" : "days")
                            .font(.system(size: 8))
                    }
                }
            } else {
                ZStack {
                    AccessoryWidgetBackground()
                    Text("🎂").font(.system(size: 16))
                }
            }
        }
        .widgetURL(entry.next?.deepLink)
    }

    private var rectangular: some View {
        Group {
            if let person = entry.next {
                VStack(alignment: .leading, spacing: 1) {
                    Text("NEXT BIRTHDAY")
                        .font(.system(size: 9, weight: .bold))
                        .widgetAccentable()
                    Text(person.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text("\(person.countdown) · \(person.shortDate)")
                        .font(.system(size: 11))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text("NEXT BIRTHDAY").font(.system(size: 9, weight: .bold))
                    Text("Nothing scheduled").font(.system(size: 13))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .widgetURL(entry.next?.deepLink)
    }
}
