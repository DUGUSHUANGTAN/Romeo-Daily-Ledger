import Foundation
import Testing
@testable import RomeoDailyLedger

@MainActor
@Suite("LedgerRepositoryTests")
struct LedgerRepositoryTests {

@MainActor
@Test func seederCreatesRequiredExpenseCategories() async throws {
    let repository = try TestRepository.make()

    try await repository.seedDefaultsIfNeeded()

    let keys = try await repository.categories(kind: .expense).compactMap(\.systemKey)
    #expect(keys == ["clothing", "food", "housing", "transport", "entertainment", "other"])
}

@MainActor
@Test func seederCreatesRequiredIncomeCategories() async throws {
    let repository = try TestRepository.make()

    try await repository.seedDefaultsIfNeeded()

    let keys = try await repository.categories(kind: .income).compactMap(\.systemKey)
    #expect(keys == ["salary", "bonus", "investment", "refund", "other"])
}

@MainActor
@Test func seedingDefaultsIsIdempotent() async throws {
    let repository = try TestRepository.make()

    try await repository.seedDefaultsIfNeeded()
    try await repository.seedDefaultsIfNeeded()

    #expect(try await repository.categories(kind: .expense).count == 6)
    #expect(try await repository.categories(kind: .income).count == 5)
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
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let end = start.addingTimeInterval(86_400)

    _ = try await repository.insert(draft(at: start, note: "start"))
    _ = try await repository.insert(draft(at: end.addingTimeInterval(-1), note: "inside"))
    _ = try await repository.insert(draft(at: end, note: "end"))

    let entries = try await repository.entries(in: DateInterval(start: start, end: end))
    #expect(entries.map(\.note) == ["start", "inside"])
}

@MainActor
@Test func updateEditsAllDraftFieldsAndRefreshesUpdatedAt() async throws {
    let repository = try TestRepository.make()
    try await repository.seedDefaultsIfNeeded()
    let saved = try await repository.insert(draft(at: .now, note: "before"))
    let originalUpdatedAt = saved.updatedAt
    let incomeCategory = try #require(
        try await repository.categories(kind: .income).first { $0.systemKey == "salary" }
    )
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

    let entries = try await repository.entries(
        in: DateInterval(start: changedDate.addingTimeInterval(-1), end: changedDate.addingTimeInterval(1))
    )
    let updated = try #require(entries.first)
    #expect(updated.kind == .income)
    #expect(updated.amount == Decimal(string: "99.25"))
    #expect(updated.categoryID == incomeCategory.id)
    #expect(updated.note == "after")
    #expect(updated.occurredAt == changedDate)
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

private func draft(at date: Date, note: String) -> LedgerDraft {
    LedgerDraft(
        kind: .expense,
        amountText: "10.00",
        categoryID: nil,
        note: note,
        occurredAt: date
    )
}

}
