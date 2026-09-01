import Foundation

protocol AIRequesting: Sendable {
    func parseLedger(text: String, currencyCode: String, configuration: AIConfiguration) async throws -> AILedgerDraftEnvelope
    func testConnection(configuration: AIConfiguration) async throws
    func analyze(question: String, scope: AIAnalysisScope, configuration: AIConfiguration) async throws -> String
}

extension AIRequesting {
    func parseLedger(text: String, configuration: AIConfiguration) async throws -> AILedgerDraftEnvelope {
        try await parseLedger(text: text, currencyCode: "USD", configuration: configuration)
    }
}

struct AIClient: AIRequesting, Sendable {
    private let session: URLSession
    private let dateNormalizer: AppDateNormalizer
    private let timeZone: TimeZone

    init(
        session: URLSession = .shared,
        clock: any AppClock = SystemAppClock(),
        timeZoneProvider: any AppTimeZoneProviding = SystemAppTimeZoneProvider()
    ) {
        self.session = session
        self.dateNormalizer = AppDateNormalizer(clock: clock, timeZoneProvider: timeZoneProvider)
        self.timeZone = timeZoneProvider.timeZone
    }

    func parseLedger(
        text: String,
        currencyCode: String,
        configuration: AIConfiguration
    ) async throws -> AILedgerDraftEnvelope {
        let request = try makeLedgerRequest(text: text, currencyCode: currencyCode, configuration: configuration)
        let content = try await send(request, protocolType: configuration.protocolType)
        let clean = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let decoder = JSONDecoder()
            decoder.userInfo[.aiLocalTimeZone] = timeZone
            let envelope = try decoder.decode(AILedgerDraftEnvelope.self, from: Data(clean.utf8))
            guard !envelope.entries.isEmpty,
                  envelope.entries.allSatisfy({ $0.amount > 0 && !$0.currency.isEmpty && !$0.note.isEmpty }) else {
                throw AIClientError.invalidStructuredResult("Invalid entries")
            }
            return AILedgerDraftEnvelope(entries: envelope.entries.map {
                var draft = $0
                draft.date = dateNormalizer.normalize(draft.date)
                return draft
            })
        } catch let error as AIClientError {
            throw error
        } catch {
            throw AIClientError.responseDecoding(error.localizedDescription)
        }
    }

    func makeLedgerRequest(text: String, configuration: AIConfiguration) throws -> URLRequest {
        try makeLedgerRequest(text: text, currencyCode: "USD", configuration: configuration)
    }

    func makeLedgerRequest(
        text: String,
        currencyCode: String,
        configuration: AIConfiguration
    ) throws -> URLRequest {
        try authorizedRequest(
            prompt: text,
            instructions: ledgerInstructions(currencyCode: currencyCode),
            configuration: configuration,
            expectsJSON: true
        )
    }

    func testConnection(configuration: AIConfiguration) async throws {
        let request = try authorizedRequest(
            prompt: "Connection test",
            instructions: "Reply with OK. \(localTimeContext)",
            configuration: configuration,
            expectsJSON: false
        )
        _ = try await send(request, protocolType: configuration.protocolType)
    }

    func analyze(
        question: String,
        scope: AIAnalysisScope,
        configuration: AIConfiguration
    ) async throws -> String {
        let request = try makeAnalysisRequest(question: question, scope: scope, configuration: configuration)
        return try await send(request, protocolType: configuration.protocolType)
    }

    func makeAnalysisRequest(
        question: String,
        scope: AIAnalysisScope,
        configuration: AIConfiguration
    ) throws -> URLRequest {
        let prompt = """
        \(question)

        Authorized ledger scope JSON:
        \(try scope.jsonString())
        """
        let styleInstructions = "Respond as a natural conversation, not as a statistics-only list. Be concise, practical, and friendly."
        let instructions = [
            "Analyze only the supplied ledger scope. State totals, categories, income versus expenses, and trends when relevant. Do not invent missing data.",
            styleInstructions,
            localTimeContext
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        return try authorizedRequest(
            prompt: prompt,
            instructions: instructions,
            configuration: configuration,
            expectsJSON: false
        )
    }

    private func authorizedRequest(
        prompt: String,
        instructions: String,
        configuration: AIConfiguration,
        expectsJSON: Bool
    ) throws -> URLRequest {
        guard Self.isAllowedBaseURL(configuration.baseURL) else {
            throw AIClientError.invalidBaseURL
        }
        guard !configuration.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIClientError.invalidModel
        }
        let key = configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw AIClientError.apiKeyMissing
        }

        var endpoint = configuration.baseURL
        endpoint.appendPathComponent(configuration.protocolType == .chatCompletions ? "chat/completions" : "responses")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        switch configuration.protocolType {
        case .chatCompletions:
            request.httpBody = try encoder.encode(
                ChatRequest(
                    model: configuration.model,
                    messages: [
                        ChatMessage(role: "system", content: instructions),
                        ChatMessage(role: "user", content: prompt)
                    ],
                    responseFormat: expectsJSON ? .init(type: "json_object") : nil
                )
            )
        case .responses:
            request.httpBody = try encoder.encode(
                ResponsesRequest(model: configuration.model, instructions: instructions, input: prompt)
            )
        }
        return request
    }

    private func send(_ request: URLRequest, protocolType: AIProtocol) async throws -> String {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw AIClientError.network("Invalid response")
            }
            guard (200..<300).contains(http.statusCode) else {
                throw AIClientError.httpStatus(http.statusCode, String(data: data, encoding: .utf8))
            }

            switch protocolType {
            case .chatCompletions:
                guard let content = try JSONDecoder().decode(ChatResponse.self, from: data).choices.first?.message.content else {
                    throw AIClientError.responseDecoding("Missing model content")
                }
                return content
            case .responses:
                let response = try JSONDecoder().decode(ResponsesResponse.self, from: data)
                if let outputText = response.outputText { return outputText }
                let contents = (response.output ?? []).compactMap(\.content).flatMap { $0 }
                if let nested = contents.first(where: { $0.type == "output_text" })?.text {
                    return nested
                }
                throw AIClientError.responseDecoding("Missing model content")
            }
        } catch let error as AIClientError {
            throw error
        } catch let error as URLError {
            throw AIClientError.network(error.localizedDescription)
        } catch {
            throw AIClientError.responseDecoding(error.localizedDescription)
        }
    }

    private static func isAllowedBaseURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), let host = url.host, !host.isEmpty else { return false }
        if scheme == "https" { return true }
        return scheme == "http" && ["localhost", "127.0.0.1", "::1"].contains(host.lowercased())
    }

    private func ledgerInstructions(currencyCode: String) -> String {
        """
        Return only one JSON object with an entries array. Every entry must contain kind, amount, currency, date, note, and category. kind must be income or expense. currency must be \(currencyCode.uppercased()). date must be YYYY-MM-DD in the user's local calendar. category must be one of clothing, food, housing, transport, entertainment, salary, bonus, investment, refund, or other. Use other when uncertain. Never include markdown.
        Current local date: \(dateNormalizer.localDateString(for: dateNormalizer.today)). Current time zone: \(dateNormalizer.timeZoneIdentifier). If no date is provided, use today. Resolve relative expressions such as today/今天, yesterday/昨天, and this month/本月 from this local date and time zone.
        """
    }

    private var localTimeContext: String {
        "Current local date: \(dateNormalizer.localDateString(for: dateNormalizer.today)). Current time zone: \(dateNormalizer.timeZoneIdentifier). Treat today, yesterday, and this month relative to this date; if no date is provided, use today."
    }
}

private struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let responseFormat: ResponseFormat?

    enum CodingKeys: String, CodingKey {
        case model, messages
        case responseFormat = "response_format"
    }

    struct ResponseFormat: Encodable { let type: String }
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ChatResponse: Decodable {
    let choices: [Choice]
    struct Choice: Decodable { let message: ChatMessage }
}

private struct ResponsesRequest: Encodable {
    let model: String
    let instructions: String
    let input: String
}

private struct ResponsesResponse: Decodable {
    let outputText: String?
    let output: [Output]?

    enum CodingKeys: String, CodingKey {
        case outputText = "output_text"
        case output
    }

    struct Output: Decodable {
        let content: [Content]?
    }

    struct Content: Decodable {
        let type: String
        let text: String?
    }
}
