import Foundation

struct LedgerDraft {
    enum ValidationError: Error {
        case invalidAmount
    }

    var kind: EntryKind
    var amountText: String
    var categoryID: UUID?
    var note: String
    var occurredAt: Date

    func validatedAmount() throws -> Decimal {
        guard let value = Decimal(string: amountText), value > 0 else {
            throw ValidationError.invalidAmount
        }

        return value
    }
}
