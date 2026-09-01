import SwiftUI

struct AppearanceSettingsView: View {
    @Bindable var preferences: AppPreferences
    let systemReduceMotion: Bool

    var body: some View {
        Form {
            Section(AppLocalization.text("settings.appearance.theme", language: preferences.language)) {
                Picker(AppLocalization.text("settings.appearance.theme", language: preferences.language), selection: $preferences.themeMode) {
                    ForEach(ThemeMode.allCases) { mode in
                        Text(AppLocalization.text("theme.\(mode.rawValue)", language: preferences.language)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("settings-theme")
                .onChange(of: preferences.themeMode, initial: true) { _, mode in
                    AppAppearancePolicy.apply(mode)
                }
            }

            Section(AppLocalization.text("settings.appearance.typography", language: preferences.language)) {
                HStack(spacing: 12) {
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
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                        .accessibilityIdentifier("settings-font-scale-value")
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(AppLocalization.text("settings.appearance.title", language: preferences.language))
        .padding(24)
        .accessibilityIdentifier("settings-appearance")
    }
}
