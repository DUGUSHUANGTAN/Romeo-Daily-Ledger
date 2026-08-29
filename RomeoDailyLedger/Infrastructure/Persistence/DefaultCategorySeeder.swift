import SwiftData

@MainActor
struct DefaultCategorySeeder {
    struct Definition {
        let kind: EntryKind
        let systemKey: String
        let iconName: String
        let colorToken: String
        let sortOrder: Int
    }

    static let definitions: [Definition] = [
        Definition(kind: .expense, systemKey: "clothing", iconName: "shirt", colorToken: "clothing", sortOrder: 0),
        Definition(kind: .expense, systemKey: "food", iconName: "utensils", colorToken: "food", sortOrder: 1),
        Definition(kind: .expense, systemKey: "housing", iconName: "house", colorToken: "housing", sortOrder: 2),
        Definition(kind: .expense, systemKey: "transport", iconName: "bus", colorToken: "transport", sortOrder: 3),
        Definition(kind: .expense, systemKey: "entertainment", iconName: "gamepad-2", colorToken: "entertainment", sortOrder: 4),
        Definition(kind: .expense, systemKey: "other", iconName: "ellipsis", colorToken: "other", sortOrder: 5),
        Definition(kind: .income, systemKey: "salary", iconName: "briefcase-business", colorToken: "salary", sortOrder: 0),
        Definition(kind: .income, systemKey: "bonus", iconName: "gift", colorToken: "bonus", sortOrder: 1),
        Definition(kind: .income, systemKey: "investment", iconName: "chart-no-axes-combined", colorToken: "investment", sortOrder: 2),
        Definition(kind: .income, systemKey: "refund", iconName: "rotate-ccw", colorToken: "refund", sortOrder: 3),
        Definition(kind: .income, systemKey: "other", iconName: "ellipsis", colorToken: "other", sortOrder: 4),
    ]

    let context: ModelContext

    func seedIfNeeded() throws {
        let existing = try context.fetch(FetchDescriptor<Category>())
        let existingKeys = Set(existing.compactMap { category -> String? in
            guard let systemKey = category.systemKey else { return nil }
            return "\(category.kindRaw):\(systemKey)"
        })

        var inserted = false
        for definition in Self.definitions {
            let identity = "\(definition.kind.rawValue):\(definition.systemKey)"
            guard !existingKeys.contains(identity) else { continue }

            context.insert(
                Category(
                    kind: definition.kind,
                    systemKey: definition.systemKey,
                    iconName: definition.iconName,
                    colorToken: definition.colorToken,
                    sortOrder: definition.sortOrder
                )
            )
            inserted = true
        }

        if inserted {
            try context.save()
        }
    }
}
