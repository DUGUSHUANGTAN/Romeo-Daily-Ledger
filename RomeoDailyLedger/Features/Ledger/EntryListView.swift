import SwiftUI

struct EntryListView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.appCurrencyCode) private var currencyCode
    @Bindable var model: LedgerViewModel
    let theme: AppTheme
    let typography: AppTypography.Style

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if model.entries.isEmpty {
                    VStack(spacing: 6) {
                        Text(AppLocalization.text("ledger.empty.title", language: language)).font(AppTypography.title(typography))
                        Text(AppLocalization.text("ledger.empty.message", language: language))
                            .font(AppTypography.body(typography))
                            .foregroundStyle(theme.secondaryText.color)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                        .accessibilityIdentifier("entry-list-empty")
                }
                ForEach(model.entries) { entry in
                    HStack(spacing: 14) {
                        Text(AppLocalization.text(entry.kind == .income ? "entry.income.short" : "entry.expense.short", language: language))
                                .font(AppTypography.caption(typography))
                                .frame(width: 28, height: 28)
                                .background(theme.secondaryAccent.color.opacity(0.22), in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.note.isEmpty ? AppLocalization.text("entry.noNote", language: language) : entry.note)
                                    .font(AppTypography.body(typography))
                                Text(entry.occurredAt, format: .dateTime.year().month().day())
                                    .font(AppTypography.caption(typography))
                                    .foregroundStyle(theme.secondaryText.color)
                            }
                            Spacer()
                            Text(LedgerFormatting.amount(entry.amount, currencyCode: currencyCode))
                                .font(AppTypography.title(typography))
                    }
                    .padding(12)
                    .foregroundStyle(theme.primaryText.color)
                    .background(model.selectedEntryIDs.contains(entry.id) ? theme.primaryAccent.color.opacity(0.16) : theme.surface.color, in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
                    .gesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .exclusively(before: TapGesture())
                            .onEnded { value in
                                switch value {
                                case .first: model.beginSelection(with: entry)
                                case .second: model.activate(entry)
                                }
                            }
                    )
                    .accessibilityLabel("\(AppLocalization.text(entry.kind == .income ? "entry.income" : "entry.expense", language: language)) \(LedgerFormatting.amount(entry.amount, currencyCode: currencyCode)) \(entry.note)")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAddTraits(model.selectedEntryIDs.contains(entry.id) ? .isSelected : [])
                    .accessibilityValue(AppLocalization.text(model.selectedEntryIDs.contains(entry.id) ? "accessibility.selected" : "accessibility.notSelected", language: language))
                    .accessibilityIdentifier("entry-row-\(entry.id.uuidString.lowercased())")
                    .contextMenu {
                        Button(AppLocalization.text("button.editEntry", language: language)) { model.editingEntry = entry }
                    }
                }
            }
        }
        .accessibilityLabel(AppLocalization.text("accessibility.entryList", language: language))
        .accessibilityIdentifier("entry-list")
    }
}
