import Foundation
import Testing
@testable import RomeoDailyLedger

@MainActor @Suite("App preferences")
struct AppPreferencesTests {
    @Test func defaultsMatchSpecification() {
        let defaults = isolatedDefaults()
        let preferences = AppPreferences(defaults: defaults, settingsStore: temporaryStore())

        #expect(preferences.currencyCode == "USD")
        #expect(preferences.themeMode == .system)
        #expect(preferences.language == .simplifiedChinese)
    }

    @Test func preferencesPersistThroughInjectedUserDefaults() {
        let defaults = isolatedDefaults()
        let store = temporaryStore()
        let first = AppPreferences(defaults: defaults, settingsStore: store)
        first.currencyCode = "EUR"
        first.themeMode = .dark
        first.language = .english

        let restored = AppPreferences(defaults: defaults, settingsStore: store)
        #expect(restored.currencyCode == "EUR")
        #expect(restored.themeMode == .dark)
        #expect(restored.language == .english)
    }

    @Test func settingsJSONDoesNotPersistRemovedTypographyOrMotionControls() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = SettingsStore(directory: directory)
        _ = AppPreferences(defaults: isolatedDefaults(), settingsStore: store)
        let text = try String(contentsOf: store.url, encoding: .utf8)
        #expect(!text.contains("typographyStyle"))
        #expect(!text.contains("motionIntensity"))
    }

    @Test func aiConfigurationPersistsAPIKeyForVisibleRestartField() throws {
        let defaults = isolatedDefaults()
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = SettingsStore(directory: directory)
        let preferences = AppPreferences(defaults: defaults, settingsStore: store)
        preferences.aiConfiguration = AIConfiguration(
            protocolType: .chatCompletions,
            baseURL: URL(string: "https://example.com/v1")!,
            model: "compatible-model",
            apiKey: "secret-value"
        )

        let restored = AppPreferences(defaults: defaults, settingsStore: store)
        #expect(restored.aiConfiguration.apiKey == "secret-value")
    }

    @Test func legacyAIConfigurationDecodesWithEmptyAPIKey() throws {
        let data = Data(#"{"protocolType":"chatCompletions","baseURL":"https:\/\/example.com\/v1","model":"legacy","allowsLedgerData":true}"#.utf8)
        let configuration = try JSONDecoder().decode(AIConfiguration.self, from: data)
        #expect(configuration.apiKey.isEmpty)
        #expect(configuration.customInstructions.isEmpty)
    }

    @Test func customAIInstructionsPersistImmediately() {
        let defaults = isolatedDefaults()
        let store = temporaryStore()
        let preferences = AppPreferences(defaults: defaults, settingsStore: store)
        preferences.aiConfiguration.customInstructions = "Keep answers practical."

        let restored = AppPreferences(defaults: defaults, settingsStore: store)
        #expect(restored.aiConfiguration.customInstructions == "Keep answers practical.")
    }

    @Test func systemClockAndTimeZoneProvidersExposeInjectedContracts() {
        let instant = Date(timeIntervalSince1970: 1_800_000_000)
        let zone = TimeZone(secondsFromGMT: 8 * 3_600)!
        let clock: any AppClock = FixedAppClock(now: instant)
        let provider: any AppTimeZoneProviding = FixedAppTimeZoneProvider(timeZone: zone)
        #expect(clock.now == instant)
        #expect(provider.timeZone == zone)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "AppPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func temporaryStore() -> SettingsStore {
        SettingsStore(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
    }
}
