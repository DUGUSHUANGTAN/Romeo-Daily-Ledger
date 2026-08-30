import SwiftUI

struct AISettingsView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var preferences: AppPreferences
    @State private var apiKey = ""
    @State private var status: String?
    private let keyStore: AIKeychainStoring

    init(preferences: AppPreferences, keyStore: AIKeychainStoring = KeychainAIKeyStore()) {
        self.preferences = preferences
        self.keyStore = keyStore
    }

    var body: some View {
        Form {
            Section(AppLocalization.text("settings.ai.connection", language: language)) {
                Picker(AppLocalization.text("settings.ai.protocol", language: language), selection: $preferences.aiConfiguration.protocolType) {
                    ForEach(AIProtocol.allCases) { protocolType in
                        Text(protocolType.displayName).tag(protocolType)
                    }
                }
                TextField(AppLocalization.text("settings.ai.baseURL", language: language), text: Binding(get: { preferences.aiConfiguration.baseURL.absoluteString }, set: { value in if let url = URL(string: value) { var config = preferences.aiConfiguration; config.baseURL = url; preferences.aiConfiguration = config } }))
                SecureField(AppLocalization.text("settings.ai.apiKey", language: language), text: $apiKey)
                TextField(AppLocalization.text("settings.ai.model", language: language), text: Binding(get: { preferences.aiConfiguration.model }, set: { value in var config = preferences.aiConfiguration; config.model = value; preferences.aiConfiguration = config }))
                Toggle(AppLocalization.text("settings.ai.allowLedger", language: language), isOn: Binding(get: { preferences.aiConfiguration.allowsLedgerData }, set: { value in var config = preferences.aiConfiguration; config.allowsLedgerData = value; preferences.aiConfiguration = config }))
                HStack {
                    Button(AppLocalization.text("settings.ai.saveKey", language: language)) { saveKey() }
                    Button(AppLocalization.text("settings.ai.test", language: language)) { status = AppLocalization.text("settings.ai.ready", language: language) }
                    if let status { Text(status).foregroundStyle(.secondary) }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(AppLocalization.text("settings.ai.title", language: language))
        .padding(24)
        .accessibilityIdentifier("settings-ai")
    }

    private func saveKey() {
        do {
            if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { try keyStore.delete(service: KeychainAIKeyStore.service, account: "apiKey") }
            else { try keyStore.save(apiKey, service: KeychainAIKeyStore.service, account: "apiKey") }
            status = AppLocalization.text("settings.ai.saved", language: language)
        } catch { status = AppLocalization.text("settings.ai.keychainError", language: language) }
    }
}
