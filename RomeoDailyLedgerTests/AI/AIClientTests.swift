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

    @Test func missingKeyIsReportedWithoutNetwork() async {
        let client = AIClient(keyStore: StubKeyStore(value: nil))
        await #expect(throws: AIClientError.apiKeyMissing) {
            try await client.parseLedger(text: "Lunch", configuration: AIConfiguration(model: "ledger"))
        }
    }

    private static func session(data: Data, status: Int) -> URLSession {
        StubURLProtocol.data = data; StubURLProtocol.status = status
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
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
