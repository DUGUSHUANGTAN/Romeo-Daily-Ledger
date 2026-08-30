import Foundation
import Testing
@testable import RomeoDailyLedger

@Suite("InsightsAggregator")
struct InsightsAggregatorTests {
    private let foodID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let salaryID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let august = DateInterval(
        start: Self.date(2026, 8, 1),
        end: Self.date(2026, 9, 1)
    )

    @Test func pureIncomeReportsIncomeAndPositiveNet() {
        let report = makeReport([entry(.income, "1000", salaryID, day: 3)])

        #expect(report.income == decimal("1000"))
        #expect(report.expense == 0)
        #expect(report.net == decimal("1000"))
    }

    @Test func pureExpenseReportsExpenseAndNegativeNet() {
        let report = makeReport([entry(.expense, "250", foodID, day: 4)])

        #expect(report.income == 0)
        #expect(report.expense == decimal("250"))
        #expect(report.net == decimal("-250"))
    }

    @Test func mixedEntriesReportMonthlyTotals() {
        let report = makeReport([
            entry(.income, "1000", salaryID, day: 3),
            entry(.expense, "150", foodID, day: 4),
            entry(.expense, "100", foodID, day: 5),
        ])

        #expect(report.income == decimal("1000"))
        #expect(report.expense == decimal("250"))
        #expect(report.net == decimal("750"))
        #expect(report.categoryTotals[foodID] == decimal("250"))
    }

    @Test func emptyInputProducesZeroReport() {
        let report = makeReport([])

        #expect(report.income == 0)
        #expect(report.expense == 0)
        #expect(report.net == 0)
        #expect(report.categories.isEmpty)
    }

    @Test func categorySharesUseTheMatchingKindTotal() {
        let transportID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let report = makeReport([
            entry(.expense, "60", foodID, day: 4),
            entry(.expense, "40", transportID, day: 5),
            entry(.income, "200", salaryID, day: 6),
        ])

        #expect(report.category(id: foodID)?.share == decimal("0.6"))
        #expect(report.category(id: transportID)?.share == decimal("0.4"))
        #expect(report.category(id: salaryID)?.share == decimal("1"))
    }

    @Test func entriesOutsideTheHalfOpenMonthIntervalAreExcluded() {
        let report = InsightsAggregator().makeReport(
            entries: [
                LedgerEntry(kind: .income, amount: decimal("10"), categoryID: salaryID, note: "before", occurredAt: Self.date(2026, 7, 31)),
                entry(.income, "20", salaryID, day: 1),
                LedgerEntry(kind: .income, amount: decimal("30"), categoryID: salaryID, note: "end", occurredAt: Self.date(2026, 9, 1)),
            ],
            interval: august
        )

        #expect(report.income == decimal("20"))
    }

    @Test func decimalPrecisionIsPreservedWithoutDoubleArithmetic() {
        let report = makeReport([
            entry(.expense, "0.10", foodID, day: 1),
            entry(.expense, "0.20", foodID, day: 2),
        ])

        #expect(report.expense == decimal("0.30"))
        #expect(report.categoryTotals[foodID] == decimal("0.30"))
    }

    @Test func uncategorizedEntriesAreGroupedIntoOther() {
        let report = makeReport([
            entry(.expense, "12.50", InsightsAggregator.uncategorizedCategoryID, day: 2),
            entry(.expense, "7.50", InsightsAggregator.uncategorizedCategoryID, day: 3),
        ])

        let other = report.category(id: InsightsAggregator.uncategorizedCategoryID)
        #expect(other?.isOther == true)
        #expect(other?.amount == decimal("20.00"))
        #expect(other?.share == decimal("1"))
    }

    private func makeReport(_ entries: [LedgerEntry]) -> InsightsReport {
        InsightsAggregator().makeReport(entries: entries, interval: august)
    }

    private func entry(_ kind: EntryKind, _ amount: String, _ categoryID: UUID, day: Int) -> LedgerEntry {
        LedgerEntry(kind: kind, amount: decimal(amount), categoryID: categoryID, note: "", occurredAt: Self.date(2026, 8, day))
    }

    private func decimal(_ value: String) -> Decimal {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))!
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
