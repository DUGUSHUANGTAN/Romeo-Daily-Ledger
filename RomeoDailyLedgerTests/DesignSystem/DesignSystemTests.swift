import Testing
@testable import RomeoDailyLedger

@Suite("DesignSystemTests")
struct DesignSystemTests {
    @Test func approvedThemesKeepTheirCanvasAndBrandAccents() {
        #expect(AppTheme.light.canvas.hex == "FFFDF8")
        #expect(AppTheme.light.primaryAccent.hex == "2F4F3E")
        #expect(AppTheme.light.secondaryAccent.hex == "E89769")
        #expect(AppTheme.dark.canvas.hex == "161B21")
        #expect(AppTheme.dark.primaryAccent.hex == "B8E78C")
    }

    @Test func selectedSidebarContentKeepsReadableContrastInBothThemes() {
        #expect(AppTheme.light.selectionForeground.hex == "FFFDF8")
        #expect(AppTheme.dark.selectionForeground.hex == "101318")
    }

    @Test func everyThemeModeResolvesWithoutChangingTokenStructure() {
        #expect(ThemeMode.system.resolve(systemIsDark: false) == .light)
        #expect(ThemeMode.system.resolve(systemIsDark: true) == .dark)
        #expect(ThemeMode.light.resolve(systemIsDark: true) == .light)
        #expect(ThemeMode.dark.resolve(systemIsDark: false) == .dark)
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
