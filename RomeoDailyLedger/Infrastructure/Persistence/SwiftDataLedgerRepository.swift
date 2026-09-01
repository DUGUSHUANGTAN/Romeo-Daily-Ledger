import Foundation
import SwiftData

@MainActor
final class SwiftDataLedgerRepository: LedgerRepository {
    enum RepositoryError: Error {
        case entryNotFound
        case fallbackCategoryNotFound
    }

    private let context: ModelContext
    private let dateNormalizer: AppDateNormalizer

    init(
        context: ModelContext,
        clock: any AppClock = SystemAppClock(),
        timeZoneProvider: any AppTimeZoneProviding = SystemAppTimeZoneProvider()
    ) {
        self.context = context
        self.dateNormalizer = AppDateNormalizer(clock: clock, timeZoneProvider: timeZoneProvider)
    }

    func seedDefaultsIfNeeded() async throws {
        try DefaultCategorySeeder(context: context).seedIfNeeded()
        var changed = false
        for entry in try context.fetch(FetchDescriptor<LedgerEntry>()) {
            let normalized = dateNormalizer.normalize(entry.occurredAt)
            if entry.occurredAt != normalized {
                entry.occurredAt = normalized
                changed = true
            }
        }
        if changed { try context.save() }
    }

    func insert(_ draft: LedgerDraft) async throws -> LedgerEntry {
        try await insert([draft])[0]
    }

    func insert(_ drafts: [LedgerDraft]) async throws -> [LedgerEntry] {
        let entries = try drafts.map { draft in
            LedgerEntry(
                id: draft.id ?? UUID(),
                kind: draft.kind,
                amount: try draft.validatedAmount(),
                categoryID: try resolvedCategoryID(for: draft),
                note: draft.note,
                occurredAt: dateNormalizer.normalize(draft.occurredAt)
            )
        }
        for entry in entries { context.insert(entry) }
        do {
            try context.save()
            return entries
        } catch {
            context.rollback()
            throw error
        }
    }

    func update(id: UUID, draft: LedgerDraft) async throws {
        guard let entry = try fetchEntry(id: id) else {
            throw RepositoryError.entryNotFound
        }

        entry.kind = draft.kind
        entry.amount = try draft.validatedAmount()
        entry.categoryID = try resolvedCategoryID(for: draft)
        entry.note = draft.note
        entry.occurredAt = dateNormalizer.normalize(draft.occurredAt)
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

    func allEntries() async throws -> [LedgerEntry] {
        var descriptor = FetchDescriptor<LedgerEntry>()
        descriptor.sortBy = [SortDescriptor(\.occurredAt), SortDescriptor(\.createdAt)]
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

    func updateCategory(id: UUID, displayName: String?, isHidden: Bool) async throws {
        guard let category = try await category(id: id) else {
            throw LedgerRepositoryValidationError.categoryNotFound
        }
        guard category.systemKey != "other" else {
            throw LedgerRepositoryValidationError.protectedCategory
        }
        let normalized = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if category.systemKey == nil && normalized.isEmpty {
            throw LedgerRepositoryValidationError.emptyCustomCategoryName
        }
        if !normalized.isEmpty {
            let siblings = try await categories(kind: category.kind)
            guard !siblings.contains(where: {
                guard $0.id != category.id else { return false }
                let siblingName = $0.customName ?? $0.systemKey ?? ""
                return siblingName.caseInsensitiveCompare(normalized) == .orderedSame
            }) else {
                throw LedgerRepositoryValidationError.duplicateCategoryName
            }
        }
        category.customName = normalized.isEmpty ? nil : normalized
        category.isHidden = isHidden
        try context.save()
    }

    func deleteCategories(ids: Set<UUID>) async throws {
        guard !ids.isEmpty else { return }
        let allCategories = try context.fetch(FetchDescriptor<Category>())
        let targets = allCategories.filter { ids.contains($0.id) }
        guard targets.count == ids.count else {
            throw LedgerRepositoryValidationError.categoryNotFound
        }
        guard !targets.contains(where: { $0.systemKey == "other" }) else {
            throw LedgerRepositoryValidationError.protectedCategory
        }

        let fallbacks = Dictionary(uniqueKeysWithValues: allCategories.compactMap { category in
            category.systemKey == "other" ? (category.kind, category.id) : nil
        })
        let targetByID = Dictionary(uniqueKeysWithValues: targets.map { ($0.id, $0) })
        let entries = try context.fetch(FetchDescriptor<LedgerEntry>())
        for entry in entries {
            guard let category = targetByID[entry.categoryID], let fallbackID = fallbacks[category.kind] else { continue }
            entry.categoryID = fallbackID
            entry.updatedAt = .now
        }
        for category in targets { context.delete(category) }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func deleteAllEntries() async throws {
        for entry in try context.fetch(FetchDescriptor<LedgerEntry>()) {
            context.delete(entry)
        }
        try context.save()
    }

    func ensureCustomCategory(named name: String, kind: EntryKind) async throws -> Category {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw LedgerRepositoryValidationError.emptyCustomCategoryName
        }
        let kindRaw = kind.rawValue
        let categories = try context.fetch(
            FetchDescriptor<Category>(predicate: #Predicate { category in category.kindRaw == kindRaw })
        )
        if let existing = categories.first(where: {
            let existingName = $0.customName ?? $0.systemKey ?? ""
            return existingName.caseInsensitiveCompare(normalized) == .orderedSame
        }) {
            return existing
        }
        let category = Category(
            kind: kind,
            customName: normalized,
            iconName: "ellipsis",
            colorToken: "other",
            sortOrder: (categories.filter { $0.systemKey != "other" }.map(\.sortOrder).max() ?? -1) + 1
        )
        context.insert(category)
        try context.save()
        return category
    }

    func reorderCategories(kind: EntryKind, orderedIDs: [UUID]) async throws {
        let categories = try await categories(kind: kind)
        let movable = categories.filter { $0.systemKey != "other" }
        guard Set(orderedIDs) == Set(movable.map(\.id)) else { throw LedgerRepositoryValidationError.categoryNotFound }
        for (index, id) in orderedIDs.enumerated() {
            movable.first(where: { $0.id == id })?.sortOrder = index
        }
        categories.first(where: { $0.systemKey == "other" })?.sortOrder = Int.max
        try context.save()
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
