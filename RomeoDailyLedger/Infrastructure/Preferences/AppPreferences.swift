import Foundation
import Observation
import Foundation

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

    var currencyCode: String {
        didSet {
            let normalized = Self.normalizedCurrencyCode(currencyCode)
            if normalized != currencyCode {
                currencyCode = normalized
                return
            }
            defaults.set(currencyCode, forKey: Key.currencyCode)
        }
    }

    var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Key.language) }
    }

    var themeMode: ThemeMode {
        didSet { defaults.set(themeMode.rawValue, forKey: Key.themeMode) }
    }

    var typographyStyle: AppTypography.Style {
        didSet { defaults.set(typographyStyle.rawValue, forKey: Key.typographyStyle) }
    }

    var motionIntensity: Int {
        didSet {
            let clamped = min(max(motionIntensity, 0), 100)
            if clamped != motionIntensity {
                motionIntensity = clamped
                return
            }
            defaults.set(motionIntensity, forKey: Key.motionIntensity)
        }
    }

    var aiConfiguration: AIConfiguration {
        didSet {
            if let data = try? JSONEncoder().encode(aiConfiguration) {
                defaults.set(data, forKey: Key.aiConfiguration)
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        currencyCode = Self.normalizedCurrencyCode(defaults.string(forKey: Key.currencyCode) ?? "USD")
        language = AppLanguage(rawValue: defaults.string(forKey: Key.language) ?? "") ?? .simplifiedChinese
        themeMode = ThemeMode(rawValue: defaults.string(forKey: Key.themeMode) ?? "") ?? .system
        typographyStyle = AppTypography.Style(rawValue: defaults.string(forKey: Key.typographyStyle) ?? "") ?? .system
        motionIntensity = defaults.object(forKey: Key.motionIntensity) == nil
            ? 50
            : min(max(defaults.integer(forKey: Key.motionIntensity), 0), 100)
        if let data = defaults.data(forKey: Key.aiConfiguration),
           let saved = try? JSONDecoder().decode(AIConfiguration.self, from: data) {
            aiConfiguration = saved
        } else {
            aiConfiguration = AIConfiguration()
        }
    }

    private static func normalizedCurrencyCode(_ value: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return normalized.isEmpty ? "USD" : String(normalized.prefix(3))
    }
}
