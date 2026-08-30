import SwiftUI

struct AISettingsView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var preferences: AppPreferences
    @State private var baseURLText: String
    @State private var apiKey = ""
    @State private var status: String?
    @State private var isTesting = false
    private let keyStore: AIKeychainStoring
    private let client: any AIRequesting

    init(
        preferences: AppPreferences,
        keyStore: AIKeychainStoring = KeychainAIKeyStore(),
        client: any AIRequesting = AIClient()
    ) {
        self.preferences = preferences
        self.keyStore = keyStore
        self.client = client
        _baseURLText = State(initialValue: preferences.aiConfiguration.baseURL.absoluteString)
    }

    var body: some View {
        Form {
            Section(AppLocalization.text("settings.ai.connection", language: language)) {
                Picker(
                    AppLocalization.text("settings.ai.protocol", language: language),
                    selection: configurationBinding(\.protocolType)
                ) {
                    ForEach(AIProtocol.allCases) { protocolType in
                        Text(protocolType.displayName).tag(protocolType)
                    }
                }
                .accessibilityIdentifier("settings-ai-protocol")

                TextField(AppLocalization.text("settings.ai.baseURL", language: language), text: $baseURLText)
                    .accessibilityIdentifier("settings-ai-base-url")
                SecureField(AppLocalization.text("settings.ai.apiKey", language: language), text: $apiKey)
                    .accessibilityIdentifier("settings-ai-api-key")
                TextField(
                    AppLocalization.text("settings.ai.model", language: language),
                    text: configurationBinding(\.model)
                )
                .accessibilityIdentifier("settings-ai-model")
                Toggle(
                    AppLocalization.text("settings.ai.allowLedger", language: language),
                    isOn: configurationBinding(\.allowsLedgerData)
                )

                HStack {
                    Button(AppLocalization.text("settings.ai.saveKey", language: language)) { save() }
                        .accessibilityIdentifier("settings-ai-save")
                    Button(
                        isTesting
                            ? AppLocalization.text("settings.ai.testing", language: language)
                            : AppLocalization.text("settings.ai.test", language: language)
                    ) { testConnection() }
                    .disabled(isTesting)
                    .accessibilityIdentifier("settings-ai-test")
                    if let status {
                        Text(status)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("settings-ai-status")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(AppLocalization.text("settings.ai.title", language: language))
        .padding(24)
        .accessibilityIdentifier("settings-ai")
    }

    private func configurationBinding<Value>(_ keyPath: WritableKeyPath<AIConfiguration, Value>) -> Binding<Value> {
        Binding(
            get: { preferences.aiConfiguration[keyPath: keyPath] },
            set: { value in
                var configuration = preferences.aiConfiguration
                configuration[keyPath: keyPath] = value
                preferences.aiConfiguration = configuration
            }
        )
    }

    private func validatedConfiguration() throws -> AIConfiguration {
        guard let url = URL(string: baseURLText), url.scheme != nil, url.host != nil else {
            throw AIClientError.invalidBaseURL
        }
        var configuration = preferences.aiConfiguration
        configuration.baseURL = url
        return configuration
    }

    private func save() {
        do {
            let configuration = try validatedConfiguration()
            if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try keyStore.save(apiKey, service: KeychainAIKeyStore.service, account: "apiKey")
                apiKey = ""
            }
            preferences.aiConfiguration = configuration
            status = AppLocalization.text("settings.ai.saved", language: language)
        } catch {
            status = localizedAIError(error, language: language)
        }
    }

    private func testConnection() {
        isTesting = true
        status = nil
        Task { @MainActor in
            defer { isTesting = false }
            do {
                let configuration = try validatedConfiguration()
                if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    try keyStore.save(apiKey, service: KeychainAIKeyStore.service, account: "apiKey")
                    apiKey = ""
                }
                preferences.aiConfiguration = configuration
                try await client.testConnection(configuration: configuration)
                status = AppLocalization.text("settings.ai.ready", language: language)
            } catch {
                status = localizedAIError(error, language: language)
            }
        }
    }
}

func localizedAIError(_ error: Error, language: AppLanguage) -> String {
    if error is AIKeychainError {
        return AppLocalization.text("settings.ai.keychainError", language: language)
    }
    guard let error = error as? AIClientError else {
        return AppLocalization.text("ai.error.network", language: language)
    }
    let key: String
    switch error {
    case .apiKeyMissing:
        key = "ai.error.apiKey"
    case .invalidBaseURL:
        key = "ai.error.baseURL"
    case .invalidModel:
        key = "ai.error.model"
    case .ledgerDataPermissionRequired:
        key = "ai.analysis.permissionRequired"
    case .network:
        key = "ai.error.network"
    case .httpStatus:
        key = "ai.error.http"
    case .responseDecoding:
        key = "ai.error.decoding"
    case .invalidStructuredResult:
        key = "ai.error.invalidResult"
    }
    return AppLocalization.text(key, language: language)
}
