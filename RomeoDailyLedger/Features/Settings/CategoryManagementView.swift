import SwiftUI

struct CategoryManagementView: View {
    let repository: LedgerRepository
    let language: AppLanguage
    @State private var expenseCategories: [Category] = []
    @State private var incomeCategories: [Category] = []
    @State private var selectedCategory: Category?
    @State private var editingCategory: Category?
    @State private var editedName = ""
    @State private var pendingDeletion: Category?
    @State private var newCategoryKind: EntryKind?
    @State private var newCategoryName = ""
    @State private var errorMessage: String?
    @State private var draggingCategoryID: UUID?
    @State private var dragTranslation: CGSize = .zero
    @State private var dropTargetID: UUID?
    @State private var categoryFrames: [UUID: CGRect] = [:]

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
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                categorySection(titleKey: "entry.expense", categories: expenseCategories)
                categorySection(titleKey: "entry.income", categories: incomeCategories)
                if errorMessage != nil {
                    Text(AppLocalization.text("error.loadCategories", language: language))
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("settings-categories-error")
                }
            }
            .padding(24)
        }
        .coordinateSpace(name: "category-drag-space")
        .onPreferenceChange(CategoryFramePreferenceKey.self) { categoryFrames = $0 }
        .navigationTitle(AppLocalization.text("settings.categories.title", language: language))
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
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible
        ) {
            Button(AppLocalization.text("button.confirmDelete", language: language), role: .destructive) {
                if let category = pendingDeletion { Task { await delete(category) } }
            }
            Button(AppLocalization.text("button.cancel", language: language), role: .cancel) { }
        }
    }

    private func categorySection(titleKey: String, categories: [Category]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(AppLocalization.text(titleKey, language: language))
                    .font(.headline)
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
            ForEach(categories, id: \.id) { category in categoryRow(category) }
        }
    }

    @ViewBuilder
    private func categoryRow(_ category: Category) -> some View {
        let isOther = category.systemKey == "other"
        let row = HStack(spacing: 12) {
            Circle()
                .fill(category.kind == .income ? AppTheme.light.primaryAccent.color : AppTheme.light.secondaryAccent.color)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(LedgerFormatting.categoryName(category, language: language))
                .frame(maxWidth: .infinity, alignment: .leading)
            if !isOther {
                Button(role: .destructive) {
                    pendingDeletion = category
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .accessibilityLabel(AppLocalization.text("button.delete", language: language))
                .accessibilityIdentifier("category-delete-\(category.id.uuidString.lowercased())")
                Button {
                    editingCategory = category
                    editedName = category.customName ?? ""
                } label: { Image(systemName: "pencil") }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("category-edit-\(category.id.uuidString.lowercased())")
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity, minHeight: 38)
        .padding(.horizontal, 4)
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(.secondary.opacity(0.25)) }
        .overlay(alignment: .top) {
            if dropTargetID == category.id, draggingCategoryID != category.id {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(height: 3)
                    .padding(.horizontal, 8)
                    .offset(y: -6)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: CategoryFramePreferenceKey.self,
                    value: [category.id: proxy.frame(in: .named("category-drag-space"))]
                )
            }
        }
        .scaleEffect(draggingCategoryID == category.id ? 1.025 : 1)
        .offset(draggingCategoryID == category.id ? dragTranslation : .zero)
        .shadow(color: .black.opacity(draggingCategoryID == category.id ? 0.18 : 0), radius: 14, y: 7)
        .zIndex(draggingCategoryID == category.id ? 10 : 0)
        .animation(.snappy(duration: 0.2), value: draggingCategoryID)
        .animation(.snappy(duration: 0.18), value: dropTargetID)
        .onTapGesture {
            selectedCategory = category
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("category-\(category.kind.rawValue)-\(category.id.uuidString.lowercased())")

        if isOther {
            row
        } else {
            row
                .highPriorityGesture(categoryDragGesture(for: category))
        }
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
    private func delete(_ category: Category) async {
        do {
            try await repository.deleteCategories(ids: [category.id])
            pendingDeletion = nil
            await loadCategories()
        } catch { errorMessage = String(describing: error) }
    }

    private func move(kind: EntryKind, source: IndexSet, destination: Int) {
        let current = kind == .expense ? expenseCategories : incomeCategories
        let reordered = CategoryOrder.reordered(current, from: source, to: destination)
        if kind == .expense { expenseCategories = reordered }
        else { incomeCategories = reordered }
        Task { @MainActor in
            do {
                try await repository.reorderCategories(
                    kind: kind,
                    orderedIDs: reordered.filter { $0.systemKey != "other" }.map(\.id)
                )
            } catch {
                errorMessage = String(describing: error)
                await loadCategories()
            }
        }
    }

    private func moveCategory(sourceID: UUID, onto target: Category) {
        guard sourceID != target.id else { return }
        let current = target.kind == .expense ? expenseCategories : incomeCategories
        let reordered = CategoryOrder.reordered(current, moving: sourceID, before: target.id)
        guard reordered.map(\.id) != current.map(\.id) else { return }
        if target.kind == .expense { expenseCategories = reordered }
        else { incomeCategories = reordered }
        Task { @MainActor in
            do {
                try await repository.reorderCategories(
                    kind: target.kind,
                    orderedIDs: reordered.filter { $0.systemKey != "other" }.map(\.id)
                )
            } catch {
                errorMessage = String(describing: error)
                await loadCategories()
            }
        }
    }

    private func categoryDragGesture(for category: Category) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named("category-drag-space"))
            .onChanged { value in
                draggingCategoryID = category.id
                dragTranslation = value.translation
                dropTargetID = nearestDropTarget(to: value.location, for: category)
            }
            .onEnded { _ in
                if let targetID = dropTargetID,
                   let target = (category.kind == .expense ? expenseCategories : incomeCategories)
                    .first(where: { $0.id == targetID }) {
                    moveCategory(sourceID: category.id, onto: target)
                }
                withAnimation(.snappy(duration: 0.24)) {
                    draggingCategoryID = nil
                    dragTranslation = .zero
                    dropTargetID = nil
                }
            }
    }

    private func nearestDropTarget(to location: CGPoint, for category: Category) -> UUID? {
        let candidates = (category.kind == .expense ? expenseCategories : incomeCategories)
            .filter { $0.id != category.id }
        return candidates.min { lhs, rhs in
            abs((categoryFrames[lhs.id]?.midY ?? .greatestFiniteMagnitude) - location.y)
                < abs((categoryFrames[rhs.id]?.midY ?? .greatestFiniteMagnitude) - location.y)
        }?.id
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

private struct CategoryFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

enum CategoryOrder {
    static func reordered(_ categories: [Category], from source: IndexSet, to destination: Int) -> [Category] {
        var movable = categories.filter { $0.systemKey != "other" }
        let validSource = IndexSet(source.filter { $0 < movable.count })
        guard !validSource.isEmpty else { return categories }
        movable.move(fromOffsets: validSource, toOffset: min(destination, movable.count))
        return movable + categories.filter { $0.systemKey == "other" }
    }

    static func reordered(_ categories: [Category], moving sourceID: UUID, before targetID: UUID) -> [Category] {
        guard let source = categories.first(where: { $0.id == sourceID }), source.systemKey != "other",
              categories.contains(where: { $0.id == targetID }) else { return categories }
        var movable = categories.filter { $0.systemKey != "other" && $0.id != sourceID }
        if let targetIndex = movable.firstIndex(where: { $0.id == targetID }) {
            movable.insert(source, at: targetIndex)
        } else {
            movable.append(source)
        }
        return movable + categories.filter { $0.systemKey == "other" }
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
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(entry.note.isEmpty ? AppLocalization.text("entry.noNote", language: language) : entry.note)
                                            Text("\(AppLocalization.text(entry.kind == .income ? "entry.income" : "entry.expense", language: language)) · \(LedgerFormatting.categoryName(category, language: language))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
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
