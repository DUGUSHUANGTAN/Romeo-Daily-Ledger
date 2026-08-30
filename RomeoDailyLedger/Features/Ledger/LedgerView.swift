import SwiftUI

struct LedgerView: View {
    @Environment(\.appLanguage) private var language
    @State private var model: LedgerViewModel
    @State private var isDeleteConfirmationPresented = false
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
