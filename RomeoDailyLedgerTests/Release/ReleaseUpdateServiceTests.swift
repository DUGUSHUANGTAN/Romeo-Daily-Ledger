import Foundation
import Testing
@testable import RomeoDailyLedger

@Suite("Release update service")
struct ReleaseUpdateServiceTests {
    @Test func semanticVersionComparison() {
        #expect(ReleaseUpdateService.compare("1.1.0", "1.0.0") == .orderedDescending)
        #expect(ReleaseUpdateService.compare("1.0", "1.0.0") == .orderedSame)
        #expect(ReleaseUpdateService.compare("0.9.9", "1.0.0") == .orderedAscending)
    }

    @Test func newerVersionIsAvailable() async throws {
        let release = GitHubRelease(tagName: "v1.1.0", htmlURL: URL(string: "https://example.com/release")!)
        #expect(try await ReleaseUpdateService.check(using: StubClient(result: .success(release))) == .updateAvailable(release))
    }

    @Test func sameVersionIsUpToDate() async throws {
        let release = GitHubRelease(tagName: "v1.0.0", htmlURL: URL(string: "https://example.com/release")!)
        #expect(try await ReleaseUpdateService.check(using: StubClient(result: .success(release))) == .upToDate(release))
    }

    @Test func errorsArePreserved() async {
        for expected in [ReleaseUpdateError.noRelease, .repositoryNotFound, .rateLimited, .invalidResponse, .network] {
            await #expect(throws: expected) {
                try await ReleaseUpdateService.check(using: StubClient(result: .failure(expected)))
            }
        }
    }
}

private struct StubClient: ReleaseUpdateFetching {
    let result: Result<GitHubRelease, ReleaseUpdateError>
    func fetchLatestRelease() async throws -> GitHubRelease { try result.get() }
}
