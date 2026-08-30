import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var preferences: AppPreferences
    let openCategories: () -> Void
    @State private var showingUpdateCheck = false

    var body: some View {
        Form {
            Section(AppLocalization.text("settings.general.regional", language: preferences.language)) {
                TextField(AppLocalization.text("settings.general.currency", language: preferences.language), text: $preferences.currencyCode)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 180)
                    .accessibilityIdentifier("settings-currency")

                Picker(AppLocalization.text("settings.general.language", language: preferences.language), selection: $preferences.language) {
                    Text(AppLocalization.text("language.zhHans", language: preferences.language)).tag(AppLanguage.simplifiedChinese)
                    Text(AppLocalization.text("language.en", language: preferences.language)).tag(AppLanguage.english)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)
                .accessibilityIdentifier("settings-language")
            }

            Section(AppLocalization.text("settings.categories.title", language: preferences.language)) {
                Button(action: openCategories) {
                    HStack {
                        LucideIconView(icon: .settings)
                        Text(AppLocalization.text("settings.general.manageCategories", language: preferences.language))
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings-open-categories")
            }

            Section(AppLocalization.text("settings.update.section", language: preferences.language)) {
                Button(AppLocalization.text("settings.update.check", language: preferences.language)) {
                    showingUpdateCheck = true
                }
                .accessibilityIdentifier("settings-check-for-updates")
            }
        }
        .formStyle(.grouped)
        .navigationTitle(AppLocalization.text("settings.general.title", language: preferences.language))
        .padding(24)
        .accessibilityIdentifier("settings-general")
        .sheet(isPresented: $showingUpdateCheck) {
            UpdateCheckView(language: preferences.language)
        }
    }
}
