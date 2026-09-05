import SwiftUI

enum SettingsPageLayout {
    static let contentInset: CGFloat = 24
    static let sidebarSelectionCornerRadius: CGFloat = 8
    static let sidebarSelectionVerticalInset: CGFloat = 2
}

struct SettingsPageScroll<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) { content() }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
    }
}

struct SettingsPageSection<Content: View>: View {
    let title: String?
    @ViewBuilder let content: () -> Content

    init(_ title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title { Text(title).font(.headline) }
            VStack(alignment: .leading, spacing: 10) { content() }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct SettingsRootView: View {
    enum Page: String, CaseIterable, Identifiable {
        case general, appearance, ai, data
        var id: Self { self }
    }

    let dependencies: AppDependencies
    var keyboardScope: Binding<SidebarKeyboardScope>?

    init(
        dependencies: AppDependencies,
        keyboardScope: Binding<SidebarKeyboardScope>? = nil
    ) {
        self.dependencies = dependencies
        self.keyboardScope = keyboardScope
    }

    var body: some View {
        SettingsContentView(dependencies: dependencies, keyboardScope: keyboardScope)
    }
}

private struct SettingsContentView: View {
    typealias Page = SettingsRootView.Page
    let dependencies: AppDependencies
    let keyboardScope: Binding<SidebarKeyboardScope>?
    @State private var selectedPage: Page = .general
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        @Bindable var preferences = dependencies.preferences
        let resolved = preferences.themeMode.resolve(systemIsDark: colorScheme == .dark)
        let theme = resolved == .dark ? AppTheme.dark : AppTheme.light
        let motion = MotionPolicy.navigation(systemReduceMotion: systemReduceMotion)

        HStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Page.allCases) { page in
                        Button {
                            selectedPage = page
                            keyboardScope?.wrappedValue = .settings
                        } label: {
                            Text(title(for: page, language: preferences.language))
                                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                                .padding(.horizontal, 8)
                                .contentShape(Rectangle())
                                .foregroundStyle(theme.primaryText.color)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .accessibilityIdentifier("settings-page-\(page.rawValue)")
                        .background {
                            SettingsSidebarSelectionBackground(
                                isSelected: selectedPage == page,
                                theme: theme
                            )
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .navigationTitle(AppLocalization.text("nav.settings.title", language: preferences.language))
            .scrollContentBackground(.hidden)
            .background(theme.chrome.color)
            .frame(width: 190)

            Divider()

            NavigationStack {
                Group {
                    switch selectedPage {
                    case .general:
                        GeneralSettingsView(preferences: preferences, storage: dependencies.storage)
                    case .appearance:
                        AppearanceSettingsView(preferences: preferences)
                    case .ai:
                        AISettingsView(preferences: preferences, client: dependencies.aiClient)
                    case .data:
                        DataSettingsView(repository: dependencies.repository, storage: dependencies.storage, language: preferences.language, currencyCode: preferences.currencyCode)
                    }
                }
                .id(selectedPage)
                .transition(motion.pageTransition)
                .animation(motion.pageAnimation, value: selectedPage)
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
        .background {
            SidebarArrowKeyMonitor(isActive: keyboardScope?.wrappedValue != .main) { direction in
                movePageSelection(direction)
            }
        }
    }

    private func title(for page: Page, language: AppLanguage) -> String {
        AppLocalization.text("settings.\(page.rawValue).title", language: language)
    }

    private func movePageSelection(_ direction: MoveCommandDirection) {
        guard direction == .up || direction == .down,
              let index = Page.allCases.firstIndex(of: selectedPage) else { return }
        let offset = direction == .down ? 1 : -1
        let pages = Page.allCases
        let next = pages[(index + offset + pages.count) % pages.count]
        selectedPage = next
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
                        .clear.tint(theme.primaryAccent.color.opacity(0.42)),
                        in: .rect(cornerRadius: SettingsPageLayout.sidebarSelectionCornerRadius)
                    )
                    .padding(.vertical, SettingsPageLayout.sidebarSelectionVerticalInset)
            } else {
                RoundedRectangle(cornerRadius: SettingsPageLayout.sidebarSelectionCornerRadius)
                    .fill(.thinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: SettingsPageLayout.sidebarSelectionCornerRadius)
                            .stroke(theme.primaryText.color.opacity(0.12), lineWidth: 0.5)
                    }
                    .padding(.vertical, SettingsPageLayout.sidebarSelectionVerticalInset)
            }
        } else {
            Color.clear
        }
    }
}
