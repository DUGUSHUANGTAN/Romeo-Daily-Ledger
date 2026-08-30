import Foundation
import Testing

@Suite("Release configuration")
struct ReleaseConfigurationTests {
    @Test func versionAndBuildNumberAreConfigured() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let project = try String(contentsOf: root.appendingPathComponent("project.yml"), encoding: .utf8)
        let info = try String(contentsOf: root.appendingPathComponent("RomeoDailyLedger/Resources/Info.plist"), encoding: .utf8)
        #expect(project.contains("MARKETING_VERSION: 1.0.0"))
        #expect(project.contains("CURRENT_PROJECT_VERSION: 1"))
        #expect(info.contains("$(MARKETING_VERSION)"))
        #expect(info.contains("$(CURRENT_PROJECT_VERSION)"))
    }
}
