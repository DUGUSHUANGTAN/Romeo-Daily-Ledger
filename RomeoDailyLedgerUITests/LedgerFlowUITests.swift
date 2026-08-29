import XCTest

@MainActor
final class LedgerFlowUITests: XCTestCase {
    func testCreateAndEditEntry() {
        let app = launchApp()
        addEntry(in: app, amount: "12.50", kind: "支出", note: "午餐")
        let createdRow = entryRow(in: app, containing: "午餐")
        XCTAssertTrue(createdRow.label.contains("$12.50"))

        createdRow.doubleClick()
        let amount = app.textFields["editor-amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 2))
        amount.click()
        amount.typeKey("a", modifierFlags: .command)
        amount.typeText("20.25")
        app.buttons["editor-kind-income"].click()
        app.textFields["editor-note"].click()
        app.textFields["editor-note"].typeKey("a", modifierFlags: .command)
        app.textFields["editor-note"].typeText("退款")
        app.buttons["editor-save"].click()

        let editedRow = entryRow(in: app, containing: "退款")
        XCTAssertTrue(editedRow.waitForExistence(timeout: 2))
        XCTAssertTrue(editedRow.label.contains("$20.25"))
    }

    func testMultiSelectionShowsIncomeExpenseAndNet() {
        let app = launchApp()
        addEntry(in: app, amount: "100", kind: "收入", note: "兼职")
        addEntry(in: app, amount: "30", kind: "支出", note: "交通")

        entryRow(in: app, containing: "兼职").click()
        entryRow(in: app, containing: "交通").click()

        XCTAssertTrue(app.descendants(matching: .any)["selection-summary-bar"].waitForExistence(timeout: 2))
        XCTAssertTrue(entryRow(in: app, containing: "兼职").isSelected)
        XCTAssertTrue(entryRow(in: app, containing: "交通").isSelected)
        XCTAssertTrue(app.staticTexts["收入 $100.00"].exists)
        XCTAssertTrue(app.staticTexts["支出 $30.00"].exists)
        XCTAssertTrue(app.staticTexts["净额 $70.00"].exists)
    }

    func testDeleteAndUndoRestoresEntry() {
        let app = launchApp()
        addEntry(in: app, amount: "8.80", kind: "支出", note: "咖啡")
        entryRow(in: app, containing: "咖啡").click()
        app.buttons["delete-selected-entries"].click()
        XCTAssertTrue(app.buttons["confirm-delete-selected"].waitForExistence(timeout: 2))
        XCTAssertTrue(entryRow(in: app, containing: "咖啡").exists)
        app.buttons["confirm-delete-selected"].click()
        XCTAssertFalse(entryRow(in: app, containing: "咖啡").exists)

        XCTAssertTrue(app.buttons["undo-delete"].waitForExistence(timeout: 2))
        app.buttons["undo-delete"].click()
        XCTAssertTrue(entryRow(in: app, containing: "咖啡").waitForExistence(timeout: 2))
    }

    func testUndoEntryExpires() {
        let app = launchApp()
        addEntry(in: app, amount: "6.60", kind: "支出", note: "过期撤销")
        entryRow(in: app, containing: "过期撤销").click()
        app.buttons["delete-selected-entries"].click()
        XCTAssertTrue(app.buttons["confirm-delete-selected"].waitForExistence(timeout: 2))
        app.buttons["confirm-delete-selected"].click()
        XCTAssertTrue(app.buttons["undo-delete"].waitForExistence(timeout: 2))

        Thread.sleep(forTimeInterval: 6)

        XCTAssertFalse(app.buttons["undo-delete"].exists)
    }

    func testCalendarFiltersEntriesBySelectedLocalDay() {
        let app = launchApp()
        addEntry(in: app, amount: "9.90", kind: "支出", note: "今日筛选")
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(app.descendants(matching: .any)["calendar-grid"].waitForExistence(timeout: 2))
        let todayIdentifier = "calendar-day-\(Int(Calendar.autoupdatingCurrent.startOfDay(for: .now).timeIntervalSince1970))"
        let anotherDay = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND identifier != %@", "calendar-day-", todayIdentifier))
            .firstMatch
        XCTAssertTrue(anotherDay.waitForExistence(timeout: 2))
        anotherDay.click()
        XCTAssertTrue(anotherDay.isSelected)
        XCTAssertTrue(app.staticTexts["calendar-empty-state"].waitForExistence(timeout: 2))

        app.buttons["calendar-today"].click()
        XCTAssertTrue(app.staticTexts["当日收入 $0.00"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["当日支出 $9.90"].exists)
        let calendarEntry = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "calendar-entry-"))
            .firstMatch
        XCTAssertTrue(calendarEntry.waitForExistence(timeout: 2))
        XCTAssertTrue(calendarEntry.label.contains("支出"))
        calendarEntry.click()
        XCTAssertTrue(app.textFields["editor-amount"].waitForExistence(timeout: 2))
    }

    func testFailedInputKeepsContents() {
        let app = launchApp()
        app.textFields["quick-entry-amount"].click()
        app.textFields["quick-entry-amount"].typeText("abc")
        app.textFields["quick-entry-note"].click()
        app.textFields["quick-entry-note"].typeText("保留这段内容")
        app.buttons["quick-entry-save"].click()

        XCTAssertEqual(app.textFields["quick-entry-amount"].value as? String, "abc")
        XCTAssertEqual(app.textFields["quick-entry-note"].value as? String, "保留这段内容")
        XCTAssertTrue(app.staticTexts["quick-entry-error"].waitForExistence(timeout: 2))
    }

    private func launchApp() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 3))
        return app
    }

    private func addEntry(in app: XCUIApplication, amount: String, kind: String, note: String) {
        let kindButton = app.buttons["quick-entry-kind-\(kind == "收入" ? "income" : "expense")"]
        kindButton.click()
        XCTAssertTrue(kindButton.isSelected)
        let amountField = app.textFields["quick-entry-amount"]
        amountField.click()
        amountField.typeText(amount)
        let noteField = app.textFields["quick-entry-note"]
        noteField.click()
        noteField.typeText(note)
        app.buttons["quick-entry-save"].click()
        let matchingRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", note)).firstMatch
        XCTAssertTrue(matchingRow.waitForExistence(timeout: 2))
    }

    private func entryRow(in app: XCUIApplication, containing text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "entry-row-", text)).firstMatch
    }
}
