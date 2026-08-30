import Foundation
import Testing
@testable import RomeoDailyLedger

@MainActor @Suite("App preferences")
struct AppPreferencesTests {
    @Test func defaultsMatchSpecification() {
        let defaults = isolatedDefaults()
        let preferences = AppPreferences(defaults: defaults)

        #expect(preferences.currencyCode == "USD")
        #expect(preferences.themeMode == .system)
        #expect(preferences.motionIntensity == 50)
        #expect(preferences.language == .simplifiedChinese)
        #expect(preferences.typographyStyle == .system)
    }

    @Test func preferencesPersistThroughInjectedUserDefaults() {
        let defaults = isolatedDefaults()
        let first = AppPreferences(defaults: defaults)
        first.currencyCode = "EUR"
        first.themeMode = .dark
        first.motionIntensity = 82
        first.language = .english
        first.typographyStyle = .rounded

        let restored = AppPreferences(defaults: defaults)
        #expect(restored.currencyCode == "EUR")
        #expect(restored.themeMode == .dark)
        #expect(restored.motionIntensity == 82)
        #expect(restored.language == .english)
        #expect(restored.typographyStyle == .rounded)
    }

    @Test func motionIntensityIsClampedBeforePersistence() {
        let defaults = isolatedDefaults()
        let preferences = AppPreferences(defaults: defaults)

        preferences.motionIntensity = 140
        #expect(preferences.motionIntensity == 100)
        preferences.motionIntensity = -2
        #expect(preferences.motionIntensity == 0)
    }

    @Test func allThreeNativeTypographyStrategiesRemainAvailable() {
        #expect(AppTypography.Style.allCases == [.system, .editorial, .rounded])
        #expect(AppTypography.Style.allCases.allSatisfy { !$0.usesBundledFont })
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "AppPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
