import WidgetKit
import SwiftUI

/// "Up Next" — small, medium and large.
struct UpNextWidget: Widget {
    let kind = "UpNextWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BirthdayProvider()) { entry in
            UpNextWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetTheme.background }
        }
        .configurationDisplayName("Up Next")
        .description("The birthdays coming up next.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct UpNextWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BirthdayEntry

    var body: some View {
        Group {
            if entry.entries.isEmpty {
                WidgetEmptyState(compact: family == .systemSmall)
            } else {
                switch family {
                case .systemSmall:  small
                case .systemLarge:  large
                default:            medium
                }
            }
        }
    }

    // MARK: Small

    private var small: some View {
        let person = entry.next
        return VStack(alignment: .leading, spacing: 6) {
            Text("NEXT BIRTHDAY")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(WidgetTheme.secondary)

            if let person {
                WidgetAvatar(entry: person, size: 38)
                Text(person.name.components(separatedBy: " ").first ?? person.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(WidgetTheme.ink)
                    .lineLimit(1)
                Text(person.countdown)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetTheme.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let age = person.turningAge {
                    Text("Turns \(age) · \(person.shortDate)")
                        .font(.system(size: 10))
                        .foregroundStyle(WidgetTheme.secondary)
                        .lineLimit(1)
                } else {
                    Text(person.shortDate)
                        .font(.system(size: 10))
                        .foregroundStyle(WidgetTheme.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(entry.next?.deepLink)
    }

    // MARK: Medium

    private var medium: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("COMING UP")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(WidgetTheme.secondary)
                Spacer()
                Text("🎂").font(.system(size: 11))
            }
            ForEach(Array(entry.entries.prefix(3))) { person in
                Link(destination: person.deepLink) {
                    WidgetPersonRow(entry: person)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Large

    private var large: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("UPCOMING BIRTHDAYS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(WidgetTheme.secondary)
                Spacer()
                Text("🎂").font(.system(size: 12))
            }

            if let next = entry.next {
                Link(destination: next.deepLink) {
                    HStack(spacing: 11) {
                        WidgetAvatar(entry: next, size: 46)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(next.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(WidgetTheme.ink)
                                .lineLimit(1)
                            Text(next.countdown)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(WidgetTheme.accent)
                            if let age = next.turningAge {
                                Text("Turns \(age)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(WidgetTheme.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(WidgetTheme.accentSoft.opacity(0.18))
                    )
                }
            }

            ForEach(Array(entry.entries.dropFirst().prefix(6))) { person in
                Link(destination: person.deepLink) {
                    WidgetPersonRow(entry: person, avatarSize: 28)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
