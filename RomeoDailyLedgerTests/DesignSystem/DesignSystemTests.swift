import Foundation
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

    @Test func sidebarHasTheSevenApprovedDestinationsAndLucideIcons() {
        #expect(SidebarDestination.allCases == [.ledger, .aiAssistant, .calendar, .insights, .history, .categories, .settings])
        #expect(Set(SidebarDestination.allCases.map(\.icon)).count == 7)
        #expect(SidebarDestination.settings.icon == .settings)
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

    @Test func settingsPagesShareTheEstablishedInsetAndSidebarSelectionFallback() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pageFiles = [
            "GeneralSettingsView.swift",
            "AppearanceSettingsView.swift",
            "DataSettingsView.swift"
        ]

        for file in pageFiles {
            let source = try String(
                contentsOf: root.appendingPathComponent("RomeoDailyLedger/Features/Settings/\(file)"),
                encoding: .utf8
            )
            #expect(source.contains(".padding(SettingsPageLayout.contentInset)"), "\(file) should use the shared settings inset")
        }

        let settingsRoot = try String(
            contentsOf: root.appendingPathComponent("RomeoDailyLedger/Features/Settings/SettingsRootView.swift"),
            encoding: .utf8
        )
        #expect(settingsRoot.contains("if #available(macOS 26.0, *)"))
        #expect(settingsRoot.contains(".glassEffect("))
        #expect(settingsRoot.contains("RoundedRectangle(cornerRadius: SettingsPageLayout.sidebarSelectionCornerRadius)"))
    }

    @Test func scrollFadeMasksContentWithoutAffectingSidebars() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("RomeoDailyLedger/App/RootView.swift"),
            encoding: .utf8
        )

        #expect(source.contains(".windowToolbarBackgroundHidden()"))
        #expect(!source.contains("scrollEdgeEffectStyle"))
        #expect(!source.contains(".listStyle(.sidebar)"))
        #expect(!source.contains(".topScrollFade(color: theme.canvas.color)"))

        let fade = try String(
            contentsOf: root.appendingPathComponent("RomeoDailyLedger/DesignSystem/AppTheme.swift"),
            encoding: .utf8
        )
        #expect(fade.contains("func fadingAtTopEdge()"))
        #expect(fade.contains("mask(alignment: .top)"))

        let calendar = try String(
            contentsOf: root.appendingPathComponent("RomeoDailyLedger/Features/Calendar/CalendarView.swift"),
            encoding: .utf8
        )
        let insights = try String(
            contentsOf: root.appendingPathComponent("RomeoDailyLedger/Features/Insights/InsightsView.swift"),
            encoding: .utf8
        )
        let settings = try String(
            contentsOf: root.appendingPathComponent("RomeoDailyLedger/Features/Settings/SettingsRootView.swift"),
            encoding: .utf8
        )
        #expect(calendar.contains(".fadingAtTopEdge()"))
        #expect(insights.contains(".fadingAtTopEdge()"))
        #expect(!settings.contains(".fadingAtTopEdge()"))
    }

    @Test func macOSSettingsCommandUsesTheSingleInWindowSettingsPage() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("RomeoDailyLedger/App/RomeoDailyLedgerApp.swift"),
            encoding: .utf8
        )

        #expect(!source.contains("SettingsLink"))
        #expect(!source.contains("\n        Settings {"))
        #expect(source.contains("dependencies.selectedDestination = .settings"))
    }

    @Test func aiAnalysisHistoryUsesLongPressBatchDeletion() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("RomeoDailyLedger/Features/AI/AILedgerAssistantView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("ai-analysis-history-selection-hint"))
        #expect(source.contains("LongPressGesture(minimumDuration: 0.5)"))
        #expect(source.contains("selectedHistoryIDs.contains(item.id)"))
        #expect(source.contains("in: RoundedRectangle(cornerRadius: 10)"))
        #expect(source.contains("removeAll { selectedHistoryIDs.contains($0.id) }"))
        #expect(!source.contains("ai-analysis-history-delete-"))
        #expect(source.contains("ToolbarItem(placement: .destructiveAction)"))
        #expect(source.contains("ToolbarItem(placement: .confirmationAction)"))
        let toolbar = try #require(source.range(of: ".toolbar {"))
        let hint = try #require(source.range(of: "ai-analysis-history-selection-hint"))
        #expect(hint.lowerBound > toolbar.lowerBound)
    }

    @Test func aiAnalysisHistoryDefaultsToNewestAndOnlyShowsEmptyStateWhenEmpty() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("RomeoDailyLedger/Features/AI/AILedgerAssistantView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("if let selected = selected ?? preferences.aiAnalysisHistory.first"))
        #expect(AppLocalization.text("ai.analysis.history.empty", language: .simplifiedChinese) == "当前没有分析历史")
    }

    @Test func aiAnalysisHistorySidebarCannotConsumeTheDetailPane() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("RomeoDailyLedger/Features/AI/AILedgerAssistantView.swift"),
            encoding: .utf8
        )

        #expect(source.contains(".navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)"))
    }

    @Test func visibleDatesFollowTheSelectedAppLanguage() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let paths = [
            "RomeoDailyLedger/Features/AI/AILedgerAssistantView.swift",
            "RomeoDailyLedger/Features/Calendar/CalendarView.swift",
            "RomeoDailyLedger/Features/Insights/InsightsView.swift",
            "RomeoDailyLedger/Features/Ledger/EntryListView.swift",
            "RomeoDailyLedger/Features/Ledger/LedgerView.swift",
            "RomeoDailyLedger/Features/Settings/CategoryManagementView.swift"
        ]

        for path in paths {
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            #expect(!source.contains("format: .dateTime.year().month().day())"))
            #expect(!source.contains("format: .dateTime.year().month(.wide))"))
        }

        let calendar = try String(
            contentsOf: root.appendingPathComponent("RomeoDailyLedger/Features/Calendar/CalendarView.swift"),
            encoding: .utf8
        )
        let insights = try String(
            contentsOf: root.appendingPathComponent("RomeoDailyLedger/Features/Insights/InsightsView.swift"),
            encoding: .utf8
        )
        #expect(calendar.contains("calendar.locale = language.locale"))
        #expect(insights.contains("calendar.locale = language.locale"))
    }

    @Test func settingsPagesUseTransparentGroupedContainersInsteadOfFormBackgrounds() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let paths = [
            "RomeoDailyLedger/Features/Settings/GeneralSettingsView.swift",
            "RomeoDailyLedger/Features/Settings/AppearanceSettingsView.swift",
            "RomeoDailyLedger/Features/Settings/AISettingsView.swift",
            "RomeoDailyLedger/Features/Settings/DataSettingsView.swift"
        ]

        for path in paths {
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            #expect(!source.contains("Form {"))
            #expect(source.contains("SettingsPageScroll"))
            #expect(source.contains("SettingsPageSection"))
        }

        let rootSource = try String(
            contentsOf: root.appendingPathComponent("RomeoDailyLedger/Features/Settings/SettingsRootView.swift"),
            encoding: .utf8
        )
        #expect(rootSource.contains("struct SettingsPageScroll"))
        #expect(rootSource.contains(".scrollContentBackground(.hidden)"))
        #expect(rootSource.contains("NavigationStack"))
        #expect(rootSource.contains(".navigationTitle(AppLocalization.text(\"nav.settings.title\", language: preferences.language))"))
    }

    @Test func generalLanguageControlsUseTheLeadingSettingsColumn() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("RomeoDailyLedger/Features/Settings/GeneralSettingsView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("HStack(spacing: 12)"))
        #expect(!source.contains(".frame(width: 120, alignment: .leading)"))
        #expect(!source.contains(".frame(width: 360)"))
    }

    @Test func aiSettingsOffersAForceRefreshForAllModels() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("RomeoDailyLedger/Features/Settings/AISettingsView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("settings.ai.checkModels"))
        #expect(source.contains("refreshConnectionStatuses(force: true)"))
        #expect(source.contains("Spacer()\n                    Button {\n                        Task { await refreshConnectionStatuses(force: true) }"))
    }

    @Test func categoryManagementUsesTheSameContentTitleStyleAsCalendar() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("RomeoDailyLedger/Features/Settings/CategoryManagementView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("AppTypography.display(.system)"))
        #expect(source.contains("settings.categories.title"))
        #expect(source.contains(".fadingAtTopEdge()"))
        #expect(!source.contains(".navigationTitle(AppLocalization.text(\"settings.categories.title\""))
    }

}
