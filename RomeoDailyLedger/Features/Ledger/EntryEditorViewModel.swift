import Foundation
import Observation

@Observable
@MainActor
final class EntryEditorViewModel {
    var draft: LedgerDraft
    var errorMessage: String?

    private let entryID: UUID
    private let repository: LedgerRepository

    init(entry: LedgerEntry, repository: LedgerRepository) {
        self.entryID = entry.id
        self.repository = repository
        self.draft = LedgerDraft(
            kind: entry.kind,
            amountText: NSDecimalNumber(decimal: entry.amount).stringValue,
            categoryID: entry.categoryID,
            note: entry.note,
            occurredAt: entry.occurredAt
        )
    }

    func save() async throws {
        do {
            try await repository.update(id: entryID, draft: draft)
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
            throw error
        }
    }
}
