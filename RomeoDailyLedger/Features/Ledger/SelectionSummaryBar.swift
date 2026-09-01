import SwiftUI

struct SelectionSummaryBar: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.appCurrencyCode) private var currencyCode
    let summary: SelectionSummary
    let theme: AppTheme
    let typography: AppTypography.Style
    let onDelete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            Button(AppLocalization.text("button.deleteSelected", language: language), action: onDelete)
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .accessibilityIdentifier("delete-selected-entries")
            Button(AppLocalization.text("button.cancelSelection", language: language), action: onCancel)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("cancel-entry-selection")
            Text(AppLocalization.format("summary.income", language: language, LedgerFormatting.amount(summary.income, currencyCode: currencyCode)))
            Text(AppLocalization.format("summary.expense", language: language, LedgerFormatting.amount(summary.expense, currencyCode: currencyCode)))
            Text(AppLocalization.format("summary.net", language: language, LedgerFormatting.amount(summary.net, currencyCode: currencyCode)))
            Spacer()
        }
        .font(AppTypography.caption(typography))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.chrome.color, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AppLocalization.text("accessibility.selectionSummary", language: language))
        .accessibilityIdentifier("selection-summary-bar")
    }
}
