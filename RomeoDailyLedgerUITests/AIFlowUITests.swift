import XCTest

@MainActor
final class AIFlowUITests: XCTestCase {
    func testAISettingsAndAllSettingsPagesUseReadableLeftAlignedDetailColumn() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--language-en"]
        app.launch()
        let settings = app.descendants(matching: .any)["sidebar-settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 3))
        settings.click()
        let aiPage = app.descendants(matching: .any)["settings-page-ai"]
        XCTAssertTrue(aiPage.waitForExistence(timeout: 3))
        aiPage.click()

        let apiKey = app.secureTextFields["settings-ai-api-key"]
        XCTAssertTrue(apiKey.waitForExistence(timeout: 3))
        XCTAssertTrue(apiKey.isHittable)
        XCTAssertTrue(app.textFields["settings-ai-model"].isHittable)
        XCTAssertFalse(app.textViews["settings-ai-custom-instructions"].exists)
        let window = app.windows.firstMatch
        XCTAssertLessThan(apiKey.frame.minX - window.frame.minX, window.frame.width * 0.72)
        XCTAssertLessThanOrEqual(apiKey.frame.maxX, window.frame.maxX - 20)
    }

    func testAIEntryShowsPreviewAndSavesOnlyAfterConfirmation() {
        let app = launchApp()
        app.descendants(matching: .any)["sidebar-aiAssistant"].click()
        let prompt = app.textViews["ai-prompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 2))
        prompt.click()
        prompt.typeText("Lunch $25")
        prompt.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(app.descendants(matching: .any)["ai-preview"].waitForExistence(timeout: 2))
        app.descendants(matching: .any)["ai-preview-cancel"].click()
        app.descendants(matching: .any)["sidebar-ledger"].click()
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "UI Test Lunch")).firstMatch.exists)

        app.descendants(matching: .any)["sidebar-aiAssistant"].click()
        let secondPrompt = app.textViews["ai-prompt"]
        secondPrompt.click()
        secondPrompt.typeText("Lunch $25")
        app.buttons["ai-generate"].click()
        XCTAssertTrue(app.descendants(matching: .any)["ai-preview"].waitForExistence(timeout: 2))
        let confirm = app.descendants(matching: .any)["ai-confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 2))
        confirm.click()
        app.descendants(matching: .any)["sidebar-ledger"].click()

        let saved = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "UI Test Lunch")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 2))
    }

    func testAIAnalysisUsesMultilineQuestionAndAdaptiveResultWithoutPermissionGate() {
        let app = launchApp()
        app.descendants(matching: .any)["sidebar-aiAssistant"].click()
        app.buttons["ai-mode-analysis"].click()

        XCTAssertTrue(app.descendants(matching: .any)["ai-analysis-scope"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.descendants(matching: .any)["ai-permission-scope"].exists)
        let question = app.textViews["ai-analysis-question"]
        XCTAssertTrue(question.waitForExistence(timeout: 2))
        question.click()
        question.typeText("How am I doing this month?")
        XCTAssertTrue(app.buttons["ai-analyze"].isEnabled)
        app.buttons["ai-analyze"].click()
        XCTAssertTrue(app.descendants(matching: .any)["ai-analysis-result"].waitForExistence(timeout: 5))
    }

    func testAISettingsRunsConnectionTest() {
        let app = launchApp()
        app.descendants(matching: .any)["sidebar-settings"].click()
        app.descendants(matching: .any)["settings-page-ai"].click()

        XCTAssertTrue(app.secureTextFields["settings-ai-api-key"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.switches["settings-ai-allow-ledger"].exists)
        XCTAssertFalse(app.buttons["settings-ai-save"].exists)
        XCTAssertFalse(app.textViews["settings-ai-custom-instructions"].exists)
        let apiKey = app.secureTextFields["settings-ai-api-key"]
        apiKey.click()
        apiKey.typeText("auto-saved-key")
        app.descendants(matching: .any)["settings-page-general"].click()
        app.descendants(matching: .any)["settings-page-ai"].click()
        XCTAssertNotEqual(app.secureTextFields["settings-ai-api-key"].value as? String, "")
        app.textFields["settings-ai-model"].click()
        app.textFields["settings-ai-model"].typeText("ui-test-model")
        app.buttons["settings-ai-test"].click()
        XCTAssertTrue(app.staticTexts["settings-ai-status"].waitForExistence(timeout: 2))
    }

    private func launchApp() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--language-en"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        return app
    }
}
