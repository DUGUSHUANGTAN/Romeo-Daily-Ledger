import Foundation

/// Coordinates portable records with the repository. UI code can use this
/// service without touching SwiftData or leaking any preferences/secrets.
@MainActor
final class LedgerTransferService {
    enum Format { case json, csv }

    private let repository: any LedgerRepository
    private let dateNormalizer: AppDateNormalizer
    private let timeZoneProvider: any AppTimeZoneProviding

    init(
        repository: any LedgerRepository,
        clock: any AppClock = SystemAppClock(),
        timeZoneProvider: any AppTimeZoneProviding = SystemAppTimeZoneProvider()
    ) {
        self.repository = repository
        self.timeZoneProvider = timeZoneProvider
        self.dateNormalizer = AppDateNormalizer(clock: clock, timeZoneProvider: timeZoneProvider)
    }

    func exportData(format: Format, currencyCode: String) async throws -> Data {
        let interval = DateInterval(start: .distantPast, end: .distantFuture)
        let entries = try await repository.entries(in: interval)
        var records: [LedgerTransferRecord] = []
        records.reserveCapacity(entries.count)
        for entry in entries {
            let category = try await repository.category(id: entry.categoryID)
            let categoryKey = category?.systemKey ?? category?.customName
            records.append(LedgerTransferRecord(id: entry.id, kind: entry.kind, amount: entry.amount,
                currencyCode: currencyCode, categoryID: entry.categoryID, categoryKey: categoryKey,
                note: entry.note, occurredAt: entry.occurredAt))
        }
        switch format {
        case .json: return try JSONCodec(timeZoneProvider: timeZoneProvider).encode(records)
        case .csv: return try CSVCodec(timeZoneProvider: timeZoneProvider).encode(records)
        }
    }

    func decode(data: Data, format: Format) throws -> [LedgerTransferRecord] {
        switch format {
        case .json: return try JSONCodec(timeZoneProvider: timeZoneProvider).decode([LedgerTransferRecord].self, from: data)
        case .csv: return try CSVCodec(timeZoneProvider: timeZoneProvider).decode([LedgerTransferRecord].self, from: data)
        }
    }

    func preview(data: Data, format: Format) throws -> LedgerTransferPreview {
        try LedgerTransferCodec.preview(decode(data: data, format: format))
    }

    func validateCurrency(_ records: [LedgerTransferRecord], expected: String) throws {
        let normalizedExpected = expected.uppercased()
        if let actual = records.lazy.map({ $0.currencyCode.uppercased() }).first(where: { $0 != normalizedExpected }) {
            throw LedgerTransferError.currencyMismatch(expected: normalizedExpected, actual: actual)
        }
    }

    /// Resolves category IDs while retaining the imported category key. A
    /// missing/unknown key is assigned to the seeded "other" category.
    func draft(for record: LedgerTransferRecord) async throws -> LedgerDraft {
        let categories = try await repository.categories(kind: record.kind)
        let wanted = record.categoryKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        var category = categories.first { $0.id == record.categoryID }
            ?? categories.first { $0.systemKey?.caseInsensitiveCompare(wanted ?? "") == .orderedSame }
            ?? categories.first { $0.customName?.caseInsensitiveCompare(wanted ?? "") == .orderedSame }
        if category == nil,
           let wanted,
           !wanted.isEmpty,
           wanted.caseInsensitiveCompare("other") != .orderedSame {
            category = try await repository.ensureCustomCategory(named: wanted, kind: record.kind)
        }
        category = category ?? categories.first { $0.systemKey == "other" }
        return LedgerDraft(id: record.id, kind: record.kind, amountText: NSDecimalNumber(decimal: record.amount).stringValue,
                           categoryID: category?.id, note: record.note, occurredAt: dateNormalizer.normalize(record.occurredAt))
    }

    func resolveDuplicates(data: Data, format: Format, existingIDs: Set<UUID>, strategy: LedgerDuplicateStrategy) throws -> LedgerDuplicateResolution {
        LedgerTransferCodec.resolveDuplicates(try decode(data: data, format: format), existingIDs: existingIDs, strategy: strategy)
    }
}
