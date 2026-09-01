import AppKit
import XCTest

@MainActor
final class DataTransferUITests: XCTestCase {
    func testThemeSelectionUpdatesImmediatelyAndSystemRestoresCurrentAppearance() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.typeKey(",", modifierFlags: .command)
        let appearancePage = app.descendants(matching: .any)["settings-page-appearance"]
        XCTAssertTrue(appearancePage.waitForExistence(timeout: 3))
        appearancePage.click()

        let dark = app.radioButtons["深色"]
        XCTAssertTrue(dark.waitForExistence(timeout: 3))
        dark.click()
        XCTAssertEqual(dark.value as? String, "1")

        let followSystem = app.radioButtons["跟随系统"]
        followSystem.click()
        XCTAssertEqual(followSystem.value as? String, "1")
    }

    func testEraseAllAppearsOnlyOnDataPageAndUsesDestructiveStyling() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.buttons["sidebar-settings"].click()

        XCTAssertFalse(app.buttons["settings-erase-all"].exists)
        let dataPage = app.descendants(matching: .any)["settings-page-data"]
        XCTAssertTrue(dataPage.waitForExistence(timeout: 3))
        dataPage.click()
        let erase = app.buttons["settings-erase-all"]
        XCTAssertTrue(erase.waitForExistence(timeout: 3))
        XCTAssertEqual(erase.value as? String, "destructive")
    }

    func testCurrencyIsOneEditableControlAndReturnCommitsIt() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.buttons["sidebar-settings"].click()

        let currency = app.descendants(matching: .any)["settings-currency"]
        XCTAssertTrue(currency.waitForExistence(timeout: 3))
        XCTAssertEqual(currency.elementType, .textField)
        XCTAssertFalse(app.popUpButtons["settings-currency"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings-currency-options"].exists)
        currency.click()
        currency.typeKey("a", modifierFlags: .command)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("hkd", forType: .string)
        currency.typeKey("v", modifierFlags: .command)
        currency.typeKey(.return, modifierFlags: [])
        XCTAssertEqual(currency.value as? String, "HKD")
    }

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
