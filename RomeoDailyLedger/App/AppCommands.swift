import SwiftUI

struct AppCommands: View {
    @Bindable var dependencies: AppDependencies

    var body: some View {
        Button("打开设置") { dependencies.selectedDestination = .settings }
            .keyboardShortcut(",", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
    }
}
