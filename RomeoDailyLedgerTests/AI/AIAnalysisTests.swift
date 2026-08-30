import Foundation
import Testing
@testable import RomeoDailyLedger

@Suite("AI analysis filtering")
struct AIAnalysisTests {
    @Test func filtersEntriesToRequestedRange() throws {
        let start = Date(timeIntervalSince1970: 0)
        let inside = LedgerEntry(kind: .expense, amount: 10, categoryID: UUID(), note: "inside", occurredAt: start.addingTimeInterval(10))
        let outside = LedgerEntry(kind: .expense, amount: 20, categoryID: UUID(), note: "outside", occurredAt: start.addingTimeInterval(200))
        let aggregator = InsightsAggregator()
        let entries = aggregator.filteredEntries(entries: [inside, outside], interval: DateInterval(start: start, duration: 100))
        #expect(entries.count == 1)
        #expect(entries.first?.note == "inside")
    }
}
