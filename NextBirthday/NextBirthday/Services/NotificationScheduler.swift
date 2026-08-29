import Foundation
import UserNotifications

/// Schedules every birthday reminder as a local notification.
///
/// iOS caps an app at 64 pending local notifications, so we always schedule the
/// soonest ones and rebuild the queue whenever the app becomes active or the
/// data changes. With the default three reminders per person that covers the
/// next ~20 birthdays, which is far beyond any realistic reminder horizon.
enum NotificationScheduler {

    static let maxPending = 60

    // MARK: - Authorization

    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: - Scheduling

    struct PendingReminder {
        let person: Person
        let daysBefore: Int
        let fireDate: Date
    }

    /// Removes every reminder and rebuilds the queue from the current data.
    @MainActor
    static func rebuild(for people: [Person], settings: AppSettings) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        let reminders = upcomingReminders(for: people, settings: settings)
            .prefix(maxPending)

        for reminder in reminders {
            let request = makeRequest(for: reminder, settings: settings)
            do {
                try await center.add(request)
            } catch {
                #if DEBUG
                print("Failed to schedule reminder: \(error)")
                #endif
            }
        }
    }

    /// Every future reminder, soonest first.
    static func upcomingReminders(for people: [Person], settings: AppSettings) -> [PendingReminder] {
        let calendar = BirthdayMath.calendar
        let now = Date()
        var result: [PendingReminder] = []

        for person in people {
            let days = person.effectiveReminderDays(defaults: settings.defaultReminderDays)
            guard !days.isEmpty else { continue }

            // Look at this year's and next year's birthday so a reminder that
            // has already passed this cycle rolls forward.
            let occurrences = [
                person.nextBirthday,
                calendar.date(byAdding: .year, value: 1, to: person.nextBirthday) ?? person.nextBirthday
            ]

            for daysBefore in days {
                for occurrence in occurrences {
                    guard let base = calendar.date(byAdding: .day, value: -daysBefore, to: occurrence),
                          let fireDate = calendar.date(bySettingHour: settings.notificationHour,
                                                       minute: settings.notificationMinute,
                                                       second: 0,
                                                       of: base)
                    else { continue }
                    if fireDate > now {
                        result.append(PendingReminder(person: person, daysBefore: daysBefore, fireDate: fireDate))
                        break // only the next cycle for this offset
                    }
                }
            }
        }

        return result.sorted { $0.fireDate < $1.fireDate }
    }

    private static func makeRequest(for reminder: PendingReminder, settings: AppSettings) -> UNNotificationRequest {
        let person = reminder.person
        let content = UNMutableNotificationContent()
        let text = message(for: person, daysBefore: reminder.daysBefore, smart: settings.smartRemindersEnabled)
        content.title = text.title
        content.body = text.body
        content.sound = .default
        content.userInfo = ["personID": person.uuid]
        content.threadIdentifier = person.uuid

        let components = BirthdayMath.calendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: reminder.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let identifier = "birthday-\(person.uuid)-\(reminder.daysBefore)"
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    // MARK: - Copy

    struct ReminderText {
        let title: String
        let body: String
    }

    static func message(for person: Person, daysBefore: Int, smart: Bool) -> ReminderText {
        let name = person.displayFirstName
        let age = person.turningAge
        let intent = ReminderOffset(rawValue: daysBefore)?.intent ?? .thinkAboutGift

        if daysBefore == 0 {
            let title = "🎉 It's \(name)'s birthday today!"
            let body: String
            if let age {
                body = "\(name) turns \(age) today. Send a message or give them a call."
            } else {
                body = "Time to wish \(name) a happy birthday."
            }
            return ReminderText(title: title, body: body)
        }

        let whenPhrase = daysBefore == 1 ? "tomorrow" : "in \(daysBefore) days"

        guard smart else {
            let title: String
            if let age {
                title = "🎂 \(name) turns \(age) \(whenPhrase)."
            } else {
                title = "🎂 \(name)'s birthday is \(whenPhrase)."
            }
            return ReminderText(title: title, body: BirthdayMath.fullDateLabel(
                month: person.birthMonth, day: person.birthDay, year: person.birthYear))
        }

        switch intent {
        case .thinkAboutGift:
            return ReminderText(
                title: "🎁 Gift idea for \(name)?",
                body: "\(name)'s birthday is \(whenPhrase). A good moment to start thinking about a gift.")
        case .buyGift:
            return ReminderText(
                title: "🛍️ Time to get \(name)'s gift",
                body: "Only \(daysBefore) days left before \(name)'s birthday.")
        case .sendMessageSoon:
            if let age {
                return ReminderText(title: "🎂 \(name) turns \(age) tomorrow",
                                    body: "Get your message ready.")
            }
            return ReminderText(title: "🎂 \(name)'s birthday is tomorrow",
                                body: "Get your message ready.")
        case .wishThemToday:
            return ReminderText(title: "🎉 It's \(name)'s birthday today!",
                                body: "Send them your wishes.")
        }
    }

    /// A suggested message the user can copy on the day.
    static func birthdayMessage(for person: Person) -> String {
        let name = person.displayFirstName
        if let age = person.turningAge {
            let formatter = NumberFormatter()
            formatter.numberStyle = .ordinal
            formatter.locale = Locale.current
            let ordinal = formatter.string(from: NSNumber(value: age)) ?? "\(age)th"
            return "Happy \(ordinal) birthday, \(name)! 🎂 Wishing you a wonderful day."
        }
        return "Happy birthday, \(name)! 🎂 Wishing you a wonderful day."
    }
}
