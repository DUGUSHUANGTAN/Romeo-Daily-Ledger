import Foundation
import Observation

@Observable
@MainActor
final class EntryEditorViewModel {
    var draft: LedgerDraft
    var errorMessage: String?

    private let entryID: UUID
    private let repository: LedgerRepository
    private let dateNormalizer: AppDateNormalizer

    init(
        entry: LedgerEntry,
        repository: LedgerRepository,
        clock: any AppClock = SystemAppClock(),
        timeZoneProvider: any AppTimeZoneProviding = SystemAppTimeZoneProvider()
    ) {
        self.entryID = entry.id
        self.repository = repository
        self.dateNormalizer = AppDateNormalizer(clock: clock, timeZoneProvider: timeZoneProvider)
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
            var normalizedDraft = draft
            normalizedDraft.occurredAt = dateNormalizer.normalize(draft.occurredAt)
            try await repository.update(id: entryID, draft: normalizedDraft)
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
            throw error
        }
    }
}
