import AppKit
import XCTest
@testable import RomeoDailyLedger

final class AppLaunchTests: XCTestCase {
    private final class SwiftUIMenuItem: NSMenuItem {}

    func testEnglishAndChineseNamesAreDefined() {
        XCTAssertEqual(AppIdentity.chineseName, "罗密欧每日记账")
        XCTAssertEqual(AppIdentity.englishName, "Romeo Daily Ledger")
        XCTAssertEqual(Bundle(for: AppLifecycleDelegate.self).object(forInfoDictionaryKey: "CFBundleName") as? String, "罗密欧每日记账")
    }

    @MainActor
    func testApplicationMenuNameFollowsSelectedLanguage() {
        let menu = NSMenu()
        let appItem = NSMenuItem(title: AppIdentity.englishName, action: nil, keyEquivalent: "")
        appItem.submenu = NSMenu(title: AppIdentity.englishName)
        menu.addItem(appItem)

        AppLocalization.updateApplicationMenuTitle(in: menu, language: .simplifiedChinese)
        XCTAssertEqual(appItem.title, "罗密欧每日记账")
        XCTAssertEqual(appItem.submenu?.title, "罗密欧每日记账")

        AppLocalization.updateApplicationMenuTitle(in: menu, language: .traditionalChinese)
        XCTAssertEqual(appItem.title, "羅密歐每日記賬")
        XCTAssertEqual(appItem.submenu?.title, "羅密歐每日記賬")

        AppLocalization.updateApplicationMenuTitle(in: menu, language: .english)
        XCTAssertEqual(appItem.title, "Romeo Daily Ledger")
        XCTAssertEqual(appItem.submenu?.title, "Romeo Daily Ledger")
    }

    @MainActor
    func testApplicationMenuLocalizationKeepsSwiftUISubmenu() {
        let menu = NSMenu()
        let appItem = SwiftUIMenuItem(title: AppIdentity.englishName, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: AppIdentity.englishName)
        submenu.addItem(withTitle: "About", action: nil, keyEquivalent: "")
        appItem.submenu = submenu
        menu.addItem(appItem)

        AppLocalization.updateApplicationMenuTitle(in: menu, language: .simplifiedChinese)

        XCTAssertTrue(menu.items.first === appItem)
        XCTAssertTrue(menu.items.first?.submenu === submenu)
        XCTAssertEqual(menu.items.first?.submenu?.items.count, 1)
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
