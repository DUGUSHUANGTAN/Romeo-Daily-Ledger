import SwiftUI

struct LedgerView: View {
    @Environment(\.appLanguage) private var language
    @State private var model: LedgerViewModel
    @State private var isDeleteConfirmationPresented = false
    @State private var showsAllEntries = false
    let repository: LedgerRepository
    let theme: AppTheme
    let typography: AppTypography.Style

    init(repository: LedgerRepository, deletionUndoCoordinator: DeletionUndoCoordinator, theme: AppTheme, typography: AppTypography.Style) {
        _model = State(initialValue: LedgerViewModel(repository: repository, deletionUndoCoordinator: deletionUndoCoordinator))
        self.repository = repository
        self.theme = theme
        self.typography = typography
    }

    var body: some View {
        if showsAllEntries {
            AllEntriesView(repository: repository, theme: theme, typography: typography) { showsAllEntries = false }
        } else {
            dailyLedger
        }
    }

    private var dailyLedger: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLocalization.text("nav.ledger.title", language: language)).font(AppTypography.display(typography))
                    Text(AppLocalization.text("ledger.subtitle", language: language))
                        .font(AppTypography.body(typography))
                        .foregroundStyle(theme.secondaryText.color)
                }
                Spacer()
                if model.canUndo {
                    Button(AppLocalization.text("button.undoDelete", language: language)) { Task { await model.undoDelete() } }
                        .accessibilityIdentifier("undo-delete")
                }
            }
            QuickEntryView(model: model, theme: theme, typography: typography)
            EntryListView(model: model, theme: theme, typography: typography)
            if !model.selectedEntryIDs.isEmpty {
                SelectionSummaryBar(summary: model.selectionSummary, theme: theme, typography: typography) {
                    isDeleteConfirmationPresented = true
                }
            }
            HStack {
                Spacer()
                Button(language == .simplifiedChinese ? "全部" : "All") { showsAllEntries = true }
                    .accessibilityIdentifier("ledger-show-all")
            }
        }
        .padding(28)
        .foregroundStyle(theme.primaryText.color)
        .background(theme.canvas.color)
        .task { await model.start() }
        .sheet(item: $model.editingEntry) { entry in
            EntryEditorView(entry: entry, repository: repository, theme: theme, typography: typography) {
                try? await model.reload()
            }
        }
        .confirmationDialog(
            AppLocalization.text("ledger.delete.confirmTitle", language: language),
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(AppLocalization.text("button.confirmDelete", language: language), role: .destructive) {
                Task { await model.deleteSelection() }
            }
            .accessibilityIdentifier("confirm-delete-selected")
            Button(AppLocalization.text("button.cancel", language: language), role: .cancel) { }
        } message: {
            Text(AppLocalization.text("ledger.delete.undoHelp", language: language))
        }
    }
}

private struct AllEntriesView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.appCurrencyCode) private var currencyCode
    @State private var entries: [LedgerEntry] = []
    @State private var errorMessage: String?
    let repository: LedgerRepository
    let theme: AppTheme
    let typography: AppTypography.Style
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button(language == .simplifiedChinese ? "返回" : "Back", action: onBack)
                    .accessibilityIdentifier("ledger-all-back")
                Text(language == .simplifiedChinese ? "全部账目" : "All Entries").font(AppTypography.display(typography))
                Spacer()
            }
            if errorMessage != nil { Text(AppLocalization.text("error.loadEntries", language: language)).foregroundStyle(.red) }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(groupedEntries) { group in
                        Section {
                            ForEach(group.entries) { entry in
                                HStack {
                                    Text(entry.note.isEmpty ? AppLocalization.text("entry.noNote", language: language) : entry.note)
                                    Spacer()
                                    Text(LedgerFormatting.amount(entry.amount, currencyCode: currencyCode))
                                }
                                .padding(12).background(theme.surface.color, in: RoundedRectangle(cornerRadius: 8))
                            }
                        } header: {
                            Text(group.date, format: .dateTime.year().month().day()).font(AppTypography.title(typography))
                        }
                    }
                }
            }.accessibilityIdentifier("ledger-all-list")
        }
        .padding(28).foregroundStyle(theme.primaryText.color).background(theme.canvas.color)
        .task { await load() }
    }

    private var groupedEntries: [LedgerEntryGrouping.Group] {
        LedgerEntryGrouping.groups(entries)
    }

    private func load() async {
        do { entries = try await repository.allEntries(); errorMessage = nil }
        catch { errorMessage = String(describing: error) }
    }
}
