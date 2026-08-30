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
        app.typeKey(",", modifierFlags: .command)

        XCTAssertTrue(app.buttons["settings-open-categories"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["settings-check-for-updates"].exists)
        app.buttons["settings-check-for-updates"].click()
        XCTAssertTrue(app.staticTexts["检查更新"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["1.0.0"].exists)
        app.buttons["关闭"].click()
        XCTAssertFalse(app.staticTexts["⌘,"].exists)
        app.staticTexts["settings-page-categories"].click()
        XCTAssertTrue(app.descendants(matching: .any)["settings-categories"].waitForExistence(timeout: 2))
        for category in ["衣", "食", "住", "行", "娱乐", "其他", "工资", "奖金", "投资", "退款"] {
            XCTAssertTrue(app.staticTexts[category].exists, "缺少内置分类：\(category)")
        }
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
