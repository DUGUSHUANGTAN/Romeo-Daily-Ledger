import SwiftUI

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
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
            Text("编辑账目").font(AppTypography.display(typography))
            HStack {
                kindButton(.expense, title: "支出")
                kindButton(.income, title: "收入")
            }
            labeled("金额") {
                TextField("金额", text: $model.draft.amountText)
                    .accessibilityIdentifier("editor-amount")
            }
            labeled("分类") {
                Picker("分类", selection: $model.draft.categoryID) {
                    Text("未选择（归入其他）").tag(UUID?.none)
                    ForEach(categories) { category in
                        Text(LedgerFormatting.categoryName(category)).tag(Optional(category.id))
                    }
                }
                .accessibilityIdentifier("editor-category")
            }
            labeled("日期") {
                DatePicker("日期", selection: $model.draft.occurredAt)
                    .labelsHidden()
                    .accessibilityIdentifier("editor-date")
            }
            labeled("备注") {
                TextField("备注", text: $model.draft.note)
                    .accessibilityIdentifier("editor-note")
            }
            if let error = model.errorMessage {
                Text(error).foregroundStyle(.red).accessibilityIdentifier("editor-error")
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }.accessibilityIdentifier("editor-cancel")
                Button("保存账目") {
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
        .accessibilityIdentifier("editor-kind-\(kind.rawValue)")
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(AppTypography.caption(typography))
            content()
        }
    }

    private func loadCategories() async {
        categories = (try? await repository.categories(kind: model.draft.kind).filter { !$0.isHidden }) ?? []
    }
}
