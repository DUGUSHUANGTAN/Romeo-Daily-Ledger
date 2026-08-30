import Foundation
import Testing
@testable import RomeoDailyLedger

@Suite("AI protocol client", .serialized)
struct AIClientTests {
    @Test func chatCompletionsResponseProducesDraft() async throws {
        let body = Data(#"{"choices":[{"message":{"role":"assistant","content":"{\"entries\":[{\"kind\":\"expense\",\"amount\":25,\"currency\":\"USD\",\"date\":\"2026-08-30\",\"note\":\"Lunch\",\"category\":\"food\"}]}"}}]}"#.utf8)
        let client = AIClient(session: Self.session(data: body, status: 200), keyStore: StubKeyStore(value: "key"))
        let result = try await client.parseLedger(text: "Lunch $25", configuration: AIConfiguration(baseURL: URL(string: "https://example.test/v1")!, model: "ledger"))
        #expect(result.entries.first?.amount == Decimal(25))
        #expect(result.entries.first?.kind == .expense)
    }

    @Test func responsesProtocolReadsOutputText() async throws {
        let body = try JSONSerialization.data(withJSONObject: ["output_text": "{\"entries\":[{\"kind\":\"income\",\"amount\":3000,\"currency\":\"USD\",\"date\":\"2026-08-30\",\"note\":\"Salary\",\"category\":\"salary\"}]}"], options: [])
        let client = AIClient(session: Self.session(data: body, status: 200), keyStore: StubKeyStore(value: "key"))
        let result = try await client.parseLedger(text: "salary", configuration: AIConfiguration(protocolType: .responses, baseURL: URL(string: "https://example.test/v1")!, model: "ledger"))
        #expect(result.entries.first?.kind == .income)
    }

    @Test func responsesProtocolReadsStandardNestedOutput() async throws {
        let body = Data(#"{"output":[{"type":"message","content":[{"type":"output_text","text":"{\"entries\":[{\"kind\":\"expense\",\"amount\":18,\"currency\":\"USD\",\"date\":\"2026-08-30\",\"note\":\"Dinner\",\"category\":\"food\"}]}"}]}]}"#.utf8)
        let client = AIClient(session: Self.session(data: body, status: 200), keyStore: StubKeyStore(value: "key"))

        let result = try await client.parseLedger(
            text: "Dinner $18",
            configuration: AIConfiguration(protocolType: .responses, baseURL: URL(string: "https://example.test/v1")!, model: "ledger")
        )

        #expect(result.entries.first?.note == "Dinner")
    }

    @Test func responsesProtocolSkipsReasoningItemsWithoutContent() async throws {
        let body = Data(#"{"output":[{"type":"reasoning"},{"type":"message","content":[{"type":"output_text","text":"{\"entries\":[{\"kind\":\"expense\",\"amount\":9,\"currency\":\"USD\",\"date\":\"2026-08-30\",\"note\":\"Coffee\",\"category\":\"food\"}]}"}]}]}"#.utf8)
        let client = AIClient(session: Self.session(data: body, status: 200), keyStore: StubKeyStore(value: "key"))

        let result = try await client.parseLedger(
            text: "Coffee $9",
            configuration: AIConfiguration(protocolType: .responses, baseURL: URL(string: "https://example.test/v1")!, model: "ledger")
        )

        #expect(result.entries.first?.note == "Coffee")
    }

    @Test func ledgerRequestIncludesStructuredOutputInstructions() async throws {
        let body = Data(#"{"choices":[{"message":{"role":"assistant","content":"{\"entries\":[{\"kind\":\"expense\",\"amount\":25,\"currency\":\"USD\",\"date\":\"2026-08-30\",\"note\":\"Lunch\",\"category\":\"food\"}]}"}}]}"#.utf8)
        let client = AIClient(session: Self.session(data: body, status: 200), keyStore: StubKeyStore(value: "key"))

        let request = try client.makeLedgerRequest(
            text: "Lunch $25",
            configuration: AIConfiguration(baseURL: URL(string: "https://example.test/v1")!, model: "ledger")
        )

        let requestBody = String(data: try #require(request.httpBody), encoding: .utf8) ?? ""
        #expect(requestBody.contains("entries"))
        #expect(requestBody.contains("category"))
    }

    @Test func ledgerRequestUsesTheCurrentLedgerCurrency() throws {
        let client = AIClient(session: Self.session(data: Data(), status: 200), keyStore: StubKeyStore(value: "key"))

        let request = try client.makeLedgerRequest(
            text: "午餐 25 元",
            currencyCode: "CNY",
            configuration: AIConfiguration(baseURL: URL(string: "https://example.test/v1")!, model: "ledger")
        )

        let requestBody = String(data: try #require(request.httpBody), encoding: .utf8) ?? ""
        #expect(requestBody.contains("CNY"))
    }

    @Test func connectionTestPerformsARealProtocolRequest() async throws {
        let body = Data(#"{"choices":[{"message":{"role":"assistant","content":"OK"}}]}"#.utf8)
        let client = AIClient(session: Self.session(data: body, status: 200), keyStore: StubKeyStore(value: "key"))

        try await client.testConnection(
            configuration: AIConfiguration(baseURL: URL(string: "https://example.test/v1")!, model: "ledger")
        )

        #expect(StubURLProtocol.lastRequest?.url?.path == "/v1/chat/completions")
    }

    @Test func analysisSendsOnlyTheAuthorizedScope() async throws {
        let body = Data(#"{"choices":[{"message":{"role":"assistant","content":"Food was the largest category."}}]}"#.utf8)
        let client = AIClient(session: Self.session(data: body, status: 200), keyStore: StubKeyStore(value: "key"))
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
            configuration: AIConfiguration(baseURL: URL(string: "https://example.test/v1")!, model: "ledger", allowsLedgerData: true)
        )

        #expect(answer == "Food was the largest category.")
    }

    @Test func analysisRequiresExplicitLedgerPermission() async {
        let client = AIClient(session: Self.session(data: Data(), status: 200), keyStore: StubKeyStore(value: "key"))
        let scope = AIAnalysisScope(interval: DateInterval(start: .now, duration: 1), currencyCode: "USD", entries: [], categoryNames: [:])

        await #expect(throws: AIClientError.ledgerDataPermissionRequired) {
            try await client.analyze(
                question: "Summary",
                scope: scope,
                configuration: AIConfiguration(baseURL: URL(string: "https://example.test/v1")!, model: "ledger")
            )
        }
    }

    @Test func insecureRemoteBaseURLIsRejectedBeforeSendingKey() async {
        let client = AIClient(session: Self.session(data: Data(), status: 200), keyStore: StubKeyStore(value: "key"))

        await #expect(throws: AIClientError.invalidBaseURL) {
            try await client.parseLedger(
                text: "Lunch",
                configuration: AIConfiguration(baseURL: URL(string: "http://example.test/v1")!, model: "ledger")
            )
        }
    }

    @Test func transportFailureIsReportedAsNetworkError() async {
        let client = AIClient(session: Self.failingSession(), keyStore: StubKeyStore(value: "key"))

        do {
            try await client.parseLedger(
                text: "Lunch",
                configuration: AIConfiguration(baseURL: URL(string: "https://example.test/v1")!, model: "ledger")
            )
            Issue.record("Expected a network error")
        } catch AIClientError.network {
            // Expected. The underlying localized description varies by system language.
        } catch {
            Issue.record("Expected network error, received \(error)")
        }
    }

    @Test func missingKeyIsReportedWithoutNetwork() async {
        let client = AIClient(keyStore: StubKeyStore(value: nil))
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

private struct StubKeyStore: AIKeychainStoring {
    let value: String?
    func read(service: String, account: String) throws -> String? { value }
    func save(_ value: String, service: String, account: String) throws {}
    func delete(service: String, account: String) throws {}
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
