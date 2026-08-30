import Foundation

/// A portable representation of a ledger entry. It deliberately contains no
/// preferences, credentials, or Keychain values.
struct LedgerTransferRecord: Codable, Equatable, Sendable {
    var id: UUID
    var kind: EntryKind
    var amount: Decimal
    var currencyCode: String
    var categoryID: UUID?
    var categoryKey: String?
    var note: String
    var occurredAt: Date

    init(
        id: UUID,
        kind: EntryKind,
        amount: Decimal,
        currencyCode: String = "USD",
        categoryID: UUID? = nil,
        categoryKey: String? = nil,
        note: String = "",
        occurredAt: Date
    ) {
        self.id = id; self.kind = kind; self.amount = amount
        self.currencyCode = currencyCode; self.categoryID = categoryID
        self.categoryKey = categoryKey; self.note = note; self.occurredAt = occurredAt
    }

    var resolvedCategoryKey: String {
        let value = categoryKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "other" : value
    }

    private enum CodingKeys: String, CodingKey { case id, kind, amount, currencyCode, categoryID, categoryKey, note, occurredAt }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = try c.decodeIfPresent(UUID.self, forKey: .id) else { throw LedgerTransferError.missingField("id") }
        guard c.contains(.kind) else { throw LedgerTransferError.missingField("kind") }
        guard let kind = try? c.decode(EntryKind.self, forKey: .kind) else { throw LedgerTransferError.invalidKind }
        guard c.contains(.amount) else { throw LedgerTransferError.missingField("amount") }
        let amount: Decimal
        if let text = try? c.decode(String.self, forKey: .amount) {
            guard let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")), value > 0 else { throw LedgerTransferError.invalidAmount }
            amount = value
        } else if let value = try? c.decode(Decimal.self, forKey: .amount), value > 0 {
            amount = value
        } else { throw LedgerTransferError.invalidAmount }
        guard c.contains(.occurredAt) else { throw LedgerTransferError.missingField("occurredAt") }
        guard let dateText = try c.decodeIfPresent(String.self, forKey: .occurredAt),
              let date = Self.parseDate(dateText) else { throw LedgerTransferError.invalidDate }
        self.init(id: id, kind: kind, amount: amount,
                  currencyCode: (try c.decodeIfPresent(String.self, forKey: .currencyCode) ?? "USD"),
                  categoryID: try c.decodeIfPresent(UUID.self, forKey: .categoryID),
                  categoryKey: try c.decodeIfPresent(String.self, forKey: .categoryKey),
                  note: try c.decodeIfPresent(String.self, forKey: .note) ?? "", occurredAt: date)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(kind, forKey: .kind)
        // String encoding avoids loss of Decimal precision in JSON/CSV readers.
        try c.encode(NSDecimalNumber(decimal: amount).stringValue, forKey: .amount)
        try c.encode(currencyCode, forKey: .currencyCode)
        try c.encodeIfPresent(categoryID, forKey: .categoryID)
        try c.encodeIfPresent(categoryKey, forKey: .categoryKey)
        try c.encode(note, forKey: .note)
        try c.encode(Self.formatDate(occurredAt), forKey: .occurredAt)
    }

    private static func parseDate(_ text: String) -> Date? {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let p = ISO8601DateFormatter(); p.formatOptions = [.withInternetDateTime]
        return f.date(from: text) ?? p.date(from: text)
    }

    private static func formatDate(_ date: Date) -> String {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }
}

enum LedgerTransferError: Error, Equatable, LocalizedError {
    case invalidData
    case missingField(String)
    case invalidAmount
    case invalidDate
    case invalidKind
    case malformedCSV
    case currencyMismatch(expected: String, actual: String)

    var errorDescription: String? {
        switch self {
        case .invalidData: return "The file is not a valid ledger export."
        case .missingField(let field): return "Required field '\(field)' is missing."
        case .invalidAmount: return "Amount must be a positive number."
        case .invalidDate: return "Date is invalid or not in ISO-8601 format."
        case .invalidKind: return "Type must be income or expense."
        case .malformedCSV: return "The CSV file is malformed or has an invalid header."
        case .currencyMismatch(let expected, let actual):
            return "The file uses \(actual), but this ledger uses \(expected)."
        }
    }
}

struct LedgerTransferPreview: Equatable, Sendable {
    let totalRecords: Int
    let incomeCount: Int
    let expenseCount: Int
    let dateRange: DateInterval?
    let categoryCounts: [String: Int]
}

enum LedgerDuplicateStrategy: Sendable { case skipDuplicates, keepBoth }

struct LedgerDuplicateResolution: Sendable {
    let imported: [LedgerTransferRecord]
    let skippedCount: Int
}

enum LedgerTransferCodec {
    static let json = JSONCodec()
    static let csv = CSVCodec()

    static func preview(_ records: [LedgerTransferRecord]) throws -> LedgerTransferPreview {
        guard records.allSatisfy({ $0.amount > 0 }) else { throw LedgerTransferError.invalidAmount }
        let dates = records.map(\.occurredAt)
        let interval = dates.min().flatMap { min in dates.max().map { DateInterval(start: min, end: $0) } }
        let categoryCounts = Dictionary(grouping: records, by: \.resolvedCategoryKey).mapValues(\.count)
        return LedgerTransferPreview(totalRecords: records.count,
                                     incomeCount: records.count(where: { $0.kind == .income }),
                                     expenseCount: records.count(where: { $0.kind == .expense }),
                                     dateRange: interval, categoryCounts: categoryCounts)
    }

    static func resolveDuplicates(_ records: [LedgerTransferRecord], existingIDs: Set<UUID>, strategy: LedgerDuplicateStrategy) -> LedgerDuplicateResolution {
        var seen = existingIDs
        var imported: [LedgerTransferRecord] = []; var skipped = 0
        for var record in records {
            if seen.contains(record.id) {
                switch strategy {
                case .skipDuplicates: skipped += 1; continue
                case .keepBoth: record.id = UUID()
                }
            }
            seen.insert(record.id); imported.append(record)
        }
        return LedgerDuplicateResolution(imported: imported, skippedCount: skipped)
    }
}

struct JSONCodec {
    func encode(_ records: [LedgerTransferRecord]) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(records)
    }
    func decode(_ type: [LedgerTransferRecord].Type, from data: Data) throws -> [LedgerTransferRecord] {
        do { return try JSONDecoder().decode(type, from: data) }
        catch let error as LedgerTransferError { throw error }
        catch { throw LedgerTransferError.invalidData }
    }
}

struct CSVCodec {
    private let header = ["id", "kind", "amount", "currencyCode", "categoryID", "categoryKey", "note", "occurredAt"]

    func encode(_ records: [LedgerTransferRecord]) throws -> Data {
        var lines = [header.joined(separator: ",")]
        for record in records {
            lines.append([
                record.id.uuidString, record.kind.rawValue,
                NSDecimalNumber(decimal: record.amount).stringValue,
                record.currencyCode, record.categoryID?.uuidString ?? "",
                record.categoryKey ?? "", record.note,
                ISO8601DateFormatter.transferString(from: record.occurredAt)
            ].map(quote).joined(separator: ","))
        }
        return lines.joined(separator: "\n").data(using: .utf8)!
    }

    func decode(_ type: [LedgerTransferRecord].Type, from data: Data) throws -> [LedgerTransferRecord] {
        guard let text = String(data: data, encoding: .utf8) else { throw LedgerTransferError.invalidData }
        let rows = try parse(text)
        guard let first = rows.first, header.allSatisfy({ first.contains($0) }) else { throw LedgerTransferError.malformedCSV }
        let indexes = Dictionary(uniqueKeysWithValues: first.enumerated().map { ($1, $0) })
        var result: [LedgerTransferRecord] = []
        for row in rows.dropFirst() where !row.allSatisfy(\.isEmpty) {
            func value(_ key: String) -> String? { indexes[key].flatMap { $0 < row.count ? row[$0] : nil } }
            guard let idText = value("id"), let id = UUID(uuidString: idText) else { throw LedgerTransferError.missingField("id") }
            guard let kindText = value("kind"), let kind = EntryKind(rawValue: kindText) else { throw LedgerTransferError.invalidKind }
            guard let amountText = value("amount"),
                  let amount = Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX")),
                  amount > 0 else { throw LedgerTransferError.invalidAmount }
            guard let dateText = value("occurredAt"), let date = ISO8601DateFormatter.parseTransferDate(dateText) else { throw LedgerTransferError.invalidDate }
            result.append(LedgerTransferRecord(id: id, kind: kind, amount: amount,
                currencyCode: value("currencyCode") ?? "USD", categoryID: value("categoryID").flatMap(UUID.init(uuidString:)),
                categoryKey: value("categoryKey").flatMap { $0.isEmpty ? nil : $0 }, note: value("note") ?? "", occurredAt: date))
        }
        return result
    }

    private func quote(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private func parse(_ text: String) throws -> [[String]] {
        var rows: [[String]] = [[]]; var field = ""; var quoted = false; var i = text.startIndex
        while i < text.endIndex {
            let ch = text[i]
            if ch == "\"" { if quoted && text.index(after: i) < text.endIndex && text[text.index(after: i)] == "\"" { field.append("\""); i = text.index(after: i) } else { quoted.toggle() } }
            else if ch == "," && !quoted { rows[rows.count - 1].append(field); field = "" }
            else if (ch == "\n" || ch == "\r") && !quoted { rows[rows.count - 1].append(field); field = ""; if ch == "\r", text.index(after: i) < text.endIndex, text[text.index(after: i)] == "\n" { i = text.index(after: i) }; rows.append([]) }
            else { field.append(ch) }
            i = text.index(after: i)
        }
        guard !quoted else { throw LedgerTransferError.malformedCSV }
        if !field.isEmpty || rows.last?.isEmpty == false { rows[rows.count - 1].append(field) }
        return rows.filter { !$0.isEmpty }
    }
}

private extension ISO8601DateFormatter {
    static func transferString(from date: Date) -> String {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f.string(from: date)
    }
    static func parseTransferDate(_ text: String) -> Date? {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let p = ISO8601DateFormatter(); p.formatOptions = [.withInternetDateTime]
        return f.date(from: text) ?? p.date(from: text)
    }
}
