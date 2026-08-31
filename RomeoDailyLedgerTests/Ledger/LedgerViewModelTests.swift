import Foundation
import Testing
@testable import RomeoDailyLedger

@MainActor
@Suite("LedgerViewModelTests")
struct LedgerViewModelTests {
    @Test func reloadUsesInjectedClockForTheRequestedLocalDay() async throws {
        let repository = RecordingLedgerRepository()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let date = try #require(ISO8601DateFormatter().date(from: "2024-02-10T12:00:00+08:00"))
        let model = LedgerViewModel(repository: repository, calendar: calendar, now: { date })

        try await model.reload()

        let interval = try #require(repository.requestedEntryIntervals.last)
        #expect(interval == calendar.dateInterval(of: .day, for: date))
    }

    @Test func quickEntryRefreshesOccurrenceTimeAtSave() async throws {
        let repository = RecordingLedgerRepository()
        let launchDate = Date(timeIntervalSince1970: 1_700_000_000)
        let saveDate = Date(timeIntervalSince1970: 1_800_000_000)
        let model = LedgerViewModel(repository: repository, now: { saveDate })
        model.draft.amountText = "12.50"
        model.draft.occurredAt = launchDate

        try await model.saveQuickEntry()

        #expect(repository.insertedDrafts.first?.occurredAt == saveDate)
        #expect(model.draft.occurredAt == saveDate)
    }

    @Test func successfulSaveClearsTransientInputButKeepsContext() async throws {
        let repository = RecordingLedgerRepository()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let categoryID = UUID()
        let model = LedgerViewModel(repository: repository)
        model.draft = LedgerDraft(
            kind: .income,
            amountText: "20.50",
            categoryID: categoryID,
            note: "Dinner",
            occurredAt: date
        )

        try await model.save()

        #expect(repository.insertedDrafts.count == 1)
        #expect(repository.insertedDrafts[0].amountText == "20.50")
        #expect(model.draft.amountText.isEmpty)
        #expect(model.draft.note.isEmpty)
        #expect(model.draft.categoryID == nil)
        #expect(model.draft.occurredAt == date)
        #expect(model.draft.kind == .income)
        #expect(model.errorMessage == nil)
    }

    @Test func failedSavePreservesEveryInputAndExposesError() async {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let categoryID = UUID()
        let model = LedgerViewModel(repository: FailingLedgerRepository())
        let input = LedgerDraft(
            kind: .income,
            amountText: "20.50",
            categoryID: categoryID,
            note: "Dinner",
            occurredAt: date
        )
        model.draft = input

        await #expect(throws: TestRepositoryError.forcedFailure) {
            try await model.save()
        }

        #expect(model.draft.kind == input.kind)
        #expect(model.draft.amountText == input.amountText)
        #expect(model.draft.categoryID == input.categoryID)
        #expect(model.draft.note == input.note)
        #expect(model.draft.occurredAt == input.occurredAt)
        #expect(model.errorMessage != nil)
    }

    @Test func invalidAmountPreservesInputAndExposesValidationError() async {
        let repository = RecordingLedgerRepository()
        let model = LedgerViewModel(repository: repository)
        model.draft.amountText = "0"
        model.draft.note = "Keep me"

        await #expect(throws: LedgerDraft.ValidationError.invalidAmount) {
            try await model.save()
        }

        #expect(repository.insertedDrafts.count == 1)
        #expect(model.draft.amountText == "0")
        #expect(model.draft.note == "Keep me")
        #expect(model.errorMessage != nil)
    }

    @Test func editorLoadsEveryEditableFieldFromEntry() {
        let repository = RecordingLedgerRepository()
        let categoryID = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = LedgerEntry(
            kind: .expense,
            amount: Decimal(string: "12.75")!,
            categoryID: categoryID,
            note: "Lunch",
            occurredAt: date
        )

        let model = EntryEditorViewModel(entry: entry, repository: repository)

        #expect(model.draft.kind == .expense)
        #expect(model.draft.amountText == "12.75")
        #expect(model.draft.categoryID == categoryID)
        #expect(model.draft.note == "Lunch")
        #expect(model.draft.occurredAt == date)
    }

    @Test func editorSavesEveryModifiedFieldThroughRepositoryUpdate() async throws {
        let repository = RecordingLedgerRepository()
        let entry = LedgerEntry(
            kind: .expense,
            amount: 10,
            categoryID: UUID(),
            note: "Before",
            occurredAt: .now
        )
        let model = EntryEditorViewModel(entry: entry, repository: repository)
        let newCategoryID = UUID()
        let newDate = Date(timeIntervalSince1970: 1_800_000_000)
        model.draft = LedgerDraft(
            kind: .income,
            amountText: "99.25",
            categoryID: newCategoryID,
            note: "After",
            occurredAt: newDate
        )

        try await model.save()

        let update = try #require(repository.updatedEntries.first)
        #expect(update.id == entry.id)
        #expect(update.draft.kind == .income)
        #expect(update.draft.amountText == "99.25")
        #expect(update.draft.categoryID == newCategoryID)
        #expect(update.draft.note == "After")
        #expect(update.draft.occurredAt == newDate)
        #expect(model.errorMessage == nil)
    }

    @Test func failedEditPreservesEveryModifiedFieldAndExposesError() async {
        let entry = LedgerEntry(
            kind: .expense,
            amount: 10,
            categoryID: UUID(),
            note: "Before",
            occurredAt: .now
        )
        let model = EntryEditorViewModel(entry: entry, repository: FailingLedgerRepository())
        let input = LedgerDraft(
            kind: .income,
            amountText: "99.25",
            categoryID: UUID(),
            note: "After",
            occurredAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        model.draft = input

        await #expect(throws: TestRepositoryError.forcedFailure) {
            try await model.save()
        }

        #expect(model.draft.kind == input.kind)
        #expect(model.draft.amountText == input.amountText)
        #expect(model.draft.categoryID == input.categoryID)
        #expect(model.draft.note == input.note)
        #expect(model.draft.occurredAt == input.occurredAt)
        #expect(model.errorMessage != nil)
    }

    @Test func hiddenCategoryIsExcludedForNewEntriesButPreservedForHistoricalEditing() {
        let visible = Category(kind: .expense, customName: "Visible", iconName: "", colorToken: "", sortOrder: 0)
        let hidden = Category(kind: .expense, customName: "Hidden", iconName: "", colorToken: "", sortOrder: 1, isHidden: true)

        #expect(CategorySelection.available(from: [visible, hidden], selectedID: nil).map(\.id) == [visible.id])
        #expect(CategorySelection.available(from: [visible, hidden], selectedID: hidden.id).map(\.id) == [visible.id, hidden.id])
    }
}
