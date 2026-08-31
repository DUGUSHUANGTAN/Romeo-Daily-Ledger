import SwiftUI

struct CategoryManagementView: View {
    let repository: LedgerRepository
    let language: AppLanguage
    @State private var expenseCategories: [Category] = []
    @State private var incomeCategories: [Category] = []
    @State private var draftNames: [UUID: String] = [:]
    @State private var draftHidden: [UUID: Bool] = [:]
    @State private var errorMessage: String?

    var body: some View {
        List {
            categorySection(titleKey: "entry.expense", categories: expenseCategories)
            categorySection(titleKey: "entry.income", categories: incomeCategories)
            if errorMessage != nil {
                Text(AppLocalization.text("error.loadCategories", language: language))
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("settings-categories-error")
            }
        }
        .navigationTitle(AppLocalization.text("settings.categories.title", language: language))
        .accessibilityIdentifier("settings-categories")
        .task { await loadCategories() }
    }

    private func categorySection(titleKey: String, categories: [Category]) -> some View {
        Section(AppLocalization.text(titleKey, language: language)) {
            ForEach(categories, id: \.id) { category in
                HStack(spacing: 12) {
                    Circle()
                        .fill(category.kind == .income ? AppTheme.light.primaryAccent.color : AppTheme.light.secondaryAccent.color)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    TextField(
                        AppLocalization.categoryName(systemKey: category.systemKey, customName: nil, language: language),
                        text: Binding(
                            get: { draftNames[category.id] ?? category.customName ?? "" },
                            set: { draftNames[category.id] = $0 }
                        )
                    )
                    .onSubmit { Task { await save(category) } }
                    .accessibilityIdentifier("category-name-\(category.id.uuidString.lowercased())")
                    Spacer()
                    Toggle(AppLocalization.text("settings.categories.hidden", language: language), isOn: Binding(
                        get: { draftHidden[category.id] ?? category.isHidden },
                        set: { value in draftHidden[category.id] = value; Task { await save(category) } }
                    )).toggleStyle(.switch)
                        .accessibilityIdentifier("category-hidden-\(category.id.uuidString.lowercased())")
                }
                .accessibilityIdentifier("category-\(category.kind.rawValue)-\(category.id.uuidString)")
            }
        }
    }

    @MainActor
    private func save(_ category: Category) async {
        do {
            let displayName = try CategoryEditPolicy.displayName(systemKey: category.systemKey, input: draftNames[category.id] ?? category.customName ?? "")
            try await repository.updateCategory(id: category.id, displayName: displayName, isHidden: draftHidden[category.id] ?? category.isHidden)
            await loadCategories()
        } catch { errorMessage = String(describing: error) }
    }

    @MainActor
    private func loadCategories() async {
        do {
            try await repository.seedDefaultsIfNeeded()
            expenseCategories = try await repository.categories(kind: .expense)
            incomeCategories = try await repository.categories(kind: .income)
            draftNames = Dictionary(uniqueKeysWithValues: (expenseCategories + incomeCategories).map { ($0.id, $0.customName ?? "") })
            draftHidden = Dictionary(uniqueKeysWithValues: (expenseCategories + incomeCategories).map { ($0.id, $0.isHidden) })
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
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
