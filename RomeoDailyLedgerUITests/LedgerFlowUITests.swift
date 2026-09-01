import XCTest

@MainActor
final class LedgerFlowUITests: XCTestCase {
    func testCreateAndEditEntry() {
        let app = launchApp()
        addEntry(in: app, amount: "12.50", kind: "支出", note: "午餐")
        let createdRow = entryRow(in: app, containing: "午餐")
        XCTAssertTrue(createdRow.label.contains("$12.50"))

        createdRow.click()
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

        entryRow(in: app, containing: "兼职").press(forDuration: 0.6)
        entryRow(in: app, containing: "交通").click()

        XCTAssertTrue(app.descendants(matching: .any)["selection-summary-bar"].waitForExistence(timeout: 2))
        XCTAssertTrue(entryRow(in: app, containing: "兼职").isSelected)
        XCTAssertTrue(entryRow(in: app, containing: "交通").isSelected)
        XCTAssertTrue(app.staticTexts["收入 $100.00"].exists)
        XCTAssertTrue(app.staticTexts["支出 $30.00"].exists)
        XCTAssertTrue(app.staticTexts["净额 $70.00"].exists)
        XCTAssertTrue(app.buttons["cancel-entry-selection"].exists)
        app.buttons["cancel-entry-selection"].click()
        XCTAssertFalse(app.descendants(matching: .any)["selection-summary-bar"].exists)
    }

    func testDeleteRequiresConfirmationAndDoesNotOfferUndo() {
        let app = launchApp()
        addEntry(in: app, amount: "8.80", kind: "支出", note: "咖啡")
        entryRow(in: app, containing: "咖啡").press(forDuration: 0.6)
        app.buttons["delete-selected-entries"].click()
        XCTAssertTrue(app.buttons["confirm-delete-selected"].waitForExistence(timeout: 2))
        XCTAssertTrue(entryRow(in: app, containing: "咖啡").exists)
        app.buttons["confirm-delete-selected"].click()
        XCTAssertFalse(entryRow(in: app, containing: "咖啡").exists)

        XCTAssertFalse(app.buttons["undo-delete"].exists)
    }

    func testCancellingDeletionKeepsEntry() {
        let app = launchApp()
        addEntry(in: app, amount: "6.60", kind: "支出", note: "过期撤销")
        entryRow(in: app, containing: "过期撤销").press(forDuration: 0.6)
        app.buttons["delete-selected-entries"].click()
        XCTAssertTrue(app.buttons["confirm-delete-selected"].waitForExistence(timeout: 2))
        app.sheets.buttons["取消"].click()
        XCTAssertTrue(entryRow(in: app, containing: "过期撤销").exists)
    }

    func testCalendarFiltersEntriesBySelectedLocalDay() {
        let app = launchApp()
        addEntry(in: app, amount: "9.90", kind: "支出", note: "今日筛选")
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(app.descendants(matching: .any)["calendar-page-scroll"].waitForExistence(timeout: 2))
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
        let calendarEntry = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "calendar-entry-"))
            .firstMatch
        XCTAssertTrue(calendarEntry.waitForExistence(timeout: 2))
        XCTAssertTrue(calendarEntry.label.contains("支出"))
        calendarEntry.click()
        XCTAssertTrue(app.textFields["editor-amount"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.popUpButtons["editor-category"].exists)
    }

    func testFailedInputKeepsContents() {
        let app = launchApp()
        app.textFields["quick-entry-amount"].click()
        app.textFields["quick-entry-amount"].typeText("abc")
        app.textViews["quick-entry-note"].click()
        app.textViews["quick-entry-note"].typeText("保留这段内容")
        app.buttons["quick-entry-save"].click()

        XCTAssertEqual(app.textFields["quick-entry-amount"].value as? String, "abc")
        XCTAssertEqual(app.textViews["quick-entry-note"].value as? String, "保留这段内容")
        XCTAssertTrue(app.staticTexts["quick-entry-error"].waitForExistence(timeout: 2))
    }

    func testInsightsEmptyStateKeepsBothChartsUnderstandableWithoutColor() {
        let app = launchApp()

        app.typeKey("3", modifierFlags: .command)

        XCTAssertTrue(app.staticTexts["insights-month-summary"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["insights-monthly-empty-state"].exists)
        XCTAssertTrue(app.staticTexts["insights-category-empty-state"].exists)
        XCTAssertFalse(app.buttons["insights-previous-month"].exists)
        XCTAssertFalse(app.buttons["insights-next-month"].exists)
    }

    func testHistoryIsAnIndependentSidebarDestination() {
        let app = launchApp()
        app.descendants(matching: .any)["sidebar-history"].click()
        XCTAssertTrue(app.scrollViews["history-list"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["history-search"].exists)
        XCTAssertFalse(app.buttons["ledger-show-all"].exists)
    }

    func testHistorySingleClickOpensEditor() {
        let app = launchApp()
        addEntry(in: app, amount: "15.00", kind: "支出", note: "全部账目编辑")
        app.descendants(matching: .any)["sidebar-history"].click()
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "history-entry-", "全部账目编辑"))
            .firstMatch

        XCTAssertTrue(row.waitForExistence(timeout: 2))
        row.click()
        XCTAssertTrue(app.textFields["editor-amount"].waitForExistence(timeout: 2))
    }

    func testHistorySearchAndLongPressSelection() {
        let app = launchApp()
        addEntry(in: app, amount: "100", kind: "收入", note: "全部收入")
        addEntry(in: app, amount: "30", kind: "支出", note: "全部支出")
        app.descendants(matching: .any)["sidebar-history"].click()
        app.textFields["history-search"].click()
        app.textFields["history-search"].typeText("全部")
        let income = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "history-entry-", "全部收入")).firstMatch
        let expense = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "history-entry-", "全部支出")).firstMatch
        XCTAssertTrue(income.waitForExistence(timeout: 2))
        income.press(forDuration: 0.6)
        expense.click()
        XCTAssertTrue(app.descendants(matching: .any)["history-selection-summary"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["delete-selected-entries"].exists)
        XCTAssertTrue(app.staticTexts["净额 $70.00"].exists)
    }

    func testLeavingLedgerCancelsLongPressSelectionMode() {
        let app = launchApp()
        addEntry(in: app, amount: "5", kind: "支出", note: "切页清空")
        entryRow(in: app, containing: "切页清空").press(forDuration: 0.6)
        XCTAssertTrue(app.descendants(matching: .any)["selection-summary-bar"].waitForExistence(timeout: 2))
        app.typeKey("2", modifierFlags: .command)
        app.typeKey("1", modifierFlags: .command)
        XCTAssertFalse(app.descendants(matching: .any)["selection-summary-bar"].exists)
    }

    func testCategoryEntriesUseClickToEditAndLongPressToManage() {
        let app = launchApp()
        addEntry(in: app, amount: "18", kind: "支出", note: "分类内批量")
        app.descendants(matching: .any)["sidebar-categories"].click()
        let expenseOther = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "category-expense-", "其他"))
            .firstMatch
        XCTAssertTrue(expenseOther.waitForExistence(timeout: 2))
        expenseOther.click()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "category-entry-", "分类内批量")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 2))
        row.click()
        XCTAssertTrue(app.textFields["editor-amount"].waitForExistence(timeout: 2))
        app.buttons["editor-cancel"].click()
        row.press(forDuration: 0.6)
        XCTAssertTrue(app.descendants(matching: .any)["category-selection-summary"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["delete-selected-entries"].exists)
    }

    func testCalendarAndInsightsUseTypedYearsWithoutAdjacentMonthButtons() {
        let app = launchApp()
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(app.textFields["calendar-year"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.popUpButtons["calendar-month"].exists)
        XCTAssertFalse(app.buttons["calendar-previous-month"].exists)
        XCTAssertFalse(app.buttons["calendar-next-month"].exists)
        app.typeKey("3", modifierFlags: .command)
        XCTAssertTrue(app.textFields["insights-year"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.popUpButtons["insights-month"].exists)
        XCTAssertFalse(app.buttons["insights-previous-month"].exists)
        XCTAssertFalse(app.buttons["insights-next-month"].exists)
        XCTAssertTrue(app.buttons["insights-current-month"].exists)
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
        let noteField = app.textViews["quick-entry-note"]
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
