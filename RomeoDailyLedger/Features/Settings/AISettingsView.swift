import SwiftUI

struct AISettingsView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var preferences: AppPreferences
    @State private var baseURLText: String
    @State private var status: String?
    @State private var requestState = AIRequestState()
    @State private var requestTask: Task<Void, Never>?
    private let client: any AIRequesting

    init(
        preferences: AppPreferences,
        client: any AIRequesting = AIClient()
    ) {
        self.preferences = preferences
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

                LabeledContent(AppLocalization.text("settings.ai.baseURL", language: language)) {
                    TextField("", text: $baseURLText)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("settings-ai-base-url")
                        .onSubmit { testConnection() }
                }
                LabeledContent(AppLocalization.text("settings.ai.apiKey", language: language)) {
                    SecureField("", text: $preferences.apiKey)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("settings-ai-api-key")
                        .onSubmit { testConnection() }
                }
                LabeledContent(AppLocalization.text("settings.ai.model", language: language)) {
                    TextField("", text: configurationBinding(\.model))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("settings-ai-model")
                        .onSubmit { testConnection() }
                }

                HStack {
                    Button(AppLocalization.text("settings.ai.test", language: language)) { testConnection() }
                    .disabled(requestTask != nil)
                    .accessibilityIdentifier("settings-ai-test")
                    if requestState.isLoading {
                        TasteSpinner(reduceMotion: reduceMotion)
                            .accessibilityLabel(AppLocalization.text("settings.ai.testing", language: language))
                        Text(AppLocalization.text("settings.ai.testing", language: language))
                    }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.leading, 16)
        .padding(.trailing, 24)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings-ai")
        .onDisappear { requestTask?.cancel() }
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

    private func testConnection() {
        status = nil
        requestTask = Task { @MainActor in
            defer { requestTask = nil }
            do {
                let configuration = try validatedConfiguration()
                preferences.aiConfiguration = configuration
                try await requestState.perform {
                    try await client.testConnection(configuration: configuration)
                }
                status = AppLocalization.text("settings.ai.ready", language: language)
            } catch is CancellationError {
            } catch {
                status = localizedAIError(error, language: language)
            }
        }
    }
}

func localizedAIError(_ error: Error, language: AppLanguage) -> String {
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
