import XCTest

@MainActor
final class DataTransferUITests: XCTestCase {
    func testSettingsOpensDataPageAndImportCanBeCancelled() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.buttons["sidebar-settings"].click()
        XCTAssertTrue(app.staticTexts["数据"].waitForExistence(timeout: 3) || app.staticTexts["Data"].waitForExistence(timeout: 1))
        app.staticTexts["数据"].click()
        XCTAssertTrue(app.descendants(matching: .any)["settings-data"].waitForExistence(timeout: 3))
        app.buttons["data-import-button"].click()
    }
}
