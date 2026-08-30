import SwiftUI

struct AppCommands: View {
    static let settingsShortcutKey: KeyEquivalent = ","

    @Bindable var dependencies: AppDependencies

    var body: some View {
        Group {
            Button(AppLocalization.text("command.openLedger", language: dependencies.preferences.language)) { dependencies.selectedDestination = .ledger }
                .keyboardShortcut("1", modifiers: .command)
            Button(AppLocalization.text("command.openCalendar", language: dependencies.preferences.language)) { dependencies.selectedDestination = .calendar }
                .keyboardShortcut("2", modifiers: .command)
            Button(AppLocalization.text("command.openInsights", language: dependencies.preferences.language)) { dependencies.selectedDestination = .insights }
                .keyboardShortcut("3", modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }
}
