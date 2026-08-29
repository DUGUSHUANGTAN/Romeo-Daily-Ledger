import SwiftUI

enum SidebarDestination: String, CaseIterable, Identifiable, Sendable {
    case ledger, aiAssistant, calendar, insights, settings
    var id: Self { self }

    var title: String {
        switch self {
        case .ledger: "记账"
        case .aiAssistant: "AI 助手"
        case .calendar: "日历"
        case .insights: "统计"
        case .settings: "设置"
        }
    }

    var subtitle: String {
        switch self {
        case .ledger: "快速记录与今日流水"
        case .aiAssistant: "自然语言记账与分析"
        case .calendar: "按日期回看账目"
        case .insights: "收支与趋势概览"
        case .settings: "主题、字体与偏好"
        }
    }

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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var dependencies = AppDependencies()

    var body: some View {
        @Bindable var dependencies = dependencies
        let resolved = dependencies.themeMode.resolve(systemIsDark: colorScheme == .dark)
        let theme = resolved == .dark ? AppTheme.dark : AppTheme.light

        NavigationSplitView {
            List(SidebarDestination.allCases, selection: $dependencies.selectedDestination) { destination in
                NavigationLink(value: destination) {
                    Label {
                        Text(destination.title)
                    } icon: {
                        LucideIconView(icon: destination.icon)
                            .foregroundStyle(dependencies.selectedDestination == destination ? theme.selectionForeground.color : theme.primaryText.color)
                    }
                    .foregroundStyle(dependencies.selectedDestination == destination ? theme.selectionForeground.color : theme.primaryText.color)
                    .accessibilityLabel(destination.title)
                }
                .accessibilityIdentifier("sidebar-\(destination.rawValue)")
            }
            .navigationTitle("每日记账")
            .scrollContentBackground(.hidden)
            .background(theme.chrome.color)
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            switch dependencies.selectedDestination {
            case .ledger:
                LedgerView(repository: dependencies.repository, deletionUndoCoordinator: dependencies.deletionUndoCoordinator, theme: theme, typography: dependencies.typographyStyle)
            case .calendar:
                CalendarView(repository: dependencies.repository, theme: theme, typography: dependencies.typographyStyle)
            default:
                DestinationPlaceholder(destination: dependencies.selectedDestination, theme: theme, typography: dependencies.typographyStyle)
            }
        }
        .tint(theme.primaryAccent.color)
        .preferredColorScheme(preferredScheme(for: dependencies.themeMode))
        .background { AppCommands(dependencies: dependencies) }
        .animation(animation(for: MotionPolicy(slider: dependencies.motionIntensity, systemReduceMotion: systemReduceMotion)), value: dependencies.selectedDestination)
        .frame(minWidth: 980, minHeight: 560)
    }

    private func preferredScheme(for mode: ThemeMode) -> ColorScheme? {
        switch mode {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LucideIconView(icon: destination.icon, size: 34)
                .foregroundStyle(theme.primaryAccent.color)
            VStack(alignment: .leading, spacing: 8) {
                Text(destination.title)
                    .font(AppTypography.display(typography))
                    .foregroundStyle(theme.primaryText.color)
                Text(destination.subtitle)
                    .font(AppTypography.body(typography))
                    .foregroundStyle(theme.secondaryText.color)
            }
            Rectangle()
                .fill(theme.secondaryAccent.color)
                .frame(width: 48, height: 3)
                .accessibilityHidden(true)
            Text("此区域将在后续任务中接入完整功能。")
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
