import SwiftUI

struct CategoryManagementView: View {
    let repository: LedgerRepository
    let language: AppLanguage
    @State private var expenseCategories: [Category] = []
    @State private var incomeCategories: [Category] = []
    @State private var selectedCategory: Category?
    @State private var editingCategory: Category?
    @State private var editedName = ""
    @State private var isManaging = false
    @State private var selectedCategoryIDs: Set<UUID> = []
    @State private var isDeleteConfirmationPresented = false
    @State private var newCategoryKind: EntryKind?
    @State private var newCategoryName = ""
    @State private var errorMessage: String?

    var body: some View {
        if let selectedCategory {
            CategoryEntriesView(category: selectedCategory, repository: repository, language: language) {
                self.selectedCategory = nil
            }
        } else {
            categoryList
        }
    }

    private var categoryList: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(AppLocalization.text("settings.categories.hint", language: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(AppLocalization.text(isManaging ? "button.done" : "button.manage", language: language)) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isManaging.toggle()
                        if !isManaging { selectedCategoryIDs.removeAll() }
                    }
                }
                .accessibilityIdentifier("categories-manage")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            List {
                categorySection(titleKey: "entry.expense", categories: expenseCategories)
                categorySection(titleKey: "entry.income", categories: incomeCategories)
                if errorMessage != nil {
                    Text(AppLocalization.text("error.loadCategories", language: language))
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("settings-categories-error")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(AppLocalization.text("settings.categories.title", language: language))
        .overlay(alignment: .bottomTrailing) {
            if isManaging {
                Button(AppLocalization.text("button.deleteSelected", language: language)) {
                    isDeleteConfirmationPresented = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(selectedCategoryIDs.isEmpty)
                .padding(20)
                .transition(.scale.combined(with: .opacity))
                .accessibilityIdentifier("categories-delete-selected")
            }
        }
        .task { await loadCategories() }
        .alert(AppLocalization.text("settings.categories.editName", language: language), isPresented: editAlertBinding) {
            TextField(AppLocalization.text("field.category", language: language), text: $editedName)
                .accessibilityIdentifier("category-name-editor")
            Button(AppLocalization.text("button.cancel", language: language), role: .cancel) { editingCategory = nil }
            Button(AppLocalization.text("button.save", language: language)) {
                guard let category = editingCategory else { return }
                Task { await save(category, name: editedName) }
            }
        }
        .alert(AppLocalization.text("settings.categories.add", language: language), isPresented: addAlertBinding) {
            TextField(AppLocalization.text("field.category", language: language), text: $newCategoryName)
                .accessibilityIdentifier("category-new-name")
            Button(AppLocalization.text("button.cancel", language: language), role: .cancel) { newCategoryKind = nil }
            Button(AppLocalization.text("button.save", language: language)) {
                guard let kind = newCategoryKind else { return }
                Task { await addCategory(named: newCategoryName, kind: kind) }
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

    private func categorySection(titleKey: String, categories: [Category]) -> some View {
        Section {
            ForEach(categories, id: \.id) { category in categoryRow(category) }
        } header: {
            HStack {
                Text(AppLocalization.text(titleKey, language: language))
                Spacer()
                Button {
                    newCategoryName = ""
                    newCategoryKind = categories.first?.kind ?? (titleKey == "entry.income" ? .income : .expense)
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier(titleKey == "entry.income" ? "category-add-income" : "category-add-expense")
            }
        }
    }

    private func categoryRow(_ category: Category) -> some View {
        let isOther = category.systemKey == "other"
        return HStack(spacing: 12) {
            if isManaging {
                Image(systemName: selectedCategoryIDs.contains(category.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOther ? Color.secondary.opacity(0.45) : Color.accentColor)
                    .accessibilityHidden(true)
            }
            Circle()
                .fill(category.kind == .income ? AppTheme.light.primaryAccent.color : AppTheme.light.secondaryAccent.color)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(LedgerFormatting.categoryName(category, language: language))
                .frame(maxWidth: .infinity, alignment: .leading)
            if !isManaging {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity)
        .opacity(isManaging && isOther ? 0.62 : 1)
        .onTapGesture {
            if isManaging {
                guard CategoryManagementPolicy.canDelete(systemKey: category.systemKey) else { return }
                if selectedCategoryIDs.contains(category.id) {
                    selectedCategoryIDs.remove(category.id)
                } else {
                    selectedCategoryIDs.insert(category.id)
                }
            } else {
                selectedCategory = category
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            guard !isManaging, CategoryManagementPolicy.canEdit(systemKey: category.systemKey) else { return }
            editingCategory = category
            editedName = category.customName ?? ""
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selectedCategoryIDs.contains(category.id) ? .isSelected : [])
        .accessibilityIdentifier("category-\(category.kind.rawValue)-\(category.id.uuidString.lowercased())")
    }

    private var editAlertBinding: Binding<Bool> {
        Binding(get: { editingCategory != nil }, set: { if !$0 { editingCategory = nil } })
    }

    private var addAlertBinding: Binding<Bool> {
        Binding(get: { newCategoryKind != nil }, set: { if !$0 { newCategoryKind = nil } })
    }

    @MainActor
    private func save(_ category: Category, name: String) async {
        do {
            let displayName = try CategoryEditPolicy.displayName(systemKey: category.systemKey, input: name)
            let siblings = category.kind == .expense ? expenseCategories : incomeCategories
            let names = siblings.filter { $0.id != category.id }.map { LedgerFormatting.categoryName($0, language: language) }
            guard !CategoryNamePolicy.isDuplicate(displayName ?? "", existingDisplayNames: names) else {
                throw LedgerRepositoryValidationError.duplicateCategoryName
            }
            try await repository.updateCategory(id: category.id, displayName: displayName, isHidden: false)
            editingCategory = nil
            await loadCategories()
        } catch { errorMessage = String(describing: error) }
    }

    @MainActor
    private func addCategory(named name: String, kind: EntryKind) async {
        do {
            let categories = kind == .expense ? expenseCategories : incomeCategories
            let names = categories.map { LedgerFormatting.categoryName($0, language: language) }
            guard !CategoryNamePolicy.isDuplicate(name, existingDisplayNames: names) else {
                throw LedgerRepositoryValidationError.duplicateCategoryName
            }
            _ = try await repository.ensureCustomCategory(named: name, kind: kind)
            newCategoryKind = nil
            await loadCategories()
        } catch { errorMessage = String(describing: error) }
    }

    @MainActor
    private func deleteSelection() async {
        do {
            try await repository.deleteCategories(ids: selectedCategoryIDs)
            selectedCategoryIDs.removeAll()
            isManaging = false
            await loadCategories()
        } catch { errorMessage = String(describing: error) }
    }

    @MainActor
    private func loadCategories() async {
        do {
            try await repository.seedDefaultsIfNeeded()
            expenseCategories = try await repository.categories(kind: .expense)
            incomeCategories = try await repository.categories(kind: .income)
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct CategoryEntriesView: View {
    @Environment(\.appCurrencyCode) private var currencyCode
    @Environment(\.colorScheme) private var colorScheme
    let category: Category
    let repository: LedgerRepository
    let language: AppLanguage
    let onBack: () -> Void
    @State private var entries: [LedgerEntry] = []
    @State private var editingEntry: LedgerEntry?
    @State private var errorMessage: String?
    @State private var selectedEntryIDs: Set<UUID> = []
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button(AppLocalization.text("button.back", language: language), action: onBack)
                    .accessibilityIdentifier("category-entries-back")
                Text(LedgerFormatting.categoryName(category, language: language)).font(.title2.weight(.semibold))
                Spacer()
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("category-entries-header")
            if errorMessage != nil {
                Text(AppLocalization.text("error.loadEntries", language: language)).foregroundStyle(.red)
            } else if entries.isEmpty {
                Text(AppLocalization.text("state.empty", language: language))
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .accessibilityIdentifier("category-entries-empty")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(LedgerEntryGrouping.groups(entries)) { group in
                            Section {
                                ForEach(group.entries) { entry in
                                    HStack(spacing: 12) {
                                        Text(entry.note.isEmpty ? AppLocalization.text("entry.noNote", language: language) : entry.note)
                                        Spacer()
                                        Text(LedgerFormatting.amount(entry.amount, currencyCode: currencyCode)).fontWeight(.semibold)
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
                                    .accessibilityIdentifier("category-entry-\(entry.id.uuidString.lowercased())")
                                }
                            } header: {
                                Text(group.date, format: .dateTime.year().month().day()).font(.headline)
                            }
                        }
                    }
                }
                .accessibilityIdentifier("category-entry-list")
            }
            if !selectedEntryIDs.isEmpty {
                SelectionSummaryBar(summary: selectionSummary, theme: theme, typography: .system) {
                    isDeleteConfirmationPresented = true
                } onCancel: {
                    selectedEntryIDs.removeAll()
                }
                .accessibilityIdentifier("category-selection-summary")
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(theme.primaryText.color)
        .background(theme.canvas.color)
        .task { await loadEntries() }
        .sheet(item: $editingEntry) { entry in
            EntryEditorView(entry: entry, repository: repository, theme: theme, typography: .system) {
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
            .accessibilityIdentifier("confirm-delete-selected")
            Button(AppLocalization.text("button.cancel", language: language), role: .cancel) { }
        }
    }

    private var theme: AppTheme { colorScheme == .dark ? .dark : .light }

    private var selectionSummary: SelectionSummary {
        SelectionSummary(entries: entries.filter { selectedEntryIDs.contains($0.id) })
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
        } catch { errorMessage = String(describing: error) }
    }

    private func loadEntries() async {
        do {
            entries = try await repository.allEntries().filter { $0.categoryID == category.id }
            selectedEntryIDs.formIntersection(Set(entries.map(\.id)))
            errorMessage = nil
        } catch { errorMessage = String(describing: error) }
    }
}

enum CategoryEditPolicy {
    static func displayName(systemKey: String?, input: String) throws -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            guard systemKey != nil else { throw LedgerRepositoryValidationError.emptyCustomCategoryName }
            return nil
        }
        return trimmed
    }
}

enum CategoryNamePolicy {
    static func isDuplicate(_ candidate: String, existingDisplayNames: [String]) -> Bool {
        let normalized = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        return existingDisplayNames.contains { $0.caseInsensitiveCompare(normalized) == .orderedSame }
    }
}

enum CategoryManagementPolicy {
    static func canEdit(systemKey: String?) -> Bool { systemKey != "other" }
    static func canDelete(systemKey: String?) -> Bool { systemKey != "other" }
}
