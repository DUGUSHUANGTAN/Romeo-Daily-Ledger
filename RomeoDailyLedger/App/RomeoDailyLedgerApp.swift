import SwiftUI

enum AppIdentity {
    static let chineseName = "罗密欧每日记账"
    static let englishName = "Romeo Daily Ledger"
}

@main
struct RomeoDailyLedgerApp: App {
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
        }
        .defaultSize(width: 1_100, height: 700)
        .commands {
            CommandGroup(replacing: .appSettings) {
                SettingsLink {
                    Text(AppLocalization.text("command.openSettings", language: dependencies.preferences.language))
                }
                .keyboardShortcut(AppCommands.settingsShortcutKey, modifiers: .command)
            }
        }

        Settings {
            SettingsRootView(dependencies: dependencies)
        }
    }
}
