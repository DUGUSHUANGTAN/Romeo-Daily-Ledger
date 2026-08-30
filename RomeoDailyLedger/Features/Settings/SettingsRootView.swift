import SwiftUI

struct SettingsRootView: View {
    enum Page: String, CaseIterable, Identifiable {
        case general, appearance, categories, ai
        var id: Self { self }
    }

    let dependencies: AppDependencies
    @State private var selectedPage: Page = .general
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        @Bindable var preferences = dependencies.preferences
        let resolved = preferences.themeMode.resolve(systemIsDark: colorScheme == .dark)
        let theme = resolved == .dark ? AppTheme.dark : AppTheme.light

        NavigationSplitView {
            List(Page.allCases, selection: $selectedPage) { page in
                Text(title(for: page, language: preferences.language))
                    .tag(page)
                    .accessibilityIdentifier("settings-page-\(page.rawValue)")
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
                    GeneralSettingsView(preferences: preferences) { selectedPage = .categories }
                case .appearance:
                    AppearanceSettingsView(preferences: preferences, systemReduceMotion: systemReduceMotion)
                case .categories:
                    CategoryManagementView(repository: dependencies.repository, language: preferences.language)
                case .ai:
                    AISettingsView(preferences: preferences)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.canvas.color)
        }
        .tint(theme.primaryAccent.color)
        .preferredColorScheme(preferredScheme(for: preferences.themeMode))
        .environment(\.locale, preferences.language.locale)
        .environment(\.appLanguage, preferences.language)
        .environment(\.appCurrencyCode, preferences.currencyCode)
        .frame(minWidth: 720, minHeight: 480)
        .accessibilityIdentifier("settings-root")
    }

    private func title(for page: Page, language: AppLanguage) -> String {
        AppLocalization.text("settings.\(page.rawValue).title", language: language)
    }

    private func preferredScheme(for mode: ThemeMode) -> ColorScheme? {
        switch mode {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
