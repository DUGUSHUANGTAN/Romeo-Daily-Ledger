import Foundation

struct AIAnalysisScope: Codable, Equatable, Sendable {
    struct Entry: Codable, Equatable, Sendable {
        let kind: EntryKind
        let amount: Decimal
        let category: String
        let note: String
        let occurredAt: String
    }

    let currencyCode: String
    let entries: [Entry]

    init(
        currencyCode: String,
        entries: [LedgerEntry],
        categoryNames: [UUID: String],
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        self.currencyCode = currencyCode
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        self.entries = entries
            .map { entry in
                Entry(
                    kind: entry.kind,
                    amount: entry.amount,
                    category: categoryNames[entry.categoryID] ?? "other",
                    note: entry.note,
                    occurredAt: formatter.string(from: entry.occurredAt)
                )
            }
    }

    func jsonString() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        guard let value = String(data: data, encoding: .utf8) else {
            throw AIClientError.invalidStructuredResult("Unable to encode analysis scope")
        }
        return value
    }
}
