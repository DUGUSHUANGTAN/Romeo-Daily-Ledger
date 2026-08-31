import Foundation
import Observation

@Observable
@MainActor
final class LedgerViewModel {
    var draft: LedgerDraft
    var errorMessage: String?
    var entries: [LedgerEntry] = []
    var categories: [Category] = []
    var selectedEntryIDs: Set<UUID> = []
    var editingEntry: LedgerEntry?

    private let repository: LedgerRepository
    private let deletionUndoCoordinator: DeletionUndoCoordinator?
    private let calendar: Calendar
    private let now: @MainActor () -> Date

    init(
        repository: LedgerRepository,
        deletionUndoCoordinator: DeletionUndoCoordinator? = nil,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping @MainActor () -> Date = { .now }
    ) {
        self.repository = repository
        self.deletionUndoCoordinator = deletionUndoCoordinator
        self.calendar = calendar
        self.now = now
        self.draft = LedgerDraft(
            kind: .expense,
            amountText: "",
            categoryID: nil,
            note: "",
            occurredAt: now()
        )
    }

    func saveQuickEntry() async throws {
        let previousDate = draft.occurredAt
        draft.occurredAt = now()
        do {
            try await save()
        } catch {
            draft.occurredAt = previousDate
            throw error
        }
    }

    func save() async throws {
        do {
            _ = try await repository.insert(draft)
            draft.amountText = ""
            draft.note = ""
            draft.categoryID = nil
            errorMessage = nil
            try await reload()
        } catch {
            errorMessage = String(describing: error)
            throw error
        }
    }

    var selectionSummary: SelectionSummary {
        SelectionSummary(entries: entries.filter { selectedEntryIDs.contains($0.id) })
    }

    var canUndo: Bool { deletionUndoCoordinator?.canUndo == true }

    func start() async {
        do {
            try await repository.seedDefaultsIfNeeded()
            try await loadCategories()
            try await reload()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func loadCategories() async throws {
        categories = CategorySelection.available(from: try await repository.categories(kind: draft.kind), selectedID: draft.categoryID)
        if let selected = draft.categoryID, !categories.contains(where: { $0.id == selected }) {
            draft.categoryID = nil
        }
    }

    func reload() async throws {
        let interval = calendar.dateInterval(of: .day, for: now())!
        entries = try await repository.entries(in: interval)
        selectedEntryIDs.formIntersection(Set(entries.map(\.id)))
    }

    func toggleSelection(_ entry: LedgerEntry) {
        if selectedEntryIDs.contains(entry.id) {
            selectedEntryIDs.remove(entry.id)
        } else {
            selectedEntryIDs.insert(entry.id)
        }
    }

    func deleteSelection() async {
        guard let deletionUndoCoordinator else { return }
        let selected = entries.filter { selectedEntryIDs.contains($0.id) }
        do {
            try await deletionUndoCoordinator.delete(entries: selected)
            selectedEntryIDs = []
            try await reload()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func undoDelete() async {
        do {
            _ = try await deletionUndoCoordinator?.undo()
            try await reload()
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
