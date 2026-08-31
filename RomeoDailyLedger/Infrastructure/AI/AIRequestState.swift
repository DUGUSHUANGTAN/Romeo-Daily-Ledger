import Foundation
import Observation

@MainActor @Observable
final class AIRequestState {
    enum StateError: Error, Equatable { case alreadyRunning }
    private(set) var isLoading = false

    func perform<Value>(_ operation: () async throws -> Value) async throws -> Value {
        guard !isLoading else { throw StateError.alreadyRunning }
        isLoading = true
        defer { isLoading = false }
        return try await operation()
    }
}
