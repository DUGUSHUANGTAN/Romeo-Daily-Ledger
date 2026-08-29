import Foundation

struct SelectionSummary: Equatable {
    let income: Decimal
    let expense: Decimal

    var net: Decimal {
        income - expense
    }

    init(entries: [LedgerEntry]) {
        var income: Decimal = 0
        var expense: Decimal = 0

        for entry in entries {
            switch entry.kind {
            case .income:
                income += entry.amount
            case .expense:
                expense += entry.amount
            }
        }

        self.income = income
        self.expense = expense
    }
}
