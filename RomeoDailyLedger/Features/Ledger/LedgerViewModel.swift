import Foundation
import Observation

@Observable
@MainActor
final class LedgerViewModel {
    var draft: LedgerDraft
    var errorMessage: String?
    var entries: [LedgerEntry] = []
    var categories: [Category] = []
    var categoryNames: [UUID: String] = [:]
    var selectedEntryIDs: Set<UUID> = []
    var editingEntry: LedgerEntry?

    private let repository: LedgerRepository
    private let calendar: Calendar
    private let dateNormalizer: AppDateNormalizer

    init(
        repository: LedgerRepository,
        calendar: Calendar = .autoupdatingCurrent,
        clock: any AppClock = SystemAppClock(),
        timeZoneProvider: any AppTimeZoneProviding = SystemAppTimeZoneProvider()
    ) {
        self.repository = repository
        self.calendar = calendar
        self.dateNormalizer = AppDateNormalizer(clock: clock, timeZoneProvider: timeZoneProvider)
        self.draft = LedgerDraft(
            kind: .expense,
            amountText: "",
            categoryID: nil,
            note: "",
            occurredAt: dateNormalizer.today
        )
    }

    func saveQuickEntry() async throws {
        do {
            try await save()
        } catch {
            throw error
        }
    }

    func save() async throws {
        do {
            var normalizedDraft = draft
            normalizedDraft.occurredAt = dateNormalizer.normalize(draft.occurredAt)
            _ = try await repository.insert(normalizedDraft)
            draft.amountText = ""
            draft.note = ""
            draft.categoryID = categories.first(where: { $0.systemKey == "other" })?.id
            draft.occurredAt = dateNormalizer.today
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
        let expense = try await repository.categories(kind: .expense)
        let income = try await repository.categories(kind: .income)
        let all = expense + income
        categoryNames = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0.customName ?? $0.systemKey ?? "other") })
        categories = CategorySelection.available(from: all.filter { $0.kind == draft.kind }, selectedID: draft.categoryID)
        if let selected = draft.categoryID, !categories.contains(where: { $0.id == selected }) {
            draft.categoryID = nil
        }
        if draft.categoryID == nil {
            draft.categoryID = categories.first(where: { $0.systemKey == "other" })?.id
        }
    }

    func reload() async throws {
        let interval = calendar.dateInterval(of: .day, for: dateNormalizer.today)!
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

    func activate(_ entry: LedgerEntry) {
        if selectedEntryIDs.isEmpty {
            editingEntry = entry
        } else {
            toggleSelection(entry)
        }
    }

    func beginSelection(with entry: LedgerEntry) {
        selectedEntryIDs.insert(entry.id)
    }

    func clearSelection() {
        selectedEntryIDs.removeAll()
    }

    func deleteSelection() async {
        guard !selectedEntryIDs.isEmpty else { return }
        do {
            try await repository.delete(ids: selectedEntryIDs)
            selectedEntryIDs = []
            try await reload()
        } catch {
            errorMessage = String(describing: error)
        }
    }

}
