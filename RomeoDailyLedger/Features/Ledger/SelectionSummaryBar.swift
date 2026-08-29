import SwiftUI

struct SelectionSummaryBar: View {
    let summary: SelectionSummary
    let theme: AppTheme
    let typography: AppTypography.Style
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            Text("收入 \(LedgerFormatting.amount(summary.income))")
            Text("支出 \(LedgerFormatting.amount(summary.expense))")
            Text("净额 \(LedgerFormatting.amount(summary.net))")
            Spacer()
            Button("删除所选", action: onDelete)
                .accessibilityIdentifier("delete-selected-entries")
        }
        .font(AppTypography.caption(typography))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.chrome.color, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("多选汇总")
        .accessibilityIdentifier("selection-summary-bar")
    }
}
