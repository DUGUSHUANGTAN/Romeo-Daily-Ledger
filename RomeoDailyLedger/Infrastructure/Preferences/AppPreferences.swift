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
