import SwiftUI
import SwiftData

/// Month grid with birthday dots, plus a year overview.
struct CalendarScreen: View {

    @Query private var people: [Person]
    @Environment(AppSettings.self) private var settings

    @State private var mode: Mode = .month
    @State private var anchor = Date()
    @State private var selectedDay: Int?

    enum Mode: String, CaseIterable, Identifiable {
        case month = "Month"
        case year = "Year"
        var id: String { rawValue }
    }

    private var calendar: Calendar { BirthdayMath.calendar }
    private var displayedMonth: Int { calendar.component(.month, from: anchor) }
    private var displayedYear: Int { calendar.component(.year, from: anchor) }

    /// People whose birthday falls in the displayed month, keyed by day.
    private var peopleByDay: [Int: [Person]] {
        Dictionary(grouping: people.filter { $0.birthMonth == displayedMonth }) { $0.birthDay }
    }

    private var monthPeople: [Person] {
        people.filter { $0.birthMonth == displayedMonth }
            .sorted { $0.birthDay < $1.birthDay }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("View", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    if mode == .month {
                        monthView
                    } else {
                        yearView
                    }
                }
                .padding(.vertical, 8)
                .padding(.bottom, 24)
            }
            .screenBackground(.calendar)
            .navigationTitle("Calendar")
            .navigationDestination(for: Person.self) { PersonDetailView(person: $0) }
        }
    }

    // MARK: Month

    private var monthView: some View {
        VStack(spacing: 14) {
            GlassCard(padding: 14) {
                VStack(spacing: 12) {
                    monthHeader
                    weekdayHeader
                    dayGrid
                }
            }
            .padding(.horizontal, 16)

            if let selectedDay, let dayPeople = peopleByDay[selectedDay], !dayPeople.isEmpty {
                selectedDayCard(day: selectedDay, people: dayPeople)
            }

            monthListCard
        }
    }

    private var monthHeader: some View {
        HStack {
            Button { step(-1) } label: {
                Image(systemName: "chevron.left").font(.body.weight(.semibold))
            }
            Spacer()
            Text("\(BirthdayMath.monthName(displayedMonth)) \(String(displayedYear))")
                .font(.headline)
                .foregroundStyle(Theme.deepInk)
            Spacer()
            Button { step(1) } label: {
                Image(systemName: "chevron.right").font(.body.weight(.semibold))
            }
        }
    }

    private var weekdayHeader: some View {
        let symbols = orderedWeekdaySymbols()
        return HStack(spacing: 0) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var dayGrid: some View {
        let cells = gridCells()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
                         spacing: 6) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 42)
                }
            }
        }
    }

    private func dayCell(_ day: Int) -> some View {
        let dayPeople = peopleByDay[day] ?? []
        let isToday = calendar.component(.day, from: Date()) == day
            && calendar.component(.month, from: Date()) == displayedMonth
            && calendar.component(.year, from: Date()) == displayedYear
        let isSelected = selectedDay == day

        return Button {
            selectedDay = (selectedDay == day) ? nil : day
        } label: {
            VStack(spacing: 3) {
                Text("\(day)")
                    .font(.system(size: 13, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isSelected ? .white : (isToday ? Theme.purple : .primary))
                HStack(spacing: 2) {
                    ForEach(0..<min(dayPeople.count, 3), id: \.self) { _ in
                        Circle()
                            .fill(isSelected ? Color.white : Theme.pink)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Theme.purple
                          : (isToday ? Theme.purple.opacity(0.14) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .disabled(dayPeople.isEmpty && !isToday)
    }

    private func selectedDayCard(day: Int, people dayPeople: [Person]) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(BirthdayMath.fullDateLabel(month: displayedMonth, day: day, year: nil))
                    .font(.subheadline.weight(.semibold))
                ForEach(dayPeople) { person in
                    NavigationLink(value: person) {
                        HStack(spacing: 10) {
                            Text("🎂")
                            PersonRow(person: person, showsCountdown: false)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var monthListCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "\(BirthdayMath.monthName(displayedMonth)) Birthdays",
                          count: monthPeople.count)
                .padding(.horizontal, 20)

            if monthPeople.isEmpty {
                GlassCard {
                    Text("No birthdays this month.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
            } else {
                GlassCard(padding: 10) {
                    VStack(spacing: 0) {
                        ForEach(Array(monthPeople.enumerated()), id: \.element.id) { index, person in
                            NavigationLink(value: person) {
                                PersonRow(person: person)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 6)
                            if index < monthPeople.count - 1 {
                                Divider().padding(.leading, 62)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: Year

    private var yearView: some View {
        let counts = (1...12).map { month in
            people.filter { $0.birthMonth == month }.count
        }
        let maximum = max(counts.max() ?? 1, 1)

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                         spacing: 10) {
            ForEach(1...12, id: \.self) { month in
                let count = counts[month - 1]
                Button {
                    anchor = BirthdayMath.resolvedDate(year: displayedYear, month: month, day: 1) ?? anchor
                    mode = .month
                    selectedDay = nil
                } label: {
                    VStack(spacing: 6) {
                        Text(BirthdayMath.monthName(month, short: true).uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("\(count)")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(count == 0 ? Color.secondary : Theme.purple)
                        Capsule()
                            .fill(Theme.pink.opacity(0.25 + 0.75 * Double(count) / Double(maximum)))
                            .frame(height: 4)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: Helpers

    private func step(_ delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: anchor) {
            anchor = next
            selectedDay = nil
        }
    }

    private func orderedWeekdaySymbols() -> [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let symbols = formatter.veryShortWeekdaySymbols ?? ["S","M","T","W","T","F","S"]
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// Leading nils pad the grid so day 1 lands on the right weekday.
    private func gridCells() -> [Int?] {
        var components = DateComponents()
        components.year = displayedYear
        components.month = displayedMonth
        components.day = 1
        guard let firstOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth)
        else { return [] }

        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var cells: [Int?] = Array(repeating: nil, count: leading)
        cells.append(contentsOf: range.map { Optional($0) })
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }
}
