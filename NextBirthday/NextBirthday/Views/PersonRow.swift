import SwiftUI

/// One person in a list: avatar, name, date, age and countdown.
struct PersonRow: View {
    let person: Person
    var showsCountdown: Bool = true

    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: person.fullName,
                       initials: person.initials,
                       photoData: person.photoData,
                       size: 46,
                       showsRing: person.isBirthdayToday,
                       ringColor: Theme.rose)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(person.fullName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if person.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.butter)
                    }
                    if person.isAcknowledgedThisYear {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.mint)
                    }
                }

                HStack(spacing: 6) {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    RelationshipTag(raw: person.relationshipRaw)
                }
            }

            Spacer(minLength: 6)

            if showsCountdown && settings.showDaysRemaining {
                Text(person.countdownLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(person.daysUntilBirthday <= 1 ? Theme.purple : .secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(person.daysUntilBirthday <= 1
                                       ? Theme.purple.opacity(0.14)
                                       : Color.primary.opacity(0.05))
                    )
            }

            Image(systemName: giftIcon)
                .font(.system(size: 15))
                .foregroundStyle(Relationship.tint(for: person.relationshipRaw).opacity(0.8))
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        var pieces: [String] = [person.shortDateLabel]
        if settings.showAge, let age = person.turningAge {
            pieces.append("Turns \(age)")
        }
        if settings.showZodiac {
            pieces.append("\(person.zodiacSymbol) \(person.zodiacSign)")
        }
        return pieces.joined(separator: " · ")
    }

    private var giftIcon: String {
        person.isBirthdayToday ? "party.popper.fill" : "gift.fill"
    }
}
