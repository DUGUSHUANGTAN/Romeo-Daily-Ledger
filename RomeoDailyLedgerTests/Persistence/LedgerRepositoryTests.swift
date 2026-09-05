import Foundation
import SwiftData
import Testing
@testable import RomeoDailyLedger

@MainActor
@Suite("LedgerRepositoryTests")
struct LedgerRepositoryTests {

@Test func startupMigratesExistingEntryDatesIdempotently() async throws {
    let container = try ModelContainerFactory.inMemory()
    let context = ModelContext(container)
    let zone = TimeZone(identifier: "Asia/Shanghai")!
    let repository = SwiftDataLedgerRepository(
        context: context,
        timeZoneProvider: FixedAppTimeZoneProvider(timeZone: zone)
    )
    let original = ISO8601DateFormatter().date(from: "2024-02-29T18:45:00Z")!
    let entry = LedgerEntry(kind: .expense, amount: 1, categoryID: UUID(), note: "legacy", occurredAt: original)
    context.insert(entry)
    try context.save()

    try await repository.seedDefaultsIfNeeded()
    let once = entry.occurredAt
    try await repository.seedDefaultsIfNeeded()

    #expect(once == ISO8601DateFormatter().date(from: "2024-02-29T16:00:00Z"))
    #expect(entry.occurredAt == once)
}

@Test func repeatedSeedDoesNotRescanEntries() async throws {
    let container = try ModelContainerFactory.inMemory()
    let context = ModelContext(container)
    let zone = TimeZone(identifier: "Asia/Shanghai")!
    let repository = SwiftDataLedgerRepository(context: context, timeZoneProvider: FixedAppTimeZoneProvider(timeZone: zone))
    try await repository.seedDefaultsIfNeeded()
    let category = try #require(try await repository.categories(kind: .expense).first)
    let original = ISO8601DateFormatter().date(from: "2024-02-29T18:45:00Z")!
    let entry = LedgerEntry(kind: .expense, amount: 1, categoryID: category.id, note: "new", occurredAt: original)
    context.insert(entry)
    try context.save()

    try await repository.seedDefaultsIfNeeded()

    #expect(entry.occurredAt == original)
}

@MainActor
@Test func seederCreatesRequiredExpenseCategories() async throws {
    let repository = try TestRepository.make()

    try await repository.seedDefaultsIfNeeded()

    let keys = try await repository.categories(kind: .expense).compactMap(\.systemKey)
    #expect(keys == ["other"])
}

@MainActor
@Test func seederCreatesRequiredIncomeCategories() async throws {
    let repository = try TestRepository.make()

    try await repository.seedDefaultsIfNeeded()

    let keys = try await repository.categories(kind: .income).compactMap(\.systemKey)
    #expect(keys == ["other"])
}

@MainActor
@Test func seedingDefaultsIsIdempotent() async throws {
    let repository = try TestRepository.make()

    try await repository.seedDefaultsIfNeeded()
    try await repository.seedDefaultsIfNeeded()

    #expect(try await repository.categories(kind: .expense).count == 1)
    #expect(try await repository.categories(kind: .income).count == 1)
}

@MainActor
@Test func expenseWithoutCategoryFallsBackToExpenseOther() async throws {
    try await expectFallbackToOther(kind: .expense)
}

@MainActor
@Test func incomeWithoutCategoryFallsBackToIncomeOther() async throws {
    try await expectFallbackToOther(kind: .income)
}

private func expectFallbackToOther(kind: EntryKind) async throws {
    let repository = try TestRepository.make()
    try await repository.seedDefaultsIfNeeded()

    let saved = try await repository.insert(
        LedgerDraft(
            kind: kind,
            amountText: "12.50",
            categoryID: nil,
            note: "Uncategorized",
            occurredAt: .now
        )
    )

    let category = try await repository.category(id: saved.categoryID)
    #expect(category?.kind == kind)
    #expect(category?.systemKey == "other")
}

@MainActor
@Test func entriesQueryUsesHalfOpenDateRange() async throws {
    let repository = try TestRepository.make()
    try await repository.seedDefaultsIfNeeded()
    let normalizer = AppDateNormalizer()
    let start = normalizer.normalize(Date(timeIntervalSince1970: 1_700_000_000))
    let end = start.addingTimeInterval(86_400)

    _ = try await repository.insert(draft(at: start, note: "start"))
    _ = try await repository.insert(draft(at: end.addingTimeInterval(-1), note: "inside"))
    _ = try await repository.insert(draft(at: end, note: "end"))

    let entries = try await repository.entries(in: DateInterval(start: start, end: end))
    #expect(Set(entries.map(\.note)) == ["start", "inside"])
}

@MainActor
@Test func updateEditsAllDraftFieldsAndRefreshesUpdatedAt() async throws {
    let repository = try TestRepository.make()
    try await repository.seedDefaultsIfNeeded()
    let saved = try await repository.insert(draft(at: .now, note: "before"))
    let originalUpdatedAt = saved.updatedAt
    let incomeCategory = try await repository.ensureCustomCategory(named: "工资", kind: .income)
    let changedDate = Date(timeIntervalSince1970: 1_800_000_000)

    try await repository.update(
        id: saved.id,
        draft: LedgerDraft(
            kind: .income,
            amountText: "99.25",
            categoryID: incomeCategory.id,
            note: "after",
            occurredAt: changedDate
        )
    )

    let normalizedDate = AppDateNormalizer().normalize(changedDate)
    let entries = try await repository.entries(
        in: DateInterval(start: normalizedDate, end: normalizedDate.addingTimeInterval(86_400))
    )
    let updated = try #require(entries.first)
    #expect(updated.kind == .income)
    #expect(updated.amount == Decimal(string: "99.25"))
    #expect(updated.categoryID == incomeCategory.id)
    #expect(updated.note == "after")
    #expect(updated.occurredAt == normalizedDate)
    #expect(updated.updatedAt >= originalUpdatedAt)
}

@MainActor
@Test func deleteRemovesEveryRequestedEntry() async throws {
    let repository = try TestRepository.make()
    try await repository.seedDefaultsIfNeeded()
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let first = try await repository.insert(draft(at: start, note: "first"))
    let second = try await repository.insert(draft(at: start.addingTimeInterval(1), note: "second"))

    try await repository.delete(ids: [first.id, second.id])

    let remaining = try await repository.entries(
        in: DateInterval(start: start.addingTimeInterval(-1), duration: 10)
    )
    #expect(remaining.isEmpty)
}

@MainActor
@Test func batchInsertPreservesImportedIdentifiers() async throws {
    let repository = try TestRepository.make()
    try await repository.seedDefaultsIfNeeded()
    let firstID = UUID()
    let secondID = UUID()
    let date = Date(timeIntervalSince1970: 1_700_000_000)

    let saved = try await repository.insert([
        LedgerDraft(id: firstID, kind: .expense, amountText: "10", categoryID: nil, note: "first", occurredAt: date),
        LedgerDraft(id: secondID, kind: .income, amountText: "20", categoryID: nil, note: "second", occurredAt: date)
    ])

    #expect(Set(saved.map(\.id)) == [firstID, secondID])
}

@MainActor
@Test func allEntriesReturnsEveryEntryInStableDateOrder() async throws {
    let repository = try TestRepository.make()
    try await repository.seedDefaultsIfNeeded()
    let later = Date(timeIntervalSince1970: 1_800_000_000)
    let earlier = Date(timeIntervalSince1970: 1_700_000_000)
    _ = try await repository.insert(draft(at: later, note: "later"))
    _ = try await repository.insert(draft(at: earlier, note: "earlier"))

    #expect(try await repository.allEntries().map(\.note) == ["earlier", "later"])
}

@MainActor
@Test func categoryUpdateEditsOnlyNameAndHiddenState() async throws {
    let repository = try TestRepository.make()
    try await repository.seedDefaultsIfNeeded()
    let category = try await repository.ensureCustomCategory(named: "餐饮", kind: .expense)
    let originalKind = category.kind
    let originalSystemKey = category.systemKey

    try await repository.updateCategory(id: category.id, displayName: "Meals", isHidden: true)

    let updated = try #require(try await repository.category(id: category.id))
    #expect(updated.customName == "Meals")
    #expect(updated.isHidden)
    #expect(updated.kind == originalKind)
    #expect(updated.systemKey == originalSystemKey)
}

@MainActor
@Test func emptyCustomCategoryNameIsRejected() async throws {
    let repository = try TestRepository.make()
    try await repository.seedDefaultsIfNeeded()
    let custom = try await repository.ensureCustomCategory(named: "Custom", kind: .expense)
    await #expect(throws: LedgerRepositoryValidationError.emptyCustomCategoryName) {
        try await repository.updateCategory(id: custom.id, displayName: "", isHidden: false)
    }
}

@MainActor
@Test func categoryNamesMustBeUniqueWithinTheSameKind() async throws {
    let repository = try TestRepository.make()
    try await repository.seedDefaultsIfNeeded()
    _ = try await repository.ensureCustomCategory(named: "Meals", kind: .expense)
    let clothing = try await repository.ensureCustomCategory(named: "Clothing", kind: .expense)

    await #expect(throws: (any Error).self) {
        try await repository.updateCategory(id: clothing.id, displayName: " meals ", isHidden: false)
    }
}

@MainActor
@Test func categoryNameCannotDuplicateOther() async throws {
    let repository = try TestRepository.make()
    try await repository.seedDefaultsIfNeeded()
    let custom = try await repository.ensureCustomCategory(named: "Custom", kind: .expense)
    await #expect(throws: LedgerRepositoryValidationError.duplicateCategoryName) {
        try await repository.updateCategory(id: custom.id, displayName: " other ", isHidden: false)
    }
}

@MainActor
@Test func ensuringCategoryByNameReusesExistingCategory() async throws {
    let repository = try TestRepository.make()
    try await repository.seedDefaultsIfNeeded()
    let food = try await repository.ensureCustomCategory(named: "Food", kind: .expense)

    let resolved = try await repository.ensureCustomCategory(named: " FOOD ", kind: .expense)

    #expect(resolved.id == food.id)
    #expect(try await repository.categories(kind: .expense).count == 2)
}

@MainActor
@Test func otherCategoryCannotBeRenamedOrHidden() async throws {
    let repository = try TestRepository.make()
    try await repository.seedDefaultsIfNeeded()
    let other = try #require(try await repository.categories(kind: .expense).first { $0.systemKey == "other" })

    await #expect(throws: (any Error).self) {
        try await repository.updateCategory(id: other.id, displayName: "Renamed", isHidden: true)
    }

    let unchanged = try #require(try await repository.category(id: other.id))
    #expect(unchanged.customName == nil)
    #expect(!unchanged.isHidden)
}

@MainActor
@Test func deletingCategoryMovesItsEntriesToOtherOfTheSameKind() async throws {
    let repository = try TestRepository.make()
    try await repository.seedDefaultsIfNeeded()
    let category = try await repository.ensureCustomCategory(named: "Coffee", kind: .expense)
    let entry = try await repository.insert(
        LedgerDraft(kind: .expense, amountText: "18", categoryID: category.id, note: "Latte", occurredAt: .now)
    )

    try await repository.deleteCategories(ids: [category.id])

    #expect(try await repository.category(id: category.id) == nil)
    let movedEntry = try #require(try await repository.allEntries().first { $0.id == entry.id })
    let fallback = try #require(try await repository.category(id: movedEntry.categoryID))
    #expect(fallback.kind == .expense)
    #expect(fallback.systemKey == "other")
}

@MainActor
@Test func otherCategoryCannotBeDeleted() async throws {
    let repository = try TestRepository.make()
    try await repository.seedDefaultsIfNeeded()
    let other = try #require(try await repository.categories(kind: .income).first { $0.systemKey == "other" })

    await #expect(throws: LedgerRepositoryValidationError.protectedCategory) {
        try await repository.deleteCategories(ids: [other.id])
    }

    #expect(try await repository.category(id: other.id) != nil)
}

@MainActor
@Test func deleteAllEntriesPreservesCategories() async throws {
    let repository = try TestRepository.make()
    try await repository.seedDefaultsIfNeeded()
    _ = try await repository.insert(draft(at: .now, note: "delete me"))
    let categoryCount = try await repository.categories(kind: .expense).count

    try await repository.deleteAllEntries()

    #expect(try await repository.allEntries().isEmpty)
    #expect(try await repository.categories(kind: .expense).count == categoryCount)
}

private func draft(at date: Date, note: String) -> LedgerDraft {
    LedgerDraft(
        kind: .expense,
        amountText: "10.00",
        categoryID: nil,
        note: note,
        occurredAt: date
    )
}

@Suite("Category name policy")
struct CategoryNamePolicyTests {
    @Test func rejectsLocalizedDisplayNameDuplicateWithinKind() {
        #expect(CategoryNamePolicy.isDuplicate(" 餐饮 ", existingDisplayNames: ["餐饮", "交通"]))
        #expect(!CategoryNamePolicy.isDuplicate("餐饮", existingDisplayNames: ["工资", "奖金"]))
    }
}

}
