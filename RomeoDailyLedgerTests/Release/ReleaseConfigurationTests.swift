import Foundation
import Testing

@Suite("Release configuration")
struct ReleaseConfigurationTests {
    @Test func versionAndBuildNumberAreConfigured() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let project = try String(contentsOf: root.appendingPathComponent("project.yml"), encoding: .utf8)
        let info = try String(contentsOf: root.appendingPathComponent("RomeoDailyLedger/Resources/Info.plist"), encoding: .utf8)
        let releaseConfig = try String(contentsOf: root.appendingPathComponent("Config/Release.xcconfig"), encoding: .utf8)
        #expect(project.contains("MARKETING_VERSION: 1.1.0"))
        #expect(project.contains("CURRENT_PROJECT_VERSION: 5"))
        #expect(info.contains("$(MARKETING_VERSION)"))
        #expect(info.contains("$(CURRENT_PROJECT_VERSION)"))
        #expect(releaseConfig.contains("ENABLE_HARDENED_RUNTIME = YES"))
        #expect(releaseConfig.contains("ARCHS = arm64"))
        #expect(releaseConfig.contains("EXCLUDED_ARCHS = x86_64"))
    }

    @Test func releaseScriptsSupportSigningWithoutChecksumAssets() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let buildScript = try String(contentsOf: root.appendingPathComponent("scripts/build_release.sh"), encoding: .utf8)
        let dmgScript = try String(contentsOf: root.appendingPathComponent("scripts/create_dmg.sh"), encoding: .utf8)

        #expect(buildScript.contains("SIGNING_IDENTITY"))
        #expect(dmgScript.contains("shasum -a 256") == false)
        #expect(dmgScript.contains("VERSION=\"${VERSION:-1.1.0}\""))
        #expect(buildScript.contains("ARCHS=arm64"))
    }
}
