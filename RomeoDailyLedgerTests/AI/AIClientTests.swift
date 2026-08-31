import Foundation
import Testing
@testable import RomeoDailyLedger

@Suite("AI protocol client", .serialized)
struct AIClientTests {
    @Test func requestUsesConfigurationKeyAndInjectedLocalDateContext() throws {
        let instant = try #require(ISO8601DateFormatter().date(from: "2026-08-31T16:30:00Z"))
        let zone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let client = AIClient(
            session: Self.session(data: Data(), status: 200),
            clock: FixedAppClock(now: instant),
            timeZoneProvider: FixedAppTimeZoneProvider(timeZone: zone)
        )
        let request = try client.makeLedgerRequest(
            text: "昨天午餐 25 元",
            currencyCode: "CNY",
            configuration: AIConfiguration(baseURL: URL(string: "https://example.test/v1")!, model: "ledger", apiKey: "visible-key")
        )
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer visible-key")
        let body = String(data: try #require(request.httpBody), encoding: .utf8) ?? ""
        #expect(body.contains("2026-09-01"))
        #expect(body.contains("Asia\\/Shanghai"))
        #expect(body.contains("昨天"))
        #expect(!body.contains("2025"))
    }
    @Test func parsedDateUsesInjectedTimeZoneLocalMidnight() async throws {
        let body = Data(#"{"choices":[{"message":{"role":"assistant","content":"{\"entries\":[{\"kind\":\"expense\",\"amount\":25,\"currency\":\"CNY\",\"date\":\"2024-03-01\",\"note\":\"Lunch\",\"category\":\"food\"}]}"}}]}"#.utf8)
        let zone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let client = AIClient(session: Self.session(data: body, status: 200), timeZoneProvider: FixedAppTimeZoneProvider(timeZone: zone))
        let result = try await client.parseLedger(text: "午餐", currencyCode: "CNY", configuration: AIConfiguration(baseURL: URL(string: "https://example.test/v1")!, model: "ledger", apiKey: "key"))
        #expect(result.entries.first?.date == ISO8601DateFormatter().date(from: "2024-03-01T08:00:00Z"))
    }
    @Test func chatCompletionsResponseProducesDraft() async throws {
        let body = Data(#"{"choices":[{"message":{"role":"assistant","content":"{\"entries\":[{\"kind\":\"expense\",\"amount\":25,\"currency\":\"USD\",\"date\":\"2026-08-30\",\"note\":\"Lunch\",\"category\":\"food\"}]}"}}]}"#.utf8)
        let client = AIClient(session: Self.session(data: body, status: 200))
        let result = try await client.parseLedger(text: "Lunch $25", configuration: AIConfiguration(baseURL: URL(string: "https://example.test/v1")!, model: "ledger", apiKey: "key"))
        #expect(result.entries.first?.amount == Decimal(25))
        #expect(result.entries.first?.kind == .expense)
    }

    @Test func responsesProtocolReadsOutputText() async throws {
        let body = try JSONSerialization.data(withJSONObject: ["output_text": "{\"entries\":[{\"kind\":\"income\",\"amount\":3000,\"currency\":\"USD\",\"date\":\"2026-08-30\",\"note\":\"Salary\",\"category\":\"salary\"}]}"], options: [])
        let client = AIClient(session: Self.session(data: body, status: 200))
        let result = try await client.parseLedger(text: "salary", configuration: AIConfiguration(protocolType: .responses, baseURL: URL(string: "https://example.test/v1")!, model: "ledger", apiKey: "key"))
        #expect(result.entries.first?.kind == .income)
    }

    @Test func responsesProtocolReadsStandardNestedOutput() async throws {
        let body = Data(#"{"output":[{"type":"message","content":[{"type":"output_text","text":"{\"entries\":[{\"kind\":\"expense\",\"amount\":18,\"currency\":\"USD\",\"date\":\"2026-08-30\",\"note\":\"Dinner\",\"category\":\"food\"}]}"}]}]}"#.utf8)
        let client = AIClient(session: Self.session(data: body, status: 200))

        let result = try await client.parseLedger(
            text: "Dinner $18",
            configuration: AIConfiguration(protocolType: .responses, baseURL: URL(string: "https://example.test/v1")!, model: "ledger", apiKey: "key")
        )

        #expect(result.entries.first?.note == "Dinner")
    }

    @Test func responsesProtocolSkipsReasoningItemsWithoutContent() async throws {
        let body = Data(#"{"output":[{"type":"reasoning"},{"type":"message","content":[{"type":"output_text","text":"{\"entries\":[{\"kind\":\"expense\",\"amount\":9,\"currency\":\"USD\",\"date\":\"2026-08-30\",\"note\":\"Coffee\",\"category\":\"food\"}]}"}]}]}"#.utf8)
        let client = AIClient(session: Self.session(data: body, status: 200))

        let result = try await client.parseLedger(
            text: "Coffee $9",
            configuration: AIConfiguration(protocolType: .responses, baseURL: URL(string: "https://example.test/v1")!, model: "ledger", apiKey: "key")
        )

        #expect(result.entries.first?.note == "Coffee")
    }

    @Test func ledgerRequestIncludesStructuredOutputInstructions() async throws {
        let body = Data(#"{"choices":[{"message":{"role":"assistant","content":"{\"entries\":[{\"kind\":\"expense\",\"amount\":25,\"currency\":\"USD\",\"date\":\"2026-08-30\",\"note\":\"Lunch\",\"category\":\"food\"}]}"}}]}"#.utf8)
        let client = AIClient(session: Self.session(data: body, status: 200))

        let request = try client.makeLedgerRequest(
            text: "Lunch $25",
            configuration: AIConfiguration(baseURL: URL(string: "https://example.test/v1")!, model: "ledger", apiKey: "key")
        )

        let requestBody = String(data: try #require(request.httpBody), encoding: .utf8) ?? ""
        #expect(requestBody.contains("entries"))
        #expect(requestBody.contains("category"))
    }

    @Test func ledgerRequestUsesTheCurrentLedgerCurrency() throws {
        let client = AIClient(session: Self.session(data: Data(), status: 200))

        let request = try client.makeLedgerRequest(
            text: "午餐 25 元",
            currencyCode: "CNY",
            configuration: AIConfiguration(baseURL: URL(string: "https://example.test/v1")!, model: "ledger", apiKey: "key")
        )

        let requestBody = String(data: try #require(request.httpBody), encoding: .utf8) ?? ""
        #expect(requestBody.contains("CNY"))
    }

    @Test func connectionTestPerformsARealProtocolRequest() async throws {
        let body = Data(#"{"choices":[{"message":{"role":"assistant","content":"OK"}}]}"#.utf8)
        let client = AIClient(session: Self.session(data: body, status: 200))

        try await client.testConnection(
            configuration: AIConfiguration(baseURL: URL(string: "https://example.test/v1")!, model: "ledger", apiKey: "key")
        )

        #expect(StubURLProtocol.lastRequest?.url?.path == "/v1/chat/completions")
    }

    @Test func analysisSendsOnlyTheAuthorizedScope() async throws {
        let body = Data(#"{"choices":[{"message":{"role":"assistant","content":"Food was the largest category."}}]}"#.utf8)
        let client = AIClient(session: Self.session(data: body, status: 200))
        let scope = AIAnalysisScope(
            interval: DateInterval(start: Date(timeIntervalSince1970: 0), duration: 100),
            currencyCode: "USD",
            entries: [
                LedgerEntry(kind: .expense, amount: 12, categoryID: UUID(), note: "Lunch", occurredAt: Date(timeIntervalSince1970: 10))
            ],
            categoryNames: [:]
        )

        let answer = try await client.analyze(
            question: "Largest category?",
            scope: scope,
            configuration: AIConfiguration(baseURL: URL(string: "https://example.test/v1")!, model: "ledger", allowsLedgerData: true, apiKey: "key")
        )

        #expect(answer == "Food was the largest category.")
    }

    @Test func analysisRequiresExplicitLedgerPermission() async {
        let client = AIClient(session: Self.session(data: Data(), status: 200))
        let scope = AIAnalysisScope(interval: DateInterval(start: .now, duration: 1), currencyCode: "USD", entries: [], categoryNames: [:])

        await #expect(throws: AIClientError.ledgerDataPermissionRequired) {
            try await client.analyze(
                question: "Summary",
                scope: scope,
                configuration: AIConfiguration(baseURL: URL(string: "https://example.test/v1")!, model: "ledger", apiKey: "key")
            )
        }
    }

    @Test func insecureRemoteBaseURLIsRejectedBeforeSendingKey() async {
        let client = AIClient(session: Self.session(data: Data(), status: 200))

        await #expect(throws: AIClientError.invalidBaseURL) {
            try await client.parseLedger(
                text: "Lunch",
                configuration: AIConfiguration(baseURL: URL(string: "http://example.test/v1")!, model: "ledger", apiKey: "key")
            )
        }
    }

    @Test func transportFailureIsReportedAsNetworkError() async {
        let client = AIClient(session: Self.failingSession())

        do {
            try await client.parseLedger(
                text: "Lunch",
                configuration: AIConfiguration(baseURL: URL(string: "https://example.test/v1")!, model: "ledger", apiKey: "key")
            )
            Issue.record("Expected a network error")
        } catch AIClientError.network {
            // Expected. The underlying localized description varies by system language.
        } catch {
            Issue.record("Expected network error, received \(error)")
        }
    }

    @Test func missingKeyIsReportedWithoutNetwork() async {
        let client = AIClient()
        await #expect(throws: AIClientError.apiKeyMissing) {
            try await client.parseLedger(text: "Lunch", configuration: AIConfiguration(model: "ledger"))
        }
    }

    private static func session(data: Data, status: Int) -> URLSession {
        StubURLProtocol.data = data
        StubURLProtocol.status = status
        StubURLProtocol.failure = nil
        StubURLProtocol.lastRequest = nil
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private static func failingSession() -> URLSession {
        StubURLProtocol.failure = URLError(.notConnectedToInternet)
        StubURLProtocol.lastRequest = nil
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var data = Data()
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var failure: Error?
    nonisolated(unsafe) static var lastRequest: URLRequest?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var captured = request
        if captured.httpBody == nil, let stream = captured.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var data = Data()
            let bufferSize = 4_096
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }
            while stream.hasBytesAvailable {
                let count = stream.read(buffer, maxLength: bufferSize)
                guard count > 0 else { break }
                data.append(buffer, count: count)
            }
            captured.httpBody = data
            captured.httpBodyStream = nil
        }
        Self.lastRequest = captured
        if let failure = Self.failure {
            client?.urlProtocol(self, didFailWithError: failure)
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
