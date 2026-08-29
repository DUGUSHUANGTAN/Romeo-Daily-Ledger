import Foundation
import Observation

@MainActor
protocol DeletionUndoScheduling: AnyObject {
    func schedule(
        after duration: Duration,
        action: @escaping @MainActor @Sendable () -> Void
    ) -> DeletionUndoCancellation
}

@MainActor
final class DeletionUndoCancellation {
    private var cancellation: (@MainActor () -> Void)?

    init(_ cancellation: @escaping @MainActor () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }
}

@MainActor
final class TaskDeletionUndoScheduler: DeletionUndoScheduling {
    func schedule(
        after duration: Duration,
        action: @escaping @MainActor @Sendable () -> Void
    ) -> DeletionUndoCancellation {
        let task = Task { @MainActor in
            do {
                try await Task.sleep(for: duration)
                action()
            } catch is CancellationError {
                // Cancellation is the expected path when undo is used or dismissed.
            } catch {
                // Task.sleep does not currently produce other errors.
            }
        }

        return DeletionUndoCancellation {
            task.cancel()
        }
    }
}

@MainActor
@Observable
final class DeletionUndoCoordinator {
    private struct EntrySnapshot: Sendable {
        let kind: EntryKind
        let amount: Decimal
        let categoryID: UUID
        let note: String
        let occurredAt: Date

        init(entry: LedgerEntry) {
            kind = entry.kind
            amount = entry.amount
            categoryID = entry.categoryID
            note = entry.note
            occurredAt = entry.occurredAt
        }

        var draft: LedgerDraft {
            LedgerDraft(
                kind: kind,
                amountText: NSDecimalNumber(decimal: amount).stringValue,
                categoryID: categoryID,
                note: note,
                occurredAt: occurredAt
            )
        }
    }

    private let repository: LedgerRepository
    private let undoWindow: Duration
    private let scheduler: any DeletionUndoScheduling
    private var snapshots: [EntrySnapshot] = []
    private var expiration: DeletionUndoCancellation?

    var canUndo: Bool {
        !snapshots.isEmpty
    }

    var pendingSnapshotCount: Int {
        snapshots.count
    }

    init(
        repository: LedgerRepository,
        undoWindow: Duration = .seconds(5),
        scheduler: any DeletionUndoScheduling = TaskDeletionUndoScheduler()
    ) {
        self.repository = repository
        self.undoWindow = undoWindow
        self.scheduler = scheduler
    }

    func delete(entries: [LedgerEntry]) async throws {
        let recoverableSnapshots = entries.map(EntrySnapshot.init)
        let ids = Set(entries.map(\.id))

        try await repository.delete(ids: ids)

        cancelUndo()
        snapshots = recoverableSnapshots
        guard !snapshots.isEmpty else { return }

        expiration = scheduler.schedule(after: undoWindow) { [weak self] in
            self?.cancelUndo()
        }
    }

    @discardableResult
    func undo() async throws -> Bool {
        guard !snapshots.isEmpty else { return false }

        let recoverableSnapshots = snapshots
        cancelUndo()

        for snapshot in recoverableSnapshots {
            _ = try await repository.insert(snapshot.draft)
        }

        return true
    }

    func cancelUndo() {
        snapshots = []
        expiration?.cancel()
        expiration = nil
    }
}
