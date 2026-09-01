import Foundation
import Testing
@testable import RomeoDailyLedger

@Suite("AI analysis filtering")
struct AIAnalysisTests {
    @Test(arguments: [(shiftPressed: false, expected: true), (shiftPressed: true, expected: false)])
    func multilineReturnSubmitsUnlessShiftIsPressed(shiftPressed: Bool, expected: Bool) {
        #expect(MultilineSubmitBehavior.shouldSubmit(shiftPressed: shiftPressed) == expected)
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

    @Test func scopeContainsOnlyEntriesInsideTheDisplayedRange() throws {
        let start = Date(timeIntervalSince1970: 0)
        let inside = LedgerEntry(kind: .expense, amount: 10, categoryID: UUID(), note: "inside", occurredAt: start.addingTimeInterval(10))
        let outside = LedgerEntry(kind: .income, amount: 20, categoryID: UUID(), note: "outside", occurredAt: start.addingTimeInterval(200))

        let scope = AIAnalysisScope(
            interval: DateInterval(start: start, duration: 100),
            currencyCode: "USD",
            entries: [inside, outside],
            categoryNames: [inside.categoryID: "food"]
        )

        #expect(scope.entries.count == 1)
        #expect(scope.entries.first?.note == "inside")
        #expect(scope.entries.first?.category == "food")
        #expect(scope.currencyCode == "USD")
    }
}
