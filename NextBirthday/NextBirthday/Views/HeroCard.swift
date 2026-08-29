import SwiftUI

/// The big "Next Birthday" card at the top of the Upcoming screen,
/// with a live day/hour/minute/second countdown.
struct HeroCard: View {
    let person: Person
    var onMessage: () -> Void

    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("NEXT CELEBRATION", systemImage: "sparkles")
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.deepInk.opacity(0.7))
                Spacer()
                Text(person.nextBirthday.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.deepInk.opacity(0.62))
            }

            HStack(alignment: .center, spacing: 14) {
                AvatarView(name: person.fullName,
                           initials: person.initials,
                           photoData: person.photoData,
                           size: 72,
                           showsRing: true,
                           ringColor: .white)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(person.displayFirstName)
                            .font(.headline)
                            .foregroundStyle(Theme.deepInk)
                        if person.isFavorite {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.rose)
                        }
                    }
                    Text(person.countdownLabel)
                        .font(.largeTitle.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(Theme.purple)
                    if settings.showAge, let age = person.turningAge {
                        Text("Turning \(age)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(person.fullDateLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button(action: onMessage) {
                    Image(systemName: person.isBirthdayToday ? "party.popper.fill" : "message.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(Theme.primaryGradient))
                        .shadow(color: Theme.rose.opacity(0.4), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Send a message to \(person.displayFirstName)")
            }

            CountdownStrip(target: person.nextBirthday)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Theme.heroGradient.opacity(0.24))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(
                    LinearGradient(colors: [Color.white.opacity(0.9), Theme.lavender.opacity(0.4)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
        .shadow(color: Theme.purple.opacity(0.16), radius: 24, y: 12)
    }
}

/// DAYS · HRS · MINS · SECS, ticking once a second.
struct CountdownStrip: View {
    let target: Date
    var compact: Bool = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let parts = Self.parts(until: target, now: context.date)
            HStack(spacing: compact ? 8 : 10) {
                unit(parts.days, compact ? "D" : "DAYS")
                unit(parts.hours, compact ? "H" : "HRS")
                unit(parts.minutes, compact ? "M" : "MINS")
                unit(parts.seconds, compact ? "S" : "SECS")
            }
        }
    }

    private func unit(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.system(size: compact ? 15 : 19, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.deepInk)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 6 : 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.62))
                .shadow(color: Theme.deepInk.opacity(0.05), radius: 5, y: 2)
        )
    }

    /// Time remaining until the *start* of the birthday.
    static func parts(until target: Date, now: Date) -> (days: Int, hours: Int, minutes: Int, seconds: Int) {
        let interval = max(0, target.timeIntervalSince(now))
        let total = Int(interval)
        return (total / 86_400,
                (total % 86_400) / 3_600,
                (total % 3_600) / 60,
                total % 60)
    }
}
