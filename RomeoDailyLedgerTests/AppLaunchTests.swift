import XCTest
@testable import RomeoDailyLedger

final class AppLaunchTests: XCTestCase {
    func testEnglishAndChineseNamesAreDefined() {
        XCTAssertEqual(AppIdentity.chineseName, "罗密欧每日记账")
        XCTAssertEqual(AppIdentity.englishName, "Romeo Daily Ledger")
    }
}
