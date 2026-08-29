import SwiftUI

struct QuickEntryView: View {
    @Bindable var model: LedgerViewModel
    let theme: AppTheme
    let typography: AppTypography.Style

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("快速记一笔").font(AppTypography.title(typography))
            HStack(spacing: 8) {
                kindButton(.expense, title: "支出")
                kindButton(.income, title: "收入")
                TextField("金额", text: $model.draft.amountText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 130)
                    .accessibilityLabel("金额")
                    .accessibilityIdentifier("quick-entry-amount")
                Picker("分类", selection: $model.draft.categoryID) {
                    Text("未选择（归入其他）").tag(UUID?.none)
                    ForEach(model.categories) { category in
                        Text(LedgerFormatting.categoryName(category)).tag(Optional(category.id))
                    }
                }
                .frame(width: 190)
                .accessibilityIdentifier("quick-entry-category")
                TextField("备注", text: $model.draft.note)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("备注")
                    .accessibilityIdentifier("quick-entry-note")
                Button("保存") { Task { try? await model.saveQuickEntry() } }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("保存账目")
                    .accessibilityIdentifier("quick-entry-save")
            }
            if let error = model.errorMessage {
                Text(error)
                    .font(AppTypography.caption(typography))
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("quick-entry-error")
            }
        }
        .padding(18)
        .background(theme.surface.color, in: RoundedRectangle(cornerRadius: 14))
    }

    private func kindButton(_ kind: EntryKind, title: String) -> some View {
        Button(title) {
            model.draft.kind = kind
            model.draft.categoryID = nil
            Task { try? await model.loadCategories() }
        }
        .buttonStyle(.bordered)
        .tint(model.draft.kind == kind ? theme.primaryAccent.color : theme.secondaryText.color)
        .accessibilityAddTraits(model.draft.kind == kind ? .isSelected : [])
        .accessibilityValue(model.draft.kind == kind ? "已选择" : "未选择")
        .accessibilityIdentifier("quick-entry-kind-\(kind.rawValue)")
    }
}
