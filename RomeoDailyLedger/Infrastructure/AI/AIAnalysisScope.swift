import Foundation

struct AIAnalysisScope: Codable, Equatable, Sendable {
    struct Entry: Codable, Equatable, Sendable {
        let kind: EntryKind
        let amount: Decimal
        let category: String
        let note: String
        let occurredAt: Date
    }

    let startDate: Date
    let endDate: Date
    let currencyCode: String
    let entries: [Entry]

    init(
        interval: DateInterval,
        currencyCode: String,
        entries: [LedgerEntry],
        categoryNames: [UUID: String]
    ) {
        startDate = interval.start
        endDate = interval.end
        self.currencyCode = currencyCode
        self.entries = entries
            .filter { interval.contains($0.occurredAt) && $0.occurredAt < interval.end }
            .map { entry in
                Entry(
                    kind: entry.kind,
                    amount: entry.amount,
                    category: categoryNames[entry.categoryID] ?? "other",
                    note: entry.note,
                    occurredAt: entry.occurredAt
                )
            }
    }

    func jsonString() throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        guard let value = String(data: data, encoding: .utf8) else {
            throw AIClientError.invalidStructuredResult("Unable to encode analysis scope")
        }
        return value
    }
}
