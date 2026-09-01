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
            if requestState.isLoading {
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
        .onDisappear { requestTask?.cancel() }
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
                Spacer()
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
                let result = try await requestState.perform {
                    try await client.parseLedger(
                        text: prompt,
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
        requestTask = Task { @MainActor in
            defer { requestTask = nil }
            do {
                analysisResult = try await requestState.perform {
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
                    return try await client.analyze(
                        question: question,
                        scope: scope,
                        configuration: dependencies.preferences.aiConfiguration
                    )
                }
            } catch is CancellationError {
            } catch {
                self.error = localizedAIError(error, language: language)
            }
        }
    }
}

enum AIAnalysisResultLayout {
    static func shouldScroll(contentHeight: CGFloat, availableHeight: CGFloat) -> Bool {
        contentHeight > availableHeight
    }

    static func contentHeight(for text: String, width: CGFloat) -> CGFloat {
        let contentWidth = max(width - 24, 1)
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: NSFont.preferredFont(forTextStyle: .body)]
        )
        return max(44, ceil(bounds.height) + 24)
    }
}

private struct AdaptiveAnalysisResult: View {
    let text: String
    let surface: Color

    var body: some View {
        GeometryReader { proxy in
            let contentHeight = AIAnalysisResultLayout.contentHeight(for: text, width: proxy.size.width)
            let availableHeight = max(proxy.size.height, 70)
            let shouldScroll = AIAnalysisResultLayout.shouldScroll(
                contentHeight: contentHeight,
                availableHeight: availableHeight
            )

            Group {
                if shouldScroll {
                    ScrollView {
                        resultText
                    }
                } else {
                    resultText
                        .frame(height: contentHeight, alignment: .top)
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: shouldScroll ? .infinity : contentHeight,
                alignment: .top
            )
            .background(surface, in: RoundedRectangle(cornerRadius: 10))
        }
        .frame(minHeight: 70, maxHeight: .infinity)
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

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == 36 || event.keyCode == 76 else {
            super.keyDown(with: event)
            return
        }
        let shiftPressed = event.modifierFlags.contains(.shift)
        guard MultilineSubmitBehavior.shouldSubmit(
            shiftPressed: shiftPressed,
            hasMarkedText: hasMarkedText()
        ) else {
            super.keyDown(with: event)
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
    }

    private func draftEditor(at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("", selection: $drafts[index].kind) {
                    Text(AppLocalization.text("entry.expense", language: language)).tag(EntryKind.expense)
                    Text(AppLocalization.text("entry.income", language: language)).tag(EntryKind.income)
                }
                .frame(width: 130)
                TextField("0", value: $drafts[index].amount, format: .number)
                    .frame(width: 110)
                    .onSubmit { save() }
                DatePicker("", selection: $drafts[index].date, displayedComponents: .date)
                    .environment(\.locale, language.datePickerLocale)
                Spacer()
                Button(AppLocalization.text("ai.preview.remove", language: language)) {
                    drafts.remove(at: index)
                }
            }
            HStack {
                Picker(AppLocalization.text("entry.category", language: language), selection: $drafts[index].category) {
                    ForEach(categoryKeys(for: drafts[index].kind), id: \.self) { key in
                        Text(AppLocalization.categoryName(systemKey: key, language: language)).tag(key)
                    }
                }
                TextField(AppLocalization.text("entry.note", language: language), text: $drafts[index].note)
                    .onSubmit { save() }
            }
        }
        .padding(12)
        .background(theme.surface.color, in: RoundedRectangle(cornerRadius: 10))
    }

    private func categoryKeys(for kind: EntryKind) -> [String] {
        switch kind {
        case .expense: ["clothing", "food", "housing", "transport", "entertainment", "other"]
        case .income: ["salary", "bonus", "investment", "refund", "other"]
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
                        ($0.systemKey ?? "").caseInsensitiveCompare(draft.category) == .orderedSame
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
