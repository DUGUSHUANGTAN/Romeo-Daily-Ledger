import SwiftUI

struct AISettingsView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var preferences: AppPreferences
    @State private var editor: ModelEditorContext?
    @State private var pendingDeletion: AIModelPreset?
    private let client: any AIRequesting

    init(preferences: AppPreferences, client: any AIRequesting = AIClient()) {
        self.preferences = preferences
        self.client = client
    }

    var body: some View {
        Form {
            Section(AppLocalization.text("settings.ai.model", language: language)) {
                ForEach(preferences.aiModelPresets) { preset in modelRow(preset) }
                Button { editor = ModelEditorContext(preset: nil) } label: {
                    Label(AppLocalization.text("settings.ai.connection", language: language), systemImage: "plus")
                }
                .accessibilityIdentifier("settings-ai-add-model")
                Text("Fill in each provider's API key to use its models.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(AppLocalization.text("settings.ai.title", language: language))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.leading, 16)
        .padding(.trailing, 24)
        .accessibilityIdentifier("settings-ai")
        .sheet(item: $editor) { context in
            AIModelEditorView(preset: context.preset, client: client) { saved in
                save(saved)
                editor = nil
            }
        }
        .alert(
            AppLocalization.text("settings.ai.model", language: language),
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            presenting: pendingDeletion
        ) { preset in
            Button(AppLocalization.text("button.cancel", language: language), role: .cancel) {}
            Button(AppLocalization.text("button.delete", language: language), role: .destructive) { delete(preset) }
        } message: { Text($0.name) }
    }

    private func modelRow(_ preset: AIModelPreset) -> some View {
        HStack(spacing: 12) {
            Button { preferences.selectedAIModelID = preset.id } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name).fontWeight(.medium)
                    Text(preset.configuration.model).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            Button(role: .destructive) { pendingDeletion = preset } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless).foregroundStyle(.red)
                .accessibilityIdentifier("settings-ai-delete-\(preset.id)")
            Button { editor = ModelEditorContext(preset: preset) } label: { Image(systemName: "pencil") }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("settings-ai-edit-\(preset.id)")
            Circle()
                .fill(preset.connectionStatus.isConnected ? Color.green : Color.red)
                .frame(width: 9, height: 9)
                .accessibilityLabel(preset.connectionStatus.isConnected ? "Connected" : "Not connected")
        }
        .padding(.vertical, 7).padding(.horizontal, 10)
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(preferences.selectedAIModelID == preset.id ? Color.accentColor : Color.secondary.opacity(0.35)) }
    }

    private func save(_ preset: AIModelPreset) {
        if let index = preferences.aiModelPresets.firstIndex(where: { $0.id == preset.id }) {
            preferences.aiModelPresets[index] = preset
        } else { preferences.aiModelPresets.append(preset) }
        preferences.selectedAIModelID = preset.id
    }

    private func delete(_ preset: AIModelPreset) {
        preferences.aiModelPresets.removeAll { $0.id == preset.id }
        if preferences.selectedAIModelID == preset.id {
            preferences.selectedAIModelID = preferences.aiModelPresets.first?.id
            if preferences.aiModelPresets.isEmpty { preferences.aiConfiguration = AIConfiguration() }
        }
        pendingDeletion = nil
    }
}

private struct ModelEditorContext: Identifiable { let id = UUID(); let preset: AIModelPreset? }

private struct AIModelEditorView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var preset: AIModelPreset
    @State private var baseURLText: String
    @State private var isKeyVisible = false
    @State private var status: String?
    @State private var requestState = AIRequestState()
    @State private var requestTask: Task<Void, Never>?
    let client: any AIRequesting
    let onSave: (AIModelPreset) -> Void

    init(preset: AIModelPreset?, client: any AIRequesting, onSave: @escaping (AIModelPreset) -> Void) {
        let value = preset ?? AIModelPreset(name: "", configuration: AIConfiguration())
        _preset = State(initialValue: value)
        _baseURLText = State(initialValue: value.configuration.baseURL.absoluteString)
        self.client = client
        self.onSave = onSave
    }

    var body: some View {
        Form {
            TextField(AppLocalization.text("settings.ai.model", language: language), text: $preset.name)
                .accessibilityIdentifier("settings-ai-preset-name")
            Picker(AppLocalization.text("settings.ai.protocol", language: language), selection: $preset.configuration.protocolType) {
                ForEach(AIProtocol.allCases) { Text($0.displayName).tag($0) }
            }
            TextField(AppLocalization.text("settings.ai.baseURL", language: language), text: $baseURLText)
                .accessibilityIdentifier("settings-ai-base-url")
            TextField(AppLocalization.text("settings.ai.model", language: language), text: $preset.configuration.model)
                .accessibilityIdentifier("settings-ai-model")
            LabeledContent(AppLocalization.text("settings.ai.apiKey", language: language)) {
                HStack(spacing: 6) {
                    Group {
                        if isKeyVisible { TextField("", text: $preset.configuration.apiKey) }
                        else { SecureField("", text: $preset.configuration.apiKey) }
                    }
                    .accessibilityIdentifier("settings-ai-api-key")
                    Button { isKeyVisible.toggle() } label: { Image(systemName: isKeyVisible ? "eye.slash" : "eye") }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("settings-ai-toggle-api-key")
                }
            }
            HStack {
                Button(AppLocalization.text("settings.ai.test", language: language)) { testConnection() }
                    .disabled(requestTask != nil)
                    .accessibilityIdentifier("settings-ai-test")
                if requestState.isLoading { TasteSpinner(reduceMotion: reduceMotion) }
                if let status { Text(status).foregroundStyle(.secondary).accessibilityIdentifier("settings-ai-status") }
            }
        }
        .formStyle(.grouped).padding(20).frame(minWidth: 520, minHeight: 360)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(AppLocalization.text("button.cancel", language: language)) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(AppLocalization.text("button.save", language: language)) { save() }
                    .disabled(preset.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear { isKeyVisible = false }
        .onDisappear { requestTask?.cancel() }
    }

    private func validatedPreset() throws -> AIModelPreset {
        guard let url = URL(string: baseURLText), url.scheme != nil, url.host != nil else { throw AIClientError.invalidBaseURL }
        var result = preset
        result.name = result.name.trimmingCharacters(in: .whitespacesAndNewlines)
        result.configuration.baseURL = url
        return result
    }

    private func save() {
        do { onSave(try validatedPreset()) }
        catch { status = localizedAIError(error, language: language) }
    }

    private func testConnection() {
        status = nil
        requestTask = Task { @MainActor in
            defer { requestTask = nil }
            do {
                var validated = try validatedPreset()
                try await requestState.perform { try await client.testConnection(configuration: validated.configuration) }
                validated.connectionStatus = .connected
                preset = validated
                status = AppLocalization.text("settings.ai.ready", language: language)
            } catch is CancellationError {
            } catch {
                preset.connectionStatus = .failed
                status = localizedAIError(error, language: language)
            }
        }
    }
}

func localizedAIError(_ error: Error, language: AppLanguage) -> String {
    guard let error = error as? AIClientError else { return AppLocalization.text("ai.error.network", language: language) }
    let key: String
    switch error {
    case .apiKeyMissing: key = "ai.error.apiKey"
    case .invalidBaseURL: key = "ai.error.baseURL"
    case .invalidModel: key = "ai.error.model"
    case .ledgerDataPermissionRequired: key = "ai.analysis.permissionRequired"
    case .network: key = "ai.error.network"
    case .httpStatus: key = "ai.error.http"
    case .responseDecoding: key = "ai.error.decoding"
    case .invalidStructuredResult: key = "ai.error.invalidResult"
    }
    return AppLocalization.text(key, language: language)
}
