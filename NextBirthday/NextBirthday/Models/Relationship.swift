import Foundation
import SwiftUI

/// Built-in relationship labels. Users can also type a custom one, which is
/// stored verbatim in `Person.relationshipRaw`.
enum Relationship: String, CaseIterable, Identifiable, Hashable {
    case family = "Family"
    case friend = "Friend"
    case partner = "Partner"
    case work = "Work"
    case school = "School"
    case other = "Other"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .family: return "house.fill"
        case .friend: return "person.2.fill"
        case .partner: return "heart.fill"
        case .work: return "briefcase.fill"
        case .school: return "graduationcap.fill"
        case .other: return "person.fill"
        }
    }

    var tint: Color {
        switch self {
        case .family: return Theme.pink
        case .friend: return Theme.purple
        case .partner: return Theme.rose
        case .work: return Theme.blue
        case .school: return Theme.mint
        case .other: return Theme.peach
        }
    }

    /// Default reminder offsets (days before) suggested for this relationship.
    var suggestedReminderDays: [Int] {
        switch self {
        case .family, .partner: return [14, 3, 0]
        case .friend: return [7, 1, 0]
        case .work: return [1, 0]
        case .school: return [3, 0]
        case .other: return [1, 0]
        }
    }

    static func tint(for raw: String?) -> Color {
        guard let raw, let known = Relationship(rawValue: raw) else { return Theme.lavender }
        return known.tint
    }

    static func symbol(for raw: String?) -> String {
        guard let raw, let known = Relationship(rawValue: raw) else { return "person.fill" }
        return known.symbol
    }
}

/// A reminder offset expressed in days before the birthday.
enum ReminderOffset: Int, CaseIterable, Identifiable, Hashable {
    case onTheDay = 0
    case oneDay = 1
    case threeDays = 3
    case oneWeek = 7
    case twoWeeks = 14
    case oneMonth = 30

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .onTheDay: return "On the birthday"
        case .oneDay: return "1 day before"
        case .threeDays: return "3 days before"
        case .oneWeek: return "1 week before"
        case .twoWeeks: return "2 weeks before"
        case .oneMonth: return "1 month before"
        }
    }

    var shortLabel: String {
        switch self {
        case .onTheDay: return "Day of"
        case .oneDay: return "1 day"
        case .threeDays: return "3 days"
        case .oneWeek: return "1 week"
        case .twoWeeks: return "2 weeks"
        case .oneMonth: return "1 month"
        }
    }

    /// What the notification is nudging the user to do.
    var intent: ReminderIntent {
        switch self {
        case .onTheDay: return .wishThemToday
        case .oneDay: return .sendMessageSoon
        case .threeDays: return .buyGift
        case .oneWeek, .twoWeeks, .oneMonth: return .thinkAboutGift
        }
    }

    static func label(forDays days: Int) -> String {
        if let known = ReminderOffset(rawValue: days) { return known.label }
        return days == 1 ? "1 day before" : "\(days) days before"
    }

    static func shortLabel(forDays days: Int) -> String {
        if let known = ReminderOffset(rawValue: days) { return known.shortLabel }
        return "\(days) days"
    }
}

/// Drives the wording of each local notification.
enum ReminderIntent {
    case thinkAboutGift
    case buyGift
    case sendMessageSoon
    case wishThemToday
}
