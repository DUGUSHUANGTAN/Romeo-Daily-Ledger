import Foundation
import Testing
@testable import RomeoDailyLedger

@Test func draftRejectsZeroAmount() {
    let draft = LedgerDraft(
        kind: .expense,
        amountText: "0",
        categoryID: nil,
        note: "",
        occurredAt: .now
    )

    #expect(throws: LedgerDraft.ValidationError.invalidAmount) {
        try draft.validatedAmount()
    }
}

@Test func entryKeepsDecimalPrecision() {
    let amount = Decimal(string: "0.10")!
    let entry = LedgerEntry(
        kind: .expense,
        amount: amount,
        categoryID: UUID(),
        note: "",
        occurredAt: .now
    )

    #expect(entry.amount == amount)
}
