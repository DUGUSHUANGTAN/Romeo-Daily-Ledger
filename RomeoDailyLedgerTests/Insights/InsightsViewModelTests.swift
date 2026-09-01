import Foundation
import Testing
@testable import RomeoDailyLedger

@Suite("InsightsViewModel")
@MainActor
struct InsightsViewModelTests {
    @Test func loadRequestsTheDisplayedLocalMonthAndPublishesReport() async {
        let repository = InsightsRepositoryStub()
        let salaryID = UUID()
        repository.entriesToReturn = [
            LedgerEntry(kind: .income, amount: decimal("88.80"), categoryID: salaryID, note: "", occurredAt: date(2026, 8, 8))
        ]
        let model = InsightsViewModel(
            repository: repository,
            calendar: calendar,
            timeZone: calendar.timeZone,
            initialDate: date(2026, 8, 18)
        )

        await model.load()

        #expect(repository.requestedIntervals == [DateInterval(start: date(2026, 8, 1), end: date(2026, 9, 1))])
        #expect(model.report.income == decimal("88.80"))
        #expect(model.errorMessage == nil)
    }

    @Test func movingMonthReloadsTheNewMonth() async {
        let repository = InsightsRepositoryStub()
        let model = InsightsViewModel(
            repository: repository,
            calendar: calendar,
            timeZone: calendar.timeZone,
            initialDate: date(2026, 8, 18)
        )

        await model.moveMonth(by: -1)

        #expect(model.displayedMonth == date(2026, 7, 1))
        #expect(repository.requestedIntervals == [DateInterval(start: date(2026, 7, 1), end: date(2026, 8, 1))])
    }

    @Test func unresolvedCategoryUsesOtherDisplayName() async {
        let repository = InsightsRepositoryStub()
        repository.entriesToReturn = [
            LedgerEntry(
                kind: .expense,
                amount: decimal("5"),
                categoryID: InsightsAggregator.uncategorizedCategoryID,
                note: "",
                occurredAt: date(2026, 8, 8)
            )
        ]
        let model = InsightsViewModel(
            repository: repository,
            calendar: calendar,
            timeZone: calendar.timeZone,
            initialDate: date(2026, 8, 18)
        )

        await model.load()

        #expect(model.displayName(for: model.report.categories[0]) == "其他")
    }

    @Test func selectingYearAndMonthReloadsImmediatelyAndClampsRange() async {
        let repository = InsightsRepositoryStub()
        let model = InsightsViewModel(repository: repository, calendar: calendar, timeZone: calendar.timeZone)
        await model.select(year: 2200, month: 0)
        #expect(model.displayedMonth == date(2100, 1, 1))
        #expect(repository.requestedIntervals == [DateInterval(start: date(2100, 1, 1), end: date(2100, 2, 1))])
    }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return value
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func decimal(_ value: String) -> Decimal {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))!
    }
}

@MainActor
private final class InsightsRepositoryStub: LedgerRepository {
    var entriesToReturn: [LedgerEntry] = []
    var categoriesToReturn: [RomeoDailyLedger.Category] = []
    private(set) var requestedIntervals: [DateInterval] = []

    func seedDefaultsIfNeeded() async throws {}
    func insert(_ draft: LedgerDraft) async throws -> LedgerEntry { throw TestRepositoryError.forcedFailure }
    func update(id: UUID, draft: LedgerDraft) async throws { throw TestRepositoryError.forcedFailure }
    func delete(ids: Set<UUID>) async throws { throw TestRepositoryError.forcedFailure }
    func entries(in interval: DateInterval) async throws -> [LedgerEntry] {
        requestedIntervals.append(interval)
        return entriesToReturn
    }
    func categories(kind: EntryKind) async throws -> [RomeoDailyLedger.Category] {
        categoriesToReturn.filter { $0.kind == kind }
    }
    func category(id: UUID) async throws -> RomeoDailyLedger.Category? {
        categoriesToReturn.first { $0.id == id }
    }
}
