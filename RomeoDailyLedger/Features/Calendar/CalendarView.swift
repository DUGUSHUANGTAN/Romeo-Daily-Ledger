import SwiftUI

struct CalendarView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.appCurrencyCode) private var currencyCode
    @State private var model = CalendarViewModel()
    @State private var entries: [LedgerEntry] = []
    @State private var errorMessage: String?
    @State private var editingEntry: LedgerEntry?
    @State private var selectedEntryIDs: Set<UUID> = []
    @State private var isDeleteConfirmationPresented = false
    @State private var yearText = ""
    @State private var categoryNames: [UUID: String] = [:]
    @FocusState private var isYearFieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    let repository: LedgerRepository
    let theme: AppTheme
    let typography: AppTypography.Style

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLocalization.text("nav.calendar.title", language: language)).font(AppTypography.display(typography))
                    Text(model.displayedMonth, format: .dateTime.year().month(.wide))
                        .font(AppTypography.body(typography))
                        .foregroundStyle(theme.secondaryText.color)
                }
                HStack(spacing: 10) {
                    TextField(AppLocalization.text("calendar.year", language: language), text: $yearText)
                        .labelsHidden()
                        .frame(width: 72)
                        .accessibilityIdentifier("calendar-year")
                        .focused($isYearFieldFocused)
                        .onSubmit { commitYear() }
                    Picker(AppLocalization.text("calendar.month", language: language), selection: monthBinding) {
                        ForEach(1...12, id: \.self) { Text(model.calendar.monthSymbols[$0 - 1]).tag($0) }
                    }
                    .labelsHidden().frame(width: 110).accessibilityIdentifier("calendar-month")
                    Button(AppLocalization.text("button.today", language: language)) {
                        model.selectToday()
                        Task { await loadEntries() }
                    }
                    .accessibilityIdentifier("calendar-today")
                    Spacer(minLength: 0)
                }
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol).font(AppTypography.caption(typography)).foregroundStyle(theme.secondaryText.color)
                }
                ForEach(model.monthGrid()) { day in
                    Button {
                        model.selectedDate = day.date
                        Task { await loadEntries() }
                    } label: {
                        Text(day.date, format: .dateTime.day())
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .foregroundStyle(day.isInDisplayedMonth ? theme.primaryText.color : theme.secondaryText.color.opacity(0.55))
                            .background(model.calendar.isDate(day.date, inSameDayAs: model.selectedDate) ? theme.primaryAccent.color.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .animation(selectionAnimation, value: model.selectedDate)
                    .accessibilityLabel(day.date.formatted(date: .long, time: .omitted))
                    .accessibilityAddTraits(model.calendar.isDate(day.date, inSameDayAs: model.selectedDate) ? .isSelected : [])
                    .accessibilityValue(AppLocalization.text(model.calendar.isDate(day.date, inSameDayAs: model.selectedDate) ? "accessibility.selected" : "accessibility.notSelected", language: language))
                    .accessibilityIdentifier("calendar-day-\(Int(day.date.timeIntervalSince1970))")
                }
            }
            .padding(14)
            .background(theme.surface.color, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(AppLocalization.text("accessibility.monthCalendar", language: language))
            .accessibilityIdentifier("calendar-grid")
            Divider()
            Text(model.selectedDate, format: .dateTime.year().month().day())
                .font(AppTypography.title(typography))
            let summary = SelectionSummary(entries: entries)
            HStack(spacing: 16) {
                Text(AppLocalization.format("calendar.dayIncome", language: language, LedgerFormatting.amount(summary.income, currencyCode: currencyCode)))
                    .accessibilityIdentifier("calendar-day-income")
                Text(AppLocalization.format("calendar.dayExpense", language: language, LedgerFormatting.amount(summary.expense, currencyCode: currencyCode)))
                    .accessibilityIdentifier("calendar-day-expense")
                Text(AppLocalization.format("calendar.dayBalance", language: language, LedgerFormatting.amount(summary.balance, currencyCode: currencyCode)))
                    .accessibilityIdentifier("calendar-day-balance")
            }
            .font(AppTypography.caption(typography))
            .foregroundStyle(theme.secondaryText.color)
            if errorMessage != nil {
                Text(AppLocalization.text("error.loadEntries", language: language))
                    .foregroundStyle(.red)
            } else if entries.isEmpty {
                Text(AppLocalization.text("calendar.empty", language: language))
                    .foregroundStyle(theme.secondaryText.color)
                    .accessibilityIdentifier("calendar-empty-state")
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(entries) { entry in
                        HStack(spacing: 12) {
                            Text(entry.note.isEmpty ? AppLocalization.text("entry.noNote", language: language) : entry.note)
                            Text("\(AppLocalization.text(entry.kind == .income ? "entry.income" : "entry.expense", language: language)) · \(categoryNames[entry.categoryID] ?? AppLocalization.text("category.other", language: language))")
                                .font(AppTypography.caption(typography)).foregroundStyle(theme.secondaryText.color)
                            Spacer()
                            Text(LedgerFormatting.amount(entry.amount, currencyCode: currencyCode))
                        }
                        .padding(12)
                        .background(selectedEntryIDs.contains(entry.id) ? theme.primaryAccent.color.opacity(0.16) : theme.surface.color, in: RoundedRectangle(cornerRadius: 10))
                        .contentShape(Rectangle())
                        .gesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .exclusively(before: TapGesture())
                                .onEnded { value in
                                    switch value {
                                    case .first: selectedEntryIDs.insert(entry.id)
                                    case .second:
                                        if selectedEntryIDs.isEmpty { editingEntry = entry }
                                        else { toggleSelection(entry.id) }
                                    }
                                }
                        )
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAddTraits(selectedEntryIDs.contains(entry.id) ? .isSelected : [])
                        .accessibilityLabel("\(AppLocalization.text(entry.kind == .income ? "entry.income" : "entry.expense", language: language)) \(categoryNames[entry.categoryID] ?? AppLocalization.text("category.other", language: language)) \(entry.note.isEmpty ? AppLocalization.text("entry.noNote", language: language) : entry.note) \(LedgerFormatting.amount(entry.amount, currencyCode: currencyCode))")
                        .accessibilityIdentifier("calendar-entry-\(entry.id.uuidString.lowercased())")
                        .contextMenu {
                            Button(AppLocalization.text("button.editEntry", language: language)) { editingEntry = entry }
                        }
                    }
                }
                .accessibilityIdentifier("calendar-entry-list")
            }
            if !selectedEntryIDs.isEmpty {
                SelectionSummaryBar(summary: SelectionSummary(entries: entries.filter { selectedEntryIDs.contains($0.id) }), theme: theme, typography: typography) {
                    isDeleteConfirmationPresented = true
                } onCancel: {
                    selectedEntryIDs.removeAll()
                }
                .accessibilityIdentifier("calendar-selection-summary")
            }
            }
            .padding(28)
            .frame(maxWidth: 980, alignment: .leading)
        }
        .accessibilityIdentifier("calendar-page-scroll")
        .foregroundStyle(theme.primaryText.color)
        .background(theme.canvas.color)
        .task {
            try? await repository.seedDefaultsIfNeeded()
            await loadCategoryNames()
            synchronizeYearText()
            await loadEntries()
        }
        .onChange(of: model.displayedMonth) { _, _ in synchronizeYearText() }
        .onChange(of: isYearFieldFocused) { wasFocused, isFocused in
            if YearInputCommitBehavior.shouldCommit(previouslyFocused: wasFocused, currentlyFocused: isFocused) {
                commitYear()
            }
        }
        .sheet(item: $editingEntry) { entry in
            EntryEditorView(entry: entry, repository: repository, theme: theme, typography: typography) {
                await loadEntries()
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
            Button(AppLocalization.text("button.cancel", language: language), role: .cancel) { }
        }
    }

    private func loadCategoryNames() async {
        let values = ((try? await repository.categories(kind: .expense)) ?? []) + ((try? await repository.categories(kind: .income)) ?? [])
        categoryNames = Dictionary(uniqueKeysWithValues: values.map { ($0.id, LedgerFormatting.categoryName($0, language: language)) })
    }

    private var weekdaySymbols: [String] {
        let symbols = model.calendar.shortStandaloneWeekdaySymbols
        let split = model.calendar.firstWeekday - 1
        return Array(symbols[split...] + symbols[..<split])
    }

    private var monthBinding: Binding<Int> { Binding(get: { model.calendar.component(.month, from: model.displayedMonth) }, set: { model.select(year: model.calendar.component(.year, from: model.displayedMonth), month: $0); Task { await loadEntries() } }) }

    private var selectionAnimation: Animation? {
        let policy = MotionPolicy.navigation(systemReduceMotion: systemReduceMotion)
        return policy.effectiveIntensity == 0 ? nil : .easeOut(duration: policy.duration)
    }

    private func synchronizeYearText() {
        yearText = String(model.calendar.component(.year, from: model.displayedMonth))
    }

    private func commitYear() {
        guard let year = CalendarViewModel.validatedYear(from: yearText) else {
            synchronizeYearText()
            return
        }
        model.select(year: year, month: model.calendar.component(.month, from: model.displayedMonth))
        Task { await loadEntries() }
    }

    private func loadEntries() async {
        do {
            entries = try await repository.entries(in: model.dayInterval(containing: model.selectedDate))
            selectedEntryIDs.formIntersection(Set(entries.map(\.id)))
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedEntryIDs.contains(id) { selectedEntryIDs.remove(id) }
        else { selectedEntryIDs.insert(id) }
    }

    private func deleteSelection() async {
        do {
            try await repository.delete(ids: selectedEntryIDs)
            selectedEntryIDs.removeAll()
            await loadEntries()
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
