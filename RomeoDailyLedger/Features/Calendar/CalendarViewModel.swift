import Foundation
import Observation

@Observable
@MainActor
final class CalendarViewModel {
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
        displayedMonth = monthStart(containing: target)
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
