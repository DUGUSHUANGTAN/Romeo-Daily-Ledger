import Foundation
import Testing
@testable import RomeoDailyLedger

@Suite("CalendarViewModel")
@MainActor
struct CalendarViewModelTests {
    private let shanghai = TimeZone(identifier: "Asia/Shanghai")!

    @Test func selectedDayUsesLocalCalendarBoundaries() throws {
        let model = CalendarViewModel(calendar: Calendar(identifier: .gregorian), timeZone: shanghai)
        let date = try #require(ISO8601DateFormatter().date(from: "2026-08-29T12:00:00+08:00"))

        let interval = model.dayInterval(containing: date)

        #expect(interval.duration == 86_400)
        #expect(model.calendar.component(.hour, from: interval.start) == 0)
        #expect(model.calendar.component(.day, from: interval.start) == 29)
        #expect(model.calendar.component(.day, from: interval.end) == 30)
    }

    @Test func monthNavigationPreservesLocalMonthStart() throws {
        let model = CalendarViewModel(calendar: Calendar(identifier: .gregorian), timeZone: shanghai)
        let august = try #require(ISO8601DateFormatter().date(from: "2026-08-15T12:00:00+08:00"))
        model.displayedMonth = august

        model.moveMonth(by: 1)

        #expect(model.calendar.component(.year, from: model.displayedMonth) == 2026)
        #expect(model.calendar.component(.month, from: model.displayedMonth) == 9)
        #expect(model.calendar.component(.day, from: model.displayedMonth) == 1)
    }

    @Test func monthGridContainsWholeWeeksAndMarksDisplayedMonth() throws {
        let model = CalendarViewModel(calendar: Calendar(identifier: .gregorian), timeZone: shanghai)
        model.displayedMonth = try #require(ISO8601DateFormatter().date(from: "2026-08-15T12:00:00+08:00"))

        let days = model.monthGrid()

        #expect(days.count.isMultiple(of: 7))
        #expect(days.count >= 35)
        #expect(days.filter(\.isInDisplayedMonth).count == 31)
    }

    @Test func yearAndMonthSelectionIsClampedToSupportedRange() {
        let model = CalendarViewModel(calendar: Calendar(identifier: .gregorian), timeZone: shanghai)
        model.select(year: 1899, month: 13)
        #expect(model.calendar.component(.year, from: model.displayedMonth) == 1900)
        #expect(model.calendar.component(.month, from: model.displayedMonth) == 12)
    }

    @Test func monthNavigationStopsAtSupportedBoundary() {
        let model = CalendarViewModel(calendar: Calendar(identifier: .gregorian), timeZone: shanghai)
        model.select(year: 2100, month: 12)
        model.moveMonth(by: 1)
        #expect(model.calendar.component(.year, from: model.displayedMonth) == 2100)
        #expect(model.calendar.component(.month, from: model.displayedMonth) == 12)
    }
}
