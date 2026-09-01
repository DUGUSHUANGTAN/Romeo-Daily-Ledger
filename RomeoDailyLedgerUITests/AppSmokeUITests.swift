import XCTest

final class AppSmokeUITests: XCTestCase {
    func testApplicationLaunches() {
        let application = XCUIApplication()

        application.launch()

        XCTAssertTrue(application.wait(for: .runningForeground, timeout: 5))
    }

    func testSidebarShowsCurrentVersionInLowerLeft() {
        let application = XCUIApplication()
        application.launchArguments = ["--ui-testing"]
        application.launch()

        let version = application.staticTexts["V1.0.2"]
        XCTAssertTrue(version.waitForExistence(timeout: 3))
    }
}
