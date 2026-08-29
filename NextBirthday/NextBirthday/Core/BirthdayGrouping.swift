import Foundation

/// Buckets upcoming birthdays the way the Upcoming screen shows them.
enum BirthdayGrouping {

    struct Section: Identifiable {
        var id: String { title }
        let title: String
        let people: [Person]
    }

    static func sections(from people: [Person], skippingFirst: Bool = false) -> [Section] {
        let sorted = people.sorted { lhs, rhs in
            if lhs.daysUntilBirthday != rhs.daysUntilBirthday {
                return lhs.daysUntilBirthday < rhs.daysUntilBirthday
            }
            return lhs.fullName < rhs.fullName
        }
        let list = skippingFirst ? Array(sorted.dropFirst()) : sorted

        var today: [Person] = []
        var tomorrow: [Person] = []
        var thisWeek: [Person] = []
        var nextWeek: [Person] = []
        var byMonth: [Int: [Person]] = [:]
        var monthOrder: [Int] = []

        for person in list {
            switch person.daysUntilBirthday {
            case 0: today.append(person)
            case 1: tomorrow.append(person)
            case 2...7: thisWeek.append(person)
            case 8...14: nextWeek.append(person)
            default:
                let month = BirthdayMath.calendar.component(.month, from: person.nextBirthday)
                if byMonth[month] == nil {
                    byMonth[month] = []
                    monthOrder.append(month)
                }
                byMonth[month]?.append(person)
            }
        }

        var sections: [Section] = []
        if !today.isEmpty { sections.append(Section(title: "Today", people: today)) }
        if !tomorrow.isEmpty { sections.append(Section(title: "Tomorrow", people: tomorrow)) }
        if !thisWeek.isEmpty { sections.append(Section(title: "This Week", people: thisWeek)) }
        if !nextWeek.isEmpty { sections.append(Section(title: "Next Week", people: nextWeek)) }
        for month in monthOrder {
            let title = BirthdayMath.monthName(month)
            sections.append(Section(title: title, people: byMonth[month] ?? []))
        }
        return sections
    }

    /// Counts shown in the small stats strip.
    static func stats(for people: [Person]) -> (thisWeek: Int, thisMonth: Int) {
        let week = people.filter { $0.daysUntilBirthday <= 7 }.count
        let currentMonth = BirthdayMath.calendar.component(.month, from: Date())
        let month = people.filter { $0.birthMonth == currentMonth }.count
        return (week, month)
    }
}
