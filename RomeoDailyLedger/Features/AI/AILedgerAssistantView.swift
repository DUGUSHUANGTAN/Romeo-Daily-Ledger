import AppKit
import SwiftUI

struct AILedgerAssistantView: View {
    private enum Mode {
        case entry
        case analysis
    }

    @Environment(\.appLanguage) private var language
    @Environment(\.appCurrencyCode) private var currencyCode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mode: Mode = .entry
    @State private var prompt = ""
    @State private var question = ""
    @State private var analysisResult: String?
    @State private var drafts: [AILedgerDraft] = []
    @State private var error: String?
    @State private var requestState = AIRequestState()
    @State private var requestTask: Task<Void, Never>?
    @State private var showPreview = false
    @State private var showAnalysisHistory = false
    @State private var analysisDidEmit = false

    let dependencies: AppDependencies
    let theme: AppTheme
    let typography: AppTypography.Style
    private let client: any AIRequesting

    init(
        dependencies: AppDependencies,
        theme: AppTheme,
        typography: AppTypography.Style,
        client: (any AIRequesting)? = nil
    ) {
        self.dependencies = dependencies
        self.theme = theme
        self.typography = typography
        self.client = client ?? dependencies.aiClient
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(AppLocalization.text("ai.title", language: language))
                .font(AppTypography.display(typography))
            Text(AppLocalization.text("ai.subtitle", language: language))
                .foregroundStyle(theme.secondaryText.color)

            HStack {
                Button(AppLocalization.text("ai.mode.entry", language: language)) { mode = .entry }
                    .buttonStyle(.bordered)
                    .tint(mode == .entry ? .accentColor : .secondary)
                    .accessibilityIdentifier("ai-mode-entry")
                Button(AppLocalization.text("ai.mode.analysis", language: language)) { mode = .analysis }
                    .buttonStyle(.bordered)
                    .tint(mode == .analysis ? .accentColor : .secondary)
                    .accessibilityIdentifier("ai-mode-analysis")
            }

            switch mode {
            case .entry:
                entryForm
            case .analysis:
                analysisForm
            }

            if let error {
                Text(error)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("ai-error")
            }
            if requestState.isLoading, mode != .analysis {
                HStack {
                    TasteSpinner(reduceMotion: reduceMotion)
                    Text(AppLocalization.text("ai.loading", language: language))
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("ai-loading")
            }
            Spacer(minLength: 0)
        }
        .padding(28)
        .foregroundStyle(theme.primaryText.color)
        .background(theme.canvas.color)
        .onChange(of: mode) { oldMode, newMode in
            if oldMode == .analysis, newMode != .analysis, !analysisDidEmit { requestTask?.cancel() }
        }
        .onDisappear {
            if mode != .analysis || !analysisDidEmit { requestTask?.cancel() }
        }
        .sheet(isPresented: $showPreview) {
            AILedgerPreviewView(
                drafts: drafts,
                currencyCode: currencyCode,
                repository: dependencies.repository,
                theme: theme,
                typography: typography
            ) {
                showPreview = false
                prompt = ""
            }
        }
        .sheet(isPresented: $showAnalysisHistory) {
            AIAnalysisHistoryView(preferences: dependencies.preferences, theme: theme, typography: typography)
        }
    }

    private var entryForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            MultilineSubmitTextEditor(
                text: $prompt,
                prompt: AppLocalization.text("ai.prompt", language: language),
                minHeight: 112,
                accessibilityIdentifier: "ai-prompt",
                onSubmit: generate
            )
            HStack {
                Button(AppLocalization.text("ai.generate", language: language)) { generate() }
                    .buttonStyle(.borderedProminent)
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || requestTask != nil)
                    .accessibilityIdentifier("ai-generate")
            }
            Text(AppLocalization.text("ai.preview.range", language: language))
                .font(.caption)
                .foregroundStyle(theme.secondaryText.color)
        }
    }

    private var analysisForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            MultilineSubmitTextEditor(
                text: $question,
                prompt: AppLocalization.text("ai.analysis.question", language: language),
                minHeight: 96,
                accessibilityIdentifier: "ai-analysis-question",
                onSubmit: analyze
            )

            Button(AppLocalization.text("ai.analysis.run", language: language)) { analyze() }
                .buttonStyle(.borderedProminent)
                .disabled(
                    question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || requestTask != nil
                )
                .accessibilityIdentifier("ai-analyze")
            Button(AppLocalization.text("ai.analysis.history", language: language)) { showAnalysisHistory = true }
                .accessibilityIdentifier("ai-analysis-history")

            if requestState.isLoading, !analysisDidEmit {
                HStack {
                    TasteSpinner(reduceMotion: reduceMotion)
                    Text(AppLocalization.text("ai.loading", language: language))
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("ai-loading")
            }

            if let analysisResult {
                VStack(alignment: .leading, spacing: 8) {
                    Text(AppLocalization.text("ai.analysis.result", language: language))
                        .font(.headline)
                    AdaptiveAnalysisResult(text: analysisResult, surface: theme.surface.color)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .accessibilityIdentifier("ai-analysis-result")
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func generate() {
        guard requestTask == nil,
              !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        error = nil
        requestTask = Task { @MainActor in
            defer { requestTask = nil }
            do {
                let localCategories = ((try? await dependencies.repository.categories(kind: .expense)) ?? [])
                    + ((try? await dependencies.repository.categories(kind: .income)) ?? [])
                let categoryContext = localCategories.map { LedgerFormatting.categoryName($0, language: language) }.joined(separator: ", ")
                let result = try await requestState.perform {
                    try await client.parseLedger(
                        text: "\(prompt)\nLocal categories: \(categoryContext)",
                        currencyCode: currencyCode,
                        configuration: dependencies.preferences.aiConfiguration
                    )
                }
                drafts = result.entries
                showPreview = true
            } catch is CancellationError {
            } catch {
                self.error = localizedAIError(error, language: language)
            }
        }
    }

    private func analyze() {
        guard requestTask == nil,
              !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        error = nil
        let submittedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        analysisResult = nil
        analysisDidEmit = false
        requestTask = Task { @MainActor in
            defer { requestTask = nil }
            do {
                let answer = try await requestState.perform {
                    let entries = try await dependencies.repository.allEntries()
                    var categoryNames: [UUID: String] = [:]
                    for id in Set(entries.map(\.categoryID)) {
                        if let category = try await dependencies.repository.category(id: id) {
                            categoryNames[id] = category.systemKey ?? category.customName ?? "other"
                        }
                    }
                    let scope = AIAnalysisScope(
                        currencyCode: currencyCode,
                        entries: entries,
                        categoryNames: categoryNames
                    )
                    var accumulated = ""
                    let completion = AnalysisStreamCompletion()
                    for try await delta in client.streamAnalysis(
                        question: submittedQuestion,
                        scope: scope,
                        configuration: dependencies.preferences.aiConfiguration,
                        onComplete: { completion.finish(with: $0) }
                    ) {
                        if completion.text != nil { break }
                        analysisDidEmit = true
                        accumulated.append(delta)
                        analysisResult = accumulated
                    }
                    if let completedText = completion.text {
                        accumulated = completedText
                        analysisResult = completedText
                    }
                    guard !accumulated.isEmpty else { throw AIClientError.responseDecoding("Missing model content") }
                    return accumulated
                }
                analysisResult = answer
                dependencies.preferences.aiAnalysisHistory.insert(
                    AIAnalysisHistoryItem(question: submittedQuestion, answer: answer),
                    at: 0
                )
            } catch is CancellationError {
                analysisResult = nil
            } catch {
                analysisResult = nil
                self.error = localizedAIError(error, language: language)
            }
        }
    }
}

private final class AnalysisStreamCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var storedText: String?

    var text: String? { lock.withLock { storedText } }

    func finish(with text: String) {
        lock.withLock { storedText = text }
    }
}

private struct AdaptiveAnalysisResult: View {
    let text: String
    let surface: Color

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                resultText
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                Color.clear.frame(height: 1).id("analysis-stream-bottom")
            }
            .onChange(of: text) { _, _ in
                proxy.scrollTo("analysis-stream-bottom", anchor: .bottom)
            }
        }
        .frame(minHeight: 70, maxHeight: .infinity, alignment: .top)
        .background(surface, in: RoundedRectangle(cornerRadius: 10))
    }

    private var resultText: some View {
        Text(text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .padding(12)
    }
}

struct MultilineSubmitTextEditor: View {
    @Environment(\.appLanguage) private var language
    @Binding var text: String
    let prompt: String
    let minHeight: CGFloat
    var accessibilityIdentifier = ""
    let onSubmit: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(prompt)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
            ComposingTextView(text: $text, accessibilityIdentifier: accessibilityIdentifier, onSubmit: onSubmit)
        }
        .frame(height: minHeight)
        .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(.separator, lineWidth: 1)
        }
        .help(AppLocalization.text("ai.multiline.submitHint", language: language))
    }
}

enum MultilineSubmitBehavior {
    static func shouldSubmit(shiftPressed: Bool, hasMarkedText: Bool) -> Bool {
        !shiftPressed && !hasMarkedText
    }

    static func shouldSubmit(command: String, shiftPressed: Bool, hasMarkedText: Bool) -> Bool {
        guard command == "insertNewline:" || command == "insertNewlineIgnoringFieldEditor:" else { return false }
        return shouldSubmit(shiftPressed: shiftPressed, hasMarkedText: hasMarkedText)
    }
}

private struct ComposingTextView: NSViewRepresentable {
    @Binding var text: String
    let accessibilityIdentifier: String
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = SubmitAwareTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = .preferredFont(forTextStyle: .body)
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.setAccessibilityIdentifier(accessibilityIdentifier)
        textView.onSubmit = onSubmit
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? SubmitAwareTextView else { return }
        if textView.string != text { textView.string = text }
        textView.onSubmit = onSubmit
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ComposingTextView
        init(parent: ComposingTextView) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

private final class SubmitAwareTextView: NSTextView {
    var onSubmit: (() -> Void)?

    override func doCommand(by selector: Selector) {
        let shiftPressed = NSApp.currentEvent?.modifierFlags.contains(.shift) == true
        guard MultilineSubmitBehavior.shouldSubmit(
            command: NSStringFromSelector(selector),
            shiftPressed: shiftPressed,
            hasMarkedText: hasMarkedText()
        ) else {
            super.doCommand(by: selector)
            return
        }
        onSubmit?()
    }
}

struct TasteSpinner: View {
    let reduceMotion: Bool
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(Color.accentColor)
                    .frame(width: 4, height: 12)
                    .scaleEffect(y: reduceMotion ? 0.72 : (animating ? 1 : 0.45))
                    .opacity(reduceMotion ? 0.8 : (animating ? 1 : 0.45))
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 0.52)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.11),
                        value: animating
                    )
            }
        }
        .frame(width: 22, height: 16)
        .onAppear {
            if !reduceMotion { animating = true }
        }
        .onChange(of: reduceMotion) { _, isReduced in
            animating = !isReduced
        }
        .accessibilityHidden(true)
    }
}

private struct AILedgerPreviewView: View {
    @Environment(\.appLanguage) private var language
    @State private var drafts: [AILedgerDraft]
    @State private var error: String?
    @State private var isSaving = false
    @State private var categories: [Category] = []
    private let dateNormalizer = AppDateNormalizer()

    let currencyCode: String
    let repository: LedgerRepository
    let theme: AppTheme
    let typography: AppTypography.Style
    let onSaved: () -> Void

    init(
        drafts: [AILedgerDraft],
        currencyCode: String,
        repository: LedgerRepository,
        theme: AppTheme,
        typography: AppTypography.Style,
        onSaved: @escaping () -> Void
    ) {
        _drafts = State(initialValue: drafts)
        self.currencyCode = currencyCode
        self.repository = repository
        self.theme = theme
        self.typography = typography
        self.onSaved = onSaved
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppLocalization.text("ai.preview.title", language: language))
                .font(AppTypography.display(typography))
            Text(AppLocalization.text("ai.preview.range", language: language))
                .foregroundStyle(theme.secondaryText.color)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(drafts.indices, id: \.self) { index in
                        draftEditor(at: index)
                    }
                }
            }

            if let error { Text(error).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button(AppLocalization.text("button.cancel", language: language)) { onSaved() }
                    .disabled(isSaving)
                    .accessibilityIdentifier("ai-preview-cancel")
                Button(AppLocalization.text("ai.preview.confirm", language: language)) { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(drafts.isEmpty || isSaving)
                    .accessibilityIdentifier("ai-confirm")
            }
        }
        .padding(24)
        .frame(minWidth: 620, minHeight: 420)
        .background(theme.canvas.color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ai-preview")
        .task { await loadCategories() }
    }

    private func draftEditor(at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("", selection: $drafts[index].kind) {
                    Text(AppLocalization.text("entry.expense", language: language)).tag(EntryKind.expense)
                    Text(AppLocalization.text("entry.income", language: language)).tag(EntryKind.income)
                }
                .frame(width: 130)
                HStack(spacing: 4) {
                    Text(LedgerFormatting.currencySymbol(for: currencyCode))
                        .foregroundStyle(theme.secondaryText.color)
                    TextField("0", value: $drafts[index].amount, format: .number)
                        .onSubmit { save() }
                }
                .frame(width: 130)
                DatePicker("", selection: $drafts[index].date, displayedComponents: .date)
                    .environment(\.locale, language.datePickerLocale)
                Spacer()
                Button(AppLocalization.text("ai.preview.remove", language: language)) {
                    drafts.remove(at: index)
                }
            }
            HStack {
                Picker(AppLocalization.text("entry.category", language: language), selection: $drafts[index].category) {
                    ForEach(categoryOptions(for: drafts[index].kind), id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                TextField(AppLocalization.text("entry.note", language: language), text: $drafts[index].note)
                    .onSubmit { save() }
            }
        }
        .padding(12)
        .background(theme.surface.color, in: RoundedRectangle(cornerRadius: 10))
    }

    private func categoryOptions(for kind: EntryKind) -> [String] {
        categories.filter { $0.kind == kind }.map { LedgerFormatting.categoryName($0, language: language) }
    }

    private func loadCategories() async {
        let expense = (try? await repository.categories(kind: .expense)) ?? []
        let income = (try? await repository.categories(kind: .income)) ?? []
        categories = expense + income
        for index in drafts.indices {
            let options = categoryOptions(for: drafts[index].kind)
            if !options.contains(where: { $0.caseInsensitiveCompare(drafts[index].category) == .orderedSame }) {
                drafts[index].category = categories.first(where: { $0.kind == drafts[index].kind && $0.systemKey == "other" }).map {
                    LedgerFormatting.categoryName($0, language: language)
                } ?? options.last ?? "other"
            }
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        error = nil
        Task { @MainActor in
            defer { isSaving = false }
            do {
                guard drafts.allSatisfy({ $0.currency.uppercased() == currencyCode.uppercased() }) else {
                    throw AIClientError.invalidStructuredResult("Currency mismatch")
                }
                var ledgerDrafts: [LedgerDraft] = []
                ledgerDrafts.reserveCapacity(drafts.count)
                for draft in drafts {
                    let categories = try await repository.categories(kind: draft.kind)
                    let categoryID = categories.first {
                        LedgerFormatting.categoryName($0, language: language).caseInsensitiveCompare(draft.category) == .orderedSame
                    }?.id
                    ledgerDrafts.append(
                        LedgerDraft(
                            kind: draft.kind,
                            amountText: draft.amount.description,
                            categoryID: categoryID,
                            note: draft.note,
                            occurredAt: dateNormalizer.normalize(draft.date)
                        )
                    )
                }
                _ = try await repository.insert(ledgerDrafts)
                onSaved()
            } catch let clientError as AIClientError {
                if case .invalidStructuredResult("Currency mismatch") = clientError {
                    error = AppLocalization.text("ai.error.currency", language: language)
                } else {
                    error = localizedAIError(clientError, language: language)
                }
            } catch {
                self.error = AppLocalization.text("ai.error.invalidResult", language: language)
            }
        }
    }
}

private struct AIAnalysisHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @Bindable var preferences: AppPreferences
    let theme: AppTheme
    let typography: AppTypography.Style
    @State private var selected: AIAnalysisHistoryItem?
    @State private var selectedHistoryIDs: Set<UUID> = []
    @State private var isDeletionConfirmationPresented = false

    var body: some View {
        NavigationSplitView {
            List(preferences.aiAnalysisHistory) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.question).lineLimit(2)
                        Text(item.createdAt, format: .dateTime.year().month().day().hour().minute().locale(language.locale))
                            .font(AppTypography.caption(typography)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    selectedHistoryIDs.contains(item.id) ? theme.primaryAccent.color.opacity(0.16) : .clear,
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .contentShape(Rectangle())
                .gesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .exclusively(before: TapGesture())
                        .onEnded { value in
                            switch value {
                            case .first:
                                selectedHistoryIDs.insert(item.id)
                            case .second:
                                if selectedHistoryIDs.isEmpty {
                                    selected = item
                                } else if !selectedHistoryIDs.insert(item.id).inserted {
                                    selectedHistoryIDs.remove(item.id)
                                }
                            }
                        }
                )
                .accessibilityAddTraits(.isButton)
                .accessibilityAddTraits(selectedHistoryIDs.contains(item.id) ? .isSelected : [])
                .accessibilityValue(AppLocalization.text(selectedHistoryIDs.contains(item.id) ? "accessibility.selected" : "accessibility.notSelected", language: language))
                .accessibilityIdentifier("ai-analysis-history-row-\(item.id.uuidString.lowercased())")
            }
            .navigationTitle(AppLocalization.text("ai.analysis.history", language: language))
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            if let selected = selected ?? preferences.aiAnalysisHistory.first {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(selected.question).font(AppTypography.title(typography))
                        Text(selected.answer).font(AppTypography.body(typography)).textSelection(.enabled)
                    }
                    .padding(24).frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text(AppLocalization.text("ai.analysis.history.empty", language: language)).foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 760, minHeight: 480)
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                HStack(spacing: 12) {
                    if selectedHistoryIDs.isEmpty {
                        Text(AppLocalization.text("ai.analysis.history.selectionHint", language: language))
                            .font(AppTypography.caption(typography))
                            .foregroundStyle(theme.secondaryText.color)
                            .accessibilityIdentifier("ai-analysis-history-selection-hint")
                    } else {
                        Button(AppLocalization.text("button.deleteSelected", language: language)) {
                            isDeletionConfirmationPresented = true
                        }
                        .tint(.red)
                        Button(AppLocalization.text("button.cancelSelection", language: language)) {
                            selectedHistoryIDs.removeAll()
                        }
                        Text(AppLocalization.format("ai.analysis.history.selectedCount", language: language, selectedHistoryIDs.count))
                            .font(AppTypography.caption(typography))
                    }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(AppLocalization.text("button.done", language: language)) { dismiss() }
            }
        }
        .confirmationDialog(
            AppLocalization.text("ledger.delete.confirmTitle", language: language),
            isPresented: $isDeletionConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(AppLocalization.text("button.confirmDelete", language: language), role: .destructive) {
                if let selected, selectedHistoryIDs.contains(selected.id) { self.selected = nil }
                preferences.aiAnalysisHistory.removeAll { selectedHistoryIDs.contains($0.id) }
                selectedHistoryIDs.removeAll()
            }
            Button(AppLocalization.text("button.cancel", language: language), role: .cancel) {}
        }
    }
}
