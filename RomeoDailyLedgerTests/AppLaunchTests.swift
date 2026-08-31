import XCTest
@testable import RomeoDailyLedger

final class AppLaunchTests: XCTestCase {
    func testEnglishAndChineseNamesAreDefined() {
        XCTAssertEqual(AppIdentity.chineseName, "罗密欧每日记账")
        XCTAssertEqual(AppIdentity.englishName, "Romeo Daily Ledger")
    }

    @MainActor
    func testApplicationTerminatesOnlyAfterTheLastWindowCloses() {
        XCTAssertTrue(AppLifecycleDelegate().applicationShouldTerminateAfterLastWindowClosed(.shared))
    }

    func testStorageFailureProducesRecoveryStateInsteadOfOpeningLedger() {
        let state = AppLaunchState(storageError: CocoaError(.fileReadCorruptFile))
        XCTAssertNotNil(state.recoveryMessage)
        XCTAssertFalse(state.canOpenLedger)
    }
}
