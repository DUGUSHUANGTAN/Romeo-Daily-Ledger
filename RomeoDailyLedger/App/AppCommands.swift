import SwiftUI

struct AppCommands: View {
    @Bindable var dependencies: AppDependencies

    var body: some View {
        Group {
            Button("打开记账") { dependencies.selectedDestination = .ledger }
                .keyboardShortcut("1", modifiers: .command)
            Button("打开日历") { dependencies.selectedDestination = .calendar }
                .keyboardShortcut("2", modifiers: .command)
            Button("打开设置") { dependencies.selectedDestination = .settings }
                .keyboardShortcut(",", modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }
}
