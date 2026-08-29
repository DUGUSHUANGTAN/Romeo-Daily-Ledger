import Foundation

@MainActor
protocol LedgerRepository {
    func seedDefaultsIfNeeded() async throws
    func insert(_ draft: LedgerDraft) async throws -> LedgerEntry
    func update(id: UUID, draft: LedgerDraft) async throws
    func delete(ids: Set<UUID>) async throws
    func entries(in interval: DateInterval) async throws -> [LedgerEntry]
    func categories(kind: EntryKind) async throws -> [Category]
    func category(id: UUID) async throws -> Category?
}
