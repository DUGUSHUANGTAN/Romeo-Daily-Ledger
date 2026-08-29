import Foundation
import Testing
@testable import RomeoDailyLedger

@Suite("Selection summary")
struct SelectionSummaryTests {
    @Test func emptySelectionReportsZeroTotals() {
        let result = SelectionSummary(entries: [])

        #expect(result.income == 0)
        #expect(result.expense == 0)
        #expect(result.net == 0)
    }

    @Test func incomeSelectionReportsIncomeAndNet() {
        let result = SelectionSummary(entries: [fixture(.income, "25"), fixture(.income, "75")])

        #expect(result.income == 100)
        #expect(result.expense == 0)
        #expect(result.net == 100)
    }

    @Test func expenseSelectionReportsExpenseAndNegativeNet() {
        let result = SelectionSummary(entries: [fixture(.expense, "30"), fixture(.expense, "20")])

        #expect(result.income == 0)
        #expect(result.expense == 50)
        #expect(result.net == -50)
    }

    @Test func mixedSelectionReportsIncomeExpenseAndNet() {
        let entries = [fixture(.expense, "30"), fixture(.income, "100"), fixture(.expense, "20")]
        let result = SelectionSummary(entries: entries)

        #expect(result.income == 100)
        #expect(result.expense == 50)
        #expect(result.net == 50)
    }

    @Test func totalsPreserveDecimalPrecision() {
        let entries = [fixture(.income, "0.10"), fixture(.income, "0.20"), fixture(.expense, "0.03")]
        let result = SelectionSummary(entries: entries)

        #expect(result.income == Decimal(string: "0.30")!)
        #expect(result.expense == Decimal(string: "0.03")!)
        #expect(result.net == Decimal(string: "0.27")!)
    }

    private func fixture(_ kind: EntryKind, _ amount: String) -> LedgerEntry {
        LedgerEntry(
            kind: kind,
            amount: Decimal(string: amount)!,
            categoryID: UUID(),
            note: "",
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}

@MainActor
@Suite("Deletion undo coordinator")
struct DeletionUndoCoordinatorTests {
    @Test func successfulDeletionStoresSnapshotAndSchedulesExpiration() async throws {
        let repository = RecordingLedgerRepository()
        let scheduler = TestUndoScheduler()
        let coordinator = DeletionUndoCoordinator(repository: repository, undoWindow: .seconds(5), scheduler: scheduler)
        let entries = [fixture(.expense, "12.50"), fixture(.income, "4.25")]

        try await coordinator.delete(entries: entries)

        #expect(repository.deletedIDSets == [Set(entries.map(\.id))])
        #expect(coordinator.canUndo)
        #expect(coordinator.pendingSnapshotCount == 2)
        #expect(scheduler.scheduledDurations == [.seconds(5)])
    }

    @Test func failedDeletionDoesNotExposeUndo() async {
        let scheduler = TestUndoScheduler()
        let coordinator = DeletionUndoCoordinator(
            repository: FailingLedgerRepository(),
            undoWindow: .seconds(5),
            scheduler: scheduler
        )

        await #expect(throws: TestRepositoryError.self) {
            try await coordinator.delete(entries: [fixture(.expense, "12.50")])
        }

        #expect(!coordinator.canUndo)
        #expect(coordinator.pendingSnapshotCount == 0)
        #expect(scheduler.scheduledDurations.isEmpty)
    }

    @Test func undoReinsertsImmutableEntrySnapshotsThroughRepository() async throws {
        let repository = RecordingLedgerRepository()
        let scheduler = TestUndoScheduler()
        let coordinator = DeletionUndoCoordinator(repository: repository, undoWindow: .seconds(5), scheduler: scheduler)
        let occurredAt = Date(timeIntervalSince1970: 1_700_000_000)
        let categoryID = UUID()
        let entry = LedgerEntry(
            kind: .expense,
            amount: Decimal(string: "12.50")!,
            categoryID: categoryID,
            note: "Lunch",
            occurredAt: occurredAt
        )

        try await coordinator.delete(entries: [entry])
        entry.amount = 999
        entry.note = "Mutated after deletion"
        let didUndo = try await coordinator.undo()

        #expect(didUndo)
        #expect(repository.insertedDrafts.count == 1)
        #expect(repository.insertedDrafts[0].kind == .expense)
        #expect(try repository.insertedDrafts[0].validatedAmount() == Decimal(string: "12.50")!)
        #expect(repository.insertedDrafts[0].categoryID == categoryID)
        #expect(repository.insertedDrafts[0].note == "Lunch")
        #expect(repository.insertedDrafts[0].occurredAt == occurredAt)
        #expect(!coordinator.canUndo)
        #expect(scheduler.cancelCount == 1)
    }

    @Test func cancellingUndoDiscardsSnapshotWithoutReinserting() async throws {
        let repository = RecordingLedgerRepository()
        let scheduler = TestUndoScheduler()
        let coordinator = DeletionUndoCoordinator(repository: repository, undoWindow: .seconds(5), scheduler: scheduler)

        try await coordinator.delete(entries: [fixture(.expense, "12.50")])
        coordinator.cancelUndo()
        let didUndo = try await coordinator.undo()

        #expect(!didUndo)
        #expect(repository.insertedDrafts.isEmpty)
        #expect(!coordinator.canUndo)
        #expect(scheduler.cancelCount == 1)
    }

    @Test func repeatedUndoOnlyReinsertsSnapshotsOnce() async throws {
        let repository = RecordingLedgerRepository()
        let scheduler = TestUndoScheduler()
        let coordinator = DeletionUndoCoordinator(repository: repository, undoWindow: .seconds(5), scheduler: scheduler)

        try await coordinator.delete(entries: [fixture(.income, "8")])
        let firstResult = try await coordinator.undo()
        let secondResult = try await coordinator.undo()

        #expect(firstResult)
        #expect(!secondResult)
        #expect(repository.insertedDrafts.count == 1)
    }

    private func fixture(_ kind: EntryKind, _ amount: String) -> LedgerEntry {
        LedgerEntry(
            kind: kind,
            amount: Decimal(string: amount)!,
            categoryID: UUID(),
            note: "Fixture",
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}

@MainActor
private final class TestUndoScheduler: DeletionUndoScheduling {
    private(set) var scheduledDurations: [Duration] = []
    private(set) var cancelCount = 0
    private var action: (@MainActor @Sendable () -> Void)?

    func schedule(
        after duration: Duration,
        action: @escaping @MainActor @Sendable () -> Void
    ) -> DeletionUndoCancellation {
        scheduledDurations.append(duration)
        self.action = action
        return DeletionUndoCancellation { [weak self] in
            self?.cancelCount += 1
            self?.action = nil
        }
    }

    func expire() {
        let action = action
        self.action = nil
        action?()
    }
}
