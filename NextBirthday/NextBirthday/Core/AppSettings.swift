import Foundation
import SwiftUI
import Observation

/// User preferences, persisted in the shared App Group defaults so the widget
/// can read display options too.
@Observable
final class AppSettings {

    private let defaults: UserDefaults

    init(defaults: UserDefaults? = SharedConstants.sharedDefaults) {
        self.defaults = defaults ?? .standard

        self.hasCompletedOnboarding = self.defaults.bool(forKey: Keys.onboarding)
        self.defaultReminderDays = AppSettings.decodeDays(
            self.defaults.string(forKey: Keys.reminderDays)) ?? [7, 1, 0]
        self.notificationHour = self.defaults.object(forKey: Keys.hour) as? Int ?? 9
        self.notificationMinute = self.defaults.object(forKey: Keys.minute) as? Int ?? 0
        self.accentIndex = self.defaults.object(forKey: Keys.accent) as? Int ?? 0
        self.showAge = self.defaults.object(forKey: Keys.showAge) as? Bool ?? true
        self.showZodiac = self.defaults.object(forKey: Keys.showZodiac) as? Bool ?? false
        self.showDaysRemaining = self.defaults.object(forKey: Keys.showDays) as? Bool ?? true
        self.showBackgroundArt = self.defaults.object(forKey: Keys.showArt) as? Bool ?? true
        self.smartRemindersEnabled = self.defaults.object(forKey: Keys.smart) as? Bool ?? true
        self.lastContactsCheck = self.defaults.object(forKey: Keys.lastCheck) as? Date
    }

    // MARK: Stored preferences

    var hasCompletedOnboarding: Bool { didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) } }
    var defaultReminderDays: [Int] { didSet { defaults.set(AppSettings.encodeDays(defaultReminderDays), forKey: Keys.reminderDays) } }
    var notificationHour: Int { didSet { defaults.set(notificationHour, forKey: Keys.hour) } }
    var notificationMinute: Int { didSet { defaults.set(notificationMinute, forKey: Keys.minute) } }
    var accentIndex: Int { didSet { defaults.set(accentIndex, forKey: Keys.accent) } }
    var showAge: Bool { didSet { defaults.set(showAge, forKey: Keys.showAge) } }
    var showZodiac: Bool { didSet { defaults.set(showZodiac, forKey: Keys.showZodiac) } }
    var showDaysRemaining: Bool { didSet { defaults.set(showDaysRemaining, forKey: Keys.showDays) } }
    var showBackgroundArt: Bool { didSet { defaults.set(showBackgroundArt, forKey: Keys.showArt) } }
    var smartRemindersEnabled: Bool { didSet { defaults.set(smartRemindersEnabled, forKey: Keys.smart) } }
    var lastContactsCheck: Date? { didSet { defaults.set(lastContactsCheck, forKey: Keys.lastCheck) } }

    // MARK: Derived

    var accentColor: Color { Theme.accent(at: accentIndex) }

    var notificationTimeLabel: String {
        var components = DateComponents()
        components.hour = notificationHour
        components.minute = notificationMinute
        let date = BirthdayMath.calendar.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    var defaultRemindersSummary: String {
        guard !defaultReminderDays.isEmpty else { return "None" }
        return defaultReminderDays
            .sorted(by: >)
            .map { ReminderOffset.shortLabel(forDays: $0) }
            .joined(separator: " · ")
    }

    // MARK: Helpers

    private enum Keys {
        static let onboarding = "hasCompletedOnboarding"
        static let reminderDays = "defaultReminderDays"
        static let hour = "notificationHour"
        static let minute = "notificationMinute"
        static let accent = "accentIndex"
        static let showAge = "showAge"
        static let showZodiac = "showZodiac"
        static let showDays = "showDaysRemaining"
        static let showArt = "showBackgroundArt"
        static let smart = "smartRemindersEnabled"
        static let lastCheck = "lastContactsCheck"
    }

    private static func encodeDays(_ days: [Int]) -> String {
        days.map(String.init).joined(separator: ",")
    }

    private static func decodeDays(_ raw: String?) -> [Int]? {
        guard let raw else { return nil }
        if raw.isEmpty { return [] }
        return raw.split(separator: ",").compactMap { Int($0) }
    }
}
