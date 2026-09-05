import AppKit
import SwiftUI

enum SidebarDestination: String, CaseIterable, Identifiable, Sendable {
    case ledger, aiAssistant, calendar, insights, history, categories, settings
    var id: Self { self }

    func localizedTitle(language: AppLanguage) -> String {
        AppLocalization.text("nav.\(rawValue).title", language: language)
    }

    var icon: LucideIcon {
        switch self {
        case .ledger: .ledger
        case .aiAssistant: .aiAssistant
        case .calendar: .calendar
        case .insights: .insights
        case .history: .history
        case .categories: .categories
        case .settings: .settings
        }
    }
}

enum SidebarKeyboardScope {
    case main, settings
}

struct RootView: View {
    let dependencies: AppDependencies

    var body: some View {
        @Bindable var preferences = dependencies.preferences
        Group {
            if dependencies.launchState.canOpenLedger {
                RootContentView(dependencies: dependencies)
            } else {
                StorageRecoveryView(dependencies: dependencies)
            }
        }
            .preferredColorScheme(preferredScheme(for: preferences.themeMode))
            .onAppear {
                AppLocalization.updateApplicationMenuTitle(in: NSApp.mainMenu, language: preferences.language)
            }
            .onChange(of: preferences.language) { _, language in
                AppLocalization.updateApplicationMenuTitle(in: NSApp.mainMenu, language: language)
            }
    }

    private func preferredScheme(for mode: ThemeMode) -> ColorScheme? {
        switch mode { case .system: nil; case .light: .light; case .dark: .dark }
    }
}

private struct StorageRecoveryView: View {
    let dependencies: AppDependencies

    var body: some View {
        @Bindable var preferences = dependencies.preferences
        VStack(alignment: .leading, spacing: 16) {
            Text(AppLocalization.text("storage.recovery.title", language: preferences.language))
                .font(.title2.weight(.semibold))
            Text(AppLocalization.text("storage.recovery.message", language: preferences.language))
            if let message = dependencies.launchState.recoveryMessage {
                Text(message)
                    .font(.callout)
                    .textSelection(.enabled)
            }
            LabeledContent(
                AppLocalization.text("storage.recovery.source", language: preferences.language),
                value: dependencies.storage.activeDirectory.path
            )
            if let pending = dependencies.storage.pendingDirectory {
                LabeledContent(
                    AppLocalization.text("storage.recovery.target", language: preferences.language),
                    value: pending.path
                )
            }
        }
        .padding(32)
        .frame(minWidth: 640, minHeight: 360, alignment: .topLeading)
        .accessibilityElement(children: .contain)
    }
}

private struct RootContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var sidebarKeyboardScope = SidebarKeyboardScope.main
    let dependencies: AppDependencies

    var body: some View {
        @Bindable var dependencies = dependencies
        @Bindable var preferences = dependencies.preferences
        let resolved = preferences.themeMode.resolve(systemIsDark: colorScheme == .dark)
        let theme = resolved == .dark ? AppTheme.dark : AppTheme.light
        let motion = MotionPolicy.navigation(systemReduceMotion: systemReduceMotion)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1.0"

        NavigationSplitView {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(SidebarDestination.allCases) { destination in
                            Button {
                                dependencies.selectedDestination = destination
                                sidebarKeyboardScope = .main
                            } label: {
                                Label {
                                    Text(destination.localizedTitle(language: preferences.language))
                                } icon: {
                                    LucideIconView(icon: destination.icon)
                                }
                                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                                .padding(.horizontal, 8)
                                .contentShape(Rectangle())
                                .accessibilityLabel(destination.localizedTitle(language: preferences.language))
                            }
                            .foregroundStyle(theme.primaryText.color)
                            .buttonStyle(.plain)
                            .focusable(false)
                            .background {
                                SidebarSelectionBackground(
                                    isSelected: dependencies.selectedDestination == destination,
                                    theme: theme
                                )
                            }
                            .accessibilityIdentifier("sidebar-\(destination.rawValue)")
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                Text("V\(version)")
                    .font(.caption2)
                    .foregroundStyle(theme.secondaryText.color.opacity(0.55))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("V\(version)")
                    .accessibilityIdentifier("app-version")
            }
            .navigationTitle(AppLocalization.text("app.name", language: preferences.language))
            .scrollContentBackground(.hidden)
            .background(theme.chrome.color)
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            ZStack {
                Group {
                    switch dependencies.selectedDestination {
                    case .ledger:
                        LedgerView(repository: dependencies.repository, theme: theme, typography: .system)
                    case .calendar:
                        CalendarView(repository: dependencies.repository, theme: theme, typography: .system)
                    case .insights:
                        InsightsView(repository: dependencies.repository, theme: theme, typography: .system, motion: motion)
                    case .history:
                        HistoryView(repository: dependencies.repository, theme: theme, typography: .system)
                    case .categories:
                        CategoryManagementView(repository: dependencies.repository, language: preferences.language)
                    case .settings:
                        SettingsRootView(dependencies: dependencies, keyboardScope: $sidebarKeyboardScope)
                    case .aiAssistant:
                        AILedgerAssistantView(dependencies: dependencies, theme: theme, typography: .system)
                    }
                }
                .id(dependencies.selectedDestination)
                .transition(motion.pageTransition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.canvas.color)
            .animation(motion.pageAnimation, value: dependencies.selectedDestination)
        }
        .windowToolbarBackgroundHidden()
        .tint(theme.primaryAccent.color)
        .environment(\.locale, preferences.language.locale)
        .environment(\.appLanguage, preferences.language)
        .environment(\.appCurrencyCode, preferences.currencyCode)
        .environment(\.font, .system(size: 14 * AppTypography.scaleFactor(percent: preferences.fontScalePercent)))
        .background {
            AppCommands(dependencies: dependencies)
            FocusDismissMonitor()
            SidebarArrowKeyMonitor(isActive: sidebarKeyboardScope == .main) { direction in
                moveSidebarSelection(direction, dependencies: dependencies)
            }
        }
        .frame(minWidth: 980, minHeight: 560)
    }

    private func moveSidebarSelection(_ direction: MoveCommandDirection, dependencies: AppDependencies) {
        guard direction == .up || direction == .down,
              let index = SidebarDestination.allCases.firstIndex(of: dependencies.selectedDestination) else { return }
        let offset = direction == .down ? 1 : -1
        let destinations = SidebarDestination.allCases
        let next = destinations[(index + offset + destinations.count) % destinations.count]
        dependencies.selectedDestination = next
    }
}

private extension View {
    @ViewBuilder
    func windowToolbarBackgroundHidden() -> some View {
        if #available(macOS 15.0, *) {
            toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        } else {
            toolbarBackground(.hidden, for: .windowToolbar)
        }
    }
}

struct SidebarArrowKeyMonitor: NSViewRepresentable {
    let isActive: Bool
    let onMove: (MoveCommandDirection) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            context.coordinator.handle(event)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.monitor { NSEvent.removeMonitor(monitor) }
    }

    @MainActor final class Coordinator {
        var parent: SidebarArrowKeyMonitor
        var monitor: Any?

        init(parent: SidebarArrowKeyMonitor) { self.parent = parent }

        func handle(_ event: NSEvent) -> NSEvent? {
            guard parent.isActive,
                  event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
                  !Self.isEditingText,
                  let direction = Self.direction(for: event.keyCode) else { return event }
            parent.onMove(direction)
            return nil
        }

        private static var isEditingText: Bool {
            guard let responder = NSApp.keyWindow?.firstResponder else { return false }
            return responder is NSTextView || responder is NSTextField
        }

        private static func direction(for keyCode: UInt16) -> MoveCommandDirection? {
            switch keyCode {
            case 125: .down
            case 126: .up
            default: nil
            }
        }
    }
}

private struct SidebarSelectionBackground: View {
    let isSelected: Bool
    let theme: AppTheme

    var body: some View {
        if isSelected {
            if #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.clear)
                    .glassEffect(
                        .clear.tint(theme.primaryAccent.color.opacity(0.42)),
                        in: .rect(cornerRadius: 8)
                    )
                    .padding(.vertical, 2)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.thinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(theme.primaryText.color.opacity(0.12), lineWidth: 0.5)
                    }
                    .padding(.vertical, 2)
            }
        } else {
            Color.clear
        }
    }
}

private struct FocusDismissMonitor: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            guard let window = event.window,
                  window == NSApp.keyWindow,
                  let hitView = window.contentView?.hitTest(event.locationInWindow),
                  !Self.isTextInput(hitView) else { return event }
            window.makeFirstResponder(nil)
            return event
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.monitor { NSEvent.removeMonitor(monitor) }
    }

    private static func isTextInput(_ view: NSView?) -> Bool {
        var candidate = view
        while let current = candidate {
            if current is NSTextView || current is NSTextField { return true }
            candidate = current.superview
        }
        return false
    }

    final class Coordinator {
        var monitor: Any?
    }
}
