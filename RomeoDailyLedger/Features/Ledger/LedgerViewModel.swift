import Foundation
import Observation

@Observable
@MainActor
final class LedgerViewModel {
    var draft: LedgerDraft
    var errorMessage: String?

    private let repository: LedgerRepository

    init(repository: LedgerRepository) {
        self.repository = repository
        self.draft = LedgerDraft(
            kind: .expense,
            amountText: "",
            categoryID: nil,
            note: "",
            occurredAt: .now
        )
    }

    func save() async throws {
        do {
            _ = try await repository.insert(draft)
            draft.amountText = ""
            draft.note = ""
            draft.categoryID = nil
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
            throw error
        }
    }
}
