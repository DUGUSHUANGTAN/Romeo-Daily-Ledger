import Foundation
import SwiftData

@MainActor
final class SwiftDataLedgerRepository: LedgerRepository {
    enum RepositoryError: Error {
        case entryNotFound
        case fallbackCategoryNotFound
    }

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func seedDefaultsIfNeeded() async throws {
        try DefaultCategorySeeder(context: context).seedIfNeeded()
    }

    func insert(_ draft: LedgerDraft) async throws -> LedgerEntry {
        let entry = LedgerEntry(
            kind: draft.kind,
            amount: try draft.validatedAmount(),
            categoryID: try resolvedCategoryID(for: draft),
            note: draft.note,
            occurredAt: draft.occurredAt
        )
        context.insert(entry)
        try context.save()
        return entry
    }

    func update(id: UUID, draft: LedgerDraft) async throws {
        guard let entry = try fetchEntry(id: id) else {
            throw RepositoryError.entryNotFound
        }

        entry.kind = draft.kind
        entry.amount = try draft.validatedAmount()
        entry.categoryID = try resolvedCategoryID(for: draft)
        entry.note = draft.note
        entry.occurredAt = draft.occurredAt
        entry.updatedAt = .now
        try context.save()
    }

    func delete(ids: Set<UUID>) async throws {
        let entries = try context.fetch(FetchDescriptor<LedgerEntry>())
        for entry in entries where ids.contains(entry.id) {
            context.delete(entry)
        }
        try context.save()
    }

    func entries(in interval: DateInterval) async throws -> [LedgerEntry] {
        let start = interval.start
        let end = interval.end
        var descriptor = FetchDescriptor<LedgerEntry>(
            predicate: #Predicate { entry in
                entry.occurredAt >= start && entry.occurredAt < end
            }
        )
        descriptor.sortBy = [SortDescriptor(\.occurredAt)]
        return try context.fetch(descriptor)
    }

    func categories(kind: EntryKind) async throws -> [Category] {
        let kindRaw = kind.rawValue
        var descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { category in category.kindRaw == kindRaw }
        )
        descriptor.sortBy = [SortDescriptor(\.sortOrder)]
        return try context.fetch(descriptor)
    }

    func category(id: UUID) async throws -> Category? {
        var descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { category in category.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func resolvedCategoryID(for draft: LedgerDraft) throws -> UUID {
        if let categoryID = draft.categoryID {
            return categoryID
        }

        let kindRaw = draft.kind.rawValue
        var descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { category in
                category.kindRaw == kindRaw && category.systemKey == "other"
            }
        )
        descriptor.fetchLimit = 1
        guard let fallback = try context.fetch(descriptor).first else {
            throw RepositoryError.fallbackCategoryNotFound
        }
        return fallback.id
    }

    private func fetchEntry(id: UUID) throws -> LedgerEntry? {
        var descriptor = FetchDescriptor<LedgerEntry>(
            predicate: #Predicate { entry in entry.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
