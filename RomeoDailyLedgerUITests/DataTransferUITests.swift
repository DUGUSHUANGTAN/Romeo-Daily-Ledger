import XCTest

@MainActor
final class DataTransferUITests: XCTestCase {
    func testSettingsOpensDataPageAndImportCanBeCancelled() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.buttons["sidebar-settings"].click()
        let dataPage = app.descendants(matching: .any)["settings-page-data"]
        XCTAssertTrue(dataPage.waitForExistence(timeout: 3))
        dataPage.click()
        XCTAssertTrue(app.descendants(matching: .any)["settings-data"].waitForExistence(timeout: 3))
        app.buttons["data-import-button"].click()
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(app.buttons["data-import-button"].waitForExistence(timeout: 2))
    }

    func testImportPreviewCanBeCancelledAndExportPanelCanOpen() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--language-en", "--ui-testing-data-preview"]
        app.launch()
        app.descendants(matching: .any)["sidebar-settings"].click()
        app.descendants(matching: .any)["settings-page-data"].click()

        XCTAssertTrue(app.descendants(matching: .any)["data-import-preview"].waitForExistence(timeout: 3))
        app.buttons["data-import-cancel"].click()
        XCTAssertFalse(app.descendants(matching: .any)["data-import-preview"].exists)

        app.buttons["data-export-json"].click()
        sleep(1)
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(app.descendants(matching: .any)["settings-data"].exists)
    }
}
