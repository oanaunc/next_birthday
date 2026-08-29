import Foundation

/// All date arithmetic for birthdays lives here so the app and the widget
/// always agree on countdowns and ages.
enum BirthdayMath {

    static var calendar: Calendar {
        var cal = Calendar.current
        cal.locale = Locale.current
        return cal
    }

    /// Start of today in the user's current time zone.
    static func today(_ now: Date = Date()) -> Date {
        calendar.startOfDay(for: now)
    }

    /// The next time this month/day occurs, at midnight, on or after `reference`.
    ///
    /// Feb 29 birthdays fall back to Feb 28 in non-leap years so the person
    /// still shows up every single year.
    static func nextOccurrence(month: Int, day: Int, from reference: Date = Date()) -> Date {
        let cal = calendar
        let start = cal.startOfDay(for: reference)
        let currentYear = cal.component(.year, from: start)

        for yearOffset in 0...1 {
            let year = currentYear + yearOffset
            if let candidate = resolvedDate(year: year, month: month, day: day),
               candidate >= start {
                return candidate
            }
        }
        // Should be unreachable; keep the app alive rather than crashing.
        return start
    }

    /// Builds a real date for a year/month/day, collapsing Feb 29 to Feb 28
    /// when the year isn't a leap year.
    static func resolvedDate(year: Int, month: Int, day: Int) -> Date? {
        let cal = calendar
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 0
        components.minute = 0
        components.second = 0

        if let date = cal.date(from: components),
           cal.component(.day, from: date) == day,
           cal.component(.month, from: date) == month {
            return date
        }

        // Feb 29 in a non-leap year (or any other invalid combination):
        // clamp to the last valid day of that month.
        var fallback = DateComponents()
        fallback.year = year
        fallback.month = month
        fallback.day = 1
        guard let firstOfMonth = cal.date(from: fallback),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth) else { return nil }
        fallback.day = min(day, range.count)
        return cal.date(from: fallback)
    }

    /// Whole days from today until the next occurrence. 0 means today.
    static func daysUntil(month: Int, day: Int, from reference: Date = Date()) -> Int {
        let start = calendar.startOfDay(for: reference)
        let next = nextOccurrence(month: month, day: day, from: reference)
        return calendar.dateComponents([.day], from: start, to: next).day ?? 0
    }

    /// Age the person turns on their *next* birthday. Nil when the year is unknown.
    static func turningAge(birthYear: Int?, month: Int, day: Int, from reference: Date = Date()) -> Int? {
        guard let birthYear else { return nil }
        let next = nextOccurrence(month: month, day: day, from: reference)
        let year = calendar.component(.year, from: next)
        let age = year - birthYear
        return age >= 0 ? age : nil
    }

    /// The person's age right now. Nil when the year is unknown.
    static func currentAge(birthYear: Int?, month: Int, day: Int, from reference: Date = Date()) -> Int? {
        guard let birthYear else { return nil }
        guard let birthDate = resolvedDate(year: birthYear, month: month, day: day) else { return nil }
        let start = calendar.startOfDay(for: reference)
        guard birthDate <= start else { return nil }
        return calendar.dateComponents([.year], from: birthDate, to: start).year
    }

    // MARK: - Formatting

    /// "Today", "Tomorrow", "In 6 days", "In 3 weeks"...
    static func countdownLabel(days: Int) -> String {
        switch days {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case 2...13: return "\(days) days"
        case 14...59:
            let weeks = Int((Double(days) / 7.0).rounded())
            return weeks == 1 ? "1 week" : "\(weeks) weeks"
        default:
            let months = Int((Double(days) / 30.44).rounded())
            return months <= 1 ? "1 month" : "\(months) months"
        }
    }

    /// Compact form for widgets and badges: "Today", "1d", "26d".
    static func compactCountdown(days: Int) -> String {
        switch days {
        case 0: return "Today"
        default: return "\(days)d"
        }
    }

    /// "September 4" or "September 4, 1995".
    static func fullDateLabel(month: Int, day: Int, year: Int?) -> String {
        guard let date = resolvedDate(year: year ?? 2000, month: month, day: day) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate(year == nil ? "MMMMd" : "MMMMdyyyy")
        return formatter.string(from: date)
    }

    /// "Sep 4".
    static func shortDateLabel(month: Int, day: Int) -> String {
        guard let date = resolvedDate(year: 2000, month: month, day: day) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }

    static func monthName(_ month: Int, short: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let symbols = short ? formatter.shortMonthSymbols : formatter.monthSymbols
        guard let symbols, month >= 1, month <= symbols.count else { return "" }
        return symbols[month - 1]
    }

    // MARK: - Zodiac

    static func zodiacSign(month: Int, day: Int) -> String {
        switch (month, day) {
        case (3, 21...31), (4, 1...19):   return "Aries"
        case (4, 20...30), (5, 1...20):   return "Taurus"
        case (5, 21...31), (6, 1...20):   return "Gemini"
        case (6, 21...30), (7, 1...22):   return "Cancer"
        case (7, 23...31), (8, 1...22):   return "Leo"
        case (8, 23...31), (9, 1...22):   return "Virgo"
        case (9, 23...30), (10, 1...22):  return "Libra"
        case (10, 23...31), (11, 1...21): return "Scorpio"
        case (11, 22...30), (12, 1...21): return "Sagittarius"
        case (12, 22...31), (1, 1...19):  return "Capricorn"
        case (1, 20...31), (2, 1...18):   return "Aquarius"
        default:                          return "Pisces"
        }
    }

    static func zodiacSymbol(month: Int, day: Int) -> String {
        switch zodiacSign(month: month, day: day) {
        case "Aries": return "♈︎"
        case "Taurus": return "♉︎"
        case "Gemini": return "♊︎"
        case "Cancer": return "♋︎"
        case "Leo": return "♌︎"
        case "Virgo": return "♍︎"
        case "Libra": return "♎︎"
        case "Scorpio": return "♏︎"
        case "Sagittarius": return "♐︎"
        case "Capricorn": return "♑︎"
        case "Aquarius": return "♒︎"
        default: return "♓︎"
        }
    }
}
