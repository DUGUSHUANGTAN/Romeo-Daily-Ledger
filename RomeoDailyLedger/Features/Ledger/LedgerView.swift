import SwiftUI

struct LedgerView: View {
    @Environment(\.appLanguage) private var language
    @State private var model: LedgerViewModel
    @State private var isDeleteConfirmationPresented = false
    let repository: LedgerRepository
    let theme: AppTheme
    let typography: AppTypography.Style

    init(repository: LedgerRepository, theme: AppTheme, typography: AppTypography.Style) {
        _model = State(initialValue: LedgerViewModel(repository: repository))
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
            }
            QuickEntryView(model: model, theme: theme, typography: typography)
            EntryListView(model: model, theme: theme, typography: typography)
            if !model.selectedEntryIDs.isEmpty {
                SelectionSummaryBar(summary: model.selectionSummary, theme: theme, typography: typography) {
                    isDeleteConfirmationPresented = true
                } onCancel: {
                    model.clearSelection()
                }
            }
        }
        .padding(28)
        .foregroundStyle(theme.primaryText.color)
        .background(theme.canvas.color)
        .task { await model.start() }
        .onDisappear { model.clearSelection() }
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
        }
    }
}

struct HistoryView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.appCurrencyCode) private var currencyCode
    @State private var model: EntriesCollectionModel
    @State private var editingEntry: LedgerEntry?
    @State private var isDeleteConfirmationPresented = false
    @State private var searchText = ""
    @State private var categoryNames: [UUID: String] = [:]
    let repository: LedgerRepository
    let theme: AppTheme
    let typography: AppTypography.Style

    init(repository: LedgerRepository, theme: AppTheme, typography: AppTypography.Style) {
        _model = State(initialValue: EntriesCollectionModel(repository: repository))
        self.repository = repository
        self.theme = theme
        self.typography = typography
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(AppLocalization.text("history.title", language: language)).font(AppTypography.display(typography))
                Spacer()
            }
            TextField(AppLocalization.text("history.search.placeholder", language: language), text: $searchText)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("history-search")
            if model.errorMessage != nil { Text(AppLocalization.text("error.loadEntries", language: language)).foregroundStyle(.red) }
            ScrollView {
                if groupedEntries.isEmpty {
                    Text(AppLocalization.text("state.empty", language: language))
                        .font(AppTypography.title(typography))
                        .foregroundStyle(theme.secondaryText.color)
                        .frame(maxWidth: .infinity, minHeight: 180)
                        .accessibilityIdentifier("history-empty")
                }
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(groupedEntries) { group in
                        Section {
                            ForEach(group.entries) { entry in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(entry.note.isEmpty ? AppLocalization.text("entry.noNote", language: language) : entry.note)
                                        Text("\(AppLocalization.text(entry.kind == .income ? "entry.income" : "entry.expense", language: language)) · \(categoryNames[entry.categoryID] ?? AppLocalization.text("category.other", language: language))")
                                            .font(AppTypography.caption(typography)).foregroundStyle(theme.secondaryText.color)
                                    }
                                    Spacer()
                                    Text(LedgerFormatting.amount(entry.amount, currencyCode: currencyCode))
                                }
                                .padding(12)
                                .background(model.selectedEntryIDs.contains(entry.id) ? theme.primaryAccent.color.opacity(0.16) : theme.surface.color, in: RoundedRectangle(cornerRadius: 8))
                                .contentShape(Rectangle())
                                .gesture(
                                    LongPressGesture(minimumDuration: 0.5)
                                        .exclusively(before: TapGesture())
                                        .onEnded { value in
                                            switch value {
                                            case .first: model.selectedEntryIDs.insert(entry.id)
                                            case .second:
                                                if model.selectedEntryIDs.isEmpty { editingEntry = entry }
                                                else { model.toggleSelection(entry.id) }
                                            }
                                        }
                                )
                                .accessibilityAddTraits(.isButton)
                                .accessibilityAddTraits(model.selectedEntryIDs.contains(entry.id) ? .isSelected : [])
                                .accessibilityIdentifier("history-entry-\(entry.id.uuidString.lowercased())")
                            }
                        } header: {
                            Text(group.date, format: .dateTime.year().month().day()).font(AppTypography.title(typography))
                        }
                    }
                }
            }.accessibilityIdentifier("history-list")
            if !model.selectedEntryIDs.isEmpty {
                SelectionSummaryBar(summary: model.selectionSummary, theme: theme, typography: typography) {
                    isDeleteConfirmationPresented = true
                } onCancel: {
                    model.selectedEntryIDs.removeAll()
                }
                .accessibilityIdentifier("history-selection-summary")
            }
        }
        .padding(28).foregroundStyle(theme.primaryText.color).background(theme.canvas.color)
        .task { await load() }
        .sheet(item: $editingEntry) { entry in
            EntryEditorView(entry: entry, repository: repository, theme: theme, typography: typography) {
                await load()
            }
        }
        .confirmationDialog(
            AppLocalization.text("ledger.delete.confirmTitle", language: language),
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(AppLocalization.text("button.confirmDelete", language: language), role: .destructive) {
                Task { await deleteSelection() }
            }
            .accessibilityIdentifier("confirm-delete-selected")
            Button(AppLocalization.text("button.cancel", language: language), role: .cancel) { }
        }
    }

    private var groupedEntries: [LedgerEntryGrouping.Group] {
        let index = HistorySearchIndex(entries: model.entries, categoryNames: categoryNames, calendar: .autoupdatingCurrent)
        return LedgerEntryGrouping.groups(index.results(matching: searchText))
    }

    private func deleteSelection() async {
        await model.deleteSelection()
    }

    private func load() async {
        await model.loadAll()
        let expense = (try? await repository.categories(kind: .expense)) ?? []
        let income = (try? await repository.categories(kind: .income)) ?? []
        categoryNames = Dictionary(uniqueKeysWithValues: (expense + income).map {
            ($0.id, LedgerFormatting.categoryName($0, language: language))
        })
    }
}
