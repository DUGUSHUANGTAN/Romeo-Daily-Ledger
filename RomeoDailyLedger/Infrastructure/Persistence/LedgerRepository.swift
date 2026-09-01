import Foundation

@MainActor
protocol LedgerRepository {
    func seedDefaultsIfNeeded() async throws
    func insert(_ draft: LedgerDraft) async throws -> LedgerEntry
    func insert(_ drafts: [LedgerDraft]) async throws -> [LedgerEntry]
    func update(id: UUID, draft: LedgerDraft) async throws
    func delete(ids: Set<UUID>) async throws
    func entries(in interval: DateInterval) async throws -> [LedgerEntry]
    func allEntries() async throws -> [LedgerEntry]
    func categories(kind: EntryKind) async throws -> [Category]
    func category(id: UUID) async throws -> Category?
    func updateCategory(id: UUID, displayName: String?, isHidden: Bool) async throws
    func deleteCategories(ids: Set<UUID>) async throws
    func deleteAllEntries() async throws
    func ensureCustomCategory(named name: String, kind: EntryKind) async throws -> Category
    func reorderCategories(kind: EntryKind, orderedIDs: [UUID]) async throws
}

enum LedgerRepositoryCapabilityError: Error {
    case customCategoryCreationUnsupported
}

enum LedgerRepositoryValidationError: Error, Equatable {
    case categoryNotFound
    case duplicateCategoryName
    case emptyCustomCategoryName
    case protectedCategory
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

    func allEntries() async throws -> [LedgerEntry] {
        try await entries(in: DateInterval(start: .distantPast, end: .distantFuture))
    }

    func updateCategory(id: UUID, displayName: String?, isHidden: Bool) async throws {
        throw LedgerRepositoryCapabilityError.customCategoryCreationUnsupported
    }

    func deleteCategories(ids: Set<UUID>) async throws {
        throw LedgerRepositoryCapabilityError.customCategoryCreationUnsupported
    }

    func deleteAllEntries() async throws {
        try await delete(ids: Set(try await allEntries().map(\.id)))
    }

    func reorderCategories(kind: EntryKind, orderedIDs: [UUID]) async throws {
        throw LedgerRepositoryCapabilityError.customCategoryCreationUnsupported
    }
}
