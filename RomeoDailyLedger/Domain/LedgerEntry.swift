import Foundation
import SwiftData

@Model
final class LedgerEntry {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var amount: Decimal
    var categoryID: UUID
    var note: String
    var occurredAt: Date
    var createdAt: Date
    var updatedAt: Date

    var kind: EntryKind {
        get { EntryKind(rawValue: kindRaw)! }
        set { kindRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        kind: EntryKind,
        amount: Decimal,
        categoryID: UUID,
        note: String,
        occurredAt: Date
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.amount = amount
        self.categoryID = categoryID
        self.note = note
        self.occurredAt = occurredAt
        self.createdAt = .now
        self.updatedAt = .now
    }
}
