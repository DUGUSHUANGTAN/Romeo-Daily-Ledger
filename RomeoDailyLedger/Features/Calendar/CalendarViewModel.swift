import Foundation
import Observation

@Observable
@MainActor
final class CalendarViewModel {
    static let supportedYears = 1900...2100
    struct Day: Identifiable, Equatable {
        let date: Date
        let isInDisplayedMonth: Bool

        var id: Date { date }
    }

    private(set) var calendar: Calendar
    var displayedMonth: Date
    var selectedDate: Date

    init(
        calendar: Calendar = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent,
        initialDate: Date = .now
    ) {
        var localCalendar = calendar
        localCalendar.timeZone = timeZone
        self.calendar = localCalendar
        self.displayedMonth = initialDate
        self.selectedDate = initialDate
        self.displayedMonth = monthStart(containing: initialDate)
    }

    func dayInterval(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .day, for: date)!
    }

    func moveMonth(by offset: Int) {
        let target = calendar.date(byAdding: .month, value: offset, to: displayedMonth)!
        let year = calendar.component(.year, from: target)
        guard Self.supportedYears.contains(year) else { return }
        displayedMonth = monthStart(containing: target)
    }

    func select(year: Int, month: Int) {
        let year = min(max(year, Self.supportedYears.lowerBound), Self.supportedYears.upperBound)
        let month = min(max(month, 1), 12)
        var components = DateComponents(year: year, month: month, day: 1)
        components.timeZone = calendar.timeZone
        if let date = calendar.date(from: components) { displayedMonth = monthStart(containing: date) }
    }

    func selectToday(_ today: Date = .now) {
        let year = calendar.component(.year, from: today)
        guard Self.supportedYears.contains(year) else { return }
        selectedDate = today
        displayedMonth = monthStart(containing: today)
    }

    func monthGrid() -> [Day] {
        let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth)!
        let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)!
        let lastDay = calendar.date(byAdding: .day, value: -1, to: monthInterval.end)!
        let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: lastDay)!

        var days: [Day] = []
        var date = firstWeek.start
        while date < lastWeek.end {
            days.append(Day(date: date, isInDisplayedMonth: calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)))
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        return days
    }

    private func monthStart(containing date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)!.start
    }
}
