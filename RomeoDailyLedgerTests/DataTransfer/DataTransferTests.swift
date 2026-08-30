import Foundation
import Testing
@testable import RomeoDailyLedger

@Suite("Data transfer")
struct DataTransferTests {
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    private var records: [LedgerTransferRecord] {
        [
            LedgerTransferRecord(id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!, kind: .income, amount: Decimal(string: "1234.50")!, currencyCode: "CNY", categoryID: nil, categoryKey: "salary", note: "工资", occurredAt: date),
            LedgerTransferRecord(id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!, kind: .expense, amount: Decimal(string: "12.30")!, currencyCode: "CNY", categoryID: nil, categoryKey: nil, note: "午餐", occurredAt: date.addingTimeInterval(3600)),
        ]
    }

    @Test func jsonRoundTripPreservesFields() throws {
        let data = try LedgerTransferCodec.json.encode(records)
        let decoded = try LedgerTransferCodec.json.decode([LedgerTransferRecord].self, from: data)
        #expect(decoded == records)
        #expect(String(data: data, encoding: .utf8)?.contains("apiKey") == false)
    }

    @Test func csvRoundTripPreservesFieldsAndQuotesNotes() throws {
        let data = try LedgerTransferCodec.csv.encode(records)
        let decoded = try LedgerTransferCodec.csv.decode([LedgerTransferRecord].self, from: data)
        #expect(decoded == records)
        #expect(String(data: data, encoding: .utf8)?.contains("\"工资\"") == false) // UTF-8 is unquoted here
    }

    @Test func previewSummarizesRecords() throws {
        let preview = try LedgerTransferCodec.preview(records)
        #expect(preview.totalRecords == 2)
        #expect(preview.incomeCount == 1)
        #expect(preview.expenseCount == 1)
        #expect(preview.dateRange?.start == date)
        #expect(preview.dateRange?.end == date.addingTimeInterval(3600))
        #expect(preview.categoryCounts["salary"] == 1)
        #expect(preview.categoryCounts["other"] == 1)
    }

    @Test func duplicateStrategySkipsOrGeneratesNewID() throws {
        let existing = Set([records[0].id])
        let skipped = LedgerTransferCodec.resolveDuplicates(records, existingIDs: existing, strategy: .skipDuplicates)
        #expect(skipped.imported.count == 1)
        #expect(skipped.skippedCount == 1)

        let kept = LedgerTransferCodec.resolveDuplicates(records, existingIDs: existing, strategy: .keepBoth)
        #expect(kept.imported.count == 2)
        #expect(kept.imported[0].id != records[0].id)
    }

    @Test func invalidAmountAndDateProduceReadableErrors() {
        let badAmount = "[{\"id\":\"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA\",\"kind\":\"expense\",\"amount\":\"wat\",\"occurredAt\":\"2023-11-14T22:13:20Z\"}]".data(using: .utf8)!
        #expect(throws: LedgerTransferError.invalidAmount) {
            _ = try LedgerTransferCodec.json.decode([LedgerTransferRecord].self, from: badAmount)
        }

        let badDate = "[{\"id\":\"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA\",\"kind\":\"expense\",\"amount\":\"1.00\",\"occurredAt\":\"not-a-date\"}]".data(using: .utf8)!
        #expect(throws: LedgerTransferError.invalidDate) {
            _ = try LedgerTransferCodec.json.decode([LedgerTransferRecord].self, from: badDate)
        }
    }

    @Test func missingCategoryFallsBackToOther() throws {
        let record = records[1]
        #expect(record.resolvedCategoryKey == "other")
    }
}
