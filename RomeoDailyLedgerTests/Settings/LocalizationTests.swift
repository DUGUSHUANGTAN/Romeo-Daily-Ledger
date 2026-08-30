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

    @Test func updateCheckCopyIsCompleteInBothLanguages() {
        let keys = [
            "settings.update.section", "settings.update.title", "settings.update.current",
            "settings.update.latest", "settings.update.check", "settings.update.checking",
            "settings.update.available", "settings.update.upToDate", "settings.update.openRelease",
            "settings.update.releasePage", "settings.update.error.noRelease",
            "settings.update.error.notFound", "settings.update.error.rateLimited",
            "settings.update.error.invalidResponse", "settings.update.error.network"
        ]
        for language in AppLanguage.allCases {
            for key in keys { #expect(AppLocalization.text(key, language: language) != key) }
        }
    }

    @Test func dataTransferCopyIsCompleteInBothLanguages() {
        let keys = [
            "settings.data.title", "settings.data.export.title", "settings.data.export.help",
            "settings.data.export.json", "settings.data.export.csv", "settings.data.import.title",
            "settings.data.import.help", "settings.data.import.button",
            "settings.data.import.preview.title", "settings.data.import.preview.total",
            "settings.data.import.preview.income", "settings.data.import.preview.expense",
            "settings.data.import.preview.dateRange", "settings.data.import.preview.categories",
            "settings.data.import.strategy", "settings.data.import.skipDuplicates",
            "settings.data.import.keepBoth", "settings.data.import.confirm",
            "settings.data.error.invalidData", "settings.data.error.export",
            "settings.data.error.import", "settings.data.error.currencyMismatch",
            "settings.data.error.missingField", "settings.data.error.invalidAmount",
            "settings.data.error.invalidDate", "settings.data.error.invalidKind",
            "settings.data.error.malformedCSV"
        ]
        for language in AppLanguage.allCases {
            for key in keys { #expect(AppLocalization.text(key, language: language) != key) }
        }
    }

    @Test func keychainFailureUsesKeychainCopyInsteadOfNetworkCopy() {
        let message = localizedAIError(AIKeychainError.status(-1), language: .english)
        #expect(message == AppLocalization.text("settings.ai.keychainError", language: .english))
    }

    @Test func aiAssistantCopyIsCompleteInBothLanguages() {
        let keys = [
            "ai.mode.entry", "ai.mode.analysis", "ai.analysis.question",
            "ai.analysis.start", "ai.analysis.end", "ai.analysis.scope",
            "ai.analysis.run", "ai.analysis.permissionRequired",
            "ai.error.apiKey", "ai.error.baseURL", "ai.error.model",
            "ai.error.network", "ai.error.http", "ai.error.decoding",
            "ai.error.invalidResult", "settings.ai.testing"
        ]
        for language in AppLanguage.allCases {
            for key in keys { #expect(AppLocalization.text(key, language: language) != key) }
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
