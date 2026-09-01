import Foundation
import Testing
@testable import RomeoDailyLedger

@Suite("Selection summary")
struct SelectionSummaryTests {
    @Test func emptySelectionReportsZeroTotals() {
        let result = SelectionSummary(entries: [])
        #expect(result.income == 0)
        #expect(result.expense == 0)
        #expect(result.net == 0)
    }

    @Test func incomeSelectionReportsIncomeAndNet() {
        let result = SelectionSummary(entries: [fixture(.income, "25"), fixture(.income, "75")])
        #expect(result.income == 100)
        #expect(result.expense == 0)
        #expect(result.net == 100)
    }

    @Test func expenseSelectionReportsExpenseAndNegativeNet() {
        let result = SelectionSummary(entries: [fixture(.expense, "30"), fixture(.expense, "20")])
        #expect(result.income == 0)
        #expect(result.expense == 50)
        #expect(result.net == -50)
    }

    @Test func mixedSelectionReportsIncomeExpenseAndNet() {
        let result = SelectionSummary(entries: [fixture(.expense, "30"), fixture(.income, "100"), fixture(.expense, "20")])
        #expect(result.income == 100)
        #expect(result.expense == 50)
        #expect(result.net == 50)
    }

    @Test func totalsPreserveDecimalPrecision() {
        let result = SelectionSummary(entries: [fixture(.income, "0.10"), fixture(.income, "0.20"), fixture(.expense, "0.03")])
        #expect(result.income == Decimal(string: "0.30")!)
        #expect(result.expense == Decimal(string: "0.03")!)
        #expect(result.net == Decimal(string: "0.27")!)
    }

    private func fixture(_ kind: EntryKind, _ amount: String) -> LedgerEntry {
        LedgerEntry(
            kind: kind,
            amount: Decimal(string: amount)!,
            categoryID: UUID(),
            note: "",
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
