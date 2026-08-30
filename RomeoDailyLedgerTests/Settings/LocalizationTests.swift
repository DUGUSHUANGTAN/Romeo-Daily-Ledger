import Testing
@testable import RomeoDailyLedger

@MainActor @Suite("Localization")
struct LocalizationTests {
    @Test func navigationDoesNotMixLanguages() {
        let chinese = SidebarDestination.allCases.map { $0.localizedTitle(language: .simplifiedChinese) }
        let english = SidebarDestination.allCases.map { $0.localizedTitle(language: .english) }

        #expect(chinese.contains("记账"))
        #expect(chinese.contains("日历"))
        #expect(chinese.contains("统计"))
        #expect(chinese.contains("设置"))
        #expect(!chinese.contains("Ledger"))
        #expect(!chinese.contains("Settings"))

        #expect(english.contains("Ledger"))
        #expect(english.contains("Calendar"))
        #expect(english.contains("Insights"))
        #expect(english.contains("Settings"))
        #expect(!english.contains("记账"))
        #expect(!english.contains("日历"))
        #expect(!english.contains("统计"))
        #expect(!english.contains("设置"))
    }

    @Test func settingsSectionsAndBuiltInCategoriesAreCompleteInBothLanguages() {
        for language in AppLanguage.allCases {
            #expect(AppLocalization.text("settings.general.title", language: language) != "settings.general.title")
            #expect(AppLocalization.text("settings.appearance.title", language: language) != "settings.appearance.title")
            #expect(AppLocalization.text("settings.categories.title", language: language) != "settings.categories.title")
            for key in ["clothing", "food", "housing", "transport", "entertainment", "other", "salary", "bonus", "investment", "refund"] {
                #expect(AppLocalization.categoryName(systemKey: key, language: language) != key)
            }
        }
    }

    @Test func customCategoryNamesAndUserNotesRemainUntranslated() {
        #expect(AppLocalization.categoryName(systemKey: nil, customName: "My Side Project", language: .simplifiedChinese) == "My Side Project")
        #expect(AppLocalization.categoryName(systemKey: nil, customName: "旅行基金", language: .english) == "旅行基金")
        #expect(AppLocalization.userContent("LedgerRepository", language: .simplifiedChinese) == "LedgerRepository")
    }

    @Test func settingsDestinationAndCommandAreDiscoverableWithoutSidebarShortcutText() {
        #expect(SidebarDestination.allCases.contains(.settings))
        #expect(SidebarDestination.settings.icon == .settings)
        #expect(AppCommands.settingsShortcutKey == ",")
        #expect(!SidebarDestination.settings.localizedSubtitle(language: .simplifiedChinese).contains("⌘"))
        #expect(!SidebarDestination.settings.localizedSubtitle(language: .english).contains("⌘"))
    }
}
