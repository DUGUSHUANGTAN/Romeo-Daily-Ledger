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
            }

        }
        .formStyle(.grouped)
        .navigationTitle(AppLocalization.text("settings.appearance.title", language: preferences.language))
        .padding(24)
        .accessibilityIdentifier("settings-appearance")
    }
}
