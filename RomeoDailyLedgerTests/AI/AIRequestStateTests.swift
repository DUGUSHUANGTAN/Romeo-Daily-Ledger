import Foundation
import Testing
@testable import RomeoDailyLedger

@MainActor @Suite("AI delayed request state")
struct AIRequestStateTests {
    enum Failure: Error { case expected }

    @Test func delayedSuccessShowsLoadingThenClears() async throws {
        let state = AIRequestState()
        let task = Task { try await state.perform { try await Task.sleep(for: .milliseconds(40)); return "ok" } }
        await Task.yield()
        #expect(state.isLoading)
        #expect(try await task.value == "ok")
        #expect(!state.isLoading)
    }

    @Test func delayedFailureClearsLoading() async {
        let state = AIRequestState()
        await #expect(throws: Failure.expected) {
            try await state.perform { try await Task.sleep(for: .milliseconds(20)); throw Failure.expected }
        }
        #expect(!state.isLoading)
    }

    @Test func cancellationClearsLoading() async {
        let state = AIRequestState()
        let task = Task { try await state.perform { try await Task.sleep(for: .seconds(2)) } }
        await Task.yield()
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(!state.isLoading)
    }

    @Test func duplicateSubmissionIsRejectedWhileDelayedRequestRuns() async throws {
        let state = AIRequestState()
        let first = Task { try await state.perform { try await Task.sleep(for: .milliseconds(50)) } }
        await Task.yield()
        await #expect(throws: AIRequestState.StateError.alreadyRunning) {
            try await state.perform { }
        }
        try await first.value
    }
}
