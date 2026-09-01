import AppKit
import SwiftUI

struct SettingsRootView: View {
    enum Page: String, CaseIterable, Identifiable {
        case general, appearance, categories, ai, data
        var id: Self { self }
    }

    let dependencies: AppDependencies

    var body: some View {
        @Bindable var preferences = dependencies.preferences
        SettingsContentView(dependencies: dependencies)
            .background { WindowAppearanceBridge(mode: preferences.themeMode) }
            .preferredColorScheme(preferredScheme(for: preferences.themeMode))
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

        NavigationSplitView {
            List(Page.allCases, selection: $selectedPage) { page in
                Text(title(for: page, language: preferences.language))
                    .tag(page)
                    .accessibilityIdentifier("settings-page-\(page.rawValue)")
                    .frame(minHeight: 34)
            }
            .navigationTitle(AppLocalization.text("nav.settings.title", language: preferences.language))
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(theme.chrome.color)
            .navigationSplitViewColumnWidth(min: 160, ideal: 190, max: 220)
        } detail: {
            Group {
                switch selectedPage {
                case .general:
                    GeneralSettingsView(preferences: preferences, storage: dependencies.storage, repository: dependencies.repository)
                case .appearance:
                    AppearanceSettingsView(preferences: preferences, systemReduceMotion: systemReduceMotion)
                case .categories:
                    CategoryManagementView(repository: dependencies.repository, language: preferences.language)
                case .ai:
                    AISettingsView(preferences: preferences, client: dependencies.aiClient)
                case .data:
                    DataSettingsView(repository: dependencies.repository, storage: dependencies.storage, language: preferences.language, currencyCode: preferences.currencyCode)
                }
            }
            .id(selectedPage)
            .transition(.opacity)
            .animation(pageAnimation(motion), value: selectedPage)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.canvas.color)
        }
        .tint(theme.primaryAccent.color)
        .environment(\.locale, preferences.language.locale)
        .environment(\.appLanguage, preferences.language)
        .environment(\.appCurrencyCode, preferences.currencyCode)
        .frame(minWidth: 720, minHeight: 480)
        .accessibilityIdentifier("settings-root")
    }

    private func title(for page: Page, language: AppLanguage) -> String {
        AppLocalization.text("settings.\(page.rawValue).title", language: language)
    }

    private func pageAnimation(_ motion: MotionPolicy) -> Animation? {
        motion.effectiveIntensity == 0 ? nil : .easeOut(duration: motion.duration)
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
    }

    func applyAppearance() {
        switch mode {
        case .system:
            window?.appearance = nil
        case .light:
            window?.appearance = NSAppearance(named: .aqua)
        case .dark:
            window?.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
