import Foundation
@testable import RomeoDailyLedger

enum TestRepositoryError: Error {
    case forcedFailure
}

@MainActor
final class RecordingLedgerRepository: LedgerRepository {
    private(set) var insertedDrafts: [LedgerDraft] = []
    private(set) var updatedEntries: [(id: UUID, draft: LedgerDraft)] = []
    private(set) var deletedIDSets: [Set<UUID>] = []
    private(set) var requestedEntryIntervals: [DateInterval] = []

    func seedDefaultsIfNeeded() async throws {}

    func insert(_ draft: LedgerDraft) async throws -> LedgerEntry {
        insertedDrafts.append(draft)
        return LedgerEntry(
            kind: draft.kind,
            amount: try draft.validatedAmount(),
            categoryID: draft.categoryID ?? UUID(),
            note: draft.note,
            occurredAt: draft.occurredAt
        )
    }

    func update(id: UUID, draft: LedgerDraft) async throws {
        updatedEntries.append((id, draft))
    }

    func delete(ids: Set<UUID>) async throws {
        deletedIDSets.append(ids)
    }

    func entries(in interval: DateInterval) async throws -> [LedgerEntry] {
        requestedEntryIntervals.append(interval)
        return []
    }
    func categories(kind: EntryKind) async throws -> [RomeoDailyLedger.Category] { [] }
    func category(id: UUID) async throws -> RomeoDailyLedger.Category? { nil }
}

@MainActor
final class FailingLedgerRepository: LedgerRepository {
    func seedDefaultsIfNeeded() async throws {
        throw TestRepositoryError.forcedFailure
    }

    func insert(_ draft: LedgerDraft) async throws -> LedgerEntry {
        throw TestRepositoryError.forcedFailure
    }

    func update(id: UUID, draft: LedgerDraft) async throws {
        throw TestRepositoryError.forcedFailure
    }

    func delete(ids: Set<UUID>) async throws {
        throw TestRepositoryError.forcedFailure
    }

    func entries(in interval: DateInterval) async throws -> [LedgerEntry] { [] }
    func categories(kind: EntryKind) async throws -> [RomeoDailyLedger.Category] { [] }
    func category(id: UUID) async throws -> RomeoDailyLedger.Category? { nil }
}
