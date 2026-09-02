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
        #expect(decoded == records.map(normalizedForCurrentTimeZone))
        #expect(String(data: data, encoding: .utf8)?.contains("apiKey") == false)
    }

    @Test func csvRoundTripPreservesFieldsAndQuotesNotes() throws {
        let data = try LedgerTransferCodec.csv.encode(records)
        let decoded = try LedgerTransferCodec.csv.decode([LedgerTransferRecord].self, from: data)
        #expect(decoded == records.map(normalizedForCurrentTimeZone))
        #expect(String(data: data, encoding: .utf8)?.contains("\"工资\"") == false) // UTF-8 is unquoted here
    }

    private func normalizedForCurrentTimeZone(_ record: LedgerTransferRecord) -> LedgerTransferRecord {
        var normalized = record
        normalized.occurredAt = AppDateNormalizer().normalize(record.occurredAt)
        return normalized
    }

    @MainActor
    @Test func exportUsesInjectedLocalDateForJSONAndCSV() async throws {
        let zone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let localMidnight = try #require(ISO8601DateFormatter().date(from: "2024-01-22T16:00:00Z"))
        let entry = LedgerEntry(kind: .expense, amount: 88, categoryID: UUID(), note: "23日", occurredAt: localMidnight)
        let service = LedgerTransferService(
            repository: TransferRepositoryStub(entries: [entry], categories: []),
            timeZoneProvider: FixedAppTimeZoneProvider(timeZone: zone)
        )

        for format in [LedgerTransferService.Format.json, .csv] {
            let data = try await service.exportData(format: format, currencyCode: "CNY")
            let text = try #require(String(data: data, encoding: .utf8))
            #expect(text.contains("2024-01-23"))
            #expect(text.contains("2024-01-22T16:00:00") == false)
        }
    }

    @MainActor
    @Test func importsDateOnlyAndLegacyISOAsInjectedLocalMidnight() throws {
        let zone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let expected = try #require(ISO8601DateFormatter().date(from: "2024-01-22T16:00:00Z"))
        let service = LedgerTransferService(
            repository: TransferRepositoryStub(entries: [], categories: []),
            timeZoneProvider: FixedAppTimeZoneProvider(timeZone: zone)
        )
        let id = "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
        let jsonDateOnly = "[{\"id\":\"\(id)\",\"kind\":\"expense\",\"amount\":\"1.00\",\"occurredAt\":\"2024-01-23\"}]".data(using: .utf8)!
        let legacyJSON = "[{\"id\":\"\(id)\",\"kind\":\"expense\",\"amount\":\"1.00\",\"occurredAt\":\"2024-01-22T16:00:00Z\"}]".data(using: .utf8)!
        let csvDateOnly = "id,kind,amount,currencyCode,categoryID,categoryKey,note,occurredAt\n\(id),expense,1,CNY,,,,2024-01-23".data(using: .utf8)!
        let legacyCSV = "id,kind,amount,currencyCode,categoryID,categoryKey,note,occurredAt\n\(id),expense,1,CNY,,,,2024-01-22T16:00:00Z".data(using: .utf8)!

        #expect(try service.decode(data: jsonDateOnly, format: .json).first?.occurredAt == expected)
        #expect(try service.decode(data: legacyJSON, format: .json).first?.occurredAt == expected)
        #expect(try service.decode(data: csvDateOnly, format: .csv).first?.occurredAt == expected)
        #expect(try service.decode(data: legacyCSV, format: .csv).first?.occurredAt == expected)
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

    @MainActor
    @Test func importingTheSameRecordTwiceCanBeSkipped() async throws {
        let repository = try TestRepository.make()
        try await repository.seedDefaultsIfNeeded()
        let service = LedgerTransferService(repository: repository)
        let record = records[0]

        let firstSaved = try await repository.insert(try await service.draft(for: record))
        let secondAttempt = LedgerTransferCodec.resolveDuplicates(
            [record],
            existingIDs: [firstSaved.id],
            strategy: .skipDuplicates
        )

        #expect(secondAttempt.imported.isEmpty)
        #expect(secondAttempt.skippedCount == 1)
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

        let missingID = "[{\"kind\":\"expense\",\"amount\":\"1.00\",\"occurredAt\":\"2023-11-14T22:13:20Z\"}]".data(using: .utf8)!
        #expect(throws: LedgerTransferError.missingField("id")) {
            _ = try LedgerTransferCodec.json.decode([LedgerTransferRecord].self, from: missingID)
        }

        let malformedCSV = "id,kind,amount,currencyCode,categoryID,categoryKey,note,occurredAt\nAAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA,expense,1,USD,,,\"unfinished,2023-11-14T22:13:20Z".data(using: .utf8)!
        #expect(throws: LedgerTransferError.malformedCSV) {
            _ = try LedgerTransferCodec.csv.decode([LedgerTransferRecord].self, from: malformedCSV)
        }
    }

    @Test func missingCategoryFallsBackToOther() throws {
        let record = records[1]
        #expect(record.resolvedCategoryKey == "other")
    }

    @MainActor
    @Test func importingAnotherCurrencyIsRejectedInsteadOfRelabeled() async throws {
        let repository = try TestRepository.make()
        let service = LedgerTransferService(repository: repository)

        #expect(throws: LedgerTransferError.currencyMismatch(expected: "USD", actual: "CNY")) {
            try service.validateCurrency(records, expected: "USD")
        }
        #expect(throws: Never.self) {
            try service.validateCurrency(records, expected: "CNY")
        }
    }

    @MainActor
    @Test func customCategoryNameSurvivesExportAndImportWhenCategoryExists() async throws {
        let category = RomeoDailyLedger.Category(
            id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            kind: .expense,
            customName: "Travel",
            iconName: "plane",
            colorToken: "other",
            sortOrder: 10
        )
        let entry = LedgerEntry(kind: .expense, amount: 88, categoryID: category.id, note: "Train", occurredAt: date)
        let exportRepository = TransferRepositoryStub(entries: [entry], categories: [category])
        let service = LedgerTransferService(repository: exportRepository)

        let data = try await service.exportData(format: .json, currencyCode: "USD")
        let exported = try service.decode(data: data, format: .json)
        #expect(exported.first?.categoryKey == "Travel")

        var portable = try #require(exported.first)
        portable.categoryID = UUID()
        let fallback = RomeoDailyLedger.Category(
            kind: .expense,
            systemKey: "other",
            iconName: "ellipsis",
            colorToken: "other",
            sortOrder: 0
        )
        let importRepository = TransferRepositoryStub(entries: [], categories: [fallback])
        let importService = LedgerTransferService(repository: importRepository)
        let draft = try await importService.draft(for: portable)
        let importedCategory = try await importRepository.category(id: try #require(draft.categoryID))
        #expect(importedCategory?.customName == "Travel")
    }
}

@MainActor
private final class TransferRepositoryStub: LedgerRepository {
    let storedEntries: [LedgerEntry]
    private(set) var storedCategories: [RomeoDailyLedger.Category]

    init(entries: [LedgerEntry], categories: [RomeoDailyLedger.Category]) {
        storedEntries = entries
        storedCategories = categories
    }

    func seedDefaultsIfNeeded() async throws {}
    func insert(_ draft: LedgerDraft) async throws -> LedgerEntry { throw LedgerTransferError.invalidData }
    func update(id: UUID, draft: LedgerDraft) async throws {}
    func delete(ids: Set<UUID>) async throws {}
    func entries(in interval: DateInterval) async throws -> [LedgerEntry] { storedEntries }
    func categories(kind: EntryKind) async throws -> [RomeoDailyLedger.Category] { storedCategories.filter { $0.kind == kind } }
    func category(id: UUID) async throws -> RomeoDailyLedger.Category? { storedCategories.first { $0.id == id } }
    func ensureCustomCategory(named name: String, kind: EntryKind) async throws -> RomeoDailyLedger.Category {
        if let existing = storedCategories.first(where: { $0.kind == kind && $0.customName == name }) { return existing }
        let category = RomeoDailyLedger.Category(
            kind: kind,
            customName: name,
            iconName: "ellipsis",
            colorToken: "other",
            sortOrder: storedCategories.count
        )
        storedCategories.append(category)
        return category
    }
}
