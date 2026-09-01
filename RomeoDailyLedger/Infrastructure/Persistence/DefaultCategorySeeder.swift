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
        Definition(kind: .expense, systemKey: "other", iconName: "ellipsis", colorToken: "other", sortOrder: Int.max),
        Definition(kind: .income, systemKey: "other", iconName: "ellipsis", colorToken: "other", sortOrder: Int.max),
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

        let allowedKeys = Set(Self.definitions.map { "\($0.kind.rawValue):\($0.systemKey)" })
        let obsolete = existing.filter {
            guard let systemKey = $0.systemKey else { return false }
            return !allowedKeys.contains("\($0.kindRaw):\(systemKey)")
        }
        let fallbacks = Dictionary(uniqueKeysWithValues: existing.compactMap {
            $0.systemKey == "other" ? ($0.kind, $0.id) : nil
        })
        if !obsolete.isEmpty {
            for entry in try context.fetch(FetchDescriptor<LedgerEntry>()) {
                guard let category = obsolete.first(where: { $0.id == entry.categoryID }),
                      let fallbackID = fallbacks[category.kind] else { continue }
                entry.categoryID = fallbackID
            }
            obsolete.forEach(context.delete)
        }
        if inserted || !obsolete.isEmpty {
            try context.save()
        }
    }
}
