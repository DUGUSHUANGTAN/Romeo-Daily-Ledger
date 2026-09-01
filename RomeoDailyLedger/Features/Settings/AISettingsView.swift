import SwiftUI

struct AISettingsView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var preferences: AppPreferences
    @State private var editor: ModelEditorContext?
    @State private var pendingDeletion: AIModelPreset?
    @State private var testingModelIDs: Set<UUID> = []
    @State private var draggingModelID: UUID?
    @State private var modelDragTranslation: CGSize = .zero
    @State private var modelDropTargetID: UUID?
    @State private var modelDropAfter = false
    @State private var modelFrames: [UUID: CGRect] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let client: any AIRequesting

    init(preferences: AppPreferences, client: any AIRequesting = AIClient()) {
        self.preferences = preferences
        self.client = client
    }

    var body: some View {
        Form {
            Section(AppLocalization.text("settings.ai.models", language: language)) {
                ForEach(preferences.aiModelPresets) { preset in modelRow(preset) }
                Button { editor = ModelEditorContext(preset: nil) } label: {
                    Label(AppLocalization.text("settings.ai.connection", language: language), systemImage: "plus")
                }
                .accessibilityIdentifier("settings-ai-add-model")
                Text(AppLocalization.text("settings.ai.models.hint", language: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button(AppLocalization.text("settings.ai.clearAnalysisHistory", language: language), role: .destructive) {
                    preferences.aiAnalysisHistory.removeAll()
                }
                .disabled(preferences.aiAnalysisHistory.isEmpty)
            }
        }
        .formStyle(.grouped)
        .coordinateSpace(name: "model-drag-space")
        .onPreferenceChange(ModelFramePreferenceKey.self) { modelFrames = $0 }
        .navigationTitle(AppLocalization.text("settings.ai.title", language: language))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.leading, 16)
        .padding(.trailing, 24)
        .accessibilityIdentifier("settings-ai")
        .task { await refreshConnectionStatuses() }
        .sheet(item: $editor) { context in
            AIModelEditorView(preset: context.preset, client: client) { saved in
                save(saved)
                editor = nil
            }
        }
        .alert(
            AppLocalization.text("settings.ai.deleteModel.title", language: language),
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            presenting: pendingDeletion
        ) { preset in
            Button(AppLocalization.text("button.cancel", language: language), role: .cancel) {}
            Button(AppLocalization.text("button.delete", language: language), role: .destructive) { delete(preset) }
        } message: { _ in Text(AppLocalization.text("settings.ai.deleteModel.message", language: language)) }
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
                .opacity(testingModelIDs.contains(preset.id) ? 0 : 1)
                .overlay { if testingModelIDs.contains(preset.id) { TasteSpinner(reduceMotion: reduceMotion) } }
                .accessibilityLabel(AppLocalization.text(
                    preset.connectionStatus.isConnected ? "settings.ai.status.connected" : "settings.ai.status.notConnected",
                    language: language
                ))
        }
        .padding(.vertical, 7).padding(.horizontal, 10)
        .contentShape(Rectangle())
        .onTapGesture { preferences.selectedAIModelID = preset.id }
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(preferences.selectedAIModelID == preset.id ? Color.accentColor : Color.secondary.opacity(0.35)) }
        .overlay(alignment: .top) {
            if modelDropTargetID == preset.id, draggingModelID != preset.id, !modelDropAfter {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(height: 3)
                    .padding(.horizontal, 8)
                    .offset(y: -6)
            }
        }
        .overlay(alignment: .bottom) {
            if modelDropTargetID == preset.id, draggingModelID != preset.id, modelDropAfter {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(height: 3)
                    .padding(.horizontal, 8)
                    .offset(y: 6)
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: ModelFramePreferenceKey.self,
                    value: [preset.id: proxy.frame(in: .named("model-drag-space"))]
                )
            }
        }
        .scaleEffect(draggingModelID == preset.id ? 1.025 : 1)
        .offset(draggingModelID == preset.id ? modelDragTranslation : .zero)
        .shadow(color: .black.opacity(draggingModelID == preset.id ? 0.18 : 0), radius: 14, y: 7)
        .zIndex(draggingModelID == preset.id ? 10 : 0)
        .animation(.snappy(duration: 0.2), value: draggingModelID)
        .animation(.snappy(duration: 0.18), value: modelDropTargetID)
        .listRowSeparator(.hidden)
        .highPriorityGesture(modelDragGesture(for: preset))
    }

    private func modelDragGesture(for preset: AIModelPreset) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named("model-drag-space"))
            .onChanged { value in
                draggingModelID = preset.id
                modelDragTranslation = value.translation
                modelDropTargetID = preferences.aiModelPresets
                    .filter { $0.id != preset.id }
                    .min {
                        abs((modelFrames[$0.id]?.midY ?? .greatestFiniteMagnitude) - value.location.y)
                            < abs((modelFrames[$1.id]?.midY ?? .greatestFiniteMagnitude) - value.location.y)
                    }?.id
                if let targetID = modelDropTargetID, let frame = modelFrames[targetID] {
                    modelDropAfter = value.location.y > frame.midY
                }
            }
            .onEnded { _ in
                if let targetID = modelDropTargetID {
                    preferences.aiModelPresets = AIModelPresetOrder.reordered(
                        preferences.aiModelPresets,
                        moving: preset.id,
                        relativeTo: targetID,
                        placeAfter: modelDropAfter
                    )
                }
                withAnimation(.snappy(duration: 0.24)) {
                    draggingModelID = nil
                    modelDragTranslation = .zero
                    modelDropTargetID = nil
                    modelDropAfter = false
                }
            }
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

    private func moveModels(from source: IndexSet, to destination: Int) {
        preferences.aiModelPresets = AIModelPresetOrder.reordered(
            preferences.aiModelPresets,
            from: source,
            to: destination
        )
    }

    @MainActor
    private func refreshConnectionStatuses() async {
        let presets = preferences.aiModelPresets
        testingModelIDs = Set(presets.map(\.id))
        await withTaskGroup(of: (UUID, AIModelConnectionStatus).self) { group in
            for preset in presets {
                group.addTask {
                    do {
                        try await client.testConnection(configuration: preset.configuration)
                        return (preset.id, .connected)
                    } catch { return (preset.id, .failed) }
                }
            }
            for await (id, status) in group {
                if let index = preferences.aiModelPresets.firstIndex(where: { $0.id == id }) {
                    preferences.aiModelPresets[index].connectionStatus = status
                }
                testingModelIDs.remove(id)
            }
        }
    }
}

private struct ModelFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

enum AIModelPresetOrder {
    static func reordered(_ presets: [AIModelPreset], from source: IndexSet, to destination: Int) -> [AIModelPreset] {
        var result = presets
        result.move(fromOffsets: source, toOffset: destination)
        return result
    }

    static func reordered(_ presets: [AIModelPreset], moving sourceID: UUID, before targetID: UUID) -> [AIModelPreset] {
        reordered(presets, moving: sourceID, relativeTo: targetID, placeAfter: false)
    }

    static func reordered(
        _ presets: [AIModelPreset],
        moving sourceID: UUID,
        relativeTo targetID: UUID,
        placeAfter: Bool
    ) -> [AIModelPreset] {
        guard let source = presets.first(where: { $0.id == sourceID }),
              presets.contains(where: { $0.id == targetID }) else { return presets }
        var result = presets.filter { $0.id != sourceID }
        guard let targetIndex = result.firstIndex(where: { $0.id == targetID }) else { return presets }
        result.insert(source, at: targetIndex + (placeAfter ? 1 : 0))
        return result
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
            TextField(AppLocalization.text("settings.ai.modelProviderName", language: language), text: $preset.name)
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
                        .accessibilityLabel(AppLocalization.text(
                            isKeyVisible ? "settings.ai.apiKey.hide" : "settings.ai.apiKey.show",
                            language: language
                        ))
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
