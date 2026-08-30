import SwiftUI

struct SelectionSummaryBar: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.appCurrencyCode) private var currencyCode
    let summary: SelectionSummary
    let theme: AppTheme
    let typography: AppTypography.Style
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            Text(AppLocalization.format("summary.income", language: language, LedgerFormatting.amount(summary.income, currencyCode: currencyCode)))
            Text(AppLocalization.format("summary.expense", language: language, LedgerFormatting.amount(summary.expense, currencyCode: currencyCode)))
            Text(AppLocalization.format("summary.net", language: language, LedgerFormatting.amount(summary.net, currencyCode: currencyCode)))
            Spacer()
            Button(AppLocalization.text("button.deleteSelected", language: language), action: onDelete)
                .accessibilityIdentifier("delete-selected-entries")
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
