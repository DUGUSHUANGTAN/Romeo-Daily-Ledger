import AppKit
import SwiftUI

enum SettingsPageLayout {
    static let contentInset: CGFloat = 24
    static let sidebarSelectionCornerRadius: CGFloat = 8
    static let sidebarSelectionVerticalInset: CGFloat = 2
}

struct SettingsRootView: View {
    enum Page: String, CaseIterable, Identifiable {
        case general, appearance, ai, data
        var id: Self { self }
    }

    let dependencies: AppDependencies
    var standalone = false

    @ViewBuilder
    var body: some View {
        @Bindable var preferences = dependencies.preferences
        if standalone {
            SettingsContentView(dependencies: dependencies)
                .frame(minWidth: 900, minHeight: 560)
                .background { WindowAppearanceBridge(mode: preferences.themeMode) }
                .preferredColorScheme(preferredScheme(for: preferences.themeMode))
        } else {
            SettingsContentView(dependencies: dependencies)
        }
    }

    private func preferredScheme(for mode: ThemeMode) -> ColorScheme? {
        switch mode { case .system: nil; case .light: .light; case .dark: .dark }
    }
}

private struct SettingsContentView: View {
    typealias Page = SettingsRootView.Page
    let dependencies: AppDependencies
    @State private var selectedPage: Page = .general
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        @Bindable var preferences = dependencies.preferences
        let resolved = preferences.themeMode.resolve(systemIsDark: colorScheme == .dark)
        let theme = resolved == .dark ? AppTheme.dark : AppTheme.light
        let motion = MotionPolicy.navigation(systemReduceMotion: systemReduceMotion)

        HStack(spacing: 0) {
            List(Page.allCases, selection: $selectedPage) { page in
                Text(title(for: page, language: preferences.language))
                    .tag(page)
                    .accessibilityIdentifier("settings-page-\(page.rawValue)")
                    .frame(minHeight: 34)
                    .foregroundStyle(selectedPage == page ? theme.selectionForeground.color : theme.primaryText.color)
                    .listRowBackground(
                        SettingsSidebarSelectionBackground(
                            isSelected: selectedPage == page,
                            theme: theme
                        )
                    )
            }
            .navigationTitle(AppLocalization.text("nav.settings.title", language: preferences.language))
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(theme.chrome.color)
            .frame(width: 190)

            Divider()

            NavigationStack {
                Group {
                    switch selectedPage {
                    case .general:
                        GeneralSettingsView(preferences: preferences, storage: dependencies.storage, repository: dependencies.repository)
                    case .appearance:
                        AppearanceSettingsView(preferences: preferences, systemReduceMotion: systemReduceMotion)
                    case .ai:
                        AISettingsView(preferences: preferences, client: dependencies.aiClient)
                    case .data:
                        DataSettingsView(repository: dependencies.repository, storage: dependencies.storage, language: preferences.language, currencyCode: preferences.currencyCode)
                    }
                }
                .id(selectedPage)
                .transition(.opacity)
                .animation(pageAnimation(motion), value: selectedPage)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(theme.canvas.color)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(theme.canvas.color)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("settings-detail-left-aligned")
        }
        .tint(theme.primaryAccent.color)
        .environment(\.locale, preferences.language.locale)
        .environment(\.appLanguage, preferences.language)
        .environment(\.appCurrencyCode, preferences.currencyCode)
        .environment(\.font, .system(size: 14 * AppTypography.scaleFactor(percent: preferences.fontScalePercent)))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings-root")
    }

    private func title(for page: Page, language: AppLanguage) -> String {
        AppLocalization.text("settings.\(page.rawValue).title", language: language)
    }

    private func pageAnimation(_ motion: MotionPolicy) -> Animation? {
        motion.effectiveIntensity == 0 ? nil : .easeOut(duration: motion.duration)
    }

}

private struct SettingsSidebarSelectionBackground: View {
    let isSelected: Bool
    let theme: AppTheme

    var body: some View {
        if isSelected {
            if #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: SettingsPageLayout.sidebarSelectionCornerRadius)
                    .fill(.clear)
                    .glassEffect(
                        .regular.tint(theme.primaryAccent.color.opacity(0.72)),
                        in: .rect(cornerRadius: SettingsPageLayout.sidebarSelectionCornerRadius)
                    )
                    .padding(.vertical, SettingsPageLayout.sidebarSelectionVerticalInset)
            } else {
                RoundedRectangle(cornerRadius: SettingsPageLayout.sidebarSelectionCornerRadius)
                    .fill(theme.primaryAccent.color)
                    .padding(.vertical, SettingsPageLayout.sidebarSelectionVerticalInset)
            }
        } else {
            Color.clear
        }
    }
}

private struct WindowAppearanceBridge: NSViewRepresentable {
    let mode: ThemeMode

    func makeNSView(context: Context) -> AppearanceHostingView {
        let view = AppearanceHostingView()
        view.mode = mode
        return view
    }

    func updateNSView(_ view: AppearanceHostingView, context: Context) {
        view.mode = mode
        view.applyAppearance()
    }
}

private final class AppearanceHostingView: NSView {
    var mode: ThemeMode = .system

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyAppearance()
        keepWindowVisible()
    }

    func applyAppearance() {
        window?.appearance = AppAppearancePolicy.appearanceName(for: mode).flatMap(NSAppearance.init(named:))
        window?.contentView?.viewDidChangeEffectiveAppearance()
    }

    private func keepWindowVisible() {
        guard let window, let visible = window.screen?.visibleFrame else { return }
        var frame = window.frame
        if frame.maxY > visible.maxY { frame.origin.y = visible.maxY - frame.height }
        if frame.minY < visible.minY { frame.origin.y = visible.minY }
        if frame.minX < visible.minX { frame.origin.x = visible.minX }
        if frame.maxX > visible.maxX { frame.origin.x = visible.maxX - frame.width }
        window.setFrame(frame, display: true, animate: false)
    }
}
