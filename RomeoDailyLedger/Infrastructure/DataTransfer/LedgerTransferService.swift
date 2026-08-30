import Foundation

/// Coordinates portable records with the repository. UI code can use this
/// service without touching SwiftData or leaking any preferences/secrets.
@MainActor
final class LedgerTransferService {
    enum Format { case json, csv }

    private let repository: any LedgerRepository

    init(repository: any LedgerRepository) { self.repository = repository }

    func exportData(format: Format, currencyCode: String) async throws -> Data {
        let interval = DateInterval(start: .distantPast, end: .distantFuture)
        let entries = try await repository.entries(in: interval)
        var records: [LedgerTransferRecord] = []
        records.reserveCapacity(entries.count)
        for entry in entries {
            let categoryKey = try await repository.category(id: entry.categoryID)?.systemKey
            records.append(LedgerTransferRecord(id: entry.id, kind: entry.kind, amount: entry.amount,
                currencyCode: currencyCode, categoryID: entry.categoryID, categoryKey: categoryKey,
                note: entry.note, occurredAt: entry.occurredAt))
        }
        switch format {
        case .json: return try LedgerTransferCodec.json.encode(records)
        case .csv: return try LedgerTransferCodec.csv.encode(records)
        }
    }

    func decode(data: Data, format: Format) throws -> [LedgerTransferRecord] {
        switch format {
        case .json: return try LedgerTransferCodec.json.decode([LedgerTransferRecord].self, from: data)
        case .csv: return try LedgerTransferCodec.csv.decode([LedgerTransferRecord].self, from: data)
        }
    }

    func preview(data: Data, format: Format) throws -> LedgerTransferPreview {
        try LedgerTransferCodec.preview(decode(data: data, format: format))
    }

    /// Resolves category IDs while retaining the imported category key. A
    /// missing/unknown key is assigned to the seeded "other" category.
    func draft(for record: LedgerTransferRecord) async throws -> LedgerDraft {
        let categories = try await repository.categories(kind: record.kind)
        let wanted = record.categoryKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = categories.first { $0.id == record.categoryID }
            ?? categories.first { $0.systemKey == wanted }
            ?? categories.first { $0.systemKey == "other" }
        return LedgerDraft(kind: record.kind, amountText: NSDecimalNumber(decimal: record.amount).stringValue,
                           categoryID: category?.id, note: record.note, occurredAt: record.occurredAt)
    }

    func resolveDuplicates(data: Data, format: Format, existingIDs: Set<UUID>, strategy: LedgerDuplicateStrategy) throws -> LedgerDuplicateResolution {
        LedgerTransferCodec.resolveDuplicates(try decode(data: data, format: format), existingIDs: existingIDs, strategy: strategy)
    }
}
