import AppKit
import XCTest
@testable import RomeoDailyLedger

final class AppLaunchTests: XCTestCase {
    private final class SwiftUIMenuItem: NSMenuItem {}
    private final class MenuDelegate: NSObject, NSMenuDelegate {}

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
        XCTAssertEqual(menu.items.first?.title, "罗密欧每日记账")
        XCTAssertEqual(menu.items.first?.submenu?.title, "罗密欧每日记账")

        AppLocalization.updateApplicationMenuTitle(in: menu, language: .traditionalChinese)
        XCTAssertEqual(menu.items.first?.title, "羅密歐每日記賬")
        XCTAssertEqual(menu.items.first?.submenu?.title, "羅密歐每日記賬")

        AppLocalization.updateApplicationMenuTitle(in: menu, language: .english)
        XCTAssertEqual(menu.items.first?.title, "Romeo Daily Ledger")
        XCTAssertEqual(menu.items.first?.submenu?.title, "Romeo Daily Ledger")
    }

    @MainActor
    func testApplicationMenuReattachesInstalledDelegateAfterRebuild() {
        let delegate = MenuDelegate()
        let menu = applicationMenu(named: AppIdentity.englishName)

        AppLocalization.installApplicationMenuDelegate(delegate)
        AppLocalization.updateApplicationMenuTitle(in: menu, language: .english)

        XCTAssertTrue(menu.items.first?.submenu?.delegate === delegate)
    }

    @MainActor
    func testApplicationMenuLocalizationKeepsSwiftUIItemAndSubmenu() {
        let menu = NSMenu()
        let appItem = SwiftUIMenuItem(title: AppIdentity.englishName, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: AppIdentity.englishName)
        submenu.addItem(withTitle: "关于\(AppIdentity.englishName)", action: nil, keyEquivalent: "")
        appItem.submenu = submenu
        menu.addItem(appItem)

        AppLocalization.updateApplicationMenuTitle(in: menu, language: .traditionalChinese)

        XCTAssertTrue(menu.items.first === appItem)
        XCTAssertTrue(menu.items.first?.submenu === submenu)
        XCTAssertEqual(menu.items.first?.submenu?.items.count, 1)
        XCTAssertEqual(menu.items.first?.title, "羅密歐每日記賬")
        XCTAssertEqual(menu.items.first?.submenu?.items.first?.title, "关于羅密歐每日記賬")
    }

    @MainActor
    func testApplicationMenuWaitsUntilSwiftUIPopulatesSubmenu() {
        let menu = NSMenu()
        let appItem = SwiftUIMenuItem(title: AppIdentity.englishName, action: nil, keyEquivalent: "")
        appItem.submenu = NSMenu(title: AppIdentity.englishName)
        menu.addItem(appItem)

        AppLocalization.updateApplicationMenuTitle(in: menu, language: .traditionalChinese)

        XCTAssertTrue(menu.items.first === appItem)
    }

    @MainActor
    func testWindowTitleUsesTheCurrentPageInsteadOfAlwaysUsingTheAppName() {
        XCTAssertEqual(SidebarDestination.ledger.windowTitle(language: .english), AppIdentity.englishName)
        XCTAssertEqual(SidebarDestination.aiAssistant.windowTitle(language: .english), AppIdentity.englishName)
        XCTAssertEqual(SidebarDestination.calendar.windowTitle(language: .english), AppIdentity.englishName)
        XCTAssertEqual(SidebarDestination.insights.windowTitle(language: .english), AppIdentity.englishName)
        XCTAssertEqual(SidebarDestination.history.windowTitle(language: .english), AppIdentity.englishName)
        XCTAssertEqual(SidebarDestination.categories.windowTitle(language: .english), AppIdentity.englishName)
        XCTAssertEqual(SidebarDestination.settings.windowTitle(language: .english), "Settings")
        XCTAssertEqual(SidebarDestination.settings.windowTitle(language: .traditionalChinese), "設置")
    }

    @MainActor
    func testWindowTitleFollowsSelectedLanguage() {
        let window = NSWindow()

        AppLocalization.updateWindowTitle(in: window, language: .english)
        XCTAssertEqual(window.title, AppIdentity.englishName)

        AppLocalization.updateWindowTitle(in: window, language: .traditionalChinese)
        XCTAssertEqual(window.title, "羅密歐每日記賬")
    }

    @MainActor
    func testRebuiltApplicationMenuReusesCurrentAppLanguage() {
        let originalMenu = applicationMenu(named: AppIdentity.englishName)
        AppLocalization.updateApplicationMenuTitle(in: originalMenu, language: .english)

        let rebuiltMenu = applicationMenu(named: AppIdentity.englishName)
        rebuiltMenu.items.first?.submenu?.addItem(
            withTitle: "关于\(AppIdentity.englishName)",
            action: nil,
            keyEquivalent: ""
        )
        rebuiltMenu.items.first?.submenu?.items.first?.attributedTitle = NSAttributedString(
            string: "关于\(AppIdentity.chineseName)"
        )

        AppLocalization.refreshApplicationMenuTitle(in: rebuiltMenu)

        XCTAssertEqual(rebuiltMenu.items.first?.title, AppIdentity.englishName)
        XCTAssertEqual(rebuiltMenu.items.first?.submenu?.items.first?.title, "关于\(AppIdentity.englishName)")
        XCTAssertEqual(
            rebuiltMenu.items.first?.submenu?.items.first?.attributedTitle?.string,
            "关于\(AppIdentity.englishName)"
        )
    }

    @MainActor
    func testApplicationMenuRefreshKeepsCustomCommandActionAlive() {
        let menu = applicationMenu(named: "羅密歐每日記賬")
        let item = SwiftUIMenuItem(title: "关于羅密歐每日記賬", action: nil, keyEquivalent: "")
        item.attributedTitle = NSAttributedString(string: "关于罗密欧每日记账")
        menu.items.first?.submenu?.addItem(item)

        AppLocalization.updateApplicationMenuTitle(in: menu, language: .traditionalChinese)

        let refreshedItem = menu.items.first?.submenu?.items.first
        XCTAssertTrue(refreshedItem === item)
        XCTAssertEqual(refreshedItem?.title, "关于羅密歐每日記賬")
        XCTAssertEqual(refreshedItem?.attributedTitle?.string, "关于羅密歐每日記賬")
    }

    @MainActor
    func testApplicationMenuRefreshPreservesStandardMenuActions() {
        let menu = applicationMenu(named: AppIdentity.chineseName)
        let hideItem = NSMenuItem(
            title: "隐藏\(AppIdentity.chineseName)",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        let quitItem = NSMenuItem(
            title: "退出\(AppIdentity.chineseName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.items.first?.submenu?.addItem(hideItem)
        menu.items.first?.submenu?.addItem(quitItem)

        AppLocalization.updateApplicationMenuTitle(in: menu, language: .english)

        let refreshedHideItem = menu.items.first?.submenu?.items[0]
        let refreshedQuitItem = menu.items.first?.submenu?.items[1]
        XCTAssertEqual(refreshedHideItem?.action, #selector(NSApplication.hide(_:)))
        XCTAssertEqual(refreshedQuitItem?.action, #selector(NSApplication.terminate(_:)))
        XCTAssertEqual(refreshedHideItem?.title, "隐藏\(AppIdentity.englishName)")
        XCTAssertEqual(refreshedQuitItem?.title, "退出\(AppIdentity.englishName)")
    }

    func testSystemMenuPrefixIsKeptWhileOnlyTheApplicationNameChanges() {
        XCTAssertEqual(
            AppLocalization.replacingApplicationName(
                in: "关于罗密欧每日记账",
                language: .english
            ),
            "关于Romeo Daily Ledger"
        )
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


    private func applicationMenu(named name: String) -> NSMenu {
        let menu = NSMenu()
        let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
        item.submenu = NSMenu(title: name)
        menu.addItem(item)
        return menu
    }
}
