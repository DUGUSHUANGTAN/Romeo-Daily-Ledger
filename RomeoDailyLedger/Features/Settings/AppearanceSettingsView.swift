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

            Section(AppLocalization.text("settings.appearance.typography", language: preferences.language)) {
                Picker(AppLocalization.text("settings.appearance.typography", language: preferences.language), selection: $preferences.typographyStyle) {
                    ForEach(AppTypography.Style.allCases) { style in
                        Text(AppLocalization.text("font.\(style.rawValue)", language: preferences.language)).tag(style)
                    }
                }
                .pickerStyle(.radioGroup)
                .accessibilityIdentifier("settings-typography")
            }

            Section(AppLocalization.text("settings.appearance.motion", language: preferences.language)) {
                HStack {
                    Slider(value: motionBinding, in: 0...100, step: 1)
                        .disabled(systemReduceMotion)
                        .accessibilityIdentifier("settings-motion")
                    Text("\(preferences.motionIntensity)")
                        .monospacedDigit()
                        .frame(width: 34, alignment: .trailing)
                }
                Text(AppLocalization.text(systemReduceMotion ? "settings.appearance.reduceMotionActive" : "settings.appearance.motionHelp", language: preferences.language))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(systemReduceMotion ? "settings-reduce-motion-note" : "settings-motion-help")
            }
        }
        .formStyle(.grouped)
        .navigationTitle(AppLocalization.text("settings.appearance.title", language: preferences.language))
        .padding(24)
        .accessibilityIdentifier("settings-appearance")
    }

    private var motionBinding: Binding<Double> {
        Binding(
            get: { Double(preferences.motionIntensity) },
            set: { preferences.motionIntensity = Int($0.rounded()) }
        )
    }
}
