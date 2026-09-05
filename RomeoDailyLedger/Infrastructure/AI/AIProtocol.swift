import Foundation

extension CodingUserInfoKey {
    static let aiLocalTimeZone = CodingUserInfoKey(rawValue: "aiLocalTimeZone")!
}

enum AIProtocol: String, Codable, CaseIterable, Identifiable, Sendable {
    case chatCompletions
    case responses

    var id: String { rawValue }
    var displayName: String { self == .chatCompletions ? "Chat Completions" : "Responses" }
}

struct AIConfiguration: Codable, Equatable, Sendable {
    var protocolType: AIProtocol
    var baseURL: URL
    var model: String
    var apiKey: String

    init(
        protocolType: AIProtocol = .chatCompletions,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        model: String = "",
        apiKey: String = ""
    ) {
        self.protocolType = protocolType
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
    }

    private enum CodingKeys: String, CodingKey {
        case protocolType, baseURL, model, apiKey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        protocolType = try container.decode(AIProtocol.self, forKey: .protocolType)
        baseURL = try container.decode(URL.self, forKey: .baseURL)
        model = try container.decode(String.self, forKey: .model)
        apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
    }
}

enum AIModelConnectionStatus: String, Codable, Equatable, Sendable {
    case notConnected
    case connected
    case failed

    var isConnected: Bool { self == .connected }
}

struct AIModelPreset: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var configuration: AIConfiguration
    var connectionStatus: AIModelConnectionStatus
    var lastConnectionCheckAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        configuration: AIConfiguration,
        connectionStatus: AIModelConnectionStatus = .notConnected,
        lastConnectionCheckAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.configuration = configuration
        self.connectionStatus = connectionStatus
        self.lastConnectionCheckAt = lastConnectionCheckAt
    }
}

enum AIModelStatusCache {
    static let maximumAge: TimeInterval = 10 * 60

    static func shouldCheck(
        lastCheckedAt: Date?,
        now: Date = .now,
        maximumAge: TimeInterval = maximumAge
    ) -> Bool {
        guard let lastCheckedAt else { return true }
        return now.timeIntervalSince(lastCheckedAt) >= maximumAge
    }
}

struct AIAnalysisHistoryItem: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var question: String
    var answer: String
    var createdAt: Date = .now
}

struct AILedgerDraft: Codable, Equatable, Sendable {
    var kind: EntryKind
    var amount: Decimal
    var currency: String
    var date: Date
    var note: String
    var category: String

    init(kind: EntryKind, amount: Decimal, currency: String, date: Date, note: String, category: String) {
        self.kind = kind
        self.amount = amount
        self.currency = currency
        self.date = date
        self.note = note
        self.category = category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(EntryKind.self, forKey: .kind)
        amount = try container.decode(Decimal.self, forKey: .amount)
        currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? ""
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "other"
        let value = try container.decode(String.self, forKey: .date)
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = decoder.userInfo[.aiLocalTimeZone] as? TimeZone ?? .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        guard let parsed = formatter.date(from: value) else {
            throw AIClientError.invalidStructuredResult("Invalid date")
        }
        date = parsed
    }

    private enum CodingKeys: String, CodingKey {
        case kind, amount, currency, date, note, category
    }
}

struct AILedgerDraftEnvelope: Codable, Equatable, Sendable {
    var entries: [AILedgerDraft]
}

enum AIClientError: LocalizedError, Equatable, Sendable {
    case apiKeyMissing
    case invalidBaseURL
    case invalidModel
    case ledgerDataPermissionRequired
    case network(String)
    case httpStatus(Int, String?)
    case responseDecoding(String)
    case invalidStructuredResult(String)

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            "API key is missing."
        case .invalidBaseURL:
            "The API base URL is invalid."
        case .invalidModel:
            "The model name is missing."
        case .ledgerDataPermissionRequired:
            "Ledger data access has not been authorized."
        case .network(let message):
            "Network request failed: \(message)"
        case .httpStatus(let code, let message):
            "The AI service returned HTTP \(code).\(message.map { " \($0)" } ?? "")"
        case .responseDecoding(let message):
            "Unable to decode the AI response: \(message)"
        case .invalidStructuredResult(let message):
            "The AI returned an invalid ledger result: \(message)"
        }
    }
}
