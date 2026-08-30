import Foundation

protocol AIRequesting: Sendable { func parseLedger(text: String, configuration: AIConfiguration) async throws -> AILedgerDraftEnvelope }

struct AIClient: AIRequesting, Sendable {
    private let session: URLSession
    private let keyStore: AIKeychainStoring
    init(session: URLSession = .shared, keyStore: AIKeychainStoring = KeychainAIKeyStore()) { self.session = session; self.keyStore = keyStore }
    func parseLedger(text: String, configuration: AIConfiguration) async throws -> AILedgerDraftEnvelope {
        guard let key = try keyStore.read(service: KeychainAIKeyStore.service, account: "apiKey"), !key.isEmpty else { throw AIClientError.apiKeyMissing }
        guard !configuration.model.isEmpty else { throw AIClientError.invalidModel }
        var url = configuration.baseURL
        url.appendPathComponent(configuration.protocolType == .chatCompletions ? "chat/completions" : "responses")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = configuration.protocolType == .chatCompletions
            ? ["model": configuration.model, "messages": [["role": "user", "content": text]]]
            : ["model": configuration.model, "input": text]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw AIClientError.network("Invalid response") }
            guard (200..<300).contains(http.statusCode) else { throw AIClientError.httpStatus(http.statusCode, String(data: data, encoding: .utf8)) }
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let content = (object?["output_text"] as? String) ?? (((object?["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any])?["content"] as? String)
            guard let content else { throw AIClientError.responseDecoding("Missing model content") }
            let clean = content.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let envelope = try JSONDecoder().decode(AILedgerDraftEnvelope.self, from: Data(clean.utf8))
            guard !envelope.entries.isEmpty, envelope.entries.allSatisfy({ $0.amount > 0 && !$0.currency.isEmpty && !$0.note.isEmpty }) else { throw AIClientError.invalidStructuredResult("Invalid entries") }
            return envelope
        } catch let error as AIClientError { throw error } catch { throw AIClientError.responseDecoding(error.localizedDescription) }
    }
}
