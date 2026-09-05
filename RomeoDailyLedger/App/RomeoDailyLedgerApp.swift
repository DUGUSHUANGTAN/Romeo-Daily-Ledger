import AppKit
import SwiftUI

enum AppIdentity {
    static let chineseName = "罗密欧每日记账"
    static let englishName = "Romeo Daily Ledger"
}

@main
struct RomeoDailyLedgerApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var lifecycleDelegate
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
        }
        .defaultSize(width: 1_100, height: 700)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(Bundle.main.localizedString(forKey: "command.openSettings", value: "Open Settings", table: "Localizable")) {
                    dependencies.selectedDestination = .settings
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first(where: \.canBecomeMain)?.makeKeyAndOrderFront(nil)
                }
                .keyboardShortcut(AppCommands.settingsShortcutKey, modifiers: .command)
            }
            CommandGroup(replacing: .appInfo) {
                Button(Bundle.main.localizedString(forKey: "command.about", value: "About \(AppIdentity.englishName)", table: "Localizable")) {
                    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1.0"
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: AppLocalization.text("app.name", language: dependencies.preferences.language),
                        .version: AppLocalization.format("app.version", language: dependencies.preferences.language, version)
                    ])
                }
            }
        }

    }
}

final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLocalization.updateApplicationMenuTitle(
            in: NSApp.mainMenu,
            language: AppPreferences.persistedLanguage()
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
