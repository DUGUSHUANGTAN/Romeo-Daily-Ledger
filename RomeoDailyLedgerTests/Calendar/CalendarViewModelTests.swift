import Foundation
import Testing
@testable import RomeoDailyLedger

@Suite("CalendarViewModel")
@MainActor
struct CalendarViewModelTests {
    @Test func manuallyEnteredYearAcceptsValidTextAndRejectsInvalidText() {
        #expect(CalendarViewModel.validatedYear(from: "0") == 0)
        #expect(CalendarViewModel.validatedYear(from: "2026") == 2026)
        #expect(CalendarViewModel.validatedYear(from: "9999") == 9999)
        #expect(CalendarViewModel.validatedYear(from: "twenty") == nil)
        #expect(CalendarViewModel.validatedYear(from: "-1") == nil)
        #expect(CalendarViewModel.validatedYear(from: "10000") == nil)
    }
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
        model.select(year: -1, month: 13)
        #expect(model.displayedYear == 0)
        #expect(model.calendar.component(.month, from: model.displayedMonth) == 12)

        model.select(year: 9999, month: 1)
        #expect(model.displayedYear == 9999)
    }

    @Test func yearAndMonthSelectionAlsoSelectsTargetMonth() {
        let model = CalendarViewModel(calendar: Calendar(identifier: .gregorian), timeZone: shanghai)
        model.select(year: 2020, month: 2)
        #expect(model.calendar.component(.year, from: model.selectedDate) == 2020)
        #expect(model.calendar.component(.month, from: model.selectedDate) == 2)
        #expect(model.calendar.component(.day, from: model.selectedDate) == 1)
    }

    @Test func monthNavigationStopsAtSupportedBoundary() {
        let model = CalendarViewModel(calendar: Calendar(identifier: .gregorian), timeZone: shanghai)
        model.select(year: 9999, month: 12)
        model.moveMonth(by: 1)
        #expect(model.displayedYear == 9999)
        #expect(model.calendar.component(.month, from: model.displayedMonth) == 12)
    }
}

@Suite("History ledger")
@MainActor
struct HistoryLedgerTests {
    @Test func searchMatchesLocalDateNoteAndLocalizedCategoryName() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let date = try #require(ISO8601DateFormatter().date(from: "2026-08-29T12:00:00+08:00"))
        let foodID = UUID()
        let entries = [
            LedgerEntry(kind: .expense, amount: 18, categoryID: foodID, note: "拿铁", occurredAt: date),
            LedgerEntry(kind: .income, amount: 100, categoryID: UUID(), note: "奖金", occurredAt: date)
        ]
        let index = HistorySearchIndex(
            entries: entries,
            categoryNames: [foodID: "餐饮"],
            calendar: calendar,
            incomeName: "收入",
            expenseName: "支出"
        )

        #expect(index.results(matching: "2026-08-29").count == 2)
        #expect(index.results(matching: "拿铁").map(\.note) == ["拿铁"])
        #expect(index.results(matching: "餐饮").map(\.note) == ["拿铁"])
        #expect(index.results(matching: "不存在").isEmpty)
    }

    @Test func searchMatchesIncomeAndExpenseInTheSelectedLanguage() {
        let income = LedgerEntry(kind: .income, amount: 100, categoryID: UUID(), note: "", occurredAt: .now)
        let expense = LedgerEntry(kind: .expense, amount: 20, categoryID: UUID(), note: "", occurredAt: .now)

        for language in AppLanguage.allCases {
            let incomeName = AppLocalization.text("entry.income", language: language)
            let expenseName = AppLocalization.text("entry.expense", language: language)
            let index = HistorySearchIndex(
                entries: [income, expense],
                categoryNames: [:],
                calendar: .autoupdatingCurrent,
                incomeName: incomeName,
                expenseName: expenseName
            )

            #expect(index.results(matching: incomeName).map(\.id) == [income.id])
            #expect(index.results(matching: expenseName).map(\.id) == [expense.id])
        }
    }

    @Test func selectionSummaryIncludesBalanceAndConfirmedDeleteIsImmediate() async {
        let repository = RecordingLedgerRepository()
        let income = LedgerEntry(kind: .income, amount: 100, categoryID: UUID(), note: "Income", occurredAt: .now)
        let expense = LedgerEntry(kind: .expense, amount: 35, categoryID: UUID(), note: "Expense", occurredAt: .now)
        repository.entriesToReturn = [income, expense]
        let model = EntriesCollectionModel(repository: repository)
        await model.loadAll()
        model.selectedEntryIDs = [income.id, expense.id]

        #expect(model.selectionSummary.balance == 65)
        await model.deleteSelection()
        #expect(repository.deletedIDSets == [[income.id, expense.id]])
        #expect(model.selectedEntryIDs.isEmpty)
    }
}
