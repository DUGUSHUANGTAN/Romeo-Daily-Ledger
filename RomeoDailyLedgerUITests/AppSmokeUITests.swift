import XCTest

final class AppSmokeUITests: XCTestCase {
    func testApplicationLaunches() {
        let application = XCUIApplication()

        application.launch()

        XCTAssertTrue(application.wait(for: .runningForeground, timeout: 5))
    }
}
