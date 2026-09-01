import Testing
@testable import RomeoDailyLedger

@Suite("DesignSystemTests")
struct DesignSystemTests {
    @Test func approvedThemesKeepTheirCanvasAndBrandAccents() {
        #expect(AppTheme.light.canvas.hex == "FFFDF8")
        #expect(AppTheme.light.primaryAccent.hex == "1F5B4A")
        #expect(AppTheme.light.secondaryAccent.hex == "E89769")
        #expect(AppTheme.dark.canvas.hex == "161B21")
        #expect(AppTheme.dark.primaryAccent.hex == "B8E78C")
        #expect(AppTheme.light.selectionForeground.hex == "F7FAF8")
        #expect(AppTheme.dark.selectionForeground.hex == "F7FAF8")
    }

    @Test func selectedSidebarContentKeepsReadableContrastInBothThemes() {
        #expect(AppTheme.light.selectionForeground.hex == "F7FAF8")
        #expect(AppTheme.dark.selectionForeground.hex == "F7FAF8")
    }

    @Test func everyThemeModeResolvesWithoutChangingTokenStructure() {
        #expect(ThemeMode.system.resolve(systemIsDark: false) == .light)
        #expect(ThemeMode.system.resolve(systemIsDark: true) == .dark)
        #expect(ThemeMode.light.resolve(systemIsDark: true) == .light)
        #expect(ThemeMode.dark.resolve(systemIsDark: false) == .dark)
    }

    @Test func returningToSystemClearsAnExplicitNativeAppearance() {
        #expect(AppAppearancePolicy.appearanceName(for: .dark) == .darkAqua)
        #expect(AppAppearancePolicy.appearanceName(for: .light) == .aqua)
        #expect(AppAppearancePolicy.appearanceName(for: .system) == nil)
    }

    @Test func fontScaleConvertsPercentageToAStableMultiplier() {
        #expect(AppTypography.scaleFactor(percent: 80) == 0.8)
        #expect(AppTypography.scaleFactor(percent: 100) == 1.0)
        #expect(AppTypography.scaleFactor(percent: 140) == 1.4)
    }

    @Test func typographyOffersOnlyNativeFontStrategies() {
        #expect(AppTypography.Style.allCases == [.system, .editorial, .rounded])
        #expect(AppTypography.Style.allCases.allSatisfy(\.usesBundledFont) == false)
    }

    @Test func motionIntensityIsClampedToSupportedRange() {
        #expect(MotionPolicy(slider: -1, systemReduceMotion: false).effectiveIntensity == 0)
        #expect(MotionPolicy(slider: 50, systemReduceMotion: false).effectiveIntensity == 50)
        #expect(MotionPolicy(slider: 101, systemReduceMotion: false).effectiveIntensity == 100)
    }

    @Test func reduceMotionOverridesSlider() {
        #expect(MotionPolicy(slider: 100, systemReduceMotion: true).effectiveIntensity == 0)
    }

    @Test func navigationMotionIsTactileButRespectsReducedMotion() {
        #expect(MotionPolicy.navigation(systemReduceMotion: false).effectiveIntensity > 0)
        #expect(MotionPolicy.navigation(systemReduceMotion: true).effectiveIntensity == 0)
    }

    @Test func darkInteractiveTextUsesThePreviousLighterAccent() {
        #expect(AppTheme.dark.primaryAccent.hex == "B8E78C")
    }

    @Test func sidebarHasTheFiveApprovedDestinationsAndLucideIcons() {
        #expect(SidebarDestination.allCases == [.ledger, .aiAssistant, .calendar, .insights, .settings])
        #expect(Set(SidebarDestination.allCases.map(\.icon)).count == 5)
        #expect(SidebarDestination.settings.icon == .settings)
        #expect(SidebarDestination.settings.title.contains("⌘,") == false)
    }

    @Test func everyDeliveredLucideIconResolvesToPinnedSVGData() throws {
        for icon in LucideIcon.allCases {
            let data = try #require(icon.svgData())
            let source = try #require(String(data: data, encoding: .utf8))
            #expect(source.contains("<svg"))
            #expect(source.contains("stroke=\"currentColor\""))
        }
        #expect(LucideIcon.version == "0.468.0")
    }
}
