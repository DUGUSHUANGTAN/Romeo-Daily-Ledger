import XCTest

@MainActor
final class AIFlowUITests: XCTestCase {
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

        XCTAssertTrue(app.descendants(matching: .any)["settings-ai"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.switches["settings-ai-allow-ledger"].exists)
        XCTAssertFalse(app.buttons["settings-ai-save"].exists)
        XCTAssertTrue(app.textViews["settings-ai-custom-instructions"].waitForExistence(timeout: 2))
        let apiKey = app.textFields["settings-ai-api-key"]
        apiKey.click()
        apiKey.typeText("auto-saved-key")
        app.descendants(matching: .any)["settings-page-general"].click()
        app.descendants(matching: .any)["settings-page-ai"].click()
        XCTAssertEqual(app.textFields["settings-ai-api-key"].value as? String, "auto-saved-key")
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
