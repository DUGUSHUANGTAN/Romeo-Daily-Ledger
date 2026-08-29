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

        Settings {
            Text("Settings")
        }
    }
}
