import SwiftUI

enum SidebarDestination: String, CaseIterable, Identifiable, Sendable {
    case ledger, aiAssistant, calendar, insights, settings
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
        case .settings: .settings
        }
    }
}

struct RootView: View {
    let dependencies: AppDependencies

    var body: some View {
        @Bindable var preferences = dependencies.preferences
        RootContentView(dependencies: dependencies)
            .preferredColorScheme(preferredScheme(for: preferences.themeMode))
    }

    private func preferredScheme(for mode: ThemeMode) -> ColorScheme? {
        switch mode { case .system: nil; case .light: .light; case .dark: .dark }
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
        let motion = MotionPolicy(slider: 0, systemReduceMotion: systemReduceMotion)

        NavigationSplitView {
            List(SidebarDestination.allCases, selection: $dependencies.selectedDestination) { destination in
                NavigationLink(value: destination) {
                    Label {
                        Text(destination.localizedTitle(language: preferences.language))
                    } icon: {
                        LucideIconView(icon: destination.icon)
                            .foregroundStyle(dependencies.selectedDestination == destination ? theme.selectionForeground.color : theme.primaryText.color)
                    }
                    .foregroundStyle(dependencies.selectedDestination == destination ? theme.selectionForeground.color : theme.primaryText.color)
                    .accessibilityLabel(destination.localizedTitle(language: preferences.language))
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(dependencies.selectedDestination == destination ? theme.primaryAccent.color : Color.clear)
                        .padding(.vertical, 2)
                )
                .frame(minHeight: 34)
                .accessibilityIdentifier("sidebar-\(destination.rawValue)")
            }
            .navigationTitle(AppLocalization.text("app.name", language: preferences.language))
            .scrollContentBackground(.hidden)
            .background(theme.chrome.color)
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            switch dependencies.selectedDestination {
            case .ledger:
                LedgerView(repository: dependencies.repository, deletionUndoCoordinator: dependencies.deletionUndoCoordinator, theme: theme, typography: .system)
            case .calendar:
                CalendarView(repository: dependencies.repository, theme: theme, typography: .system)
            case .insights:
                InsightsView(repository: dependencies.repository, theme: theme, typography: .system, motion: motion)
            case .settings:
                SettingsRootView(dependencies: dependencies)
            case .aiAssistant:
                AILedgerAssistantView(dependencies: dependencies, theme: theme, typography: .system)
            }
        }
        .tint(theme.primaryAccent.color)
        .environment(\.locale, preferences.language.locale)
        .environment(\.appLanguage, preferences.language)
        .environment(\.appCurrencyCode, preferences.currencyCode)
        .background { AppCommands(dependencies: dependencies) }
        .frame(minWidth: 980, minHeight: 560)
    }

    private func animation(for policy: MotionPolicy) -> Animation? {
        guard policy.effectiveIntensity > 0 else { return nil }
        return policy.usesSpring ? .snappy(duration: policy.duration) : .easeOut(duration: policy.duration)
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
