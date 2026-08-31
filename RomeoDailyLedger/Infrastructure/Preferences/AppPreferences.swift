import Foundation
import Observation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var id: Self { self }
    var locale: Locale { Locale(identifier: rawValue) }
}

@MainActor @Observable
final class AppPreferences {
    private enum Key {
        static let currencyCode = "preferences.currencyCode"
        static let language = "preferences.language"
        static let themeMode = "preferences.themeMode"
        static let typographyStyle = "preferences.typographyStyle"
        static let motionIntensity = "preferences.motionIntensity"
        static let aiConfiguration = "preferences.aiConfiguration"
    }

    private let defaults: UserDefaults
    private let settingsStore: SettingsStore
    private var isLoading = true

    var currencyCode: String {
        didSet {
            let normalized = Self.normalizedCurrencyCode(currencyCode)
            if normalized != currencyCode {
                currencyCode = normalized
                return
            }
            persist()
        }
    }

    var language: AppLanguage {
        didSet { persist() }
    }

    var themeMode: ThemeMode {
        didSet { persist() }
    }

    var typographyStyle: AppTypography.Style {
        didSet { persist() }
    }

    var motionIntensity: Int {
        didSet {
            let clamped = min(max(motionIntensity, 0), 100)
            if clamped != motionIntensity {
                motionIntensity = clamped
                return
            }
            persist()
        }
    }

    var aiConfiguration: AIConfiguration {
        didSet {
            persist()
        }
    }

    var apiKey: String {
        get { aiConfiguration.apiKey }
        set { aiConfiguration.apiKey = newValue }
    }

    init(defaults: UserDefaults = .standard, settingsStore: SettingsStore? = nil) {
        self.defaults = defaults
        let directory = StorageCoordinator(defaults: defaults).activeDirectory
        self.settingsStore = settingsStore ?? SettingsStore(directory: directory)
        let stored = try? self.settingsStore.load()
        currencyCode = Self.normalizedCurrencyCode(stored?.currencyCode ?? defaults.string(forKey: Key.currencyCode) ?? "USD")
        language = AppLanguage(rawValue: stored?.language ?? defaults.string(forKey: Key.language) ?? "") ?? .simplifiedChinese
        themeMode = ThemeMode(rawValue: stored?.themeMode ?? defaults.string(forKey: Key.themeMode) ?? "") ?? .system
        typographyStyle = AppTypography.Style(rawValue: stored?.typographyStyle ?? defaults.string(forKey: Key.typographyStyle) ?? "") ?? .system
        motionIntensity = stored?.motionIntensity ?? (defaults.object(forKey: Key.motionIntensity) == nil
            ? 50
            : min(max(defaults.integer(forKey: Key.motionIntensity), 0), 100))
        if let configuration = stored?.aiConfiguration {
            aiConfiguration = configuration
        } else if let data = defaults.data(forKey: Key.aiConfiguration),
           let saved = try? JSONDecoder().decode(AIConfiguration.self, from: data) {
            aiConfiguration = saved
        } else {
            aiConfiguration = AIConfiguration()
        }
        isLoading = false
        persist()
        [Key.currencyCode, Key.language, Key.themeMode, Key.typographyStyle, Key.motionIntensity, Key.aiConfiguration].forEach(defaults.removeObject)
    }

    private func persist() {
        guard !isLoading else { return }
        try? settingsStore.save(StoredSettings(currencyCode: currencyCode, language: language.rawValue, themeMode: themeMode.rawValue, typographyStyle: typographyStyle.rawValue, motionIntensity: motionIntensity, aiConfiguration: aiConfiguration))
    }

    private static func normalizedCurrencyCode(_ value: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return normalized.isEmpty ? "USD" : String(normalized.prefix(3))
    }
}

private struct LegacyAIConfiguration: Codable {
    let protocolType: AIProtocol
    let baseURL: URL
    let model: String
    let allowsLedgerData: Bool

    init(configuration: AIConfiguration) {
        protocolType = configuration.protocolType
        baseURL = configuration.baseURL
        model = configuration.model
        allowsLedgerData = configuration.allowsLedgerData
    }
}

protocol AppClock: Sendable {
    var now: Date { get }
}

protocol AppTimeZoneProviding: Sendable {
    var timeZone: TimeZone { get }
}

struct SystemAppClock: AppClock {
    var now: Date { .now }
}

struct SystemAppTimeZoneProvider: AppTimeZoneProviding {
    var timeZone: TimeZone { .autoupdatingCurrent }
}

struct FixedAppClock: AppClock {
    let now: Date
}

struct FixedAppTimeZoneProvider: AppTimeZoneProviding {
    let timeZone: TimeZone
}
