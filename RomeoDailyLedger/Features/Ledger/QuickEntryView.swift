import SwiftUI

struct QuickEntryView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var model: LedgerViewModel
    let theme: AppTheme
    let typography: AppTypography.Style

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppLocalization.text("ledger.quickEntry", language: language)).font(AppTypography.title(typography))
            HStack(spacing: 8) {
                kindButton(.expense, title: AppLocalization.text("entry.expense", language: language))
                kindButton(.income, title: AppLocalization.text("entry.income", language: language))
                TextField(AppLocalization.text("field.amount", language: language), text: $model.draft.amountText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 130)
                    .accessibilityLabel(AppLocalization.text("field.amount", language: language))
                    .accessibilityIdentifier("quick-entry-amount")
                Picker(AppLocalization.text("field.category", language: language), selection: $model.draft.categoryID) {
                    Text(AppLocalization.text("category.unselectedFallback", language: language)).tag(UUID?.none)
                    ForEach(model.categories) { category in
                        Text(LedgerFormatting.categoryName(category, language: language)).tag(Optional(category.id))
                    }
                }
                .frame(width: 190)
                .accessibilityIdentifier("quick-entry-category")
                TextField(AppLocalization.text("field.note", language: language), text: $model.draft.note)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(AppLocalization.text("field.note", language: language))
                    .accessibilityIdentifier("quick-entry-note")
                Button(AppLocalization.text("button.save", language: language)) { Task { try? await model.saveQuickEntry() } }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel(AppLocalization.text("button.saveEntry", language: language))
                    .accessibilityIdentifier("quick-entry-save")
            }
            if model.errorMessage != nil {
                Text(AppLocalization.text("error.saveEntry", language: language))
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
        .accessibilityValue(AppLocalization.text(model.draft.kind == kind ? "accessibility.selected" : "accessibility.notSelected", language: language))
        .accessibilityIdentifier("quick-entry-kind-\(kind.rawValue)")
    }
}
