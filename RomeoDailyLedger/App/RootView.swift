import AppKit
import SwiftUI

enum SidebarDestination: String, CaseIterable, Identifiable, Sendable {
    case ledger, aiAssistant, calendar, insights, history, categories, settings
    var id: Self { self }

    func localizedTitle(language: AppLanguage) -> String {
        AppLocalization.text("nav.\(rawValue).title", language: language)
    }

    func localizedSubtitle(language: AppLanguage) -> String {
        AppLocalization.text("nav.\(rawValue).subtitle", language: language)
    }

    var title: String { localizedTitle(language: .simplifiedChinese) }
    var subtitle: String { localizedSubtitle(language: .simplifiedChinese) }

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
    let dependencies: AppDependencies

    var body: some View {
        @Bindable var dependencies = dependencies
        @Bindable var preferences = dependencies.preferences
        let resolved = preferences.themeMode.resolve(systemIsDark: colorScheme == .dark)
        let theme = resolved == .dark ? AppTheme.dark : AppTheme.light
        let motion = MotionPolicy.navigation(systemReduceMotion: systemReduceMotion)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.3"

        NavigationSplitView {
            VStack(spacing: 0) {
                List(SidebarDestination.allCases, selection: $dependencies.selectedDestination) { destination in
                    NavigationLink(value: destination) {
                        Label {
                            Text(destination.localizedTitle(language: preferences.language))
                        } icon: {
                            LucideIconView(icon: destination.icon)
                        }
                        .accessibilityLabel(destination.localizedTitle(language: preferences.language))
                    }
                    .frame(minHeight: 34)
                    .accessibilityIdentifier("sidebar-\(destination.rawValue)")
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
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
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
                    SettingsRootView(dependencies: dependencies)
                case .aiAssistant:
                    AILedgerAssistantView(dependencies: dependencies, theme: theme, typography: .system)
                }
            }
            .id(dependencies.selectedDestination)
            .transition(.opacity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.canvas.color)
            .animation(animation(for: motion), value: dependencies.selectedDestination)
        }
        .tint(theme.primaryAccent.color)
        .environment(\.locale, preferences.language.locale)
        .environment(\.appLanguage, preferences.language)
        .environment(\.appCurrencyCode, preferences.currencyCode)
        .environment(\.font, .system(size: 14 * AppTypography.scaleFactor(percent: preferences.fontScalePercent)))
        .background {
            AppCommands(dependencies: dependencies)
            FocusDismissMonitor()
        }
        .frame(minWidth: 980, minHeight: 560)
    }

    private func animation(for policy: MotionPolicy) -> Animation? {
        guard policy.effectiveIntensity > 0 else { return nil }
        return policy.usesSpring ? .snappy(duration: policy.duration) : .easeOut(duration: policy.duration)
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

    private static func isTextInput(_ view: NSView) -> Bool {
        var candidate: NSView? = view
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

private struct DestinationPlaceholder: View {
    let destination: SidebarDestination
    let theme: AppTheme
    let typography: AppTypography.Style
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LucideIconView(icon: destination.icon, size: 34)
                .foregroundStyle(theme.primaryAccent.color)
            VStack(alignment: .leading, spacing: 8) {
                Text(destination.localizedTitle(language: language))
                    .font(AppTypography.display(typography))
                    .foregroundStyle(theme.primaryText.color)
                Text(destination.localizedSubtitle(language: language))
                    .font(AppTypography.body(typography))
                    .foregroundStyle(theme.secondaryText.color)
            }
            Rectangle()
                .fill(theme.secondaryAccent.color)
                .frame(width: 48, height: 3)
                .accessibilityHidden(true)
            Text(AppLocalization.text("placeholder.futureFeature", language: language))
                .font(AppTypography.caption(typography))
                .foregroundStyle(theme.secondaryText.color)
            Spacer()
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.canvas.color)
        .id(destination)
    }
}
