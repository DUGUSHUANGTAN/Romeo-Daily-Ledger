import Foundation
import Observation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"

    var id: Self { self }
    var locale: Locale { Locale(identifier: rawValue) }
    var datePickerLocale: Locale {
        switch self {
        case .simplifiedChinese: Locale(identifier: "zh_CN")
        case .traditionalChinese: Locale(identifier: "zh_TW")
        case .english: Locale(identifier: "en_SE")
        }
    }
}

@MainActor @Observable
final class AppPreferences {
    private enum Key {
        static let currencyCode = "preferences.currencyCode"
        static let language = "preferences.language"
        static let themeMode = "preferences.themeMode"
        static let fontScalePercent = "preferences.fontScalePercent"
        static let aiConfiguration = "preferences.aiConfiguration"
    }

    private let defaults: UserDefaults
    private let settingsStore: SettingsStore
    private var isLoading = true

    static func persistedLanguage(defaults: UserDefaults = .standard) -> AppLanguage {
        let directory = StorageCoordinator(defaults: defaults).activeDirectory
        let stored = try? SettingsStore(directory: directory).load()
        return AppLanguage(rawValue: stored?.language ?? defaults.string(forKey: Key.language) ?? "") ?? .simplifiedChinese
    }

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

    var fontScalePercent: Int {
        didSet {
            let normalized = Self.normalizedFontScalePercent(fontScalePercent)
            if normalized != fontScalePercent {
                fontScalePercent = normalized
                return
            }
            AppTypography.currentScalePercent = normalized
            persist()
        }
    }

    var aiConfiguration: AIConfiguration {
        didSet {
            persist()
        }
    }

    var aiModelPresets: [AIModelPreset] {
        didSet {
            if let selectedAIModelID,
               let selected = aiModelPresets.first(where: { $0.id == selectedAIModelID }) {
                aiConfiguration = selected.configuration
            }
            persist()
        }
    }

    var selectedAIModelID: UUID? {
        didSet {
            if let selectedAIModelID,
               let selected = aiModelPresets.first(where: { $0.id == selectedAIModelID }) {
                aiConfiguration = selected.configuration
            }
            persist()
        }
    }

    var aiAnalysisHistory: [AIAnalysisHistoryItem] { didSet { persist() } }

    var apiKey: String {
        get { aiConfiguration.apiKey }
        set { aiConfiguration.apiKey = newValue }
    }

    init(
        defaults: UserDefaults = .standard,
        settingsStore: SettingsStore? = nil
    ) {
        self.defaults = defaults
        let directory = StorageCoordinator(defaults: defaults).activeDirectory
        self.settingsStore = settingsStore ?? SettingsStore(directory: directory)
        let stored = try? self.settingsStore.load()
        currencyCode = Self.normalizedCurrencyCode(stored?.currencyCode ?? defaults.string(forKey: Key.currencyCode) ?? "USD")
        language = AppLanguage(rawValue: stored?.language ?? defaults.string(forKey: Key.language) ?? "") ?? .simplifiedChinese
        themeMode = ThemeMode(rawValue: stored?.themeMode ?? defaults.string(forKey: Key.themeMode) ?? "") ?? .system
        fontScalePercent = Self.normalizedFontScalePercent(stored?.fontScalePercent ?? defaults.integer(forKey: Key.fontScalePercent))
        var configuration: AIConfiguration
        if let storedConfiguration = stored?.aiConfiguration {
            configuration = storedConfiguration
        } else if let data = defaults.data(forKey: Key.aiConfiguration),
           let saved = try? JSONDecoder().decode(AIConfiguration.self, from: data) {
            configuration = saved
        } else {
            configuration = AIConfiguration()
        }
        aiConfiguration = configuration
        aiModelPresets = stored?.aiModelPresets ?? []
        selectedAIModelID = stored?.selectedAIModelID
        aiAnalysisHistory = stored?.aiAnalysisHistory ?? []
        isLoading = false
        AppTypography.currentScalePercent = fontScalePercent
        persist()
        [Key.currencyCode, Key.language, Key.themeMode, Key.fontScalePercent, "preferences.typographyStyle", "preferences.motionIntensity", Key.aiConfiguration].forEach(defaults.removeObject)
    }

    private func persist() {
        guard !isLoading else { return }
        do {
            try settingsStore.save(StoredSettings(
                currencyCode: currencyCode,
                language: language.rawValue,
                themeMode: themeMode.rawValue,
                fontScalePercent: fontScalePercent,
                aiConfiguration: aiConfiguration,
                aiModelPresets: aiModelPresets,
                selectedAIModelID: selectedAIModelID,
                aiAnalysisHistory: aiAnalysisHistory
            ))
        } catch { return }
    }

    private static func normalizedCurrencyCode(_ value: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return normalized.isEmpty ? "USD" : String(normalized.prefix(3))
    }

    private static func normalizedFontScalePercent(_ value: Int) -> Int {
        guard value != 0 else { return 100 }
        let clamped = min(max(value, 80), 140)
        return Int((Double(clamped) / 5).rounded()) * 5
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

struct AppDateNormalizer: Sendable {
    private let clock: any AppClock
    private let timeZoneProvider: any AppTimeZoneProviding

    init(
        clock: any AppClock = SystemAppClock(),
        timeZoneProvider: any AppTimeZoneProviding = SystemAppTimeZoneProvider()
    ) {
        self.clock = clock
        self.timeZoneProvider = timeZoneProvider
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZoneProvider.timeZone
        return calendar
    }

    var today: Date { normalize(clock.now) }
    var yesterday: Date { calendar.date(byAdding: .day, value: -1, to: today)! }
    var startOfCurrentMonth: Date { calendar.dateInterval(of: .month, for: today)!.start }
    var timeZoneIdentifier: String { timeZoneProvider.timeZone.identifier }

    func normalize(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    func localDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZoneProvider.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
