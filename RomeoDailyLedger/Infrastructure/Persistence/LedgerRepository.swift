import Foundation

@MainActor
protocol LedgerRepository {
    func seedDefaultsIfNeeded() async throws
    func insert(_ draft: LedgerDraft) async throws -> LedgerEntry
    func insert(_ drafts: [LedgerDraft]) async throws -> [LedgerEntry]
    func update(id: UUID, draft: LedgerDraft) async throws
    func delete(ids: Set<UUID>) async throws
    func entries(in interval: DateInterval) async throws -> [LedgerEntry]
    func categories(kind: EntryKind) async throws -> [Category]
    func category(id: UUID) async throws -> Category?
    func ensureCustomCategory(named name: String, kind: EntryKind) async throws -> Category
}

enum LedgerRepositoryCapabilityError: Error {
    case customCategoryCreationUnsupported
}

extension LedgerRepository {
    func insert(_ drafts: [LedgerDraft]) async throws -> [LedgerEntry] {
        var entries: [LedgerEntry] = []
        entries.reserveCapacity(drafts.count)
        for draft in drafts { entries.append(try await insert(draft)) }
        return entries
    }

    func ensureCustomCategory(named name: String, kind: EntryKind) async throws -> Category {
        if let existing = try await categories(kind: kind).first(where: {
            $0.customName?.caseInsensitiveCompare(name) == .orderedSame
        }) {
            return existing
        }
        throw LedgerRepositoryCapabilityError.customCategoryCreationUnsupported
    }
}
