import SwiftUI

struct AILedgerAssistantView: View {
    private enum Mode {
        case entry
        case analysis
    }

    @Environment(\.appLanguage) private var language
    @Environment(\.appCurrencyCode) private var currencyCode
    @State private var mode: Mode = .entry
    @State private var prompt = ""
    @State private var question = ""
    @State private var analysisStart = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var analysisEnd = Date.now
    @State private var analysisResult: String?
    @State private var drafts: [AILedgerDraft] = []
    @State private var error: String?
    @State private var isLoading = false
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
            Spacer()
        }
        .padding(28)
        .foregroundStyle(theme.primaryText.color)
        .background(theme.canvas.color)
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
            HStack {
                TextField(AppLocalization.text("ai.prompt", language: language), text: $prompt)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("ai-prompt")
                Button(AppLocalization.text("ai.generate", language: language)) { generate() }
                    .buttonStyle(.borderedProminent)
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                    .accessibilityIdentifier("ai-generate")
            }
            Text(AppLocalization.text("ai.preview.range", language: language))
                .font(.caption)
                .foregroundStyle(theme.secondaryText.color)
        }
    }

    private var analysisForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField(AppLocalization.text("ai.analysis.question", language: language), text: $question)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("ai-analysis-question")

            HStack {
                DatePicker(
                    AppLocalization.text("ai.analysis.start", language: language),
                    selection: $analysisStart,
                    displayedComponents: .date
                )
                DatePicker(
                    AppLocalization.text("ai.analysis.end", language: language),
                    selection: $analysisEnd,
                    displayedComponents: .date
                )
            }
            .padding(12)
            .background(theme.surface.color, in: RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(AppLocalization.text("ai.analysis.scope", language: language))
            .accessibilityIdentifier("ai-analysis-scope")

            if !dependencies.preferences.aiConfiguration.allowsLedgerData {
                Text(AppLocalization.text("ai.analysis.permissionRequired", language: language))
                    .foregroundStyle(theme.secondaryText.color)
                    .accessibilityIdentifier("ai-permission-scope")
            }

            Button(AppLocalization.text("ai.analysis.run", language: language)) { analyze() }
                .buttonStyle(.borderedProminent)
                .disabled(
                    question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || !dependencies.preferences.aiConfiguration.allowsLedgerData
                        || isLoading
                )
                .accessibilityIdentifier("ai-analyze")

            if let analysisResult {
                GroupBox(AppLocalization.text("ai.analysis.result", language: language)) {
                    Text(analysisResult)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .accessibilityIdentifier("ai-analysis-result")
            }
        }
    }

    private func generate() {
        isLoading = true
        error = nil
        Task { @MainActor in
            defer { isLoading = false }
            do {
                let result = try await client.parseLedger(
                    text: prompt,
                    currencyCode: currencyCode,
                    configuration: dependencies.preferences.aiConfiguration
                )
                drafts = result.entries
                showPreview = true
            } catch {
                self.error = localizedAIError(error, language: language)
            }
        }
    }

    private func analyze() {
        isLoading = true
        error = nil
        analysisResult = nil
        Task { @MainActor in
            defer { isLoading = false }
            do {
                let calendar = Calendar.autoupdatingCurrent
                let lower = min(analysisStart, analysisEnd)
                let upper = max(analysisStart, analysisEnd)
                let start = calendar.startOfDay(for: lower)
                guard let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: upper)) else {
                    throw AIClientError.invalidStructuredResult("Invalid date interval")
                }
                let interval = DateInterval(start: start, end: end)
                let entries = try await dependencies.repository.entries(in: interval)
                var categoryNames: [UUID: String] = [:]
                for id in Set(entries.map(\.categoryID)) {
                    if let category = try await dependencies.repository.category(id: id) {
                        categoryNames[id] = category.systemKey ?? category.customName ?? "other"
                    }
                }
                let scope = AIAnalysisScope(
                    interval: interval,
                    currencyCode: currencyCode,
                    entries: entries,
                    categoryNames: categoryNames
                )
                analysisResult = try await client.analyze(
                    question: question,
                    scope: scope,
                    configuration: dependencies.preferences.aiConfiguration
                )
            } catch {
                self.error = localizedAIError(error, language: language)
            }
        }
    }
}

private struct AILedgerPreviewView: View {
    @Environment(\.appLanguage) private var language
    @State private var drafts: [AILedgerDraft]
    @State private var error: String?
    @State private var isSaving = false

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
                Text(LedgerFormatting.amount(drafts[index].amount, currencyCode: currencyCode))
                    .accessibilityIdentifier("ai-draft-formatted-amount-\(index)")
                DatePicker("", selection: $drafts[index].date, displayedComponents: .date)
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
                            occurredAt: draft.date
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
