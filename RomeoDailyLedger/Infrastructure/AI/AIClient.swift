import Foundation

protocol AIRequesting: Sendable {
    func parseLedger(text: String, currencyCode: String, configuration: AIConfiguration) async throws -> AILedgerDraftEnvelope
    func testConnection(configuration: AIConfiguration) async throws
    func analyze(question: String, scope: AIAnalysisScope, configuration: AIConfiguration) async throws -> String
    func streamAnalysis(
        question: String,
        scope: AIAnalysisScope,
        configuration: AIConfiguration,
        onComplete: @escaping @Sendable (String) -> Void
    ) -> AsyncThrowingStream<String, Error>
}

extension AIRequesting {
    func streamAnalysis(
        question: String,
        scope: AIAnalysisScope,
        configuration: AIConfiguration
    ) -> AsyncThrowingStream<String, Error> {
        streamAnalysis(question: question, scope: scope, configuration: configuration, onComplete: { _ in })
    }

    func parseLedger(text: String, configuration: AIConfiguration) async throws -> AILedgerDraftEnvelope {
        try await parseLedger(text: text, currencyCode: "USD", configuration: configuration)
    }

    func streamAnalysis(
        question: String,
        scope: AIAnalysisScope,
        configuration: AIConfiguration,
        onComplete: @escaping @Sendable (String) -> Void
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let answer = try await analyze(question: question, scope: scope, configuration: configuration)
                    continuation.yield(answer)
                    onComplete(answer)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
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
                  envelope.entries.allSatisfy({ $0.amount > 0 }) else {
                throw AIClientError.invalidStructuredResult("Invalid entries")
            }
            return AILedgerDraftEnvelope(entries: envelope.entries.map {
                var draft = $0
                draft.date = dateNormalizer.normalize(draft.date)
                draft.currency = currencyCode.uppercased()
                draft.category = draft.category.trimmingCharacters(in: .whitespacesAndNewlines)
                if draft.category.isEmpty { draft.category = "other" }
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
        let request = try makeConnectionTestRequest(configuration: configuration)
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw AIClientError.network("Invalid response") }
            guard (200..<300).contains(http.statusCode) else {
                throw AIClientError.httpStatus(http.statusCode, String(data: data, encoding: .utf8))
            }
            guard try JSONSerialization.jsonObject(with: data) is [String: Any] else {
                throw AIClientError.responseDecoding("Invalid response")
            }
        } catch let error as AIClientError {
            throw error
        } catch let error as URLError {
            throw AIClientError.network(error.localizedDescription)
        } catch {
            throw AIClientError.responseDecoding(error.localizedDescription)
        }
    }

    func makeConnectionTestRequest(configuration: AIConfiguration) throws -> URLRequest {
        try authorizedRequest(
            prompt: "1",
            instructions: "",
            configuration: configuration,
            expectsJSON: false,
            maximumOutputTokens: 1
        )
    }

    func analyze(
        question: String,
        scope: AIAnalysisScope,
        configuration: AIConfiguration
    ) async throws -> String {
        let request = try makeAnalysisRequest(question: question, scope: scope, configuration: configuration)
        return try await send(request, protocolType: configuration.protocolType)
    }

    func streamAnalysis(
        question: String,
        scope: AIAnalysisScope,
        configuration: AIConfiguration,
        onComplete: @escaping @Sendable (String) -> Void
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try makeAnalysisRequest(
                        question: question,
                        scope: scope,
                        configuration: configuration,
                        streams: true
                    )
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw AIClientError.network("Invalid response")
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        var body = Data()
                        for try await byte in bytes { body.append(byte) }
                        throw AIClientError.httpStatus(http.statusCode, String(data: body, encoding: .utf8))
                    }

                    let contentType = http.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
                    if !contentType.contains("text/event-stream") {
                        var body = Data()
                        for try await byte in bytes { body.append(byte) }
                        let answer = try decodeResponse(body, protocolType: configuration.protocolType)
                        continuation.yield(answer)
                        onComplete(answer)
                        continuation.finish()
                        return
                    }

                    let parser = AIStreamEventParser(protocolType: configuration.protocolType)
                    var didYield = false
                    var didComplete = false
                    var accumulated = ""
                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if parser.isTerminal(payload) {
                            onComplete(accumulated)
                            didComplete = true
                            break
                        }
                        guard let delta = try parser.delta(from: payload), !delta.isEmpty else { continue }
                        didYield = true
                        accumulated.append(delta)
                        continuation.yield(delta)
                    }
                    guard didYield else { throw AIClientError.responseDecoding("Missing model content") }
                    if !didComplete { onComplete(accumulated) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func makeAnalysisRequest(
        question: String,
        scope: AIAnalysisScope,
        configuration: AIConfiguration
    ) throws -> URLRequest {
        try makeAnalysisRequest(question: question, scope: scope, configuration: configuration, streams: false)
    }

    func makeAnalysisRequest(
        question: String,
        scope: AIAnalysisScope,
        configuration: AIConfiguration,
        streams: Bool
    ) throws -> URLRequest {
        let prompt = """
        \(question)

        Authorized ledger scope JSON:
        \(try scope.jsonString())
        """
        let styleInstructions = "Respond as a natural conversation, not as a statistics-only list. Be concise, practical, and friendly."
        let instructions = [
            "Analyze only the supplied ledger scope and answer only the user's specific question. Include totals, counts, categories, income versus expenses, or trends only when needed to answer it. Do not mention or analyze anything the user did not ask about. Do not invent missing data.",
            styleInstructions,
            localTimeContext
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        return try authorizedRequest(
            prompt: prompt,
            instructions: instructions,
            configuration: configuration,
            expectsJSON: false,
            streams: streams
        )
    }

    private func authorizedRequest(
        prompt: String,
        instructions: String,
        configuration: AIConfiguration,
        expectsJSON: Bool,
        streams: Bool = false,
        maximumOutputTokens: Int? = nil
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
            let messages = instructions.isEmpty
                ? [ChatMessage(role: "user", content: prompt)]
                : [ChatMessage(role: "system", content: instructions), ChatMessage(role: "user", content: prompt)]
            request.httpBody = try encoder.encode(
                ChatRequest(
                    model: configuration.model,
                    messages: messages,
                    responseFormat: expectsJSON ? .init(type: "json_object") : nil,
                    stream: streams ? true : nil,
                    maxTokens: maximumOutputTokens
                )
            )
        case .responses:
            request.httpBody = try encoder.encode(ResponsesRequest(
                model: configuration.model,
                instructions: instructions.isEmpty ? nil : instructions,
                input: prompt,
                stream: streams ? true : nil,
                maxOutputTokens: maximumOutputTokens
            ))
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

            return try decodeResponse(data, protocolType: protocolType)
        } catch let error as AIClientError {
            throw error
        } catch let error as URLError {
            throw AIClientError.network(error.localizedDescription)
        } catch {
            throw AIClientError.responseDecoding(error.localizedDescription)
        }
    }

    private func decodeResponse(_ data: Data, protocolType: AIProtocol) throws -> String {
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
            if let nested = contents.first(where: { $0.type == "output_text" })?.text { return nested }
            throw AIClientError.responseDecoding("Missing model content")
        }
    }

    private static func isAllowedBaseURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), let host = url.host, !host.isEmpty else { return false }
        if scheme == "https" { return true }
        return scheme == "http" && ["localhost", "127.0.0.1", "::1"].contains(host.lowercased())
    }

    private func ledgerInstructions(currencyCode: String) -> String {
        """
        Return only one JSON object with an entries array. Every entry must contain kind, amount, and date. kind must be income or expense. amount must be positive. date must be YYYY-MM-DD in the user's local calendar. currency should be \(currencyCode.uppercased()); omit it when uncertain. note and category are optional. Use an exact local category name supplied with the prompt; use 其他/Other when uncertain. Never include markdown.
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
    let stream: Bool?
    let maxTokens: Int?

    enum CodingKeys: String, CodingKey {
        case model, messages
        case responseFormat = "response_format"
        case stream
        case maxTokens = "max_tokens"
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
    let instructions: String?
    let input: String
    let stream: Bool?
    let maxOutputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case model, instructions, input, stream
        case maxOutputTokens = "max_output_tokens"
    }
}

struct AIStreamEventParser {
    let protocolType: AIProtocol

    func isTerminal(_ payload: String) -> Bool {
        if payload == "[DONE]" { return true }
        guard let data = payload.data(using: .utf8) else { return false }
        switch protocolType {
        case .chatCompletions:
            return (try? JSONDecoder().decode(ChatStreamEvent.self, from: data).choices.first?.finishReason) != nil
        case .responses:
            return (try? JSONDecoder().decode(ResponsesStreamEvent.self, from: data).type) == "response.completed"
        }
    }

    func delta(from payload: String) throws -> String? {
        guard let data = payload.data(using: .utf8) else { return nil }
        switch protocolType {
        case .chatCompletions:
            return try JSONDecoder().decode(ChatStreamEvent.self, from: data).choices.first?.delta.content
        case .responses:
            let event = try JSONDecoder().decode(ResponsesStreamEvent.self, from: data)
            return event.type == "response.output_text.delta" ? event.delta : nil
        }
    }
}

private struct ChatStreamEvent: Decodable {
    let choices: [Choice]
    struct Choice: Decodable {
        let delta: Delta
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }
    struct Delta: Decodable { let content: String? }
}

private struct ResponsesStreamEvent: Decodable {
    let type: String
    let delta: String?
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
