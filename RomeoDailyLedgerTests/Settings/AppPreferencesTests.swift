import Foundation
import Testing
@testable import RomeoDailyLedger

@MainActor @Suite("App preferences")
struct AppPreferencesTests {
    @Test func modelPresetsCanBeReorderedRepeatedly() {
        let presets = ["A", "B", "C"].map {
            AIModelPreset(name: $0, configuration: AIConfiguration(model: $0))
        }
        let dragged = AIModelPresetOrder.reordered(presets, moving: presets[2].id, before: presets[0].id)
        #expect(dragged.map(\.name) == ["C", "A", "B"])

        let movedToBottom = AIModelPresetOrder.reordered(
            dragged,
            moving: dragged[0].id,
            relativeTo: dragged[2].id,
            placeAfter: true
        )
        #expect(movedToBottom.map(\.name) == ["A", "B", "C"])
    }

    @Test func categoryReorderingKeepsOtherLastAcrossRepeatedMoves() {
        let first = Category(kind: .expense, customName: "A", iconName: "tag", colorToken: "custom", sortOrder: 0)
        let second = Category(kind: .expense, customName: "B", iconName: "tag", colorToken: "custom", sortOrder: 1)
        let other = Category(kind: .expense, systemKey: "other", iconName: "ellipsis", colorToken: "other", sortOrder: .max)

        let dragged = CategoryOrder.reordered([first, second, other], moving: second.id, before: first.id)
        #expect(dragged.map(\.customName) == ["B", "A", nil])
        #expect(dragged.last?.systemKey == "other")
        let attemptedOtherDrag = CategoryOrder.reordered(dragged, moving: other.id, before: first.id)
        #expect(attemptedOtherDrag.map(\.id) == dragged.map(\.id))
    }

    @Test func modelPresetStatusDefaultsToNotConnectedAndPersists() throws {
        let checkedAt = Date(timeIntervalSince1970: 1_000)
        let preset = AIModelPreset(
            name: "OpenAI",
            configuration: AIConfiguration(model: "gpt-test", apiKey: "key"),
            lastConnectionCheckAt: checkedAt
        )
        #expect(preset.connectionStatus == .notConnected)

        let decoded = try JSONDecoder().decode(AIModelPreset.self, from: JSONEncoder().encode(preset))
        #expect(decoded == preset)
        #expect(decoded.lastConnectionCheckAt == checkedAt)
    }

    @Test func legacyModelPresetWithoutCheckTimeStillDecodes() throws {
        let data = Data(#"{"id":"00000000-0000-0000-0000-000000000001","name":"Legacy","configuration":{"protocolType":"chatCompletions","baseURL":"https:\/\/example.com\/v1","model":"ledger","apiKey":""},"connectionStatus":"connected"}"#.utf8)

        let preset = try JSONDecoder().decode(AIModelPreset.self, from: data)

        #expect(preset.lastConnectionCheckAt == nil)
    }

    @Test func modelStatusCacheExpiresAtTenMinutes() {
        let now = Date(timeIntervalSince1970: 1_000)

        #expect(!AIModelStatusCache.shouldCheck(lastCheckedAt: now.addingTimeInterval(-599), now: now))
        #expect(AIModelStatusCache.shouldCheck(lastCheckedAt: now.addingTimeInterval(-600), now: now))
        #expect(AIModelStatusCache.shouldCheck(lastCheckedAt: nil, now: now))
    }

    @Test func failedAndUntestedModelsUseDisconnectedIndicator() {
        #expect(AIModelConnectionStatus.notConnected.isConnected == false)
        #expect(AIModelConnectionStatus.failed.isConnected == false)
        #expect(AIModelConnectionStatus.connected.isConnected == true)
    }
    @Test func defaultsMatchSpecification() {
        let defaults = isolatedDefaults()
        let preferences = AppPreferences(defaults: defaults, settingsStore: temporaryStore())

        #expect(preferences.currencyCode == "USD")
        #expect(preferences.themeMode == .system)
        #expect(preferences.language == .simplifiedChinese)
        #expect(preferences.fontScalePercent == 100)
    }

    @Test func preferencesPersistThroughInjectedUserDefaults() {
        let defaults = isolatedDefaults()
        let store = temporaryStore()
        let first = AppPreferences(defaults: defaults, settingsStore: store)
        first.currencyCode = "EUR"
        first.themeMode = .dark
        first.language = .english
        first.fontScalePercent = 125

        let restored = AppPreferences(defaults: defaults, settingsStore: store)
        #expect(restored.currencyCode == "EUR")
        #expect(restored.themeMode == .dark)
        #expect(restored.language == .english)
        #expect(restored.fontScalePercent == 125)
    }

    @Test func fontScaleIsClampedAndRoundedToFivePercentSteps() {
        let preferences = AppPreferences(defaults: isolatedDefaults(), settingsStore: temporaryStore())

        preferences.fontScalePercent = 143
        #expect(preferences.fontScalePercent == 140)

        preferences.fontScalePercent = 82
        #expect(preferences.fontScalePercent == 80)

        preferences.fontScalePercent = 113
        #expect(preferences.fontScalePercent == 115)
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
        let json = try String(contentsOf: store.url, encoding: .utf8)

        let restored = AppPreferences(defaults: defaults, settingsStore: store)
        #expect(json.contains("secret-value"))
        #expect(restored.aiConfiguration.apiKey == "secret-value")
    }

    @Test func modelPresetKeysRoundTripThroughSettingsJSON() throws {
        let defaults = isolatedDefaults()
        let store = temporaryStore()
        let id = UUID()
        let preferences = AppPreferences(defaults: defaults, settingsStore: store)
        preferences.aiModelPresets = [AIModelPreset(
            id: id,
            name: "Local",
            configuration: AIConfiguration(model: "model", apiKey: "preset-secret")
        )]

        let json = try String(contentsOf: store.url, encoding: .utf8)
        let restored = AppPreferences(defaults: defaults, settingsStore: store)

        #expect(json.contains("preset-secret"))
        #expect(restored.aiModelPresets.first?.configuration.apiKey == "preset-secret")
    }

    @Test func legacyAIConfigurationDecodesWithEmptyAPIKey() throws {
        let data = Data(#"{"protocolType":"chatCompletions","baseURL":"https:\/\/example.com\/v1","model":"legacy","allowsLedgerData":true}"#.utf8)
        let configuration = try JSONDecoder().decode(AIConfiguration.self, from: data)
        #expect(configuration.apiKey.isEmpty)
    }

    @Test func legacyStoredSettingsDecodesWithoutModelPresetFields() throws {
        let data = Data(#"{"currencyCode":"CNY","language":"zh-Hans","themeMode":"system","aiConfiguration":{"protocolType":"chatCompletions","baseURL":"https:\/\/example.com\/v1","model":"legacy","apiKey":"key"}}"#.utf8)
        let settings = try JSONDecoder().decode(StoredSettings.self, from: data)
        #expect(settings.aiModelPresets.isEmpty)
        #expect(settings.selectedAIModelID == nil)
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
