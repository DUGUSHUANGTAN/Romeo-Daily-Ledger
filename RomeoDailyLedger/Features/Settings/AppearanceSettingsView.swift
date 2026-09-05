import SwiftUI

struct AppearanceSettingsView: View {
    @Bindable var preferences: AppPreferences

    var body: some View {
        SettingsPageScroll {
            SettingsPageSection(AppLocalization.text("settings.appearance.theme", language: preferences.language)) {
                Picker(AppLocalization.text("settings.appearance.theme", language: preferences.language), selection: $preferences.themeMode) {
                    ForEach(ThemeMode.allCases) { mode in
                        Text(AppLocalization.text("theme.\(mode.rawValue)", language: preferences.language))
                            .accessibilityValue(preferences.themeMode == mode ? "1" : "0")
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("settings-theme")
                .onChange(of: preferences.themeMode, initial: true) { _, mode in
                    AppAppearancePolicy.apply(mode)
                }
            }

            SettingsPageSection(AppLocalization.text("settings.appearance.typography", language: preferences.language)) {
                HStack(spacing: 12) {
                    Text(AppLocalization.text("settings.appearance.fontSize", language: preferences.language))
                        .font(AppTypography.body(.system))
                    Slider(
                        value: Binding(
                            get: { Double(preferences.fontScalePercent) },
                            set: { preferences.fontScalePercent = Int($0) }
                        ),
                        in: 80...140,
                        step: 5
                    )
                    .accessibilityIdentifier("settings-font-scale")

                    Text("\(preferences.fontScalePercent)%")
                        .font(AppTypography.body(.system))
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                        .accessibilityIdentifier("settings-font-scale-value")
                }
            }
        }
        .padding(SettingsPageLayout.contentInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(AppLocalization.text("settings.appearance.title", language: preferences.language))
        .accessibilityIdentifier("settings-appearance")
    }
}
