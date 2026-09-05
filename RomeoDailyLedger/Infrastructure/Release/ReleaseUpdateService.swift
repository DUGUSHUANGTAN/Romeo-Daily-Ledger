import Foundation

struct GitHubRelease: Decodable, Equatable, Sendable {
    let tagName: String
    let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}

enum ReleaseUpdateResult: Equatable, Sendable {
    case updateAvailable(GitHubRelease)
    case upToDate(GitHubRelease)
}

enum ReleaseUpdateError: Error, Equatable {
    case noRelease
    case repositoryNotFound
    case rateLimited
    case invalidResponse
    case network
}

protocol ReleaseUpdateFetching: Sendable {
    func fetchLatestRelease() async throws -> GitHubRelease
}

struct GitHubReleaseClient: ReleaseUpdateFetching {
    private let latestURL = URL(string: "https://api.github.com/repos/DUGUSHUANGTAN/Romeo-Daily-Ledger/releases/latest")!
    private let repositoryURL = URL(string: "https://api.github.com/repos/DUGUSHUANGTAN/Romeo-Daily-Ledger")!

    func fetchLatestRelease() async throws -> GitHubRelease {
        do {
            let (data, response) = try await URLSession.shared.data(for: request(for: latestURL))
            guard let http = response as? HTTPURLResponse else { throw ReleaseUpdateError.invalidResponse }
            switch http.statusCode {
            case 200:
                do { return try JSONDecoder().decode(GitHubRelease.self, from: data) }
                catch { throw ReleaseUpdateError.invalidResponse }
            case 404:
                try await classifyNotFound()
                throw ReleaseUpdateError.noRelease
            case 403, 429:
                throw ReleaseUpdateError.rateLimited
            default:
                throw ReleaseUpdateError.invalidResponse
            }
        } catch let error as ReleaseUpdateError {
            throw error
        } catch {
            throw ReleaseUpdateError.network
        }
    }

    private func classifyNotFound() async throws {
        let (_, response) = try await URLSession.shared.data(for: request(for: repositoryURL))
        guard let http = response as? HTTPURLResponse else { throw ReleaseUpdateError.invalidResponse }
        switch http.statusCode {
        case 200: return
        case 404: throw ReleaseUpdateError.repositoryNotFound
        case 403, 429: throw ReleaseUpdateError.rateLimited
        default: throw ReleaseUpdateError.invalidResponse
        }
    }

    private func request(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Romeo-Daily-Ledger/1.1.0", forHTTPHeaderField: "User-Agent")
        return request
    }
}

enum ReleaseUpdateService {
    static let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1.0"
    static let releasesPage = URL(string: "https://github.com/DUGUSHUANGTAN/Romeo-Daily-Ledger/releases")!

    static func check(using client: any ReleaseUpdateFetching = GitHubReleaseClient()) async throws -> ReleaseUpdateResult {
        let release = try await client.fetchLatestRelease()
        let latest = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        guard !latest.isEmpty else { throw ReleaseUpdateError.noRelease }
        return compare(latest, currentVersion) == .orderedDescending ? .updateAvailable(release) : .upToDate(release)
    }

    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(left.count, right.count) {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l < r ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }
}
