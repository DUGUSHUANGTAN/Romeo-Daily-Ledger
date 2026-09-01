import Foundation
import Testing
@testable import RomeoDailyLedger

@Suite("AI analysis filtering")
struct AIAnalysisTests {
    @Test(arguments: [
        (shiftPressed: false, hasMarkedText: false, expected: true),
        (shiftPressed: true, hasMarkedText: false, expected: false),
        (shiftPressed: false, hasMarkedText: true, expected: false)
    ])
    func multilineReturnHonorsShiftAndInputMethodComposition(shiftPressed: Bool, hasMarkedText: Bool, expected: Bool) {
        #expect(MultilineSubmitBehavior.shouldSubmit(shiftPressed: shiftPressed, hasMarkedText: hasMarkedText) == expected)
    }

    @Test(arguments: [
        (content: CGFloat(80), available: CGFloat(120), expected: false),
        (content: CGFloat(120), available: CGFloat(120), expected: false),
        (content: CGFloat(121), available: CGFloat(120), expected: true)
    ])
    func analysisResultScrollsOnlyWhenContentExceedsAvailableSpace(
        content: CGFloat,
        available: CGFloat,
        expected: Bool
    ) {
        #expect(AIAnalysisResultLayout.shouldScroll(contentHeight: content, availableHeight: available) == expected)
    }

    @Test func filtersEntriesToRequestedRange() throws {
        let start = Date(timeIntervalSince1970: 0)
        let inside = LedgerEntry(kind: .expense, amount: 10, categoryID: UUID(), note: "inside", occurredAt: start.addingTimeInterval(10))
        let outside = LedgerEntry(kind: .expense, amount: 20, categoryID: UUID(), note: "outside", occurredAt: start.addingTimeInterval(200))
        let aggregator = InsightsAggregator()
        let entries = aggregator.filteredEntries(entries: [inside, outside], interval: DateInterval(start: start, duration: 100))
        #expect(entries.count == 1)
        #expect(entries.first?.note == "inside")
    }

    @Test func scopeContainsEveryLedgerEntryWithoutDateFiltering() throws {
        let start = Date(timeIntervalSince1970: 0)
        let inside = LedgerEntry(kind: .expense, amount: 10, categoryID: UUID(), note: "inside", occurredAt: start.addingTimeInterval(10))
        let outside = LedgerEntry(kind: .income, amount: 20, categoryID: UUID(), note: "outside", occurredAt: start.addingTimeInterval(200))

        let scope = AIAnalysisScope(
            currencyCode: "USD",
            entries: [inside, outside],
            categoryNames: [inside.categoryID: "food"],
            timeZone: TimeZone(secondsFromGMT: 8 * 3600)!
        )

        #expect(scope.entries.count == 2)
        #expect(scope.currencyCode == "USD")
    }

    @Test func scopeSerializesDatesAsLocalCalendarDaysWithoutUTCTimestamps() throws {
        let instant = try #require(ISO8601DateFormatter().date(from: "2026-08-31T16:30:00Z"))
        let entry = LedgerEntry(kind: .expense, amount: 10, categoryID: UUID(), note: "late", occurredAt: instant)
        let scope = AIAnalysisScope(
            currencyCode: "CNY",
            entries: [entry],
            categoryNames: [:],
            timeZone: try #require(TimeZone(identifier: "Asia/Shanghai"))
        )

        let json = try scope.jsonString()
        #expect(json.contains("2026-09-01"))
        #expect(!json.contains("T16:30:00Z"))
        #expect(!json.contains("startDate"))
        #expect(!json.contains("endDate"))
    }
}
