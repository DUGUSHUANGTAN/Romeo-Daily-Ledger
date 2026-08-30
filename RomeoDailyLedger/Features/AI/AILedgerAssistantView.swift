import SwiftUI

struct AILedgerAssistantView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.appCurrencyCode) private var currencyCode
    @State private var prompt = ""
    @State private var drafts: [AILedgerDraft] = []
    @State private var error: String?
    @State private var isLoading = false
    @State private var showPreview = false
    let dependencies: AppDependencies
    let theme: AppTheme
    let typography: AppTypography.Style
    private let client: AIRequesting

    init(dependencies: AppDependencies, theme: AppTheme, typography: AppTypography.Style, client: AIRequesting = AIClient()) {
        self.dependencies = dependencies
        self.theme = theme
        self.typography = typography
        self.client = client
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(AppLocalization.text("ai.title", language: language)).font(AppTypography.display(typography))
            Text(AppLocalization.text("ai.subtitle", language: language)).foregroundStyle(theme.secondaryText.color)
            HStack {
                TextField(AppLocalization.text("ai.prompt", language: language), text: $prompt)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("ai-prompt")
                Button(AppLocalization.text("ai.generate", language: language)) { generate() }
                    .buttonStyle(.borderedProminent)
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                    .accessibilityIdentifier("ai-generate")
            }
            if !dependencies.preferences.aiConfiguration.allowsLedgerData {
                Label(AppLocalization.text("ai.permissionRequired", language: language), systemImage: "lock")
                    .foregroundStyle(theme.secondaryText.color)
                    .accessibilityIdentifier("ai-permission-scope")
            }
            if let error { Text(error).foregroundStyle(.red).accessibilityIdentifier("ai-error") }
            Spacer()
        }
        .padding(28)
        .foregroundStyle(theme.primaryText.color)
        .background(theme.canvas.color)
        .sheet(isPresented: $showPreview) {
            AILedgerPreviewView(drafts: drafts, repository: dependencies.repository, theme: theme, typography: typography) {
                showPreview = false
                prompt = ""
            }
        }
    }

    private func generate() {
        isLoading = true; error = nil
        Task { @MainActor in
            do {
                let result = try await client.parseLedger(text: prompt, configuration: dependencies.preferences.aiConfiguration)
                drafts = result.entries; showPreview = true; isLoading = false
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? String(describing: error); isLoading = false
            }
        }
    }
}

private struct AILedgerPreviewView: View {
    @Environment(\.appLanguage) private var language
    let drafts: [AILedgerDraft]
    let repository: LedgerRepository
    let theme: AppTheme
    let typography: AppTypography.Style
    let onSaved: () -> Void
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppLocalization.text("ai.preview.title", language: language)).font(AppTypography.display(typography))
            Text(AppLocalization.text("ai.preview.range", language: language)).foregroundStyle(theme.secondaryText.color)
            ForEach(Array(drafts.enumerated()), id: \.offset) { _, draft in
                HStack {
                    Text(draft.kind == .income ? AppLocalization.text("entry.income", language: language) : AppLocalization.text("entry.expense", language: language))
                    Text("\(draft.amount.description) \(draft.currency)")
                    Spacer()
                    Text(draft.note)
                }
                .padding(10)
                .background(theme.surface.color, in: RoundedRectangle(cornerRadius: 8))
            }
            if let error { Text(error).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button(AppLocalization.text("button.cancel", language: language)) { onSaved() }
                Button(AppLocalization.text("ai.preview.confirm", language: language)) { save() }.buttonStyle(.borderedProminent).accessibilityIdentifier("ai-confirm")
            }
        }
        .padding(24)
        .frame(minWidth: 520)
        .background(theme.canvas.color)
        .accessibilityIdentifier("ai-preview")
    }

    private func save() {
        Task { @MainActor in
            do {
                for draft in drafts {
                    let categories = try await repository.categories(kind: draft.kind)
                    let categoryID = categories.first { ($0.systemKey ?? "").lowercased() == draft.category.lowercased() }?.id
                    let ledgerDraft = LedgerDraft(kind: draft.kind, amountText: draft.amount.description, categoryID: categoryID, note: draft.note, occurredAt: draft.date)
                    _ = try await repository.insert(ledgerDraft)
                }
                onSaved()
            } catch { self.error = String(describing: error) }
        }
    }
}
