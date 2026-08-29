import SwiftUI

enum AppIdentity {
    static let chineseName = "罗密欧每日记账"
    static let englishName = "Romeo Daily Ledger"
}

@main
struct RomeoDailyLedgerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .defaultSize(width: 1_100, height: 700)

        Settings {
            Text("Settings")
        }
    }
}
