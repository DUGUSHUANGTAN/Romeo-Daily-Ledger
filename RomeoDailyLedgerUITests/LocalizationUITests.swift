import XCTest

@MainActor
final class LocalizationUITests: XCTestCase {
    func testSimplifiedChineseSystemNavigationDoesNotMixEnglish() {
        let app = launch(languageArgument: "--language-zh-Hans")
        revealSidebar(in: app, buttonLabel: "显示边栏")

        let expectedNavigation = [
            "sidebar-ledger": "记账",
            "sidebar-calendar": "日历",
            "sidebar-insights": "统计",
            "sidebar-settings": "设置"
        ]
        for (identifier, expected) in expectedNavigation {
            XCTAssertEqual(app.descendants(matching: .any)[identifier].label, expected, "缺少中文系统导航：\(expected)")
        }
        for forbidden in ["Ledger", "Settings", "General", "Appearance"] {
            XCTAssertFalse(app.staticTexts[forbidden].exists, "中文模式夹杂英文：\(forbidden)")
        }
    }

    func testEnglishSystemNavigationDoesNotMixChinese() {
        let app = launch(languageArgument: "--language-en")
        revealSidebar(in: app, buttonLabel: "Show Sidebar")

        let expectedNavigation = [
            "sidebar-ledger": "Ledger",
            "sidebar-calendar": "Calendar",
            "sidebar-insights": "Insights",
            "sidebar-settings": "Settings"
        ]
        for (identifier, expected) in expectedNavigation {
            XCTAssertEqual(app.descendants(matching: .any)[identifier].label, expected, "Missing English navigation: \(expected)")
        }
        for forbidden in ["记账", "日历", "统计", "设置"] {
            XCTAssertFalse(app.staticTexts[forbidden].exists, "English mode contains Chinese navigation: \(forbidden)")
        }
    }

    func testSettingsEntryCommandAndRequiredCategories() {
        let app = launch(languageArgument: "--language-zh-Hans")
        app.descendants(matching: .any)["sidebar-categories"].click()
        let expenseRows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "category-expense-")
        )
        let incomeRows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "category-income-")
        )
        XCTAssertEqual(expenseRows.count, 1)
        XCTAssertEqual(incomeRows.count, 1)
        XCTAssertTrue(app.buttons["category-add-expense"].exists)
        XCTAssertTrue(app.buttons["category-add-income"].exists)
        XCTAssertFalse(app.switches.matching(NSPredicate(format: "identifier BEGINSWITH %@", "category-hidden-")).firstMatch.exists)

        expenseRows.firstMatch.click()
        XCTAssertTrue(app.buttons["category-entries-back"].waitForExistence(timeout: 2))
        let header = app.descendants(matching: .any)["category-entries-header"]
        XCTAssertTrue(header.waitForExistence(timeout: 2))
        XCTAssertLessThan(header.frame.minY - app.windows.firstMatch.frame.minY, 120)
        XCTAssertTrue(app.staticTexts["空"].exists)
        app.buttons["category-entries-back"].click()

        app.buttons["sidebar-settings"].click()
        XCTAssertFalse(app.buttons["settings-open-categories"].exists)
        XCTAssertFalse(app.staticTexts["⌘,"].exists)
    }

    private func launch(languageArgument: String) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", languageArgument]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 3))
        return app
    }

    private func revealSidebar(in app: XCUIApplication, buttonLabel: String) {
        let ledger = app.descendants(matching: .any)["sidebar-ledger"]
        guard !ledger.exists else { return }
        let revealButton = app.buttons[buttonLabel]
        XCTAssertTrue(revealButton.waitForExistence(timeout: 2))
        revealButton.click()
        XCTAssertTrue(ledger.waitForExistence(timeout: 2))
    }
}
