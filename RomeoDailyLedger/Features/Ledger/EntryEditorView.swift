import SwiftUI

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @State private var model: EntryEditorViewModel
    @State private var categories: [Category] = []
    let repository: LedgerRepository
    let theme: AppTheme
    let typography: AppTypography.Style
    let onSaved: () async -> Void

    init(entry: LedgerEntry, repository: LedgerRepository, theme: AppTheme, typography: AppTypography.Style, onSaved: @escaping () async -> Void) {
        _model = State(initialValue: EntryEditorViewModel(entry: entry, repository: repository))
        self.repository = repository
        self.theme = theme
        self.typography = typography
        self.onSaved = onSaved
    }

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 18) {
            Text(AppLocalization.text("editor.title", language: language)).font(AppTypography.display(typography))
            HStack {
                kindButton(.expense, title: AppLocalization.text("entry.expense", language: language))
                kindButton(.income, title: AppLocalization.text("entry.income", language: language))
            }
            labeled(AppLocalization.text("field.amount", language: language)) {
                TextField(AppLocalization.text("field.amount", language: language), text: $model.draft.amountText)
                    .accessibilityIdentifier("editor-amount")
            }
            labeled(AppLocalization.text("field.category", language: language)) {
                Picker(AppLocalization.text("field.category", language: language), selection: $model.draft.categoryID) {
                    ForEach(categories) { category in
                        Text(LedgerFormatting.categoryName(category, language: language)).tag(Optional(category.id))
                    }
                }
                .accessibilityIdentifier("editor-category")
            }
            labeled(AppLocalization.text("field.date", language: language)) {
                DatePicker(AppLocalization.text("field.date", language: language), selection: $model.draft.occurredAt, displayedComponents: .date)
                    .labelsHidden()
                    .accessibilityIdentifier("editor-date")
            }
            labeled(AppLocalization.text("field.note", language: language)) {
                TextField(AppLocalization.text("field.note", language: language), text: $model.draft.note)
                    .accessibilityIdentifier("editor-note")
            }
            if model.errorMessage != nil {
                Text(AppLocalization.text("error.updateEntry", language: language))
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("editor-error")
            }
            HStack {
                Spacer()
                Button(AppLocalization.text("button.cancel", language: language)) { dismiss() }.accessibilityIdentifier("editor-cancel")
                Button(AppLocalization.text("button.saveEntry", language: language)) {
                    Task {
                        do {
                            try await model.save()
                            await onSaved()
                            dismiss()
                        } catch { }
                    }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("editor-save")
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(28)
        .frame(width: 430)
        .background(theme.canvas.color)
        .task { await loadCategories() }
    }

    private func kindButton(_ kind: EntryKind, title: String) -> some View {
        Button(title) {
            model.draft.kind = kind
            model.draft.categoryID = nil
            Task { await loadCategories() }
        }
        .buttonStyle(.bordered)
        .tint(model.draft.kind == kind ? theme.primaryAccent.color : theme.secondaryText.color)
        .accessibilityAddTraits(model.draft.kind == kind ? .isSelected : [])
        .accessibilityValue(AppLocalization.text(model.draft.kind == kind ? "accessibility.selected" : "accessibility.notSelected", language: language))
        .accessibilityIdentifier("editor-kind-\(kind.rawValue)")
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(AppTypography.caption(typography))
            content()
        }
    }

    private func loadCategories() async {
        categories = CategorySelection.available(from: (try? await repository.categories(kind: model.draft.kind)) ?? [], selectedID: model.draft.categoryID)
        if model.draft.categoryID == nil {
            model.draft.categoryID = categories.first(where: { $0.systemKey == "other" })?.id
        }
    }
}
