import SwiftUI

struct CategoryManagementView: View {
    let repository: LedgerRepository
    let language: AppLanguage
    @State private var expenseCategories: [Category] = []
    @State private var incomeCategories: [Category] = []
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
                    Text(AppLocalization.categoryName(systemKey: category.systemKey, customName: category.customName, language: language))
                    Spacer()
                    if category.customName != nil {
                        Text(AppLocalization.text("settings.categories.custom", language: language))
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("category-\(category.kind.rawValue)-\(category.id.uuidString)")
            }
        }
    }

    @MainActor
    private func loadCategories() async {
        do {
            try await repository.seedDefaultsIfNeeded()
            expenseCategories = try await repository.categories(kind: .expense)
            incomeCategories = try await repository.categories(kind: .income)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
